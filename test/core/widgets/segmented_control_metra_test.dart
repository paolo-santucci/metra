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
import 'package:metra/core/widgets/segmented_control_metra.dart';

Widget _wrap(Widget child, ThemeData theme) => MaterialApp(
      theme: theme,
      home: Scaffold(body: Center(child: child)),
    );

const _segments = ['Lista', 'Tabella'];

void main() {
  testWidgets('golden — light theme index 0 selected', (tester) async {
    await tester.pumpWidget(
      _wrap(
        SegmentedControlMetra(
          segments: _segments,
          selectedIndex: 0,
          onChanged: (_) {},
        ),
        MetraTheme.light(),
      ),
    );
    await expectLater(
      find.byType(SegmentedControlMetra),
      matchesGoldenFile('goldens/segmented_control_metra_light.png'),
    );
  });

  testWidgets('golden — dark theme index 1 selected', (tester) async {
    await tester.pumpWidget(
      _wrap(
        SegmentedControlMetra(
          segments: _segments,
          selectedIndex: 1,
          onChanged: (_) {},
        ),
        MetraTheme.dark(),
      ),
    );
    await expectLater(
      find.byType(SegmentedControlMetra),
      matchesGoldenFile('goldens/segmented_control_metra_dark.png'),
    );
  });

  testWidgets('onChanged fires with correct index', (tester) async {
    int? received;
    await tester.pumpWidget(
      _wrap(
        SegmentedControlMetra(
          segments: _segments,
          selectedIndex: 0,
          onChanged: (i) => received = i,
        ),
        MetraTheme.light(),
      ),
    );
    // Tap the second segment.
    await tester.tap(find.text('Tabella'));
    expect(received, 1);
  });

  testWidgets('renders correct number of segments', (tester) async {
    await tester.pumpWidget(
      _wrap(
        SegmentedControlMetra(
          segments: const ['A', 'B', 'C'],
          selectedIndex: 0,
          onChanged: (_) {},
        ),
        MetraTheme.light(),
      ),
    );
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('C'), findsOneWidget);
  });
}
