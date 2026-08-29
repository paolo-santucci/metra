// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/errors/metra_exception.dart';
import 'package:metra/features/backup/state/backup_connect_error.dart';
import 'package:metra/features/backup/state/backup_state.dart';

void main() {
  group('isNoBrowserError', () {
    test(
        'true for PlatformException whose message mentions "No Activity found"',
        () {
      final e = PlatformException(
        code: 'error',
        message:
            'No Activity found to handle Intent { act=android.intent.action.VIEW '
            'dat=https://www.dropbox.com/... flg=0x30000000 (has extras) }',
      );
      expect(isNoBrowserError(e), isTrue);
    });

    test(
        'true for PlatformException whose details mention ActivityNotFoundException',
        () {
      final e = PlatformException(
        code: 'error',
        message: 'something',
        details:
            'android.content.ActivityNotFoundException: No Activity found to '
            'handle Intent { act=android.intent.action.VIEW }',
      );
      expect(isNoBrowserError(e), isTrue);
    });

    test('false for an unrelated PlatformException', () {
      final e = PlatformException(code: 'other', message: 'network down');
      expect(isNoBrowserError(e), isFalse);
    });

    test('false for a non-PlatformException', () {
      expect(isNoBrowserError(const SyncException('auth failed')), isFalse);
      expect(isNoBrowserError(Exception('boom')), isFalse);
    });
  });

  group('backupErrorFromException', () {
    test('no-browser PlatformException → kind noBrowser + browser message', () {
      final e = PlatformException(
        code: 'error',
        message:
            'No Activity found to handle Intent { act=android.intent.action.VIEW }',
      );
      final state = backupErrorFromException(e);
      expect(state.kind, BackupErrorKind.noBrowser);
      expect(state.message, noBrowserMessage);
    });

    test('MetraException → generic kind + exception message', () {
      const e = SyncException('Could not fetch account');
      final state = backupErrorFromException(e);
      expect(state.kind, BackupErrorKind.generic);
      expect(state.message, 'Could not fetch account');
    });

    test('arbitrary Exception → generic kind + fallback message', () {
      final state = backupErrorFromException(Exception('boom'));
      expect(state.kind, BackupErrorKind.generic);
      expect(state.message, 'Something went wrong. Please try again.');
    });
  });
}
