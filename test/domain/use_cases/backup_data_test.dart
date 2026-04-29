// Copyright (C) 2024 Paolo Santucci
//
// This file is part of Métra.
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/errors/metra_exception.dart';
import 'package:metra/core/utils/result.dart';
import 'package:metra/domain/use_cases/backup_data.dart';

class _FakeRunner implements BackupRunner {
  Object? backupError;
  bool backupCalled = false;

  @override
  Future<void> backup() async {
    backupCalled = true;
    if (backupError != null) throw backupError!;
  }

  @override
  Future<void> restore() async {}
}

void main() {
  test('returns Ok(null) on success', () async {
    final r = _FakeRunner();
    final result = await BackupData(r)();
    expect(result, isA<Ok<void>>());
    expect(r.backupCalled, isTrue);
  });

  test('returns Err on MetraException', () async {
    final r = _FakeRunner()..backupError = const SyncException('x');
    final result = await BackupData(r)();
    expect(result, isA<Err<void>>());
    expect((result as Err<void>).error, isA<SyncException>());
  });

  test('wraps unknown error in SyncException Err', () async {
    final r = _FakeRunner()..backupError = StateError('unexpected');
    final result = await BackupData(r)();
    expect(result, isA<Err<void>>());
    expect((result as Err<void>).error, isA<SyncException>());
  });
}
