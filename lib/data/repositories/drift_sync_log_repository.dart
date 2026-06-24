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

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../data/database/app_database.dart';
import '../../data/database/daos/sync_log_dao.dart';
import '../../domain/entities/sync_log_entity.dart';
import '../../domain/repositories/sync_log_repository.dart';

class DriftSyncLogRepository implements SyncLogRepository {
  const DriftSyncLogRepository(this._dao);

  final SyncLogDao _dao;

  // ---- enum <-> string mapping ----

  // Explicit switch guards against future enum members being silently stored
  // as arbitrary .name strings that differ from the DB contract.
  // Wire strings are hard-coded names (FR-04, NFR-06) — never `.name`.
  @visibleForTesting
  static String providerToString(SyncProvider provider) => switch (provider) {
        SyncProvider.dropbox => 'dropbox',
        SyncProvider.googleDrive => 'google_drive',
        SyncProvider.iCloud => 'icloud',
      };

  // The sync-log read path stays strict: unknown values throw (never clamp).
  // The settings read path uses a separate clamp-mapper (TASK-07).
  @visibleForTesting
  static SyncProvider stringToProvider(String value) => switch (value) {
        'dropbox' => SyncProvider.dropbox,
        'google_drive' => SyncProvider.googleDrive,
        'icloud' => SyncProvider.iCloud,
        _ => throw StateError('Unknown SyncProvider in DB: "$value"'),
      };

  static String _operationToString(SyncOperation op) => switch (op) {
        SyncOperation.backup => 'backup',
        SyncOperation.restore => 'restore',
        SyncOperation.backupSkipped => 'backup_skipped',
      };

  static SyncOperation _stringToOperation(String value) => switch (value) {
        'backup' => SyncOperation.backup,
        'restore' => SyncOperation.restore,
        'backup_skipped' => SyncOperation.backupSkipped,
        _ => throw StateError('Unknown SyncOperation in DB: "$value"'),
      };

  // ---- redaction ----

  // Truncates and strips OAuth bearer tokens and query-string tokens so that
  // no access credentials end up in the local audit log.  Returns null when
  // the input is null (preserving the absence of an error message).
  static String? _redactErrorMessage(String? msg) {
    if (msg == null) return null;
    var clean = msg.length > 500 ? '${msg.substring(0, 500)}…' : msg;
    clean = clean.replaceAll(
      RegExp(r'Bearer\s+[A-Za-z0-9._\-]+'),
      'Bearer [REDACTED]',
    );
    clean = clean.replaceAll(
      RegExp(r'access_token=[^&\s]+'),
      'access_token=[REDACTED]',
    );
    clean = clean.replaceAll(
      RegExp(r'refresh_token=[^&\s]+'),
      'refresh_token=[REDACTED]',
    );
    return clean;
  }

  // ---- mapping helpers ----

  static SyncLogEntity _fromRow(SyncLog row) => SyncLogEntity(
        id: row.id,
        timestamp: row.timestamp.toUtc(),
        provider: stringToProvider(row.provider),
        operation: _stringToOperation(row.operation),
        success: row.success,
        errorMessage: row.errorMessage,
      );

  static SyncLogsCompanion _toInsertCompanion(SyncLogEntity entity) =>
      SyncLogsCompanion.insert(
        timestamp: entity.timestamp,
        provider: providerToString(entity.provider),
        operation: _operationToString(entity.operation),
        success: entity.success,
        errorMessage: Value(_redactErrorMessage(entity.errorMessage)),
      );

  // ---- interface implementation ----

  @override
  Future<void> append(SyncLogEntity log) =>
      _dao.insertLog(_toInsertCompanion(log));

  @override
  Future<List<SyncLogEntity>> getRecent({int limit = 50}) async {
    final rows = await _dao.getRecent(limit);
    return rows.map(_fromRow).toList();
  }

  @override
  Future<void> deleteAll() => _dao.deleteAllLogs();
}
