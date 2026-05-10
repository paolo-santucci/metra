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

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/theme/metra_colors.dart';
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
  int saveCallCount = 0;

  @override
  Future<AppSettingsData> build() async => _initial;

  @override
  Future<void> save(AppSettingsData settings) async {
    savedSettings = settings;
    saveCallCount++;
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

  // ── TASK-09 smoke tests ──────────────────────────────────────────────────────

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

  group('BUG-007: Preavviso row disabled when notifications toggle is off', () {
    testWidgets(
      'Preavviso row is disabled when notificationsEnabled is false',
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

        await tester.tap(find.text('Preavviso'));
        await tester.pumpAndSettle();

        // No picker opens when disabled; savedSettings remains null.
        expect(find.byType(CupertinoPicker), findsNothing);
        expect(stub.savedSettings, isNull);
      },
    );
  });

  // ── End TASK-09 smoke tests ──────────────────────────────────────────────────

  // ── TASK-17 tests (FR-12, FR-13, FR-15, FR-17) ──────────────────────────────

  group('SettingsScreen — Orario notifica row time picker FR-13', () {
    testWidgets(
      'android_time_picker_uses_cupertino_wheel',
      (tester) async {
        // FR-13: on Android the picker must now be a Cupertino wheel, not
        // the Material TimePickerDialog. The Material dialog was replaced to
        // give a unified UX on both platforms.
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
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
          find.byType(CupertinoDatePicker),
          findsOneWidget,
          reason: 'Android must now open a CupertinoDatePicker wheel, not the '
              'Material TimePickerDialog.',
        );
        expect(
          find.byType(TimePickerDialog),
          findsNothing,
          reason:
              'TimePickerDialog must not appear on Android after migration.',
        );
        debugDefaultTargetPlatformOverride = null;
      },
    );

    testWidgets(
      'should_not_write_when_barrier_dismiss_given_open_time_picker',
      (tester) async {
        // FR-13: opening the Cupertino picker and dismissing via the barrier
        // (tap outside the 310 px bottom sheet) without moving the wheel must
        // leave savedSettings null — no debounce fires, no Drift write occurs.
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

        // Dismiss by tapping above the 310 px bottom sheet.
        // physicalSize is 800×4000, devicePixelRatio=1 → logical size 800×4000.
        // The sheet is anchored at the bottom; Offset(400, 100) is well above it.
        await tester.tapAt(const Offset(400, 100));
        await tester.pumpAndSettle();

        expect(
          stub.savedSettings,
          isNull,
          reason:
              'Dismissing the Cupertino picker without wheel movement must not '
              'trigger any settings write (no debounce was scheduled).',
        );
      },
    );
  });

  // Note: the "Android time-picker theme (FR-01, FR-02)" group was removed
  // when the Material TimePickerDialog was replaced by the unified Cupertino
  // wheel on all platforms. TimePickerThemeData is no longer configured or
  // testable from the settings screen.

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

  group('SettingsScreen — advance picker (CupertinoPicker) platform parity', () {
    testWidgets(
      'android_advance_picker_uses_cupertino_wheel',
      (tester) async {
        // SimpleDialog replaced by CupertinoPicker on Android for visual
        // consistency with iOS and the time-picker wheel.
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
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

        await tester.tap(find.text('Preavviso'));
        await tester.pumpAndSettle();

        expect(
          find.byType(CupertinoPicker),
          findsOneWidget,
          reason:
              'Android must open CupertinoPicker for Preavviso, not a SimpleDialog.',
        );
        expect(
          find.byType(Dialog),
          findsNothing,
          reason: 'SimpleDialog must not appear on Android after migration.',
        );
        debugDefaultTargetPlatformOverride = null;
      },
    );

    testWidgets(
      'should_not_write_when_barrier_dismiss_given_open_advance_picker',
      (tester) async {
        // Opening the Cupertino picker and dismissing via the barrier without
        // moving the wheel must leave savedSettings null — no debounce fires.
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

        await tester.tap(find.text('Preavviso'));
        await tester.pumpAndSettle();

        // Dismiss by tapping above the bottom sheet (Offset(400, 100) is well
        // above the anchored-at-bottom modal on an 800×4000 logical screen).
        await tester.tapAt(const Offset(400, 100));
        await tester.pumpAndSettle();

        expect(
          stub.savedSettings,
          isNull,
          reason:
              'Dismissing the advance picker without wheel movement must not '
              'trigger any settings write.',
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

  group('SettingsScreen — iOS time picker (CupertinoDatePicker)', () {
    testWidgets('tap on enabled row opens CupertinoDatePicker modal',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
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
        find.byType(CupertinoDatePicker),
        findsOneWidget,
        reason:
            'iOS time row must open CupertinoDatePicker, not TimePickerDialog',
      );
      expect(
        find.byType(TimePickerDialog),
        findsNothing,
        reason: 'TimePickerDialog must not appear on iOS',
      );
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets(
      'Ripristina resets wheel and resaves original; modal stays open (time)',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        tester.view.physicalSize = const Size(800, 4000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        // Seed 540 (09:00) — already round-5; Ripristina must restore to 540.
        final stub = _StubSettingsNotifier(
          defaults.copyWith(
            notificationsEnabled: true,
            notificationTimeMinutes: 540,
          ),
        );
        await tester.pumpWidget(
          _wrap([settingsNotifierProvider.overrideWith(() => stub)]),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Orario notifica'));
        await tester.pumpAndSettle();

        // Drag the minutes column of CupertinoDatePicker.
        //
        // Layout (800px wide viewport, devicePixelRatio=1):
        //   In 12h time mode there are 3 wheels: [0]=hours, [1]=minutes, [2]=AM/PM.
        //   In 24h mode: [0]=hours, [1]=minutes.
        //   The minutes column center is at x≈400 in both formats.
        //   itemExtent=32; a drag of ≥64px triggers a selection change.
        //   dragFrom(Offset(400, pickerRect.center.dy), ...) targets the
        //   minutes column reliably without assuming wheel index.
        final pickerFinder = find.byType(CupertinoDatePicker);
        final pickerRect = tester.getRect(pickerFinder);
        // 4 scroll items * 32 px/item = 128 px → 3 minute-intervals (+15 min).
        await tester.dragFrom(
          Offset(400, pickerRect.center.dy),
          const Offset(0, -128),
        );
        // pumpAndSettle lets the snap finish AND fires the 250 ms debounce timer
        // (default step is 100 ms, so 3 steps cross the 250 ms window).
        await tester.pumpAndSettle();

        // Autosave must have fired.
        expect(
          stub.savedSettings,
          isNotNull,
          reason: 'Autosave must fire after wheel settles',
        );
        expect(
          stub.savedSettings?.notificationTimeMinutes,
          isNot(540),
          reason: 'Autosave must write a value different from the seed',
        );

        // Tap Ripristina — should resave the original and keep modal open.
        await tester.tap(find.text('Ripristina'));
        await tester.pumpAndSettle();

        expect(
          stub.savedSettings?.notificationTimeMinutes,
          540,
          reason: 'Ripristina must restore the seed value (540)',
        );
        expect(
          find.byType(CupertinoDatePicker),
          findsOneWidget,
          reason: 'Modal must stay open after Ripristina',
        );
        expect(
          find.text('Ripristina'),
          findsOneWidget,
          reason: 'Ripristina button must still be visible',
        );
        expect(
          find.text('Annulla'),
          findsNothing,
          reason: 'Annulla must not exist — replaced by Ripristina',
        );
        debugDefaultTargetPlatformOverride = null;
      },
    );

    testWidgets('OK closes the modal (time)', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final stub = _StubSettingsNotifier(
        defaults.copyWith(
          notificationsEnabled: true,
          notificationTimeMinutes: 540,
        ),
      );
      await tester.pumpWidget(
        _wrap([settingsNotifierProvider.overrideWith(() => stub)]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Orario notifica'));
      await tester.pumpAndSettle();

      // Tap OK without scrolling — modal must close.
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(
        find.byType(CupertinoDatePicker),
        findsNothing,
        reason: 'OK must close the modal',
      );
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets(
      'BUG-008: Ripristina label color is accentFlow (not textSecondary)',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        tester.view.physicalSize = const Size(800, 4000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final stub = _StubSettingsNotifier(
          defaults.copyWith(
            notificationsEnabled: true,
            notificationTimeMinutes: 540,
          ),
        );
        await tester.pumpWidget(
          _wrap([settingsNotifierProvider.overrideWith(() => stub)]),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Orario notifica'));
        await tester.pumpAndSettle();

        // Resolve expected color from the live theme context.
        final ctx = tester.element(find.byType(SettingsScreen));
        final expected = MetraColors.of(ctx).accentFlow;

        final ripristina = tester.widget<Text>(find.text('Ripristina'));
        expect(
          ripristina.style?.color,
          expected,
          reason:
              'Ripristina is an active reset action — must use accentFlow, not textSecondary',
        );

        // FR-11 + §18.10.1 parity rule: Ripristina must match OK weight/size.
        expect(
          ripristina.style?.fontWeight,
          FontWeight.w600,
          reason:
              'FR-11: Ripristina must be w600 — equal semantic weight with OK.',
        );
        expect(
          ripristina.style?.fontSize,
          17,
          reason: 'FR-11: Ripristina fontSize must be 17 pt (parity with OK).',
        );

        // Regression guard: OK must also carry the same three values.
        final ok = tester.widget<Text>(find.text('OK'));
        expect(
          ok.style?.color,
          expected,
          reason: '§18.10.1 parity: OK must use accentFlow (regression guard).',
        );
        expect(
          ok.style?.fontWeight,
          FontWeight.w600,
          reason: '§18.10.1 parity: OK must be w600 (regression guard).',
        );
        expect(
          ok.style?.fontSize,
          17,
          reason:
              '§18.10.1 parity: OK fontSize must be 17 pt (regression guard).',
        );

        debugDefaultTargetPlatformOverride = null;
      },
    );
  });

  group('SettingsScreen — advance picker (CupertinoPicker) behaviour', () {
    testWidgets('tap on Preavviso row opens CupertinoPicker modal',
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

      await tester.tap(find.text('Preavviso'));
      await tester.pumpAndSettle();

      expect(
        find.byType(CupertinoPicker),
        findsOneWidget,
        reason: 'Preavviso row must open CupertinoPicker on all platforms',
      );
      expect(
        find.byType(Dialog),
        findsNothing,
        reason: 'SimpleDialog must not appear on any platform',
      );
    });

    testWidgets(
      'Ripristina resets wheel and resaves original; modal stays open (days)',
      (tester) async {
        tester.view.physicalSize = const Size(800, 4000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        // Seed 3 days → seededIndex = 2. Ripristina must restore to 3.
        final stub = _StubSettingsNotifier(
          defaults.copyWith(
            notificationsEnabled: true,
            notificationDaysBefore: 3,
          ),
        );
        await tester.pumpWidget(
          _wrap([settingsNotifierProvider.overrideWith(() => stub)]),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Preavviso'));
        await tester.pumpAndSettle();

        // Drag 2 items upward on the CupertinoPicker (itemExtent=44 → 88 px).
        final pickerFinder = find.byType(CupertinoPicker);
        await tester.drag(pickerFinder, const Offset(0, -88.0));
        await tester.pumpAndSettle();
        // Without iOS scroll physics the snap animation completes in < 250 ms
        // of fake time. Advance explicitly past the debounce threshold.
        await tester.pump(const Duration(milliseconds: 300));

        // Autosave must have fired.
        expect(
          stub.savedSettings,
          isNotNull,
          reason: 'Autosave must fire after wheel settles',
        );
        expect(
          stub.savedSettings?.notificationDaysBefore,
          isNot(3),
          reason: 'Autosave must write a value different from the seed',
        );

        // Tap Ripristina — should resave original and keep modal open.
        await tester.tap(find.text('Ripristina'));
        await tester.pumpAndSettle();

        expect(
          stub.savedSettings?.notificationDaysBefore,
          3,
          reason: 'Ripristina must restore the seed value (3)',
        );
        expect(
          find.byType(CupertinoPicker),
          findsOneWidget,
          reason: 'Modal must stay open after Ripristina',
        );
        expect(
          find.text('Ripristina'),
          findsOneWidget,
          reason: 'Ripristina button must still be visible',
        );
        expect(
          find.text('Annulla'),
          findsNothing,
          reason: 'Annulla must not exist — replaced by Ripristina',
        );
      },
    );

    testWidgets('OK closes the modal (days)', (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final stub = _StubSettingsNotifier(
        defaults.copyWith(
          notificationsEnabled: true,
          notificationDaysBefore: 3,
        ),
      );
      await tester.pumpWidget(
        _wrap([settingsNotifierProvider.overrideWith(() => stub)]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Preavviso'));
      await tester.pumpAndSettle();

      // Tap OK without scrolling — modal must close.
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(
        find.byType(CupertinoPicker),
        findsNothing,
        reason: 'OK must close the modal',
      );
    });

    testWidgets('shows day labels near center of picker', (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // defaults.notificationDaysBefore=2 → initialItem=1 (index of "2 giorni prima").
      // ListWheelScrollView renders only items near the current scroll position.
      // Verify items reliably in-viewport around index 1: "1 giorno prima"
      // through "5 giorni prima". The last items (6-7) may not be rendered until
      // the wheel is scrolled there.
      final stub = _StubSettingsNotifier(
        defaults.copyWith(notificationsEnabled: true),
      );
      await tester.pumpWidget(
        _wrap([settingsNotifierProvider.overrideWith(() => stub)]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Preavviso'));
      await tester.pumpAndSettle();

      final pickerFinder = find.byType(CupertinoPicker);
      expect(
        pickerFinder,
        findsOneWidget,
        reason: 'CupertinoPicker must be present',
      );

      for (final label in [
        '1 giorno prima',
        '2 giorni prima',
        '3 giorni prima',
        '4 giorni prima',
        '5 giorni prima',
      ]) {
        expect(
          find.descendant(of: pickerFinder, matching: find.text(label)),
          findsAtLeastNWidgets(1),
          reason: 'Day label "$label" must appear in CupertinoPicker',
        );
      }
    });
  });

  // ---------------------------------------------------------------------------
  // NEW autosave / Ripristina / debounce-flush tests
  // ---------------------------------------------------------------------------

  group('SettingsScreen — iOS time picker autosave + debounce', () {
    testWidgets(
      'wheel-stop autosave fires after 250 ms (time)',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        tester.view.physicalSize = const Size(800, 4000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        // Seed 540 (09:00). Drag +3 items in minute column (+15 min → 555).
        final stub = _StubSettingsNotifier(
          defaults.copyWith(
            notificationsEnabled: true,
            notificationTimeMinutes: 540,
          ),
        );
        await tester.pumpWidget(
          _wrap([settingsNotifierProvider.overrideWith(() => stub)]),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Orario notifica'));
        await tester.pumpAndSettle();

        // Drag +15 min: 4 scroll items * 32 px/item = 128 px → 555 min.
        final pickerFinder = find.byType(CupertinoDatePicker);
        final pickerRect = tester.getRect(pickerFinder);
        await tester.dragFrom(
          Offset(400, pickerRect.center.dy),
          const Offset(0, -128),
        );
        // pumpAndSettle fires the 250 ms debounce (default step = 100 ms).
        await tester.pumpAndSettle();

        expect(
          stub.savedSettings?.notificationTimeMinutes,
          555,
          reason: 'Autosave must write 555 (540 + 15 min) after debounce',
        );
        expect(
          find.byType(CupertinoDatePicker),
          findsOneWidget,
          reason: 'Modal must stay open after autosave',
        );
        debugDefaultTargetPlatformOverride = null;
      },
    );

    testWidgets(
      'OK after autosave saves once with last scrolled value (time)',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        tester.view.physicalSize = const Size(800, 4000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        // Seed 540. Drag +10 min (96 px → 550), let autosave fire, then tap OK.
        final stub = _StubSettingsNotifier(
          defaults.copyWith(
            notificationsEnabled: true,
            notificationTimeMinutes: 540,
          ),
        );
        await tester.pumpWidget(
          _wrap([settingsNotifierProvider.overrideWith(() => stub)]),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Orario notifica'));
        await tester.pumpAndSettle();

        final pickerFinder = find.byType(CupertinoDatePicker);
        final pickerRect = tester.getRect(pickerFinder);
        // 96 px → +10 min (550).
        await tester.dragFrom(
          Offset(400, pickerRect.center.dy),
          const Offset(0, -96),
        );
        // pumpAndSettle fires autosave (timer fires during settle).
        await tester.pumpAndSettle();

        // Reset call count; OK must not trigger another save.
        stub.saveCallCount = 0;

        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        expect(
          find.byType(CupertinoDatePicker),
          findsNothing,
          reason: 'OK must close the modal',
        );
        expect(
          stub.savedSettings?.notificationTimeMinutes,
          550,
          reason: 'Last scrolled value (550) must be persisted',
        );
        expect(
          stub.saveCallCount,
          0,
          reason:
              'OK must not trigger an extra save when debounce already fired',
        );
        debugDefaultTargetPlatformOverride = null;
      },
    );

    testWidgets(
      'barrier-dismiss preserves auto-saved value (time)',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        tester.view.physicalSize = const Size(800, 4000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        // Seed 540. Drag +5 min (64 px → 545); let autosave fire, then dismiss.
        final stub = _StubSettingsNotifier(
          defaults.copyWith(
            notificationsEnabled: true,
            notificationTimeMinutes: 540,
          ),
        );
        await tester.pumpWidget(
          _wrap([settingsNotifierProvider.overrideWith(() => stub)]),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Orario notifica'));
        await tester.pumpAndSettle();

        final pickerFinder = find.byType(CupertinoDatePicker);
        final pickerRect = tester.getRect(pickerFinder);
        // 64 px → +5 min (545).
        await tester.dragFrom(
          Offset(400, pickerRect.center.dy),
          const Offset(0, -64),
        );
        // pumpAndSettle fires autosave.
        await tester.pumpAndSettle();

        // Dismiss via barrier tap (top-left corner, above the 310 px popup).
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        expect(
          find.byType(CupertinoDatePicker),
          findsNothing,
          reason: 'Barrier tap must dismiss the modal',
        );
        expect(
          stub.savedSettings?.notificationTimeMinutes,
          545,
          reason:
              'Auto-saved value (545) must NOT be reverted on barrier dismiss',
        );
        debugDefaultTargetPlatformOverride = null;
      },
    );

    testWidgets(
      'tap-OK with debounce still pending flushes synchronously (time)',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        tester.view.physicalSize = const Size(800, 4000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        // Seed 540. Drag +5 min (64 px → 545); pump only 30 ms (debounce
        // still pending at 30 ms < 250 ms), then tap OK.
        final stub = _StubSettingsNotifier(
          defaults.copyWith(
            notificationsEnabled: true,
            notificationTimeMinutes: 540,
          ),
        );
        await tester.pumpWidget(
          _wrap([settingsNotifierProvider.overrideWith(() => stub)]),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Orario notifica'));
        await tester.pumpAndSettle();

        final pickerFinder = find.byType(CupertinoDatePicker);
        final pickerRect = tester.getRect(pickerFinder);
        // 64 px → +5 min (545). onDateTimeChanged fires immediately.
        await tester.dragFrom(
          Offset(400, pickerRect.center.dy),
          const Offset(0, -64),
        );
        // Advance 30 ms — snap settles but 250 ms timer still pending.
        await tester.pump(const Duration(milliseconds: 10));
        await tester.pump(const Duration(milliseconds: 10));
        await tester.pump(const Duration(milliseconds: 10));

        // Tap OK — must synchronously flush the pending debounce.
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        expect(
          find.byType(CupertinoDatePicker),
          findsNothing,
          reason: 'OK must close the modal',
        );
        expect(
          stub.savedSettings?.notificationTimeMinutes,
          545,
          reason: 'OK must synchronously flush pending debounce and save 545',
        );
        expect(
          stub.saveCallCount,
          1,
          reason: 'Exactly one save must occur (the flushed pending debounce)',
        );
        debugDefaultTargetPlatformOverride = null;
      },
    );
  });

  group('SettingsScreen — advance picker autosave + debounce', () {
    testWidgets(
      'wheel-stop autosave fires after 250 ms (days)',
      (tester) async {
        tester.view.physicalSize = const Size(800, 4000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        // Seed 2 days → seededIndex=1. Drag +2 items → index 3 → 4 days.
        final stub = _StubSettingsNotifier(
          defaults.copyWith(
            notificationsEnabled: true,
            notificationDaysBefore: 2,
          ),
        );
        await tester.pumpWidget(
          _wrap([settingsNotifierProvider.overrideWith(() => stub)]),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Preavviso'));
        await tester.pumpAndSettle();

        // Drag 2 items upward (towards higher day numbers).
        // itemExtent=44; drag(Offset(0, -2*44)) → index seededIndex+2 = 3 → 4 days.
        final pickerFinder = find.byType(CupertinoPicker);
        await tester.drag(pickerFinder, const Offset(0, -2 * 44.0));
        await tester.pumpAndSettle();
        // Without iOS scroll physics the snap animation completes in < 250 ms
        // of fake time. Advance explicitly past the debounce threshold.
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          stub.savedSettings?.notificationDaysBefore,
          4,
          reason: 'Autosave must write 4 days after debounce',
        );
        expect(
          find.byType(CupertinoPicker),
          findsOneWidget,
          reason: 'Modal must stay open after autosave',
        );
      },
    );

    testWidgets(
      'OK after autosave saves once with last scrolled value (days)',
      (tester) async {
        tester.view.physicalSize = const Size(800, 4000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        // Seed 2 days. Drag +2 items → 4 days; let autosave fire; then OK.
        final stub = _StubSettingsNotifier(
          defaults.copyWith(
            notificationsEnabled: true,
            notificationDaysBefore: 2,
          ),
        );
        await tester.pumpWidget(
          _wrap([settingsNotifierProvider.overrideWith(() => stub)]),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Preavviso'));
        await tester.pumpAndSettle();

        final pickerFinder = find.byType(CupertinoPicker);
        await tester.drag(pickerFinder, const Offset(0, -2 * 44.0));
        await tester.pumpAndSettle();
        // Without iOS scroll physics the snap animation completes in < 250 ms
        // of fake time. Advance explicitly past the debounce threshold.
        await tester.pump(const Duration(milliseconds: 300));

        // Reset count; OK must not trigger another save.
        stub.saveCallCount = 0;

        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        expect(
          find.byType(CupertinoPicker),
          findsNothing,
          reason: 'OK must close the modal',
        );
        expect(
          stub.savedSettings?.notificationDaysBefore,
          4,
          reason: 'Last scrolled value (4 days) must be persisted',
        );
        expect(
          stub.saveCallCount,
          0,
          reason:
              'OK must not trigger an extra save when debounce already fired',
        );
      },
    );

    testWidgets(
      'tap-OK with debounce still pending flushes synchronously (days)',
      (tester) async {
        tester.view.physicalSize = const Size(800, 4000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        // Seed 2 days. Drag +1 item → 3 days; pump only 30 ms (debounce
        // still pending at 30 ms < 250 ms), then tap OK.
        final stub = _StubSettingsNotifier(
          defaults.copyWith(
            notificationsEnabled: true,
            notificationDaysBefore: 2,
          ),
        );
        await tester.pumpWidget(
          _wrap([settingsNotifierProvider.overrideWith(() => stub)]),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Preavviso'));
        await tester.pumpAndSettle();

        final pickerFinder = find.byType(CupertinoPicker);
        // Drag 1 item upward. onSelectedItemChanged fires immediately.
        await tester.drag(pickerFinder, const Offset(0, -44.0));
        // Advance 30 ms — snap settles but 250 ms timer still pending.
        await tester.pump(const Duration(milliseconds: 10));
        await tester.pump(const Duration(milliseconds: 10));
        await tester.pump(const Duration(milliseconds: 10));

        // Tap OK — must synchronously flush the pending debounce.
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        expect(
          find.byType(CupertinoPicker),
          findsNothing,
          reason: 'OK must close the modal',
        );
        expect(
          stub.savedSettings?.notificationDaysBefore,
          3,
          reason:
              'OK must synchronously flush pending debounce and save 3 days',
        );
        expect(
          stub.saveCallCount,
          1,
          reason: 'Exactly one save must occur (the flushed pending debounce)',
        );
      },
    );
  });

  // Note: the "FR-03 battery-opt row (TASK-07)" group was removed when the
  // "Pianificazione in background" settings row was removed from the UI.
  // The underlying NotificationService.isIgnoringBatteryOptimizations() and
  // openBatteryOptimizationSettings() methods are preserved for future use.
}
