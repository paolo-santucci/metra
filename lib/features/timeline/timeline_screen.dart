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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/metra_colors.dart';
import '../../core/theme/metra_spacing.dart';
import '../../core/theme/metra_typography.dart';
import '../../core/widgets/choice_chip_metra.dart';
import '../../core/widgets/metra_icon.dart';
import '../../core/widgets/segmented_control_metra.dart';
import '../../core/widgets/text_field_metra.dart';
import '../../domain/entities/cycle_summary.dart';
import '../../domain/entities/pain_symptom_data.dart';
import '../../domain/entities/pain_symptom_type.dart';
import '../../domain/services/cycle_filter_matcher.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/calendar_focus_provider.dart';
import 'state/timeline_controller.dart';
import 'widgets/table_view.dart';
import 'widgets/timeline_view.dart';

enum _ViewMode { timeline, table }

/// §5.1.G / OQ-07 — the quiet gap that commits the typed query: exactly 300 ms,
/// restarting on every keystroke (EC-11). Chips and the clear affordance
/// deliberately bypass it (EC-12/EC-13).
const Duration _kQueryCommitDebounce = Duration(milliseconds: 300);

class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  _ViewMode _mode = _ViewMode.timeline;

  /// §5.1.G — raw field text. The clear affordance keys off this value, so a
  /// whitespace-only query keeps it visible (EC-04/OQ-16).
  final TextEditingController _queryController = TextEditingController();

  /// §5.1.G — post-debounce query: the text the reduced list is currently
  /// derived from. Only [_commitQuery] writes it.
  String _committedQuery = '';

  /// §5.1.G — chip selection. Screen-local by design: no provider holds filter
  /// state, so leaving the tab resets it (FR-12).
  Set<PainSymptomData> _selectedSymptoms = <PainSymptomData>{};

  /// §5.1.G — symptom chip panel visibility (operator decision, §10.1). The
  /// row is collapsed by default and only ever built while open; closing the
  /// panel drops the chip selection, so a hidden filter can never stay applied.
  bool _filtersPanelOpen = false;

  /// §5.1.G — restart-per-keystroke commit timer (EC-11). Cancelled by the
  /// clear affordance (EC-13) and on disposal (EC-10); chip toggles leave it
  /// untouched so the pending text still commits (EC-12).
  Timer? _debounce;

  @override
  void dispose() {
    _cancelPendingCommit();
    _queryController.dispose();
    super.dispose();
  }

  /// Restarts the 300 ms quiet-gap window on every keystroke (FR-08/EC-11).
  ///
  /// Typing back to the query already on screen needs no commit, so no timer is
  /// armed then. The timer never captures [value]: [_commitQuery] re-reads the
  /// controller, so a commit can only ever apply what the field holds.
  void _handleQueryChanged(String value) {
    _cancelPendingCommit();
    if (value == _committedQuery) return;
    _debounce = Timer(_kQueryCommitDebounce, _commitQuery);
  }

  /// Commits the field text once the quiet gap elapsed (FR-08).
  void _commitQuery() {
    _debounce = null;
    final query = _queryController.text;
    if (query == _committedQuery) return;
    setState(() => _committedQuery = query);
  }

  /// Drops the pending commit, so the discarded text never reaches the list
  /// (EC-13; also the `dispose` path — EC-10).
  void _cancelPendingCommit() {
    _debounce?.cancel();
    _debounce = null;
  }

  /// Switches view mode (§10.1).
  ///
  /// The filter chrome is Timeline-only: Tabella renders the full list, so
  /// entering it drops every filter — pending commit, raw field text, committed
  /// query, chip selection and the chip panel — and nothing invisible can stay
  /// applied when the user returns to Timeline.
  void _handleModeChanged(int index) {
    final next = _ViewMode.values[index];
    if (next == _mode) return;
    if (next == _ViewMode.table) {
      _cancelPendingCommit();
      _queryController.clear();
    }
    setState(() {
      _mode = next;
      if (next == _ViewMode.table) {
        _committedQuery = '';
        _selectedSymptoms = <PainSymptomData>{};
        _filtersPanelOpen = false;
      }
    });
  }

  /// Reveals/hides the whole filter panel (search field, chip row, count row)
  /// from the funnel on the view-toggle line. Hiding clears every filter — the
  /// pending commit, the raw field text, the committed query and the chip
  /// selection — because a filter the user cannot see must never keep narrowing
  /// the list.
  void _handleFilterPanelToggled() {
    if (_filtersPanelOpen) {
      _cancelPendingCommit();
      _queryController.clear();
    }
    setState(() {
      _filtersPanelOpen = !_filtersPanelOpen;
      if (!_filtersPanelOpen) {
        _committedQuery = '';
        _selectedSymptoms = <PainSymptomData>{};
      }
    });
  }

  /// Toggles one chip in the selection. Chips apply immediately and never touch
  /// the debounce timer (EC-12).
  void _handleChipToggled(PainSymptomData symptom, bool selected) {
    setState(() {
      if (selected) {
        _selectedSymptoms.add(symptom);
      } else {
        _selectedSymptoms.remove(symptom);
      }
    });
  }

  /// Empties the field. EC-13: the pending commit is cancelled and the committed
  /// query dropped immediately, so the list can never stay filtered by text the
  /// user just cleared.
  void _handleClearQuery() {
    _cancelPendingCommit();
    final hadCommittedQuery = _committedQuery.isNotEmpty;
    _committedQuery = '';
    _queryController.clear();
    if (hadCommittedQuery) {
      setState(() {});
    }
  }

  /// Clears every filter — shared by the no-match clear-filters action (FR-10)
  /// and the count row's clear-all (FR-11). EC-13: the pending commit is
  /// cancelled so discarded text never reaches the list, the raw field is
  /// emptied (its clear affordance is keyed off it), the committed query is
  /// dropped and every chip is deselected in one rebuild.
  void _handleClearAllFilters() {
    _cancelPendingCommit();
    final hadFilters =
        _committedQuery.isNotEmpty || _selectedSymptoms.isNotEmpty;
    _committedQuery = '';
    _queryController.clear();
    _selectedSymptoms = <PainSymptomData>{};
    if (hadFilters) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = MetraColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final summariesAsync = ref.watch(timelineProvider);

    // §10.1 — the filter chrome (field, funnel, chips, count row, no-match
    // state) lives only in the Timeline view. Tabella always renders the full
    // list and therefore derives nothing.
    final isTimeline = _mode == _ViewMode.timeline;

    // §4.3.2 — the reduced list is derived here, in the screen's `build()`:
    // never in the views, never in a provider. `timelineNotesProvider` is the
    // parallel note-text path the matcher's text condition reads; it
    // auto-disposes with the screen (FR-12/§4.3.4).
    final notesAsync = ref.watch(timelineNotesProvider);

    // The chip set derives from the FULL unfiltered dataset (FR-03), and only
    // from a resolved one: loading/error keep the row hidden (EC-05/EC-08).
    // Outside Timeline no chip exists at all.
    final chips = !isTimeline
        ? const <PainSymptomData>[]
        : summariesAsync.when(
            data: (data) => _deriveSymptomChips(l10n, data),
            loading: () => const <PainSymptomData>[],
            error: (_, __) => const <PainSymptomData>[],
          );

    // EC-14 groundwork: intersect the selection with the derived chip set on
    // every re-derivation, so a symptom that vanished from the data cannot keep
    // the list filtered forever.
    if (isTimeline) {
      final chipSet = chips.toSet();
      if (!chipSet.containsAll(_selectedSymptoms)) {
        _selectedSymptoms = _selectedSymptoms.intersection(chipSet);
      }
    }

    // §4.3.2 — the reduced list is derived here, in the screen's `build()`:
    // never in the views, never in a provider. A filter is "active" only when
    // it can actually reduce the list: `CycleFilterQuery.isActive` trims the
    // query, so a whitespace-only entry filters nothing (EC-04).
    final query = CycleFilterQuery(
      symptoms: _selectedSymptoms,
      noteText: _committedQuery,
    );
    final summaries = summariesAsync.valueOrNull;
    final filtered = !isTimeline || summaries == null || summaries.isEmpty
        ? null
        : const CycleFilterMatcher().apply(
            summaries: summaries,
            notesByDate: notesAsync.valueOrNull ?? const <DateTime, String>{},
            query: query,
          );

    // §6.1 (1)/(2) — the loading and error branches can be driven by either
    // provider: the note-text path joins them only while the raw committed
    // query is non-empty — and only in Timeline, where a text filter can apply
    // at all. That predicate is `_committedQuery.isNotEmpty` —
    // UNTRIMMED (OQ-16 operator decision): a whitespace-only commit keeps the
    // clear (X) affordance visible (EC-04), so it is text the user entered even
    // though no text filter can apply once the notes land.
    //
    // `!hasValue` reproduces `AsyncValue.when`'s default `skipLoadingOnRefresh`:
    // a data-bearing reload (e.g. the `timelineProvider` invalidation after
    // saving a log) keeps the list on screen instead of flashing a spinner.
    final notesGate = isTimeline && _committedQuery.isNotEmpty;
    final showLoading =
        (summariesAsync.isLoading && !summariesAsync.hasValue) ||
            (notesGate && notesAsync.isLoading);
    final showError =
        summariesAsync.hasError || (notesGate && notesAsync.hasError);

    // FR-11/EC-03: the count row exists only while a filter is active AND at
    // least one cycle matches; the no-match state supersedes it at zero, and
    // the loading/error branches suppress it — a result count describes a list
    // that is not on screen (`valueOrNull` can otherwise hand a stale count to
    // the error branch). Tabella filters nothing, so it never counts.
    final matchingCount = !isTimeline || showLoading || showError
        ? null
        : query.isActive && filtered != null && filtered.isNotEmpty
            ? filtered.length
            : null;

    return Scaffold(
      backgroundColor: colors.bgPrimary,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.archive_title, style: MetraTypography.screenTitle),
                  const SizedBox(height: 12),
                  // Canon §10.1 header order: title → [view toggle · funnel] →
                  // filter panel (search field → chip row → count row). The
                  // funnel sits on the toggle's line, right-aligned, and the
                  // whole panel stays collapsed until it is tapped.
                  Row(
                    children: [
                      SegmentedControlMetra(
                        segments: [
                          l10n.timeline_view_toggle,
                          l10n.table_view_toggle,
                        ],
                        selectedIndex: _mode.index,
                        onChanged: _handleModeChanged,
                      ),
                      const Spacer(),
                      if (isTimeline) ...[
                        const SizedBox(width: MetraSpacing.s2),
                        _FilterToggleButton(
                          open: _filtersPanelOpen,
                          label: l10n.timeline_filters_toggle_a11y,
                          onTap: _handleFilterPanelToggled,
                        ),
                      ],
                    ],
                  ),
                  // Tabella owns no filter chrome and never filters (FR-09).
                  if (isTimeline && _filtersPanelOpen) ...[
                    const SizedBox(height: MetraSpacing.s3),
                    _TimelineFilterBar(
                      queryController: _queryController,
                      chips: chips,
                      selectedSymptoms: _selectedSymptoms,
                      matchingCount: matchingCount,
                      onQueryChanged: _handleQueryChanged,
                      onChipToggled: _handleChipToggled,
                      onClearQuery: _handleClearQuery,
                      onClearAll: _handleClearAllFilters,
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              // §6.1 — the five-state enumeration, in order: loading → error
              // → truly-empty → no-match → data.
              child: showLoading
                  ? _buildLoadingBranch(l10n)
                  : showError
                      ? _buildErrorBranch(colors, l10n)
                      : _buildListBranch(
                          data: summaries ?? const <CycleSummary>[],
                          filtered: filtered,
                        ),
            ),
          ],
        ),
      ),
    );
  }

  /// §6.1 (1) — the pre-existing loading branch, unchanged (FR-13): centered
  /// spinner announced by `common_loading`. Reachable when either provider
  /// holds the screen.
  Widget _buildLoadingBranch(AppLocalizations l10n) => Center(
        child: Semantics(
          label: l10n.common_loading,
          child: const CircularProgressIndicator(),
        ),
      );

  /// §6.1 (2) — the pre-existing generic error branch, unchanged (FR-13): no
  /// domain-specific surface and no exception detail (canon §"Error model").
  Widget _buildErrorBranch(MetraPalette colors, AppLocalizations l10n) =>
      Center(
        child: Text(
          l10n.common_error_generic,
          style: TextStyle(color: colors.textSecondary),
        ),
      );

  /// §6.1 (3)–(5) — truly-empty → no-match → data, over the list already
  /// derived in [build].
  Widget _buildListBranch({
    required List<CycleSummary> data,
    required List<CycleSummary>? filtered,
  }) {
    // EC-01: truly-empty outranks every filter — delegate the empty list
    // untouched so the views keep rendering their existing hint (the no-match
    // state needs ≥ 1 cycle).
    //
    // EC-03: with ≥ 1 cycle, an active filter and zero matches the
    // screen-level no-match state replaces the list — in Timeline only. The
    // views stay filter-agnostic, and Tabella always gets the full list.
    final isTimeline = _mode == _ViewMode.timeline;
    final visible = !isTimeline || data.isEmpty ? data : (filtered ?? data);
    if (isTimeline && data.isNotEmpty && visible.isEmpty) {
      return _NoMatchState(onClearFilters: _handleClearAllFilters);
    }

    return _mode == _ViewMode.timeline
        ? TimelineView(
            summaries: visible,
            onCardTap: (summary) {
              // Order matters (#3, FR-01/FR-02): the focus request must land
              // BEFORE navigation, otherwise the router could build
              // CalendarScreen first and silently drop the request.
              ref
                  .read(calendarFocusRequestProvider.notifier)
                  .request(summary.cycle.startDate);
              context.go('/calendar');
            },
          )
        : TableView(summaries: visible);
  }
}

