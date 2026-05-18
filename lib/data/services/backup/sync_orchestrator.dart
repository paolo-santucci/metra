// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/errors/metra_exception.dart';
import '../../../domain/entities/backup_snapshot.dart';
import '../../../domain/entities/sync_log_entity.dart';
import '../../../domain/repositories/app_settings_repository.dart';
import '../../../domain/repositories/daily_log_repository.dart';
import '../../../domain/repositories/sync_log_repository.dart';
import '../../../domain/use_cases/backup_data.dart';
import '../encryption_service.dart';
import 'backup_file_entry.dart';
import 'backup_filename.dart';
import 'backup_service.dart';
import 'dropbox_provider.dart';

typedef RecomputeFn = Future<dynamic> Function();

/// Maximum number of backup files to retain in cloud storage.
/// TASK-04 reduced from 10 to 3; the 507 retry loop caps progressive-prune
/// deletions at [kBackupRetentionMaxFiles] − 1 = 2.
const int kBackupRetentionMaxFiles = 3;

class SyncOrchestrator implements BackupRunner {
  SyncOrchestrator({
    required BackupService backupService,
    required EncryptionService encryptionService,
    required CloudBackupProvider provider,
    required AppSettingsRepository settingsRepo,
    required SyncLogRepository syncLogRepo,
    required DailyLogRepository logRepo,
    required RecomputeFn recompute,
    required FlutterSecureStorage secureStorage,
    DateTime Function()? now,
  })  : _backupService = backupService,
        _encryption = encryptionService,
        _provider = provider,
        _settingsRepo = settingsRepo,
        _syncLogRepo = syncLogRepo,
        _logRepo = logRepo,
        _recompute = recompute,
        _secureStorage = secureStorage,
        _now = now ?? _defaultNow;

  static const _passphraseKey = 'metra_backup_passphrase_v1';

  static DateTime _defaultNow() => DateTime.now().toUtc();

  final BackupService _backupService;
  final EncryptionService _encryption;
  final CloudBackupProvider _provider;
  final AppSettingsRepository _settingsRepo;
  final SyncLogRepository _syncLogRepo;
  final DailyLogRepository _logRepo;
  final RecomputeFn _recompute;
  final FlutterSecureStorage _secureStorage;
  final DateTime Function() _now;

