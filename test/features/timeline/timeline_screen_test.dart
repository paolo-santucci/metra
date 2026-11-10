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

import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:metra/core/theme/metra_theme.dart';
import 'package:metra/core/widgets/choice_chip_metra.dart';
import 'package:metra/core/widgets/metra_icon.dart';
import 'package:metra/core/widgets/segmented_control_metra.dart';
import 'package:metra/core/widgets/text_field_metra.dart';
import 'package:metra/domain/entities/cycle_entry_entity.dart';
import 'package:metra/domain/entities/cycle_summary.dart';
import 'package:metra/domain/entities/daily_log_entity.dart';
import 'package:metra/domain/entities/pain_symptom_data.dart';
import 'package:metra/domain/entities/pain_symptom_type.dart';
import 'package:metra/features/timeline/state/timeline_controller.dart';
import 'package:metra/features/timeline/timeline_screen.dart';
import 'package:metra/features/timeline/widgets/table_view.dart';
import 'package:metra/features/timeline/widgets/timeline_card.dart';
import 'package:metra/features/timeline/widgets/timeline_view.dart';
import 'package:metra/l10n/app_localizations.dart';
import 'package:metra/providers/calendar_focus_provider.dart';
import 'package:metra/providers/repository_providers.dart';

import '../../helpers/fake_cycle_entry_repository.dart';
import '../../helpers/fake_daily_log_repository.dart';

// TASK-15 (sp-20260705-gh-issues-batch-onboard-notif-calendar): tapping a
// Timeline card must record a calendarFocusRequestProvider request BEFORE
// navigating to /calendar (reversed order would let CalendarScreen build —
// and consume/clear the request — before it lands, silently dropping it).
// Traces to ui-design-bible §10.3 (card anatomy) + §5 (no-ripple tap
// affordance); the Table/"Tabella" view stays non-interactive (guarded by a
// later task, not here).

/// Spy [CalendarFocusRequest] that records the router's current location at
/// the moment `request()` is invoked. `GoRouteInformationProvider.value` is
/// updated synchronously inside `context.go(...)`, before any frame/rebuild
/// — so if a future change reordered `onCardTap` to call `context.go(...)`
/// first, the recorded location would already read '/calendar' instead of
/// '/timeline', failing the order assertion below.
class _SpyCalendarFocusRequest extends CalendarFocusRequest {
  _SpyCalendarFocusRequest(this._router);

  final GoRouter _router;

  /// Router location captured on each `request()` call, in call order.
  final List<String> locationsAtRequestTime = [];

  @override
  void request(DateTime date) {
    locationsAtRequestTime
        .add(_router.routeInformationProvider.value.uri.toString());
    super.request(date);
  }
}

// Fake notifiers — extend TimelineNotifier and override build().
// Do NOT call super.build() — these are pure stubs.

class _LoadingNotifier extends TimelineNotifier {
  @override
  Future<List<CycleSummary>> build() => Completer<List<CycleSummary>>().future;
}

class _ErrorNotifier extends TimelineNotifier {
  @override
  Future<List<CycleSummary>> build() async => throw Exception('test error');
}

class _DataNotifier extends TimelineNotifier {
  _DataNotifier(this._data);
  final List<CycleSummary> _data;
  @override
  Future<List<CycleSummary>> build() async => _data;
}

// Helper: wrap TimelineScreen with GoRouter + ProviderScope + MaterialApp.
// `routerAwareOverrides` receives the constructed [GoRouter] so a test can
// spy on a provider that needs to inspect the router's live location (the
// #3 focus-before-navigate order assertion below).
Widget _wrap(
  List<Override> overrides, {
  List<Override> Function(GoRouter router)? routerAwareOverrides,
  Map<DateTime, String> notes = const <DateTime, String>{},
  bool overrideNotesProvider = true,
}) {
  final router = GoRouter(
    initialLocation: '/timeline',
    routes: [
      GoRoute(path: '/timeline', builder: (_, __) => const TimelineScreen()),
      GoRoute(
        path: '/daily-entry/:date',
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('entry-stub'))),
      ),
      GoRoute(
        path: '/calendar',
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('calendar-stub'))),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      // TASK-12: the screen derives the filtered list from
      // `timelineNotesProvider`, so every test controls the note map through
      // this override instead of touching the Drift-backed chain (the default
      // empty map keeps the pre-filter suites byte-identical).
      //
      // TASK-13: the read-budget test opts out to exercise the real
      // repository-backed note path.
      if (overrideNotesProvider)
        timelineNotesProvider.overrideWith((ref) => Stream.value(notes)),
      ...overrides,
      ...?routerAwareOverrides?.call(router),
    ],
    child: MaterialApp.router(
      theme: MetraTheme.light(),
      locale: const Locale('it'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

// Helper: make a minimal CycleSummary
CycleSummary _makeSummary({
  required DateTime start,
  DateTime? end,
  int? cycleLength,
  int? periodLength,
  List<PainSymptomData> symptoms = const [],
}) =>
    CycleSummary(
      cycle: CycleEntryEntity(
        id: 1,
        startDate: start,
        endDate: end,
        cycleLength: cycleLength,
        periodLength: periodLength,
      ),
      symptoms: symptoms,
      dominantPainIntensity: null,
    );

// Helper: one recorded symptom, predefined or custom.
PainSymptomData _symptom(PainSymptomType type, [String? label]) =>
    PainSymptomData(symptomType: type, customLabel: label);

// Helper: a chip-row label lookup. Scoped to ChoiceChipMetra because
// TimelineCard renders the same symptom labels on the cards below (FR-03).
Finder _chipText(String label) => find.descendant(
      of: find.byType(ChoiceChipMetra),
      matching: find.text(label),
    );

Finder _chip(String label) => find.ancestor(
      of: _chipText(label),
      matching: find.byType(ChoiceChipMetra),
    );

// Helper: chip labels in render order (FR-04).
List<String> _chipLabels(WidgetTester tester) => tester
    .widgetList<ChoiceChipMetra>(find.byType(ChoiceChipMetra))
    .map((chip) => chip.label)
    .toList();

// Helper: the labels of the chips currently toggled on, in render order
// (EC-14 — proves which selection survived a re-derivation).
List<String> _selectedChipLabels(WidgetTester tester) => tester
    .widgetList<ChoiceChipMetra>(find.byType(ChoiceChipMetra))
    .where((chip) => chip.selected)
    .map((chip) => chip.label)
    .toList();

// Helper: the field's own glyphs (the optional clear X only — the funnel lives
// outside the field, in the same row), scoped to TextFieldMetra because the
// cards carry MetraIcons too.
Finder _fieldIcons() => find.descendant(
      of: find.byType(TextFieldMetra),
      matching: find.byType(MetraIcon),
    );

// Helper: any Semantics widget announcing [label] — used to prove the hidden
// clear control leaves no orphan semantics node behind (FR-17).
Finder _semanticsWithLabel(String label) => find.byWidgetPredicate(
      (widget) => widget is Semantics && widget.properties.label == label,
    );

// Helper: the funnel on the view-toggle line that reveals the whole filter
// panel — search field, chip row and count row (§10.1). It is found by its
// glyph, so the finder is locale-independent. The panel is collapsed by
// default, so every filter-facing test opens it first.
Finder _filterToggle() => find.ancestor(
      of: find.byWidgetPredicate(
        (widget) =>
            widget is MetraIcon && widget.svgBody == MetraIcons.filterRefined,
      ),
      matching: find.byType(GestureDetector),
    );

/// The funnel's accessible name, read from the delegate rather than hardcoded
/// (§5.1.H copy lives in the ARB — FR-17).
String _filterToggleLabel(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(TimelineScreen)))!
        .timeline_filters_toggle_a11y;

/// Whether the whole filter panel is on screen. Keyed on the field: the panel
/// always renders it, while the chip row is omitted when the data carries no
/// symptom at all (EC-02).
bool _isFilterPanelOpen() => find.byType(TextFieldMetra).evaluate().isNotEmpty;

/// Reveals the filter panel (idempotent, so a test can call it without
/// tracking the panel state). Pass `settle: false` on the loading-branch
/// harnesses, whose spinner never settles.
Future<void> _openFilterPanel(WidgetTester tester, {bool settle = true}) async {
  if (_isFilterPanelOpen()) return;
  await tester.tap(_filterToggle());
  if (!settle) {
    await tester.pump();
    return;
  }
  await tester.pumpAndSettle();
}

/// Hides the filter panel, which also drops every filter (§10.1).
Future<void> _closeFilterPanel(WidgetTester tester) async {
  await tester.tap(_filterToggle());
  await tester.pumpAndSettle();
}

// Helper: start dates of the rendered cards, in order — proves which cycles
// survived the filter (TASK-12).
List<DateTime> _cardStarts(WidgetTester tester) => tester
    .widgetList<TimelineCard>(find.byType(TimelineCard))
    .map((card) => card.summary.cycle.startDate)
    .toList();

// Helper: the Tabella data rows (`_DataRow` is private to table_view.dart).
Finder _tableRows() => find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == '_DataRow',
    );

// Helper: the polite live region that announces the result count (FR-15).
Finder _liveRegion() => find.byWidgetPredicate(
      (widget) => widget is Semantics && widget.properties.liveRegion == true,
    );

// Helper: the search field's raw text, as the user sees it (TASK-13).
String _fieldText(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).controller!.text;

// Helper: a cycle table row for the repository-backed read-budget harness.
CycleEntryEntity _cycleEntry(DateTime start, {DateTime? end}) =>
    CycleEntryEntity(
      id: start.millisecondsSinceEpoch,
      startDate: start,
      endDate: end,
    );

// Spy [DailyLogRepository] counting the reads the screen's data path performs
// (TASK-13, NFR-02 read budget).
class _CountingDailyLogRepository extends FakeDailyLogRepository {
  int getAllOrderedByDateCalls = 0;
  int getPainSymptomsCalls = 0;

