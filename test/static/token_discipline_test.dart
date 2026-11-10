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
// TASK-19 (`sp-20261109-timeline-filter-symptoms-note-search` plan) extends the
// scan set with the sprint's surface — `lib/features/timeline/` plus the two
// core widgets the sprint extended (`text_field_metra.dart`,
// `choice_chip_metra.dart`) — and adds the NFR-08 value checks: no hex colour
// literals, no `.withOpacity(`, no bare `fontFamily:` string, and no
// *uncatalogued* font size / border radius literal (0 new visual values).
//
// The guard is proven meaningful by the "detection self-check" group: the very
// same scan helpers are pointed at a deliberately-violating fixture written to a
// temp directory (hex literal + `.withOpacity(` + bare `fontFamily` + an
// uncatalogued font size and radius) and must report every one of them, plus a
// negative control proving a fully tokenized fixture passes.
//
// Scope: this file only. A violation reported for a lib file is handed to the
// owning agent (flutter-frontend-engineer) — this task must not edit lib/**.
//
// Test platforms: all (Linux CI — no device required; dart:io file access only).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Package root resolution
// ---------------------------------------------------------------------------

/// The package root, resolved lazily so the guard works from any cwd.
final Directory _projectRoot = _locateProjectRoot();

/// Walks up from the process cwd (and from the running test script) until the
/// directory holding both `pubspec.yaml` and `lib/` is found.
Directory _locateProjectRoot() {
  final starts = <Directory>[
    Directory.current,
    ..._scriptAncestors(),
  ];
  for (final start in starts) {
    var dir = start.absolute;
    for (var depth = 0; depth < 12; depth++) {
      final hasPubspec = File('${dir.path}/pubspec.yaml').existsSync();
      final hasLib = Directory('${dir.path}/lib').existsSync();
      if (hasPubspec && hasLib) return dir;
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
  }
  throw StateError(
    'token_discipline_test: unable to locate the Métra package root from '
    '${Directory.current.path} or from the running test script. Run the guard '
    'from the package root (flutter test test/static/).',
  );
}

/// Directories above the running test script, nearest first.
List<Directory> _scriptAncestors() {
  final dirs = <Directory>[];
  final script = Platform.script;
  if (!script.hasScheme) return dirs;
  var dir = File(script.toFilePath()).parent;
  for (var depth = 0; depth < 12; depth++) {
    dirs.add(dir);
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return dirs;
}

/// Resolves a scan target against the package root. Absolute paths (temp
/// fixtures) are used verbatim so the same helpers cover the self-check.
String _resolveTargetPath(String target) {
  if (Uri.file(target).hasScheme) return target;
  return '${_projectRoot.path}/$target';
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Every `.dart` file reachable from [targets] (directories are walked
/// recursively; individual files are taken as-is), in a stable order so failure
/// messages are reproducible.
List<File> _dartFilesUnder(List<String> targets) {
  final files = <File>[];
  for (final target in targets) {
    final path = _resolveTargetPath(target);
    final type = FileSystemEntity.typeSync(path);
    if (type == FileSystemEntityType.directory) {
      for (final entity in Directory(path).listSync(recursive: true)) {
        if (entity is! File) continue;
        if (!entity.path.endsWith('.dart')) continue;
        files.add(entity);
      }
    } else if (type == FileSystemEntityType.file && path.endsWith('.dart')) {
      files.add(File(path));
    }
  }
  files.sort((a, b) => a.path.compareTo(b.path));
  return files;
}

/// Returns every line (with its path and 1-based number) that matches [pattern]
/// inside all `.dart` files found under each [targets] path.
List<String> _grepDartFiles(List<String> targets, RegExp pattern) {
  final hits = <String>[];
  for (final file in _dartFilesUnder(targets)) {
    final lines = file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      if (pattern.hasMatch(lines[i])) {
        hits.add('${file.path}:${i + 1}: ${lines[i]}');
      }
    }
  }
  return hits;
}

/// One numeric literal captured from a source line.
typedef _NumericLiteral = ({String location, num value});

/// Returns every numeric literal captured by group 1 of [pattern] across the
/// `.dart` files under [targets].
List<_NumericLiteral> _grepNumericLiterals(
  List<String> targets,
  RegExp pattern,
) {
  final hits = <_NumericLiteral>[];
  for (final file in _dartFilesUnder(targets)) {
    final lines = file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      for (final match in pattern.allMatches(lines[i])) {
        final literal = match.group(1);
        if (literal == null) continue;
        final value = num.tryParse(literal);
        if (value == null) continue;
        final location = '${file.path}:${i + 1}: ${lines[i].trim()}';
        hits.add((location: location, value: value));
      }
    }
  }
  return hits;
}

/// Filters [hits] down to the literals missing from [catalogue].
List<_NumericLiteral> _uncatalogued(
  List<_NumericLiteral> hits,
  Set<num> catalogue,
) {
  return hits.where((hit) => !catalogue.contains(hit.value)).toList();
}

/// Renders [hits] for an `expect` failure message.
String _describe(List<_NumericLiteral> hits) =>
    hits.map((hit) => hit.location).join('\n');

/// `fontSize: 13` and `fontSize: 12.5` — the numeric literal is group 1.
final RegExp _fontSizeLiteral = RegExp(r'fontSize:\s*([0-9]+(?:\.[0-9]+)?)');

/// `Radius.circular(14)`, `BorderRadius.circular(14)` (the former is a substring
/// of the latter, so one pattern covers both). Symbolic radii
/// (`BorderRadius.circular(MetraRadius.md)`) are correctly ignored.
final RegExp _radiusLiteral =
    RegExp(r'Radius\.circular\(\s*([0-9]+(?:\.[0-9]+)?)');

/// Reads the `static const double` values declared inside [className] in the
/// token file at [relativePath], so the catalogues below stay in sync with the
/// theme instead of silently drifting.
Set<num> _tokenConstants(String relativePath, String className) {
  final values = <num>{};
  var inside = false;
  for (final line in File(_resolveTargetPath(relativePath)).readAsLinesSync()) {
    if (line.contains('class $className')) {
      inside = true;
      continue;
    }
    if (!inside) continue;
    if (RegExp(r'class\s+\w+').hasMatch(line)) break;
    final match = RegExp(
      r'static const double \w+\s*=\s*([0-9.]+);',
    ).firstMatch(line);
    if (match == null) continue;
    final value = num.tryParse(match.group(1)!);
    if (value != null) values.add(value);
  }
  return values;
}

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

/// The two source directories covered by NFR-01, NFR-02, and FR-29.
const _backupAndSettings = [
  'lib/features/backup',
  'lib/core/widgets/settings',
];

/// Scan set added by TASK-19 (NFR-08): the timeline-filter / symptom /
/// note-search sprint surface — the feature's source plus the two core widgets
/// the sprint extended.
const List<String> _timelineFilterSurface = <String>[
  'lib/features/timeline',
  'lib/core/widgets/text_field_metra.dart',
  'lib/core/widgets/choice_chip_metra.dart',
];

/// Font sizes catalogued by the design bible §1.2 (typography) and expressed as
/// `MetraTypography` constants. 14 is catalogued in §1.2 (archive timeline card
/// / archive-table cells, bible lines 227 and 846–848) but has no dedicated
/// `MetraTypography` style — the shipped archive widgets use it as a literal.
const Set<num> _cataloguedFontSizes = <num>{
  10,
  11,
  12,
  13,
  14,
  15,
  16,
  17,
  18,
  20,
  22,
  26,
  28,
  30,
  32,
  34,
  40,
  48,
  56,
};

/// Border radii catalogued as `MetraRadius` (design bible §1.2 radius table).
const Set<num> _cataloguedRadii = <num>{6, 8, 10, 12, 14, 16, 18, 20, 24, 44};

/// The two token files the catalogues above mirror.
const String _typographyPath = 'lib/core/theme/metra_typography.dart';
const String _spacingPath = 'lib/core/theme/metra_spacing.dart';

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

  // ---------------------------------------------------------------------------
  // TASK-19 / NFR-08: token discipline on the timeline filter surface
  // ---------------------------------------------------------------------------

  group(
      'NFR-08 token discipline — lib/features/timeline/ + extended core widgets',
      () {
    test(
      'should_scan_every_declared_target_when_the_scan_set_resolves',
      () {
        // A scan set that silently resolves to nothing would make every check
        // below vacuous. Pin the resolved file set instead.
        final files = _dartFilesUnder(_timelineFilterSurface)
            .map((file) => file.path.replaceFirst('${_projectRoot.path}/', ''))
            .toList();

        for (final target in _timelineFilterSurface) {
          final type = FileSystemEntity.typeSync(_resolveTargetPath(target));
          expect(
            type,
            isNot(FileSystemEntityType.notFound),
            reason: 'Scan target "$target" does not exist — the NFR-08 guard '
                'would silently stop covering it.',
          );
        }

        expect(
          files,
          containsAll(<String>[
            'lib/features/timeline/timeline_screen.dart',
            'lib/core/widgets/text_field_metra.dart',
            'lib/core/widgets/choice_chip_metra.dart',
          ]),
          reason: 'The extended scan set must cover the screen and both '
              'extended core widgets. Resolved:\n${files.join('\n')}',
        );
        // The feature directory is walked recursively, so the widget/state
        // subdirectories are covered too.
        expect(
          files
              .where((path) => path.startsWith('lib/features/timeline/'))
              .length,
          greaterThanOrEqualTo(4),
          reason: 'lib/features/timeline/ must be walked recursively.\n'
              'Resolved:\n${files.join('\n')}',
        );
      },
    );

    test(
      'should_find_no_hex_colour_literal_when_scanning_the_timeline_filter_surface',
      () {
        final hits = _grepDartFiles(
          _timelineFilterSurface,
          RegExp(r'Color\(0x'),
        );
        expect(
          hits,
          isEmpty,
          reason: 'Hardcoded Color(0x…) hex literals found in the timeline '
              'filter surface (NFR-08: 0 new hex literals).\n'
              'Use MetraColors.of(context).<token> or a withValues/withAlpha '
              'stop of a token.\n'
              'Hits:\n${hits.join('\n')}',
        );
      },
    );

    test(
      'should_find_no_with_opacity_call_when_scanning_the_timeline_filter_surface',
      () {
        final hits = _grepDartFiles(
          _timelineFilterSurface,
          RegExp(r'\.withOpacity\('),
        );
        expect(
          hits,
          isEmpty,
          reason: '.withOpacity( calls found in the timeline filter surface '
              '(NFR-08: 0 new alpha stops).\n'
              'Replace with .withValues(alpha: <catalogued stop>) or '
              '.withAlpha(0xNN).\n'
              'Hits:\n${hits.join('\n')}',
        );
      },
    );

    test(
      'should_find_no_bare_font_family_when_scanning_the_timeline_filter_surface',
      () {
        final hits = _grepDartFiles(
          _timelineFilterSurface,
          RegExp(r"""fontFamily:\s*['"]"""),
        );
        expect(
          hits,
          isEmpty,
          reason: 'Bare fontFamily: string literals found in the timeline '
              'filter surface.\n'
              'Use MetraTypography.<style> or GoogleFonts.inter(…).\n'
              'Hits:\n${hits.join('\n')}',
        );
      },
    );

    test(
      'should_use_only_catalogued_font_sizes_when_scanning_the_timeline_filter_surface',
      () {
        final hits = _grepNumericLiterals(
          _timelineFilterSurface,
          _fontSizeLiteral,
        );
        final uncatalogued = _uncatalogued(hits, _cataloguedFontSizes);
        expect(
          uncatalogued,
          isEmpty,
          reason: 'Uncatalogued font size literal(s) in the timeline filter '
              'surface (NFR-08: 0 new font sizes).\n'
              'Catalogued sizes: ${(_cataloguedFontSizes.toList()..sort()).join(', ')}\n'
              'Use a MetraTypography style, or a bible §1.2 size.\n'
              'Hits:\n${_describe(uncatalogued)}',
        );
      },
    );

    test(
      'should_use_only_catalogued_radii_when_scanning_the_timeline_filter_surface',
      () {
        final hits = _grepNumericLiterals(
          _timelineFilterSurface,
          _radiusLiteral,
        );
        final uncatalogued = _uncatalogued(hits, _cataloguedRadii);
        expect(
          uncatalogued,
          isEmpty,
          reason: 'Uncatalogued border radius literal(s) in the timeline '
              'filter surface (NFR-08: 0 new radii).\n'
              'Catalogued radii: ${(_cataloguedRadii.toList()..sort()).join(', ')}\n'
              'Use BorderRadius.circular(MetraRadius.<token>).\n'
              'Hits:\n${_describe(uncatalogued)}',
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Catalogue sanity — the catalogues above must not be narrower than the theme
  // ---------------------------------------------------------------------------

  group('catalogue sanity — NFR-08 catalogues track the theme tokens', () {
    test(
      'should_keep_font_size_catalogue_in_sync_when_reading_metra_typography',
      () {
        final themeSizes = _grepNumericLiterals(
          <String>[_typographyPath],
          _fontSizeLiteral,
        ).map((hit) => hit.value).toSet();

        expect(themeSizes, isNotEmpty);
        final missing = themeSizes.difference(_cataloguedFontSizes);
        expect(
          missing,
          isEmpty,
          reason: 'MetraTypography declares font sizes missing from the NFR-08 '
              'catalogue: ${(missing.toList()..sort()).join(', ')}. '
              'Add them to _cataloguedFontSizes (and cite the bible section).',
        );
      },
    );

    test(
      'should_keep_radius_catalogue_in_sync_when_reading_metra_radius',
      () {
        final themeRadii = _tokenConstants(_spacingPath, 'MetraRadius');

        expect(themeRadii, isNotEmpty);
        final missing = themeRadii.difference(_cataloguedRadii);
        expect(
          missing,
          isEmpty,
          reason: 'MetraRadius declares radii missing from the NFR-08 '
              'catalogue: ${(missing.toList()..sort()).join(', ')}. '
              'Add them to _cataloguedRadii (and cite the bible section).',
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Detection self-check — the guard must fail on violations. Runs before any
  // real-tree assertion would be trusted: a guard that cannot fail is worthless.
  // ---------------------------------------------------------------------------

  group('detection self-check — deliberately violating fixtures', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('metra_token_discipline_');
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    File writeFixture(String name, String source) {
      final file = File('${tempDir.path}/$name');
      file.writeAsStringSync(source);
      return file;
    }

    test(
      'should_flag_all_forbidden_patterns_when_scanning_a_violating_fixture',
      () {
        // One fixture, every NFR-08 rule broken: hex literal, .withOpacity(,
        // bare fontFamily, an uncatalogued font size and an uncatalogued radius.
        writeFixture(
          'violating_fixture.dart',
          "import 'package:flutter/material.dart';\n"
              '\n'
              'const TextStyle style = TextStyle(\n'
              "  fontFamily: 'Inter',\n"
              '  fontSize: 99,\n'
              '  color: Color(0xFFC87456),\n'
              ');\n'
              '\n'
              'BorderRadius radius() => BorderRadius.circular(7);\n'
              '\n'
              'Color fade(Color base) => base.withOpacity(0.5);\n',
        );

        final targets = <String>[tempDir.path];

        expect(
          _grepDartFiles(targets, RegExp(r'Color\(0x')),
          hasLength(1),
          reason: 'The hex-literal check must fail on the fixture.',
        );
        expect(
          _grepDartFiles(targets, RegExp(r'\.withOpacity\(')),
          hasLength(1),
          reason: 'The .withOpacity( check must fail on the fixture.',
        );
        expect(
          _grepDartFiles(targets, RegExp(r"""fontFamily:\s*['"]""")),
          hasLength(1),
          reason: 'The bare fontFamily check must fail on the fixture.',
        );

        final sizeHits = _grepNumericLiterals(targets, _fontSizeLiteral);
        expect(sizeHits.map((hit) => hit.value), <num>[99]);
        expect(_uncatalogued(sizeHits, _cataloguedFontSizes), hasLength(1));

        final radiusHits = _grepNumericLiterals(targets, _radiusLiteral);
        expect(radiusHits.map((hit) => hit.value), <num>[7]);
        expect(_uncatalogued(radiusHits, _cataloguedRadii), hasLength(1));

        // Line numbers must stay actionable for the real tree.
        expect(sizeHits.single.location, contains('violating_fixture.dart:5'));
      },
    );

    test(
      'should_report_clean_when_scanning_a_fully_tokenized_fixture',
      () {
        // Negative control: the same helpers must stay silent on canon-only
        // values, otherwise the real-tree green is meaningless.
        writeFixture(
          'clean_fixture.dart',
          "import 'package:flutter/material.dart';\n"
              '\n'
              'const TextStyle style = TextStyle(\n'
              '  fontSize: 13,\n'
              '  color: MetraColors.textPrimary,\n'
              ');\n'
              '\n'
              'BorderRadius radius() => BorderRadius.circular(MetraRadius.md);\n'
              '\n'
              'Color fade(Color base) => base.withValues(alpha: 0.68);\n',
        );

        final targets = <String>[tempDir.path];

        expect(_grepDartFiles(targets, RegExp(r'Color\(0x')), isEmpty);
        expect(_grepDartFiles(targets, RegExp(r'\.withOpacity\(')), isEmpty);
        expect(
          _grepDartFiles(targets, RegExp(r"""fontFamily:\s*['"]""")),
          isEmpty,
        );
        expect(
          _uncatalogued(
            _grepNumericLiterals(targets, _fontSizeLiteral),
            _cataloguedFontSizes,
          ),
          isEmpty,
        );
        expect(
          _uncatalogued(
            _grepNumericLiterals(targets, _radiusLiteral),
            _cataloguedRadii,
          ),
          isEmpty,
        );
      },
    );
  });
}
