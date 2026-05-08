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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/theme/metra_theme.dart';
import 'package:metra/domain/entities/app_settings_data.dart';
import 'package:metra/domain/use_cases/delete_all_data.dart';
import 'package:metra/features/backup/state/backup_notifier.dart';
import 'package:metra/features/backup/state/backup_state.dart';
import 'package:metra/features/settings/settings_screen.dart';
import 'package:metra/features/settings/state/settings_notifier.dart';
import 'package:metra/l10n/app_localizations.dart';
import 'package:metra/providers/use_case_providers.dart';

import '../../helpers/fake_cycle_entry_repository.dart';
import '../../helpers/fake_daily_log_repository.dart';

// ---------------------------------------------------------------------------
// Stub notifier
// ---------------------------------------------------------------------------

class _StubSettingsNotifier extends SettingsNotifier {
  _StubSettingsNotifier(this._initial);

  final AppSettingsData _initial;
  AppSettingsData? savedSettings;

  @override
  Future<AppSettingsData> build() async => _initial;

  @override
  Future<void> save(AppSettingsData settings) async {
    savedSettings = settings;
    state = AsyncData(settings);
  }
}

class _StubBackupNotifier extends BackupNotifier {
  _StubBackupNotifier(this._initial);

  final BackupState _initial;

  @override
  Future<BackupState> build() async => _initial;
}

// ---------------------------------------------------------------------------
// Test helper
// ---------------------------------------------------------------------------

