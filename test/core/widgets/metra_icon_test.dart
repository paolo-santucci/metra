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
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/widgets/metra_icon.dart';
import 'package:metra/core/widgets/moon.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('MetraIcon', () {
    testWidgets('renders at the requested size', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const MetraIcon(svgBody: MetraIcons.calendar, size: 32),
        ),
      );
      final svg = tester.widget<SvgPicture>(find.byType(SvgPicture).first);
      expect(svg.width, 32.0);
      expect(svg.height, 32.0);
    });

    testWidgets('defaults to size 24', (tester) async {
      await tester.pumpWidget(
        _wrap(const MetraIcon(svgBody: MetraIcons.wave)),
      );
      final svg = tester.widget<SvgPicture>(find.byType(SvgPicture).first);
      expect(svg.width, 24.0);
      expect(svg.height, 24.0);
    });

    testWidgets('accepts an explicit color without throwing', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const MetraIcon(
            svgBody: MetraIcons.chevronRight,
            color: Colors.red,
          ),
        ),
      );
      expect(find.byType(SvgPicture), findsOneWidget);
    });

    testWidgets('filled variant renders without throwing', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const MetraIcon(
            svgBody: MetraIcons.dropFilled,
            color: Color(0xFFC87456),
            filled: true,
          ),
        ),
      );
      expect(find.byType(SvgPicture), findsOneWidget);
    });

    testWidgets('renders all required stroke icons without throwing',
        (tester) async {
      const icons = [
        MetraIcons.chevronLeft,
        MetraIcons.chevronRight,
        MetraIcons.calendar,
        MetraIcons.note,
        MetraIcons.wave,
        MetraIcons.chart,
        MetraIcons.settings,
        MetraIcons.drop,
        MetraIcons.x,
        MetraIcons.plus,
        MetraIcons.check,
        MetraIcons.moonCrescent,
        MetraIcons.starSmall,
      ];
      for (final icon in icons) {
        await tester.pumpWidget(_wrap(MetraIcon(svgBody: icon)));
        expect(
          find.byType(SvgPicture),
          findsOneWidget,
          reason: 'Icon "$icon" did not render',
        );
      }
    });

    testWidgets('renders all DataIcon variants without throwing',
        (tester) async {
      const dataIcons = [
        MetraIcons.dropFilled,
        MetraIcons.dropOutline,
        MetraIcons.moonCrescentFilled,
        MetraIcons.starSmallFilled,
        MetraIcons.zapFilled,
      ];
      for (final icon in dataIcons) {
        await tester.pumpWidget(
          _wrap(MetraIcon(svgBody: icon, color: const Color(0xFFC87456))),
        );
        expect(
          find.byType(SvgPicture),
          findsOneWidget,
          reason: 'DataIcon "$icon" did not render',
        );
      }
    });
  });

  group('MetraMoon', () {
    for (final phase in [0, 1, 2, 3, 4]) {
      testWidgets('phase $phase renders without throwing', (tester) async {
        await tester.pumpWidget(
          _wrap(MetraMoon(phase: phase)),
        );
        expect(find.byType(SvgPicture), findsOneWidget);
      });
    }

    testWidgets('clamps phase above 4 without throwing', (tester) async {
      await tester.pumpWidget(_wrap(const MetraMoon(phase: 99)));
      expect(find.byType(SvgPicture), findsOneWidget);
    });

    testWidgets('clamps phase below 0 without throwing', (tester) async {
      await tester.pumpWidget(_wrap(const MetraMoon(phase: -1)));
      expect(find.byType(SvgPicture), findsOneWidget);
    });

    testWidgets('renders at custom size', (tester) async {
      await tester.pumpWidget(
        _wrap(const MetraMoon(phase: 2, size: 40)),
      );
      final svg = tester.widget<SvgPicture>(find.byType(SvgPicture).first);
      expect(svg.width, 40.0);
      expect(svg.height, 40.0);
    });

    testWidgets('accepts a custom color without throwing', (tester) async {
      await tester.pumpWidget(
        _wrap(const MetraMoon(phase: 4, color: Color(0xFF9E7488))),
      );
      expect(find.byType(SvgPicture), findsOneWidget);
    });
  });
}
