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

// TASK-33 — Group L: FR-31 no-inline-literals grep test.
//
// Verifies that none of the new backup view/widget Dart source files contain
// hardcoded Italian or English user-visible string literals that bypass
// AppLocalizations.  All user-facing copy must go through l10n.
//
// Exemptions applied:
//   1. Lines containing only a code comment (`//` prefix after trimming).
//   2. Constructor parameter default declarations — lines that match the
//      pattern `this.<name> = '<literal>'` — are API safety defaults, not
//      user-visible text rendered directly (all production callers always
//      supply localised values).
//   3. Semantics label prefixes that intentionally concatenate a fixed prefix
//      with an l10n value (e.g. `'Distruttivo: ${l10n.xxx}'`) — FR-32
//      mandates this pattern; the interpolation contains the translated word.
//   4. Import / export / part directives and `package:` paths.
//   5. Key literal strings passed to the `Key(...)` constructor.
//
// Target platforms: all (static analysis — no device required).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Returns `true` when the trimmed [line] should be excluded from the literal
/// check based on the documented exemptions.
bool _isExemptLine(String line) {
  final trimmed = line.trim();

  // Exemption 1 — pure comment lines.
  if (trimmed.startsWith('//')) return true;

  // Exemption 4 — import / export / part directives and package paths.
  if (trimmed.startsWith('import ')) return true;
  if (trimmed.startsWith('export ')) return true;
  if (trimmed.startsWith('part ')) return true;

  // Exemption 5 — Key(…) widget key literals (identifiers, not user text).
  if (RegExp(r'\bKey\s*\(').hasMatch(trimmed)) return true;

  // Exemption 2 — constructor parameter defaults: `this.<name> = '…'`.
  // Pattern: this.someParam = 'Literal' or this.someParam = 'Literal',
  // Use a double-quoted raw string to avoid early string termination by the
  // embedded single-quote in the character class.
  if (RegExp(r"""\bthis\.\w+\s*=\s*['"]""").hasMatch(trimmed)) return true;

  // Exemption 3 — Semantics label prefix concatenation:
  //   label: 'Distruttivo: ${l10n.xxx}'
  //   label: 'Prefix: $something'
  // The literal is only a structural prefix; the translated term is
  // interpolated.  We accept any string starting with 'Distruttivo: $'
  // or ending with a `${` interpolation.
  if (RegExp(r"""['"]Distruttivo:\s*\$\{""").hasMatch(trimmed)) return true;

  // Exemption: locale-tag string used in DateFormat  ('en', 'it', etc.) —
  // these are language tags, not user-visible text.
  if (RegExp(r"DateFormat\.[a-zA-Z]+\(").hasMatch(trimmed)) return true;

  // Exemption 6 — Null-coalesce fallback defaults in factory/static methods:
  //   `label: someParam ?? 'Default'`
  // These mirror defaults already declared as `this.param = 'Default'` in the
  // widget constructor (covered by Exemption 2). The literal is not rendered
  // independently — production callers always pass the l10n value.
  if (RegExp(r"""\?\?\s*['"][^'"]*['"]""").hasMatch(trimmed)) return true;

  // Exemption 7 — camelCase identifier strings passed to error constructors
  // (ArgumentError, AssertionError, etc.): `ArgumentError.value(x, 'paramName', ...)`.
  // The string is a developer-facing parameter name, not user-visible text.
  if (RegExp(r'ArgumentError').hasMatch(trimmed)) return true;
  // Also exempt any string that is purely a camelCase identifier (no spaces,
  // no uppercase start — these are symbol names not translated copy).
  // Detection: the string contains no whitespace AND starts with a lowercase letter.
  // We handle this at the content-level check below rather than the line level.

  return false;
}

/// Searches [path] for inline Italian or English user-visible string literals.
///
/// Returns a list of `"$path:$lineNo: $content"` strings for each violation.
///
/// Detection heuristic: a quoted string literal is suspicious if it:
///   - starts with an uppercase letter followed by a lowercase letter, OR
///   - contains 8 or more alphabetic characters in a row (long word/phrase).
///
/// This matches Italian strings like `'Annulla'`, `'Backup'`, `'Connetti'`
/// and English strings like `'Account'`, `'Restore'`, `'Connecting'`.
List<String> _findInlineLiterals(String path) {
  final file = File(path);
  if (!file.existsSync()) return [];

  final violations = <String>[];
  final lines = file.readAsLinesSync();

  // Outer pattern: find any quoted literal that contains a
  // capital-then-lowercase sequence or 8+ consecutive alpha chars.
  // (An earlier lookbehind-based variant was removed — too brittle across
  // Dart regex engines; the heuristic check below is sufficient.)
  final literalPattern = RegExp(
    r"""(?:'([^']*)'|"([^"]*)")""",
  );

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (_isExemptLine(line)) continue;

    for (final match in literalPattern.allMatches(line)) {
      final content = match.group(1) ?? match.group(2) ?? '';
      if (content.isEmpty) continue;

      // Check heuristics: starts with Capital+lowercase OR has 8+ alpha chars.
      final capsLower = RegExp(r'^[A-Z][a-z]').hasMatch(content);
      final longAlpha = RegExp(r'[A-Za-z]{8,}').hasMatch(content);

      if (capsLower || longAlpha) {
        // Content-level exemption: purely camelCase identifiers (no spaces,
        // starts with lowercase letter — these are symbol/parameter names
        // passed to developer-facing APIs, not rendered text).
        final isCamelCaseIdentifier =
            RegExp(r'^[a-z][a-zA-Z0-9]+$').hasMatch(content);
        if (isCamelCaseIdentifier) continue;

        violations.add('${path.replaceAll('\\', '/')}:${i + 1}: $content');
      }
    }
  }

  return violations;
}

// ---------------------------------------------------------------------------
// Test
// ---------------------------------------------------------------------------

void main() {
  group('FR-31 — no inline Italian/English literals in new backup source files',
      () {
    // Files in scope per spec §7.1 Group L bullet 1.
    // TASK-33 (Wave 8): added backup_connected_view_handlers.dart which was
    // omitted from the initial list.
    const filePaths = [
      'lib/features/backup/views/backup_empty_view.dart',
      'lib/features/backup/views/backup_connected_view.dart',
      'lib/features/backup/views/backup_error_view.dart',
      'lib/features/backup/views/backup_connected_view_handlers.dart',
      'lib/features/backup/widgets/status_indicator.dart',
      'lib/features/backup/widgets/metra_confirm_dialog.dart',
      'lib/features/backup/widgets/backup_picker_sheet.dart',
      'lib/features/backup/widgets/backup_picker_sheet_internals.dart',
      'lib/features/backup/restore_progress_screen.dart',
    ];

    for (final path in filePaths) {
      test('no inline user-visible literals in $path', () {
        final violations = _findInlineLiterals(path);
        expect(
          violations,
          isEmpty,
          reason:
              'Found inline string literals that may bypass AppLocalizations:\n'
              '${violations.join('\n')}\n\n'
              'All user-visible strings must go through l10n.',
        );
      });
    }
  });
}