  @override
  Future<List<DailyLogEntity>> getAllOrderedByDate() {
    getAllOrderedByDateCalls++;
    return super.getAllOrderedByDate();
  }

  @override
  Future<List<PainSymptomData>> getPainSymptoms(DateTime date) {
    getPainSymptomsCalls++;
    return super.getPainSymptoms(date);
  }
}

// Fake whose `watchAll()` is a caller-supplied BROADCAST stream: the shared
// fake's controllable mode is single-subscription, while the screen's real
// chain subscribes twice (summaries + notes) to the same emission.
class _BroadcastCycleRepository extends FakeCycleEntryRepository {
  _BroadcastCycleRepository(this._watchAll);

  final Stream<List<CycleEntryEntity>> _watchAll;

  @override
  Stream<List<CycleEntryEntity>> watchAll() => _watchAll;
}

// TASK-16: a `timelineProvider` notifier fed by a caller-owned stream, so one
// test can push several table-trigger emissions through the same provider.
// Mirrors the production [TimelineNotifier] shape exactly: the FIRST emission
// completes `build()`, every later one lands in `state` (EC-14/EC-15).
class _ReemittingNotifier extends TimelineNotifier {
  _ReemittingNotifier(this._emissions);

  final Stream<List<CycleSummary>> _emissions;

  @override
  Future<List<CycleSummary>> build() async {
    final completer = Completer<List<CycleSummary>>();
    final sub = _emissions.listen((summaries) {
      if (!completer.isCompleted) {
        completer.complete(summaries);
      } else {
        state = AsyncData(summaries);
      }
    });
    ref.onDispose(sub.cancel);
    return completer.future;
  }
}

