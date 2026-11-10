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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:metra/core/theme/metra_theme.dart';
import 'package:metra/core/widgets/choice_chip_metra.dart';
import 'package:metra/core/widgets/metra_icon.dart';
import 'package:metra/domain/entities/cycle_summary.dart';
import 'package:metra/domain/entities/pain_symptom_data.dart';
import 'package:metra/domain/entities/pain_symptom_type.dart';
import 'package:metra/domain/services/cycle_filter_matcher.dart';
import 'package:metra/features/timeline/state/timeline_controller.dart';
import 'package:metra/features/timeline/timeline_screen.dart';
import 'package:metra/l10n/app_localizations.dart';

import '../../helpers/timeline_perf_fixture.dart';

// TASK-18 (sp-20261109-timeline-filter-symptoms-note-search, NFR-01):
// filter application must stay interactive — from the debounce commit (or the
// immediate chip/clear commit) to the rendered list update, p95 ≤ 100 ms on a
// ten-year history (≈130 cycles, ≈3,650 daily logs).
//
// The fixture is generated from a seeded `Random` (test/helpers/
// timeline_perf_fixture.dart) — nothing is checked in, so CI's diff gates stay
// clean and the dataset is identical on every machine and every run.
//
// Per OQ-15 the check runs UNTAGGED in the default suite: no Makefile/CI
// wiring changes. The measured window is the commit → first rendered frame;
// the 300 ms quiet gap before a text commit is fake-time advance under
// `flutter_test` and costs no real time, so it does not inflate the samples.

/// Commits profiled per run (mixed chip toggles, text commits and clears).
const int _kCommitTarget = 100;

/// NFR-01 budget, in milliseconds.
const double _kP95BudgetMillis = 100;

/// The screen's `_kQueryCommitDebounce` (private): the quiet gap that commits
/// a typed query.
const Duration _kDebounce = Duration(milliseconds: 300);

/// Post-sample settle pump — deliberately OUTSIDE the measured window, so chip
/// colour/opacity animations never bleed into the next sample.
const Duration _kSettle = Duration(milliseconds: 350);

const PainSymptomData _kHeadache = PainSymptomData(
  symptomType: PainSymptomType.headache,
);

/// Stub notifier: serves the fixture's summaries without touching Drift.
class _DataNotifier extends TimelineNotifier {
  _DataNotifier(this._data);

  final List<CycleSummary> _data;

  @override
  Future<List<CycleSummary>> build() async => _data;
}

