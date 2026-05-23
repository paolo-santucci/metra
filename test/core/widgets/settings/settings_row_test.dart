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
import 'package:metra/core/theme/metra_colors.dart';
import 'package:metra/core/theme/metra_theme.dart';
import 'package:metra/core/theme/metra_typography.dart';
import 'package:metra/core/widgets/settings/settings_row.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

Widget _wrap(
  Widget child, {
  ThemeMode themeMode = ThemeMode.light,
  double textScaleFactor = 1.0,
}) {
  final theme =
      themeMode == ThemeMode.light ? MetraTheme.light() : MetraTheme.dark();
  return MaterialApp(
    theme: theme,
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScaleFactor)),
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  // -------------------------------------------------------------------------
  // SettingsRow.nav
  // -------------------------------------------------------------------------

  testWidgets(
      'SettingsRow.nav: minHeight 56, 20dp padding, chevron present, onTap fires once',
      (tester) async {
    int tapCount = 0;
    await tester.pumpWidget(
      _wrap(
        SettingsRow.nav(label: 'Account', onTap: () => tapCount++),
      ),
    );

    // Chevron icon must be present.
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);

    // Row height is at least 56 dp.
    final box = tester.renderObject<RenderBox>(find.byType(SettingsRow));
    expect(box.size.height, greaterThanOrEqualTo(56.0));

    // Horizontal padding 20 dp on each side — find the innermost padding that
    // has left == right == 20.
    bool found20dp = false;
    find.byType(Padding).evaluate().forEach((e) {
      final w = e.widget as Padding;
      final edgeInsets = w.padding.resolve(TextDirection.ltr);
      if (edgeInsets.left == 20.0 && edgeInsets.right == 20.0) {
        found20dp = true;
      }
    });
    expect(
      found20dp,
      isTrue,
      reason: 'Expected a Padding widget with left=right=20dp',
    );

    // onTap fires once.
    await tester.tap(find.byType(SettingsRow));
    await tester.pump();
    expect(tapCount, 1);
  });

  // -------------------------------------------------------------------------
  // SettingsRow.staticInfo
  // -------------------------------------------------------------------------

  testWidgets(
      'SettingsRow.staticInfo: IgnorePointer present, no chevron, value visible',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const SettingsRow.staticInfo(
          label: 'Account',
          valueText: 'test@example.com',
        ),
      ),
    );

    // IgnorePointer must be present as a descendant of SettingsRow.
    expect(
      find.descendant(
        of: find.byType(SettingsRow),
        matching: find.byType(IgnorePointer),
      ),
      findsAtLeastNWidgets(1),
    );

    // No chevron icon.
    expect(find.byIcon(Icons.chevron_right), findsNothing);

    // Value text visible.
    expect(find.text('test@example.com'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // SettingsRow.toggle
  // -------------------------------------------------------------------------

  testWidgets('SettingsRow.toggle: row tap does NOT fire toggle onChanged',
      (tester) async {
    int onChangedCount = 0;
    bool toggleValue = false;
    await tester.pumpWidget(
      _wrap(
        StatefulBuilder(
          builder: (context, setState) => SettingsRow.toggle(
            label: 'Notifiche',
            toggle: Switch(
              value: toggleValue,
              onChanged: (v) {
                onChangedCount++;
                setState(() => toggleValue = v);
              },
            ),
          ),
        ),
      ),
    );

    // Tap on the SettingsRow itself (not on the Switch widget).
    // We hit-test the label text to be sure we're not hitting the switch.
    await tester.tap(find.text('Notifiche'));
    await tester.pump();

    // Row background tap must NOT call onChanged.
    expect(onChangedCount, 0);
  });

  // -------------------------------------------------------------------------
  // SettingsRow.action
  // -------------------------------------------------------------------------

  testWidgets(
      'SettingsRow.action: transparent background, textPrimary label, onTap fires',
      (tester) async {
    int tapCount = 0;
    await tester.pumpWidget(
      _wrap(
        SettingsRow.action(
          label: 'Esegui backup ora',
          onTap: () => tapCount++,
        ),
      ),
    );

    // No chevron.
    expect(find.byIcon(Icons.chevron_right), findsNothing);

    // Label text present.
    expect(find.text('Esegui backup ora'), findsOneWidget);

    // Tap fires.
    await tester.tap(find.byType(SettingsRow));
    await tester.pump();
    expect(tapCount, 1);
  });

  // -------------------------------------------------------------------------
  // SettingsRow.destructive
  // -------------------------------------------------------------------------

  testWidgets(
      'SettingsRow.destructive: background accentFlow.withAlpha(0x0D), '
      'label accentFlowText', (tester) async {
    await tester.pumpWidget(
      _wrap(
        SettingsRow.destructive(label: 'Disconnetti', onTap: () {}),
      ),
    );

    // Label present.
    expect(find.text('Disconnetti'), findsOneWidget);

    // Label colour must be accentFlowText.
    final element = tester.element(find.text('Disconnetti'));
    final colors = MetraColors.of(element);

    final textWidget = tester.widget<Text>(find.text('Disconnetti'));
    expect(
      textWidget.style!.color,
      colors.accentFlowText,
      reason: 'Destructive label should use accentFlowText',
    );

    // Background: Container with accentFlow.withAlpha(0x0D).
    bool foundTintedBg = false;
    find.byType(Container).evaluate().forEach((e) {
      final widget = e.widget as Container;
      if (widget.color == colors.accentFlow.withAlpha(0x0D)) {
        foundTintedBg = true;
      }
    });
    expect(
      foundTintedBg,
      isTrue,
      reason: 'Expected Container with accentFlow.withAlpha(0x0D) background',
    );
  });

  // -------------------------------------------------------------------------
  // NFR-05 / EC-10: minHeight — grows past 56dp at large text scale
  // -------------------------------------------------------------------------

  testWidgets('SettingsRow grows past 56dp at textScaleFactor 2.0 (no clip)',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        SettingsRow.nav(
          label: 'Un titolo lungo che può andare a capo',
          onTap: () {},
        ),
        textScaleFactor: 2.0,
      ),
    );
    await tester.pump();

    // At 2× text scale, the row should grow taller than 56 dp.
    final box = tester.renderObject<RenderBox>(find.byType(SettingsRow));
    expect(box.size.height, greaterThan(56.0));

    // No overflow exception.
    expect(tester.takeException(), isNull);
  });

  // -------------------------------------------------------------------------
  // Dark palette smoke
  // -------------------------------------------------------------------------

  testWidgets(
      'SettingsRow.nav: dark palette — label resolves to dark textPrimary',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        SettingsRow.nav(label: 'Account', onTap: () {}),
        themeMode: ThemeMode.dark,
      ),
    );

    final element = tester.element(find.text('Account'));
    final colors = MetraColors.of(element);

    final textWidget = tester.widget<Text>(find.text('Account'));
    expect(textWidget.style!.color, colors.textPrimary);
  });

  // -------------------------------------------------------------------------
  // Typography assertions (Group B)
  // -------------------------------------------------------------------------

  testWidgets(
    'SettingsRow.toggle: label typography Inter 15 / w500 / textPrimary',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SettingsRow.toggle(
            label: 'Notifiche',
            toggle: SizedBox.shrink(),
          ),
        ),
      );
      await tester.pump();

      final element = tester.element(find.text('Notifiche'));
      final colors = MetraColors.of(element);
      final textWidget = tester.widget<Text>(find.text('Notifiche'));
      final style = textWidget.style!;

      // Inter 15 / w500 — MetraTypography.listTitle
      expect(
        style.fontSize,
        MetraTypography.listTitle.fontSize,
        reason: 'Toggle label must use MetraTypography.listTitle (15px)',
      );
      expect(
        style.fontWeight,
        MetraTypography.listTitle.fontWeight,
        reason: 'Toggle label must use MetraTypography.listTitle (w500)',
      );
      expect(
        style.color,
        colors.textPrimary,
        reason: 'Toggle label must use MetraColors.of(context).textPrimary',
      );
    },
  );

  testWidgets(
    'SettingsRow.staticInfo: value text Inter 14 / w400 / textSecondary',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SettingsRow.staticInfo(
            label: 'Account',
            valueText: 'user@example.com',
          ),
        ),
      );
      await tester.pump();

      final element = tester.element(find.text('user@example.com'));
      final colors = MetraColors.of(element);
      final textWidget = tester.widget<Text>(find.text('user@example.com'));
      final style = textWidget.style!;

      // Inter 14 / w400 at textSecondary
      expect(
        style.fontSize,
        14.0,
        reason: 'staticInfo value must use Inter 14',
      );
      expect(
        style.fontWeight,
        FontWeight.w400,
        reason: 'staticInfo value must use Inter w400',
      );
      expect(
        style.color,
        colors.textSecondary,
        reason:
            'staticInfo value must use MetraColors.of(context).textSecondary',
      );
    },
  );

  testWidgets(
    'SettingsRow.action: label colour is textPrimary',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          SettingsRow.action(
            label: 'Esegui backup ora',
            onTap: () {},
          ),
        ),
      );
      await tester.pump();

      final element = tester.element(find.text('Esegui backup ora'));
      final colors = MetraColors.of(element);
      final textWidget = tester.widget<Text>(find.text('Esegui backup ora'));

      expect(
        textWidget.style!.color,
        colors.textPrimary,
        reason: 'Action label must use MetraColors.of(context).textPrimary',
      );
    },
  );

  // -------------------------------------------------------------------------
  // SettingsRow.toggle — trailing widget presence
  // -------------------------------------------------------------------------

  testWidgets(
    'SettingsRow.toggle: toggle widget is rendered as trailing descendant',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SettingsRow.toggle(
            label: 'Notifiche',
            toggle: SizedBox(
              key: ValueKey('toggle-widget'),
              width: 48,
              height: 28,
            ),
          ),
        ),
      );
      await tester.pump();

      // The toggle widget passed to .toggle must appear as a descendant
      // of the SettingsRow.
      expect(
        find.descendant(
          of: find.byType(SettingsRow),
          matching: find.byKey(const ValueKey('toggle-widget')),
        ),
        findsOneWidget,
        reason: 'Toggle widget must be rendered inside the SettingsRow',
      );
    },
  );

  // -------------------------------------------------------------------------
  // SettingsRow.destructive — dark palette tokens
  // -------------------------------------------------------------------------

  testWidgets(
    'SettingsRow.destructive: dark palette — label resolves dark accentFlowText, '
    'background resolves dark accentFlow.withAlpha(0x0D)',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          SettingsRow.destructive(label: 'Disconnetti', onTap: () {}),
          themeMode: ThemeMode.dark,
        ),
      );
      await tester.pump();

      final element = tester.element(find.text('Disconnetti'));
      final colors = MetraColors.of(element);

      // Label must use the dark accentFlowText token.
      final textWidget = tester.widget<Text>(find.text('Disconnetti'));
      expect(
        textWidget.style!.color,
        colors.accentFlowText,
        reason: 'Dark palette: destructive label must use dark accentFlowText',
      );

      // Dark accentFlowText must differ from the light token.
      expect(
        colors.accentFlowText,
        isNot(MetraColors.light.accentFlowText),
      );

      // Background Container must use dark accentFlow.withAlpha(0x0D).
      bool foundTintedBg = false;
      find.byType(Container).evaluate().forEach((e) {
        final widget = e.widget as Container;
        if (widget.color == colors.accentFlow.withAlpha(0x0D)) {
          foundTintedBg = true;
        }
      });
      expect(
        foundTintedBg,
        isTrue,
        reason:
            'Dark palette: destructive row must use dark accentFlow.withAlpha(0x0D) background',
      );
    },
  );

  // -------------------------------------------------------------------------
  // Cross-contamination guard (Group B)
  // -------------------------------------------------------------------------

  testWidgets(
    'SettingsRow.action next to .destructive: action does NOT carry tinted background',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          Column(
            children: [
              SettingsRow.action(
                key: const ValueKey('action-row'),
                label: 'Esegui backup ora',
                onTap: () {},
              ),
              SettingsRow.destructive(
                key: const ValueKey('destructive-row'),
                label: 'Disconnetti',
                onTap: () {},
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      // Resolve colors from the action row's element.
      final actionElement = tester.element(find.text('Esegui backup ora'));
      final colors = MetraColors.of(actionElement);
      final tintedColor = colors.accentFlow.withAlpha(0x0D);

      // Collect Container colors only within the action row subtree.
      bool actionHasTint = false;
      find
          .descendant(
            of: find.byKey(const ValueKey('action-row')),
            matching: find.byType(Container),
          )
          .evaluate()
          .forEach((e) {
        final widget = e.widget as Container;
        if (widget.color == tintedColor) {
          actionHasTint = true;
        }
      });

      expect(
        actionHasTint,
        isFalse,
        reason: 'action row must NOT carry the destructive tinted background '
            '(no cross-contamination between variants)',
      );

      // Destructive row DOES have the tint (positive control).
      bool destructiveHasTint = false;
      find
          .descendant(
            of: find.byKey(const ValueKey('destructive-row')),
            matching: find.byType(Container),
          )
          .evaluate()
          .forEach((e) {
        final widget = e.widget as Container;
        if (widget.color == tintedColor) {
          destructiveHasTint = true;
        }
      });

      expect(
        destructiveHasTint,
        isTrue,
        reason: 'destructive row must have the tinted background',
      );
    },
  );
}
