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

import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/theme/metra_theme.dart';
import 'package:metra/core/widgets/choice_chip_metra.dart';

Widget _wrap(Widget child, ThemeData theme) => MaterialApp(
      theme: theme,
      home: Scaffold(body: Center(child: child)),
    );

/// Weight actually applied to the chip's label [Text] node.
FontWeight? _labelWeight(WidgetTester tester) =>
    tester.widget<Text>(find.text(_testLabel)).style?.fontWeight;

const _testLabel = 'Stanchezza';
const _testSemantics = 'Stanchezza, selezionato';
const _testSemanticsUnselected = 'Stanchezza, non selezionato';

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

  testWidgets('semantics toggled true when selected', (tester) async {
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
    expect(semantics.flagsCollection.isToggled, Tristate.isTrue);
  });

  testWidgets('semantics toggled false when unselected', (tester) async {
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
    final semantics = tester.getSemantics(find.byType(ChoiceChipMetra));
    expect(semantics.flagsCollection.isToggled, isNot(Tristate.isTrue));
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

  // ── idleFontWeight opt-in extension (spec §5.1.F, canon §1.2) ─────────────
  //
  // Canon §1.2 "Filter / chip label": Inter 13, 400 idle / 500 selected. The
  // parameter defaults to null so the daily-entry rendering (and its goldens)
  // stay byte-identical at w500.

  testWidgets('idle label w500 by default', (tester) async {
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
    expect(_labelWeight(tester), FontWeight.w500);
  });

  testWidgets('selected label w500 by default', (tester) async {
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
    expect(_labelWeight(tester), FontWeight.w500);
  });

  testWidgets('idle label w400 when opted in', (tester) async {
    await tester.pumpWidget(
      _wrap(
        ChoiceChipMetra(
          label: _testLabel,
          selected: false,
          onSelected: (_) {},
          semanticsLabel: _testSemanticsUnselected,
          idleFontWeight: FontWeight.w400,
        ),
        MetraTheme.light(),
      ),
    );
    expect(_labelWeight(tester), FontWeight.w400);
  });

  testWidgets('selected label stays w500 at w400', (tester) async {
    await tester.pumpWidget(
      _wrap(
        ChoiceChipMetra(
          label: _testLabel,
          selected: true,
          onSelected: (_) {},
          semanticsLabel: _testSemantics,
          idleFontWeight: FontWeight.w400,
        ),
        MetraTheme.light(),
      ),
    );
    expect(_labelWeight(tester), FontWeight.w500);
  });

  testWidgets('label stays 13 px at w400', (tester) async {
    await tester.pumpWidget(
      _wrap(
        ChoiceChipMetra(
          label: _testLabel,
          selected: false,
          onSelected: (_) {},
          semanticsLabel: _testSemanticsUnselected,
          idleFontWeight: FontWeight.w400,
        ),
        MetraTheme.light(),
      ),
    );
    final style = tester.widget<Text>(find.text(_testLabel)).style;
    expect(style?.fontSize, 13.0);
  });

  // FR-16 / NFR-03 hold under BOTH weights and both selection states.
  for (final weight in const <FontWeight?>[null, FontWeight.w400]) {
    testWidgets('toggled false, tap target — $weight', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ChoiceChipMetra(
            label: _testLabel,
            selected: false,
            onSelected: (_) {},
            semanticsLabel: _testSemanticsUnselected,
            idleFontWeight: weight,
          ),
          MetraTheme.light(),
        ),
      );

      final size = tester.getSize(find.byType(ChoiceChipMetra));
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));

      final semantics = tester.getSemantics(find.byType(ChoiceChipMetra));
      expect(semantics.label, _testSemanticsUnselected);
      expect(semantics.flagsCollection.isToggled, isNot(Tristate.isTrue));
    });

    testWidgets('toggled true, tap target — $weight', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ChoiceChipMetra(
            label: _testLabel,
            selected: true,
            onSelected: (_) {},
            semanticsLabel: _testSemantics,
            idleFontWeight: weight,
          ),
          MetraTheme.light(),
        ),
      );

      final size = tester.getSize(find.byType(ChoiceChipMetra));
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));

      final semantics = tester.getSemantics(find.byType(ChoiceChipMetra));
      expect(semantics.label, _testSemantics);
      expect(semantics.flagsCollection.isToggled, Tristate.isTrue);
    });
  }
}
