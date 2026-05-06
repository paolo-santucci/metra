// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
//
// Métra is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Métra is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Métra. If not, see <https://www.gnu.org/licenses/>.

// Integration tests for tools/add_license_header.sh and
// tools/check_license_headers.sh.
//
// Design notes:
// - Both scripts begin with `cd "$(dirname "$0")/.."` which anchors their
//   effective CWD to the parent of the directory containing the script.
//   For tests that target the REAL scripts (T1–T11), the anchor resolves to
//   the repo root, so constants sourcing always works.  Individual .dart files
//   are passed as CLI arguments — bypassing `find lib test` entirely.
// - Tests that must isolate the checker from the real repo (T12–T14) copy the
//   scripts + constants file into a temp tree, so the anchor resolves to the
//   temp root.
// - SHA / byte equality uses File.readAsBytesSync() — no extra packages needed.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Constants & helpers
// ---------------------------------------------------------------------------

/// Canonical first line that the stamper prepends.
const _requiredLine = '// Copyright (C) 2026  Paolo Santucci';

/// Path to the repo root (flutter test runs from repo root by convention).
final _repoRoot = Directory.current.path;

/// Absolute path to add_license_header.sh.
final _stamper = '$_repoRoot/tools/add_license_header.sh';

/// Absolute path to check_license_headers.sh.
final _checker = '$_repoRoot/tools/check_license_headers.sh';

/// Runs the stamper script with [args] via bash.
/// [workingDirectory] defaults to [_repoRoot].
Future<ProcessResult> _runStamper(
  List<String> args, {
  String? workingDirectory,
  Map<String, String>? environment,
}) {
  return Process.run(
    'bash',
    [_stamper, ...args],
    workingDirectory: workingDirectory ?? _repoRoot,
    environment: environment,
  );
}

/// Runs the checker script via bash from [workingDirectory].
/// [scriptPath] defaults to [_checker]; override to test copies.
Future<ProcessResult> _runChecker({
  String? scriptPath,
  String? workingDirectory,
}) {
  return Process.run(
    'bash',
    [scriptPath ?? _checker],
    workingDirectory: workingDirectory ?? _repoRoot,
  );
}

/// Returns the bytes of [filePath] for byte-equality comparison.
List<int> _bytes(String filePath) => File(filePath).readAsBytesSync();

/// Copies the real tools/ directory into [tempRoot]/tools/.
void _copyTools(Directory tempRoot) {
  Directory('${tempRoot.path}/tools').createSync();
  for (final name in [
    'add_license_header.sh',
    'check_license_headers.sh',
    'license_header_constants.sh',
  ]) {
    File('$_repoRoot/tools/$name').copySync('${tempRoot.path}/tools/$name');
  }
}

/// Writes a file with content built from [linesBefore] non-matching lines,
/// then [requiredLine] (the REQUIRED_LINE) at position [linesBefore + 1].
void _writeFileWithRequiredLineAt(
  String filePath,
  int linesBefore, {
  String lineContent = '// placeholder line',
}) {
  final buf = StringBuffer();
  for (var i = 0; i < linesBefore; i++) {
    buf.writeln(lineContent);
  }
  buf.writeln(_requiredLine);
  buf.writeln('// additional body');
  File(filePath).writeAsStringSync(buf.toString());
}

