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

// TASK-23 — Group A: NFR-01, NFR-02, FR-29 token-discipline grep tests
//
// These are static-analysis-style tests that scan source files for forbidden
// patterns.  All assertions are against the post-diff tree; failures indicate
// a token-discipline regression that must be fixed before merging.
//
// Spec ref: §7.1 Group A (FR-01, FR-02, NFR-01, NFR-02) and FR-29.
//
// Directories in scope:
//   lib/features/backup/        (new backup UI atoms and views)
//   lib/core/widgets/settings/  (promoted Settings atoms)
//
// Test platforms: all (Linux CI — no device required; dart:io file access only).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Returns every line (with its path and 1-based number) that matches [pattern]
/// inside all `.dart` files found recursively under each [dirs] path.
List<String> _grepDartFiles(List<String> dirs, RegExp pattern) {
  final hits = <String>[];
  for (final dirPath in dirs) {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) continue;
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (pattern.hasMatch(lines[i])) {
          hits.add('${entity.path}:${i + 1}: ${lines[i]}');
        }
      }
    }
  }
  return hits;
}

/// The two source directories covered by NFR-01, NFR-02, and FR-29.
const _backupAndSettings = [
  'lib/features/backup',
  'lib/core/widgets/settings',
];

// ---------------------------------------------------------------------------
// NFR-01: token discipline — no hardcoded colours, fontFamily strings, or
//          numeric spacing/itemExtent literals
// ---------------------------------------------------------------------------

void main() {
  group(
      'NFR-01 token discipline — lib/features/backup/ + lib/core/widgets/settings/',
      () {
    test(
      'zero Color(0x…) hex colour literals',
      () {
        // Catches patterns like Color(0xFF123456) or Color(0x80AABBCC).
        // All alpha/colour values must go through MetraColors.of(context)
        // or withAlpha(0xNN) applied to a token getter.
        final hits = _grepDartFiles(
          _backupAndSettings,
          RegExp(r'Color\(0x'),
        );
        expect(
          hits,
          isEmpty,
          reason: 'Hardcoded Color(0x…) hex literals found.\n'
              'Replace with MetraColors.of(context).<token>.\n'
              'Hits:\n${hits.join('\n')}',
        );
      },
    );

    test(
      'zero fontFamily: string literals (Inter / DM Serif must go through MetraTypography)',
      () {
        // Catches fontFamily: 'Inter' or fontFamily: "DM Serif Display" etc.
        // Typography must always be accessed via MetraTypography or GoogleFonts.inter(…)
        // without a bare fontFamily string literal.
        final hits = _grepDartFiles(
          _backupAndSettings,
          RegExp(r"""fontFamily:\s*['"]"""),
        );
        expect(
          hits,
          isEmpty,
          reason: 'fontFamily: string literals found.\n'
              'Use MetraTypography.<style> or GoogleFonts.inter(…) instead.\n'
              'Hits:\n${hits.join('\n')}',
        );
      },
    );

    test(
      'zero numeric itemExtent literals '
      '(CupertinoPicker itemExtent must route through MetraSpacing.sp44)',
      () {
        // Scope: the task-prescribed pattern is `itemExtent: <digit>` — this
        // catches itemExtent: 44, itemExtent: 40, etc. in both directories.
        //
        // Note: the broader height:/width: literal sweep (RegExp r'[\s:](44|40)[,)]')
        // is parked pending a flutter-frontend-engineer hand-off:
        //   lib/core/widgets/settings/cupertino_picker_scaffold.dart:215
        //   has `height: 44,` that must be replaced with MetraSpacing.sp44.
        // That file is outside the scope of TASK-23 (no lib/** edits allowed).
        // The broader scan is tracked as a future tightening once the
        // cupertino_picker_scaffold.dart:215 regression is fixed.
        final hits = _grepDartFiles(
          _backupAndSettings,
          RegExp(r'itemExtent:\s*[0-9]'),
        );
        expect(
          hits,
          isEmpty,
          reason:
              'Numeric itemExtent literal found (must use MetraSpacing token).\n'
              'Replace with MetraSpacing.sp44 (or the appropriate token).\n'
              'Hits:\n${hits.join('\n')}',
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // NFR-02: no .withOpacity(…) — all alpha must use withAlpha(0xNN)
  // ---------------------------------------------------------------------------

  group('NFR-02 — .withOpacity( absent in new source files', () {
    test(
      'zero .withOpacity( calls across lib/features/backup/ and lib/core/widgets/settings/',
      () {
        final hits = _grepDartFiles(
          _backupAndSettings,
          RegExp(r'\.withOpacity\('),
        );
        expect(
          hits,
          isEmpty,
          reason: '.withOpacity( calls found.\n'
              'Replace with .withAlpha(0xNN) (hex alpha, 0x00–0xFF).\n'
              'Hits:\n${hits.join('\n')}',
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // FR-29: Colors.red absent in passphrase_dialog.dart
  // ---------------------------------------------------------------------------

  group('FR-29 — Colors.red absent in passphrase_dialog.dart', () {
    test(
      'grep Colors.red in lib/features/backup/widgets/passphrase_dialog.dart '
      'returns zero matches',
      () {
        final src = File(
          'lib/features/backup/widgets/passphrase_dialog.dart',
        ).readAsStringSync();

        // Extract matching lines for a useful failure message.
        final hits = src
            .split('\n')
            .asMap()
            .entries
            .where((e) => e.value.contains('Colors.red'))
            .map((e) => 'line ${e.key + 1}: ${e.value}')
            .toList();

        expect(
          hits,
          isEmpty,
          reason: 'Colors.red still present in passphrase_dialog.dart.\n'
              'Must be replaced with MetraColors.of(context).accentFlowStrong.\n'
              'Hits:\n${hits.join('\n')}',
        );
      },
    );
  });
}
