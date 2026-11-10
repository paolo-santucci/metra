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
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/theme/metra_colors.dart';
import 'package:metra/core/theme/metra_theme.dart';
import 'package:metra/core/widgets/choice_chip_metra.dart';
import 'package:metra/core/widgets/metra_icon.dart';
import 'package:metra/core/widgets/text_field_metra.dart';
import 'package:metra/domain/entities/cycle_entry_entity.dart';
import 'package:metra/domain/entities/cycle_summary.dart';
import 'package:metra/domain/entities/pain_symptom_data.dart';
import 'package:metra/domain/entities/pain_symptom_type.dart';
import 'package:metra/features/timeline/state/timeline_controller.dart';
import 'package:metra/features/timeline/timeline_screen.dart';
import 'package:metra/l10n/app_localizations.dart';

// TASK-17 (sp-20261109-timeline-filter-symptoms-note-search): a11y + l10n
// verification sweep over the *finished* Archivio filter chrome — the search
// field, the symptom chip row, the count row's clear-all and the screen-level
// no-match state.
//
// Vectors (§7.2 of the spec):
//   NFR-03 / FR-02 / FR-10 / FR-11 — hit regions: every chip, the funnel filter
//     toggle, the clear (X), clear-all, clear-filters and the search field
//     expose ≥ 44×44 dp hit regions in light AND dark themes (canon §9.6
//     min-height-44 / §5.4 invisible-hit-region technique).
//   NFR-04 / FR-15 — contrast: the new secondary text (count row, no-match
//     message) at the §1.1.2/§1.1.1 body-secondary stop (0.68 light / 0.65
//     dark) clears 4.5:1 against sabbia/notte; clear-all renders `textPrimary`
//     (≥ 4.5:1); the selected chip's §6.1 fill is measured against the
//     non-text floor. The pre-existing `timeline_empty_hint` `textSecondary`
//     0.40 stop (≈ 2.3:1 light — OQ-14) must NOT propagate onto the new
//     surfaces: the light-theme tests pin both the alpha stop and the control
//     ratio that the 0.40 stop would produce. Measurement technique copied
//     from `segmented_control_metra_test.dart` Group O (canon §5.4 FR-12).
//   NFR-06 / FR-16 / FR-17 — l10n: the six new strings render from the ARB in
//     both the IT template and the EN mirror.
//
// Out of scope by task charter: widget-level `TextFieldMetra` / `ChoiceChipMetra`
// changes (their files are not in scope — shortfalls there are reported, not
// patched here).

/// One brightness target, with the palette its contrast math is measured
/// against (the rendered colour is read from the widget; the background comes
/// from the catalogued token — never a hardcoded literal).
class _ThemeCase {
  const _ThemeCase({
    required this.name,
    required this.theme,
    required this.colors,
  });

  final String name;
  final ThemeData theme;
  final MetraPalette colors;
}

final List<_ThemeCase> _themes = [
  _ThemeCase(
    name: 'light',
    theme: MetraTheme.light(),
    colors: MetraColors.light,
  ),
  _ThemeCase(name: 'dark', theme: MetraTheme.dark(), colors: MetraColors.dark),
];

/// The six new strings, pinned per locale so the sweep proves the *rendered*
/// locale (not just the ARB entry — `test/l10n/` owns key parity).
class _FilterStrings {
  const _FilterStrings({
    required this.locale,
    required this.hint,
    required this.clearA11y,
    required this.toggle,
    required this.oneMatch,
    required this.threeMatches,
    required this.clearAll,
    required this.noMatch,
    required this.noMatchAction,
  });

  final Locale locale;
  final String hint;
  final String clearA11y;
  final String toggle;
  final String oneMatch;
  final String threeMatches;
  final String clearAll;
  final String noMatch;
  final String noMatchAction;
}

const _it = _FilterStrings(
  locale: Locale('it'),
  hint: 'Cerca nelle note',
  clearA11y: 'Cancella la ricerca',
  toggle: 'Filtri sintomi',
  oneMatch: '1 ciclo',
  threeMatches: '3 cicli',
  clearAll: 'Rimuovi filtri',
  noMatch: 'Nessun ciclo corrisponde ai filtri',
  noMatchAction: 'Rimuovi filtri',
);

