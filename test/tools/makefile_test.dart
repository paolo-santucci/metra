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

// Tests for the root Makefile `test`, `test-full`, and `help` targets.
// Uses `make -n` (dry-run) to inspect recipe text without executing flutter.
// Copies the real Makefile into a temp directory with minimal pubspec stubs.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Copies the repo root Makefile into [dir].
void _copyMakefile(Directory dir) {
  // flutter test runs with CWD at package root (repo root in this project).
  final src = File('Makefile');
  final dst = File('${dir.path}/Makefile');
  dst.writeAsStringSync(src.readAsStringSync());
}

/// Creates a minimal pubspec.yaml stub in [dir].
void _writePubspecYaml(Directory dir) {
  File('${dir.path}/pubspec.yaml').writeAsStringSync('name: metra_test\n');
}

/// Creates a minimal pubspec.lock stub in [dir].
void _writePubspecLock(Directory dir) {
  File('${dir.path}/pubspec.lock').writeAsStringSync('# lock\n');
}

/// Runs `make` with [args] in [dir] and returns the result.
Future<ProcessResult> _make(Directory dir, List<String> args) {
  return Process.run(
    'make',
    args,
    workingDirectory: dir.path,
    // Capture both stdout and stderr as strings.
    runInShell: false,
  );
}

void main() {
  group('Makefile targets', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('metra_makefile_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    // Test 1 — FR-12 fresh: pubspec.lock mtime >= pubspec.yaml mtime.
    // `make -n test` must NOT contain 'flutter pub get' and MUST contain
    // 'flutter test --no-pub'.
    test(
      'make -n test: fresh lock → no pub get, yes flutter test --no-pub',
      () async {
        _copyMakefile(tempDir);
        _writePubspecYaml(tempDir);
        _writePubspecLock(tempDir);

        // Ensure lock is newer than yaml by setting yaml mtime to the past.
        final yaml = File('${tempDir.path}/pubspec.yaml');
        final lock = File('${tempDir.path}/pubspec.lock');
        final past = DateTime.now().subtract(const Duration(seconds: 5));
        yaml.setLastModifiedSync(past);
        // Lock is already newer (just created).
        expect(
          lock.lastModifiedSync().isAfter(yaml.lastModifiedSync()),
          isTrue,
          reason: 'precondition: lock must be newer than yaml',
        );

        final result = await _make(tempDir, ['-n', 'test']);
        final output = result.stdout as String;

        expect(
          output,
          isNot(contains('flutter pub get')),
          reason: 'fresh lock should not trigger pub get',
        );
        expect(
          output,
          contains('flutter test --no-pub'),
          reason: 'test target must always run flutter test --no-pub',
        );
      },
    );

    // Test 2 — FR-12 stale: pubspec.yaml is newer than pubspec.lock.
    // `make -n test` must contain BOTH 'flutter pub get' AND
    // 'flutter test --no-pub'.
    test(
      'make -n test: stale lock → pub get then flutter test --no-pub',
      () async {
        _copyMakefile(tempDir);
        _writePubspecYaml(tempDir);
        _writePubspecLock(tempDir);

        // Make lock older than yaml.
        final lock = File('${tempDir.path}/pubspec.lock');
        final past = DateTime.now().subtract(const Duration(seconds: 5));
        lock.setLastModifiedSync(past);
        // yaml is already newer (just written after lock was backdated).
        final yaml = File('${tempDir.path}/pubspec.yaml');
        expect(
          yaml.lastModifiedSync().isAfter(lock.lastModifiedSync()),
          isTrue,
          reason: 'precondition: yaml must be newer than lock',
        );

        final result = await _make(tempDir, ['-n', 'test']);
        final output = result.stdout as String;

        expect(
          output,
          contains('flutter pub get'),
          reason: 'stale lock should trigger pub get',
        );
        expect(
          output,
          contains('flutter test --no-pub'),
          reason: 'test target must always run flutter test --no-pub',
        );
      },
    );

    // Test 3 — EC-01 absent lock: pubspec.lock does not exist.
    // `make -n test` must contain BOTH 'flutter pub get' AND
    // 'flutter test --no-pub'.
    test(
      'make -n test: absent lock → pub get then flutter test --no-pub',
      () async {
        _copyMakefile(tempDir);
        _writePubspecYaml(tempDir);
        // Deliberately NOT writing pubspec.lock.

        final result = await _make(tempDir, ['-n', 'test']);
        final output = result.stdout as String;

        expect(
          output,
          contains('flutter pub get'),
          reason: 'absent lock should trigger pub get',
        );
        expect(
          output,
          contains('flutter test --no-pub'),
          reason: 'test target must always run flutter test --no-pub',
        );
      },
    );

    // Test 4 — FR-13: `make -n test-full` always prints both 'flutter pub get'
    // and 'flutter test' (without --no-pub).
    test(
      'make -n test-full: always runs pub get and flutter test (no --no-pub)',
      () async {
        _copyMakefile(tempDir);
        _writePubspecYaml(tempDir);
        _writePubspecLock(tempDir);

        final result = await _make(tempDir, ['-n', 'test-full']);
        final output = result.stdout as String;

        expect(
          output,
          contains('flutter pub get'),
          reason: 'test-full always runs pub get',
        );
        // Must contain 'flutter test' but NOT 'flutter test --no-pub'.
        expect(
          output,
          contains('flutter test'),
          reason: 'test-full must run flutter test',
        );
        expect(
          output,
          isNot(contains('flutter test --no-pub')),
          reason: 'test-full must not pass --no-pub',
        );
      },
    );

    // Test 5 — FR-14 help: `make help` exits 0 and stdout mentions all targets.
    test(
      'make help: exit 0, lists test, test-full, help',
      () async {
        _copyMakefile(tempDir);
        _writePubspecYaml(tempDir);

        final result = await _make(tempDir, ['help']);

        expect(result.exitCode, equals(0), reason: 'make help must exit 0');
        final output = result.stdout as String;
        expect(output, contains('test'), reason: 'help must mention test');
        expect(
          output,
          contains('test-full'),
          reason: 'help must mention test-full',
        );
        expect(output, contains('help'), reason: 'help must mention help');
      },
    );

    // Test 6 — FR-14 default: `make` with no args → same as `make help`.
    test(
      'make (no target): default goal is help, exits 0 and lists targets',
      () async {
        _copyMakefile(tempDir);
        _writePubspecYaml(tempDir);

        final noArgsResult = await _make(tempDir, []);
        final helpResult = await _make(tempDir, ['help']);

        expect(
          noArgsResult.exitCode,
          equals(0),
          reason: 'make with no args must exit 0',
        );
        expect(
          noArgsResult.stdout,
          equals(helpResult.stdout),
          reason: 'make with no args must produce same output as make help',
        );
      },
    );
  });
}