/// Canon §9.6 daily-entry order for the six predefined symptom types ("Mal di
/// testa · Stanchezza · Mal di schiena · Nausea · Gonfiore · Tensione
/// mammaria").
const List<PainSymptomType> _canonicalSymptomOrder = [
  PainSymptomType.headache,
  PainSymptomType.fatigue,
  PainSymptomType.backPain,
  PainSymptomType.nausea,
  PainSymptomType.bloating,
  PainSymptomType.breastTenderness,
];

/// Derives the ordered filter-chip set from the FULL unfiltered summaries
/// (FR-03/FR-04): predefined symptoms in the canon §9.6 daily-entry order, then
/// the legacy [PainSymptomType.migraine] value when the data carries it (OQ-06),
/// then custom labels in alphabetical order.
///
/// Returns an empty list when the data carries no symptom at all, so the caller
/// omits the row entirely (EC-02).
List<PainSymptomData> _deriveSymptomChips(
  AppLocalizations l10n,
  List<CycleSummary> summaries,
) {
  final present = summaries.expand((s) => s.symptoms).toSet();
  if (present.isEmpty) {
    return const <PainSymptomData>[];
  }

  final byType = <PainSymptomType, List<PainSymptomData>>{};
  for (final symptom in present) {
    byType
        .putIfAbsent(symptom.symptomType, () => <PainSymptomData>[])
        .add(symptom);
  }

  final chips = <PainSymptomData>[];
  for (final type in _canonicalSymptomOrder) {
    final predefined = byType[type];
    if (predefined != null) {
      chips.addAll(predefined);
    }
  }
  final legacy = byType[PainSymptomType.migraine];
  if (legacy != null) {
    chips.addAll(legacy);
  }
  final custom = byType[PainSymptomType.custom];
  if (custom != null) {
    final sorted = <PainSymptomData>[...custom];
    sorted.sort(
      (a, b) => _compareLabels(
        _symptomLabel(l10n, a),
        _symptomLabel(l10n, b),
      ),
    );
    chips.addAll(sorted);
  }
  return chips;
}

