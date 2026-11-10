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
import 'package:metra/core/widgets/text_field_metra.dart';

Widget _wrap(Widget child, ThemeData theme) => MaterialApp(
      theme: theme,
      home: Scaffold(body: Center(child: SizedBox(width: 300, child: child))),
    );

/// Hint used by the pre-existing golden files — the default-params regression
/// cases below must reproduce those files byte-for-byte.
const _goldenHint = 'Come ti senti oggi?';

const _searchLabel = 'Cerca nelle note';

const _prefixKey = ValueKey('prefix-icon');
const _suffixKey = ValueKey('suffix-icon');

const _prefixIcon = SizedBox.square(
  key: _prefixKey,
  dimension: 24,
  child: Icon(Icons.search),
);

const _suffixIcon = SizedBox.square(
  key: _suffixKey,
  dimension: 24,
  child: Icon(Icons.close),
);

/// Widgets [TextFieldMetra] inserts between itself and the [TextField] it
/// builds. Proves the optional [Semantics] wrapper exists only when
/// `semanticsLabel` is set — and that no orphan node is added when it is null.
Iterable<Widget> _metraWrappers(WidgetTester tester) {
  final wrappers = <Widget>[];
  tester.element(find.byType(TextField)).visitAncestorElements((element) {
    if (element.widget is TextFieldMetra) {
      return false;
    }
    wrappers.add(element.widget);
    return true;
  });
  return wrappers;
}