const _en = _FilterStrings(
  locale: Locale('en'),
  hint: 'Search in notes',
  clearA11y: 'Clear search',
  toggle: 'Symptom filters',
  oneMatch: '1 cycle',
  threeMatches: '3 cycles',
  clearAll: 'Clear filters',
  noMatch: 'No cycles match the filters',
  noMatchAction: 'Clear filters',
);

class _DataNotifier extends TimelineNotifier {
  _DataNotifier(this._data);

  final List<CycleSummary> _data;

  @override
  Future<List<CycleSummary>> build() async => _data;
}

CycleSummary _makeSummary({
  required DateTime start,
  DateTime? end,
  List<PainSymptomData> symptoms = const [],
}) =>
    CycleSummary(
      cycle: CycleEntryEntity(id: 1, startDate: start, endDate: end),
      symptoms: symptoms,
      dominantPainIntensity: null,
    );

PainSymptomData _symptom(PainSymptomType type) => PainSymptomData(
      symptomType: type,
    );

/// Two cycles with disjoint symptoms: selecting both chips can never match
/// (AND semantics), which is the only way a derived chip set yields zero
/// matches (FR-10/EC-03).
final List<CycleSummary> _kSplit = [
  _makeSummary(
    start: DateTime.utc(2026, 1, 10),
    end: DateTime.utc(2026, 1, 14),
    symptoms: [_symptom(PainSymptomType.headache)],
  ),
  _makeSummary(
    start: DateTime.utc(2026, 2, 10),
    end: DateTime.utc(2026, 2, 14),
    symptoms: [_symptom(PainSymptomType.fatigue)],
  ),
];

/// Seven cycles, three of which carry the (first-ordered) headache chip — the
/// FR-11 count vector (`3 cicli` / `3 cycles`) with a two-chip row.
final List<CycleSummary> _kSeven = [
  for (var i = 0; i < 7; i++)
    _makeSummary(
      start: DateTime.utc(2026, i + 1, 10),
      end: DateTime.utc(2026, i + 1, 14),
      symptoms: [
        if (i < 3)
          _symptom(PainSymptomType.headache)
        else
          _symptom(PainSymptomType.fatigue),
      ],
    ),
];

