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

// TASK-11 — NFR-09 / §5.1.C: domain-purity and privacy import guard
//
// Static-analysis-style test (same dart:io file-scan pattern as
// test/static/token_discipline_test.dart) that scans the four domain files
// introduced by the timeline-filter / symptom / note-search sprint and asserts
// they import only `dart:core` / `dart:async` plus domain-internal URIs.
//
// Forbidden: any `package:flutter/…` import, `dart:io`, HTTP clients
// (`package:http`, `package:dio`), Drift (`package:drift`), and any relative
// import that leaves `lib/domain/`. This pins:
//   - §5.1.C layering: UI → Domain → Data, never Domain → Flutter/Data.
//   - NFR-09 privacy: the filter/matcher opens no new IO or network path.
//
// The guard is proven meaningful by the "detection self-check" group: it is
// first pointed at deliberately-violating fixtures written to a temp directory
// and must report them, plus a negative control proving a clean file passes. A
// guard that cannot fail is worthless.
//
// Scope: this file only. If a violation is reported for a lib file, hand the fix
// to flutter-domain-tdd — this task must not modify lib/**.
//
// Test platforms: all (Linux CI — no device required; dart:io file access only).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

/// The four domain files pinned by NFR-09 / §5.1.C, relative to the package
/// root.
const List<String> _pinnedDomainFiles = <String>[
  'lib/domain/services/search_folding.dart',
  'lib/domain/services/cycle_date_range.dart',
  'lib/domain/services/cycle_filter_matcher.dart',
  'lib/domain/use_cases/get_cycle_notes.dart',
];

/// `dart:` libraries a domain file may import explicitly. Everything else
/// (`dart:io`, `dart:ui`, `dart:typed_data`, …) is a purity or privacy break.
const Set<String> _allowedDartLibraries = <String>{'dart:core', 'dart:async'};

/// Same-layer self imports (`package:metra/domain/…`) are purity-neutral and
/// therefore allowed; they are still separate from `lib/domain/`'s preferred
/// relative style, so keep them rare.
const String _selfDomainPackagePrefix = 'package:metra/domain/';

/// Package-relative prefix that relative imports must stay inside.
const String _domainPathPrefix = 'lib/domain/';

/// Human-readable rationale used in failure messages, keyed by URI prefix.
const Map<String, String> _forbiddenHints = <String, String>{
  'package:flutter/': 'Flutter must not reach lib/domain/ (§5.1.C)',
  'package:flutter_test/': 'test-only deps must not reach lib/domain/',
  'dart:io': 'no new IO paths in the domain layer (NFR-09)',
  'dart:ui': 'engine types must not reach lib/domain/ (§5.1.C)',
  'package:http/': 'no network clients in the domain layer (NFR-09)',
  'package:dio/': 'no network clients in the domain layer (NFR-09)',
  'package:web_socket_channel/': 'no network clients (NFR-09)',
  'package:drift/': 'Drift is a data-layer type (UI → Domain → Data)',
  'package:sqlite3/': 'sqlite3 is a data-layer type',
  'package:shared_preferences/': 'persistence belongs to lib/data/',
  'package:url_launcher/': 'platform channels must not reach lib/domain/',
};

/// Matches the first line of an `import` / `export` directive.
final RegExp _directiveStart = RegExp(r'''^\s*(?:import|export)\s+['"]''');

/// Matches a single- or double-quoted string literal and captures its contents.
final RegExp _quotedLiteral = RegExp('''['"]([^'"]*)['"]''');

