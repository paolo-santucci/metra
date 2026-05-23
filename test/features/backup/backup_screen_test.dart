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

// TASK-30 — Group H: BackupScreen dispatcher widget tests (full rewrite)
//
// Tests in this file exercise the BackupScreen dispatcher (TASK-21 / FR-20).
// Each test verifies a single user-visible routing behaviour.
//
// Tests removed from this file during the TASK-30 rewrite and their new homes:
//   - Auto-backup indicator (FR-20/FR-21 StatusIndicator)  → TASK-31 Group I
//   - PassphraseDialog (setNew / unlock validation)         → passphrase_dialog_token_test.dart
//   - _handleBackup FR-12/FR-13/FR-14 passphrase cache      → TASK-31 Group I
//   - FR-14d confirm-CTA colour                             → TASK-27 Group E
//   - FR-14e failure snackbar                               → TASK-35 integration scenarios
//   - Restore flow picker+passphrase (FR-14 E2E)            → TASK-35 integration scenarios
//   - HC-5 no filename-parsing                              → TASK-34 Group M
//
// Platform matrix: Linux CI, headless (no device-farm dependency).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/theme/metra_theme.dart';
import 'package:metra/data/services/backup/backup_file_entry.dart';
import 'package:metra/features/backup/backup_screen.dart';
import 'package:metra/features/backup/restore_progress_screen.dart';
import 'package:metra/features/backup/state/backup_notifier.dart';
import 'package:metra/features/backup/state/backup_state.dart';
import 'package:metra/features/backup/views/backup_connected_view.dart';
import 'package:metra/features/backup/views/backup_empty_view.dart';
import 'package:metra/features/backup/views/backup_error_view.dart';
import 'package:metra/l10n/app_localizations.dart';
import 'package:metra/providers/backup_providers.dart';
import 'package:metra/providers/encryption_provider.dart';

import '../../helpers/fake_dropbox_provider.dart';
import '../../helpers/in_memory_secure_storage.dart';

// ---------------------------------------------------------------------------
// Stub notifier
// ---------------------------------------------------------------------------

class _StubBackupNotifier extends BackupNotifier {
  _StubBackupNotifier(this._initial);

  final BackupState _initial;
  String? capturedRestorePassphrase;
  String? capturedRestoreFilename;
  String? capturedBackupPassphrase;
  int backupSilentCallCount = 0;
  int backupWithPassphraseCallCount = 0;
  int backupNowCallCount = 0;

  /// When non-null, [restoreWithPassphrase] transitions state to
  /// [BackupErrorState] with this message instead of completing silently.
  String? restoreFailMessage;

  @override
  Future<BackupState> build() async => _initial;

  // Override to capture the passphrase without touching real providers
  // (restoreDataProvider / secureStorageProvider are unseeded in widget tests).
  @override
  Future<void> restoreWithPassphrase(
    String passphrase, {
    String? filename,
  }) async {
    capturedRestorePassphrase = passphrase;
    capturedRestoreFilename = filename;
    if (restoreFailMessage != null) {
      state = AsyncData(BackupErrorState(restoreFailMessage!));
    }
  }

  @override
  Future<void> backupWithPassphrase(String passphrase) async {
    capturedBackupPassphrase = passphrase;
    backupWithPassphraseCallCount++;
  }

  @override
  Future<void> backupSilent() async {
    backupSilentCallCount++;
  }

  @override
  Future<void> backupNow() async {
    backupNowCallCount++;
  }
}

// ---------------------------------------------------------------------------
// Test helper
// ---------------------------------------------------------------------------

/// Default seed used by [_wrap] to stub
/// [backupFileListProvider].  One entry is enough to allow the picker to
/// open and "Use newest" to be tapped; tests that need specific entries
/// should pass a custom [fakeProvider].
final _defaultSeedEntry = BackupFileEntry(
  name: 'default.enc',
  timestampUtc: DateTime.utc(2026, 5, 17, 12),
  sizeBytes: 1024,
);