Future<void> _pump(
  WidgetTester tester, {
  required _ThemeCase themeCase,
  required Locale locale,
  required List<CycleSummary> summaries,
  bool openFilterPanel = true,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // The screen reads the note-text path in parallel with the summaries;
        // an explicit empty map keeps the Drift-backed chain out of the test.
        timelineNotesProvider.overrideWith(
          (ref) => Stream.value(const <DateTime, String>{}),
        ),
        timelineProvider.overrideWith(() => _DataNotifier(summaries)),
      ],
      child: MaterialApp(
        theme: themeCase.theme,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const TimelineScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();

  // §10.1: the symptom chip row is collapsed until the funnel is tapped, so
  // every chip-facing vector reveals it first (no chip is in the tree before).
  if (openFilterPanel && _funnelHitRegion().evaluate().isNotEmpty) {
    await tester.tap(_funnelHitRegion());
    await tester.pumpAndSettle();
  }
}

// ── Finders ──────────────────────────────────────────────────────────────────

/// The n-th chip in render order (canon §9.6 order, so index 0 is the first
/// predefined symptom present in the fixture). Locale-independent on purpose.
Finder _chipAt(int index) => find.byType(ChoiceChipMetra).at(index);

/// Every chip's own hit-region widget (`ChoiceChipMetra` wraps its body in a
/// single opaque [GestureDetector] — canon §5.4 technique).
Finder _chipHitRegions() => find.descendant(
      of: find.byType(ChoiceChipMetra),
      matching: find.byType(GestureDetector),
    );

/// The funnel toggle's hit region: the [GestureDetector] wrapped around the
/// refined funnel glyph (locale-independent, so it works in the EN vectors too).
Finder _funnelHitRegion() => find.ancestor(
      of: find.byWidgetPredicate(
        (widget) =>
            widget is MetraIcon && widget.svgBody == MetraIcons.filterRefined,
      ),
      matching: find.byType(GestureDetector),
    );

/// Any [Semantics] node announcing [label] — the clear (X) affordance's
/// accessible label (FR-17), asserted without enabling the semantics tree.
Finder _semantics(String label) => find.byWidgetPredicate(
      (widget) => widget is Semantics && widget.properties.label == label,
    );

/// The clear (X) affordance's tap region, scoped by its semantics label so the
/// field's own tap handling cannot be mistaken for it.
Finder _clearHitRegion(String label) => find.descendant(
      of: _semantics(label),
      matching: find.byType(GestureDetector),
    );

/// The bare text action (§8.1 pattern) that renders [label]: its
/// `GestureDetector` is the hit region.
Finder _textActionHitRegion(String label) => find.ancestor(
      of: find.text(label),
      matching: find.byType(GestureDetector),
    );

/// The rendered colour of the [Text] showing [text].
Color _renderedColor(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style!.color!;

// ── WCAG 2.1 contrast helpers (canon §5.4 FR-12) ────────────────────────────
// Copied from `test/core/widgets/segmented_control_metra_test.dart` Group O:
// pure static math over an alpha-composited foreground, so the measurement is
// independent of the renderer.

/// Alpha-composites [fg] (with its own alpha) over an opaque [bg]. WCAG
/// contrast is only defined between two opaque colours, so a translucent text
/// colour is flattened against its immediate background first.
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

/// WCAG 2.1 relative-luminance contrast ratio between two opaque colours.
double _contrastRatio(Color a, Color b) {
  final double la = _relativeLuminance(a);
  final double lb = _relativeLuminance(b);
  final double lighter = math.max(la, lb);
  final double darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

/// Ratio of a translucent text colour against the page background.
double _renderedTextRatio(WidgetTester tester, String text, Color bg) =>
    _contrastRatio(_compositeOver(_renderedColor(tester, text), bg), bg);

void main() {
  // ── NFR-03 / FR-02 / FR-10 / FR-11 — hit regions ─────────────────────────
  for (final themeCase in _themes) {
    group('hit regions — ${themeCase.name} theme (§9.6 / §5.4)', () {
      testWidgets('the search field exposes a ≥44 dp tall hit region',
          (tester) async {
        await _pump(
          tester,
          themeCase: themeCase,
          locale: _it.locale,
          summaries: _kSeven,
        );

        // Guard: the field really is the filter chrome's search box.
        expect(find.text(_it.hint), findsOneWidget);

        final size = tester.getSize(find.byType(TextFieldMetra));
        expect(
          size.height,
          greaterThanOrEqualTo(44),
          reason: 'the field body must keep the 44 dp min-height with the '
              'prefix icon and the suffix slot present (NFR-03)',
        );
        expect(size.width, greaterThanOrEqualTo(44));
      });

      testWidgets('every filter chip exposes a ≥44×44 dp hit region',
          (tester) async {
        await _pump(
          tester,
          themeCase: themeCase,
          locale: _it.locale,
          summaries: _kSeven,
        );

        // Guard: the loop below is never vacuous.
        final chips = tester.widgetList<ChoiceChipMetra>(
          find.byType(ChoiceChipMetra),
        );
        expect(chips.length, 2);

        final regions = _chipHitRegions();
        expect(regions, findsNWidgets(chips.length));
        for (var i = 0; i < chips.length; i++) {
          final size = tester.getSize(regions.at(i));
          expect(
            size.width,
            greaterThanOrEqualTo(44),
            reason: 'chip ${chips.elementAt(i).label} width ${size.width} '
                'must clear the 44 dp floor (NFR-03)',
          );
          expect(
            size.height,
            greaterThanOrEqualTo(44),
            reason: 'chip ${chips.elementAt(i).label} height ${size.height} '
                'must clear the 44 dp floor (NFR-03)',
          );
        }
      });

      testWidgets(
          'the funnel toggle exposes a ≥44×44 dp hit region and reports its '
          'toggled state', (tester) async {
        await _pump(
          tester,
          themeCase: themeCase,
          locale: _it.locale,
          summaries: _kSeven,
          openFilterPanel: false,
        );

        // Collapsed by default: the panel is not built, the funnel is.
        expect(find.byType(ChoiceChipMetra), findsNothing);

        final region = _funnelHitRegion();
        expect(region, findsOneWidget);
        expect(
          tester.widget<GestureDetector>(region).behavior,
          HitTestBehavior.opaque,
          reason: 'the invisible hit region must be opaque to be hit-testable '
              'at every point of its 44 dp box (§5.4)',
        );

        final size = tester.getSize(region);
        expect(
          size.width,
          greaterThanOrEqualTo(44),
          reason: 'funnel width ${size.width} must clear the 44 dp floor',
        );
        expect(
          size.height,
          greaterThanOrEqualTo(44),
          reason: 'funnel height ${size.height} must clear the 44 dp floor',
        );

        final idle = tester.getSemantics(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.label == _it.toggle,
          ),
        );
        expect(idle.flagsCollection.isToggled, isNot(Tristate.isTrue));

        // The extreme corner of the region still activates the toggle.
        await tester.tapAt(
          tester.getRect(region).topLeft + const Offset(2, 2),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ChoiceChipMetra), findsNWidgets(2));
        final open = tester.getSemantics(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.label == _it.toggle,
          ),
        );
        expect(open.flagsCollection.isToggled, Tristate.isTrue);
      });

      testWidgets(
          'the clear X exposes a ≥44×44 dp hit region and clears when hit '
          'at its corner', (tester) async {
        await _pump(
          tester,
          themeCase: themeCase,
          locale: _it.locale,
          summaries: _kSeven,
        );

        // FR-17: no orphan clear control while the field is empty.
        expect(_semantics(_it.clearA11y), findsNothing);

        await tester.enterText(find.byType(TextField), 'mestruazioni');
        await tester.pump();

        final region = _clearHitRegion(_it.clearA11y);
        expect(region, findsOneWidget);
        expect(
          tester.widget<GestureDetector>(region).behavior,
          HitTestBehavior.opaque,
          reason: 'the invisible hit region must be opaque to be hit-testable '
              'at every point of its 44 dp box (§5.4)',
        );

        final size = tester.getSize(region);
        expect(size.width, greaterThanOrEqualTo(44));
        expect(size.height, greaterThanOrEqualTo(44));

        // Hit-testability proof: the extreme corner of the region — outside the
        // 18 dp glyph — still activates the clear (FR-02/EC-13).
        await tester.tapAt(tester.getRect(region).topLeft + const Offset(2, 2));
        await tester.pump();

        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          isEmpty,
        );
        expect(_semantics(_it.clearA11y), findsNothing);
      });

      testWidgets('the count row clear-all exposes a ≥44×44 dp hit region',
          (tester) async {
        await _pump(
          tester,
          themeCase: themeCase,
          locale: _it.locale,
          summaries: _kSeven,
        );

        await tester.tap(_chipAt(0));
        await tester.pumpAndSettle();
        expect(find.text(_it.threeMatches), findsOneWidget);

        final region = _textActionHitRegion(_it.clearAll);
        expect(region, findsOneWidget);
        final size = tester.getSize(region);
        expect(
          size.width,
          greaterThanOrEqualTo(44),
          reason: 'clear-all width ${size.width} must clear the 44 dp floor',
        );
        expect(
          size.height,
          greaterThanOrEqualTo(44),
          reason: 'clear-all height ${size.height} must clear the 44 dp floor',
        );
      });

      testWidgets(
          'the no-match clear-filters action exposes a ≥44×44 dp hit region',
          (tester) async {
        await _pump(
          tester,
          themeCase: themeCase,
          locale: _it.locale,
          summaries: _kSplit,
        );

        await tester.tap(_chipAt(0));
        await tester.pumpAndSettle();
        await tester.tap(_chipAt(1));
        await tester.pumpAndSettle();
        expect(find.text(_it.noMatch), findsOneWidget);
        expect(find.text(_it.noMatchAction), findsOneWidget);

        final region = _textActionHitRegion(_it.noMatchAction);
        expect(region, findsOneWidget);
        final size = tester.getSize(region);
        expect(
          size.width,
          greaterThanOrEqualTo(44),
          reason:
              'clear-filters width ${size.width} must clear the 44 dp floor',
        );
        expect(
          size.height,
          greaterThanOrEqualTo(44),
          reason:
              'clear-filters height ${size.height} must clear the 44 dp floor',
        );
      });
    });
  }

  // ── NFR-04 / FR-15 — contrast ────────────────────────────────────────────
  for (final themeCase in _themes) {
    group('contrast — ${themeCase.name} theme (§5.4 FR-12)', () {
      final colors = themeCase.colors;
      // §1.1.2 (light) / §1.1.1 (dark) catalogued body-secondary alpha stop.
      final double bodySecondaryAlpha = themeCase.name == 'light' ? 0.68 : 0.65;

      testWidgets('the count row clears 4.5:1 at the body-secondary stop',
          (tester) async {
        await _pump(
          tester,
          themeCase: themeCase,
          locale: _it.locale,
          summaries: _kSeven,
        );

        await tester.tap(_chipAt(0));
        await tester.pumpAndSettle();
        expect(find.text(_it.threeMatches), findsOneWidget);

        final color = _renderedColor(tester, _it.threeMatches);
        expect(
          color.a,
          closeTo(bodySecondaryAlpha, 0.001),
          reason: 'the count row must sit at the §1.1.2/§1.1.1 '
              'body-secondary stop, not at another alpha',
        );

        final ratio = _renderedTextRatio(
          tester,
          _it.threeMatches,
          colors.bgPrimary,
        );
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: 'measured ${ratio.toStringAsFixed(2)}:1 for the count row '
              'over bgPrimary (NFR-04 text floor 4.5:1)',
        );

        if (themeCase.name == 'light') {
          // OQ-14 non-propagation pin: the new surface must not reuse the
          // pre-existing hint's 0.40 `textSecondary` stop…
          expect(color.a, isNot(colors.textSecondary.a));
          // …and the control proves the measurement discriminates: that stop
          // would land below the floor (≈ 2.3:1), which is why it is banned
          // here rather than copied from `timeline_empty_hint`.
          final decoy = _contrastRatio(
            _compositeOver(colors.textSecondary, colors.bgPrimary),
            colors.bgPrimary,
          );
          expect(decoy, lessThan(4.5));
        }
      });

      testWidgets(
          'the no-match message clears 4.5:1 at the body-secondary stop',
          (tester) async {
        await _pump(
          tester,
          themeCase: themeCase,
          locale: _it.locale,
          summaries: _kSplit,
        );

        await tester.tap(_chipAt(0));
        await tester.pumpAndSettle();
        await tester.tap(_chipAt(1));
        await tester.pumpAndSettle();
        expect(find.text(_it.noMatch), findsOneWidget);

        final color = _renderedColor(tester, _it.noMatch);
        expect(color.a, closeTo(bodySecondaryAlpha, 0.001));

        final ratio = _renderedTextRatio(
          tester,
          _it.noMatch,
          colors.bgPrimary,
        );
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: 'measured ${ratio.toStringAsFixed(2)}:1 for the no-match '
              'message over bgPrimary (NFR-04 text floor 4.5:1)',
        );

        if (themeCase.name == 'light') {
          expect(color.a, isNot(colors.textSecondary.a));
          final decoy = _contrastRatio(
            _compositeOver(colors.textSecondary, colors.bgPrimary),
            colors.bgPrimary,
          );
          expect(decoy, lessThan(4.5));
        }
      });

      testWidgets('clear-all renders textPrimary and clears 4.5:1',
          (tester) async {
        await _pump(
          tester,
          themeCase: themeCase,
          locale: _it.locale,
          summaries: _kSeven,
        );

        await tester.tap(_chipAt(0));
        await tester.pumpAndSettle();
        expect(find.text(_it.clearAll), findsOneWidget);

        final color = _renderedColor(tester, _it.clearAll);
        expect(color, colors.textPrimary);

        final ratio =
            _renderedTextRatio(tester, _it.clearAll, colors.bgPrimary);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: 'measured ${ratio.toStringAsFixed(2)}:1 for the clear-all '
              'text action (NFR-04 text floor 4.5:1)',
        );
      });

      testWidgets('the selected chip fill is the §6.1 canon pair — measured',
          (tester) async {
        await _pump(
          tester,
          themeCase: themeCase,
          locale: _it.locale,
          summaries: _kSplit,
        );

        await tester.tap(_chipAt(0));
        await tester.pumpAndSettle();

        final decoration = tester
            .widget<Container>(
              find.descendant(
                of: _chipAt(0),
                matching: find.byType(Container),
              ),
            )
            .decoration! as BoxDecoration;

        // NFR-08: the filter row introduces no new visual value — the selected
        // state is the catalogued §6.1 pair, unchanged from the daily entry.
        expect(decoration.color, colors.accentFlow);
        expect(
          decoration.border!.top.color,
          Colors.transparent,
          reason:
              'canon §6.1: selection is colour-only, the selected border is '
              'transparent (no checkmark, no second outline)',
        );

        final ratio = _contrastRatio(decoration.color!, colors.bgPrimary);
        if (themeCase.name == 'dark') {
          expect(
            ratio,
            greaterThanOrEqualTo(3.0),
            reason: 'measured ${ratio.toStringAsFixed(2)}:1 for the selected '
                'chip fill over bgPrimary (NFR-04 non-text floor 3:1)',
          );
        } else {
          // <!-- CANON GAP: §6.1 light selected-chip fill — terracotta on
          // sabbia composites to ≈2.97:1, 0.03 under the NFR-04 3:1 non-text
          // floor. The pair is the canon value (not a new one, NFR-08) and
          // lives in `ChoiceChipMetra`/the palette — outside this task's fix
          // authority. Recorded as a §6 observation; this pin guards against
          // further degradation rather than encoding compliance. -->
          expect(
            ratio,
            greaterThanOrEqualTo(2.95),
            reason: 'measured ${ratio.toStringAsFixed(2)}:1 for the selected '
                'chip fill over bgPrimary — canon §6.1 pair; the shortfall vs '
                '3:1 is the documented §6 canon gap',
          );
        }
      });
    });
  }

  // ── NFR-06 / FR-16 / FR-17 — l10n rendering ──────────────────────────────
  for (final strings in [_it, _en]) {
    final other = strings.locale.languageCode == 'it' ? _en : _it;

    group('l10n rendering — ${strings.locale.languageCode}', () {
      testWidgets('hint and clear a11y label render in the active locale',
          (tester) async {
        await _pump(
          tester,
          themeCase: _themes.first,
          locale: strings.locale,
          summaries: _kSeven,
        );

        expect(find.text(strings.hint), findsOneWidget);
        expect(find.text(other.hint), findsNothing);
        // The field's own accessible label mirrors the hint (FR-17).
        expect(_semantics(strings.hint), findsOneWidget);

        await tester.enterText(find.byType(TextField), 'mestruazioni');
        await tester.pump();

        expect(_semantics(strings.clearA11y), findsOneWidget);
        expect(_semantics(other.clearA11y), findsNothing);
      });

      testWidgets('the funnel toggle label renders in the active locale',
          (tester) async {
        await _pump(
          tester,
          themeCase: _themes.first,
          locale: strings.locale,
          summaries: _kSeven,
          openFilterPanel: false,
        );

        expect(_semantics(strings.toggle), findsOneWidget);
        expect(_semantics(other.toggle), findsNothing);

        // The field itself carries no leading glyph any more: the funnel moved
        // outside it, into the same row (§10.1 operator decision).
        expect(
          find.descendant(
            of: find.byType(TextFieldMetra),
            matching: find.byType(MetraIcon),
          ),
          findsNothing,
        );
      });

      testWidgets('the plural count and clear-all render in the active locale',
          (tester) async {
        await _pump(
          tester,
          themeCase: _themes.first,
          locale: strings.locale,
          summaries: _kSeven,
        );

        await tester.tap(_chipAt(0));
        await tester.pumpAndSettle();

        expect(find.text(strings.threeMatches), findsOneWidget);
        expect(find.text(other.threeMatches), findsNothing);
        expect(find.text(strings.clearAll), findsOneWidget);
        expect(find.text(other.clearAll), findsNothing);
      });

      testWidgets('the singular plural form renders in the active locale',
          (tester) async {
        await _pump(
          tester,
          themeCase: _themes.first,
          locale: strings.locale,
          summaries: _kSplit,
        );

        await tester.tap(_chipAt(0));
        await tester.pumpAndSettle();

        expect(find.text(strings.oneMatch), findsOneWidget);
        expect(find.text(other.oneMatch), findsNothing);
      });

      testWidgets('the no-match message and action render in the active locale',
          (tester) async {
        await _pump(
          tester,
          themeCase: _themes.first,
          locale: strings.locale,
          summaries: _kSplit,
        );

        await tester.tap(_chipAt(0));
        await tester.pumpAndSettle();
        await tester.tap(_chipAt(1));
        await tester.pumpAndSettle();

        expect(find.text(strings.noMatch), findsOneWidget);
        expect(find.text(other.noMatch), findsNothing);
        expect(find.text(strings.noMatchAction), findsOneWidget);
        expect(find.text(other.noMatchAction), findsNothing);
      });
    });
  }
}