void main() {
  late TextEditingController controller;

  setUp(() => controller = TextEditingController());
  tearDown(() => controller.dispose());

  testWidgets('golden — light theme single line', (tester) async {
    await tester.pumpWidget(
      _wrap(
        TextFieldMetra(
          controller: controller,
          hint: 'Come ti senti oggi?',
        ),
        MetraTheme.light(),
      ),
    );
    await expectLater(
      find.byType(TextFieldMetra),
      matchesGoldenFile('goldens/text_field_metra_light.png'),
    );
  });

  testWidgets('golden — dark theme single line', (tester) async {
    await tester.pumpWidget(
      _wrap(
        TextFieldMetra(
          controller: controller,
          hint: 'Come ti senti oggi?',
        ),
        MetraTheme.dark(),
      ),
    );
    await expectLater(
      find.byType(TextFieldMetra),
      matchesGoldenFile('goldens/text_field_metra_dark.png'),
    );
  });

  testWidgets('onChanged fires', (tester) async {
    String? received;
    await tester.pumpWidget(
      _wrap(
        TextFieldMetra(
          controller: controller,
          hint: 'Note',
          onChanged: (v) => received = v,
        ),
        MetraTheme.light(),
      ),
    );
    await tester.enterText(find.byType(TextField), 'ciao');
    expect(received, 'ciao');
  });

  testWidgets('minimum tap target height ≥ 44', (tester) async {
    await tester.pumpWidget(
      _wrap(
        TextFieldMetra(controller: controller, hint: 'Note'),
        MetraTheme.light(),
      ),
    );
    final size = tester.getSize(find.byType(TextFieldMetra));
    expect(size.height, greaterThanOrEqualTo(44));
  });

  // --- TASK-03: opt-in prefixIcon / suffixIcon / semanticsLabel ---

  testWidgets('golden — light theme, new params null', (tester) async {
    await tester.pumpWidget(
      _wrap(
        TextFieldMetra(
          controller: controller,
          hint: _goldenHint,
          prefixIcon: null,
          suffixIcon: null,
          semanticsLabel: null,
        ),
        MetraTheme.light(),
      ),
    );
    await expectLater(
      find.byType(TextFieldMetra),
      matchesGoldenFile('goldens/text_field_metra_light.png'),
    );
  });

  testWidgets('golden — dark theme, new params null', (tester) async {
    await tester.pumpWidget(
      _wrap(
        TextFieldMetra(
          controller: controller,
          hint: _goldenHint,
          prefixIcon: null,
          suffixIcon: null,
          semanticsLabel: null,
        ),
        MetraTheme.dark(),
      ),
    );
    await expectLater(
      find.byType(TextFieldMetra),
      matchesGoldenFile('goldens/text_field_metra_dark.png'),
    );
  });

  testWidgets('golden — light theme focused', (tester) async {
    await tester.pumpWidget(
      _wrap(
        TextFieldMetra(controller: controller, hint: _searchLabel),
        MetraTheme.light(),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();
    // Let the InputDecorator focus transition settle (200 ms) without
    // advancing into the cursor's 500 ms blink half-period.
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(
      find.byType(TextFieldMetra),
      matchesGoldenFile('goldens/text_field_metra_light_focused.png'),
    );
  });

  testWidgets('golden — dark theme focused', (tester) async {
    await tester.pumpWidget(
      _wrap(
        TextFieldMetra(controller: controller, hint: _searchLabel),
        MetraTheme.dark(),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();
    // Same deterministic two-pump settle as the light focused golden.
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(
      find.byType(TextFieldMetra),
      matchesGoldenFile('goldens/text_field_metra_dark_focused.png'),
    );
  });

  testWidgets('icons render in leading and trailing slots', (tester) async {
    await tester.pumpWidget(
      _wrap(
        TextFieldMetra(
          controller: controller,
          hint: _searchLabel,
          prefixIcon: _prefixIcon,
          suffixIcon: _suffixIcon,
        ),
        MetraTheme.light(),
      ),
    );

    expect(find.byKey(_prefixKey), findsOneWidget);
    expect(find.byKey(_suffixKey), findsOneWidget);

    final fieldRect = tester.getRect(find.byType(TextFieldMetra));
    final prefixCenter = tester.getCenter(find.byKey(_prefixKey));
    final suffixCenter = tester.getCenter(find.byKey(_suffixKey));

    // The leading glyph sits before the midline, the trailing one after it,
    // and both stay inside the field's own bounds.
    expect(fieldRect.contains(prefixCenter), isTrue);
    expect(fieldRect.contains(suffixCenter), isTrue);
    expect(prefixCenter.dx, lessThan(fieldRect.center.dx));
    expect(suffixCenter.dx, greaterThan(fieldRect.center.dx));
  });

  testWidgets('onChanged fires with icons present', (tester) async {
    String? received;
    await tester.pumpWidget(
      _wrap(
        TextFieldMetra(
          controller: controller,
          hint: _searchLabel,
          prefixIcon: _prefixIcon,
          suffixIcon: _suffixIcon,
          onChanged: (v) => received = v,
        ),
        MetraTheme.light(),
      ),
    );
    await tester.enterText(find.byType(TextField), 'ciao');
    expect(received, 'ciao');
  });

  testWidgets('min height ≥ 44 holds with icons present', (tester) async {
    await tester.pumpWidget(
      _wrap(
        TextFieldMetra(
          controller: controller,
          hint: _searchLabel,
          prefixIcon: _prefixIcon,
          suffixIcon: _suffixIcon,
        ),
        MetraTheme.light(),
      ),
    );
    final size = tester.getSize(find.byType(TextFieldMetra));
    expect(size.height, greaterThanOrEqualTo(44));
  });

  testWidgets('semanticsLabel adds exactly one wrapper node', (tester) async {
    await tester.pumpWidget(
      _wrap(
        TextFieldMetra(
          controller: controller,
          hint: _searchLabel,
          semanticsLabel: _searchLabel,
        ),
        MetraTheme.light(),
      ),
    );

    final wrappers = _metraWrappers(tester).whereType<Semantics>().toList();
    expect(wrappers, hasLength(1));

    // Exact equality: the label must not be merged with the field's own
    // semantics (no "label\nhint" concatenation).
    final semantics = tester.getSemantics(find.byType(TextFieldMetra));
    expect(semantics.label, _searchLabel);
  });

  testWidgets('no wrapper Semantics when label null', (tester) async {
    await tester.pumpWidget(
      _wrap(
        TextFieldMetra(controller: controller, hint: _searchLabel),
        MetraTheme.light(),
      ),
    );

    expect(_metraWrappers(tester).whereType<Semantics>(), isEmpty);
  });
}
