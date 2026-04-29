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

// ---------------------------------------------------------------------------
// Test helper
// ---------------------------------------------------------------------------

Widget _wrap(List<Override> overrides) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: MetraTheme.light(),
      locale: const Locale('it'),
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

      expect(find.text('Preferenze'), findsOneWidget);
      expect(find.text('Registro'), findsOneWidget);
      expect(find.text('Notifiche'), findsOneWidget);
      expect(find.text('Privacy e dati'), findsOneWidget);
      expect(find.text('Zona pericolosa'), findsOneWidget);
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

      expect(find.text('Traccia dolore'), findsOneWidget);
      expect(find.text('Note giornaliere'), findsOneWidget);
    });
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

      // First Switch in the list is the pain toggle (under "Registro")
      await tester.tap(find.byType(Switch).first);
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

      await tester.tap(find.text('Cancella tutti i dati').first);
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

      await tester.tap(find.text('Cancella tutti i dati').first);
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
      await tester.tap(find.text('Cancella tutti i dati').first);
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
  });
}
