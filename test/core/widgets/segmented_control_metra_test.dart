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

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/theme/metra_colors.dart';
import 'package:metra/core/theme/metra_theme.dart';
import 'package:metra/core/widgets/segmented_control_metra.dart';

Widget _wrap(Widget child, ThemeData theme) => MaterialApp(
      theme: theme,
      home: Scaffold(body: Center(child: child)),
    );

const _segments = ['Lista', 'Tabella'];

// ── WCAG 2.1 contrast helpers (ui-design-bible.md § 5.4 FR-12) ─────────────
// Pure static math, no widget dependency — used by Group O below to verify
// the idle-label alpha (read from the actually-rendered Text style, not a
// hardcoded literal) composites to a WCAG-compliant contrast ratio.

/// Alpha-composites [fg] (with its own alpha) over an opaque [bg]. WCAG
/// contrast is only defined between two opaque colors; a translucent label
/// must first be flattened against its immediate background.
Color _compositeOver(Color fg, Color bg) {
  final double a = fg.a;
  return Color.from(
    alpha: 1,
    red: fg.r * a + bg.r * (1 - a),
    green: fg.g * a + bg.g * (1 - a),
    blue: fg.b * a + bg.b * (1 - a),
  );
}

double _linearize(double channel) => channel <= 0.03928
    ? channel / 12.92
    : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();

double _relativeLuminance(Color c) =>
    0.2126 * _linearize(c.r) +
    0.7152 * _linearize(c.g) +
    0.0722 * _linearize(c.b);

