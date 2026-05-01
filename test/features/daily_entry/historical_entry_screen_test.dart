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
import 'package:metra/features/daily_entry/historical_entry_screen.dart';
import 'package:metra/features/daily_entry/state/daily_entry_controller.dart';
import 'package:metra/l10n/app_localizations.dart';
import 'package:metra/providers/repository_providers.dart';

import '../../helpers/fake_daily_log_repository.dart';

// ---------------------------------------------------------------------------
// Fake notifiers
// ---------------------------------------------------------------------------

class _FakeHistoricalEntryNotifier extends DailyEntryNotifier {
  _FakeHistoricalEntryNotifier(this._initial);

  final DailyLogEntity? _initial;
  DailyLogEntity? lastSaved;

  @override
  Future<DailyLogEntity?> build(DateTime arg) async => _initial;

  @override
  Future<void> save(DailyLogEntity log) async {
    lastSaved = log;
    state = AsyncData(log);
  }

  @override
  Future<void> delete() async {}
}

class _ErrorHistoricalEntryNotifier extends DailyEntryNotifier {
  @override
  Future<DailyLogEntity?> build(DateTime arg) async =>
      throw Exception('test error');

  @override
  Future<void> save(DailyLogEntity log) async {}

  @override
  Future<void> delete() async {}
}

// ---------------------------------------------------------------------------
// Test helper
// ---------------------------------------------------------------------------

final _testDate = DateTime.utc(2024, 3, 15);

Widget _wrapWithRouter(List<Override> overrides) {
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
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('HistoricalEntryScreen — C-1 round-trip', () {
    testWidgets('existing log with otherDischarge=true preserves flag on save',
        (tester) async {
      final existingLog = DailyLogEntity(
        date: _testDate,
        otherDischarge: true,
      );
      final fakeNotifier = _FakeHistoricalEntryNotifier(existingLog);
      final fakeRepo = FakeDailyLogRepository()..savedLogs.add(existingLog);

      await tester.pumpWidget(
        _wrapWithRouter([
          dailyEntryProvider.overrideWith(() => fakeNotifier),
          painSymptomsProvider.overrideWith((ref, date) async => []),
          dailyLogRepositoryProvider.overrideWith((_) async => fakeRepo),
        ]),
      );
      await tester.pumpAndSettle();
      await _navigate(tester);

      await tester.tap(find.text('Salva giornata'));
      await tester.pumpAndSettle();

      expect(fakeNotifier.lastSaved?.otherDischarge, isTrue);
    });

    testWidgets('pain deselected via CirclePainPicker clears painIntensity',
        (tester) async {
      final existingLog = DailyLogEntity(
        date: _testDate,
        painEnabled: true,
        painIntensity: 2,
      );
      final fakeNotifier = _FakeHistoricalEntryNotifier(existingLog);
      final fakeRepo = FakeDailyLogRepository()..savedLogs.add(existingLog);

      await tester.pumpWidget(
        _wrapWithRouter([
          dailyEntryProvider.overrideWith(() => fakeNotifier),
          painSymptomsProvider.overrideWith((ref, date) async => []),
          dailyLogRepositoryProvider.overrideWith((_) async => fakeRepo),
        ]),
      );
      await tester.pumpAndSettle();
      await _navigate(tester);

      // Tap the already-selected "Moderato" circle to deselect pain.
      await tester.tap(find.text('Moderato'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Salva giornata'));
      await tester.pumpAndSettle();

      expect(fakeNotifier.lastSaved?.painEnabled, isFalse);
      expect(fakeNotifier.lastSaved?.painIntensity, isNull);
    });
  });

  group('HistoricalEntryScreen — I-4 accessibility', () {
    testWidgets('error state is wrapped in Semantics with liveRegion: true',
        (tester) async {
      final fakeRepo = FakeDailyLogRepository();

      await tester.pumpWidget(
        _wrapWithRouter([
          dailyEntryProvider.overrideWith(_ErrorHistoricalEntryNotifier.new),
          painSymptomsProvider.overrideWith((ref, date) async => []),
          dailyLogRepositoryProvider.overrideWith((_) async => fakeRepo),
        ]),
      );
      await tester.pumpAndSettle();
      await _navigate(tester);

      final semanticsWidgets = tester.widgetList<Semantics>(
        find.byType(Semantics),
      );
      final hasLiveRegion = semanticsWidgets.any(
        (s) => s.properties.liveRegion == true,
      );
      expect(hasLiveRegion, isTrue);
    });
  });
}