// ---------------------------------------------------------------------------
// Test suite
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // add_license_header.sh tests (T1–T11)
  // -------------------------------------------------------------------------
  group('add_license_header.sh', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('metra_stamp_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    // T1: outdated copyright → first line becomes REQUIRED_LINE.
    test(
      'T1: outdated copyright is replaced with canonical first line',
      () async {
        final file = File('${tempDir.path}/outdated.dart');
        file.writeAsStringSync('// Copyright 2024 Acme Corp\nvoid main() {}\n');

        final result = await _runStamper([file.path]);

        expect(result.exitCode, equals(0), reason: 'stamper must exit 0');
        final lines = file.readAsLinesSync();
        expect(
          lines.first,
          equals(_requiredLine),
          reason: 'first line must be REQUIRED_LINE after stamping',
        );
      },
    );

    // T2: already-correct file → SHA unchanged (idempotency).
    test(
      'T2: already-stamped file is not modified (idempotency)',
      () async {
        final file = File('${tempDir.path}/correct.dart');
        file.writeAsStringSync('$_requiredLine\nvoid main() {}\n');
        final before = _bytes(file.path);

        final result = await _runStamper([file.path]);

        expect(result.exitCode, equals(0));
        expect(
          _bytes(file.path),
          equals(before),
          reason: 'file must be byte-identical',
        );
      },
    );

    // T3: database.g.dart → untouched (generated file exclusion).
    test(
      'T3: database.g.dart is skipped (generated file)',
      () async {
        final file = File('${tempDir.path}/database.g.dart');
        file.writeAsStringSync('// GENERATED CODE - DO NOT MODIFY\n');
        final before = _bytes(file.path);

        final result = await _runStamper([file.path]);

        expect(result.exitCode, equals(0));
        expect(
          _bytes(file.path),
          equals(before),
          reason: '*.g.dart must be untouched',
        );
      },
    );

    // T4: app_localizations_en.dart → untouched (l10n exclusion).
    test(
      'T4: app_localizations_en.dart is skipped (l10n generated file)',
      () async {
        final file = File('${tempDir.path}/app_localizations_en.dart');
        file.writeAsStringSync(
          '// ignore: unused_import\nimport \'package:intl/intl.dart\';\n',
        );
        final before = _bytes(file.path);

        final result = await _runStamper([file.path]);

        expect(result.exitCode, equals(0));
        expect(
          _bytes(file.path),
          equals(before),
          reason: 'l10n file must be untouched',
        );
      },
    );

    // T5: mixed dir — foo.dart stamped, bar.g.dart + app_localizations.dart untouched.
    test(
      'T5: mixed directory — hand-written stamped, generated files untouched',
      () async {
        final hand = File('${tempDir.path}/foo.dart');
        hand.writeAsStringSync('void foo() {}\n');

        final generated = File('${tempDir.path}/bar.g.dart');
        generated.writeAsStringSync('// GENERATED\n');
        final generatedBefore = _bytes(generated.path);

        final l10n = File('${tempDir.path}/app_localizations.dart');
        l10n.writeAsStringSync('// l10n glue\n');
        final l10nBefore = _bytes(l10n.path);

        final result =
            await _runStamper([hand.path, generated.path, l10n.path]);

        expect(result.exitCode, equals(0));
        // hand-written file stamped
        expect(
          hand.readAsLinesSync().first,
          equals(_requiredLine),
          reason: 'foo.dart must be stamped',
        );
        // generated files untouched
        expect(_bytes(generated.path), equals(generatedBefore));
        expect(_bytes(l10n.path), equals(l10nBefore));
      },
    );

    // T6: empty .dart file → receives header (not a crash).
    test(
      'T6: empty .dart file receives header without crashing',
      () async {
        final file = File('${tempDir.path}/empty.dart');
        file.writeAsStringSync('');

        final result = await _runStamper([file.path]);

        expect(result.exitCode, equals(0));
        expect(
          file.readAsLinesSync().first,
          equals(_requiredLine),
          reason: 'empty file must receive header',
        );
      },
    );

    // T7: REQUIRED_LINE on line 20 → not re-stamped (EC-09 lower boundary).
    // Detection: head -n 20 | grep -qF REQUIRED_LINE → found on line 20 → skip.
    test(
      'T7: REQUIRED_LINE on line 20 → not re-stamped (boundary: within window)',
      () async {
        final file = File('${tempDir.path}/boundary_20.dart');
        // 19 non-matching lines, then REQUIRED_LINE on line 20.
        _writeFileWithRequiredLineAt(file.path, 19);
        final before = _bytes(file.path);

        final result = await _runStamper([file.path]);

        expect(result.exitCode, equals(0));
        expect(
          _bytes(file.path),
          equals(before),
          reason: 'REQUIRED_LINE on line 20 must not trigger re-stamp',
        );
      },
    );

    // T8: REQUIRED_LINE on line 21 → re-stamped (EC-09 upper boundary).
    // Detection: head -n 20 sees lines 1-20, none matching → stamp is prepended.
    test(
      'T8: REQUIRED_LINE on line 21 → re-stamped (boundary: outside window)',
      () async {
        final file = File('${tempDir.path}/boundary_21.dart');
        // 20 non-matching lines, then REQUIRED_LINE on line 21.
        _writeFileWithRequiredLineAt(file.path, 20);
        final before = _bytes(file.path);

        final result = await _runStamper([file.path]);

        expect(result.exitCode, equals(0));
        expect(
          _bytes(file.path),
          isNot(equals(before)),
          reason: 'REQUIRED_LINE on line 21 must trigger re-stamp',
        );
        expect(
          file.readAsLinesSync().first,
          equals(_requiredLine),
          reason: 'first line after re-stamp must be REQUIRED_LINE',
        );
      },
    );

    // T9: temp file cleaned up after normal exit.
    // Strategy: override $TMPDIR to a scratch dir so mktemp creates files there;
    // after exit, assert the scratch dir contains no files.
    test(
      'T9: temp file is cleaned up after normal exit',
      () async {
        final scratchDir =
            Directory.systemTemp.createTempSync('metra_scratch_');
        addTearDown(() {
          if (scratchDir.existsSync()) scratchDir.deleteSync(recursive: true);
        });

        final file = File('${tempDir.path}/cleanup_test.dart');
        file.writeAsStringSync('void main() {}\n');

        final result = await _runStamper(
          [file.path],
          environment: {
            ...Platform.environment,
            'TMPDIR': scratchDir.path,
          },
        );

        expect(result.exitCode, equals(0));
        final leftovers = scratchDir.listSync();
        expect(
          leftovers,
          isEmpty,
          reason: 'trap EXIT must remove the temp file; found: '
              '${leftovers.map((e) => e.path).join(', ')}',
        );
      },
    );

    // T10: missing license_header_constants.sh → non-zero exit, file unmodified.
    // Strategy: copy only the stamper to <tempDir>/tools/; no constants file.
    // dirname("$0")/.. = tempDir, so `source "tools/license_header_constants.sh"` fails.
    test(
      'T10: missing constants file → non-zero exit, input file unmodified',
      () async {
        // Build an isolated tree without license_header_constants.sh.
        final isolatedTools = Directory('${tempDir.path}/tools')..createSync();
        File(_stamper).copySync('${isolatedTools.path}/add_license_header.sh');
        // Deliberately NOT copying license_header_constants.sh.

        final targetFile = File('${tempDir.path}/target.dart');
        targetFile.writeAsStringSync('void target() {}\n');
        final before = _bytes(targetFile.path);

        final result = await Process.run(
          'bash',
          ['${isolatedTools.path}/add_license_header.sh', targetFile.path],
          workingDirectory: tempDir.path,
        );

        expect(
          result.exitCode,
          isNot(equals(0)),
          reason: 'missing constants must cause non-zero exit',
        );
        expect(
          _bytes(targetFile.path),
          equals(before),
          reason: 'file must be byte-identical when script aborts',
        );
      },
    );

    // T11: two concurrent disjoint runs → both succeed, no temp collision.
    test(
      'T11: two concurrent runs on disjoint files both succeed (no temp collision)',
      () async {
        final dir1 = Directory.systemTemp.createTempSync('metra_concurrent_1_');
        final dir2 = Directory.systemTemp.createTempSync('metra_concurrent_2_');
        addTearDown(() {
          if (dir1.existsSync()) dir1.deleteSync(recursive: true);
          if (dir2.existsSync()) dir2.deleteSync(recursive: true);
        });

        final file1 = File('${dir1.path}/a.dart');
        file1.writeAsStringSync('void a() {}\n');

        final file2 = File('${dir2.path}/b.dart');
        file2.writeAsStringSync('void b() {}\n');

        final results = await Future.wait([
          _runStamper([file1.path]),
          _runStamper([file2.path]),
        ]);

        expect(results[0].exitCode, equals(0), reason: 'run 1 must succeed');
        expect(results[1].exitCode, equals(0), reason: 'run 2 must succeed');
        expect(
          file1.readAsLinesSync().first,
          equals(_requiredLine),
          reason: 'file1 must be stamped',
        );
        expect(
          file2.readAsLinesSync().first,
          equals(_requiredLine),
          reason: 'file2 must be stamped',
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // check_license_headers.sh tests (T12–T14)
  //
  // These tests copy the scripts into an isolated temp tree so the checker's
  // `find lib test` anchors to that tree, not the real repo.
  // -------------------------------------------------------------------------
  group('check_license_headers.sh', () {
    // T12: CWD-independence — running the REAL checker from different CWDs
    // produces byte-identical stdout and the same exit code.
    // The checker anchors to repo root via `cd "$(dirname "$0")/.."`, so
    // stdout/exit must be identical regardless of caller CWD.
    test(
      'T12: CWD-independence — identical output from repo root, tools/, and /tmp',
      () async {
        final fromRoot = await _runChecker(workingDirectory: _repoRoot);
        final fromTools =
            await _runChecker(workingDirectory: '$_repoRoot/tools');
        final fromTmp = await _runChecker(workingDirectory: '/tmp');

        expect(
          fromTools.exitCode,
          equals(fromRoot.exitCode),
          reason: 'exit code must match from tools/ vs root',
        );
        expect(
          fromTmp.exitCode,
          equals(fromRoot.exitCode),
          reason: 'exit code must match from /tmp vs root',
        );
        expect(
          fromTools.stdout,
          equals(fromRoot.stdout),
          reason: 'stdout must be identical from tools/ vs root',
        );
        expect(
          fromTmp.stdout,
          equals(fromRoot.stdout),
          reason: 'stdout must be identical from /tmp vs root',
        );
      },
    );

    // T13: app_localizations_en.dart excluded from all CWDs (no false positive).
    // Runs the real checker; app_localizations_en.dart has no license header
    // but must NOT appear in stdout as "MISSING".
    test(
      'T13: app_localizations_en.dart never reported as missing (excluded)',
      () async {
        final fromRoot = await _runChecker(workingDirectory: _repoRoot);
        final fromTools =
            await _runChecker(workingDirectory: '$_repoRoot/tools');
        final fromTmp = await _runChecker(workingDirectory: '/tmp');

        for (final result in [fromRoot, fromTools, fromTmp]) {
          expect(
            result.stdout as String,
            isNot(contains('app_localizations_en.dart')),
            reason: 'app_localizations_en.dart must not appear as MISSING',
          );
        }
      },
    );

    // T14: hand-written .dart file under a temp lib/ dir missing header →
    // reported in output, exit 1.
    // Strategy: build an isolated tree in temp with copied scripts and a
    // lib/missing.dart that has no license header.
    test(
      'T14: hand-written file missing header is reported and causes exit 1',
      () async {
        final tempRoot =
            Directory.systemTemp.createTempSync('metra_checker_test_');
        addTearDown(() {
          if (tempRoot.existsSync()) tempRoot.deleteSync(recursive: true);
        });

        _copyTools(tempRoot);

        // Create lib/missing.dart without a license header.
        final libDir = Directory('${tempRoot.path}/lib')..createSync();
        File('${libDir.path}/missing.dart')
            .writeAsStringSync('void missing() {}\n');

        // Create an empty test/ dir so the checker's `find lib test` doesn't fail.
        Directory('${tempRoot.path}/test').createSync();

        final isolatedCheckerPath =
            '${tempRoot.path}/tools/check_license_headers.sh';
        final result = await _runChecker(scriptPath: isolatedCheckerPath);

        expect(
          result.exitCode,
          equals(1),
          reason: 'checker must exit 1 when a file is missing the header',
        );
        expect(
          result.stdout as String,
          contains('missing.dart'),
          reason: 'missing file must be named in output',
        );
      },
    );
  });
}
