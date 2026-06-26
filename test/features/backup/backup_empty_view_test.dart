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

// TASK-07 (M4) — BackupEmptyView widget tests.
//
// TDD contract (write failing, confirm red, then implement):
//   handleConnectViaPicker happy: picker→googleDrive → notifier.switchProvider(googleDrive)
//              called once; NO MetraConfirmDialog shown (EC-02).
//   cancel: picker→null → switchProvider NOT called; view unchanged (EC-01).
//   CTA enabled (isRunning==false): onPressed non-null; tap opens picker (FR-07).
//   CTA disabled (isRunning==true): onPressed==null; tapping region does NOT open picker (EC-10).
//
// locale: Italian ('it') — canonical test locale.
// Localized strings used:
//   backupConnectAction   → "Connetti"
//   commonCancel          → "Annulla"
//   backupProviderPickerTitle → "Scegli un provider"
//
// No sqlite dependency — pure widget tests.
// If sqlite is pulled in transitively: LD_LIBRARY_PATH=/tmp/sqlitelib flutter test <file>

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/theme/metra_theme.dart';
import 'package:metra/domain/entities/sync_log_entity.dart';
import 'package:metra/features/backup/state/backup_notifier.dart';
import 'package:metra/features/backup/state/backup_state.dart';
import 'package:metra/features/backup/views/backup_empty_view.dart';
import 'package:metra/features/backup/widgets/backup_provider_picker_sheet.dart';
import 'package:metra/features/backup/widgets/metra_confirm_dialog.dart';
import 'package:metra/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Spy notifier
// ---------------------------------------------------------------------------

/// Spy [BackupNotifier] that records [switchProvider] call arguments and
/// returns [_initial] from [build()] without touching any real provider.
class _SpyBackupNotifier extends BackupNotifier {
  _SpyBackupNotifier(this._initial);

  final BackupState _initial;

  /// Arguments passed to [switchProvider], in call order.
  final List<SyncProvider> switchProviderCalls = [];

  @override
  Future<BackupState> build() async => _initial;

  @override
  Future<void> switchProvider(SyncProvider target) async {
    switchProviderCalls.add(target);
  }
}

// ---------------------------------------------------------------------------
// Test helper
// ---------------------------------------------------------------------------

