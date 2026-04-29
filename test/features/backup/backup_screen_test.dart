// Copyright (C) 2024 Paolo Santucci
//
// This file is part of Métra.
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
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

  @override
  Future<BackupState> build() async => _initial;
}

// ---------------------------------------------------------------------------
// Test helper
// ---------------------------------------------------------------------------

Widget _wrap(BackupState state) {
  return ProviderScope(
    overrides: [
      backupNotifierProvider.overrideWith(() => _StubBackupNotifier(state)),
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

      await tester.pumpWidget(_wrap(
        const BackupConnected(email: 'user@example.com'),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('user@example.com'), findsOneWidget);
      expect(find.text('Back up now'), findsOneWidget);
      expect(find.text('Restore from backup'), findsOneWidget);
    });

    testWidgets('restore shows confirm dialog', (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(_wrap(
        const BackupConnected(email: 'a@b.com'),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Restore from backup'));
      await tester.pumpAndSettle();

      expect(find.text('Restore backup?'), findsOneWidget);
    });

    testWidgets('disconnect shows confirm dialog', (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(_wrap(
        const BackupConnected(email: 'a@b.com'),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Disconnect'));
      await tester.pumpAndSettle();

      expect(find.text('Disconnect Dropbox?'), findsOneWidget);
    });
  });

  group('BackupScreen — running', () {
    testWidgets('shows loading indicator when backing up', (tester) async {
      await tester.pumpWidget(_wrap(
        const BackupRunning(BackupOperation.backingUp),
      ));
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
      expect(semantics.hasFlag(SemanticsFlag.isLiveRegion), isTrue);
    });
  });

  group('PassphraseDialog', () {
    testWidgets('shows mismatch error when fields differ', (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(_wrap(
        const BackupConnected(email: 'a@b.com'),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Back up now'));
      await tester.pumpAndSettle();

      // Enter ≥8 chars in passphrase field.
      await tester.enterText(
        find.widgetWithText(TextField, 'Passphrase').first,
        'password1',
      );
      // Enter different value in confirm field.
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

      await tester.pumpWidget(_wrap(
        const BackupConnected(email: 'a@b.com'),
      ));
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

      await tester.pumpWidget(_wrap(
        const BackupConnected(email: 'a@b.com'),
      ));
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
}
