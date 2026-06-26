// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
// SPDX-License-Identifier: GPL-3.0-or-later

// TASK-09 — Source-level constraint guards (§7.1 Group J / §7.2 Group F).
//
// Spec refs: NFR-07, CC-1, CC-3.1, FR-13.
//
// Each test reads the production source file and asserts invariants that
// cannot be detected at runtime but are required by the spec architecture:
//
//   G-01  Single defaultTargetPlatform guard (CC-3.1): no platform-branch
//         equality check outside availableProviders/resolveBackupProvider.
//   G-02  No notifier-level connect/disconnect in switchProvider body (CC-1).
//   G-03  No deleteFile in the switch path (FR-13).
//   G-04  No passphrase key reference in switchProvider body (FR-13/FR-09).
//   G-05  No unauthorized data-layer imports in backup widgets / views (NFR-07).
//
// Pattern mirrors the existing source-grep guard at the end of
// test/providers/backup_providers_test.dart (the `readSourceFile` helper).
//
// Platform matrix: all platforms (pure file-read, no Flutter rendering).
//
// To run locally:
//   LD_LIBRARY_PATH=/tmp/sqlitelib flutter test \
//     test/features/backup/backup_source_guards_test.dart

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Source-file reader (same pattern as backup_providers_test.dart)
// ---------------------------------------------------------------------------

Future<String> _readSource(String relativePath) =>
    File(relativePath).readAsString();

// ---------------------------------------------------------------------------
// Helper: extract a method body from [source] between [methodStart] and
// [nextMethodStart] markers.  Both markers are searched via simple
// [String.indexOf] so they must be unique substrings in the file.
// ---------------------------------------------------------------------------
String _extractBetween(
  String source,
  String methodStart,
  String nextMethodStart,
) {
  final start = source.indexOf(methodStart);
  if (start < 0) return '';
  final end = source.indexOf(nextMethodStart, start + methodStart.length);
  if (end < 0) return source.substring(start);
  return source.substring(start, end);
}

