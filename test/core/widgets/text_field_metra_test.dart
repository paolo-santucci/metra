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
}