/// Case-insensitive label comparison.
///
/// `intl` 0.20 (the pinned version) ships no `Collator`, so this is a case-folded
/// `String.compareTo` with a code-unit tie-break for determinism. IT and EN share
/// the Latin alphabet, which keeps FR-04's alphabetical order stable in both
/// locales.
int _compareLabels(String a, String b) {
  final folded = a.toLowerCase().compareTo(b.toLowerCase());
  return folded != 0 ? folded : a.compareTo(b);
}

/// Localized chip label for one recorded symptom. Redirected into a chip's
/// `label` and `semanticsLabel` alike (FR-16).
String _symptomLabel(AppLocalizations l10n, PainSymptomData symptom) =>
    switch (symptom.symptomType) {
      PainSymptomType.backPain => l10n.daily_entry_symptom_backPain,
      PainSymptomType.headache => l10n.daily_entry_symptom_headache,
      PainSymptomType.migraine => l10n.daily_entry_symptom_migraine,
      PainSymptomType.bloating => l10n.daily_entry_symptom_bloating,
      PainSymptomType.fatigue => l10n.daily_entry_symptom_fatigue,
      PainSymptomType.nausea => l10n.daily_entry_symptom_nausea,
      PainSymptomType.breastTenderness =>
        l10n.daily_entry_symptom_breastTenderness,
      PainSymptomType.custom =>
        symptom.customLabel ?? l10n.daily_entry_symptom_custom,
    };

