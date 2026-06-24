// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
//
// Métra is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License,
// or (at your option) any later version.
//
// Métra is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Métra. If not, see <https://www.gnu.org/licenses/>.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/backup/backup_file_entry.dart';
import '../data/services/backup/backup_service.dart';
import '../data/services/backup/cloud_backup_provider.dart';
import '../data/services/backup/dropbox_provider.dart';
import '../data/services/backup/google_drive_provider.dart';
import '../data/services/backup/sync_orchestrator.dart';
import '../domain/entities/sync_log_entity.dart';
import '../domain/use_cases/backup_data.dart';
import '../domain/use_cases/restore_data.dart';
import 'encryption_provider.dart';
import 'repository_providers.dart';
import 'use_case_providers.dart';

const _dropboxAppKey = String.fromEnvironment('DROPBOX_APP_KEY');
const _googleOauthClientId = String.fromEnvironment('GOOGLE_OAUTH_CLIENT_ID');

final dropboxProviderProvider = Provider<DropboxProvider>((ref) {
  return DropboxProvider(
    appKey: _dropboxAppKey,
    storage: ref.watch(secureStorageProvider),
  );
});

final googleDriveProviderProvider = Provider<GoogleDriveProvider>(
  (ref) => GoogleDriveProvider(
    clientId: _googleOauthClientId,
    storage: ref.watch(secureStorageProvider),
  ),
);

/// Resolves the active backup provider implementation from the persisted
/// [AppSettingsData.activeProvider] setting.
///
/// Stays a synchronous [Provider] — converting to [FutureProvider] would break
/// 40+ [overrideWithValue] test sites and cascade [await] through
/// [backupFileListProvider] and [BackupNotifier] (NFR-03).
///
/// Resolution rules:
/// - Reads [appSettingsStreamProvider].valueOrNull?.activeProvider synchronously.
/// - Defaults to [SyncProvider.dropbox] during the settings-loading frame
///   (when the stream has not yet emitted — EC-01).
/// - M2: googleDrive → GoogleDriveProvider (ODQ-1 resolved).
/// - iCloud has no impl yet — falls back to Dropbox (ODQ-1, pending M3).
final cloudBackupProvider = Provider<CloudBackupProvider>((ref) {
  // Read activeProvider synchronously; default to dropbox during the
  // settings-loading frame (stream has not yet emitted — EC-01).
  final activeProvider =
      ref.watch(appSettingsStreamProvider).valueOrNull?.activeProvider ??
          SyncProvider.dropbox;

  switch (activeProvider) {
    case SyncProvider.dropbox:
      return ref.watch(dropboxProviderProvider);
    case SyncProvider.googleDrive:
      return ref.watch(googleDriveProviderProvider);
    case SyncProvider.iCloud:
      // iCloud has no impl yet — fall back to Dropbox (ODQ-1, pending M3).
      return ref.watch(dropboxProviderProvider);
  }
});

final backupServiceProvider = FutureProvider<BackupService>((ref) async {
  final logRepo = await ref.watch(dailyLogRepositoryProvider.future);
  return BackupService(logRepo);
});

final syncOrchestratorProvider = FutureProvider<SyncOrchestrator>((ref) async {
  final backupSvc = await ref.watch(backupServiceProvider.future);
  final settingsRepo = await ref.watch(appSettingsRepositoryProvider.future);
  final logRepo = await ref.watch(dailyLogRepositoryProvider.future);
  final syncLogRepo = await ref.watch(syncLogRepositoryProvider.future);
  final recomputeUseCase =
      await ref.watch(recomputeCycleEntriesProvider.future);
  return SyncOrchestrator(
    backupService: backupSvc,
    encryptionService: ref.watch(encryptionServiceProvider),
    provider: ref.watch(cloudBackupProvider),
    settingsRepo: settingsRepo,
    syncLogRepo: syncLogRepo,
    logRepo: logRepo,
    // RecomputeCycleEntries is a callable class; the tear-off satisfies
    // RecomputeFn = Future<dynamic> Function() because Result<...> <: dynamic.
    recompute: recomputeUseCase.call,
    secureStorage: ref.watch(secureStorageProvider),
  );
});

final backupDataProvider = FutureProvider<BackupData>((ref) async {
  final orch = await ref.watch(syncOrchestratorProvider.future);
  return BackupData(orch);
});

final restoreDataProvider = FutureProvider<RestoreData>((ref) async {
  final orch = await ref.watch(syncOrchestratorProvider.future);
  return RestoreData(orch);
});

final backupFileListProvider =
    FutureProvider.autoDispose<List<BackupFileEntry>>((ref) async {
  return ref.watch(cloudBackupProvider).listFiles();
});
