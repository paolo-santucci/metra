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
import 'package:metra/core/widgets/button_primary.dart';

Widget _wrap(Widget child, ThemeData theme) => MaterialApp(
      theme: theme,
      home: Scaffold(body: Center(child: child)),
    );

const _testLabel = 'Salva';
const _testSemantics = 'Salva la giornata';

void main() {
  testWidgets('golden — light theme', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const ButtonPrimary(
          label: _testLabel,
          onPressed: null,
          semanticsLabel: _testSemantics,
        ),
        MetraTheme.light(),
      ),
    );
    await expectLater(
      find.byType(ButtonPrimary),
      matchesGoldenFile('goldens/button_primary_light.png'),
    );
  });

  testWidgets('golden — dark theme', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const ButtonPrimary(
          label: _testLabel,
          onPressed: null,
          semanticsLabel: _testSemantics,
        ),
        MetraTheme.dark(),
      ),
    );
    await expectLater(
      find.byType(ButtonPrimary),
      matchesGoldenFile('goldens/button_primary_dark.png'),
    );
  });

  testWidgets('semantics label is correct', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const ButtonPrimary(
          label: _testLabel,
          onPressed: null,
          semanticsLabel: _testSemantics,
        ),
        MetraTheme.light(),
      ),
    );
    final semantics = tester.getSemantics(find.byType(ButtonPrimary));
    expect(semantics.label, _testSemantics);
  });

  testWidgets('minimum tap target size ≥ 44×44', (tester) async {
    await tester.pumpWidget(
      _wrap(
        ButtonPrimary(
          label: _testLabel,
          onPressed: () {},
          semanticsLabel: _testSemantics,
        ),
        MetraTheme.light(),
      ),
    );
    final size = tester.getSize(find.byType(ButtonPrimary));
    expect(size.width, greaterThanOrEqualTo(44));
    expect(size.height, greaterThanOrEqualTo(44));
  });

  testWidgets('fires onPressed when enabled', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _wrap(
        ButtonPrimary(
          label: _testLabel,
          onPressed: () => tapped = true,
          semanticsLabel: _testSemantics,
        ),
        MetraTheme.light(),
      ),
    );
    await tester.tap(find.byType(ButtonPrimary));
    expect(tapped, isTrue);
  });
}
