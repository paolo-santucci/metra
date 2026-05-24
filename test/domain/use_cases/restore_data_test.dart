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
import 'package:metra/core/errors/metra_exception.dart';
import 'package:metra/core/utils/result.dart';
import 'package:metra/domain/use_cases/restore_data.dart';

import '../../helpers/fake_backup_runner.dart';

void main() {
  group('RestoreData — existing behaviour', () {
    test('returns Ok(0) on success (default restoreReturnValue)', () async {
      final runner = FakeBackupRunner();
      final result = await RestoreData(runner)();
      expect(result, isA<Ok<int>>());
      expect(runner.restoreCallCount, equals(1));
    });

    test('returns Err on MetraException (e.g. SyncException)', () async {
      final runner = FakeBackupRunner()
        ..restoreError = const SyncException('x');
      final result = await RestoreData(runner)();
      expect(result, isA<Err<int>>());
      expect((result as Err<int>).error, isA<SyncException>());
    });

    test('wraps unknown error in SyncException Err', () async {
      final runner = FakeBackupRunner()
        ..restoreError = StateError('unexpected');
      final result = await RestoreData(runner)();
      expect(result, isA<Err<int>>());
      expect((result as Err<int>).error, isA<SyncException>());
    });

    test('EncryptionException flows through as Err', () async {
      final runner = FakeBackupRunner()
        ..restoreError = const EncryptionException('wrong passphrase');
      final result = await RestoreData(runner)();
      expect(result, isA<Err<int>>());
      expect((result as Err<int>).error, isA<EncryptionException>());
    });
  });

  group('RestoreData — filename forwarding (FR-14a)', () {
    test(
      'given_filename_string_when_call_with_filename_then_runner_receives_filename',
      () async {
        final runner = FakeBackupRunner();
        final useCase = RestoreData(runner);
        await useCase.call(
          filename: 'metra_backup_20260517T120000Z_abc123.enc',
        );
        expect(
          runner.lastFilename,
          equals('metra_backup_20260517T120000Z_abc123.enc'),
        );
      },
    );

    test(
      'given_null_filename_when_call_with_null_then_runner_receives_null_and_is_called_once',
      () async {
        final runner = FakeBackupRunner();
        final useCase = RestoreData(runner);
        await useCase.call(filename: null);
        expect(runner.lastFilename, isNull);
        expect(runner.restoreCallCount, equals(1));
      },
    );
  });

  group('RestoreData — Future<int> return (BUG-RT02)', () {
    test('call_returns_Ok_int_when_runner_succeeds', () async {
      final runner = FakeBackupRunner()..restoreReturnValue = 7;
      final useCase = RestoreData(runner);
      final result = await useCase(filename: 'metra_backup_test');
      expect(result, isA<Ok<int>>());
      expect((result as Ok<int>).value, equals(7));
    });

    test('call_returns_Err_when_runner_throws', () async {
      final runner = FakeBackupRunner()
        ..restoreError = const SyncException('boom');
      final useCase = RestoreData(runner);
      final result = await useCase();
      expect(result, isA<Err<int>>());
      expect((result as Err<int>).error.message, contains('boom'));
    });
  });
}