/// Filter chrome mounted directly below the Timeline/Tabella segmented control,
/// Timeline view only: the note-search field with the funnel toggle beside it,
/// the collapsible symptom chip row and the result-count row
/// (FR-01/FR-03/FR-11, §10.1).
///
/// <!-- CANON GAP: filter-chip visual surface — OQ-02 -->
/// <!-- CANON GAP: search-input surface — OQ-03 -->
/// <!-- CANON GAP: funnel filter toggle — no dedicated bible section; reuses
/// the §5.4 invisible-hit-region technique (44×44) around a stroke glyph at the
/// 0.68 body-secondary stop, the same stop as the field's clear affordance
/// (OQ-02/OQ-03 bible patch) -->
/// <!-- CANON GAP: count/clear-all row — no dedicated bible section; reuses the
/// §1.2 "Body secondary" row and the §8.1 "Oggi" text-action precedent
/// (OQ-02/OQ-03 bible patch) -->
///
/// The bible defines no Archivio filter/search chrome, so these surfaces are
/// documented-gap reuses: they compose catalogued tokens only — the
/// `TextFieldMetra` surface (bgSurface fill, borderSubtle border, focusRing,
/// 44 dp minHeight), canon §6.1 chip anatomy via `ChoiceChipMetra` with the §1.2
/// "Filter / chip label" `w400` idle weight, the 0.68 body-secondary stop and
/// §1.3 spacing steps. No new visual value is introduced (NFR-08). A bible patch
/// (mockup first) is tracked as a follow-up.
///
/// Private on purpose: the screen owns both the state (§5.1.G) and the derived
/// chip set, so no new public widget contract is introduced.
class _TimelineFilterBar extends StatelessWidget {
  const _TimelineFilterBar({
    required this.queryController,
    required this.chips,
    required this.selectedSymptoms,
    required this.matchingCount,
    required this.onQueryChanged,
    required this.onChipToggled,
    required this.onClearQuery,
    required this.onClearAll,
  });

