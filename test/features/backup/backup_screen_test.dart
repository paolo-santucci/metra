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

// ---------------------------------------------------------------------------
// Stub notifier
// ---------------------------------------------------------------------------

class _StubBackupNotifier extends BackupNotifier {
  _StubBackupNotifier(this._initial);

  final BackupState _initial;
  String? capturedRestorePassphrase;
  String? capturedBackupPassphrase;

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
  }
}

// ---------------------------------------------------------------------------
// Test helper
// ---------------------------------------------------------------------------

Widget _wrap(BackupState state, {_StubBackupNotifier? stub}) {
  return ProviderScope(
    overrides: [
      backupNotifierProvider.overrideWith(
        () => stub ?? _StubBackupNotifier(state),
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
}