Widget _wrap(
  BackupState state, {
  _StubBackupNotifier? stub,
  FakeDropboxProvider? fakeProvider,
}) {
  // Provide an empty InMemorySecureStorage so _handleBackup's read() returns
  // null and the setNew PassphraseDialog path is exercised without calling
  // the real FlutterSecureStorage plugin (which is unavailable in widget tests).
  return ProviderScope(
    overrides: [
      backupNotifierProvider.overrideWith(
        () => stub ?? _StubBackupNotifier(state),
      ),
      secureStorageProvider.overrideWithValue(InMemorySecureStorage()),
      cloudBackupProvider.overrideWithValue(
        fakeProvider ?? FakeDropboxProvider(seedEntries: [_defaultSeedEntry]),
      ),
    ],
    child: MaterialApp(
      theme: MetraTheme.light(),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const BackupScreen(),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  // Group H — BackupScreen dispatcher (FR-20)
  // Spec ref: §7.1 Group H
  // =========================================================================

  group('Group H — BackupScreen dispatcher (FR-20)', () {
    // H-1: BackupNotConnected → BackupEmptyView
    testWidgets(
        'should_render_BackupEmptyView_when_state_is_BackupNotConnected',
        (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(_wrap(const BackupNotConnected()));
      await tester.pumpAndSettle();

      expect(find.byType(BackupEmptyView), findsOneWidget);
    });

    // H-2: BackupConnected → BackupConnectedView
    testWidgets(
        'should_render_BackupConnectedView_when_state_is_BackupConnected',
        (tester) async {
      tester.view.physicalSize = const Size(2400, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _wrap(
          const BackupConnected(
            email: 'a@b.it',
            autoBackupActive: true,
            lastBackupAt: null,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BackupConnectedView), findsOneWidget);
    });

    // H-3: BackupRunning(restoring) → RestoreProgressScreen
    testWidgets(
        'should_render_RestoreProgressScreen_when_state_is_BackupRunning_restoring',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const BackupRunning(BackupOperation.restoring)),
      );
      await tester.pump();

      expect(find.byType(RestoreProgressScreen), findsOneWidget);
    });

    // H-4: BackupRunning(non-restoring) → _RunningBody, NOT RestoreProgressScreen
    testWidgets(
        'should_render_running_overlay_and_NOT_RestoreProgressScreen_when_state_is_BackupRunning_backingUp',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const BackupRunning(BackupOperation.backingUp)),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(RestoreProgressScreen), findsNothing);
    });

    // H-5: BackupErrorState → BackupErrorView
    testWidgets('should_render_BackupErrorView_when_state_is_BackupErrorState',
        (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(_wrap(const BackupErrorState('Network error')));
      await tester.pumpAndSettle();

      expect(find.byType(BackupErrorView), findsOneWidget);
    });

    // H-6: Exhaustive switch — no default branch, no analyzer warning
    test('backup_screen.dart switch has no default branch', () async {
      final src = await File(
        'lib/features/backup/backup_screen.dart',
      ).readAsString();
      // No bare 'default:' label in the switch (outside comments).
      expect(
        RegExp(r'^\s*default\s*:', multiLine: true).hasMatch(src),
        isFalse,
        reason: 'backup_screen.dart must not contain a default: branch — '
            'the switch must be exhaustive so adding a new BackupState '
            'subtype fails the analyzer (FR-20 neg)',
      );
    });

    test('flutter analyze backup_screen.dart reports zero issues', () async {
      final result = await Process.run(
        'flutter',
        [
          'analyze',
          'lib/features/backup/backup_screen.dart',
          '--no-fatal-infos',
        ],
        workingDirectory: '.',
      );
      expect(
        result.exitCode,
        0,
        reason: 'flutter analyze output:\n${result.stdout}\n${result.stderr}',
      );
    });

    // H-7: Scaffold ownership — each view owns its own AppBar;
    //       dispatcher does NOT wrap in second Scaffold.
    group('Scaffold ownership — each view owns its own AppBar', () {
      testWidgets('BackupEmptyView mounted standalone has exactly one AppBar',
          (tester) async {
        tester.view.physicalSize = const Size(800, 4000);
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              backupNotifierProvider.overrideWith(
                () => _StubBackupNotifier(const BackupNotConnected()),
              ),
              secureStorageProvider.overrideWithValue(InMemorySecureStorage()),
              cloudBackupProvider.overrideWithValue(
                FakeDropboxProvider(seedEntries: [_defaultSeedEntry]),
              ),
            ],
            child: MaterialApp(
              theme: MetraTheme.light(),
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const BackupEmptyView(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AppBar), findsOneWidget);
      });

      testWidgets(
          'BackupConnectedView mounted standalone has exactly one AppBar',
          (tester) async {
        tester.view.physicalSize = const Size(2400, 6000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        const connectedState = BackupConnected(
          email: 'scaffold@test.com',
          autoBackupActive: true,
          lastBackupAt: null,
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              backupNotifierProvider.overrideWith(
                () => _StubBackupNotifier(connectedState),
              ),
              secureStorageProvider.overrideWithValue(InMemorySecureStorage()),
              cloudBackupProvider.overrideWithValue(
                FakeDropboxProvider(seedEntries: [_defaultSeedEntry]),
              ),
            ],
            child: MaterialApp(
              theme: MetraTheme.light(),
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const BackupConnectedView(state: connectedState),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AppBar), findsOneWidget);
      });

      testWidgets(
          'RestoreProgressScreen mounted standalone has exactly one AppBar',
          (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              backupNotifierProvider.overrideWith(
                () => _StubBackupNotifier(
                  const BackupRunning(BackupOperation.restoring),
                ),
              ),
              secureStorageProvider.overrideWithValue(InMemorySecureStorage()),
              cloudBackupProvider.overrideWithValue(
                FakeDropboxProvider(seedEntries: [_defaultSeedEntry]),
              ),
            ],
            child: MaterialApp(
              theme: MetraTheme.light(),
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const RestoreProgressScreen(),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(AppBar), findsOneWidget);
      });

      testWidgets(
          'BackupScreen dispatcher wrapping BackupEmptyView has exactly one AppBar (no double-Scaffold)',
          (tester) async {
        tester.view.physicalSize = const Size(800, 4000);
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(_wrap(const BackupNotConnected()));
        await tester.pumpAndSettle();

        // If the dispatcher wrapped in a second Scaffold + AppBar this would
        // find 2. The dispatcher must produce exactly 1 AppBar (owned by
        // BackupEmptyView).
        expect(find.byType(AppBar), findsOneWidget);
      });

      testWidgets('BackupErrorView mounted standalone has exactly one AppBar',
          (tester) async {
        tester.view.physicalSize = const Size(800, 4000);
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              backupNotifierProvider.overrideWith(
                () => _StubBackupNotifier(const BackupNotConnected()),
              ),
              secureStorageProvider.overrideWithValue(InMemorySecureStorage()),
              cloudBackupProvider.overrideWithValue(
                FakeDropboxProvider(seedEntries: [_defaultSeedEntry]),
              ),
            ],
            child: MaterialApp(
              theme: MetraTheme.light(),
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const BackupErrorView(message: 'standalone error'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AppBar), findsOneWidget);
      });

      testWidgets(
          'BackupScreen dispatcher wrapping BackupConnectedView has exactly one AppBar (no double-Scaffold)',
          (tester) async {
        tester.view.physicalSize = const Size(2400, 6000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          _wrap(
            const BackupConnected(
              email: 'scaffold@test.com',
              autoBackupActive: false,
              lastBackupAt: null,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AppBar), findsOneWidget);
      });

      testWidgets(
          'BackupScreen dispatcher wrapping RestoreProgressScreen has exactly one AppBar (no double-Scaffold)',
          (tester) async {
        await tester.pumpWidget(
          _wrap(const BackupRunning(BackupOperation.restoring)),
        );
        await tester.pump();

        expect(find.byType(AppBar), findsOneWidget);
      });

      testWidgets(
          'BackupScreen dispatcher wrapping BackupErrorView has exactly one AppBar (no double-Scaffold)',
          (tester) async {
        tester.view.physicalSize = const Size(800, 4000);
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(_wrap(const BackupErrorState('wrap error')));
        await tester.pumpAndSettle();

        expect(find.byType(AppBar), findsOneWidget);
      });
    });
  });

  // =========================================================================
  // Dispatcher async-state envelope (FR-20 — AsyncValue.when branches)
  // =========================================================================

  group('Dispatcher async-state envelope (FR-20)', () {
    // AsyncLoading → loading scaffold with CircularProgressIndicator
    testWidgets(
        'should_show_CircularProgressIndicator_when_asyncState_is_AsyncLoading',
        (tester) async {
      final stub = _StubBackupNotifier(const BackupNotConnected());

      await tester.pumpWidget(_wrap(const BackupNotConnected(), stub: stub));
      // Overwrite the resolved AsyncData with AsyncLoading before rebuild.
      stub.state = const AsyncLoading();
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    // AsyncError → BackupErrorView with the error message
    testWidgets('should_render_BackupErrorView_when_asyncState_is_AsyncError',
        (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      addTearDown(() => tester.view.resetPhysicalSize());

      final stub = _StubBackupNotifier(const BackupNotConnected());

      await tester.pumpWidget(_wrap(const BackupNotConnected(), stub: stub));
      await tester.pumpAndSettle();

      stub.state = AsyncError(Exception('async-error-test'), StackTrace.empty);
      await tester.pumpAndSettle();

      expect(find.byType(BackupErrorView), findsOneWidget);
    });
  });
}
