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
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/theme/metra_theme.dart';
import 'package:metra/core/widgets/settings/cupertino_picker_scaffold.dart';
import 'package:metra/core/widgets/settings/metra_picker_wheel.dart';
import 'package:metra/l10n/app_localizations.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('large text fits compact sheet in $brightness', (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: brightness == Brightness.light
              ? MetraTheme.light()
              : MetraTheme.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 480),
              padding: EdgeInsets.only(bottom: 34),
              textScaler: TextScaler.linear(2),
            ),
            child: CupertinoPickerScaffold(
              onReset: () {},
              onConfirm: () {},
              resetLabel: 'Annulla',
              confirmLabel: 'Connetti',
              title: 'Provider',
              useSafeArea: true,
              child: MetraPickerWheel(
                initialItem: 1,
                onSelectedItemChanged: (_) {},
                children: const [
                  Center(child: Text('Dropbox')),
                  Center(child: Text('Google Drive')),
                  Center(child: Text('iCloud')),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final wheel =
          tester.widget<CupertinoPicker>(find.byType(CupertinoPicker));
      expect(wheel.itemExtent, 65);
      expect(wheel.scrollController!.selectedItem, 1);
      expect(
        tester.getBottomRight(find.byType(CupertinoPicker)).dy,
        lessThanOrEqualTo(446),
      );
    });
  }

  testWidgets('selection survives parent rebuild and resets with a new key',
      (tester) async {
    var selected = 1;
    var wheelKey = UniqueKey();
    late StateSetter rebuild;
    await tester.pumpWidget(
      MaterialApp(
        theme: MetraTheme.light(),
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return MetraPickerWheel(
              key: wheelKey,
              initialItem: 1,
              onSelectedItemChanged: (value) =>
                  setState(() => selected = value),
              children: List.generate(6, (i) => Center(child: Text('$i'))),
            );
          },
        ),
      ),
    );
    final controller = tester
        .widget<CupertinoPicker>(find.byType(CupertinoPicker))
        .scrollController!;
    controller.jumpToItem(4);
    await tester.pumpAndSettle();
    expect(selected, 4);
    expect(
      tester
          .widget<CupertinoPicker>(find.byType(CupertinoPicker))
          .scrollController,
      same(controller),
    );
    expect(controller.selectedItem, 4);
    rebuild(() => wheelKey = UniqueKey());
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CupertinoPicker>(find.byType(CupertinoPicker))
          .scrollController!
          .selectedItem,
      1,
    );
    expect(tester.takeException(), isNull);
  });
}
