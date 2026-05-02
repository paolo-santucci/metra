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
import 'package:metra/core/widgets/metra_tab_bar.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('MetraTabBar', () {
    testWidgets('renders exactly 84 dp high', (tester) async {
      await tester.pumpWidget(
        _wrap(MetraTabBar(currentIndex: 0, onTabSelected: (_) {})),
      );
      final size = tester.getSize(find.byType(MetraTabBar));
      expect(size.height, equals(84.0));
    });

    testWidgets('contains a BackdropFilter', (tester) async {
      await tester.pumpWidget(
        _wrap(MetraTabBar(currentIndex: 0, onTabSelected: (_) {})),
      );
      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('contains no Material NavigationBar', (tester) async {
      await tester.pumpWidget(
        _wrap(MetraTabBar(currentIndex: 0, onTabSelected: (_) {})),
      );
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('shows 4 tab items', (tester) async {
      await tester.pumpWidget(
        _wrap(MetraTabBar(currentIndex: 0, onTabSelected: (_) {})),
      );
      expect(find.byType(GestureDetector), findsNWidgets(4));
    });

    testWidgets('calls onTabSelected with correct index on tap', (tester) async {
      int? tapped;
      await tester.pumpWidget(
        _wrap(
          MetraTabBar(
            currentIndex: 0,
            onTabSelected: (i) => tapped = i,
          ),
        ),
      );
      final gestures = find.byType(GestureDetector);
      await tester.tap(gestures.at(2));
      expect(tapped, equals(2));
    });

    testWidgets('shows all Italian tab labels', (tester) async {
      await tester.pumpWidget(
        _wrap(MetraTabBar(currentIndex: 0, onTabSelected: (_) {})),
      );
      expect(find.text('Calendario'), findsOneWidget);
      expect(find.text('Oggi'), findsNothing);
      expect(find.text('Archivio'), findsOneWidget);
      expect(find.text('Statistiche'), findsOneWidget);
      expect(find.text('Impostazioni'), findsOneWidget);
    });
  });
}
