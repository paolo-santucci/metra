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
import 'package:metra/domain/entities/flow_intensity.dart';
import 'package:metra/domain/entities/pain_symptom_type.dart';
import 'package:metra/features/stats/state/stats_controller.dart';
import 'package:metra/features/stats/stats_screen.dart';
import 'package:metra/features/stats/widgets/cycle_length_chart.dart';
import 'package:metra/features/stats/widgets/flow_intensity_chart.dart';
import 'package:metra/features/stats/widgets/period_length_chart.dart';
import 'package:metra/features/stats/widgets/symptom_frequency_chart.dart';
import 'package:metra/l10n/app_localizations.dart';

// Fake notifiers — extend StatsNotifier and override build().
// Do NOT call super.build() — these are pure stubs.

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

// Helper: wrap StatsScreen with ProviderScope + MaterialApp
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

// Minimal CycleStatsData with 2 data points
CycleStatsData _makeStatsData() => CycleStatsData(
      points: [
        CycleDataPoint(
          startDate: DateTime.utc(2026, 1, 10),
          cycleLength: 28,
          periodLength: 5,
          dominantFlow: FlowIntensity.medium,
        ),
        CycleDataPoint(
          startDate: DateTime.utc(2026, 2, 7),
          cycleLength: 30,
          periodLength: 6,
          dominantFlow: FlowIntensity.light,
        ),
      ],
      symptomFrequencies: {
        PainSymptomType.cramps: 0.8,
        PainSymptomType.backPain: 0.4,
        PainSymptomType.headache: 0.2,
        PainSymptomType.migraine: 0.1,
        PainSymptomType.bloating: 0.5,
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
    testWidgets('shows insufficient data text in all four stat cards',
        (tester) async {
      await tester.pumpWidget(
        _wrap([statsProvider.overrideWith(() => _DataNotifier(null))]),
      );
      await tester.pumpAndSettle();
      expect(find.text('Dati insufficienti'), findsNWidgets(4));
    });
  });

  group('StatsScreen — with data', () {
    testWidgets('renders four chart widgets when data is available',
        (tester) async {
      await tester.pumpWidget(
        _wrap([
          statsProvider.overrideWith(() => _DataNotifier(_makeStatsData())),
        ]),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CycleLengthChart), findsOneWidget);
      expect(find.byType(PeriodLengthChart), findsOneWidget);
      expect(find.byType(SymptomFrequencyChart), findsOneWidget);
      expect(find.byType(FlowIntensityChart), findsOneWidget);
    });

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
  });
}
