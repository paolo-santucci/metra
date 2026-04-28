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
import 'package:metra/core/widgets/section_title_metra.dart';

Widget _wrap(Widget child, ThemeData theme) => MaterialApp(
      theme: theme,
      home: Scaffold(body: Center(child: child)),
    );

const _testTitle = 'Flusso mestruale';

void main() {
  testWidgets('golden — light theme', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const SectionTitleMetra(title: _testTitle),
        MetraTheme.light(),
      ),
    );
    await expectLater(
      find.byType(SectionTitleMetra),
      matchesGoldenFile('goldens/section_title_light.png'),
    );
  });

  testWidgets('golden — dark theme', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const SectionTitleMetra(title: _testTitle),
        MetraTheme.dark(),
      ),
    );
    await expectLater(
      find.byType(SectionTitleMetra),
      matchesGoldenFile('goldens/section_title_dark.png'),
    );
  });

  testWidgets('semantics marks widget as heading', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const SectionTitleMetra(title: _testTitle),
        MetraTheme.light(),
      ),
    );
    final semantics = tester.getSemantics(find.byType(SectionTitleMetra));
    expect(semantics.flagsCollection.isHeader, isTrue);
  });

  testWidgets('title text is visible in widget tree', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const SectionTitleMetra(title: _testTitle),
        MetraTheme.light(),
      ),
    );
    expect(find.text(_testTitle), findsOneWidget);
  });
}
