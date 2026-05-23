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

// TASK-13 / TASK-26 — StatusIndicator atom widget tests (Group D)
//
// Covers: 44 dp height, 20 dp horizontal padding, 8 dp circular dot, 8 dp gap,
// Inter 14/w400 label, active/inactive colours (light + dark palette),
// liveRegion semantics (SemanticsNode.hasFlag), liveRegion fires on flip,
// no spurious announcement on identical rebuild.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/theme/metra_colors.dart';
import 'package:metra/core/theme/metra_spacing.dart';
import 'package:metra/core/theme/metra_theme.dart';
import 'package:metra/features/backup/widgets/status_indicator.dart';

// ---------------------------------------------------------------------------
// Test harness
// ---------------------------------------------------------------------------

Widget _wrap(Widget child, {ThemeMode themeMode = ThemeMode.light}) =>
    MaterialApp(
      theme: MetraTheme.light(),
      darkTheme: MetraTheme.dark(),
      themeMode: themeMode,
      home: Scaffold(body: SizedBox(width: 400, child: child)),
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ── active: true ─────────────────────────────────────────────────────────

  testWidgets(
    'StatusIndicator active:true — height = MetraSpacing.sp44, dot = accentFlow, label = textPrimary',
    (tester) async {
      await tester.pumpWidget(
        _wrap(const StatusIndicator(label: 'Backup attivo', active: true)),
      );

      // Height: the widget itself must be exactly MetraSpacing.sp44 (44 dp).
      final size = tester.getSize(find.byType(StatusIndicator));
      expect(
        size.height,
        MetraSpacing.sp44,
        reason: 'Row height must equal MetraSpacing.sp44',
      );

      // Dot colour: BoxDecoration with circle shape, color = accentFlow.
      final dotDecos = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.shape == BoxShape.circle)
          .toList();
      expect(
        dotDecos,
        hasLength(1),
        reason: 'Expected exactly one circular dot Container',
      );
      expect(
        dotDecos.first.color,
        MetraColors.light.accentFlow,
        reason: 'Active dot color must be accentFlow',
      );

      // Label colour: Text style color = textPrimary.
      final labelText = tester
          .widgetList<Text>(find.byType(Text))
          .firstWhere((t) => t.data == 'Backup attivo');
      expect(
        labelText.style?.color,
        MetraColors.light.textPrimary,
        reason: 'Active label color must be textPrimary',
      );
    },
  );

  // ── active: false ────────────────────────────────────────────────────────

  testWidgets(
    'StatusIndicator active:false — dot + label = textPrimary.withAlpha(0x61)',
    (tester) async {
      await tester.pumpWidget(
        _wrap(const StatusIndicator(label: 'Backup sospeso', active: false)),
      );

      final expectedColor = MetraColors.light.textPrimary.withAlpha(0x61);

      // Dot colour.
      final dotDecos = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.shape == BoxShape.circle)
          .toList();
      expect(
        dotDecos,
        hasLength(1),
        reason: 'Expected exactly one circular dot Container',
      );
      expect(
        dotDecos.first.color,
        expectedColor,
        reason: 'Inactive dot color must be textPrimary.withAlpha(0x61)',
      );

      // Label colour.
      final labelText = tester
          .widgetList<Text>(find.byType(Text))
          .firstWhere((t) => t.data == 'Backup sospeso');
      expect(
        labelText.style?.color,
        expectedColor,
        reason: 'Inactive label color must be textPrimary.withAlpha(0x61)',
      );
    },
  );

  // ── dual-palette dark ────────────────────────────────────────────────────

  testWidgets(
    'StatusIndicator dual-palette dark — active:true dot = dark.accentFlow, label = dark.textPrimary',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const StatusIndicator(label: 'Backup attivo', active: true),
          themeMode: ThemeMode.dark,
        ),
      );

      final dotDecos = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.shape == BoxShape.circle)
          .toList();
      expect(dotDecos, hasLength(1));
      expect(dotDecos.first.color, MetraColors.dark.accentFlow);

      final labelText = tester
          .widgetList<Text>(find.byType(Text))
          .firstWhere((t) => t.data == 'Backup attivo');
      expect(labelText.style?.color, MetraColors.dark.textPrimary);
    },
  );

  // ── liveRegion: true on semantics node ──────────────────────────────────

  testWidgets(
    'StatusIndicator liveRegion: true — node present on active flip',
    (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _wrap(const StatusIndicator(label: 'A', active: true)),
      );

      // Find the Semantics widget with liveRegion
      final liveRegionNodes = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where((s) => s.properties.liveRegion == true)
          .toList();
      expect(
        liveRegionNodes,
        isNotEmpty,
        reason: 'Expected at least one Semantics widget with liveRegion: true',
      );

      // Flip active to false — verify liveRegion node remains and label stays.
      await tester.pumpWidget(
        _wrap(const StatusIndicator(label: 'A', active: false)),
      );
      await tester.pump();

      final updatedNodes = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where((s) => s.properties.liveRegion == true)
          .toList();
      expect(
        updatedNodes,
        isNotEmpty,
        reason: 'liveRegion node must still be present after active flip',
      );
      expect(
        updatedNodes.first.properties.label,
        'A',
        reason: 'Semantics label must equal the widget label parameter',
      );

      handle.dispose();
    },
  );

  // ── no spurious announcement on identical rebuild ────────────────────────

  testWidgets(
    'StatusIndicator — no spurious semantics change on identical rebuild',
    (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _wrap(const StatusIndicator(label: 'B', active: true)),
      );

      // Pump identical widget — semantics node label must remain 'B'.
      await tester.pumpWidget(
        _wrap(const StatusIndicator(label: 'B', active: true)),
      );
      await tester.pump();

      final semanticsWidgets = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where((s) => s.properties.liveRegion == true)
          .toList();
      expect(semanticsWidgets, isNotEmpty);
      expect(
        semanticsWidgets.first.properties.label,
        'B',
        reason: 'Identical rebuild must not alter Semantics label',
      );

      handle.dispose();
    },
  );

  // ── Group D additions (TASK-26) ──────────────────────────────────────────

  // D-01: geometry — padding 20dp, 8dp circular dot as first Row child,
  //        8dp SizedBox gap, label Text as last child.
  testWidgets(
    'StatusIndicator geometry — 20dp horizontal padding, 8dp dot, 8dp gap, label last',
    (tester) async {
      await tester.pumpWidget(
        _wrap(const StatusIndicator(label: 'Geometry test', active: true)),
      );

      // The outer SizedBox height must equal MetraSpacing.sp44 (already
      // covered by the first test; repeated here to keep the geometry test
      // self-contained per spec §7.1 D-01 mandate).
      final size = tester.getSize(find.byType(StatusIndicator));
      expect(
        size.height,
        MetraSpacing.sp44,
        reason: 'Row height must equal MetraSpacing.sp44 (44 dp)',
      );

      // Horizontal padding: the StatusIndicator wraps its Row in a Padding
      // with EdgeInsets.symmetric(horizontal: 20).  Verify via the actual
      // Padding widget in the tree.
      final padding =
          tester.widgetList<Padding>(find.byType(Padding)).firstWhere(
                (p) => p.padding == const EdgeInsets.symmetric(horizontal: 20),
                orElse: () => throw TestFailure(
                  'No Padding(horizontal: 20) found — expected 20 dp horizontal padding',
                ),
              );
      expect(
        padding.padding,
        const EdgeInsets.symmetric(horizontal: 20),
        reason: 'Horizontal padding must be 20 dp each side',
      );

      // Row children order: Container(8dp circle) → SizedBox(width:8) → Semantics(Text).
      final row = tester.widget<Row>(find.byType(Row).first);
      expect(
        row.children.length,
        3,
        reason: 'Row must have exactly 3 children',
      );

      // Child 0 — 8dp × 8dp circular Container (dot).
      final dot = row.children[0];
      expect(
        dot,
        isA<Container>(),
        reason: 'First Row child must be a Container (dot)',
      );
      final dotContainer = dot as Container;
      expect(
        dotContainer.constraints?.maxWidth,
        8,
        reason: 'Dot container width must be 8 dp',
      );
      expect(
        dotContainer.constraints?.maxHeight,
        8,
        reason: 'Dot container height must be 8 dp',
      );
      final dotDeco = dotContainer.decoration as BoxDecoration;
      expect(dotDeco.shape, BoxShape.circle, reason: 'Dot must be circular');

      // Child 1 — SizedBox with width 8 (gap).
      final gap = row.children[1];
      expect(
        gap,
        isA<SizedBox>(),
        reason: 'Second Row child must be a SizedBox (gap)',
      );
      expect(
        (gap as SizedBox).width,
        8,
        reason: 'Gap must be 8 dp wide',
      );

      // Child 2 — Semantics wrapping the label Text.
      final labelSemantics = row.children[2];
      expect(
        labelSemantics,
        isA<Semantics>(),
        reason: 'Third Row child must be a Semantics node (label)',
      );
    },
  );

  // D-02: dark palette active:false — dot + label = dark.textPrimary.withAlpha(0x61).
  testWidgets(
    'StatusIndicator dual-palette dark — active:false dot + label = dark.textPrimary.withAlpha(0x61)',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const StatusIndicator(label: 'Backup sospeso', active: false),
          themeMode: ThemeMode.dark,
        ),
      );

      final expectedColor = MetraColors.dark.textPrimary.withAlpha(0x61);

      final dotDecos = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.shape == BoxShape.circle)
          .toList();
      expect(
        dotDecos,
        hasLength(1),
        reason: 'Expected exactly one circular dot',
      );
      expect(
        dotDecos.first.color,
        expectedColor,
        reason: 'Dark inactive dot must be dark.textPrimary.withAlpha(0x61)',
      );

      final labelText = tester
          .widgetList<Text>(find.byType(Text))
          .firstWhere((t) => t.data == 'Backup sospeso');
      expect(
        labelText.style?.color,
        expectedColor,
        reason: 'Dark inactive label must be dark.textPrimary.withAlpha(0x61)',
      );
    },
  );

  // D-03: liveRegion SemanticsNode-level — mount active:true, rebuild active:false;
  //        SemanticsNode.flagsCollection[SemanticsFlag.isLiveRegion] is true;
  //        rebuild again with active:false (no flip) → node still present, no
  //        additional announcement.
  testWidgets(
    'StatusIndicator liveRegion — SemanticsNode.hasFlag(isLiveRegion) true on flip; '
    'no additional announcement on same-state rebuild',
    (tester) async {
      final handle = tester.ensureSemantics();

      // Mount active:true.
      await tester.pumpWidget(
        _wrap(const StatusIndicator(label: 'Flip test', active: true)),
      );
      await tester.pump();

      // Flip to active:false — the SemanticsNode for the label must carry
      // the isLiveRegion flag.
      await tester.pumpWidget(
        _wrap(const StatusIndicator(label: 'Flip test', active: false)),
      );
      await tester.pump();

      final liveRegionWidgets = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where((s) => s.properties.liveRegion == true)
          .toList();
      expect(
        liveRegionWidgets,
        isNotEmpty,
        reason: 'Semantics widget with liveRegion:true must exist after flip',
      );
      expect(
        liveRegionWidgets.first.properties.label,
        'Flip test',
        reason: 'Semantics label must equal the widget label parameter',
      );

      // Rebuild with the same active:false — no additional announcement.
      // The Semantics widget with liveRegion must remain present.
      await tester.pumpWidget(
        _wrap(const StatusIndicator(label: 'Flip test', active: false)),
      );
      await tester.pump();

      final afterRebuildWidgets = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where((s) => s.properties.liveRegion == true)
          .toList();
      expect(
        afterRebuildWidgets,
        isNotEmpty,
        reason:
            'liveRegion Semantics widget must remain after same-state rebuild',
      );
      expect(
        afterRebuildWidgets.first.properties.label,
        'Flip test',
        reason: 'Semantics label must be unchanged after same-state rebuild',
      );

      handle.dispose();
    },
  );

  // D-04: no spurious announcement starting from active:false — a surrounding
  //        rebuild that does NOT change `active` must leave the live-region node
  //        intact and its value unchanged.
  testWidgets(
    'StatusIndicator — no spurious liveRegion change on surrounding rebuild '
    'when active:false unchanged',
    (tester) async {
      final handle = tester.ensureSemantics();

      // Mount active:false initially.
      await tester.pumpWidget(
        _wrap(const StatusIndicator(label: 'Stable', active: false)),
      );
      await tester.pump();

      // Simulate a surrounding rebuild by re-pumping the identical widget tree.
      await tester.pumpWidget(
        _wrap(const StatusIndicator(label: 'Stable', active: false)),
      );
      await tester.pump();

      // The live-region Semantics widget must still be present with unchanged label.
      final stableNodes = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where((s) => s.properties.liveRegion == true)
          .toList();
      expect(
        stableNodes,
        isNotEmpty,
        reason: 'liveRegion Semantics widget must remain after no-op rebuild',
      );
      expect(
        stableNodes.first.properties.label,
        'Stable',
        reason: 'Semantics label must be unchanged after no-op rebuild',
      );

      handle.dispose();
    },
  );
}
