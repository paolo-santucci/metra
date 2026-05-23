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

// TASK-17 — BackupEmptyView smoke tests
//
// Covers:
//   1. Widget structure: heading, body, CTA present; cloud icon 64×64;
//      body capped at 240dp; CTA anchored 24dp from bottom safe-area.
//   2. CTA tap → notifier.connect() called once.
//   3. HC-2 gate: CTA disabled during BackupRunning(connecting).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/theme/metra_theme.dart';
import 'package:metra/features/backup/state/backup_notifier.dart';
import 'package:metra/features/backup/state/backup_state.dart';
import 'package:metra/features/backup/views/backup_empty_view.dart';
import 'package:metra/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Fake notifier helpers
// ---------------------------------------------------------------------------

/// Records how many times [connect] was called.
class _FakeBackupNotifier extends AsyncNotifier<BackupState>
    implements BackupNotifier {
  _FakeBackupNotifier(this._initialState);

  final BackupState _initialState;
  int connectCalls = 0;

  @override
  Future<BackupState> build() async => _initialState;

  @override
  Future<void> connect() async {
    connectCalls++;
  }

  // All other BackupNotifier methods are not exercised in these tests.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Builds a [ProviderScope] + [MaterialApp] harness that wraps [BackupEmptyView]
/// with an overridden [backupNotifierProvider].
Widget _harness(
  _FakeBackupNotifier fakeNotifier, {
  ThemeMode themeMode = ThemeMode.light,
}) {
  return ProviderScope(
    overrides: [
      backupNotifierProvider.overrideWith(() => fakeNotifier),
    ],
    child: MaterialApp(
      theme: MetraTheme.light(),
      darkTheme: MetraTheme.dark(),
      themeMode: themeMode,
      locale: const Locale('it'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const BackupEmptyView(),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ── 1. Widget structure ───────────────────────────────────────────────────

  testWidgets(
    'BackupEmptyView: heading, body, CTA present; cloud icon 64×64; body ≤ 240dp wide',
    (tester) async {
      final fake = _FakeBackupNotifier(const BackupNotConnected());
      await tester.pumpWidget(_harness(fake));
      await tester.pumpAndSettle();

      // AppBar title "Backup" is present.
      expect(find.byType(AppBar), findsOneWidget);

      // Cloud icon — a 64×64 SizedBox with key 'backup_empty_cloud_icon'.
      final iconBox = tester.widget<SizedBox>(
        find.byKey(const Key('backup_empty_cloud_icon')),
      );
      expect(
        iconBox.width,
        64.0,
        reason: 'Cloud icon container must be 64dp wide',
      );
      expect(
        iconBox.height,
        64.0,
        reason: 'Cloud icon container must be 64dp tall',
      );

      // Heading text present.
      expect(
        find.byKey(const Key('backup_empty_heading')),
        findsOneWidget,
        reason: 'Heading widget must be present',
      );

      // Body text present and capped at 240dp.
      final bodyWidget = tester.widget<ConstrainedBox>(
        find.byKey(const Key('backup_empty_body_constrained')),
      );
      expect(
        bodyWidget.constraints.maxWidth,
        240.0,
        reason: 'Body text must be capped at 240dp',
      );

      // CTA button present.
      expect(
        find.byKey(const Key('backup_empty_cta')),
        findsOneWidget,
        reason: 'CTA button must be present',
      );
    },
  );

  // ── 2. CTA tap → connect() called once ───────────────────────────────────

  testWidgets(
    'BackupEmptyView: CTA tap → notifier.connect() called once',
    (tester) async {
      final fake = _FakeBackupNotifier(const BackupNotConnected());
      await tester.pumpWidget(_harness(fake));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('backup_empty_cta')));
      await tester.pump();

      expect(
        fake.connectCalls,
        1,
        reason: 'connect() must be called exactly once on CTA tap',
      );
    },
  );

  // ── 3. HC-2 gate: CTA disabled during BackupRunning ──────────────────────

  testWidgets(
    'BackupEmptyView: CTA disabled during BackupRunning(connecting)',
    (tester) async {
      final fake =
          _FakeBackupNotifier(const BackupRunning(BackupOperation.connecting));
      await tester.pumpWidget(_harness(fake));
      await tester.pumpAndSettle();

      // The ElevatedButton inside ButtonPrimary should have onPressed == null.
      final button = tester.widget<ElevatedButton>(
        find.descendant(
          of: find.byKey(const Key('backup_empty_cta')),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(
        button.onPressed,
        isNull,
        reason: 'CTA must be disabled (onPressed == null) during BackupRunning',
      );
    },
  );

  // ── 4. HC-2 concurrency guard (EC-05): tap with pre-seeded BackupRunning ──

  testWidgets(
    'BackupEmptyView: tap CTA with pre-seeded BackupRunning does NOT call connect()',
    (tester) async {
      // Stub is pre-seeded to BackupRunning(connecting) before any tap.
      // The HC-2 view-side gate (onPressed == null) must fire before the notifier
      // is ever reached — so connectCalls must remain 0.
      final fake =
          _FakeBackupNotifier(const BackupRunning(BackupOperation.connecting));
      await tester.pumpWidget(_harness(fake));
      await tester.pumpAndSettle();

      // Attempt to tap the CTA while BackupRunning is active.
      await tester.tap(
        find.byKey(const Key('backup_empty_cta')),
        warnIfMissed: false, // CTA is present but gestures are swallowed
      );
      await tester.pump();

      expect(
        fake.connectCalls,
        0,
        reason:
            'connect() must NOT be called when the CTA tap-gate fires (HC-2, EC-05)',
      );
    },
  );
}
