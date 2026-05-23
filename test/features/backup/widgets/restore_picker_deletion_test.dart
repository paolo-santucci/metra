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

// SPDX-License-Identifier: GPL-3.0-or-later

// TASK-22 — Deletion-verification tests for restore_picker_dialog.dart.
//
// These tests enforce that the RestorePickerDialog and its associated test
// files have been fully deleted and that no Dart code in lib/ or test/ still
// imports or references the deleted symbols.  They are written before deletion
// (TDD) and must FAIL when the target files still exist; they pass only after
// the deletion + reference-cleanup in TASK-22 is complete.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TASK-22 deletion verification', () {
    test('restore_picker_dialog.dart deleted', () {
      expect(
        File('lib/features/backup/widgets/restore_picker_dialog.dart')
            .existsSync(),
        isFalse,
        reason: 'restore_picker_dialog.dart must be deleted as part of TASK-22',
      );
    });

    test('backup_fr14_restore_picker_test.dart deleted', () {
      expect(
        File(
          'test/features/backup/widgets/backup_fr14_restore_picker_test.dart',
        ).existsSync(),
        isFalse,
        reason:
            'backup_fr14_restore_picker_test.dart must be deleted as part of TASK-22',
      );
    });

    test('integration backup_fr14_restore_picker_test.dart deleted', () {
      expect(
        File(
          'test/integration/backup_fr14_restore_picker_test.dart',
        ).existsSync(),
        isFalse,
        reason:
            'integration/backup_fr14_restore_picker_test.dart must be deleted as part of TASK-22',
      );
    });

    test('no remaining import of restore_picker_dialog in lib/ or test/', () {
      // Exclude this file itself (its filename appears in the reason: string).
      final result = Process.runSync('grep', [
        '-rl',
        '--include=*.dart',
        '--exclude=restore_picker_deletion_test.dart',
        'restore_picker_dialog',
        'lib/',
        'test/',
      ]);
      expect(
        result.stdout.toString().trim(),
        isEmpty,
        reason:
            'These files still import restore_picker_dialog:\n${result.stdout}',
      );
    });

    test(
        'RestorePickerOutcome and friends not referenced in Dart source '
        'files in lib/ or test/', () {
      // Check .dart files only, excluding generated l10n files
      // (app_localizations*.dart are generated from ARB — cleaned up via
      // flutter gen-l10n after ARB description strings are updated).
      // This file itself is excluded because it contains the symbol names
      // as literal strings inside reason: clauses.
      final result = Process.runSync('grep', [
        '-rEl',
        r'RestorePickerOutcome|RestorePickFilename|RestorePickNewest|RestorePickerDialog',
        '--include=*.dart',
        '--exclude=app_localizations*.dart',
        '--exclude=restore_picker_deletion_test.dart',
        'lib/',
        'test/',
      ]);
      expect(
        result.stdout.toString().trim(),
        isEmpty,
        reason:
            'These Dart files still reference deleted symbols:\n${result.stdout}',
      );
    });
  });
}
