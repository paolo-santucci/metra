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
import 'package:metra/core/widgets/choice_chip_metra.dart';

Widget _wrap(Widget child, ThemeData theme) => MaterialApp(
      theme: theme,
      home: Scaffold(body: Center(child: child)),
    );

const _testLabel = 'Crampi';
const _testSemantics = 'Crampi, selezionato';
const _testSemanticsUnselected = 'Crampi, non selezionato';

void main() {
  testWidgets('golden — light unselected', (tester) async {
    await tester.pumpWidget(
      _wrap(
        ChoiceChipMetra(
          label: _testLabel,
          selected: false,
          onSelected: (_) {},
          semanticsLabel: _testSemanticsUnselected,
        ),
        MetraTheme.light(),
      ),
    );
    await expectLater(
      find.byType(ChoiceChipMetra),
      matchesGoldenFile('goldens/choice_chip_metra_light_unselected.png'),
    );
  });

  testWidgets('golden — light selected', (tester) async {
    await tester.pumpWidget(
      _wrap(
        ChoiceChipMetra(
          label: _testLabel,
          selected: true,
          onSelected: (_) {},
          semanticsLabel: _testSemantics,
        ),
        MetraTheme.light(),
      ),
    );
    await expectLater(
      find.byType(ChoiceChipMetra),
      matchesGoldenFile('goldens/choice_chip_metra_light_selected.png'),
    );
  });

  testWidgets('golden — dark selected', (tester) async {
    await tester.pumpWidget(
      _wrap(
        ChoiceChipMetra(
          label: _testLabel,
          selected: true,
          onSelected: (_) {},
          semanticsLabel: _testSemantics,
        ),
        MetraTheme.dark(),
      ),
    );
    await expectLater(
      find.byType(ChoiceChipMetra),
      matchesGoldenFile('goldens/choice_chip_metra_dark_selected.png'),
    );
  });

  testWidgets('semantics label is correct', (tester) async {
    await tester.pumpWidget(
      _wrap(
        ChoiceChipMetra(
          label: _testLabel,
          selected: true,
          onSelected: (_) {},
          semanticsLabel: _testSemantics,
        ),
        MetraTheme.light(),
      ),
    );
    final semantics = tester.getSemantics(find.byType(ChoiceChipMetra));
    expect(semantics.label, _testSemantics);
  });

  testWidgets('minimum tap target size ≥ 44×44', (tester) async {
    await tester.pumpWidget(
      _wrap(
        ChoiceChipMetra(
          label: _testLabel,
          selected: false,
          onSelected: (_) {},
          semanticsLabel: _testSemanticsUnselected,
        ),
        MetraTheme.light(),
      ),
    );
    final size = tester.getSize(find.byType(ChoiceChipMetra));
    expect(size.width, greaterThanOrEqualTo(44));
    expect(size.height, greaterThanOrEqualTo(44));
  });

  testWidgets('check icon visible when selected', (tester) async {
    await tester.pumpWidget(
      _wrap(
        ChoiceChipMetra(
          label: _testLabel,
          selected: true,
          onSelected: (_) {},
          semanticsLabel: _testSemantics,
        ),
        MetraTheme.light(),
      ),
    );
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('no check icon when unselected', (tester) async {
    await tester.pumpWidget(
      _wrap(
        ChoiceChipMetra(
          label: _testLabel,
          selected: false,
          onSelected: (_) {},
          semanticsLabel: _testSemanticsUnselected,
        ),
        MetraTheme.light(),
      ),
    );
    expect(find.byIcon(Icons.check), findsNothing);
  });

  testWidgets('onSelected callback fires with toggled value', (tester) async {
    bool? received;
    await tester.pumpWidget(
      _wrap(
        ChoiceChipMetra(
          label: _testLabel,
          selected: false,
          onSelected: (v) => received = v,
          semanticsLabel: _testSemanticsUnselected,
        ),
        MetraTheme.light(),
      ),
    );
    await tester.tap(find.byType(ChoiceChipMetra));
    expect(received, isTrue);
  });
}
