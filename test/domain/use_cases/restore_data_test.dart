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
import 'package:metra/domain/use_cases/backup_data.dart';
import 'package:metra/domain/use_cases/restore_data.dart';

class _FakeRunner implements BackupRunner {
  Object? restoreError;
  bool restoreCalled = false;

  @override
  Future<void> backup() async {}

  @override
  Future<void> restore() async {
    restoreCalled = true;
    if (restoreError != null) throw restoreError!;
  }
}

void main() {
  test('returns Ok(null) on success', () async {
    final r = _FakeRunner();
    final result = await RestoreData(r)();
    expect(result, isA<Ok<void>>());
    expect(r.restoreCalled, isTrue);
  });

  test('returns Err on MetraException (e.g. SyncException)', () async {
    final r = _FakeRunner()..restoreError = const SyncException('x');
    final result = await RestoreData(r)();
    expect(result, isA<Err<void>>());
    expect((result as Err<void>).error, isA<SyncException>());
  });

  test('wraps unknown error in SyncException Err', () async {
    final r = _FakeRunner()..restoreError = StateError('unexpected');
    final result = await RestoreData(r)();
    expect(result, isA<Err<void>>());
    expect((result as Err<void>).error, isA<SyncException>());
  });

  test('EncryptionException flows through as Err', () async {
    final r = _FakeRunner()
      ..restoreError = const EncryptionException('wrong passphrase');
    final result = await RestoreData(r)();
    expect(result, isA<Err<void>>());
    expect((result as Err<void>).error, isA<EncryptionException>());
  });
}