/// WCAG 2.1 relative-luminance contrast ratio between two opaque colors.
double _contrastRatio(Color a, Color b) {
  final double la = _relativeLuminance(a);
  final double lb = _relativeLuminance(b);
  final double lighter = math.max(la, lb);
  final double darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  testWidgets('golden — light theme index 0 selected', (tester) async {
    await tester.pumpWidget(
      _wrap(
        SegmentedControlMetra(
          segments: _segments,
          selectedIndex: 0,
          onChanged: (_) {},
        ),
        MetraTheme.light(),
      ),
    );
    await expectLater(
      find.byType(SegmentedControlMetra),
      matchesGoldenFile('goldens/segmented_control_metra_light.png'),
    );
  });

  testWidgets('golden — dark theme index 1 selected', (tester) async {
    await tester.pumpWidget(
      _wrap(
        SegmentedControlMetra(
          segments: _segments,
          selectedIndex: 1,
          onChanged: (_) {},
        ),
        MetraTheme.dark(),
      ),
    );
    await expectLater(
      find.byType(SegmentedControlMetra),
      matchesGoldenFile('goldens/segmented_control_metra_dark.png'),
    );
  });

  testWidgets('onChanged fires with correct index', (tester) async {
    int? received;
    await tester.pumpWidget(
      _wrap(
        SegmentedControlMetra(
          segments: _segments,
          selectedIndex: 0,
          onChanged: (i) => received = i,
        ),
        MetraTheme.light(),
      ),
    );
    // Tap the second segment. FR-12 intentionally stacks an invisible,
    // opaque 44×44 dp hit-region on top of the visible pill text (see
    // SegmentedControlMetra's class doc-comment), so the visible Text is
    // correctly occluded for hit-testing — silence the benign
    // "obscured by another widget" warning that follows from that by
    // design; the tap still lands on and is handled by the right segment,
    // as proven by the assertion below.
    await tester.tap(find.text('Tabella'), warnIfMissed: false);
    expect(received, 1);
  });

  testWidgets('renders correct number of segments', (tester) async {
    await tester.pumpWidget(
      _wrap(
        SegmentedControlMetra(
          segments: const ['A', 'B', 'C'],
          selectedIndex: 0,
          onChanged: (_) {},
        ),
        MetraTheme.light(),
      ),
    );
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('C'), findsOneWidget);
  });

  group('Group O — contrast statics (§5.4 FR-12)', () {
    // Canon track-tint alphas from ui-design-bible.md § 5.4. These are the
    // documented rgba(...) tint values, NOT MetraColors.bgSunken's actual
    // runtime alpha (a separate, pre-existing discrepancy — out of scope).
    const lightTrackTintAlpha = 0.08;
    const darkTrackTintAlpha = 0.10;

    final lightTrackTint = _compositeOver(
      MetraColors.light.ink.withValues(alpha: lightTrackTintAlpha),
      MetraColors.light.sand,
    );
    final darkTrackTint = _compositeOver(
      MetraColors.dark.ink.withValues(alpha: darkTrackTintAlpha),
      MetraColors.dark.sand,
    );

    test('light active-label (inchiostro on sabbia) clears 4.5:1', () {
      final ratio =
          _contrastRatio(MetraColors.light.ink, MetraColors.light.sand);
      expect(ratio, greaterThanOrEqualTo(4.5));
    });

    test('dark active-label (avorio on notte) clears 4.5:1', () {
      final ratio = _contrastRatio(MetraColors.dark.ink, MetraColors.dark.sand);
      expect(ratio, greaterThanOrEqualTo(4.5));
    });

    testWidgets(
        'light idle-label composited over the tinted track clears 4.5:1',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          SegmentedControlMetra(
            segments: _segments,
            selectedIndex: 0,
            onChanged: (_) {},
          ),
          MetraTheme.light(),
        ),
      );
      // 'Tabella' is the idle segment (index 1) — selectedIndex is 0.
      // style/color are always set by the widget for every segment, so the
      // `!` unwraps are safe here.
      final idleColor = tester.widget<Text>(find.text('Tabella')).style!.color!;
      final composite = _compositeOver(idleColor, lightTrackTint);
      final ratio = _contrastRatio(composite, lightTrackTint);
      expect(
        ratio,
        greaterThanOrEqualTo(4.5),
        reason: 'idle-label alpha ${idleColor.a} composited over the light '
            'tinted track must clear the NFR-04 4.5:1 floor (§5.4 FR-12)',
      );
    });

    testWidgets('dark idle-label composited over the tinted track clears 4.5:1',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          SegmentedControlMetra(
            segments: _segments,
            selectedIndex: 0,
            onChanged: (_) {},
          ),
          MetraTheme.dark(),
        ),
      );
      final idleColor = tester.widget<Text>(find.text('Tabella')).style!.color!;
      final composite = _compositeOver(idleColor, darkTrackTint);
      final ratio = _contrastRatio(composite, darkTrackTint);
      expect(
        ratio,
        greaterThanOrEqualTo(4.5),
        reason: 'idle-label alpha ${idleColor.a} composited over the dark '
            'tinted track must clear the NFR-04 4.5:1 floor (§5.4 FR-12)',
      );
    });
  });

  group('Group H — FR-12 tap-target (44×44 dp invisible hit-region)', () {
    testWidgets('each segment offers a hit-testable region >= 44x44 dp',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          SegmentedControlMetra(
            segments: _segments,
            selectedIndex: 0,
            onChanged: (_) {},
          ),
          MetraTheme.light(),
        ),
      );
      final hitRegions = find.descendant(
        of: find.byType(SegmentedControlMetra),
        matching: find.byType(GestureDetector),
      );
      expect(hitRegions, findsNWidgets(_segments.length));
      for (var i = 0; i < _segments.length; i++) {
        final size = tester.getSize(hitRegions.at(i));
        expect(size.width, greaterThanOrEqualTo(44));
        expect(size.height, greaterThanOrEqualTo(44));
      }
    });

    testWidgets('the visual pill keeps its unchanged 36 dp painted height',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          SegmentedControlMetra(
            segments: _segments,
            selectedIndex: 0,
            onChanged: (_) {},
          ),
          MetraTheme.light(),
        ),
      );
      final pills = find.descendant(
        of: find.byType(SegmentedControlMetra),
        matching: find.byType(AnimatedContainer),
      );
      expect(pills, findsNWidgets(_segments.length));
      for (var i = 0; i < _segments.length; i++) {
        // Pre-existing minHeight:36 constraint (not 34 — a documented,
        // out-of-scope deviation from the bible text). Unchanged by FR-12.
        expect(tester.getSize(pills.at(i)).height, 36.0);
      }
    });

    testWidgets('the decorated track container footprint does not grow',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          SegmentedControlMetra(
            segments: _segments,
            selectedIndex: 0,
            onChanged: (_) {},
          ),
          MetraTheme.light(),
        ),
      );
      // A dedicated Key is required here: find.byType(Container) also
      // matches AnimatedContainer's own internal Container implementation
      // detail (2 extra matches, one per segment), not just the track.
      final track = find.byKey(segmentedControlTrackKey);
      expect(track, findsOneWidget);
      // Row height (36, from the unchanged pill minHeight) + 3 dp track
      // padding each side — pre-existing geometry, untouched by FR-12.
      expect(tester.getSize(track).height, 42.0);
    });
  });

  group('Group C — Vista regression (FR-07 additive param)', () {
    testWidgets(
        'existing call site with no semanticsLabel keeps the Vista label',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          SegmentedControlMetra(
            segments: _segments,
            selectedIndex: 0,
            onChanged: (_) {},
          ),
          MetraTheme.light(),
        ),
      );
      final semantics = tester.getSemantics(find.byType(SegmentedControlMetra));
      expect(semantics.label, 'Vista');
    });
  });

  group('FR-07 — semanticsLabel wiring', () {
    testWidgets('passing semanticsLabel overrides the container label',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          SegmentedControlMetra(
            segments: _segments,
            selectedIndex: 0,
            onChanged: (_) {},
            semanticsLabel: 'Lingua',
          ),
          MetraTheme.light(),
        ),
      );
      final semantics = tester.getSemantics(find.byType(SegmentedControlMetra));
      expect(semantics.label, 'Lingua');
    });
  });
}
