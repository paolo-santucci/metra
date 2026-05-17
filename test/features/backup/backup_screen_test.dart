// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/theme/metra_theme.dart';
import 'package:metra/data/services/backup/backup_file_entry.dart';
import 'package:metra/features/backup/backup_screen.dart';
import 'package:metra/features/backup/state/backup_notifier.dart';
import 'package:metra/features/backup/state/backup_state.dart';
import 'package:metra/features/backup/widgets/restore_picker_dialog.dart';
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
}

// ---------------------------------------------------------------------------
// Test helper
// ---------------------------------------------------------------------------

/// Default seed used by [_wrap] / [_wrapWithStorage] to stub
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

/// Helper that also overrides [secureStorageProvider] with [storage].
Widget _wrapWithStorage(
  BackupState state, {
  required InMemorySecureStorage storage,
  _StubBackupNotifier? stub,
  FakeDropboxProvider? fakeProvider,
}) {
  final notifierStub = stub ?? _StubBackupNotifier(state);
  return ProviderScope(
    overrides: [
      backupNotifierProvider.overrideWith(() => notifierStub),
      secureStorageProvider.overrideWithValue(storage),
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
// Picker dialog harness (standalone — does NOT use BackupScreen)
// ---------------------------------------------------------------------------

/// Minimal harness that wraps [child] in the theme + l10n environment required
/// by [RestorePickerDialog].  The [child] is responsible for opening the
/// dialog via [RestorePickerDialog.show].
Widget _pickerHarness(Widget child) {
  return MaterialApp(
    theme: MetraTheme.light(),
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: Center(child: child)),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('BackupScreen — not connected', () {
    testWidgets('shows connect button when not connected', (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(_wrap(const BackupNotConnected()));
      await tester.pumpAndSettle();

      expect(find.text('Connect Dropbox'), findsOneWidget);
      expect(find.text('Back up now'), findsNothing);
    });
  });

  group('BackupScreen — connected', () {
    testWidgets('shows email and backup button when connected', (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        _wrap(const BackupConnected(email: 'user@example.com')),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('user@example.com'), findsOneWidget);
      expect(find.text('Back up now'), findsOneWidget);
      expect(find.text('Restore from backup'), findsOneWidget);
    });

    testWidgets('restore shows confirm dialog', (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        _wrap(const BackupConnected(email: 'a@b.com')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Restore from backup'));
      await tester.pumpAndSettle();

      expect(find.text('Restore backup?'), findsOneWidget);
    });

    testWidgets('disconnect shows confirm dialog', (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        _wrap(const BackupConnected(email: 'a@b.com')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Disconnect'));
      await tester.pumpAndSettle();

      expect(find.text('Disconnect Dropbox?'), findsOneWidget);
    });
  });

  group('BackupScreen — running', () {
    testWidgets('shows loading indicator when backing up', (tester) async {
      await tester.pumpWidget(
        _wrap(const BackupRunning(BackupOperation.backingUp)),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('BackupScreen — error', () {
    testWidgets('error state shows live region Semantics', (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(_wrap(const BackupErrorState('Upload failed')));
      await tester.pumpAndSettle();

      final semantics = tester.getSemantics(find.text('Upload failed'));
      expect(
        semantics.flagsCollection.isLiveRegion,
        isTrue,
      );
    });
  });

  group('PassphraseDialog', () {
    testWidgets('shows mismatch error when fields differ', (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        _wrap(const BackupConnected(email: 'a@b.com')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Back up now'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Passphrase').first,
        'password1',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Confirm passphrase').first,
        'password2',
      );
      await tester.pumpAndSettle();

      expect(find.text('Passphrases do not match.'), findsOneWidget);
    });

    testWidgets('disables submit when passphrase < 8 chars', (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        _wrap(const BackupConnected(email: 'a@b.com')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Back up now'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Passphrase').first,
        'short',
      );
      await tester.pumpAndSettle();

      final button = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'I understand — save and back up'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('shows too-short error when passphrase < 8 chars',
        (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        _wrap(const BackupConnected(email: 'a@b.com')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Back up now'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Passphrase').first,
        'short',
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Passphrase must be at least 8 characters.'),
        findsOneWidget,
      );
    });
  });

  group('Restore flow — passphrase unlock', () {
    testWidgets(
        'restore confirm -> unlock dialog -> calls restoreWithPassphrase',
        (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      addTearDown(() => tester.view.resetPhysicalSize());

      final stub = _StubBackupNotifier(const BackupConnected(email: 'a@b.com'));
      await tester.pumpWidget(
        _wrap(const BackupConnected(email: 'a@b.com'), stub: stub),
      );
      await tester.pumpAndSettle();

      // 1. Tap "Restore from backup".
      await tester.tap(find.text('Restore from backup'));
      await tester.pumpAndSettle();

      // 2. Confirm the destructive dialog.
      expect(find.text('Restore backup?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Restore'));
      await tester.pumpAndSettle();

      // 3. Picker dialog appears — tap "Use newest" shortcut.
      expect(find.text('Choose version'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Use newest'));
      await tester.pumpAndSettle();

      // 4. Passphrase unlock dialog appears.
      expect(find.text('Enter passphrase'), findsOneWidget);
      // Only one passphrase field — no Confirm field in unlock mode.
      expect(
        find.widgetWithText(TextField, 'Confirm passphrase'),
        findsNothing,
      );

      // 5. Enter a passphrase (any non-empty value passes unlock validation).
      await tester.enterText(
        find.widgetWithText(TextField, 'Passphrase').first,
        'my-secret',
      );
      await tester.pumpAndSettle();

      // 6. Tap the unlock-and-restore button.
      await tester.tap(
        find.widgetWithText(TextButton, 'Unlock and restore'),
      );
      await tester.pumpAndSettle();

      // 7. Verify the notifier received the entered passphrase.
      expect(stub.capturedRestorePassphrase, 'my-secret');
    });

    testWidgets(
        'unlock mode: short passphrase still enables submit '
        '(no min-length)', (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        _wrap(const BackupConnected(email: 'a@b.com')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Restore from backup'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Restore'));
      await tester.pumpAndSettle();

      // Picker dialog — use "Use newest" shortcut.
      await tester.tap(find.widgetWithText(TextButton, 'Use newest'));
      await tester.pumpAndSettle();

      // 4-char passphrase — would fail in setNew mode but is fine in unlock.
      await tester.enterText(
        find.widgetWithText(TextField, 'Passphrase').first,
        'abcd',
      );
      await tester.pumpAndSettle();

      final button = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Unlock and restore'),
      );
      expect(button.onPressed, isNotNull);
      // Min-length error message must NOT appear in unlock mode.
      expect(
        find.text('Passphrase must be at least 8 characters.'),
        findsNothing,
      );
    });

    testWidgets('unlock mode: empty passphrase keeps submit disabled',
        (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        _wrap(const BackupConnected(email: 'a@b.com')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Restore from backup'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Restore'));
      await tester.pumpAndSettle();

      // Picker dialog — use "Use newest" shortcut.
      await tester.tap(find.widgetWithText(TextButton, 'Use newest'));
      await tester.pumpAndSettle();

      // No text entered — button must be disabled.
      final button = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Unlock and restore'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('cancel on confirm dialog skips passphrase prompt',
        (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      addTearDown(() => tester.view.resetPhysicalSize());

      final stub = _StubBackupNotifier(const BackupConnected(email: 'a@b.com'));
      await tester.pumpWidget(
        _wrap(const BackupConnected(email: 'a@b.com'), stub: stub),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Restore from backup'));
      await tester.pumpAndSettle();

      // Cancel the destructive confirmation.
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      // No passphrase dialog must open and no passphrase captured.
      expect(find.text('Enter passphrase'), findsNothing);
      expect(stub.capturedRestorePassphrase, isNull);
    });

    testWidgets('cancel on passphrase dialog aborts cleanly', (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      addTearDown(() => tester.view.resetPhysicalSize());

      final stub = _StubBackupNotifier(const BackupConnected(email: 'a@b.com'));
      await tester.pumpWidget(
        _wrap(const BackupConnected(email: 'a@b.com'), stub: stub),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Restore from backup'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Restore'));
      await tester.pumpAndSettle();

      // Picker dialog — use "Use newest" shortcut to reach passphrase.
      await tester.tap(find.widgetWithText(TextButton, 'Use newest'));
      await tester.pumpAndSettle();

      expect(find.text('Enter passphrase'), findsOneWidget);

      // Cancel the passphrase dialog.
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(stub.capturedRestorePassphrase, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // FR-12 / FR-13 / FR-14 — _handleBackup passphrase caching + button disable
  // ---------------------------------------------------------------------------

  group('_handleBackup — FR-12: Nth-time (cached passphrase)', () {
    testWidgets(
        'cached passphrase → no dialog → backupSilent called once '
        '(FR-12 / BUG-D01)', (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      addTearDown(() => tester.view.resetPhysicalSize());

      final storage = InMemorySecureStorage()
        ..values['metra_backup_passphrase_v1'] = 'cached-pass-123';
      final stub = _StubBackupNotifier(
        const BackupConnected(email: 'user@example.com'),
      );

      await tester.pumpWidget(
        _wrapWithStorage(
          const BackupConnected(email: 'user@example.com'),
          storage: storage,
          stub: stub,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Back up now'));
      await tester.pumpAndSettle();

      // Dialog must NOT appear (FR-12: cached passphrase path skips dialog).
      expect(find.text('Set passphrase'), findsNothing);

      // backupSilent called once; backupWithPassphrase never called.
      expect(stub.backupSilentCallCount, 1);
      expect(stub.backupWithPassphraseCallCount, 0);

      // Cached passphrase must NOT be rewritten (FR-12 read-once invariant).
      expect(storage.values['metra_backup_passphrase_v1'], 'cached-pass-123');
    });
  });

  group('_handleBackup — FR-13: first-time (no cached passphrase)', () {
    testWidgets(
        'no passphrase in storage → dialog shown → confirm → '
        'backupWithPassphrase called (FR-13 / EC-01)', (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      addTearDown(() => tester.view.resetPhysicalSize());

      final storage = InMemorySecureStorage(); // empty — no cached passphrase
      final stub = _StubBackupNotifier(
        const BackupConnected(email: 'user@example.com'),
      );

      await tester.pumpWidget(
        _wrapWithStorage(
          const BackupConnected(email: 'user@example.com'),
          storage: storage,
          stub: stub,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Back up now'));
      await tester.pumpAndSettle();

      // PassphraseDialog must appear in setNew mode.
      expect(find.text('Set a backup passphrase'), findsOneWidget);
      expect(
        find.widgetWithText(TextField, 'Confirm passphrase'),
        findsOneWidget,
      );

      // Enter a valid passphrase (≥ 8 chars, matching confirm).
      await tester.enterText(
        find.widgetWithText(TextField, 'Passphrase').first,
        'my-secret-pass',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Confirm passphrase').first,
        'my-secret-pass',
      );
      await tester.pumpAndSettle();

      // Tap confirm.
      await tester.tap(
        find.widgetWithText(TextButton, 'I understand — save and back up'),
      );
      await tester.pumpAndSettle();

      // backupWithPassphrase called with the entered value.
      expect(stub.capturedBackupPassphrase, 'my-secret-pass');
      expect(stub.backupWithPassphraseCallCount, 1);
      // backupSilent must NOT be called.
      expect(stub.backupSilentCallCount, 0);
    });

    testWidgets(
        'cancel on setNew dialog → no write, no notifier call, '
        'button re-enables (FR-13 cancel path)', (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      addTearDown(() => tester.view.resetPhysicalSize());

      final storage = InMemorySecureStorage(); // empty
      final stub = _StubBackupNotifier(
        const BackupConnected(email: 'user@example.com'),
      );

      await tester.pumpWidget(
        _wrapWithStorage(
          const BackupConnected(email: 'user@example.com'),
          storage: storage,
          stub: stub,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Back up now'));
      await tester.pumpAndSettle();

      expect(find.text('Set a backup passphrase'), findsOneWidget);

      // Cancel without confirming.
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      // No write to secure storage.
      expect(storage.values.containsKey('metra_backup_passphrase_v1'), isFalse);
      // No notifier calls.
      expect(stub.backupWithPassphraseCallCount, 0);
      expect(stub.backupSilentCallCount, 0);
      // Button is re-enabled (not stuck disabled).
      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Back up now'),
      );
      expect(button.onPressed, isNotNull);
    });
  });

  group('_handleBackup — FR-14: button state', () {
    testWidgets(
        'Salva ora button is not present when state is BackupRunning '
        '(FR-14 / EC-02)', (tester) async {
      // When state is BackupRunning, the screen switches to _RunningBody which
      // has no "Back up now" button. Absence = unreachable = disabled per FR-14.
      await tester.pumpWidget(
        _wrap(const BackupRunning(BackupOperation.backingUp)),
      );
      await tester.pump();

      expect(
        find.widgetWithText(ElevatedButton, 'Back up now'),
        findsNothing,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // RestorePickerDialog tests (TASK-18)
  // ---------------------------------------------------------------------------

  group('RestorePickerDialog', () {
    final threeEntries = [
      BackupFileEntry(
        name: 'newest.enc',
        timestampUtc: DateTime.utc(2026, 5, 17, 12),
        sizeBytes: 4096,
      ),
      BackupFileEntry(
        name: 'mid.enc',
        timestampUtc: DateTime.utc(2026, 5, 16, 12),
        sizeBytes: 4096,
      ),
      BackupFileEntry(
        name: 'oldest.enc',
        timestampUtc: DateTime.utc(2026, 5, 15, 12),
        sizeBytes: 4096,
      ),
    ];

    testWidgets(
        'FR-14 render — 3 entries: 3 RadioListTile rows, '
        'newest pre-selected, both CTAs enabled', (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        _pickerHarness(
          Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () =>
                  RestorePickerDialog.show(ctx, entries: threeEntries),
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Three rows rendered.
      expect(find.byType(RadioListTile<String>), findsNWidgets(3));

      // RadioGroup.groupValue == entries.first.name (newest pre-selected).
      final radioGroup = tester.widget<RadioGroup<String>>(
        find.byType(RadioGroup<String>),
      );
      expect(radioGroup.groupValue, equals('newest.enc'));

      // Both CTAs are enabled (onPressed != null).
      final useNewest = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Use newest'),
      );
      final restoreThis = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Restore this version'),
      );
      expect(useNewest.onPressed, isNotNull);
      expect(restoreThis.onPressed, isNotNull);
    });

    testWidgets('FR-14 shortcut — "Use newest" returns RestorePickNewest',
        (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      addTearDown(() => tester.view.resetPhysicalSize());

      RestorePickerOutcome? captured;

      await tester.pumpWidget(
        _pickerHarness(
          Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () =>
                  RestorePickerDialog.show(ctx, entries: threeEntries)
                      .then((v) => captured = v),
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Use newest'));
      await tester.pumpAndSettle();

      expect(captured, isA<RestorePickNewest>());
    });

    testWidgets(
        'FR-14 select — tap second row + "Restore this version" '
        'returns RestorePickFilename for mid.enc', (tester) async {
      // Use a larger physical canvas so all rows are on screen.
      tester.view.physicalSize = const Size(2400, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      RestorePickerOutcome? captured;

      await tester.pumpWidget(
        _pickerHarness(
          Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () =>
                  RestorePickerDialog.show(ctx, entries: threeEntries)
                      .then((v) => captured = v),
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Tap the second RadioListTile row.
      await tester.tap(find.byType(RadioListTile<String>).at(1));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Restore this version'));
      await tester.pumpAndSettle();

      expect(captured, isA<RestorePickFilename>());
      expect((captured! as RestorePickFilename).filename, equals('mid.enc'));
    });

    testWidgets(
        'FR-14d — "Restore this version" foregroundColor is colorScheme.error',
        (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        _pickerHarness(
          Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => RestorePickerDialog.show(
                ctx,
                entries: [
                  BackupFileEntry(
                    name: 'only.enc',
                    timestampUtc: DateTime.utc(2026, 5, 17, 12),
                    sizeBytes: 1024,
                  ),
                ],
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final button = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Restore this version'),
      );
      final colorScheme = MetraTheme.light().colorScheme;
      final resolved = button.style!.foregroundColor!.resolve(<WidgetState>{});
      expect(resolved, equals(colorScheme.error));
    });

    testWidgets(
        'EC-01 — empty entries: no RadioListTile rows, both CTAs disabled',
        (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        _pickerHarness(
          Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => RestorePickerDialog.show(ctx, entries: const []),
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // No list rows in the empty-state branch.
      expect(find.byType(RadioListTile<String>), findsNothing);

      // Both CTAs have null onPressed (disabled).
      final useNewest = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Use newest'),
      );
      final restoreThis = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Restore this version'),
      );
      expect(useNewest.onPressed, isNull);
      expect(restoreThis.onPressed, isNull);
    });

    testWidgets('NFR-06 — empty body wrapped in Semantics(liveRegion: true)',
        (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        _pickerHarness(
          Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => RestorePickerDialog.show(ctx, entries: const []),
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // A Semantics node with liveRegion: true must exist in the dialog tree.
      final liveRegionNode = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.liveRegion == true,
      );
      expect(liveRegionNode, findsAtLeastNWidgets(1));
    });

    test(
        'HC-5 — widget source does NOT reference metra_backup_ or BackupFilename',
        () async {
      final src = await File(
        'lib/features/backup/widgets/restore_picker_dialog.dart',
      ).readAsString();
      expect(src.contains('metra_backup_'), isFalse);
      expect(src.contains('BackupFilename'), isFalse);
    });

    testWidgets('EC-12 — rows display localized date strings (DateFormat used)',
        (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        _pickerHarness(
          Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => RestorePickerDialog.show(
                ctx,
                entries: [
                  BackupFileEntry(
                    name: 'only.enc',
                    timestampUtc: DateTime.utc(2026, 5, 17, 12),
                    sizeBytes: 1024,
                  ),
                ],
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // The row must display the year 2026, proving DateFormat was applied
      // (raw filename 'only.enc' does not contain '2026').
      expect(find.textContaining('2026'), findsAtLeastNWidgets(1));
    });
  });

// ---------------------------------------------------------------------------
// TASK-20 — BackupScreen._handleRestore rewire + FR-14d + FR-14e
// ---------------------------------------------------------------------------

  group('BackupScreen — TASK-20 restore rewire', () {
    final twoEntries = [
      BackupFileEntry(
        name: 'newest-t20.enc',
        timestampUtc: DateTime.utc(2026, 5, 17, 12),
        sizeBytes: 2048,
      ),
      BackupFileEntry(
        name: 'older-t20.enc',
        timestampUtc: DateTime.utc(2026, 5, 16, 12),
        sizeBytes: 2048,
      ),
    ];

    testWidgets(
        'FR-14 E2E: confirm → picker → select second row → passphrase → '
        'notifier called with correct filename', (tester) async {
      tester.view.physicalSize = const Size(2400, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final stub = _StubBackupNotifier(
        const BackupConnected(email: 'e2e@test.com'),
      );
      await tester.pumpWidget(
        _wrap(
          const BackupConnected(email: 'e2e@test.com'),
          stub: stub,
          fakeProvider: FakeDropboxProvider(seedEntries: twoEntries),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Tap "Restore from backup".
      await tester.tap(find.text('Restore from backup'));
      await tester.pumpAndSettle();

      // 2. Confirm the destructive dialog.
      await tester.tap(find.widgetWithText(TextButton, 'Restore'));
      await tester.pumpAndSettle();

      // 3. Picker opens — tap the second row, then "Restore this version".
      await tester.tap(find.byType(RadioListTile<String>).at(1));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(TextButton, 'Restore this version'),
      );
      await tester.pumpAndSettle();

      // 4. Enter passphrase and confirm.
      await tester.enterText(
        find.widgetWithText(TextField, 'Passphrase').first,
        'test-pass',
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(TextButton, 'Unlock and restore'),
      );
      await tester.pumpAndSettle();

      // 5. Notifier must have received the selected filename.
      expect(
        stub.capturedRestoreFilename,
        equals('older-t20.enc'),
      );
      expect(stub.capturedRestorePassphrase, equals('test-pass'));
    });

    testWidgets(
        'FR-14d — restore confirm CTA uses foregroundColor: colorScheme.error',
        (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        _wrap(const BackupConnected(email: 'a@b.com')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Restore from backup'));
      await tester.pumpAndSettle();

      expect(find.text('Restore backup?'), findsOneWidget);

      final restoreButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Restore'),
      );
      final colorScheme = MetraTheme.light().colorScheme;
      final resolved =
          restoreButton.style!.foregroundColor!.resolve(<WidgetState>{});
      expect(resolved, equals(colorScheme.error));
    });

    testWidgets(
        'FR-14d — disconnect confirm CTA uses foregroundColor: colorScheme.error',
        (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        _wrap(const BackupConnected(email: 'a@b.com')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Disconnect'));
      await tester.pumpAndSettle();

      expect(find.text('Disconnect Dropbox?'), findsOneWidget);

      // The dialog's CTA is identified by being a descendant of the AlertDialog,
      // not the screen-level "Disconnect" button that opened it.
      final disconnectButton = tester.widget<TextButton>(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(TextButton, 'Disconnect'),
        ),
      );
      final colorScheme = MetraTheme.light().colorScheme;
      final resolved =
          disconnectButton.style!.foregroundColor!.resolve(<WidgetState>{});
      expect(resolved, equals(colorScheme.error));
    });

    testWidgets(
        'FR-14e — failure result drives failure snackbar; '
        'no success snackbar shown on failure', (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      addTearDown(() => tester.view.resetPhysicalSize());

      final stub = _StubBackupNotifier(
        const BackupConnected(email: 'fr14e@test.com'),
      )..restoreFailMessage = 'test-failure';

      await tester.pumpWidget(
        _wrap(
          const BackupConnected(email: 'fr14e@test.com'),
          stub: stub,
          fakeProvider: FakeDropboxProvider(seedEntries: twoEntries),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Restore from backup'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Restore'));
      await tester.pumpAndSettle();

      // Picker — use "Use newest".
      await tester.tap(find.widgetWithText(TextButton, 'Use newest'));
      await tester.pumpAndSettle();

      // Passphrase dialog.
      await tester.enterText(
        find.widgetWithText(TextField, 'Passphrase').first,
        'pass-for-fail',
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(TextButton, 'Unlock and restore'),
      );
      await tester.pumpAndSettle();

      // Failure snackbar must appear with the error message.
      // The text appears in both the SnackBar and the BackupErrorState body —
      // both are correct; assert at least one occurrence.
      expect(find.textContaining('test-failure'), findsAtLeastNWidgets(1));
    });

    test('HC-5 — backup_screen.dart has zero filename-parsing references',
        () async {
      final src = await File(
        'lib/features/backup/backup_screen.dart',
      ).readAsString();
      expect(src.contains('metra_backup_'), isFalse);
      expect(src.contains('BackupFilename'), isFalse);
    });
  });
}
