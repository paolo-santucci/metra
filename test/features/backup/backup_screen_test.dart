// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/theme/metra_theme.dart';
import 'package:metra/features/backup/backup_screen.dart';
import 'package:metra/features/backup/state/backup_notifier.dart';
import 'package:metra/features/backup/state/backup_state.dart';
import 'package:metra/l10n/app_localizations.dart';
import 'package:metra/providers/encryption_provider.dart';

import '../../helpers/in_memory_secure_storage.dart';

// ---------------------------------------------------------------------------
// Stub notifier
// ---------------------------------------------------------------------------

class _StubBackupNotifier extends BackupNotifier {
  _StubBackupNotifier(this._initial);

  final BackupState _initial;
  String? capturedRestorePassphrase;
  String? capturedBackupPassphrase;
  int backupSilentCallCount = 0;
  int backupWithPassphraseCallCount = 0;

  @override
  Future<BackupState> build() async => _initial;

  // Override to capture the passphrase without touching real providers
  // (restoreDataProvider / secureStorageProvider are unseeded in widget tests).
  @override
  Future<void> restoreWithPassphrase(String passphrase) async {
    capturedRestorePassphrase = passphrase;
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

Widget _wrap(BackupState state, {_StubBackupNotifier? stub}) {
  // Provide an empty InMemorySecureStorage so _handleBackup's read() returns
  // null and the setNew PassphraseDialog path is exercised without calling
  // the real FlutterSecureStorage plugin (which is unavailable in widget tests).
  return ProviderScope(
    overrides: [
      backupNotifierProvider.overrideWith(
        () => stub ?? _StubBackupNotifier(state),
      ),
      secureStorageProvider.overrideWithValue(InMemorySecureStorage()),
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
}) {
  final notifierStub = stub ?? _StubBackupNotifier(state);
  return ProviderScope(
    overrides: [
      backupNotifierProvider.overrideWith(() => notifierStub),
      secureStorageProvider.overrideWithValue(storage),
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

      // 3. Passphrase unlock dialog appears.
      expect(find.text('Enter passphrase'), findsOneWidget);
      // Only one passphrase field — no Confirm field in unlock mode.
      expect(
        find.widgetWithText(TextField, 'Confirm passphrase'),
        findsNothing,
      );

      // 4. Enter a passphrase (any non-empty value passes unlock validation).
      await tester.enterText(
        find.widgetWithText(TextField, 'Passphrase').first,
        'my-secret',
      );
      await tester.pumpAndSettle();

      // 5. Tap the unlock-and-restore button.
      await tester.tap(
        find.widgetWithText(TextButton, 'Unlock and restore'),
      );
      await tester.pumpAndSettle();

      // 6. Verify the notifier received the entered passphrase.
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
}
