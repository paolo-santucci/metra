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

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/data/database/app_database.dart';
import 'package:metra/data/database/daos/sync_log_dao.dart';
import 'package:metra/data/repositories/drift_sync_log_repository.dart';
import 'package:metra/domain/entities/sync_log_entity.dart';

AppDatabase _openTestDb() => AppDatabase(NativeDatabase.memory());

void main() {
  // ---- TASK-01: wire-map pure functions (no DB required) ----

  group('wire-map pure functions (no DB required)', () {
    group('providerToString', () {
      test(
        'given_dropbox_when_converting_to_string_then_returns_dropbox',
        () {
          expect(
            DriftSyncLogRepository.providerToString(SyncProvider.dropbox),
            'dropbox',
          );
        },
      );

      test(
        'given_googleDrive_when_converting_to_string_then_returns_google_drive',
        () {
          expect(
            DriftSyncLogRepository.providerToString(SyncProvider.googleDrive),
            'google_drive',
          );
        },
      );

      test(
        'given_iCloud_when_converting_to_string_then_returns_icloud',
        () {
          expect(
            DriftSyncLogRepository.providerToString(SyncProvider.iCloud),
            'icloud',
          );
        },
      );

      test(
        'given_all_providers_when_converting_to_string_then_results_are_string_based_not_positional',
        () {
          // Verifies wire strings are hard-coded names, not enum index or .name.
          // If code used .name, dropbox→"dropbox" (coincidentally correct) but
          // googleDrive→"googleDrive" (not "google_drive") and iCloud→"iCloud"
          // (not "icloud") — these assertions catch any .name regression.
          expect(
            DriftSyncLogRepository.providerToString(SyncProvider.googleDrive),
            isNot(SyncProvider.googleDrive.name),
          );
          expect(
            DriftSyncLogRepository.providerToString(SyncProvider.iCloud),
            isNot(SyncProvider.iCloud.name),
          );
        },
      );
    });

    group('stringToProvider', () {
      test(
        'given_dropbox_string_when_converting_then_returns_dropbox',
        () {
          expect(
            DriftSyncLogRepository.stringToProvider('dropbox'),
            SyncProvider.dropbox,
          );
        },
      );

      test(
        'given_google_drive_string_when_converting_then_returns_googleDrive',
        () {
          expect(
            DriftSyncLogRepository.stringToProvider('google_drive'),
            SyncProvider.googleDrive,
          );
        },
      );

      test(
        'given_icloud_string_when_converting_then_returns_iCloud',
        () {
          expect(
            DriftSyncLogRepository.stringToProvider('icloud'),
            SyncProvider.iCloud,
          );
        },
      );

      test(
        'given_unknown_value_when_converting_then_throws_StateError',
        () {
          expect(
            () => DriftSyncLogRepository.stringToProvider('unknown_value'),
            throwsA(isA<StateError>()),
          );
        },
      );

      test(
        'given_oneDrive_legacy_string_when_converting_then_throws_StateError',
        () {
          // The read path stays strict: unknown values throw, never silently map.
          expect(
            () => DriftSyncLogRepository.stringToProvider('one_drive'),
            throwsA(isA<StateError>()),
          );
        },
      );
    });
  });

  // ---- end TASK-01 ----

  // ---- DB-dependent tests (GREEN-ON-CI-ONLY: require native sqlite3) ----

  late AppDatabase db;
  late SyncLogDao dao;
  late DriftSyncLogRepository repo;

  setUp(() {
    db = _openTestDb();
    dao = db.syncLogDao;
    repo = DriftSyncLogRepository(dao);
  });

  tearDown(() => db.close());

  final baseTimestamp = DateTime.utc(2026, 4, 29, 12);

  SyncLogEntity makeLog({
    SyncProvider provider = SyncProvider.dropbox,
    SyncOperation operation = SyncOperation.backup,
    bool success = true,
    String? errorMessage,
  }) =>
      SyncLogEntity(
        timestamp: baseTimestamp,
        provider: provider,
        operation: operation,
        success: success,
        errorMessage: errorMessage,
      );

  test('round-trip: append then getRecent returns the same field values',
      () async {
    final log = makeLog(success: true);
    await repo.append(log);

    final recent = await repo.getRecent(limit: 1);
    expect(recent.length, 1);

    final stored = recent.first;
    expect(stored.timestamp.toUtc(), log.timestamp.toUtc());
    expect(stored.provider, SyncProvider.dropbox);
    expect(stored.operation, SyncOperation.backup);
    expect(stored.success, true);
    expect(stored.errorMessage, isNull);
    // id is auto-assigned, must be non-null after insert
    expect(stored.id, isNotNull);
  });

  test('deleteAll empties the log', () async {
    await repo.append(makeLog());
    await repo.append(makeLog());

    await repo.deleteAll();

    final after = await repo.getRecent();
    expect(after, isEmpty);
  });

  test('Bearer token in errorMessage is redacted on store', () async {
    final log = makeLog(
      success: false,
      errorMessage: '401 Bearer abc.def.ghi unauthorized',
    );
    await repo.append(log);

    final recent = await repo.getRecent(limit: 1);
    expect(recent.first.errorMessage, '401 Bearer [REDACTED] unauthorized');
  });

  test('access_token query parameter is redacted on store', () async {
    final log = makeLog(
      success: false,
      errorMessage:
          'https://api.dropbox.com/token?access_token=supersecret&foo=bar',
    );
    await repo.append(log);

    final recent = await repo.getRecent(limit: 1);
    expect(
      recent.first.errorMessage,
      'https://api.dropbox.com/token?access_token=[REDACTED]&foo=bar',
    );
  });

  test('getRecent respects limit and returns most recent first', () async {
    final t1 = DateTime.utc(2026, 4, 1);
    final t2 = DateTime.utc(2026, 4, 2);
    final t3 = DateTime.utc(2026, 4, 3);

    await repo.append(
      SyncLogEntity(
        timestamp: t1,
        provider: SyncProvider.dropbox,
        operation: SyncOperation.backup,
        success: true,
      ),
    );
    await repo.append(
      SyncLogEntity(
        timestamp: t2,
        provider: SyncProvider.dropbox,
        operation: SyncOperation.restore,
        success: true,
      ),
    );
    await repo.append(
      SyncLogEntity(
        timestamp: t3,
        provider: SyncProvider.dropbox,
        operation: SyncOperation.backup,
        success: false,
      ),
    );

    final recent = await repo.getRecent(limit: 2);
    expect(recent.length, 2);
    // Most recent timestamp comes first.
    expect(recent.first.timestamp.toUtc(), t3);
    expect(recent.last.timestamp.toUtc(), t2);
  });
}