/// The minimal slice of the screen harness this file needs (router + theme +
/// locale + the two data-path overrides), mirroring `timeline_screen_test.dart`
/// without touching it.
Widget _wrap({
  required List<CycleSummary> summaries,
  required Map<DateTime, String> notes,
}) {
  final router = GoRouter(
    initialLocation: '/timeline',
    routes: [
      GoRoute(path: '/timeline', builder: (_, __) => const TimelineScreen()),
    ],
  );
  return ProviderScope(
    overrides: [
      timelineNotesProvider.overrideWith((ref) => Stream.value(notes)),
      timelineProvider.overrideWith(() => _DataNotifier(summaries)),
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

/// Reveals the symptom chip row: the panel is collapsed by default (§10.1), so
/// every chip-facing vector taps the funnel next to the search field first.
/// The tap stays outside any measured window.
Future<void> _openFilterPanel(WidgetTester tester) async {
  await tester.tap(
    find.ancestor(
      of: find.byWidgetPredicate(
        (widget) =>
            widget is MetraIcon && widget.svgBody == MetraIcons.filterRefined,
      ),
      matching: find.byType(GestureDetector),
    ),
  );
  await tester.pumpAndSettle();
}

/// Nearest-rank p95 over an ascending list of microsecond samples.
int _percentile95(List<int> sortedMicros) =>
    sortedMicros[((sortedMicros.length - 1) * 0.95).round()];

double _toMillis(int microseconds) =>
    microseconds / Duration.microsecondsPerMillisecond;

/// The slowest few samples, labelled — failure diagnostics only.
String _slowestSamples(List<int> samplesMicros, List<String> labels) {
  final order = List<int>.generate(samplesMicros.length, (i) => i)
    ..sort((a, b) => samplesMicros[b].compareTo(samplesMicros[a]));
  return order
      .take(3)
      .map(
        (i) =>
            '${labels[i]} ${_toMillis(samplesMicros[i]).toStringAsFixed(1)} ms',
      )
      .join(', ');
}

void main() {
  group('TimelinePerfFixture', () {
    test(
      'should_generate_identical_cycles_logs_and_notes_when_the_same_seed_runs_twice',
      () {
        final first = TimelinePerfFixture.generate();
        final second = TimelinePerfFixture.generate();

        // Deep equality: CycleSummary/DailyLogEntity implement `==`, so a
        // single seeded run is reproducible byte-for-byte (no checked-in data).
        expect(second.cycles, equals(first.cycles));
        expect(second.dailyLogs, equals(first.dailyLogs));
        expect(second.notesByDate, equals(first.notesByDate));

        // A different seed must actually change the dataset — otherwise the
        // seed would be decorative and the reproducibility claim vacuous.
        final other = TimelinePerfFixture.generate(seed: 7);
        expect(
          other.cycles.map((s) => s.cycle.startDate).toList(),
          isNot(equals(first.cycles.map((s) => s.cycle.startDate).toList())),
        );
      },
    );

    test('should_cover_a_ten_year_history_when_generated', () {
      final fixture = TimelinePerfFixture.generate();

      expect(fixture.dailyLogs, hasLength(TimelinePerfFixture.historyDays));
      expect(
        fixture.cycles,
        hasLength(TimelinePerfFixture.expectedCycleCount),
      );
      expect(
        fixture.cycles.fold<int>(
          0,
          (sum, summary) => sum + (summary.cycle.cycleLength ?? 0),
        ),
        TimelinePerfFixture.historyDays,
      );

      expect(fixture.dailyLogs.first.date, TimelinePerfFixture.firstDay);
      for (var i = 1; i < fixture.dailyLogs.length; i++) {
        expect(
          fixture.dailyLogs[i].date.difference(fixture.dailyLogs[i - 1].date),
          const Duration(days: 1),
          reason: 'log $i must be the day after log ${i - 1}',
        );
      }

      // Note-bearing subset present, but nowhere near exhaustive: the text
      // path pays `foldForSearch` per note, not per day.
      expect(
        fixture.noteBearingLogCount,
        greaterThan(fixture.dailyLogs.length ~/ 4),
      );
      expect(fixture.noteBearingLogCount, lessThan(fixture.dailyLogs.length));

      // Every note belongs to a log of the same date, and every cycle whose
      // range holds a note advertises `hasNote` (the `_enrich` contract).
      for (final entry in fixture.notesByDate.entries) {
        final log = fixture.dailyLogs.firstWhere(
          (log) => log.date == entry.key,
        );
        expect(log.notes, entry.value);
        expect(entry.value, isNotEmpty);
      }
      final cyclesWithNote = fixture.cycles.where((s) => s.hasNote);
      expect(cyclesWithNote, isNotEmpty);
      for (final summary in cyclesWithNote) {
        final rangeStart = summary.cycle.startDate;
        final rangeEnd = summary.cycle.endDate!;
        expect(
          fixture.notesByDate.keys.where(
            (date) => !date.isBefore(rangeStart) && !date.isAfter(rangeEnd),
          ),
          isNotEmpty,
          reason: 'hasNote without a note in range at $rangeStart',
        );
      }
    });
  });

  group('TimelineScreen — NFR-01 filter performance', () {
    testWidgets(
      'should_show_the_matcher_expected_match_count_when_a_fixture_chip_is_toggled',
      (tester) async {
        final fixture = TimelinePerfFixture.generate();
        final expected = const CycleFilterMatcher()
            .apply(
              summaries: fixture.cycles,
              notesByDate: fixture.notesByDate,
              query: CycleFilterQuery(symptoms: {_kHeadache}),
            )
            .length;
        expect(expected, greaterThan(0));

        await tester.pumpWidget(
          _wrap(summaries: fixture.cycles, notes: fixture.notesByDate),
        );
        await tester.pumpAndSettle();
        await _openFilterPanel(tester);

        final l10n = AppLocalizations.of(
          tester.element(find.byType(TimelineScreen)),
        )!;
        final chip = find.byWidgetPredicate(
          (widget) =>
              widget is ChoiceChipMetra &&
              widget.label == l10n.daily_entry_symptom_headache,
        );
        expect(chip, findsOneWidget);

        await tester.tap(chip);
        await tester.pump();

        expect(
          find.text(l10n.timeline_filter_results_count(expected)),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'should_keep_commit_to_render_p95_within_budget_when_100_filters_commit_on_the_ten_year_fixture',
      (tester) async {
        final fixture = TimelinePerfFixture.generate();

        await tester.pumpWidget(
          _wrap(summaries: fixture.cycles, notes: fixture.notesByDate),
        );
        await tester.pumpAndSettle();
        await _openFilterPanel(tester);

        final l10n = AppLocalizations.of(
          tester.element(find.byType(TimelineScreen)),
        )!;

        // The first three derived chips are the predefined, highest-frequency
        // symptoms of the fixture — always present, always tappable.
        final chipTargets = tester
            .widgetList<ChoiceChipMetra>(find.byType(ChoiceChipMetra))
            .take(3)
            .toList();
        expect(chipTargets, hasLength(3));

        final field = tester.widget<TextField>(find.byType(TextField));
        final controller = field.controller!;
        final onQueryChanged = field.onChanged!;

        final samplesMicros = <int>[];
        final sampleLabels = <String>[];

        void record(String label, Stopwatch watch) {
          watch.stop();
          samplesMicros.add(watch.elapsedMicroseconds);
          sampleLabels.add(label);
        }

        /// Measures one immediate commit (chip toggle / clear): from the
        /// handler invocation to the first rendered frame.
        Future<void> measureFrame(
          String label,
          Future<void> Function() commit,
        ) async {
          final watch = Stopwatch()..start();
          await commit();
          await tester.pump();
          record(label, watch);
          await tester.pump(_kSettle);
        }

        /// Measures one text commit: the keystroke frame (suffix rebuild) is
        /// pumped first and stays outside the window, then the debounce fire
        /// and the resulting frame are timed. Advancing fake time by 300 ms
        /// costs no real time under `flutter_test`.
        var textIndex = 0;
        Future<void> measureTextCommit() async {
          final query = TimelinePerfFixture
              .textQueries[textIndex % TimelinePerfFixture.textQueries.length];
          textIndex++;
          controller.text = query;
          onQueryChanged(query);
          await tester.pump();
          final watch = Stopwatch()..start();
          await tester.pump(_kDebounce);
          record('text:$query', watch);
          await tester.pump(_kSettle);
          // Outside the window: a committed query is a *visible* filter, so
          // the count row (≥ 1 match) or the no-match state must have rendered
          // — proves the sample timed a real list update, not a no-op commit.
          expect(
            find.text(l10n.timeline_filter_clear_all).evaluate().isNotEmpty ||
                find
                    .text(l10n.timeline_filter_no_match_action)
                    .evaluate()
                    .isNotEmpty,
            isTrue,
            reason: 'text commit "$query" did not apply a visible filter',
          );
        }

        Future<void> measureChipToggle(ChoiceChipMetra chip) async {
          final label = chip.label;
          final finder = find.byWidgetPredicate(
            (widget) => widget is ChoiceChipMetra && widget.label == label,
          );
          final next = !tester.widget<ChoiceChipMetra>(finder).selected;
          final captured = tester.widget<ChoiceChipMetra>(finder);
          await measureFrame('chip:$label', () async {
            captured.onSelected(next);
          });
          expect(
            tester.widget<ChoiceChipMetra>(finder).selected,
            next,
            reason: 'chip "$label" did not apply the toggled state',
          );
        }

        Future<void> measureClearQuery() async {
          final clearField = find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label == l10n.timeline_search_clear_a11y,
          );
          expect(clearField, findsOneWidget);
          await measureFrame('clear-query', () => tester.tap(clearField));
          expect(controller.text, isEmpty);
        }

        Future<void> measureClearAll() async {
          final countAction = find.text(l10n.timeline_filter_clear_all);
          final target = countAction.evaluate().isNotEmpty
              ? countAction
              : find.text(l10n.timeline_filter_no_match_action);
          expect(target, findsOneWidget);
          await measureFrame('clear-all', () => tester.tap(target));
          expect(controller.text, isEmpty);
          expect(
            tester
                .widgetList<ChoiceChipMetra>(find.byType(ChoiceChipMetra))
                .where((chip) => chip.selected),
            isEmpty,
          );
        }

        // Ten rounds of ten commits: text commit → chip toggle → text commit
        // → chip toggle → clear-query → text commit → clear-all → chip toggle
        // → text commit → clear-all. Every round therefore exercises the
        // debounced commit, both immediate commit kinds and the no-match path
        // (the last text token matches nothing).
        for (var round = 0; round < _kCommitTarget ~/ 10; round++) {
          await measureTextCommit();
          await measureChipToggle(chipTargets[round % chipTargets.length]);
          await measureTextCommit();
          await measureChipToggle(
            chipTargets[(round + 1) % chipTargets.length],
          );
          await measureClearQuery();
          await measureTextCommit();
          await measureClearAll();
          await measureChipToggle(
            chipTargets[(round + 2) % chipTargets.length],
          );
          await measureTextCommit();
          await measureClearAll();
        }

        expect(samplesMicros, hasLength(_kCommitTarget));
        expect(
          sampleLabels.where((label) => label.startsWith('text:')).length,
          40,
        );
        expect(
          sampleLabels.where((label) => label.startsWith('chip:')).length,
          30,
        );
        expect(
          sampleLabels.where((label) => label.startsWith('clear-')).length,
          30,
        );

        final sorted = <int>[...samplesMicros]..sort();
        final p50Millis = _toMillis(sorted[sorted.length ~/ 2]);
        final p95Millis = _toMillis(_percentile95(sorted));
        final maxMillis = _toMillis(sorted.last);

        // One line per run, so the NFR-01 trend is visible in CI logs even on
        // green runs (debugPrint, not print: `avoid_print`).
        debugPrint(
          'NFR-01 timeline filter: n=$_kCommitTarget '
          'p50=${p50Millis.toStringAsFixed(1)}ms '
          'p95=${p95Millis.toStringAsFixed(1)}ms '
          'max=${maxMillis.toStringAsFixed(1)}ms',
        );

        expect(
          p95Millis,
          lessThanOrEqualTo(_kP95BudgetMillis),
          reason: 'NFR-01: commit→render p95 must stay ≤ $_kP95BudgetMillis ms '
              'on the ten-year fixture (p50 ${p50Millis.toStringAsFixed(1)} ms, '
              'max ${maxMillis.toStringAsFixed(1)} ms; slowest: '
              '${_slowestSamples(samplesMicros, sampleLabels)}). '
              'A regression here is a plan change (memoization follow-up), not '
              'a reason to loosen the budget.',
        );
      },
    );
  });
}