Widget _wrap(
  List<Override> overrides, {
  BackupState backupState = const BackupNotConnected(),
  Locale locale = const Locale('it'),
}) {
  // The settings screen reads backupNotifierProvider for the Backup-row
  // value text (Design Bible § 18.6). The real notifier's build() touches
  // appSettingsRepositoryProvider — not seeded in widget tests — so every
  // test must override this provider with a stub.
  return ProviderScope(
    overrides: [
      backupNotifierProvider
          .overrideWith(() => _StubBackupNotifier(backupState)),
      ...overrides,
    ],
    child: MaterialApp(
      theme: MetraTheme.light(),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const SettingsScreen(),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  const defaults = AppSettingsData(
    languageCode: 'it',
    darkMode: null,
    painEnabled: true,
    notesEnabled: true,
    notificationDaysBefore: 2,
    notificationsEnabled: false,
    onboardingCompleted: false,
  );

  group('SettingsScreen — smoke', () {
    testWidgets('renders all group headers', (tester) async {
      // Tall viewport so all sections render without scrolling.
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final stub = _StubSettingsNotifier(defaults);
      await tester.pumpWidget(
        _wrap([settingsNotifierProvider.overrideWith(() => stub)]),
      );
      await tester.pumpAndSettle();

      expect(find.text('PREFERENZE'), findsOneWidget);
      expect(find.text('REGISTRO'), findsOneWidget);
      expect(find.text('NOTIFICHE'), findsOneWidget);
      expect(find.text('DATI'), findsOneWidget);
      expect(find.text('AZIONI IRREVERSIBILI'), findsOneWidget);
    });

    testWidgets('renders language and theme rows', (tester) async {
      final stub = _StubSettingsNotifier(defaults);
      await tester.pumpWidget(
        _wrap([settingsNotifierProvider.overrideWith(() => stub)]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Lingua'), findsOneWidget);
      expect(find.text('Tema'), findsOneWidget);
    });

    testWidgets('renders pain and notes toggles', (tester) async {
      final stub = _StubSettingsNotifier(defaults);
      await tester.pumpWidget(
        _wrap([settingsNotifierProvider.overrideWith(() => stub)]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dolore'), findsOneWidget);
      expect(find.text('Note giornaliere'), findsOneWidget);
    });
  });

  group('SettingsScreen — language name helper', () {
    testWidgets(
      '_languageName returns settings_language_system label when languageCode is empty',
      (tester) async {
        const systemLocale = AppSettingsData(
          languageCode: '',
          darkMode: null,
          painEnabled: true,
          notesEnabled: true,
          notificationDaysBefore: 2,
          notificationsEnabled: false,
          onboardingCompleted: false,
        );

        final stub = _StubSettingsNotifier(systemLocale);
        await tester.pumpWidget(
          _wrap([settingsNotifierProvider.overrideWith(() => stub)]),
        );
        await tester.pumpAndSettle();

        // The language row subtitle must show "Automatica" (IT locale).
        expect(find.text('Automatica'), findsOneWidget);
      },
    );
  });

  group('SettingsScreen — toggles', () {
    testWidgets('toggling pain switch calls save with flipped painEnabled',
        (tester) async {
      final stub =
          _StubSettingsNotifier(defaults); // defaults: painEnabled=true
      await tester.pumpWidget(
        _wrap([settingsNotifierProvider.overrideWith(() => stub)]),
      );
      await tester.pumpAndSettle();

      // Tap the pain row label — the row's InkWell flips painEnabled.
      await tester.tap(find.text('Dolore'));
      await tester.pumpAndSettle();

      expect(stub.savedSettings?.painEnabled, isFalse);
    });
  });

  group('SettingsScreen — delete confirmation', () {
    testWidgets('tapping delete-all row shows confirmation dialog',
        (tester) async {
      // Tall viewport so the danger zone is rendered without scrolling.
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final stub = _StubSettingsNotifier(defaults);
      await tester.pumpWidget(
        _wrap([settingsNotifierProvider.overrideWith(() => stub)]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Elimina tutti i dati').first);
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Questa operazione è irreversibile. Tutto il registro sarà eliminato. Le impostazioni resteranno invariate.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('tapping Annulla dismisses dialog', (tester) async {
      // Tall viewport so the danger zone is rendered without scrolling.
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final stub = _StubSettingsNotifier(defaults);
      await tester.pumpWidget(
        _wrap([settingsNotifierProvider.overrideWith(() => stub)]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Elimina tutti i dati').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    });
  });

  group('SettingsScreen — delete execution', () {
    testWidgets('tapping confirm button calls deleteAllData.execute()',
        (tester) async {
      // Use a tall viewport so the ListView renders all sections including the
      // danger zone without needing to scroll.
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final stub = _StubSettingsNotifier(defaults);
      final fakeLogRepo = FakeDailyLogRepository();
      final fakeCycleRepo = FakeCycleEntryRepository();
      final fakeDeleteUc = DeleteAllData(fakeLogRepo, fakeCycleRepo);

      await tester.pumpWidget(
        _wrap([
          settingsNotifierProvider.overrideWith(() => stub),
          deleteAllDataProvider.overrideWith((_) async => fakeDeleteUc),
        ]),
      );
      await tester.pumpAndSettle();

      // The row label and the confirm-dialog title share the same text.
      // At this point only the row is present (no dialog).
      await tester.tap(find.text('Elimina tutti i dati').first);
      await tester.pumpAndSettle();

      // Tap the destructive confirm button.
      await tester.tap(find.text('Elimina'));
      await tester.pumpAndSettle();

      expect(fakeLogRepo.deleteAllCalled, isTrue);
      expect(fakeCycleRepo.deleteAllCalled, isTrue);
    });
  });

  group('SettingsScreen — CSV export button', () {
    testWidgets('Export CSV button is visible', (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final stub = _StubSettingsNotifier(defaults);
      await tester.pumpWidget(
        _wrap([settingsNotifierProvider.overrideWith(() => stub)]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Esporta CSV'), findsOneWidget);
    });

    testWidgets('tapping Export CSV shows privacy warning bottom sheet',
        (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final stub = _StubSettingsNotifier(defaults);
      await tester.pumpWidget(
        _wrap([settingsNotifierProvider.overrideWith(() => stub)]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Esporta CSV'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Questo file contiene dati sanitari'),
        findsOneWidget,
      );
    });

    testWidgets('tapping Cancel on privacy warning dismisses sheet',
        (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final stub = _StubSettingsNotifier(defaults);
      await tester.pumpWidget(
        _wrap([settingsNotifierProvider.overrideWith(() => stub)]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Esporta CSV'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Questo file contiene dati sanitari'),
        findsNothing,
      );
    });
  });

  group('SettingsScreen — CSV import button', () {
    testWidgets('Import CSV button is visible', (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final stub = _StubSettingsNotifier(defaults);
      await tester.pumpWidget(
        _wrap([settingsNotifierProvider.overrideWith(() => stub)]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Importa CSV'), findsOneWidget);
    });

    testWidgets('Import CSV button is tappable (does not throw)',
        (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final stub = _StubSettingsNotifier(defaults);
      await tester.pumpWidget(
        _wrap([settingsNotifierProvider.overrideWith(() => stub)]),
      );
      await tester.pumpAndSettle();

      // Tap does not throw even though FilePicker returns null in test env.
      await tester.tap(find.text('Importa CSV'));
      await tester.pump();
    });
  });

  group('SettingsScreen — advance picker', () {
    testWidgets('shows all 7 options when picker row is tapped',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final stub = _StubSettingsNotifier(defaults);
      await tester.pumpWidget(
        _wrap([settingsNotifierProvider.overrideWith(() => stub)]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Preavviso'));
      await tester.pumpAndSettle();

      final sheet = find.byType(BottomSheet);
      expect(sheet, findsOneWidget);
      for (final label in [
        '1 giorno prima',
        '2 giorni prima',
        '3 giorni prima',
        '4 giorni prima',
        '5 giorni prima',
        '6 giorni prima',
        '7 giorni prima',
      ]) {
        expect(
          find.descendant(of: sheet, matching: find.text(label)),
          findsOneWidget,
          reason: 'Option "$label" must be visible without scrolling',
        );
      }
      // OQ-A resolution (TASK-09): 14 ListTiles × 56 dp ≈ 784 dp exceed a
      // 640 dp viewport — the no-Scrollable invariant is structurally
      // unsatisfiable. The picker now wraps in SingleChildScrollView.
      expect(
        find.descendant(of: sheet, matching: find.byType(Scrollable)),
        findsOneWidget,
        reason:
            'Picker uses SingleChildScrollView to fit 14 rows (OQ-A resolution)',
      );
    });

    testWidgets('tapping an option saves the correct notificationDaysBefore',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final stub = _StubSettingsNotifier(defaults);
      await tester.pumpWidget(
        _wrap([settingsNotifierProvider.overrideWith(() => stub)]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Preavviso'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('5 giorni prima'),
        ),
      );
      await tester.pumpAndSettle();

      expect(stub.savedSettings?.notificationDaysBefore, equals(5));
    });

    testWidgets('tapping the selected option re-saves the same value',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final stub = _StubSettingsNotifier(defaults); // notificationDaysBefore: 2
      await tester.pumpWidget(
        _wrap([settingsNotifierProvider.overrideWith(() => stub)]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Preavviso'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('2 giorni prima'),
        ),
      );
      await tester.pumpAndSettle();

      expect(stub.savedSettings?.notificationDaysBefore, equals(2));
    });

    testWidgets('check icon appears only on the currently selected option',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final stub = _StubSettingsNotifier(defaults); // notificationDaysBefore: 2
      await tester.pumpWidget(
        _wrap([settingsNotifierProvider.overrideWith(() => stub)]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Preavviso'));
      await tester.pumpAndSettle();

      final sheet = find.byType(BottomSheet);
      expect(
        find.descendant(of: sheet, matching: find.byIcon(Icons.check)),
        findsOneWidget,
        reason: 'Exactly one check icon must appear (the selected option)',
      );
    });
  });

  group('SettingsScreen — advance picker (narrow viewport)', () {
    testWidgets('all 7 options are visible on a compact phone screen',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      tester.view.padding = const FakeViewPadding(bottom: 48);
      addTearDown(tester.view.reset);

      final stub = _StubSettingsNotifier(defaults);
      await tester.pumpWidget(
        _wrap([settingsNotifierProvider.overrideWith(() => stub)]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Preavviso'));
      await tester.pumpAndSettle();

      final sheet = find.byType(BottomSheet);
      expect(sheet, findsOneWidget);
      for (final expected in [
        '1 giorno prima',
        '2 giorni prima',
        '3 giorni prima',
        '4 giorni prima',
        '5 giorni prima',
        '6 giorni prima',
        '7 giorni prima',
      ]) {
        expect(
          find.descendant(of: sheet, matching: find.text(expected)),
          findsOneWidget,
        );
      }
      // OQ-A resolution (TASK-09): SingleChildScrollView now wraps the 14
      // ListTiles — the no-Scrollable invariant intentionally relaxed.
      expect(
        find.descendant(of: sheet, matching: find.byType(Scrollable)),
        findsOneWidget,
        reason:
            'Picker uses SingleChildScrollView to fit 14 rows (OQ-A resolution)',
      );
    });
  });

  // ── TASK-09 smoke tests (TDD: write first, implement second) ────────────────

  group('SettingsScreen — Orario notifica row', () {
    testWidgets('row is visible when notificationsEnabled=true',
        (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final stub = _StubSettingsNotifier(
        defaults.copyWith(notificationsEnabled: true),
      );
      await tester.pumpWidget(
        _wrap([settingsNotifierProvider.overrideWith(() => stub)]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Orario notifica'), findsOneWidget);
    });

    testWidgets(
      'row is non-interactive when notificationsEnabled=false',
      (tester) async {
        tester.view.physicalSize = const Size(800, 4000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        // defaults has notificationsEnabled=false
        final stub = _StubSettingsNotifier(defaults);
        await tester.pumpWidget(
          _wrap([settingsNotifierProvider.overrideWith(() => stub)]),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Orario notifica'));
        await tester.pumpAndSettle();

        // No dialog opens when disabled; savedSettings remains null.
        expect(find.byType(Dialog), findsNothing);
        expect(stub.savedSettings, isNull);
      },
    );
  });

  group('SettingsScreen — advance picker 14 rows', () {
    testWidgets('shows 14 rows on 360x640 viewport', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      tester.view.padding = const FakeViewPadding(bottom: 48);
      addTearDown(tester.view.reset);

      final stub = _StubSettingsNotifier(defaults);
      await tester.pumpWidget(
        _wrap([settingsNotifierProvider.overrideWith(() => stub)]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Preavviso'));
      await tester.pumpAndSettle();

      final sheet = find.byType(BottomSheet);
      expect(sheet, findsOneWidget);

      // All 14 options must be present (scroll to reveal them if needed).
      for (int i = 1; i <= 14; i++) {
        final label = i == 1 ? '1 giorno prima' : '$i giorni prima';
        expect(
          find.descendant(of: sheet, matching: find.text(label)),
          findsOneWidget,
          reason: 'Option "$label" must exist in the sheet',
        );
      }
    });
  });

  // ── End TASK-09 smoke tests ──────────────────────────────────────────────────

  // ── TASK-17 tests (FR-12, FR-13, FR-15, FR-17) ──────────────────────────────

  group('SettingsScreen — Orario notifica row time picker FR-13', () {
    testWidgets(
      'tap on enabled row opens TimePickerDialog',
      (tester) async {
        tester.view.physicalSize = const Size(800, 4000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final stub = _StubSettingsNotifier(
          defaults.copyWith(notificationsEnabled: true),
        );
        await tester.pumpWidget(
          _wrap([settingsNotifierProvider.overrideWith(() => stub)]),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Orario notifica'));
        await tester.pumpAndSettle();

        expect(
          find.byType(TimePickerDialog),
          findsOneWidget,
          reason:
              'Tapping the Orario notifica row must open a TimePickerDialog',
        );
      },
    );

    testWidgets(
      'should_write_540_when_confirm_at_initial_09_00_given_default_settings',
      (tester) async {
        // FR-13: initial time derived from notificationTimeMinutes=540 (09:00).
        // Confirming without changing the time must write 540.
        tester.view.physicalSize = const Size(800, 4000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final stub = _StubSettingsNotifier(
          defaults.copyWith(notificationsEnabled: true),
        );
        await tester.pumpWidget(
          _wrap([settingsNotifierProvider.overrideWith(() => stub)]),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Orario notifica'));
        await tester.pumpAndSettle();

        // Tap OK without changing the time — confirms the initial 09:00.
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        expect(
          stub.savedSettings?.notificationTimeMinutes,
          540,
          reason:
              'Confirming at initial 09:00 must persist notificationTimeMinutes=540',
        );
      },
    );

    testWidgets(
      'should_write_825_when_confirm_at_13_45_given_input_mode',
      (tester) async {
        // FR-13: switch to keyboard input mode, type 13:45, confirm → 825.
        // Force 24h format so 13 is a valid hour in the time picker's input
        // validation (otherwise MediaQuery.alwaysUse24HourFormat defaults to
        // false in the test environment and rejects hours > 12).
        tester.platformDispatcher.alwaysUse24HourFormatTestValue = true;
        addTearDown(
          () =>
              tester.platformDispatcher.alwaysUse24HourFormatTestValue = false,
        );

        tester.view.physicalSize = const Size(800, 4000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final stub = _StubSettingsNotifier(
          defaults.copyWith(notificationsEnabled: true),
        );
        await tester.pumpWidget(
          _wrap([settingsNotifierProvider.overrideWith(() => stub)]),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Orario notifica'));
        await tester.pumpAndSettle();

        // Switch from dial to keyboard input mode.
        await tester.tap(find.byIcon(Icons.keyboard_outlined));
        await tester.pumpAndSettle();

        // In 24h input mode there are two TextFields inside TimePickerDialog:
        // hours first, minutes second.
        final dialog = find.byType(TimePickerDialog);
        final fieldsInDialog = find.descendant(
          of: dialog,
          matching: find.byType(TextField),
        );

        await tester.enterText(fieldsInDialog.first, '13');
        await tester.pump();
        await tester.enterText(fieldsInDialog.last, '45');
        await tester.pumpAndSettle();

        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        expect(
          stub.savedSettings?.notificationTimeMinutes,
          825,
          reason:
              'Confirming at 13:45 must persist notificationTimeMinutes=825 (13*60+45)',
        );
      },
    );

    testWidgets(
      'should_not_write_when_cancel_given_open_time_picker',
      (tester) async {
        // FR-13: cancel must leave savedSettings null (no Drift write).
        tester.view.physicalSize = const Size(800, 4000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final stub = _StubSettingsNotifier(
          defaults.copyWith(notificationsEnabled: true),
        );
        await tester.pumpWidget(
          _wrap([settingsNotifierProvider.overrideWith(() => stub)]),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Orario notifica'));
        await tester.pumpAndSettle();

        // Tap Cancel (IT locale: "Annulla").
        await tester.tap(find.text('Annulla'));
        await tester.pumpAndSettle();

        expect(
          stub.savedSettings,
          isNull,
          reason:
              'Cancelling the time picker must not trigger any settings write',
        );
      },
    );
  });

  group('SettingsScreen — settings_notification_time_value locale format FR-15',
      () {
    // 825 minutes = 13:45.  IT (24h) → "13:45".  EN (12h) → "1:45 PM".
    const timeMinutes = 825;

    testWidgets(
      'should_show_13_45_in_IT_locale_given_notificationTimeMinutes_825',
      (tester) async {
        tester.view.physicalSize = const Size(800, 4000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final stub = _StubSettingsNotifier(
          defaults.copyWith(
            notificationsEnabled: true,
            notificationTimeMinutes: timeMinutes,
          ),
        );
        await tester.pumpWidget(
          _wrap(
            [settingsNotifierProvider.overrideWith(() => stub)],
            locale: const Locale('it'),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('13:45'),
          findsOneWidget,
          reason:
              'IT (24h) locale must format 825 min as "13:45" in the Orario notifica row',
        );
      },
    );

    testWidgets(
      'should_show_1_45_PM_in_EN_locale_given_notificationTimeMinutes_825',
      (tester) async {
        tester.view.physicalSize = const Size(800, 4000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final stub = _StubSettingsNotifier(
          defaults.copyWith(
            notificationsEnabled: true,
            notificationTimeMinutes: timeMinutes,
          ),
        );
        await tester.pumpWidget(
          _wrap(
            [settingsNotifierProvider.overrideWith(() => stub)],
            locale: const Locale('en'),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('1:45 PM'),
          findsOneWidget,
          reason:
              'EN (12h) locale must format 825 min as "1:45 PM" in the Reminder time row',
        );
      },
    );
  });

  group('SettingsScreen — advance picker 14 rows FR-12 (wide viewport)', () {
    testWidgets(
      'shows all 14 rows on 800x2000 viewport',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final stub = _StubSettingsNotifier(defaults);
        await tester.pumpWidget(
          _wrap([settingsNotifierProvider.overrideWith(() => stub)]),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Preavviso'));
        await tester.pumpAndSettle();

        final sheet = find.byType(BottomSheet);
        expect(sheet, findsOneWidget);

        for (int i = 1; i <= 14; i++) {
          final label = i == 1 ? '1 giorno prima' : '$i giorni prima';
          expect(
            find.descendant(of: sheet, matching: find.text(label)),
            findsOneWidget,
            reason:
                'Option "$label" must be present in the advance picker (wide viewport)',
          );
        }

        // OQ-A resolution (TASK-09): SingleChildScrollView wraps all 14 rows.
        expect(
          find.descendant(of: sheet, matching: find.byType(Scrollable)),
          findsOneWidget,
          reason:
              'Picker uses SingleChildScrollView for 14 rows (OQ-A resolution)',
        );
      },
    );
  });

  group('SettingsScreen — Scrollable invariant FR-17', () {
    // Both assertions were flipped from findsNothing → findsOneWidget in
    // TASK-09 (OQ-A resolution). These tests confirm the flip holds.

    testWidgets(
      'advance picker Scrollable findsOneWidget on wide viewport (FR-17)',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final stub = _StubSettingsNotifier(defaults);
        await tester.pumpWidget(
          _wrap([settingsNotifierProvider.overrideWith(() => stub)]),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Preavviso'));
        await tester.pumpAndSettle();

        final sheet = find.byType(BottomSheet);
        expect(
          find.descendant(of: sheet, matching: find.byType(Scrollable)),
          findsOneWidget,
          reason:
              'OQ-A resolution: SingleChildScrollView present on wide viewport for 14-row picker',
        );
      },
    );

    testWidgets(
      'advance picker Scrollable findsOneWidget on narrow viewport (FR-17)',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        tester.view.padding = const FakeViewPadding(bottom: 48);
        addTearDown(tester.view.reset);

        final stub = _StubSettingsNotifier(defaults);
        await tester.pumpWidget(
          _wrap([settingsNotifierProvider.overrideWith(() => stub)]),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Preavviso'));
        await tester.pumpAndSettle();

        final sheet = find.byType(BottomSheet);
        expect(
          find.descendant(of: sheet, matching: find.byType(Scrollable)),
          findsOneWidget,
          reason:
              'OQ-A resolution: SingleChildScrollView present on narrow viewport for 14-row picker',
        );
      },
    );
  });

  // ── End TASK-17 tests ────────────────────────────────────────────────────────

  group('SettingsScreen — backup row', () {
    testWidgets('backup row is visible', (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final stub = _StubSettingsNotifier(defaults);
      await tester.pumpWidget(
        _wrap([settingsNotifierProvider.overrideWith(() => stub)]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Backup cloud'), findsOneWidget);
    });

    testWidgets(
      'value text is "Non configurato" when backup state is BackupNotConnected',
      (tester) async {
        tester.view.physicalSize = const Size(800, 4000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final stub = _StubSettingsNotifier(defaults);
        await tester.pumpWidget(
          _wrap(
            [settingsNotifierProvider.overrideWith(() => stub)],
            backupState: const BackupNotConnected(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Non configurato'), findsOneWidget);
        expect(find.text('Configurato'), findsNothing);
      },
    );

    testWidgets(
      'value text is "Configurato" when backup state is BackupConnected',
      (tester) async {
        tester.view.physicalSize = const Size(800, 4000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final stub = _StubSettingsNotifier(defaults);
        await tester.pumpWidget(
          _wrap(
            [settingsNotifierProvider.overrideWith(() => stub)],
            backupState: const BackupConnected(email: 'user@example.com'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Configurato'), findsOneWidget);
        expect(find.text('Non configurato'), findsNothing);
      },
    );

    testWidgets(
      'value text falls back to "Non configurato" for BackupRunning',
      (tester) async {
        tester.view.physicalSize = const Size(800, 4000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final stub = _StubSettingsNotifier(defaults);
        await tester.pumpWidget(
          _wrap(
            [settingsNotifierProvider.overrideWith(() => stub)],
            backupState: const BackupRunning(BackupOperation.backingUp),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Non configurato'), findsOneWidget);
        expect(find.text('Configurato'), findsNothing);
      },
    );

    testWidgets(
      'value text falls back to "Non configurato" for BackupErrorState',
      (tester) async {
        tester.view.physicalSize = const Size(800, 4000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final stub = _StubSettingsNotifier(defaults);
        await tester.pumpWidget(
          _wrap(
            [settingsNotifierProvider.overrideWith(() => stub)],
            backupState: const BackupErrorState('boom'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Non configurato'), findsOneWidget);
        expect(find.text('Configurato'), findsNothing);
      },
    );
  });
}
