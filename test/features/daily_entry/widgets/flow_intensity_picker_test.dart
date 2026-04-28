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
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/theme/metra_theme.dart';
import 'package:metra/domain/entities/flow_intensity.dart';
import 'package:metra/features/daily_entry/widgets/flow_intensity_picker.dart';
import 'package:metra/l10n/app_localizations.dart';

Widget _wrap({
  FlowIntensity? selectedFlow,
  bool isSpotting = false,
  ValueChanged<FlowIntensity?>? onFlowChanged,
  ValueChanged<bool>? onSpottingChanged,
}) =>
    MaterialApp(
      theme: MetraTheme.light(),
      locale: const Locale('it'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: FlowIntensityPicker(
          selectedFlow: selectedFlow,
          isSpotting: isSpotting,
          onFlowChanged: onFlowChanged ?? (_) {},
          onSpottingChanged: onSpottingChanged ?? (_) {},
        ),
      ),
    );

void main() {
  group('FlowIntensityPicker', () {
    testWidgets('renders all flow chips and spotting chip', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      expect(find.text('Spotting'), findsOneWidget);
      expect(find.text('Nessun flusso'), findsOneWidget);
      expect(find.text('Flusso leggero'), findsOneWidget);
      expect(find.text('Flusso moderato'), findsOneWidget);
      expect(find.text('Flusso intenso'), findsOneWidget);
      expect(find.text('Flusso molto intenso'), findsOneWidget);
    });

    testWidgets('tapping a flow chip fires onFlowChanged with correct FlowIntensity',
        (tester) async {
      FlowIntensity? captured;
      await tester.pumpWidget(
        _wrap(onFlowChanged: (f) => captured = f),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Flusso leggero'));
      await tester.pumpAndSettle();

      expect(captured, equals(FlowIntensity.light));
    });

    testWidgets('tapping spotting chip fires onSpottingChanged(true)',
        (tester) async {
      bool? spottingCaptured;
      await tester.pumpWidget(
        _wrap(onSpottingChanged: (s) => spottingCaptured = s),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Spotting'));
      await tester.pumpAndSettle();

      expect(spottingCaptured, isTrue);
    });

    testWidgets(
        'selecting flow when spotting is active clears spotting',
        (tester) async {
      FlowIntensity? flowCapture;
      bool? spottingCapture;

      await tester.pumpWidget(
        _wrap(
          isSpotting: true,
          onFlowChanged: (f) => flowCapture = f,
          onSpottingChanged: (s) => spottingCapture = s,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Flusso moderato'));
      await tester.pumpAndSettle();

      // Selecting a flow chip calls onSpottingChanged(false) before onFlowChanged.
      expect(spottingCapture, isFalse);
      expect(flowCapture, equals(FlowIntensity.medium));
    });

    testWidgets('selecting spotting when flow is active clears flow',
        (tester) async {
      FlowIntensity? flowCapture;
      bool? spottingCapture;

      await tester.pumpWidget(
        _wrap(
          selectedFlow: FlowIntensity.heavy,
          onFlowChanged: (f) => flowCapture = f,
          onSpottingChanged: (s) => spottingCapture = s,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Spotting'));
      await tester.pumpAndSettle();

      expect(flowCapture, isNull);
      expect(spottingCapture, isTrue);
    });

    testWidgets(
        'deselecting the currently selected flow chip fires onFlowChanged(null)',
        (tester) async {
      FlowIntensity? flowCapture = FlowIntensity.medium; // non-null sentinel

      await tester.pumpWidget(
        _wrap(
          selectedFlow: FlowIntensity.medium,
          onFlowChanged: (f) => flowCapture = f,
        ),
      );
      await tester.pumpAndSettle();

      // Tap the already-selected chip — should deselect.
      await tester.tap(find.text('Flusso moderato'));
      await tester.pumpAndSettle();

      expect(flowCapture, isNull);
    });
  });
}