void main() {
  // ── G-01: Single defaultTargetPlatform guard ────────────────────────────
  //
  // CC-3.1 / FR-02: the iOS-only-iCloud rule lives ONCE in
  // availableProviders() and resolveBackupProvider() in backup_providers.dart.
  // View and widget files are allowed to call
  // availableProviders(defaultTargetPlatform) — that single argument-pass is
  // the only legal use.  No file in features/backup/ may contain a second
  // PLATFORM-BRANCH (i.e. `defaultTargetPlatform == TargetPlatform`) that
  // separately decides which provider to show or resolve.

  group('G-01 single defaultTargetPlatform guard (CC-3.1 / FR-02)', () {
    // Files under features/backup/ that are allowed to reference
    // `defaultTargetPlatform` only as an argument (no equality branch).
    final featureBackupDirs = [
      'lib/features/backup/widgets',
      'lib/features/backup/views',
    ];

    test(
      'no equality-check platform branch in features/backup/widgets/ or views/',
      () async {
        // Collect all .dart files under widgets/ and views/.
        final files = <File>[];
        for (final dir in featureBackupDirs) {
          final d = Directory(dir);
          if (d.existsSync()) {
            files.addAll(
              d
                  .listSync(recursive: false)
                  .whereType<File>()
                  .where((f) => f.path.endsWith('.dart')),
            );
          }
        }
        expect(
          files,
          isNotEmpty,
          reason: 'test sanity: at least one .dart file must exist in scope',
        );

        // The equality check pattern that would constitute a second
        // platform-branch for provider filtering.
        const equalityPattern = 'defaultTargetPlatform == TargetPlatform';

        for (final file in files) {
          final source = await file.readAsString();
          expect(
            source,
            isNot(contains(equalityPattern)),
            reason: '${file.path} must NOT contain "$equalityPattern" — '
                'the iOS-only-iCloud rule lives in availableProviders() / '
                'resolveBackupProvider() only (CC-3.1)',
          );
        }
      },
    );

    test(
      'backup_providers.dart contains defaultTargetPlatform exactly inside '
      'availableProviders and resolveBackupProvider (sanity check)',
      () async {
        // This test mirrors the existing source-grep in backup_providers_test.dart
        // and confirms the single-source rule holds at the providers file level.
        const filePath = 'lib/providers/backup_providers.dart';
        final source = await _readSource(filePath);

        // The equality check must appear at least once (it's the implementation).
        const guard = 'defaultTargetPlatform == TargetPlatform.iOS';
        expect(
          source,
          contains(guard),
          reason: 'backup_providers.dart must contain the iOS guard',
        );

        // Extract the combined body of both functions.
        final availableBody = _extractBetween(
          source,
          'List<SyncProvider> availableProviders(',
          'final resolveBackupProvider',
        );
        final resolveBody = _extractBetween(
          source,
          'final resolveBackupProvider',
          'final cloudBackupProvider',
        );

        // The guard must appear in at least one of those two bodies.
        expect(
          availableBody.contains(guard) || resolveBody.contains(guard),
          isTrue,
          reason: 'The defaultTargetPlatform guard must appear in '
              'availableProviders or resolveBackupProvider body',
        );
      },
    );
  });

  // ── G-02: No notifier-level connect/disconnect in switchProvider body ────
  //
  // CC-1 / FR-09: switchProvider composes PROVIDER-LEVEL token-forget
  // primitives (old.disconnect(), newProvider.authorize()).  It must NEVER
  // call the notifier's own connect() / disconnect() — both methods delete
  // the shared passphrase key kBackupPassphraseKey.

  group('G-02 no notifier-level connect/disconnect in switchProvider (CC-1)',
      () {
    const notifierPath = 'lib/features/backup/state/backup_notifier.dart';

    late String switchBody;

    setUp(() async {
      final source = await _readSource(notifierPath);
      // Extract from switchProvider declaration to the next method.
      switchBody = _extractBetween(
        source,
        'Future<void> switchProvider(',
        'Future<void> backupWithPassphrase(',
      );
      expect(
        switchBody,
        isNotEmpty,
        reason: 'test sanity: switchProvider body must be non-empty',
      );
    });

    test(
      'switchProvider body does not contain explicit "this.connect" call (CC-1)',
      () {
        expect(
          switchBody,
          isNot(contains('this.connect')),
          reason: 'switchProvider must not call this.connect() — CC-1',
        );
      },
    );

    test(
      'switchProvider body does not contain explicit "this.disconnect" call (CC-1)',
      () {
        expect(
          switchBody,
          isNot(contains('this.disconnect')),
          reason: 'switchProvider must not call this.disconnect() — CC-1',
        );
      },
    );

    test(
      'switchProvider body does not contain bare "await connect(" (CC-1)',
      () {
        // "await connect(" would be a notifier-level call.
        // "await old.disconnect(" is fine — the dot distinguishes it from a
        // bare method call and does NOT match this pattern.
        expect(
          switchBody,
          isNot(contains('await connect(')),
          reason: 'switchProvider must not call the notifier-level connect() — '
              'provider-level old.disconnect() is the correct primitive (CC-1)',
        );
      },
    );
  });

  // ── G-03: No deleteFile in the switch path ───────────────────────────────
  //
  // FR-13: old .enc files are left intact.  switchProvider and handleSwitchProvider
  // must never call deleteFile.

  group('G-03 no deleteFile in switch path (FR-13)', () {
    test(
      'switchProvider body in backup_notifier.dart does not call deleteFile',
      () async {
        final source = await _readSource(
          'lib/features/backup/state/backup_notifier.dart',
        );
        final switchBody = _extractBetween(
          source,
          'Future<void> switchProvider(',
          'Future<void> backupWithPassphrase(',
        );
        expect(
          switchBody,
          isNot(contains('deleteFile')),
          reason: 'switchProvider must not call deleteFile — '
              'old .enc files must stay intact (FR-13)',
        );
      },
    );

    test(
      'handleSwitchProvider body in backup_connected_view_handlers.dart '
      'does not call deleteFile',
      () async {
        final source = await _readSource(
          'lib/features/backup/views/backup_connected_view_handlers.dart',
        );
        final handlerBody = _extractBetween(
          source,
          'Future<void> handleSwitchProvider()',
          // The mixin ends with '}\n}'; use the closing sequence after the method.
          // Fallback: if the marker is absent, _extractBetween returns the rest of file.
          '}',
        );
        // Also check the whole file for deleteFile — the handler file should
        // never reference it regardless of extraction boundary.
        expect(
          source,
          isNot(contains('deleteFile')),
          reason:
              'backup_connected_view_handlers.dart must not call deleteFile '
              '(old .enc files must stay intact — FR-13)',
        );
        // Extra: the extracted handler body should also be clean.
        expect(
          handlerBody,
          isNot(contains('deleteFile')),
          reason: 'handleSwitchProvider body must not call deleteFile (FR-13)',
        );
      },
    );
  });

  // ── G-04: No passphrase key in switchProvider body ───────────────────────
  //
  // FR-13 / FR-09: the shared passphrase key is NEVER read, written, or
  // deleted during the switch flow.  switchProvider must not reference the key
  // constant or its literal value.

  group('G-04 no passphrase key in switchProvider body (FR-13/FR-09)', () {
    late String switchBody;

    setUp(() async {
      final source = await _readSource(
        'lib/features/backup/state/backup_notifier.dart',
      );
      switchBody = _extractBetween(
        source,
        'Future<void> switchProvider(',
        'Future<void> backupWithPassphrase(',
      );
    });

    test('switchProvider body does not reference kPassphraseKey', () {
      expect(
        switchBody,
        isNot(contains('kPassphraseKey')),
        reason: 'switchProvider must not use kPassphraseKey (FR-13)',
      );
    });

    test('switchProvider body does not reference _passphraseKey', () {
      expect(
        switchBody,
        isNot(contains('_passphraseKey')),
        reason: 'switchProvider must not use _passphraseKey (FR-13)',
      );
    });

    test('switchProvider body does not reference kBackupPassphraseKey', () {
      expect(
        switchBody,
        isNot(contains('kBackupPassphraseKey')),
        reason: 'switchProvider must not use kBackupPassphraseKey (FR-13)',
      );
    });

    test(
      'switchProvider body does not contain the passphrase key literal string',
      () {
        expect(
          switchBody,
          isNot(contains('metra_backup_passphrase_v1')),
          reason: 'switchProvider must not contain the literal passphrase key '
              'string "metra_backup_passphrase_v1" (FR-13)',
        );
      },
    );
  });

  // ── G-05: No unauthorized data-layer imports in backup widgets / views ────
  //
  // NFR-07: strict UI → Domain → Data layering.  Files in
  // features/backup/widgets/ and features/backup/views/ must NOT import:
  //   • data/database/  (Drift schema / DAOs / migrations)
  //   • data/services/  EXCEPT the allowed backup_file_entry.dart
  //     (BackupFileEntry is a plain data class the view layer already uses
  //     for the restore-file picker — approved cross-layer type).
  //
  // "No drift/http/plugin import" means the widget/view layer must not pull
  // in Drift table definitions, HTTP clients, or native plugin bindings directly.

  group(
      'G-05 no unauthorized data-layer imports in backup widgets/views (NFR-07)',
      () {
    final dirsToCheck = [
      'lib/features/backup/widgets',
      'lib/features/backup/views',
    ];

    // Imports from data/services/ that are allowed because they expose
    // plain data classes already used by the pre-M4 module.
    const allowedDataServicesImports = [
      "data/services/backup/backup_file_entry.dart",
    ];

    test('no data/database import in backup widgets/ or views/', () async {
      for (final dir in dirsToCheck) {
        final d = Directory(dir);
        if (!d.existsSync()) continue;
        for (final file in d
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))) {
          final source = await file.readAsString();
          expect(
            source,
            isNot(contains("data/database")),
            reason: '${file.path} must not import data/database — '
                'Drift types must not leak into the UI layer (NFR-07)',
          );
        }
      }
    });

    test(
      'any data/services import in backup widgets/ or views/ is only '
      'the allowed backup_file_entry.dart',
      () async {
        for (final dir in dirsToCheck) {
          final d = Directory(dir);
          if (!d.existsSync()) continue;
          for (final file in d
              .listSync()
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart'))) {
            final source = await file.readAsString();
            // Extract all import lines that reference data/services.
            final dataServicesImports = source
                .split('\n')
                .where(
                  (line) =>
                      line.trimLeft().startsWith('import') &&
                      line.contains("data/services"),
                )
                .toList();

            for (final importLine in dataServicesImports) {
              final isAllowed =
                  allowedDataServicesImports.any(importLine.contains);
              expect(
                isAllowed,
                isTrue,
                reason: '${file.path} contains an unauthorized data/services '
                    'import: "$importLine"\n'
                    'Only ${allowedDataServicesImports.join(', ')} is allowed '
                    'in the UI layer (NFR-07)',
              );
            }
          }
        }
      },
    );

    test(
      'no direct Drift/http/plugin package imports in backup widgets/ or views/',
      () async {
        // These package imports indicate the UI layer is reaching into
        // implementation-level dependencies it should not own.
        const forbiddenPackages = [
          "package:drift/",
          "package:http/",
          "package:icloud_storage/",
          "package:google_sign_in/",
          "package:googleapis/",
          "package:sqlcipher_flutter_libs/",
        ];

        for (final dir in dirsToCheck) {
          final d = Directory(dir);
          if (!d.existsSync()) continue;
          for (final file in d
              .listSync()
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart'))) {
            final source = await file.readAsString();
            for (final pkg in forbiddenPackages) {
              expect(
                source,
                isNot(contains(pkg)),
                reason: '${file.path} must not import "$pkg" — '
                    'data-layer / plugin imports must not appear in '
                    'the UI layer (NFR-07)',
              );
            }
          }
        }
      },
    );
  });
}