void main() {
  group('TimelineScreen — loading', () {
    testWidgets('shows spinner while loading', (tester) async {
      await tester.pumpWidget(
        _wrap([timelineProvider.overrideWith(_LoadingNotifier.new)]),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('TimelineScreen — error', () {
    testWidgets('shows error text on failure', (tester) async {
      await tester.pumpWidget(
        _wrap([timelineProvider.overrideWith(_ErrorNotifier.new)]),
      );
      await tester.pumpAndSettle();
      expect(find.text('Qualcosa è andato storto. Riprova.'), findsOneWidget);
    });
  });

  group('TimelineScreen — empty data', () {
    testWidgets('shows empty-state hint when no cycles', (tester) async {
      await tester.pumpWidget(
        _wrap([timelineProvider.overrideWith(() => _DataNotifier([]))]),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Registra il tuo primo ciclo'),
        findsOneWidget,
      );
    });
  });

  group('TimelineScreen — with data', () {
    final kSummaries = [
      _makeSummary(
        start: DateTime.utc(2026, 1, 15),
        end: DateTime.utc(2026, 1, 20),
        cycleLength: 28,
        periodLength: 6,
      ),
    ];

    testWidgets('renders TimelineCard in timeline mode', (tester) async {
      await tester.pumpWidget(
        _wrap([timelineProvider.overrideWith(() => _DataNotifier(kSummaries))]),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TimelineCard), findsOneWidget);
    });

    testWidgets('tapping Tabella segment switches to table view',
        (tester) async {
      await tester.pumpWidget(
        _wrap([timelineProvider.overrideWith(() => _DataNotifier(kSummaries))]),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tabella'));
      await tester.pumpAndSettle();
      expect(find.byType(TimelineCard), findsNothing);
      // §10.4 rebuild renamed first column from "Inizio" to "Mese"
      expect(find.text('Mese'), findsOneWidget);
    });

    testWidgets('TimelineCard shows month label and footer', (tester) async {
      await tester.pumpWidget(
        _wrap([timelineProvider.overrideWith(() => _DataNotifier(kSummaries))]),
      );
      await tester.pumpAndSettle();
      // Month label contains locale-formatted start date
      expect(find.textContaining('gen'), findsWidgets);
      // Footer contains cycle length
      expect(find.textContaining('Ciclo 28g'), findsOneWidget);
    });

    testWidgets('flow pill always renders, shows dash when no flow',
        (tester) async {
      await tester.pumpWidget(
        _wrap([timelineProvider.overrideWith(() => _DataNotifier(kSummaries))]),
      );
      await tester.pumpAndSettle();
      expect(find.text('—'), findsOneWidget);
    });
  });

  group('TimelineScreen — onCardTap navigation (#3)', () {
    final kSummary = _makeSummary(
      start: DateTime.utc(2026, 1, 15),
      end: DateTime.utc(2026, 1, 20),
      cycleLength: 28,
      periodLength: 6,
    );

    testWidgets(
        'tapping a card requests calendar focus with the card startDate '
        'BEFORE navigating to /calendar (order regression guard)',
        (tester) async {
      late _SpyCalendarFocusRequest spy;
      await tester.pumpWidget(
        _wrap(
          [
            timelineProvider.overrideWith(() => _DataNotifier([kSummary])),
          ],
          routerAwareOverrides: (router) {
            spy = _SpyCalendarFocusRequest(router);
            return [calendarFocusRequestProvider.overrideWith(() => spy)];
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TimelineCard));

      // request() ran while the router was still on '/timeline' — proves
      // it fired strictly before context.go('/calendar') took effect.
      expect(spy.locationsAtRequestTime, ['/timeline']);
      expect(spy.state, kSummary.cycle.startDate);

      await tester.pumpAndSettle();
      expect(find.text('calendar-stub'), findsOneWidget);
    });

    testWidgets('tapping a card in Timeline mode navigates to /calendar',
        (tester) async {
      await tester.pumpWidget(
        _wrap([
          timelineProvider.overrideWith(() => _DataNotifier([kSummary])),
        ]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TimelineCard));
      await tester.pumpAndSettle();

      expect(find.text('calendar-stub'), findsOneWidget);
      expect(find.byType(TimelineScreen), findsNothing);
    });
  });

  // TASK-10 (sp-20261109-timeline-filter-symptoms-note-search): the filter
  // chrome mounts directly below the segmented control, Timeline view only —
  // search field first with the funnel toggle beside it, then the collapsible
  // chip row derived from the FULL unfiltered dataset (canon §10.1 header
  // order; FR-01/FR-03/FR-04/FR-16/FR-17, EC-01/EC-02, OQ-06).
  group('TimelineScreen — filter chrome', () {
    final kSymptomSummaries = [
      _makeSummary(
        start: DateTime.utc(2026, 1, 15),
        symptoms: [
          _symptom(PainSymptomType.headache),
          _symptom(PainSymptomType.fatigue),
          _symptom(PainSymptomType.custom, 'Vertigini'),
        ],
      ),
      _makeSummary(
        start: DateTime.utc(2026, 2, 12),
        symptoms: [
          _symptom(PainSymptomType.headache),
          _symptom(PainSymptomType.custom, 'Acne'),
          _symptom(PainSymptomType.migraine),
        ],
      ),
    ];

    final kAllSymptomSummaries = [
      _makeSummary(
        start: DateTime.utc(2026, 3, 10),
        symptoms: [
          _symptom(PainSymptomType.breastTenderness),
          _symptom(PainSymptomType.custom, 'Vertigini'),
          _symptom(PainSymptomType.nausea),
          _symptom(PainSymptomType.bloating),
          _symptom(PainSymptomType.backPain),
          _symptom(PainSymptomType.migraine),
          _symptom(PainSymptomType.custom, 'Acne'),
          _symptom(PainSymptomType.fatigue),
          _symptom(PainSymptomType.headache),
        ],
      ),
    ];

    final kPlainSummaries = [
      _makeSummary(start: DateTime.utc(2026, 1, 15)),
    ];

    List<Override> overridesFor(List<CycleSummary> summaries) {
      return [
        timelineProvider.overrideWith(() => _DataNotifier(summaries)),
      ];
    }

    testWidgets(
        'keeps the whole panel collapsed until the funnel is tapped, then '
        'mounts the search field below the toggle line', (tester) async {
      await tester.pumpWidget(_wrap(overridesFor(kSymptomSummaries)));
      await tester.pumpAndSettle();

      // §10.1: collapsed by default — not "offstage", not in the tree. Only
      // the funnel is offered, on the view-toggle line.
      expect(find.byType(TextFieldMetra), findsNothing);
      expect(find.byType(ChoiceChipMetra), findsNothing);
      expect(_liveRegion(), findsNothing);
      expect(_filterToggle(), findsOneWidget);
      // …right-aligned on the toggle's own line (same vertical centre).
      expect(
        tester.getCenter(_filterToggle()).dy,
        closeTo(
          tester.getCenter(find.byType(SegmentedControlMetra)).dy,
          0.5,
        ),
      );
      final segmentedBottom =
          tester.getBottomLeft(find.byType(SegmentedControlMetra)).dy;

      await _openFilterPanel(tester);

      expect(find.byType(TextFieldMetra), findsOneWidget);
      final fieldTop = tester.getTopLeft(find.byType(TextFieldMetra)).dy;
      expect(fieldTop, greaterThanOrEqualTo(segmentedBottom));
      // The funnel is right-aligned to the chrome's trailing edge, which the
      // full-width field also ends on.
      expect(
        tester.getTopRight(_filterToggle()).dx,
        closeTo(tester.getTopRight(find.byType(TextFieldMetra)).dx, 0.5),
      );
    });

    testWidgets('the funnel exposes button/toggled semantics with its label',
        (tester) async {
      await tester.pumpWidget(_wrap(overridesFor(kSymptomSummaries)));
      await tester.pumpAndSettle();

      final label = _filterToggleLabel(tester);
      expect(_semanticsWithLabel(label), findsOneWidget);
      final collapsed = tester.widget<Semantics>(
        _semanticsWithLabel(label),
      );
      expect(collapsed.properties.button, isTrue);
      expect(collapsed.properties.toggled, isFalse);
      expect(
        tester
            .getSemantics(_semanticsWithLabel(label))
            .flagsCollection
            .isToggled,
        isNot(Tristate.isTrue),
      );

      await _openFilterPanel(tester);

      final expanded = tester.widget<Semantics>(_semanticsWithLabel(label));
      expect(expanded.properties.button, isTrue);
      expect(
        tester
            .getSemantics(_semanticsWithLabel(label))
            .flagsCollection
            .isToggled,
        Tristate.isTrue,
      );
    });

    testWidgets(
        'renders neither the search field nor the funnel in table mode, and '
        'the table always shows every cycle', (tester) async {
      await tester.pumpWidget(_wrap(overridesFor(kSymptomSummaries)));
      await tester.pumpAndSettle();
      await _openFilterPanel(tester);
      expect(find.byType(TextFieldMetra), findsOneWidget);
      expect(_filterToggle(), findsOneWidget);

      await tester.tap(find.text('Tabella'));
      await tester.pumpAndSettle();

      // §10.1: the table owns no filter chrome at all.
      expect(find.byType(TextFieldMetra), findsNothing);
      expect(_filterToggle(), findsNothing);
      expect(find.byType(ChoiceChipMetra), findsNothing);
      expect(find.textContaining('Cerca nelle note'), findsNothing);
      // …because Tabella never filters: all four cycles are listed.
      expect(_tableRows(), findsNWidgets(kSymptomSummaries.length));
    });

    testWidgets('derives one chip per distinct symptom', (tester) async {
      await tester.pumpWidget(_wrap(overridesFor(kSymptomSummaries)));
      await tester.pumpAndSettle();
      await _openFilterPanel(tester);

      expect(_chipLabels(tester), [
        'Mal di testa',
        'Stanchezza',
        'Emicrania',
        'Acne',
        'Vertigini',
      ]);
    });

    testWidgets('keeps all chips when one is selected', (tester) async {
      await tester.pumpWidget(_wrap(overridesFor(kSymptomSummaries)));
      await tester.pumpAndSettle();
      await _openFilterPanel(tester);

      await tester.tap(_chip('Mal di testa'));
      await tester.pump();

      expect(
        tester.widget<ChoiceChipMetra>(_chip('Mal di testa')).selected,
        isTrue,
      );
      expect(
        tester.widget<ChoiceChipMetra>(_chip('Stanchezza')).selected,
        isFalse,
      );
      expect(_chipLabels(tester).length, 5);

      // A second chip still toggles on: the filter is AND across chips and the
      // chip set never derives from the filtered list (EC-12).
      await tester.tap(_chip('Stanchezza'));
      await tester.pump();
      expect(
        tester.widget<ChoiceChipMetra>(_chip('Stanchezza')).selected,
        isTrue,
      );
    });

    testWidgets('orders predefined, then legacy, then custom chips',
        (tester) async {
      await tester.pumpWidget(_wrap(overridesFor(kAllSymptomSummaries)));
      await tester.pumpAndSettle();
      await _openFilterPanel(tester);

      expect(_chipLabels(tester), [
        'Mal di testa',
        'Stanchezza',
        'Mal di schiena',
        'Nausea',
        'Gonfiore',
        'Tensione mammaria',
        'Emicrania',
        'Acne',
        'Vertigini',
      ]);
    });

    testWidgets('renders the field and no chip row with zero cycles',
        (tester) async {
      await tester.pumpWidget(_wrap(overridesFor(const <CycleSummary>[])));
      await tester.pumpAndSettle();
      await _openFilterPanel(tester);

      // The funnel is offered even without a derivable chip: the panel also
      // carries the note search (FR-01/FR-02).
      expect(_filterToggle(), findsOneWidget);
      expect(find.byType(TextFieldMetra), findsOneWidget);
      // Nothing to toggle: with no symptom in the data there is no chip row
      // (EC-02).
      expect(find.byType(ChoiceChipMetra), findsNothing);
      // …and the truly-empty hint still outranks any filter (EC-01).
      expect(
        find.textContaining('Registra il tuo primo ciclo'),
        findsOneWidget,
      );
    });

    testWidgets('omits the chip row when no cycle has symptoms',
        (tester) async {
      await tester.pumpWidget(_wrap(overridesFor(kPlainSummaries)));
      await tester.pumpAndSettle();
      await _openFilterPanel(tester);

      expect(_filterToggle(), findsOneWidget);
      expect(find.byType(TextFieldMetra), findsOneWidget);
      expect(find.byType(ChoiceChipMetra), findsNothing);
    });

    testWidgets(
        'keeps the chip row hidden until the funnel is tapped, and closing it '
        'builds no chip at all', (tester) async {
      await tester.pumpWidget(_wrap(overridesFor(kSymptomSummaries)));
      await tester.pumpAndSettle();

      // Collapsed by default: not "offstage" — not in the tree.
      expect(find.byType(ChoiceChipMetra), findsNothing);
      expect(_filterToggle(), findsOneWidget);

      await _openFilterPanel(tester);
      expect(find.byType(ChoiceChipMetra), findsNWidgets(5));

      await _closeFilterPanel(tester);
      expect(find.byType(ChoiceChipMetra), findsNothing);
    });

    testWidgets(
        'closing the funnel deselects the chips and re-expands the list',
        (tester) async {
      await tester.pumpWidget(_wrap(overridesFor(kSymptomSummaries)));
      await tester.pumpAndSettle();
      await _openFilterPanel(tester);

      await tester.tap(_chip('Stanchezza'));
      await tester.pumpAndSettle();
      expect(find.text('1 ciclo'), findsOneWidget);
      expect(_cardStarts(tester), [DateTime.utc(2026, 1, 15)]);

      // A filter the user cannot see must never keep narrowing the list.
      await _closeFilterPanel(tester);
      expect(find.byType(ChoiceChipMetra), findsNothing);
      expect(find.text('1 ciclo'), findsNothing);
      expect(
        _cardStarts(tester),
        [DateTime.utc(2026, 1, 15), DateTime.utc(2026, 2, 12)],
      );

      // Reopening shows the same chips, all deselected.
      await _openFilterPanel(tester);
      expect(_selectedChipLabels(tester), isEmpty);
    });

    testWidgets('chips expose toggled semantics', (tester) async {
      await tester.pumpWidget(_wrap(overridesFor(kSymptomSummaries)));
      await tester.pumpAndSettle();
      await _openFilterPanel(tester);

      final idle = tester.getSemantics(_chip('Mal di testa'));
      expect(idle.label, 'Mal di testa');
      expect(idle.flagsCollection.isToggled, isNot(Tristate.isTrue));

      await tester.tap(_chip('Mal di testa'));
      await tester.pump();

      final selected = tester.getSemantics(_chip('Mal di testa'));
      expect(selected.label, 'Mal di testa');
      expect(selected.flagsCollection.isToggled, Tristate.isTrue);
    });

    testWidgets('field exposes its semantics label', (tester) async {
      await tester.pumpWidget(_wrap(overridesFor(kSymptomSummaries)));
      await tester.pumpAndSettle();
      await _openFilterPanel(tester);

      final semantics = tester.getSemantics(find.byType(TextFieldMetra));
      expect(semantics.label, 'Cerca nelle note');
    });

    testWidgets('clear affordance toggles with the raw query', (tester) async {
      await tester.pumpWidget(_wrap(overridesFor(kSymptomSummaries)));
      await tester.pumpAndSettle();
      await _openFilterPanel(tester);

      // Empty query: the field carries no glyph at all (the funnel sits beside
      // it, outside the field) and no clear control exists (FR-17).
      expect(_fieldIcons(), findsNothing);
      expect(_semanticsWithLabel('Cancella la ricerca'), findsNothing);

      await tester.enterText(find.byType(TextField), 'mestruazioni');
      await tester.pump();

      expect(_fieldIcons(), findsOneWidget);
      expect(_semanticsWithLabel('Cancella la ricerca'), findsOneWidget);

      await tester.tap(_semanticsWithLabel('Cancella la ricerca'));
      await tester.pump();

      expect(_fieldIcons(), findsNothing);
      expect(_semanticsWithLabel('Cancella la ricerca'), findsNothing);
    });

    testWidgets(
        'closing the panel clears the typed query, the chips and the count '
        'row, and re-expands the list', (tester) async {
      // One note carries the token, so the text filter demonstrably narrows.
      await tester.pumpWidget(
        _wrap(
          overridesFor(kSymptomSummaries),
          notes: {DateTime.utc(2026, 1, 16): 'Vertigini forti'},
        ),
      );
      await tester.pumpAndSettle();
      await _openFilterPanel(tester);

      await tester.enterText(find.byType(TextField), 'vert');
      await tester.pump(const Duration(milliseconds: 300));

      // A committed text query narrows the list and shows the count row.
      expect(_cardStarts(tester), [DateTime.utc(2026, 1, 15)]);
      expect(find.text('1 ciclo'), findsOneWidget);

      // Closing the panel discards a filter the user can no longer see: the
      // query is dropped with the chrome, never left applied invisibly.
      await _closeFilterPanel(tester);
      expect(find.byType(TextFieldMetra), findsNothing);
      expect(find.byType(ChoiceChipMetra), findsNothing);
      expect(find.text('1 ciclo'), findsNothing);
      expect(_liveRegion(), findsNothing);
      expect(
        _cardStarts(tester),
        [DateTime.utc(2026, 1, 15), DateTime.utc(2026, 2, 12)],
      );

      // Reopening starts from a clean panel: empty field, no clear X, no chip.
      await _openFilterPanel(tester);
      expect(_fieldText(tester), '');
      expect(_semanticsWithLabel('Cancella la ricerca'), findsNothing);
      expect(_selectedChipLabels(tester), isEmpty);
    });
  });

  // TASK-12 (sp-20261109-timeline-filter-symptoms-note-search): the reduced
  // list is derived in the screen's `build()` — never in the views, never in a
  // provider. §10.1 operator decision: the derivation applies to the Timeline
  // view only; Tabella always renders the full list and entering it resets the
  // filters (FR-05/FR-12/FR-13, EC-01).
  group('TimelineScreen — filter derivation', () {
    final jan10 = DateTime.utc(2026, 1, 10);
    final jan15 = DateTime.utc(2026, 1, 15);
    final feb12 = DateTime.utc(2026, 2, 12);
    final mar10 = DateTime.utc(2026, 3, 10);

    final kAndSummaries = [
      _makeSummary(
        start: jan15,
        symptoms: [
          _symptom(PainSymptomType.headache),
          _symptom(PainSymptomType.fatigue),
        ],
      ),
      _makeSummary(
        start: feb12,
        symptoms: [_symptom(PainSymptomType.headache)],
      ),
    ];

    final kFiveSummaries = [
      _makeSummary(
        start: jan10,
        symptoms: [_symptom(PainSymptomType.fatigue)],
      ),
      _makeSummary(
        start: DateTime.utc(2026, 2, 10),
        symptoms: [_symptom(PainSymptomType.headache)],
      ),
      _makeSummary(
        start: mar10,
        symptoms: [
          _symptom(PainSymptomType.fatigue),
          _symptom(PainSymptomType.backPain),
        ],
      ),
      _makeSummary(
        start: DateTime.utc(2026, 4, 10),
        symptoms: [_symptom(PainSymptomType.nausea)],
      ),
      _makeSummary(start: DateTime.utc(2026, 5, 10)),
    ];

    List<Override> overridesFor(List<CycleSummary> summaries) {
      return [
        timelineProvider.overrideWith(() => _DataNotifier(summaries)),
      ];
    }

    testWidgets('requires every selected chip to be present (AND, not OR)',
        (tester) async {
      await tester.pumpWidget(_wrap(overridesFor(kAndSummaries)));
      await tester.pumpAndSettle();
      await _openFilterPanel(tester);

      await tester.tap(_chip('Mal di testa'));
      await tester.pump();
      await tester.tap(_chip('Stanchezza'));
      await tester.pumpAndSettle();

      // Only the cycle carrying BOTH symptoms survives — a cycle with just
      // one of the two selected chips is excluded (FR-05).
      expect(_cardStarts(tester), [jan15]);
    });

    testWidgets('keeps every cycle when no chip is selected', (tester) async {
      await tester.pumpWidget(_wrap(overridesFor(kAndSummaries)));
      await tester.pumpAndSettle();
      await _openFilterPanel(tester);

      expect(_cardStarts(tester), [jan15, feb12]);

      // Toggling the shared symptom on and off round-trips to the identity
      // list (FR-05: no selection = no symptom filter).
      await tester.tap(_chip('Mal di testa'));
      await tester.pumpAndSettle();
      await tester.tap(_chip('Mal di testa'));
      await tester.pumpAndSettle();

      expect(find.byType(TimelineCard), findsNWidgets(2));
    });

    testWidgets(
        'Timeline shows the reduced list while Tabella shows every cycle and '
        'resets the filters', (tester) async {
      await tester.pumpWidget(_wrap(overridesFor(kFiveSummaries)));
      await tester.pumpAndSettle();
      await _openFilterPanel(tester);

      // A chip filter AND a typed query, both visible in Timeline.
      await tester.tap(_chip('Stanchezza'));
      await tester.pumpAndSettle();
      expect(_cardStarts(tester), [jan10, mar10]);
      await tester.enterText(find.byType(TextField), 'gorgo');
      await tester.pump(const Duration(milliseconds: 300));
      expect(_fieldText(tester), 'gorgo');
      // No note carries the token, so the text filter actively empties the
      // list in Timeline — the state the table must never inherit.
      expect(find.text('Nessun ciclo corrisponde ai filtri'), findsOneWidget);

      await tester.tap(find.text('Tabella'));
      await tester.pumpAndSettle();

      // §10.1: the table always renders the FULL list — the filters reset on
      // the way in, so nothing invisible stays applied.
      expect(find.byType(TimelineCard), findsNothing);
      expect(_tableRows(), findsNWidgets(kFiveSummaries.length));
      expect(find.textContaining('Gen'), findsOneWidget);
      expect(find.textContaining('Feb'), findsOneWidget);
      expect(find.textContaining('Mar'), findsOneWidget);
      expect(find.byType(TextFieldMetra), findsNothing);
      expect(_filterToggle(), findsNothing);
      expect(find.text('Rimuovi filtri'), findsNothing);

      await tester.tap(find.text('Timeline'));
      await tester.pumpAndSettle();

      // Back in Timeline: clean slate — the panel is closed again (only the
      // funnel renders), no filter is applied and no count row exists (the
      // first cycles are unfiltered; the list is lazy, so only the built
      // cards are inspected).
      expect(find.byType(TextFieldMetra), findsNothing);
      expect(find.byType(ChoiceChipMetra), findsNothing);
      expect(_filterToggle(), findsOneWidget);
      expect(find.text('Rimuovi filtri'), findsNothing);
      expect(_liveRegion(), findsNothing);
      expect(
        _cardStarts(tester).take(3),
        [jan10, DateTime.utc(2026, 2, 10), mar10],
      );

      // Reopening the panel proves the reset: empty field, no chip selected.
      await _openFilterPanel(tester);
      expect(_fieldText(tester), '');
      expect(_selectedChipLabels(tester), isEmpty);
    });

    testWidgets('keeps filters across a resize and resets them on Tabella',
        (tester) async {
      tester.view.physicalSize = const Size(600, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrap(overridesFor(kFiveSummaries)));
      await tester.pumpAndSettle();
      await _openFilterPanel(tester);

      await tester.tap(_chip('Stanchezza'));
      await tester.pumpAndSettle();

      // Rotation stand-in: screen-local filter state survives the rebuild
      // (FR-12).
      tester.view.physicalSize = const Size(900, 600);
      await tester.pumpAndSettle();
      expect(_cardStarts(tester), [jan10, mar10]);

      // The mode switch is the reset point: the table shows every cycle.
      await tester.tap(find.text('Tabella'));
      await tester.pumpAndSettle();
      expect(_tableRows(), findsNWidgets(kFiveSummaries.length));
    });

    testWidgets('tapping the single filtered card keeps the focus order',
        (tester) async {
      late _SpyCalendarFocusRequest spy;
      await tester.pumpWidget(
        _wrap(
          overridesFor(kAndSummaries),
          routerAwareOverrides: (router) {
            spy = _SpyCalendarFocusRequest(router);
            return [calendarFocusRequestProvider.overrideWith(() => spy)];
          },
        ),
      );
      await tester.pumpAndSettle();
      await _openFilterPanel(tester);

      await tester.tap(_chip('Mal di testa'));
      await tester.pump();
      await tester.tap(_chip('Stanchezza'));
      await tester.pumpAndSettle();
      expect(find.byType(TimelineCard), findsOneWidget);

      await tester.tap(find.byType(TimelineCard));

      // FR-13: filtering does not reorder focus-request vs navigation.
      expect(spy.locationsAtRequestTime, ['/timeline']);
      expect(spy.state, jan15);

      await tester.pumpAndSettle();
      expect(find.text('calendar-stub'), findsOneWidget);
    });

    testWidgets('keeps the truly-empty hint above any filter (EC-01)',
        (tester) async {
      await tester.pumpWidget(
        _wrap(overridesFor(const <CycleSummary>[])),
      );
      await tester.pumpAndSettle();
      await _openFilterPanel(tester);

      // Zero cycles also means no derivable chip, so only text can be typed —
      // the truly-empty branch must still outrank it.
      await tester.enterText(find.byType(TextField), 'perche');
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Registra il tuo primo ciclo'),
        findsOneWidget,
      );
      expect(find.byType(ChoiceChipMetra), findsNothing);
      expect(find.textContaining('Nessun ciclo corrisponde'), findsNothing);
    });

    testWidgets('ignores notes until a text query is committed',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          overridesFor(kAndSummaries),
          notes: {DateTime.utc(2026, 1, 16): 'Perché è stata dura'},
        ),
      );
      await tester.pumpAndSettle();

      // `_committedQuery` stays empty until TASK-13, so the note map cannot
      // reduce the list yet — it is already the derivation's text input.
      expect(find.byType(TimelineCard), findsNWidgets(2));
    });

    testWidgets('keeps loading, error, and truly-empty branches unchanged',
        (tester) async {
      await tester.pumpWidget(
        _wrap([timelineProvider.overrideWith(_LoadingNotifier.new)]),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Dispose the never-settling loading tree between branches.
      await tester.pumpWidget(const SizedBox.shrink());

      await tester.pumpWidget(
        _wrap([timelineProvider.overrideWith(_ErrorNotifier.new)]),
      );
      await tester.pumpAndSettle();
      expect(find.text('Qualcosa è andato storto. Riprova.'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());

      await tester.pumpWidget(
        _wrap([timelineProvider.overrideWith(() => _DataNotifier(const []))]),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Registra il tuo primo ciclo'),
        findsOneWidget,
      );
    });
  });

  // TASK-13 (sp-20261109-timeline-filter-symptoms-note-search): the §5.1.G
  // text-commit lifecycle — a 300 ms restart-per-keystroke commit (FR-08,
  // EC-11), immediate chip/clear interaction (EC-12/EC-13), the timer
  // cancelled on disposal plus the screen-local reset on re-entry
  // (EC-10/FR-12), the note-search behaviour the committed query drives at
  // screen level (FR-06/FR-07, EC-04) and the NFR-02 read budget.
  group('TimelineScreen — debounce lifecycle', () {
    final jan10 = DateTime.utc(2026, 1, 10);
    final feb10 = DateTime.utc(2026, 2, 10);
    final mar10 = DateTime.utc(2026, 3, 10);

    // A carries the only "vert" note; B carries a "v" but no "vert", so a
    // commit that fires too early is visible as a still-unfiltered list.
    final kTwoSummaries = [
      _makeSummary(
        start: jan10,
        end: DateTime.utc(2026, 1, 20),
        symptoms: [_symptom(PainSymptomType.headache)],
      ),
      _makeSummary(
        start: feb10,
        end: DateTime.utc(2026, 2, 20),
        symptoms: [_symptom(PainSymptomType.fatigue)],
      ),
    ];

    final kTwoNotes = {
      DateTime.utc(2026, 1, 15): 'Vertigini forti',
      DateTime.utc(2026, 2, 15): 'Voglia di dormire',
    };

    // Three cycles so the chip condition and the text condition reduce
    // differently (EC-12).
    final kThreeSummaries = [
      _makeSummary(
        start: jan10,
        end: DateTime.utc(2026, 1, 20),
        symptoms: [_symptom(PainSymptomType.headache)],
      ),
      _makeSummary(
        start: feb10,
        end: DateTime.utc(2026, 2, 20),
        symptoms: [_symptom(PainSymptomType.headache)],
      ),
      _makeSummary(
        start: mar10,
        symptoms: [_symptom(PainSymptomType.fatigue)],
      ),
    ];

    final kThreeNotes = {
      DateTime.utc(2026, 1, 15): 'Vertigini forti',
      DateTime.utc(2026, 2, 15): 'Sonno agitato',
      DateTime.utc(2026, 3, 15): 'Voglia di dormire',
    };

    // One note, folding-relevant: 'perche', 'perchè' and 'ché' all hit it.
    final kAccentNotes = {DateTime.utc(2026, 1, 15): 'Perché è stato dura'};

    List<Override> overridesFor(List<CycleSummary> summaries) {
      return [
        timelineProvider.overrideWith(() => _DataNotifier(summaries)),
      ];
    }

    // The repository-backed chain opens on the loading spinner, which never
    // settles: pump a fixed frame budget instead of `pumpAndSettle`.
    Future<void> pumpFrames(WidgetTester tester) async {
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 1));
      }
    }

    testWidgets('commits 300 ms after the last keystroke', (tester) async {
      await tester.pumpWidget(
        _wrap(overridesFor(kTwoSummaries), notes: kTwoNotes),
      );
      await tester.pumpAndSettle();
      expect(_cardStarts(tester), [jan10, feb10]);
      await _openFilterPanel(tester);

      // "vert" character by character, every gap < 300 ms: no commit yet.
      for (final text in ['v', 've', 'ver', 'vert']) {
        await tester.enterText(find.byType(TextField), text);
        await tester.pump(const Duration(milliseconds: 100));
        expect(_cardStarts(tester), [jan10, feb10]);
      }

      // 299 ms of quiet still renders the unfiltered list …
      await tester.pump(const Duration(milliseconds: 199));
      expect(_cardStarts(tester), [jan10, feb10]);

      // … and exactly one commit lands at 300 ms with the final text (EC-11).
      await tester.pump(const Duration(milliseconds: 1));
      expect(_cardStarts(tester), [jan10]);
    });

    testWidgets('a keystroke at 299 ms restarts the window', (tester) async {
      await tester.pumpWidget(
        _wrap(overridesFor(kTwoSummaries), notes: kTwoNotes),
      );
      await tester.pumpAndSettle();
      await _openFilterPanel(tester);

      await tester.enterText(find.byType(TextField), 'v');
      await tester.pump(const Duration(milliseconds: 299));

      await tester.enterText(find.byType(TextField), 'vert');
      // 10 ms later an un-restarted "v" window would already have committed
      // the field's "vert", filtering the list down to A.
      await tester.pump(const Duration(milliseconds: 10));
      expect(_cardStarts(tester), [jan10, feb10]);

      // 299 ms after the LAST keystroke: still nothing committed.
      await tester.pump(const Duration(milliseconds: 289));
      expect(_cardStarts(tester), [jan10, feb10]);

      await tester.pump(const Duration(milliseconds: 1));
      expect(_cardStarts(tester), [jan10]);
    });

    testWidgets('clear cancels the pending commit', (tester) async {
      await tester.pumpWidget(
        _wrap(overridesFor(kTwoSummaries), notes: kTwoNotes),
      );
      await tester.pumpAndSettle();
      await _openFilterPanel(tester);

      await tester.enterText(find.byType(TextField), 'vert');
      await tester.pump(const Duration(milliseconds: 100));
      expect(_cardStarts(tester), [jan10, feb10]);

      await tester.tap(_semanticsWithLabel('Cancella la ricerca'));
      await tester.pump();

      // EC-13: immediate, with no clock advance — and the field is empty.
      expect(_fieldText(tester), '');
      expect(_cardStarts(tester), [jan10, feb10]);
      expect(_semanticsWithLabel('Cancella la ricerca'), findsNothing);

      // The cancelled timer must never commit the discarded text.
      await tester.pump(const Duration(milliseconds: 400));
      expect(_cardStarts(tester), [jan10, feb10]);
    });

    testWidgets('chip applies now, text commits later (EC-12)', (tester) async {
      await tester.pumpWidget(
        _wrap(overridesFor(kThreeSummaries), notes: kThreeNotes),
      );
      await tester.pumpAndSettle();
      expect(_cardStarts(tester), [jan10, feb10, mar10]);
      await _openFilterPanel(tester);

      await tester.enterText(find.byType(TextField), 'vert');
      await tester.pump(const Duration(milliseconds: 100));
      expect(_cardStarts(tester), [jan10, feb10, mar10]);

      // The chip applies immediately, against the last COMMITTED query ('').
      await tester.tap(_chip('Mal di testa'));
      await tester.pump();
      expect(_cardStarts(tester), [jan10, feb10]);

      // The pending timer was NOT cancelled: the newer text still commits and
      // is ANDed with the chip — two applications, no lost update.
      await tester.pump(const Duration(milliseconds: 300));
      expect(_cardStarts(tester), [jan10]);
      expect(
        tester.widget<ChoiceChipMetra>(_chip('Mal di testa')).selected,
        isTrue,
      );
    });

    testWidgets('ANDs the chip with the committed query', (tester) async {
      final bothNotes = {
        DateTime.utc(2026, 1, 15): 'Perché è stato dura',
        DateTime.utc(2026, 2, 15): 'Perché è stato dura',
      };
      await tester.pumpWidget(
        _wrap(overridesFor(kTwoSummaries), notes: bothNotes),
      );
      await tester.pumpAndSettle();
      await _openFilterPanel(tester);

      await tester.enterText(find.byType(TextField), 'perche');
      await tester.pump(const Duration(milliseconds: 300));
      // Both cycles carry a matching note: text alone keeps both (FR-07).
      expect(_cardStarts(tester), [jan10, feb10]);

      await tester.tap(_chip('Mal di testa'));
      await tester.pump();
      // FR-06: only A carries the chip, so the text match is not sufficient.
      expect(_cardStarts(tester), [jan10]);
    });

    testWidgets('folds case and diacritics (FR-07)', (tester) async {
      await tester.pumpWidget(
        _wrap(overridesFor(kTwoSummaries), notes: kAccentNotes),
      );
      await tester.pumpAndSettle();
      await _openFilterPanel(tester);

      for (final query in ['PERCHE', 'perchè', 'ché']) {
        await tester.enterText(find.byType(TextField), query);
        await tester.pump(const Duration(milliseconds: 300));
        expect(_cardStarts(tester), [jan10], reason: query);
      }
    });

    testWidgets('whitespace-only query filters nothing (EC-04)',
        (tester) async {
      await tester.pumpWidget(
        _wrap(overridesFor(kTwoSummaries), notes: kAccentNotes),
      );
      await tester.pumpAndSettle();
      await _openFilterPanel(tester);

      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump(const Duration(milliseconds: 300));

      // No text filter applies, but the raw text keeps the clear X (OQ-08).
      expect(_cardStarts(tester), [jan10, feb10]);
      expect(_semanticsWithLabel('Cancella la ricerca'), findsOneWidget);

      await tester.tap(_semanticsWithLabel('Cancella la ricerca'));
      await tester.pump();
      expect(_fieldText(tester), '');
      expect(_cardStarts(tester), [jan10, feb10]);

      // The padded query is trimmed before matching (FR-07).
      await tester.enterText(find.byType(TextField), '  perche  ');
      await tester.pump(const Duration(milliseconds: 300));
      expect(_cardStarts(tester), [jan10]);
    });

    testWidgets('disposal cancels; re-entry resets (EC-10)', (tester) async {
      await tester.pumpWidget(
        _wrap(overridesFor(kTwoSummaries), notes: kTwoNotes),
      );
      await tester.pumpAndSettle();
      await _openFilterPanel(tester);

      await tester.tap(_chip('Mal di testa'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'vert');
      await tester.pump(const Duration(milliseconds: 100));

      // Unmounted with a pending timer: `dispose` cancels it (EC-10).
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);

      // Re-entering the tab starts from an empty query, no chips and a closed
      // panel (FR-12).
      await tester.pumpWidget(
        _wrap(overridesFor(kTwoSummaries), notes: kTwoNotes),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TextFieldMetra), findsNothing);
      expect(find.byType(ChoiceChipMetra), findsNothing);
      expect(_cardStarts(tester), [jan10, feb10]);

      // The reopened panel proves the screen-local state started over.
      await _openFilterPanel(tester);
      expect(_fieldText(tester), '');
      expect(_selectedChipLabels(tester), isEmpty);
    });

    testWidgets('keystrokes hit no repository (NFR-02)', (tester) async {
      final logRepo = _CountingDailyLogRepository()
        ..savedLogs.add(
          DailyLogEntity(
            date: DateTime.utc(2026, 1, 15),
            notes: 'Vertigini forti',
          ),
        );
      final cycles = StreamController<List<CycleEntryEntity>>.broadcast();
      addTearDown(cycles.close);
      final cycleRepo = _BroadcastCycleRepository(cycles.stream);

      await tester.pumpWidget(
        _wrap(
          [
            dailyLogRepositoryProvider.overrideWith((_) async => logRepo),
            cycleEntryRepositoryProvider.overrideWith((_) async => cycleRepo),
          ],
          overrideNotesProvider: false,
        ),
      );
      await pumpFrames(tester);

      cycles.add([
        _cycleEntry(jan10, end: DateTime.utc(2026, 1, 20)),
        _cycleEntry(feb10),
      ]);
      await pumpFrames(tester);
      expect(_cardStarts(tester), [feb10, jan10]);

      // One emission → the pre-existing summaries read plus exactly one added
      // note-path read, and zero symptom reads from the note path.
      expect(logRepo.getAllOrderedByDateCalls, 2);
      expect(logRepo.getPainSymptomsCalls, 1);

      // Reveal the note-search field; the tap itself reads nothing either.
      await _openFilterPanel(tester, settle: false);
      expect(logRepo.getAllOrderedByDateCalls, 2);
      expect(logRepo.getPainSymptomsCalls, 1);

      for (final text in ['v', 've', 'ver', 'vert']) {
        await tester.enterText(find.byType(TextField), text);
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pump(const Duration(milliseconds: 300));

      // N keystrokes (and the commit they produce) read nothing at all.
      expect(logRepo.getAllOrderedByDateCalls, 2);
      expect(logRepo.getPainSymptomsCalls, 1);
      expect(_cardStarts(tester), [jan10]);

      cycles.add([
        _cycleEntry(jan10, end: DateTime.utc(2026, 1, 20)),
        _cycleEntry(feb10),
        _cycleEntry(mar10),
      ]);
      await pumpFrames(tester);

      // Exactly one added full-log read per cycle-table emission.
      expect(logRepo.getAllOrderedByDateCalls, 4);
    });
  });

  // TASK-14 (sp-20261109-timeline-filter-symptoms-note-search): the screen-level
  // no-match state (§13 empty-state register / FR-10, EC-03), the result-count
  // row with its clear-all action (FR-11) and the polite live region that
  // announces count changes (FR-15). Both states live in the screen, never in
  // the filter-agnostic views.
  group('TimelineScreen — no-match + count row', () {
    final jan10 = DateTime.utc(2026, 1, 10);
    final feb10 = DateTime.utc(2026, 2, 10);

    // Two cycles with disjoint symptoms: selecting both chips can never match
    // (AND semantics), which is the only way a derived chip set can yield zero
    // matches.
    final kSplitSummaries = [
      _makeSummary(
        start: jan10,
        end: DateTime.utc(2026, 1, 14),
        symptoms: [_symptom(PainSymptomType.headache)],
      ),
      _makeSummary(
        start: feb10,
        end: DateTime.utc(2026, 2, 14),
        symptoms: [_symptom(PainSymptomType.fatigue)],
      ),
    ];

    // Seven cycles, three of which carry the headache chip (FR-11 vector).
    final kSevenSummaries = [
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

    // Seven cycles, five fatigued and two of those also headache — the 5 → 2
    // live-region vector (FR-15).
    final kFiveThenTwo = [
      for (var i = 0; i < 7; i++)
        _makeSummary(
          start: DateTime.utc(2026, i + 1, 10),
          end: DateTime.utc(2026, i + 1, 14),
          symptoms: [
            if (i < 5) _symptom(PainSymptomType.fatigue),
            if (i < 2) _symptom(PainSymptomType.headache),
          ],
        ),
    ];

    List<Override> overridesFor(List<CycleSummary> summaries) {
      return [
        timelineProvider.overrideWith(() => _DataNotifier(summaries)),
      ];
    }

    testWidgets(
        'replaces the list with the no-match state in Timeline only, and '
        'Tabella resets it', (tester) async {
      await tester.pumpWidget(_wrap(overridesFor(kSplitSummaries)));
      await tester.pumpAndSettle();
      await _openFilterPanel(tester);

      await tester.tap(_chip('Mal di testa'));
      await tester.pump();
      await tester.tap(_chip('Stanchezza'));
      await tester.pumpAndSettle();

      expect(find.byType(TimelineCard), findsNothing);
      expect(find.byType(TimelineView), findsNothing);
      expect(find.text('Nessun ciclo corrisponde ai filtri'), findsOneWidget);
      // Exactly one clear affordance: the count row is superseded, so no
      // "0 cicli" row stacks on the message (EC-03).
      expect(find.text('Rimuovi filtri'), findsOneWidget);
      expect(find.textContaining('cicli'), findsNothing);
      expect(_liveRegion(), findsNothing);

      await tester.tap(find.text('Tabella'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<SegmentedControlMetra>(find.byType(SegmentedControlMetra))
            .selectedIndex,
        1,
      );
      // §10.1: entering the table drops the filters, so the no-match state
      // cannot survive the switch — every cycle renders, and no filter chrome.
      expect(find.byType(TableView), findsOneWidget);
      expect(_tableRows(), findsNWidgets(2));
      expect(find.text('Mese'), findsOneWidget);
      expect(find.text('Nessun ciclo corrisponde ai filtri'), findsNothing);
      expect(find.text('Rimuovi filtri'), findsNothing);
      expect(find.byType(ChoiceChipMetra), findsNothing);
    });

    testWidgets(
        'clear-filters empties the query, deselects chips and cancels the '
        'pending commit', (tester) async {
      await tester.pumpWidget(_wrap(overridesFor(kSplitSummaries)));
      await tester.pumpAndSettle();
      await _openFilterPanel(tester);

      await tester.tap(_chip('Mal di testa'));
      await tester.pump();
      await tester.tap(_chip('Stanchezza'));
      await tester.pump();

      // The typed text is still inside the 300 ms window, so the no-match state
      // is driven by the chips alone.
      await tester.enterText(find.byType(TextField), 'vert');
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Nessun ciclo corrisponde ai filtri'), findsOneWidget);

      await tester.tap(find.text('Rimuovi filtri'));
      await tester.pump();

      expect(_fieldText(tester), '');
      expect(
        tester.widget<ChoiceChipMetra>(_chip('Mal di testa')).selected,
        isFalse,
      );
      expect(
        tester.widget<ChoiceChipMetra>(_chip('Stanchezza')).selected,
        isFalse,
      );
      expect(_cardStarts(tester), [jan10, feb10]);
      expect(find.text('Nessun ciclo corrisponde ai filtri'), findsNothing);
      expect(find.text('Rimuovi filtri'), findsNothing);

      // The cancelled window must never commit the discarded text (EC-13).
      await tester.pump(const Duration(milliseconds: 400));
      expect(_cardStarts(tester), [jan10, feb10]);
      expect(find.text('Nessun ciclo corrisponde ai filtri'), findsNothing);
    });

    testWidgets('renders the plural count and clear-all in a live region',
        (tester) async {
      await tester.pumpWidget(_wrap(overridesFor(kSevenSummaries)));
      await tester.pumpAndSettle();
      await _openFilterPanel(tester);

      await tester.tap(_chip('Mal di testa'));
      await tester.pumpAndSettle();

      expect(find.text('3 cicli'), findsOneWidget);
      expect(find.text('Rimuovi filtri'), findsOneWidget);
      expect(_liveRegion(), findsOneWidget);
      expect(
        find.descendant(of: _liveRegion(), matching: find.text('3 cicli')),
        findsOneWidget,
      );
      // The count text sits at the §1.2 "Body secondary" row: Inter 13 with
      // the default 400 weight (catalogued, not overridden).
      final count = tester.widget<Text>(find.text('3 cicli'));
      expect(count.style?.fontSize, 13);
      expect(count.style?.fontWeight ?? FontWeight.w400, FontWeight.w400);
      // Clear-all follows the §8.1 "Oggi" text-action pattern.
      final clearAll = tester.widget<Text>(find.text('Rimuovi filtri'));
      expect(clearAll.style?.fontSize, 13);
      expect(clearAll.style?.fontWeight, FontWeight.w500);
    });

    testWidgets('announces a 5 → 2 count change in the polite live region',
        (tester) async {
      await tester.pumpWidget(_wrap(overridesFor(kFiveThenTwo)));
      await tester.pumpAndSettle();
      await _openFilterPanel(tester);

      await tester.tap(_chip('Stanchezza'));
      await tester.pumpAndSettle();
      expect(find.text('5 cicli'), findsOneWidget);
      expect(_liveRegion(), findsOneWidget);
      expect(
        find.descendant(of: _liveRegion(), matching: find.text('5 cicli')),
        findsOneWidget,
      );

      await tester.tap(_chip('Mal di testa'));
      await tester.pumpAndSettle();

      expect(find.text('5 cicli'), findsNothing);
      expect(find.text('2 cicli'), findsOneWidget);
      expect(_liveRegion(), findsOneWidget);
      expect(
        find.descendant(of: _liveRegion(), matching: find.text('2 cicli')),
        findsOneWidget,
      );
    });

    testWidgets('hides the count row with no active filter, clear-all resets',
        (tester) async {
      await tester.pumpWidget(_wrap(overridesFor(kSplitSummaries)));
      await tester.pumpAndSettle();
      await _openFilterPanel(tester);

      // FR-11: no filter active → neither the count nor clear-all renders.
      expect(_liveRegion(), findsNothing);
      expect(find.text('Rimuovi filtri'), findsNothing);

      await tester.tap(_chip('Mal di testa'));
      await tester.pumpAndSettle();
      expect(find.text('1 ciclo'), findsOneWidget);
      expect(find.text('Rimuovi filtri'), findsOneWidget);

      await tester.tap(find.text('Rimuovi filtri'));
      await tester.pumpAndSettle();

      // All filters reset, the full list renders, the row hides.
      expect(_cardStarts(tester), [jan10, feb10]);
      expect(_liveRegion(), findsNothing);
      expect(find.text('Rimuovi filtri'), findsNothing);
      expect(
        tester
            .widgetList<ChoiceChipMetra>(find.byType(ChoiceChipMetra))
            .every((chip) => !chip.selected),
        isTrue,
      );
    });

    testWidgets('keeps the truly-empty hint with a typed query (EC-01)',
        (tester) async {
      await tester.pumpWidget(
        _wrap(overridesFor(const <CycleSummary>[])),
      );
      await tester.pumpAndSettle();
      await _openFilterPanel(tester);

      await tester.enterText(find.byType(TextField), 'perche');
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Registra il tuo primo ciclo'),
        findsOneWidget,
      );
      expect(find.text('Nessun ciclo corrisponde ai filtri'), findsNothing);
      expect(find.text('Rimuovi filtri'), findsNothing);
      expect(_liveRegion(), findsNothing);
    });
  });

  // TASK-15 (sp-20261109-timeline-filter-symptoms-note-search): the §6.1
  // five-state enumeration — loading → error → truly-empty → no-match → data.
  // The loading and error branches can be driven by EITHER provider; the
  // notes half of those conditions is gated on the RAW committed query
  // (`_committedQuery.isNotEmpty`, the OQ-16 operator decision), so a
  // whitespace-only commit still holds/errors on the notes provider even
  // though no text filter can ever apply. Branch visuals are unchanged
  // (FR-13): the same centered spinner + `common_loading` Semantics and the
  // same `common_error_generic` in `textSecondary`.
  group('TimelineScreen — async-state gating', () {
    final jan10 = DateTime.utc(2026, 1, 10);
    final feb10 = DateTime.utc(2026, 2, 10);

    final kTwoSummaries = [
      _makeSummary(
        start: jan10,
        end: DateTime.utc(2026, 1, 20),
        symptoms: [_symptom(PainSymptomType.headache)],
      ),
      _makeSummary(
        start: feb10,
        end: DateTime.utc(2026, 2, 20),
        symptoms: [_symptom(PainSymptomType.fatigue)],
      ),
    ];

    const kErrorText = 'Qualcosa è andato storto. Riprova.';
    const kLoadingLabel = 'Caricamento…';

    // A note path that never emits: `timelineNotesProvider` stays AsyncLoading
    // until the controller is closed (after the tree is unmounted).
    Stream<Map<DateTime, String>> pendingNotes() {
      final controller = StreamController<Map<DateTime, String>>();
      addTearDown(controller.close);
      return controller.stream;
    }

    Stream<Map<DateTime, String>> failingNotes() =>
        Stream<Map<DateTime, String>>.error(Exception('notes read failed'));

    List<Override> overridesFor(
      List<CycleSummary> summaries, {
      required Stream<Map<DateTime, String>> Function() notes,
    }) =>
        [
          timelineProvider.overrideWith(() => _DataNotifier(summaries)),
          timelineNotesProvider.overrideWith((ref) => notes()),
        ];

    // The pending-notes harness never settles through `pumpAndSettle`, so drive
    // a fixed frame budget instead (the spinner animates forever).
    Future<void> pumpFrames(WidgetTester tester) async {
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 1));
      }
    }

    testWidgets('summaries error keeps the generic branch only (EC-05)',
        (tester) async {
      await tester.pumpWidget(
        _wrap([timelineProvider.overrideWith(_ErrorNotifier.new)]),
      );
      await tester.pumpAndSettle();

      // The existing generic treatment: no exception detail on screen.
      expect(find.text(kErrorText), findsOneWidget);
      expect(find.textContaining('test error'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // The funnel is still offered — the filter chrome is Timeline-only, not
      // data-dependent — but the panel stays collapsed until it is tapped.
      expect(_filterToggle(), findsOneWidget);
      expect(find.byType(TextFieldMetra), findsNothing);
      await _openFilterPanel(tester);

      // The search field renders with the panel; no data means no chip row.
      expect(find.byType(TextFieldMetra), findsOneWidget);
      expect(find.byType(ChoiceChipMetra), findsNothing);

      // Typed text persists in screen state, but cannot have any effect.
      await tester.enterText(find.byType(TextField), 'vert');
      await tester.pump(const Duration(milliseconds: 300));
      expect(_fieldText(tester), 'vert');
      expect(find.text(kErrorText), findsOneWidget);
      expect(find.byType(TimelineCard), findsNothing);
    });

    testWidgets('notes error is ignored without a committed query (EC-07)',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          overridesFor(kTwoSummaries, notes: failingNotes),
          overrideNotesProvider: false,
        ),
      );
      await tester.pumpAndSettle();

      // Notes are not needed while no text filter applies.
      expect(_cardStarts(tester), [jan10, feb10]);
      expect(find.text(kErrorText), findsNothing);

      // Committing a query afterwards flips to the EC-06 treatment.
      await _openFilterPanel(tester);
      await tester.enterText(find.byType(TextField), 'vert');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(kErrorText), findsOneWidget);
      expect(find.byType(TimelineCard), findsNothing);
    });

    testWidgets(
        'notes error replaces the list while a query is committed '
        '(EC-06)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          overridesFor(kTwoSummaries, notes: failingNotes),
          overrideNotesProvider: false,
        ),
      );
      await tester.pumpAndSettle();
      await _openFilterPanel(tester);

      await tester.tap(_chip('Mal di testa'));
      await tester.pumpAndSettle();
      expect(_cardStarts(tester), [jan10]);

      await tester.enterText(find.byType(TextField), 'vert');
      await tester.pump(const Duration(milliseconds: 300));

      // The text filter cannot be evaluated → the generic error replaces the
      // list, and the count row (which describes a list that is not on
      // screen) is suppressed with it.
      expect(find.text(kErrorText), findsOneWidget);
      expect(find.byType(TimelineCard), findsNothing);
      expect(_liveRegion(), findsNothing);
      expect(find.text('Rimuovi filtri'), findsNothing);

      // Clearing the text query immediately restores the list, still filtered
      // by the chip alone.
      await tester.tap(_semanticsWithLabel('Cancella la ricerca'));
      await tester.pump();

      expect(_fieldText(tester), '');
      expect(find.text(kErrorText), findsNothing);
      expect(_cardStarts(tester), [jan10]);
      expect(find.text('1 ciclo'), findsOneWidget);
    });

    testWidgets(
        'a whitespace-only commit also lands in the notes-error '
        'branch (OQ-16)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          overridesFor(kTwoSummaries, notes: failingNotes),
          overrideNotesProvider: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(_cardStarts(tester), [jan10, feb10]);
      await _openFilterPanel(tester);

      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump(const Duration(milliseconds: 300));

      // The raw query is non-empty, so it counts as text the user entered —
      // even though no text filter would apply once the notes land (EC-04).
      expect(find.text(kErrorText), findsOneWidget);
      expect(find.byType(TimelineCard), findsNothing);

      // Emptying the field drops the gate, and no text filter applies.
      await tester.tap(_semanticsWithLabel('Cancella la ricerca'));
      await tester.pump();
      expect(_cardStarts(tester), [jan10, feb10]);
      expect(find.text(kErrorText), findsNothing);
    });

    testWidgets('summaries loading keeps the spinner and search field (EC-08)',
        (tester) async {
      await tester.pumpWidget(
        _wrap([timelineProvider.overrideWith(_LoadingNotifier.new)]),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(_semanticsWithLabel(kLoadingLabel), findsOneWidget);

      // The spinner never settles, so reveal the panel without settling.
      await _openFilterPanel(tester, settle: false);
      expect(find.byType(TextFieldMetra), findsOneWidget);
      expect(find.byType(ChoiceChipMetra), findsNothing);
    });

    testWidgets(
        'notes loading holds the spinner while a query is committed '
        '(EC-09)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          overridesFor(kTwoSummaries, notes: pendingNotes),
          overrideNotesProvider: false,
        ),
      );
      await pumpFrames(tester);

      // No committed query → the notes path is ignored, the list renders.
      expect(_cardStarts(tester), [jan10, feb10]);
      await _openFilterPanel(tester, settle: false);

      await tester.enterText(find.byType(TextField), 'vert');
      await tester.pump(const Duration(milliseconds: 300));

      // The pending text filter cannot be evaluated yet: the loading branch
      // holds instead of flashing cycles the filter would remove.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(_semanticsWithLabel(kLoadingLabel), findsOneWidget);
      expect(find.byType(TimelineCard), findsNothing);

      // A whitespace-only commit holds it too (OQ-16) …
      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(TimelineCard), findsNothing);

      // … while an empty raw query releases it immediately.
      await tester.enterText(find.byType(TextField), '');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(_cardStarts(tester), [jan10, feb10]);

      // Unmount before the pending controller closes (no listener left).
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  // TASK-16 (sp-20261109-timeline-filter-symptoms-note-search): a table-trigger
  // re-emission must leave the filter chrome self-consistent. The chip set
  // re-derives from the NEW full list, the selection is intersected with it (a
  // symptom that vanished is silently dropped — keeping it would pin the list
  // in "no match" forever), and the filtered list, count and no-match state
  // re-derive (EC-14). Custom labels join in their alphabetical position and
  // disappear with the data (EC-15). A note-only edit re-emits BOTH providers
  // while every CycleSummary stays deep-equal — the stats input is untouched
  // (FR-14).
  group('TimelineScreen — re-emission robustness', () {
    final jan10 = DateTime.utc(2026, 1, 10);
    final feb10 = DateTime.utc(2026, 2, 10);
    final jan16 = DateTime.utc(2026, 1, 16);
    final feb16 = DateTime.utc(2026, 2, 16);

    // Test-owned table-trigger emissions (EC-14): non-broadcast controllers
    // buffer, so events pushed before `pumpWidget` are delivered on listen.
    StreamController<List<CycleSummary>> summariesStream() {
      final controller = StreamController<List<CycleSummary>>();
      addTearDown(controller.close);
      return controller;
    }

    StreamController<Map<DateTime, String>> notesStream() {
      final controller = StreamController<Map<DateTime, String>>();
      addTearDown(controller.close);
      return controller;
    }

    List<Override> streamOverrides(
      StreamController<List<CycleSummary>> summaries,
    ) =>
        [
          timelineProvider.overrideWith(
            () => _ReemittingNotifier(summaries.stream),
          ),
        ];

    testWidgets(
        're-emission re-derives chips and drops a vanished selection (EC-14)',
        (tester) async {
      final summaries = summariesStream();
      summaries.add([
        _makeSummary(
          start: jan10,
          symptoms: [
            _symptom(PainSymptomType.headache),
            _symptom(PainSymptomType.custom, 'Vertigini'),
          ],
        ),
        _makeSummary(
          start: feb10,
          symptoms: [_symptom(PainSymptomType.fatigue)],
        ),
      ]);

      await tester.pumpWidget(_wrap(streamOverrides(summaries)));
      await tester.pumpAndSettle();
      await _openFilterPanel(tester);
      expect(_chipLabels(tester), ['Mal di testa', 'Stanchezza', 'Vertigini']);

      await tester.tap(_chip('Stanchezza'));
      await tester.pumpAndSettle();
      expect(_cardStarts(tester), [feb10]);
      expect(find.text('1 ciclo'), findsOneWidget);

      // The next table trigger no longer carries 'Stanchezza' anywhere — the
      // entry that recorded it was edited away.
      summaries.add([
        _makeSummary(
          start: jan10,
          symptoms: [
            _symptom(PainSymptomType.headache),
            _symptom(PainSymptomType.custom, 'Vertigini'),
          ],
        ),
        _makeSummary(
          start: feb10,
          symptoms: [_symptom(PainSymptomType.headache)],
        ),
      ]);
      await tester.pump();
      await tester.pumpAndSettle();

      // The chip set re-derives from the NEW full list …
      expect(_chipLabels(tester), ['Mal di testa', 'Vertigini']);
      // … and the vanished symptom is silently dropped from the selection.
      expect(_selectedChipLabels(tester), isEmpty);
      // The list re-expands instead of staying pinned in the no-match state.
      expect(_cardStarts(tester), [jan10, feb10]);
      expect(find.textContaining('Nessun ciclo corrisponde'), findsNothing);
      // The count row re-derives too: no filter is active any more (FR-11).
      expect(_liveRegion(), findsNothing);
      expect(find.text('Rimuovi filtri'), findsNothing);

      // Unmount before the controllers close (no listener left).
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('re-emission re-derives the count and the no-match state',
        (tester) async {
      final summaries = summariesStream();
      summaries.add([
        _makeSummary(
          start: jan10,
          symptoms: [
            _symptom(PainSymptomType.headache),
            _symptom(PainSymptomType.fatigue),
          ],
        ),
        _makeSummary(
          start: feb10,
          symptoms: [_symptom(PainSymptomType.headache)],
        ),
      ]);

      await tester.pumpWidget(_wrap(streamOverrides(summaries)));
      await tester.pumpAndSettle();
      await _openFilterPanel(tester);

      await tester.tap(_chip('Mal di testa'));
      await tester.pump();
      await tester.tap(_chip('Stanchezza'));
      await tester.pumpAndSettle();
      expect(_cardStarts(tester), [jan10]);
      expect(find.text('1 ciclo'), findsOneWidget);

      // Both symptoms still exist, but no single cycle carries both any more
      // (the fatigue entry moved to the other cycle).
      summaries.add([
        _makeSummary(
          start: jan10,
          symptoms: [_symptom(PainSymptomType.headache)],
        ),
        _makeSummary(
          start: feb10,
          symptoms: [_symptom(PainSymptomType.fatigue)],
        ),
      ]);
      await tester.pump();
      await tester.pumpAndSettle();

      // Both selections survive the intersection — their chips still exist …
      expect(_selectedChipLabels(tester), ['Mal di testa', 'Stanchezza']);
      // … and the no-match state takes over from the count row (EC-03/EC-14).
      expect(find.text('Nessun ciclo corrisponde ai filtri'), findsOneWidget);
      expect(find.byType(TimelineCard), findsNothing);
      expect(_liveRegion(), findsNothing);
      expect(find.text('Rimuovi filtri'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('custom chips follow the data mid-visit (EC-15)',
        (tester) async {
      final summaries = summariesStream();
      summaries.add([
        _makeSummary(
          start: jan10,
          symptoms: [
            _symptom(PainSymptomType.headache),
            _symptom(PainSymptomType.custom, 'Acne'),
          ],
        ),
        _makeSummary(
          start: feb10,
          symptoms: [_symptom(PainSymptomType.custom, 'Vertigini')],
        ),
      ]);

      await tester.pumpWidget(_wrap(streamOverrides(summaries)));
      await tester.pumpAndSettle();
      await _openFilterPanel(tester);
      expect(_chipLabels(tester), ['Mal di testa', 'Acne', 'Vertigini']);

      await tester.tap(_chip('Acne'));
      await tester.pumpAndSettle();
      expect(_cardStarts(tester), [jan10]);

      // Mid-visit daily entry on another tab: 'Bruciore' recorded, the
      // 'Vertigini' label removed from the data.
      summaries.add([
        _makeSummary(
          start: jan10,
          symptoms: [
            _symptom(PainSymptomType.headache),
            _symptom(PainSymptomType.custom, 'Acne'),
            _symptom(PainSymptomType.custom, 'Bruciore'),
          ],
        ),
        _makeSummary(
          start: feb10,
          symptoms: [_symptom(PainSymptomType.headache)],
        ),
      ]);
      await tester.pump();
      await tester.pumpAndSettle();

      // 'Bruciore' slots in after 'Acne', where 'Vertigini' used to be …
      expect(_chipLabels(tester), ['Mal di testa', 'Acne', 'Bruciore']);
      // … and the vanished label's chip is gone (EC-15).
      expect(_chipText('Vertigini'), findsNothing);
      // The surviving custom selection still narrows the same cycle.
      expect(_selectedChipLabels(tester), ['Acne']);
      expect(_cardStarts(tester), [jan10]);
      expect(find.text('1 ciclo'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('note-only edit re-emits both providers, stats stay stable',
        (tester) async {
      final summaries = summariesStream();
      final notes = notesStream();

      // Note-only edit: the daily-log save recomputes the cycle rows, so BOTH
      // read paths re-emit while every summary field stays identical (FR-14).
      List<CycleSummary> summariesV1() => [
            _makeSummary(
              start: jan10,
              end: DateTime.utc(2026, 1, 20),
              symptoms: [_symptom(PainSymptomType.headache)],
            ),
            _makeSummary(
              start: feb10,
              end: DateTime.utc(2026, 2, 20),
              symptoms: [_symptom(PainSymptomType.fatigue)],
            ),
          ];
      List<CycleSummary> summariesV2() => [
            _makeSummary(
              start: jan10,
              end: DateTime.utc(2026, 1, 20),
              symptoms: [_symptom(PainSymptomType.headache)],
            ),
            _makeSummary(
              start: feb10,
              end: DateTime.utc(2026, 2, 20),
              symptoms: [_symptom(PainSymptomType.fatigue)],
            ),
          ];

      summaries.add(summariesV1());
      notes.add({jan16: 'Perché è stata dura', feb16: 'Giornata dura'});

      await tester.pumpWidget(
        _wrap(
          [
            ...streamOverrides(summaries),
            timelineNotesProvider.overrideWith((ref) => notes.stream),
          ],
          overrideNotesProvider: false,
        ),
      );
      await tester.pumpAndSettle();
      await _openFilterPanel(tester);

      await tester.enterText(find.byType(TextField), 'dura');
      await tester.pump(const Duration(milliseconds: 300));
      expect(_cardStarts(tester), [jan10, feb10]);
      expect(find.text('2 cicli'), findsOneWidget);

      final before = tester
          .widgetList<TimelineCard>(find.byType(TimelineCard))
          .map((card) => card.summary)
          .toList();

      // Summaries re-emission alone: fresh instances, identical values.
      summaries.add(summariesV2());
      await tester.pump();
      await tester.pumpAndSettle();

      // Summaries-new / notes-old window: the list keeps rendering off the
      // latest AsyncData of each provider, unchanged (EC-14).
      expect(_cardStarts(tester), [jan10, feb10]);
      expect(find.text('2 cicli'), findsOneWidget);

      final after = tester
          .widgetList<TimelineCard>(find.byType(TimelineCard))
          .map((card) => card.summary)
          .toList();

      // FR-14: every CycleSummary is deep-equal across the note-only edit, so
      // the computeCycleStats input contract is untouched.
      expect(after.length, before.length);
      for (var i = 0; i < before.length; i++) {
        expect(identical(after[i], before[i]), isFalse);
        expect(after[i], equals(before[i]));
      }

      // The notes emission resolves the window: the NEW note map is what the
      // text filter now sees, so 'dura' no longer matches (EC-14).
      notes.add({jan16: 'nulla da segnalare', feb16: 'tutto tranquillo'});
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Nessun ciclo corrisponde ai filtri'), findsOneWidget);
      expect(find.byType(TimelineCard), findsNothing);

      // Unmount before closing the test-owned streams. The close futures are
      // not awaited: a controller whose subscription was cancelled on unmount
      // delivers no further `done` event to await here.
      await tester.pumpWidget(const SizedBox.shrink());
      unawaited(summaries.close());
      unawaited(notes.close());
    });
  });
}
