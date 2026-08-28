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

// Structural test for the icloud_storage dependency declaration in pubspec.yaml
// (TASK-01, sp-20260625-m3-icloud-provider).
// Asserts:
//   1. An exact-pinned (no caret) `icloud_storage` entry exists with three
//      numeric version segments.
//   2. No caret prefix is present on the entry (FR-10-neg).
//   3. An inline "rule-8" justification comment appears on the same line or
//      within 2 lines of the `icloud_storage` entry (CLAUDE.md §8 rule-8).
//
// These are TEXT-LEVEL assertions on pubspec.yaml, not pub resolution checks.
// The CI-only enforce-lockfile gate (quality.yml) covers resolution (FR-11).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('pubspec.yaml icloud_storage dependency', () {
    late List<String> lines;

    setUpAll(() {
      final file = File('pubspec.yaml');
      expect(
        file.existsSync(),
        isTrue,
        reason: 'pubspec.yaml must exist at the repo root',
      );
      lines = file.readAsLinesSync();
    });

    test(
      'has an exact-pinned icloud_storage entry (three numeric segments, no caret)',
      () {
        // Matches: icloud_storage: 2.2.0  (no leading ^, no trailing .*)
        final exactPin = RegExp(r'^\s*icloud_storage:\s*\d+\.\d+\.\d+\s*');
        final found = lines.any(exactPin.hasMatch);
        expect(
          found,
          isTrue,
          reason:
              'Expected a line matching /^\\s*icloud_storage:\\s*\\d+\\.\\d+\\.\\d+/ '
              'in pubspec.yaml — pin icloud_storage without a caret (TASK-01)',
        );
      },
    );

    test('icloud_storage entry has NO caret prefix', () {
      // Any occurrence of "icloud_storage: ^" would fail.
      final caretPattern = RegExp(r'icloud_storage:\s*\^');
      final caretFound = lines.any(caretPattern.hasMatch);
      expect(
        caretFound,
        isFalse,
        reason: 'icloud_storage must NOT be declared with a caret (^) — '
            'exact pin required per TASK-01 acceptance criteria [FR-10-neg]',
      );
    });

    test(
      'icloud_storage entry has a "rule-8" justification comment within 2 lines',
      () {
        final entryPattern = RegExp(r'^\s*icloud_storage:');
        int? entryLineIndex;
        for (var i = 0; i < lines.length; i++) {
          if (entryPattern.hasMatch(lines[i])) {
            entryLineIndex = i;
            break;
          }
        }

        expect(
          entryLineIndex,
          isNotNull,
          reason: 'icloud_storage entry must be present in pubspec.yaml before '
              'checking for rule-8 comment',
        );

        // Check the entry line itself plus the next 2 lines for "rule-8".
        final windowEnd = (entryLineIndex! + 2).clamp(0, lines.length - 1);
        final window = lines.sublist(entryLineIndex, windowEnd + 1).join('\n');
        expect(
          window.contains('rule-8'),
          isTrue,
          reason:
              'A comment containing "rule-8" must appear on the icloud_storage '
              'line or within 2 lines after it (CLAUDE.md §8 rule-8 compliance)',
        );
      },
    );
  });
}