/// Lazily resolved package root, so the guard works from any working directory.
final Directory _projectRoot = _locateProjectRoot();

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Walks up from the process cwd (and from the running test script) until the
/// directory that holds both `pubspec.yaml` and `lib/domain/` is found.
Directory _locateProjectRoot() {
  final List<Directory> starts = <Directory>[
    Directory.current,
    ..._scriptAncestors(),
  ];
  for (final Directory start in starts) {
    var dir = start.absolute;
    for (var depth = 0; depth < 12; depth++) {
      final hasPubspec = File('${dir.path}/pubspec.yaml').existsSync();
      final hasDomain =
          Directory('${dir.path}/$_domainPathPrefix').existsSync();
      if (hasPubspec && hasDomain) return dir;
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
  }
  throw StateError(
    'domain_purity_test: unable to locate the Métra package root from '
    '${Directory.current.path} or from the running test script. Run the guard '
    'from the package root (flutter test test/static/).',
  );
}

/// Directories above the running test script, nearest first.
List<Directory> _scriptAncestors() {
  final List<Directory> dirs = <Directory>[];
  final Uri script = Platform.script;
  if (script.scheme != 'file') return dirs;
  var dir = File(script.toFilePath()).parent;
  for (var depth = 0; depth < 12; depth++) {
    dirs.add(dir);
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return dirs;
}

/// One import/export directive found in a source file.
typedef _Directive = ({int line, String uri});

/// Returns every `import` / `export` URI in [source] with its 1-based line
/// number. Multi-line directives and trailing `//` comments are handled; string
/// literals that are not part of a directive are ignored.
List<_Directive> _directiveUris(String source) {
  final List<_Directive> directives = <_Directive>[];
  final buffer = StringBuffer();
  var startLine = 0;
  var collecting = false;
  final lines = source.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (!collecting) {
      if (!_directiveStart.hasMatch(line)) continue;
      collecting = true;
      startLine = i + 1;
      buffer.clear();
    }
    final withoutComment = line.split('//').first;
    buffer.write(withoutComment);
    buffer.write(' ');
    if (!withoutComment.contains(';')) continue;
    collecting = false;
    for (final match in _quotedLiteral.allMatches(buffer.toString())) {
      directives.add((line: startLine, uri: match.group(1) ?? ''));
    }
  }
  return directives;
}

/// Resolves [uri], written in the file at package-relative [fromPath], into a
/// package-relative path. Returns null when the URI is not relative or when it
/// escapes the package root.
String? _resolveRelativePath(String fromPath, String uri) {
  if (uri.startsWith('dart:') || uri.startsWith('package:')) return null;
  final segments = fromPath.split('/')..removeLast();
  for (final segment in uri.split('/')) {
    if (segment.isEmpty || segment == '.') continue;
    if (segment == '..') {
      if (segments.isEmpty) return null;
      segments.removeLast();
    } else {
      segments.add(segment);
    }
  }
  return segments.join('/');
}

/// Explains why [uri] was rejected.
String _hintFor(String uri) {
  for (final entry in _forbiddenHints.entries) {
    if (uri.startsWith(entry.key)) return entry.value;
  }
  return 'only dart:core, dart:async and domain-internal imports are allowed';
}

/// Classifies one directive URI for the file at package-relative [fromPath].
/// Returns a violation description, or null when the URI is acceptable inside
/// `lib/domain/`.
String? _uriViolation(String fromPath, String uri) {
  if (uri.isEmpty) return 'empty import URI';
  if (uri.startsWith('dart:')) {
    if (_allowedDartLibraries.contains(uri)) return null;
    return 'forbidden $uri import — ${_hintFor(uri)}';
  }
  if (uri.startsWith('package:')) {
    if (uri.startsWith(_selfDomainPackagePrefix)) return null;
    return 'forbidden $uri import — ${_hintFor(uri)}';
  }
  final resolved = _resolveRelativePath(fromPath, uri);
  if (resolved == null) {
    return 'relative import "$uri" escapes the package root';
  }
  if (!resolved.startsWith(_domainPathPrefix)) {
    return 'relative import "$uri" leaves lib/domain/ (resolves to $resolved)';
  }
  return null;
}

/// Returns one human-readable message per purity violation in [file]. An empty
/// list means the file is import-pure.
///
/// [logicalPath] is the package-relative path used to resolve relative imports.
/// It is always passed explicitly so temp fixtures outside the package tree are
/// scanned with the same rules as real domain files.
List<String> _findViolations(File file, {required String logicalPath}) {
  final path = logicalPath;
  final violations = <String>[];
  for (final directive in _directiveUris(file.readAsStringSync())) {
    final problem = _uriViolation(path, directive.uri);
    if (problem != null) {
      violations.add('$path:${directive.line}: $problem');
    }
  }
  return violations;
}

/// Writes [source] to `<dir>/<name>` and returns the file.
File _writeFixture(Directory dir, String name, String source) {
  final file = File('${dir.path}/$name');
  file.writeAsStringSync(source);
  return file;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // Detection self-check — the guard must fail on violations. Runs first on
  // purpose: evidence that the assertions below are meaningful.
  // -------------------------------------------------------------------------
  group('detection self-check — deliberately violating fixtures', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('metra_domain_purity_');
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test(
      'should_flag_flutter_import_when_fixture_imports_material',
      () {
        final fixture = _writeFixture(
          tempDir,
          'flutter_leak.dart',
          "import 'package:flutter/material.dart';\n\nclass FlutterLeak {}\n",
        );

        final violations = _findViolations(
          fixture,
          logicalPath: 'lib/domain/services/fixture_flutter.dart',
        );

        expect(
          violations,
          hasLength(1),
          reason: 'The guard must fail on a Flutter import; got: $violations',
        );
        expect(violations.single, contains('package:flutter/material.dart'));
        // Line numbers must reflect the import's real position so failures stay
        // actionable: this fixture puts the import on line 1.
        expect(violations.single, contains('fixture_flutter.dart:1'));
      },
    );

    test(
      'should_report_true_line_number_when_import_is_not_on_the_first_line',
      () {
        final fixture = _writeFixture(
          tempDir,
          'flutter_leak_offset.dart',
          "// header\n"
              "\n"
              "import 'package:flutter/widgets.dart';\n",
        );

        final violations = _findViolations(
          fixture,
          logicalPath: 'lib/domain/services/fixture_offset.dart',
        );

        expect(
          violations,
          hasLength(1),
          reason: 'The guard must fail on a Flutter import; got: $violations',
        );
        expect(
          violations.single,
          contains('fixture_offset.dart:3'),
          reason: 'Violation line numbers must match the source position; '
              'got: $violations',
        );
      },
    );

    test(
      'should_flag_every_forbidden_family_when_fixture_imports_io_http_'
      'drift_or_flutter',
      () {
        const forbiddenUris = <String>[
          'dart:io',
          'package:http/http.dart',
          'package:drift/drift.dart',
          'package:flutter/widgets.dart',
          'package:dio/dio.dart',
        ];

        for (var i = 0; i < forbiddenUris.length; i++) {
          final uri = forbiddenUris[i];
          final fixture = _writeFixture(
            tempDir,
            'leak_$i.dart',
            "import '$uri' as dep;\n",
          );

          final violations = _findViolations(
            fixture,
            logicalPath: 'lib/domain/services/fixture_leak_$i.dart',
          );

          expect(
            violations,
            hasLength(1),
            reason: 'The guard must fail on "$uri"; got: $violations',
          );
          expect(violations.single, contains(uri));
          expect(violations.single, contains('forbidden'));
        }
      },
    );

    test(
      'should_flag_relative_escape_when_fixture_reaches_into_data_layer',
      () {
        final fixture = _writeFixture(
          tempDir,
          'escape.dart',
          r'''
import '../../data/repositories/cycle_entry_repository.dart';
''',
        );

        final violations = _findViolations(
          fixture,
          logicalPath: 'lib/domain/services/fixture_escape.dart',
        );

        expect(
          violations,
          hasLength(1),
          reason: 'A relative import leaving lib/domain/ must be flagged; '
              'got: $violations',
        );
        expect(violations.single, contains('leaves lib/domain/'));
        expect(violations.single, contains('lib/data/repositories'));
      },
    );

    test(
      'should_report_clean_when_fixture_uses_only_dart_core_async_and_'
      'domain_imports',
      () {
        // Negative control: proves the scan does not simply report everything.
        final fixture = _writeFixture(
          tempDir,
          'clean.dart',
          r'''
import 'dart:async';
import 'dart:core';

import '../entities/cycle_entry_entity.dart';
import 'cycle_date_range.dart';

// A comment mentioning package:flutter/material.dart must not be flagged.
class CleanDomainFixture {}
''',
        );

        expect(
          _findViolations(
            fixture,
            logicalPath: 'lib/domain/services/fixture_clean.dart',
          ),
          isEmpty,
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // Guard sanity — a silently-empty parser would make the group below a
  // false green, so verify the directive parser sees real imports.
  // -------------------------------------------------------------------------
  group('guard sanity — directive parser', () {
    test(
      'should_parse_known_imports_when_scanning_a_pinned_domain_file',
      () {
        final file = File(
          '${_projectRoot.path}/lib/domain/services/cycle_filter_matcher.dart',
        );
        expect(file.existsSync(), isTrue);

        final uris = _directiveUris(file.readAsStringSync())
            .map((directive) => directive.uri)
            .toList();

        expect(
          uris,
          containsAll(<String>[
            '../entities/cycle_summary.dart',
            '../entities/pain_symptom_data.dart',
            'cycle_date_range.dart',
            'search_folding.dart',
          ]),
          reason: 'The import parser found $uris — a parser that returns '
              'nothing would make the purity guard trivially green.',
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // NFR-09 / §5.1.C — the real tree.
  // -------------------------------------------------------------------------
  group('NFR-09 / §5.1.C — pinned domain files are import-pure', () {
    for (final relativePath in _pinnedDomainFiles) {
      test(
        'should_import_only_domain_abstractions_when_scanning_$relativePath',
        () {
          final file = File('${_projectRoot.path}/$relativePath');
          expect(
            file.existsSync(),
            isTrue,
            reason: '$relativePath is missing — the guard cannot verify a file '
                'that does not exist.',
          );

          // Pass the known package-relative path explicitly: resolving it from
          // the absolute file path would break if the checkout is reached
          // through a symlink.
          final violations = _findViolations(file, logicalPath: relativePath);

          expect(
            violations,
            isEmpty,
            reason: 'Domain-purity violation(s) in $relativePath '
                '(§5.1.C / NFR-09). Hand the fix to flutter-domain-tdd; '
                'never silence the guard.\nViolations:\n'
                '${violations.join('\n')}',
          );
        },
      );
    }
  });
}