  @override
  Future<void> backup() async {
    final ts = _now();
    try {
      final passphrase = await _secureStorage.read(key: _passphraseKey);
      if (passphrase == null) {
        throw const SyncException('No passphrase configured');
      }
      final snapshot = await _backupService.buildSnapshot();
      final bytes = Uint8List.fromList(utf8.encode(snapshot.encode()));
      final blob = await _encryption.encrypt(bytes, passphrase);
      final filename = BackupFilename.filenameFor(ts);
      // 507 progressive-prune retry loop (FR-14, NFR-02).
      // On InsufficientStorageException the oldest backup is deleted to free
      // space, then upload is retried. Safety constraints:
      //   - Never delete the last remaining file (FR-14 safety floor).
      //   - At most kBackupRetentionMaxFiles − 1 deletions (NFR-02 cap = 2).
      // Individual deleteFile failures are swallowed (EC-06).
      var pruneDeletions = 0;
      while (true) {
        try {
          await _provider.upload(blob, filename);
          break; // upload succeeded
        } on InsufficientStorageException {
          final currentFiles = await _provider.listFiles();
          if (currentFiles.length <= 1) {
            // Safety floor: never delete the last backup — rethrow immediately.
            rethrow;
          }
          if (pruneDeletions >= kBackupRetentionMaxFiles - 1) {
            // NFR-02 cap reached — rethrow.
            rethrow;
          }
          final oldest = currentFiles.last;
          try {
            await _provider.deleteFile(oldest.name);
          } catch (_) {
            // EC-06: swallow per-file delete failure; next listFiles() call
            // in the following iteration will reflect the actual state.
          }
          await _syncLogRepo.append(
            SyncLogEntity(
              timestamp: _now(),
              provider: SyncProvider.dropbox,
              operation: SyncOperation.backup,
              success: false,
              errorMessage: 'progressive-prune: ${oldest.name}',
            ),
          );
          pruneDeletions++;
        }
      }
      // Verify that the upload registered before pruning older files.
      final files = await _provider.listFiles();
      if (!files.any((e) => e.name == filename)) {
        throw const SyncException('Upload verification failed');
      }
      // Prune entries beyond the N=10 retention cap — best-effort; a per-file
      // failure is logged and does not abort the overall backup operation.
      // listFiles() returns entries newest-first; take(N) keeps the newest N.
      final pruneSet = files.skip(kBackupRetentionMaxFiles);
      for (final BackupFileEntry entry in pruneSet) {
        try {
          await _provider.deleteFile(entry.name);
        } catch (e) {
          await _syncLogRepo.append(
            SyncLogEntity(
              timestamp: _now(),
              provider: SyncProvider.dropbox,
              operation: SyncOperation.backup,
              success: false,
              errorMessage: 'prune-failure: ${entry.name}: $e',
            ),
          );
        }
      }
      final settings = await _settingsRepo.getOrCreate();
      await _settingsRepo.updateBackupState(
        dropboxEmail: settings.dropboxEmail,
        lastBackupAt: ts,
      );
      await _syncLogRepo.append(
        SyncLogEntity(
          timestamp: ts,
          provider: SyncProvider.dropbox,
          operation: SyncOperation.backup,
          success: true,
        ),
      );
    } catch (e) {
      await _syncLogRepo.append(
        SyncLogEntity(
          timestamp: ts,
          provider: SyncProvider.dropbox,
          operation: SyncOperation.backup,
          success: false,
          errorMessage: e.toString(),
        ),
      );
      rethrow;
    }
  }

  @override
  Future<void> restore({String? filename}) async {
    final ts = _now();
    try {
      final passphrase = await _secureStorage.read(key: _passphraseKey);
      if (passphrase == null) {
        throw const SyncException('No passphrase configured');
      }
      final files = await _provider.listFiles();
      if (files.isEmpty) {
        throw const SyncException('No backup found');
      }
      // When filename is null, download the newest file (legacy path).
      // When filename is non-null, download the exact requested file.
      final blob = await _provider.download(filename ?? files.first.name);
      final bytes = await _encryption.decrypt(blob, passphrase);
      final snapshot = BackupSnapshot.decode(utf8.decode(bytes));
      final logs = snapshot.logsWithSymptoms.map((lws) => lws.log).toList();
      final symptomsMap = {
        for (final lws in snapshot.logsWithSymptoms) lws.log.date: lws.symptoms,
      };
      await _logRepo.deleteAllAndReplace(logs, symptomsMap);
      await _recompute();
      // FR-15: align lastLogOrSymptomWriteAt to lastBackupAt after a successful
      // restore. Without this, deleteAllAndReplace() bumps lastLogOrSymptomWriteAt
      // to the restore time, and the next cold-start would see it > lastBackupAt
      // and re-upload the just-restored data unnecessarily.
      final freshSettings = await _settingsRepo.getOrCreate();
      if (freshSettings.lastBackupAt != null) {
        await _settingsRepo.updateLastDataWriteAt(freshSettings.lastBackupAt!);
      }
      await _syncLogRepo.append(
        SyncLogEntity(
          timestamp: ts,
          provider: SyncProvider.dropbox,
          operation: SyncOperation.restore,
          success: true,
        ),
      );
    } catch (e) {
      await _syncLogRepo.append(
        SyncLogEntity(
          timestamp: ts,
          provider: SyncProvider.dropbox,
          operation: SyncOperation.restore,
          success: false,
          errorMessage: e.toString(),
        ),
      );
      rethrow;
    }
  }
}