/// Wraps [BackupEmptyView] in a minimal [ProviderScope] + [MaterialApp] with
/// Italian localizations. [spy] is registered as the [backupNotifierProvider]
/// override so callers can assert on its call log.
Widget _wrap({required _SpyBackupNotifier spy}) {
  return ProviderScope(
    overrides: [
      backupNotifierProvider.overrideWith(() => spy),
    ],
    child: MaterialApp(
      theme: MetraTheme.light(),
      locale: const Locale('it'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const BackupEmptyView(),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('TASK-07 — BackupEmptyView CTA wiring (handleConnectViaPicker)', () {
    // ── Happy path ───────────────────────────────────────────────────────────

    testWidgets(
      'happy_path: picker confirmed with default selection → '
      'switchProvider(dropbox) called once; NO MetraConfirmDialog (EC-02)',
      (tester) async {
        tester.view.physicalSize = const Size(800, 4000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final spy = _SpyBackupNotifier(const BackupNotConnected());
        await tester.pumpWidget(_wrap(spy: spy));
        await tester.pumpAndSettle();

        // Tap CTA to open the provider picker.
        await tester.tap(find.byKey(const Key('backup_empty_cta')));
        await tester.pumpAndSettle();

        // Picker sheet must be open.
        expect(
          find.byType(BackupProviderPickerSheet),
          findsOneWidget,
          reason: 'Provider picker must open after CTA tap',
        );
        // No MetraConfirmDialog must have appeared before confirmation (EC-02).
        expect(
          find.byType(MetraConfirmDialog),
          findsNothing,
          reason: 'No confirm dialog allowed for first-connect (EC-02)',
        );

        // Confirm with default selection (Dropbox, initialIndex=0).
        // The wiring-under-test is: picked provider → switchProvider(picked).
        // The picker's own scroll behaviour (selecting googleDrive/iCloud) is
        // covered by backup_provider_picker_sheet_test.dart.
        await tester.tap(find.byKey(const Key('confirm')));
        await tester.pumpAndSettle();

        // switchProvider must have been called exactly once with the selected
        // provider (Dropbox, index 0 by default).
        expect(
          spy.switchProviderCalls,
          hasLength(1),
          reason: 'switchProvider must be called exactly once — FR-07',
        );
        expect(
          spy.switchProviderCalls.first,
          SyncProvider.dropbox,
          reason:
              'switchProvider must receive the provider selected in the picker',
        );

        // No MetraConfirmDialog at any point in the flow (EC-02: first connect,
        // nothing to lose — the forget step is an idempotent no-op).
        expect(
          find.byType(MetraConfirmDialog),
          findsNothing,
          reason: 'NO MetraConfirmDialog must appear for first-connect (EC-02)',
        );
      },
    );

    // ── Cancel ───────────────────────────────────────────────────────────────

    testWidgets(
      'cancel: picker Annulla → switchProvider NOT called; view unchanged (EC-01)',
      (tester) async {
        tester.view.physicalSize = const Size(800, 4000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final spy = _SpyBackupNotifier(const BackupNotConnected());
        await tester.pumpWidget(_wrap(spy: spy));
        await tester.pumpAndSettle();

        // Open picker.
        await tester.tap(find.byKey(const Key('backup_empty_cta')));
        await tester.pumpAndSettle();

        expect(find.byType(BackupProviderPickerSheet), findsOneWidget);

        // Cancel the picker (Annulla = commonCancel in IT).
        await tester.tap(find.text('Annulla'));
        await tester.pumpAndSettle();

        expect(
          spy.switchProviderCalls,
          isEmpty,
          reason:
              'switchProvider must NOT be called when picker is cancelled — EC-01',
        );

        // View is still showing the empty state.
        expect(find.byType(BackupEmptyView), findsOneWidget);
        // Picker is closed.
        expect(find.byType(BackupProviderPickerSheet), findsNothing);
      },
    );

    // ── CTA enabled gate ─────────────────────────────────────────────────────

    testWidgets(
      'CTA_enabled_isRunning_false: onPressed non-null; tap opens picker (FR-07)',
      (tester) async {
        tester.view.physicalSize = const Size(800, 4000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final spy = _SpyBackupNotifier(const BackupNotConnected());
        await tester.pumpWidget(_wrap(spy: spy));
        await tester.pumpAndSettle();

        // ElevatedButton inside the CTA SizedBox must have non-null onPressed.
        final button = tester.widget<ElevatedButton>(
          find.descendant(
            of: find.byKey(const Key('backup_empty_cta')),
            matching: find.byType(ElevatedButton),
          ),
        );
        expect(
          button.onPressed,
          isNotNull,
          reason:
              'CTA must be enabled when not running (isRunning==false) — FR-07',
        );

        // Tapping the CTA must open the provider picker.
        await tester.tap(find.byKey(const Key('backup_empty_cta')));
        await tester.pumpAndSettle();

        expect(
          find.byType(BackupProviderPickerSheet),
          findsOneWidget,
          reason: 'Picker must open on CTA tap when not running — FR-07',
        );
      },
    );

    // ── CTA disabled gate (EC-10) ─────────────────────────────────────────────

    testWidgets(
      'CTA_disabled_isRunning_true: onPressed==null; tapping does NOT open picker (EC-10)',
      (tester) async {
        tester.view.physicalSize = const Size(800, 4000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final spy =
            _SpyBackupNotifier(const BackupRunning(BackupOperation.backingUp));
        await tester.pumpWidget(_wrap(spy: spy));
        await tester.pumpAndSettle();

        // ElevatedButton inside the CTA SizedBox must have null onPressed (disabled).
        final button = tester.widget<ElevatedButton>(
          find.descendant(
            of: find.byKey(const Key('backup_empty_cta')),
            matching: find.byType(ElevatedButton),
          ),
        );
        expect(
          button.onPressed,
          isNull,
          reason: 'CTA must be disabled when running (isRunning==true) — EC-10',
        );

        // Tapping the disabled CTA must NOT open the picker.
        await tester.tap(
          find.byKey(const Key('backup_empty_cta')),
          warnIfMissed: false,
        );
        await tester.pumpAndSettle();

        expect(
          find.byType(BackupProviderPickerSheet),
          findsNothing,
          reason: 'Picker must NOT open when CTA is disabled — EC-10',
        );
        expect(
          spy.switchProviderCalls,
          isEmpty,
          reason:
              'switchProvider must NOT be called when CTA is disabled — EC-10',
        );
      },
    );
  });
}
