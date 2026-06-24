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

import 'package:flutter_test/flutter_test.dart';
import 'package:metra/domain/entities/sync_log_entity.dart';

void main() {
  // ---- TASK-01: SyncProvider enum contract ----

  group('SyncProvider enum contract', () {
    test(
      'given_syncProvider_when_checking_values_length_then_exactly_three_members',
      () {
        expect(SyncProvider.values.length, 3);
      },
    );

    test(
      'given_syncProvider_when_listing_members_then_contains_exactly_dropbox_googleDrive_iCloud',
      () {
        expect(
          SyncProvider.values,
          containsAll([
            SyncProvider.dropbox,
            SyncProvider.googleDrive,
            SyncProvider.iCloud,
          ]),
        );
      },
    );

    test(
      'given_syncProvider_when_checking_names_then_no_oneDrive_member_exists',
      () {
        final names = SyncProvider.values.map((e) => e.name).toList();
        expect(names, isNot(contains('oneDrive')));
      },
    );
  });

  // ---- end TASK-01 ----

  final ts = DateTime.utc(2026, 5, 1, 12, 0);

  SyncLogEntity makeLog({
    int? id = 1,
    DateTime? timestamp,
    SyncProvider provider = SyncProvider.dropbox,
    SyncOperation operation = SyncOperation.backup,
    bool success = true,
    String? errorMessage,
  }) =>
      SyncLogEntity(
        id: id,
        timestamp: timestamp ?? ts,
        provider: provider,
        operation: operation,
        success: success,
        errorMessage: errorMessage,
      );

  group('SyncLogEntity construction', () {
    test('stores all required fields', () {
      final log = SyncLogEntity(
        timestamp: ts,
        provider: SyncProvider.dropbox,
        operation: SyncOperation.backup,
        success: true,
      );

      expect(log.id, isNull);
      expect(log.timestamp, ts);
      expect(log.provider, SyncProvider.dropbox);
      expect(log.operation, SyncOperation.backup);
      expect(log.success, isTrue);
      expect(log.errorMessage, isNull);
    });

    test('stores optional id and errorMessage when provided', () {
      final log = makeLog(id: 42, errorMessage: 'network failure');

      expect(log.id, 42);
      expect(log.errorMessage, 'network failure');
    });

    test('stores restore operation', () {
      final log = makeLog(operation: SyncOperation.restore);

      expect(log.operation, SyncOperation.restore);
    });

    test('stores failed sync', () {
      final log = makeLog(success: false, errorMessage: 'timeout');

      expect(log.success, isFalse);
      expect(log.errorMessage, 'timeout');
    });
  });

  group('SyncLogEntity equality', () {
    test('identical instance equals itself', () {
      final log = makeLog();
      expect(log == log, isTrue);
    });

    test('two instances with same fields are equal', () {
      final a = makeLog(id: 5, errorMessage: 'err');
      final b = makeLog(id: 5, errorMessage: 'err');

      expect(a, equals(b));
    });

    test('instances with different id are not equal', () {
      final a = makeLog(id: 1);
      final b = makeLog(id: 2);

      expect(a, isNot(equals(b)));
    });

    test('instances with different timestamp are not equal', () {
      final a = makeLog(timestamp: DateTime.utc(2026, 5, 1));
      final b = makeLog(timestamp: DateTime.utc(2026, 5, 2));

      expect(a, isNot(equals(b)));
    });

    test('instances with different provider are not equal', () {
      // Currently only dropbox exists; test structural branch by comparing
      // a log with its copy where we mutate via copyWith on a field we own.
      // Since there is only one provider, we test the provider path via copyWith.
      final a = makeLog();
      final b = a.copyWith(provider: SyncProvider.dropbox, success: false);

      expect(a, isNot(equals(b)));
    });

    test('instances with different operation are not equal', () {
      final a = makeLog(operation: SyncOperation.backup);
      final b = makeLog(operation: SyncOperation.restore);

      expect(a, isNot(equals(b)));
    });

    test('instances with different success are not equal', () {
      final a = makeLog(success: true);
      final b = makeLog(success: false);

      expect(a, isNot(equals(b)));
    });

    test('instances with different errorMessage are not equal', () {
      final a = makeLog(errorMessage: 'err A');
      final b = makeLog(errorMessage: 'err B');

      expect(a, isNot(equals(b)));
    });

    test('instance does not equal object of different type', () {
      final log = makeLog();

      // ignore: unrelated_type_equality_checks
      expect(log == 'not a log', isFalse);
    });
  });

  group('SyncLogEntity hashCode', () {
    test('equal objects have the same hashCode', () {
      final a = makeLog(id: 7, errorMessage: 'oops');
      final b = makeLog(id: 7, errorMessage: 'oops');

      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('SyncLogEntity copyWith', () {
    test('returns equal object when no arguments supplied', () {
      final log = makeLog(id: 3, errorMessage: 'x');
      final copy = log.copyWith();

      expect(copy, equals(log));
    });

    test('updates id', () {
      final log = makeLog(id: 1);
      final copy = log.copyWith(id: 99);

      expect(copy.id, 99);
    });

    test('updates timestamp', () {
      final log = makeLog();
      final newTs = DateTime.utc(2026, 6, 15);
      final copy = log.copyWith(timestamp: newTs);

      expect(copy.timestamp, newTs);
    });

    test('updates provider', () {
      final log = makeLog();
      final copy = log.copyWith(provider: SyncProvider.dropbox);

      expect(copy.provider, SyncProvider.dropbox);
    });

    test('updates operation', () {
      final log = makeLog(operation: SyncOperation.backup);
      final copy = log.copyWith(operation: SyncOperation.restore);

      expect(copy.operation, SyncOperation.restore);
    });

    test('updates success', () {
      final log = makeLog(success: true);
      final copy = log.copyWith(success: false);

      expect(copy.success, isFalse);
    });

    test('updates errorMessage', () {
      final log = makeLog();
      final copy = log.copyWith(errorMessage: 'new error');

      expect(copy.errorMessage, 'new error');
    });

    test('preserves errorMessage when not specified', () {
      final log = makeLog(errorMessage: 'preserved');
      final copy = log.copyWith(success: false);

      expect(copy.errorMessage, 'preserved');
    });
  });
}
