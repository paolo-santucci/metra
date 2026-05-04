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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/theme/metra_theme.dart';
import 'package:metra/domain/entities/cycle_stats_data.dart';
import 'package:metra/domain/entities/pain_symptom_type.dart';
import 'package:metra/features/stats/state/stats_controller.dart';
import 'package:metra/features/stats/stats_screen.dart';
import 'package:metra/features/stats/widgets/mini_bar_chart.dart';
import 'package:metra/features/stats/widgets/stat_card.dart';
import 'package:metra/features/stats/widgets/symptom_frequency_chart.dart';
import 'package:metra/l10n/app_localizations.dart';

class _LoadingNotifier extends StatsNotifier {
  @override
  Future<CycleStatsData?> build() => Completer<CycleStatsData?>().future;
}

class _ErrorNotifier extends StatsNotifier {
  @override
  Future<CycleStatsData?> build() async => throw Exception('test error');
}

class _DataNotifier extends StatsNotifier {
  _DataNotifier(this._data);
  final CycleStatsData? _data;
  @override
  Future<CycleStatsData?> build() async => _data;
}

Widget _wrap(List<Override> overrides) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: MetraTheme.light(),
      locale: const Locale('it'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const StatsScreen(),
    ),
  );
}

CycleStatsData _makeStatsData() => CycleStatsData(
      points: [
        CycleDataPoint(
          startDate: DateTime.utc(2026, 1, 10),
          cycleLength: 28,
          periodLength: 5,
        ),
        CycleDataPoint(
          startDate: DateTime.utc(2026, 2, 7),
          cycleLength: 30,
          periodLength: 6,
        ),
        CycleDataPoint(
          startDate: DateTime.utc(2026, 3, 9),
          cycleLength: 29,
          periodLength: 5,
        ),
      ],
      cycleLengthAvg: 29,
      cycleLengthMin: 28,
      cycleLengthMax: 30,
      periodLengthAvg: 5.3,
      periodLengthMin: 5,
      periodLengthMax: 6,
      painIntensityAvg: null,
      painTrend: null,
      cyclesTrackedCount: 3,
      symptomCounts: {
        PainSymptomType.backPain: 2,
        PainSymptomType.headache: 0,
        PainSymptomType.migraine: 0,
        PainSymptomType.bloating: 1,
        PainSymptomType.fatigue: 1,
        PainSymptomType.nausea: 0,
        PainSymptomType.breastTenderness: 0,
      },
    );

void main() {
  group('StatsScreen — loading', () {
    testWidgets('shows spinner while loading', (tester) async {
      await tester.pumpWidget(
        _wrap([statsProvider.overrideWith(_LoadingNotifier.new)]),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('StatsScreen — error', () {
    testWidgets('shows error text on failure', (tester) async {
      await tester.pumpWidget(
        _wrap([statsProvider.overrideWith(_ErrorNotifier.new)]),
      );
      await tester.pumpAndSettle();
      expect(find.text('Qualcosa è andato storto. Riprova.'), findsOneWidget);
    });
  });

  group('StatsScreen — null data', () {
    testWidgets('shows insufficient data text', (tester) async {
      await tester.pumpWidget(
        _wrap([statsProvider.overrideWith(() => _DataNotifier(null))]),
      );
      await tester.pumpAndSettle();
      expect(find.text('Dati insufficienti'), findsOneWidget);
    });
  });

  group('StatsScreen — with data', () {
    testWidgets('does not show insufficient data text when data is present',
        (tester) async {
      await tester.pumpWidget(
        _wrap([
          statsProvider.overrideWith(() => _DataNotifier(_makeStatsData())),
        ]),
      );
      await tester.pumpAndSettle();
      expect(find.text('Dati insufficienti'), findsNothing);
    });

    testWidgets('renders StatSummaryCard widgets', (tester) async {
      await tester.pumpWidget(
        _wrap([
          statsProvider.overrideWith(() => _DataNotifier(_makeStatsData())),
        ]),
      );
      await tester.pumpAndSettle();
      expect(find.byType(StatSummaryCard), findsWidgets);
    });

    testWidgets('renders MiniBarChart widgets', (tester) async {
      await tester.pumpWidget(
        _wrap([
          statsProvider.overrideWith(() => _DataNotifier(_makeStatsData())),
        ]),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MiniBarChart), findsWidgets);
    });

    testWidgets('renders SymptomFrequencyChart widget', (tester) async {
      await tester.pumpWidget(
        _wrap([
          statsProvider.overrideWith(() => _DataNotifier(_makeStatsData())),
        ]),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SymptomFrequencyChart), findsOneWidget);
    });

    testWidgets('header shows title Statistiche', (tester) async {
      await tester.pumpWidget(
        _wrap([
          statsProvider.overrideWith(() => _DataNotifier(_makeStatsData())),
        ]),
      );
      await tester.pumpAndSettle();
      expect(find.text('Statistiche'), findsOneWidget);
    });

    testWidgets('header shows subtitle Ultimi 6 cicli', (tester) async {
      await tester.pumpWidget(
        _wrap([
          statsProvider.overrideWith(() => _DataNotifier(_makeStatsData())),
        ]),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ultimi 6 cicli'), findsOneWidget);
    });
  });
}
