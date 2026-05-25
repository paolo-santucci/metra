// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
// SPDX-License-Identifier: GPL-3.0-or-later
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

// TASK-32 — Group J static grep: _handleRestore mounted-guard coverage
// sp-20260524 T-04 — guard count updated to 5 (C-05: new guard 5 after
//   restoreWithPassphrase await, before messenger.showSnackBar dispatch).
//
// Spec ref: §7.1 Group J (FR-28, EC-08)
//
// Verifies that in backup_connected_view_handlers.dart:
//   (a) handleRestore() contains exactly 5 `if (!mounted) return` guards —
//       one after each of the five async boundaries in the restore flow:
//       1. provider fetch, 2. sheet pop, 3. confirm dialog pop,
//       4. passphrase callback, 5. restoreWithPassphrase (new — C-05).
//   (b) Every `await` expression inside handleRestore() that is followed by
//       a `BuildContext`-consuming symbol (context, Navigator, ScaffoldMessenger,
//       dialog `.show(`) has a preceding `if (!mounted) return` guard within
//       the same flow block.
//
// The "captured pre-await" uses of `context` at the top of handleRestore
// (AppLocalizations.of(context)! and ScaffoldMessenger.of(context)) are
// captured *before* any await and therefore do not need a mounted guard.
//
// Target platforms: all (Linux CI — no device required; dart:io only).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const handlersPath =
      'lib/features/backup/views/backup_connected_view_handlers.dart';

  // ---------------------------------------------------------------------------
  // Helper: extract the body of handleRestore() from the source file.
  // ---------------------------------------------------------------------------

  /// Returns the substring of [source] that constitutes the body of
  /// handleRestore(), delimited by its opening `{` and the matching closing `}`.
  String extractHandleRestoreBody(String source) {
    // Locate "Future<void> handleRestore() async {"
    final startPattern = RegExp(r'Future<void> handleRestore\(\) async \{');
    final match = startPattern.firstMatch(source);
    if (match == null) {
      throw TestFailure(
        'handleRestore() not found in $handlersPath',
      );
    }
    // Walk the source from the opening brace, counting brace depth.
    int depth = 0;
    final int start = match.end - 1; // position of the opening '{'
    int end = start;
    for (int i = start; i < source.length; i++) {
      if (source[i] == '{') {
        depth++;
      } else if (source[i] == '}') {
        depth--;
        if (depth == 0) {
          end = i;
          break;
        }
      }
    }
    return source.substring(start, end + 1);
  }

  // ---------------------------------------------------------------------------
  // Test: exactly 4 mounted guards inside handleRestore
  // ---------------------------------------------------------------------------

  test(
    'handleRestore_has_exactly_5_mounted_guards_one_per_async_boundary',
    () {
      final src = File(handlersPath).readAsStringSync();
      final body = extractHandleRestoreBody(src);

      // Count literal occurrences of the canonical guard form.
      const guard = 'if (!mounted) return;';
      final guards = guard.allMatches(body).length;

      expect(
        guards,
        5,
        reason:
            'handleRestore() must contain exactly 5 `if (!mounted) return;` '
            'guards — one after each of the five async boundaries: (1) provider '
            'fetch, (2) sheet pop, (3) confirm dialog pop, (4) passphrase '
            'callback, (5) restoreWithPassphrase (C-05, T-04). '
            'Found: $guards',
      );
    },
  );

  // ---------------------------------------------------------------------------
  // Test: every await in handleRestore followed by a context-consuming
  //       symbol is preceded by a mounted guard in the same flow block.
  // ---------------------------------------------------------------------------
  //
  // Strategy: scan the handleRestore body line-by-line.  Whenever we see a
  // line containing `await `, record the line index.  For each such line,
  // scan forward up to 10 lines looking for the next non-blank, non-comment
  // statement.  If that statement contains a BuildContext-consuming symbol
  // (context, Navigator, ScaffoldMessenger, .show(), showDialog,
  // showModalBottomSheet) but the line immediately after the await does NOT
  // start with `if (!mounted)`, flag it.
  //
  // Exception: the two pre-await captures at the top of handleRestore are
  // `= AppLocalizations.of(context)!` and `= ScaffoldMessenger.of(context)` —
  // both appear before the first await, so they are not flagged by this scan.

  test(
    'no_BuildContext_use_after_await_without_preceding_mounted_guard',
    () {
      final src = File(handlersPath).readAsStringSync();
      final body = extractHandleRestoreBody(src);
      final lines = body.split('\n');

      // Symbols that indicate a BuildContext use (post-await, not pre-await).
      final contextConsumers = RegExp(
        r'(?:(?<![._a-z])context|Navigator\.|ScaffoldMessenger\.|\.show\(|showDialog|showModalBottomSheet)',
      );

      final violations = <String>[];

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        final trimmed = line.trim();
        // Skip comment lines that mention "await" only in passing.
        if (trimmed.startsWith('//')) continue;
        if (!trimmed.contains('await ')) continue;

        // If the await expression spans multiple lines (ends with `(` or no `;`),
        // walk forward until the call closes, then look at the next statement.
        // This avoids flagging `context,` that is an argument continuation.
        int exprEnd = i;
        if (!trimmed.endsWith(';')) {
          int depth = 0;
          bool foundOpen = false;
          for (int k = i; k < lines.length && k <= i + 15; k++) {
            for (final ch in lines[k].split('')) {
              if (ch == '(') {
                depth++;
                foundOpen = true;
              } else if (ch == ')') {
                depth--;
              }
            }
            if (foundOpen && depth <= 0) {
              exprEnd = k;
              break;
            }
          }
        }

        // Find the first meaningful statement after the complete expression.
        for (int j = exprEnd + 1; j < lines.length && j <= exprEnd + 10; j++) {
          final next = lines[j].trim();
          if (next.isEmpty || next.startsWith('//')) continue;

          if (contextConsumers.hasMatch(next)) {
            // A context-consuming statement follows the await expression.
            // It must be guarded — look for a mounted check immediately before it.
            final prevNonBlank = _previousNonBlankLine(lines, j);
            if (!prevNonBlank.contains('if (!mounted) return')) {
              violations.add(
                'Line ${i + 1}: await followed by context use at line '
                '${j + 1} without a preceding mounted guard. '
                'Await line: "$trimmed"  '
                'Context-use line: "$next"',
              );
            }
          }
          break; // only check the first meaningful line after the await
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Every await in handleRestore() that is followed by a '
            'BuildContext-consuming statement must have a preceding '
            '`if (!mounted) return` guard. Violations:\n'
            '${violations.join('\n')}',
      );
    },
  );

  // ---------------------------------------------------------------------------
  // Group: _handleRestore BuildContext after await guard
  //
  // Extends coverage beyond handleRestore() to the full handlers file:
  //   • handleBackup()     — has one if(!mounted) guard before PassphraseDialog.show
  //   • handleDisconnect() — has one if(!mounted) guard before notifier.disconnect
  //   • backup_connected_view.dart view file has no async ops (build only), so
  //     its scan yields zero violations — which is itself an assertion.
  // ---------------------------------------------------------------------------

  test(
    'restoreSuccessToast_appears_before_fifth_mounted_guard_in_handleRestore',
    () {
      final src = File(handlersPath).readAsStringSync();
      final body = extractHandleRestoreBody(src);

      // Locate the success toast via its unique l10n key.
      // IMPORTANT: do NOT use 'messenger.showSnackBar(' — that substring appears
      // twice in handleRestore() (error toast + success toast). 'restoreSuccessToast'
      // is unique to the success branch.
      final toastPos = body.indexOf('restoreSuccessToast');
      expect(
        toastPos,
        isNonNegative,
        reason: 'handleRestore() must dispatch the success toast via '
            'l10n.restoreSuccessToast — substring not found in body.',
      );

      // Locate the 5th 'if (!mounted) return;' guard.
      const guard = 'if (!mounted) return;';
      final matches = guard.allMatches(body).toList();
      expect(
        matches.length,
        5,
        reason: 'handleRestore() must contain exactly 5 mounted guards '
            '(re-asserted here for clarity). Found: ${matches.length}',
      );
      final guard5Pos = matches[4].start;

      expect(
        toastPos,
        lessThan(guard5Pos),
        reason: 'In handleRestore(), the success-toast dispatch '
            '(substring `restoreSuccessToast`) must appear BEFORE the 5th '
            '`if (!mounted) return;` guard. Otherwise the toast is dead code: '
            'in the real app, restore() swaps the view away synchronously and '
            'BackupConnectedView unmounts before restoreWithPassphrase() returns, '
            'so guard 5 always fires and the toast is never shown. '
            'Found: toastPos=$toastPos, guard5Pos=$guard5Pos.',
      );
    },
  );

  group('_handleRestore BuildContext after await guard', () {
    test(
      'no_BuildContext_use_after_await_without_mounted_guard_in_full_handlers_file',
      () {
        // Read both files that contain async handlers.
        final handlersSrc = File(handlersPath).readAsStringSync();
        final viewSrc = File(
          'lib/features/backup/views/backup_connected_view.dart',
        ).readAsStringSync();

        // Symbols that indicate a BuildContext use (post-await).
        final contextConsumers = RegExp(
          r'(?:(?<![._a-z])context|Navigator\.|ScaffoldMessenger\.|\.show\(|showDialog|showModalBottomSheet)',
        );

        // Scan a single source string for unguarded await → context patterns.
        //
        // Strategy:
        //   For each `await ` line, first determine whether it is a multi-line
        //   call (does the trimmed line end with `(` or lack a closing `)`?).
        //   If multi-line, skip ahead until the call expression ends (a line
        //   whose trimmed form ends with `);` or matches the closing paren
        //   pattern). Then look at the first meaningful statement AFTER the
        //   complete await expression for a context-consuming symbol.
        //
        // Returns a list of violation descriptions.
        List<String> findViolations(String src, String label) {
          final lines = src.split('\n');
          final found = <String>[];
          for (int i = 0; i < lines.length; i++) {
            final line = lines[i];
            // Skip comment lines that mention "await" in passing.
            final trimmed = line.trim();
            if (trimmed.startsWith('//')) continue;
            if (!trimmed.contains('await ')) continue;

            // Determine where the await expression ends. If the line ends with
            // an open paren or comma (multi-line call), walk forward until we
            // find the matching close.
            int exprEnd = i;
            if (!trimmed.endsWith(';')) {
              // Walk forward counting paren depth to find end of expression.
              int depth = 0;
              bool foundOpen = false;
              for (int k = i; k < lines.length && k <= i + 20; k++) {
                for (final ch in lines[k].split('')) {
                  if (ch == '(') {
                    depth++;
                    foundOpen = true;
                  } else if (ch == ')') {
                    depth--;
                  }
                }
                if (foundOpen && depth <= 0) {
                  exprEnd = k;
                  break;
                }
              }
            }

            // Now find the first meaningful statement AFTER the expression.
            for (int j = exprEnd + 1;
                j < lines.length && j <= exprEnd + 10;
                j++) {
              final next = lines[j].trim();
              if (next.isEmpty || next.startsWith('//')) continue;
              if (contextConsumers.hasMatch(next)) {
                final prevNonBlank = _previousNonBlankLine(lines, j);
                if (!prevNonBlank.contains('if (!mounted) return')) {
                  found.add(
                    '$label line ${i + 1}: await followed by context use at '
                    'line ${j + 1} without a mounted guard. '
                    'Await: "$trimmed"  '
                    'Context use: "$next"',
                  );
                }
              }
              break;
            }
          }
          return found;
        }

        final handlersViolations = findViolations(handlersSrc, 'handlers');
        final viewViolations = findViolations(viewSrc, 'view');

        final allViolations = [...handlersViolations, ...viewViolations];

        expect(
          allViolations,
          isEmpty,
          reason: 'Every await in backup_connected_view_handlers.dart and '
              'backup_connected_view.dart followed by a BuildContext-consuming '
              'statement must have a preceding `if (!mounted) return` guard. '
              'Violations:\n${allViolations.join('\n')}',
        );
      },
    );
  });
}

/// Returns the last non-blank, non-comment line before [lineIndex] in [lines].
String _previousNonBlankLine(List<String> lines, int lineIndex) {
  for (int k = lineIndex - 1; k >= 0; k--) {
    final t = lines[k].trim();
    if (t.isNotEmpty && !t.startsWith('//')) return t;
  }
  return '';
}
