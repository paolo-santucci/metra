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
import 'package:go_router/go_router.dart';
import 'package:metra/core/theme/metra_theme.dart';
import 'package:metra/domain/entities/daily_log_entity.dart';
import 'package:metra/domain/entities/pain_symptom_data.dart';
import 'package:metra/domain/entities/pain_symptom_type.dart';
import 'package:metra/features/daily_entry/historical_entry_screen.dart';
import 'package:metra/features/daily_entry/state/daily_entry_controller.dart';
import 'package:metra/l10n/app_localizations.dart';
import 'package:metra/providers/repository_providers.dart';

import '../../helpers/fake_daily_log_repository.dart';

// ---------------------------------------------------------------------------
// Fake notifier shared by all tests in this file
// ---------------------------------------------------------------------------

class _FakeNotifier extends DailyEntryNotifier {
  _FakeNotifier(this._initial);

  final DailyLogEntity? _initial;

  @override
  Future<DailyLogEntity?> build(DateTime arg) async => _initial;

  @override
  Future<void> save(DailyLogEntity log) async {
    state = AsyncData(log);
  }

  @override
  Future<void> delete() async {}
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

final _testDate = DateTime.utc(2024, 3, 15);

Widget _buildHistoricalScreen(List<Override> overrides) {
  final router = GoRouter(
    initialLocation: '/calendar',
    routes: [
      GoRoute(
        path: '/calendar',
        builder: (_, __) => Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () => ctx.push('/history'),
              child: const Text('open'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/history',
        builder: (_, __) => HistoricalEntryScreen(date: _testDate),
      ),
    ],
  );

  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(
      theme: MetraTheme.light(),
      locale: const Locale('it'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

Future<void> _navigate(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests — HistoricalEntryScreen (representative screen for both; logic is
// identical on TodayScreen)
// ---------------------------------------------------------------------------

void main() {
  group('Custom symptom — add flow', () {
    testWidgets('typing and confirming shows the label as a chip',
        (tester) async {
      final fakeNotifier = _FakeNotifier(null);
      final fakeRepo = FakeDailyLogRepository();

      await tester.pumpWidget(
        _buildHistoricalScreen([
          dailyEntryProvider.overrideWith(() => fakeNotifier),
          painSymptomsProvider.overrideWith((ref, date) async => []),
          dailyLogRepositoryProvider.overrideWith((_) async => fakeRepo),
        ]),
      );
      await tester.pumpAndSettle();
      await _navigate(tester);

      await tester.tap(find.text('Aggiungi'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Vertigini');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.text('Vertigini'), findsOneWidget);
      expect(find.text('Aggiungi'), findsOneWidget);
    });

    testWidgets('save persists custom label via replacePainSymptoms',
        (tester) async {
      final fakeNotifier = _FakeNotifier(null);
      final fakeRepo = FakeDailyLogRepository();

      await tester.pumpWidget(
        _buildHistoricalScreen([
          dailyEntryProvider.overrideWith(() => fakeNotifier),
          painSymptomsProvider.overrideWith((ref, date) async => []),
          dailyLogRepositoryProvider.overrideWith((_) async => fakeRepo),
        ]),
      );
      await tester.pumpAndSettle();
      await _navigate(tester);

      await tester.tap(find.text('Aggiungi'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Vertigini');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Salva giornata'));
      await tester.tap(find.text('Salva giornata'));
      await tester.pumpAndSettle();

      expect(
        fakeRepo.symptoms[_testDate],
        contains(
          const PainSymptomData(
            symptomType: PainSymptomType.custom,
            customLabel: 'Vertigini',
          ),
        ),
      );
    });

    testWidgets('empty confirm does not add a chip', (tester) async {
      final fakeNotifier = _FakeNotifier(null);
      final fakeRepo = FakeDailyLogRepository();

      await tester.pumpWidget(
        _buildHistoricalScreen([
          dailyEntryProvider.overrideWith(() => fakeNotifier),
          painSymptomsProvider.overrideWith((ref, date) async => []),
          dailyLogRepositoryProvider.overrideWith((_) async => fakeRepo),
        ]),
      );
      await tester.pumpAndSettle();
      await _navigate(tester);

      await tester.tap(find.text('Aggiungi'));
      await tester.pumpAndSettle();

      // Confirm with nothing typed.
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // The inline input closes, + Aggiungi returns, no new chip text visible
      // except the 7 fixed labels. Custom chip "Vertigini" (or anything) absent.
      expect(find.text('Aggiungi'), findsOneWidget);
      // Chip count should be exactly the 7 fixed labels.
      expect(find.text('Crampi'), findsOneWidget);
    });

    testWidgets('duplicate label (case-insensitive) is silently rejected',
        (tester) async {
      final fakeNotifier = _FakeNotifier(null);
      final fakeRepo = FakeDailyLogRepository();

      await tester.pumpWidget(
        _buildHistoricalScreen([
          dailyEntryProvider.overrideWith(() => fakeNotifier),
          painSymptomsProvider.overrideWith((ref, date) async => []),
          dailyLogRepositoryProvider.overrideWith((_) async => fakeRepo),
        ]),
      );
      await tester.pumpAndSettle();
      await _navigate(tester);

      // Add once.
      await tester.tap(find.text('Aggiungi'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Vertigini');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Try to add again with different casing.
      await tester.tap(find.text('Aggiungi'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'vertigini');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Still only one 'Vertigini' chip.
      expect(find.text('Vertigini'), findsOneWidget);
    });

    testWidgets('fixed label (case-insensitive) is silently rejected',
        (tester) async {
      final fakeNotifier = _FakeNotifier(null);
      final fakeRepo = FakeDailyLogRepository();

      await tester.pumpWidget(
        _buildHistoricalScreen([
          dailyEntryProvider.overrideWith(() => fakeNotifier),
          painSymptomsProvider.overrideWith((ref, date) async => []),
          dailyLogRepositoryProvider.overrideWith((_) async => fakeRepo),
        ]),
      );
      await tester.pumpAndSettle();
      await _navigate(tester);

      await tester.tap(find.text('Aggiungi'));
      await tester.pumpAndSettle();
      // 'crampi' matches the fixed label 'Crampi'.
      await tester.enterText(find.byType(TextField).first, 'crampi');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Only one 'Crampi' chip (the fixed one), no custom chip added.
      expect(find.text('Crampi'), findsOneWidget);
    });
  });

  group('Custom symptom — remove flow', () {
    testWidgets('tapping a custom chip removes it', (tester) async {
      final fakeNotifier = _FakeNotifier(null);
      final fakeRepo = FakeDailyLogRepository();

      await tester.pumpWidget(
        _buildHistoricalScreen([
          dailyEntryProvider.overrideWith(() => fakeNotifier),
          // Pre-load a custom symptom.
          painSymptomsProvider.overrideWith(
            (ref, date) async => [
              const PainSymptomData(
                symptomType: PainSymptomType.custom,
                customLabel: 'Vertigini',
              ),
            ],
          ),
          dailyLogRepositoryProvider.overrideWith((_) async => fakeRepo),
        ]),
      );
      await tester.pumpAndSettle();
      await _navigate(tester);

      expect(find.text('Vertigini'), findsOneWidget);

      await tester.tap(find.text('Vertigini'));
      await tester.pumpAndSettle();

      expect(find.text('Vertigini'), findsNothing);
    });

    testWidgets('removed chip is absent from replacePainSymptoms call',
        (tester) async {
      final fakeNotifier = _FakeNotifier(null);
      final fakeRepo = FakeDailyLogRepository();

      await tester.pumpWidget(
        _buildHistoricalScreen([
          dailyEntryProvider.overrideWith(() => fakeNotifier),
          painSymptomsProvider.overrideWith(
            (ref, date) async => [
              const PainSymptomData(
                symptomType: PainSymptomType.custom,
                customLabel: 'Vertigini',
              ),
            ],
          ),
          dailyLogRepositoryProvider.overrideWith((_) async => fakeRepo),
        ]),
      );
      await tester.pumpAndSettle();
      await _navigate(tester);

      await tester.tap(find.text('Vertigini'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Salva giornata'));
      await tester.tap(find.text('Salva giornata'));
      await tester.pumpAndSettle();

      final saved = fakeRepo.symptoms[_testDate] ?? [];
      expect(
        saved.any(
          (s) =>
              s.symptomType == PainSymptomType.custom &&
              s.customLabel == 'Vertigini',
        ),
        isFalse,
      );
    });
  });

  group('Custom symptom — hydration', () {
    testWidgets('existing custom symptom shows chip on screen load',
        (tester) async {
      final fakeNotifier = _FakeNotifier(null);
      final fakeRepo = FakeDailyLogRepository();

      await tester.pumpWidget(
        _buildHistoricalScreen([
          dailyEntryProvider.overrideWith(() => fakeNotifier),
          painSymptomsProvider.overrideWith(
            (ref, date) async => [
              const PainSymptomData(
                symptomType: PainSymptomType.custom,
                customLabel: 'Vertigini',
              ),
            ],
          ),
          dailyLogRepositoryProvider.overrideWith((_) async => fakeRepo),
        ]),
      );
      await tester.pumpAndSettle();
      await _navigate(tester);

      expect(find.text('Vertigini'), findsOneWidget);
    });

    testWidgets(
        'custom symptom round-trips: hydrate then save preserves the label',
        (tester) async {
      final fakeNotifier = _FakeNotifier(null);
      final fakeRepo = FakeDailyLogRepository();

      await tester.pumpWidget(
        _buildHistoricalScreen([
          dailyEntryProvider.overrideWith(() => fakeNotifier),
          painSymptomsProvider.overrideWith(
            (ref, date) async => [
              const PainSymptomData(
                symptomType: PainSymptomType.custom,
                customLabel: 'Insonnia',
              ),
            ],
          ),
          dailyLogRepositoryProvider.overrideWith((_) async => fakeRepo),
        ]),
      );
      await tester.pumpAndSettle();
      await _navigate(tester);

      await tester.ensureVisible(find.text('Salva giornata'));
      await tester.tap(find.text('Salva giornata'));
      await tester.pumpAndSettle();

      expect(
        fakeRepo.symptoms[_testDate],
        contains(
          const PainSymptomData(
            symptomType: PainSymptomType.custom,
            customLabel: 'Insonnia',
          ),
        ),
      );
    });
  });
}
