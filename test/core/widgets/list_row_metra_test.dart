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
import 'package:metra/core/widgets/list_row_metra.dart';

Widget _wrap(Widget child, ThemeData theme) => MaterialApp(
      theme: theme,
      home: Scaffold(body: child),
    );

const _testTitle = 'Notifiche';
const _testSemantics = 'Notifiche, apre le impostazioni';

void main() {
  testWidgets('golden — light theme interactive', (tester) async {
    await tester.pumpWidget(
      _wrap(
        ListRowMetra(
          title: _testTitle,
          semanticsLabel: _testSemantics,
          leading: const Icon(Icons.notifications_outlined),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {},
        ),
        MetraTheme.light(),
      ),
    );
    await expectLater(
      find.byType(ListRowMetra),
      matchesGoldenFile('goldens/list_row_metra_light.png'),
    );
  });

  testWidgets('golden — dark theme', (tester) async {
    await tester.pumpWidget(
      _wrap(
        ListRowMetra(
          title: _testTitle,
          semanticsLabel: _testSemantics,
          onTap: () {},
        ),
        MetraTheme.dark(),
      ),
    );
    await expectLater(
      find.byType(ListRowMetra),
      matchesGoldenFile('goldens/list_row_metra_dark.png'),
    );
  });

  testWidgets('semantics label is correct', (tester) async {
    await tester.pumpWidget(
      _wrap(
        ListRowMetra(
          title: _testTitle,
          semanticsLabel: _testSemantics,
          onTap: () {},
        ),
        MetraTheme.light(),
      ),
    );
    final semantics = tester.getSemantics(find.byType(ListRowMetra));
    expect(semantics.label, _testSemantics);
  });

  testWidgets('minimum tap target height ≥ 48', (tester) async {
    await tester.pumpWidget(
      _wrap(
        ListRowMetra(
          title: _testTitle,
          semanticsLabel: _testSemantics,
          onTap: () {},
        ),
        MetraTheme.light(),
      ),
    );
    final size = tester.getSize(find.byType(ListRowMetra));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('onTap fires', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _wrap(
        ListRowMetra(
          title: _testTitle,
          semanticsLabel: _testSemantics,
          onTap: () => tapped = true,
        ),
        MetraTheme.light(),
      ),
    );
    await tester.tap(find.byType(ListRowMetra));
    expect(tapped, isTrue);
  });
}