  /// Raw field text; the clear affordance is driven by it (EC-04).
  final TextEditingController queryController;

  /// Ordered, de-duplicated chip set derived from the full unfiltered data.
  /// Empty → the chip row is omitted entirely (EC-02).
  final List<PainSymptomData> chips;

  final Set<PainSymptomData> selectedSymptoms;

  /// Matching-cycle count while a filter is active and ≥ 1 cycle matches
  /// (FR-11); `null` hides the count row — no active filter, or zero matches,
  /// where the screen-level no-match state supersedes it (EC-03).
  final int? matchingCount;

  /// Feeds the 300 ms commit window; the field owns no debounce logic itself
  /// (§5.1.F: debounce lives in the screen).
  final ValueChanged<String> onQueryChanged;

  final void Function(PainSymptomData symptom, bool selected) onChipToggled;

  final VoidCallback onClearQuery;

  /// Clears every filter; shared by the count row's clear-all and the no-match
  /// state's clear-filters action (FR-10/FR-11).
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    final colors = MetraColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final count = matchingCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Only the raw text drives the suffix slot, so listen to the controller
        // instead of rebuilding the whole screen on every keystroke (EC-04).
        // The field carries no leading glyph: the funnel lives on the
        // view-toggle line, outside the panel.
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: queryController,
          builder: (context, value, _) => TextFieldMetra(
            controller: queryController,
            hint: l10n.timeline_search_hint,
            semanticsLabel: l10n.timeline_search_hint,
            onChanged: onQueryChanged,
            suffixIcon: value.text.isEmpty
                ? null
                : Semantics(
                    label: l10n.timeline_search_clear_a11y,
                    button: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onClearQuery,
                      child: SizedBox(
                        width: MetraSpacing.sp44,
                        height: MetraSpacing.sp44,
                        child: Center(
                          child: MetraIcon(
                            svgBody: MetraIcons.x,
                            size: 18,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ),
        if (chips.isNotEmpty) ...[
          const SizedBox(height: MetraSpacing.s3),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final symptom in chips)
                  Padding(
                    padding: const EdgeInsets.only(right: MetraSpacing.s2),
                    child: ChoiceChipMetra(
                      label: _symptomLabel(l10n, symptom),
                      selected: selectedSymptoms.contains(symptom),
                      semanticsLabel: _symptomLabel(l10n, symptom),
                      idleFontWeight: FontWeight.w400,
                      onSelected: (selected) =>
                          onChipToggled(symptom, selected),
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (count != null)
          Padding(
            padding: const EdgeInsets.only(top: MetraSpacing.s3),
            child: _FilterCountRow(count: count, onClearAll: onClearAll),
          ),
      ],
    );
  }
}

/// The funnel that reveals/hides the whole filter panel (search field + chip
/// row + count row), sitting on the Timeline/Tabella toggle line, right-aligned.
///
/// <!-- CANON GAP: funnel filter toggle — no bible section; see OQ-02/OQ-03 -->
///
/// Anatomy: an opaque 44×44 hit region (§5.4 technique, NFR-03) around the
/// refined funnel glyph drawn at the 0.68 body-secondary stop while collapsed
/// and at `textPrimary` while the panel is open — both catalogued values, so no
/// new visual token is introduced (NFR-08). The whole control is one
/// `Semantics(button: true, toggled:)` node with the localized label (FR-17).
class _FilterToggleButton extends StatelessWidget {
  const _FilterToggleButton({
    required this.open,
    required this.label,
    required this.onTap,
  });

  /// Whether the chip row is currently revealed.
  final bool open;

  /// Localized accessible name of the toggle.
  final String label;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = MetraColors.of(context);

    return Semantics(
      button: true,
      toggled: open,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: MetraSpacing.sp44,
          height: MetraSpacing.sp44,
          child: Center(
            child: MetraIcon(
              svgBody: MetraIcons.filterRefined,
              size: 18,
              color: open
                  ? colors.textPrimary
                  : colors.textPrimary.withValues(alpha: 0.68),
            ),
          ),
        ),
      ),
    );
  }
}

/// Result count + clear-all row (FR-11), visible only while a filter is active
/// and ≥ 1 cycle matches.
///
/// <!-- CANON GAP: no bible section covers this surface — see OQ-02/OQ-03 -->
///
/// Count text: §1.2 "Body secondary" row (`MetraTypography.caption`, Inter
/// 13/400) at the §1.1.2/§1.1.1 body-secondary alpha stop, wrapped in a polite
/// live region so screen readers announce every change (FR-15).
class _FilterCountRow extends StatelessWidget {
  const _FilterCountRow({required this.count, required this.onClearAll});

  final int count;

  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    final colors = MetraColors.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Row(
      children: [
        Expanded(
          child: Semantics(
            liveRegion: true,
            child: Text(
              l10n.timeline_filter_results_count(count),
              style: MetraTypography.caption.copyWith(
                color: colors.textPrimary.withValues(
                  alpha: _bodySecondaryAlpha(context),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: MetraSpacing.s2),
        _FilterTextAction(
          label: l10n.timeline_filter_clear_all,
          onTap: onClearAll,
        ),
      ],
    );
  }
}

/// Bare text action in the canon §8.1 "Oggi" pattern: Inter 13 weight 500 in
/// `textPrimary`, no border, no pill, with a ≥ 44×44 hit region.
///
/// <!-- CANON GAP: the bare text-action pattern has no dedicated bible
/// section; it reuses the §8.1 precedent (OQ-02/OQ-03 bible patch) -->
class _FilterTextAction extends StatelessWidget {
  const _FilterTextAction({required this.label, required this.onTap});

  final String label;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = MetraColors.of(context);

    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: MetraSpacing.sp44,
            minHeight: MetraSpacing.sp44,
          ),
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: MetraTypography.caption.copyWith(
                fontWeight: FontWeight.w500,
                color: colors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Screen-level no-match state (FR-10/EC-03): ≥ 1 cycle, at least one active
/// filter, zero matching cycles. It lives in the screen — never in the
/// filter-agnostic `TimelineView`/`TableView`.
///
/// Canon §13 empty-state register: Inter 15 italic (§1.2 "List item title"
/// size, italic per §1.2.1), centered, `MetraSpacing.s8` padding (the
/// `TimelineView._EmptyState` geometry), at the §1.1.2/§1.1.1 body-secondary
/// stop (0.68 light / 0.65 dark ≈ 4.9:1) — deliberately NOT the 0.40
/// `textSecondary` of the pre-existing hint (OQ-14: ≈ 2.3:1, not propagated
/// onto a new surface).
class _NoMatchState extends StatelessWidget {
  const _NoMatchState({required this.onClearFilters});

  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final colors = MetraColors.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MetraSpacing.s8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.timeline_filter_no_match,
              textAlign: TextAlign.center,
              style: MetraTypography.listTitle.copyWith(
                color: colors.textPrimary.withValues(
                  alpha: _bodySecondaryAlpha(context),
                ),
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: MetraSpacing.s3),
            _FilterTextAction(
              label: l10n.timeline_filter_no_match_action,
              onTap: onClearFilters,
            ),
          ],
        ),
      ),
    );
  }
}

/// The §1.1.2 (light) / §1.1.1 (dark) body-secondary catalogued alpha stop.
double _bodySecondaryAlpha(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? 0.65 : 0.68;
