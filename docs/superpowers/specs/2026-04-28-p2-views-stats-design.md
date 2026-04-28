# Design Spec — P-2: Views + Stats

**Date:** 2026-04-28  
**Features:** F-03 (Timeline), F-04 (Dense Table), F-05 (Statistics)  
**Commit base:** c28280a (v0.1.0-p1 tagged)  
**Status:** Approved

---

## 1. Scope

P-2 replaces the two placeholder screens (`TimelineScreen`, `StatsScreen`) with full implementations:

- **F-03** Vertical timeline — scrollable list of cycle cards with a proportional horizontal bar.
- **F-04** Dense table — compact tabular view of the same cycles. A `SegmentedControlMetra` in the timeline screen header toggles between F-03 and F-04; they share a single route and a single notifier.
- **F-05** Statistics — four stat cards (cycle length, period length, symptom frequency, flow intensity) using `fl_chart` line and bar charts.

Out of scope for P-2: predictions (F-06), cycle-length filtering/date range selection, custom symptoms in the frequency chart (limited to the five fixed `PainSymptomType` values: cramps, backPain, headache, migraine, bloating).

---

## 2. Domain layer

### 2.1 `CycleSummary` value object

New file: `lib/domain/entities/cycle_summary.dart`

```
CycleSummary {
  final CycleEntryEntity cycle
  final List<PainSymptomType> symptoms   // distinct types seen across the cycle's date range
  final FlowIntensity? dominantFlow      // most-frequent non-null FlowIntensity in range; null if none; highest intensity wins on tie
}
```

Pure Dart value object. Implements `==` and `hashCode`. No Drift or Flutter imports.

### 2.2 `CycleStatsData` value object

New file: `lib/domain/entities/cycle_stats_data.dart`

```
CycleStatsData {
  final List<CycleDataPoint> points      // one per complete cycle, oldest-first
  final Map<PainSymptomType, double> symptomFrequencies  // 0.0–1.0 fraction
}

CycleDataPoint {
  final DateTime startDate               // used as X-axis label
  final int cycleLength                  // always non-null (complete cycles only)
  final int? periodLength                // null if not recorded
  final FlowIntensity? dominantFlow
}
```

### 2.3 `GetCycleSummaries` use case

File: `lib/domain/use_cases/get_cycle_summaries.dart`

```dart
Stream<List<CycleSummary>> call()
```

- Combines `CycleEntryRepository.watchAll()` (stream) with `DailyLogRepository.getAllOrderedByDate()` (future, re-fetched on each cycle-list emission via `asyncMap`).
- For each `CycleEntryEntity`, filters daily logs to the range `[startDate, endDate ?? today]`.
- Extracts distinct `PainSymptomType` values from `PainSymptomData` for those logs (requires `DailyLogRepository.getPainSymptoms(date)` calls — one per flow-day in the cycle).
- Computes `dominantFlow` as the mode of non-null `flowIntensity` values across those logs.
- Returns list sorted newest-first.

**Optimization note:** `getPainSymptoms` is called per day. For MVP this is acceptable (cycles are typically 4–7 flow days). If performance becomes an issue in P-3+, a `getDailyLogsWithSymbolsForRange(start, end)` DAO method can be added.

### 2.4 `ComputeCycleStats` use case

File: `lib/domain/use_cases/compute_cycle_stats.dart`

```dart
Stream<CycleStatsData?> call()
```

- Derived from `GetCycleSummaries` stream via `map`.
- Filters to complete cycles only (`cycle.endDate != null && cycle.cycleLength != null`).
- Returns `null` if zero complete cycles.
- `points`: each complete cycle becomes a `CycleDataPoint`, oldest-first.
- `symptomFrequencies`: for each fixed `PainSymptomType`, count cycles where the symptom appears ÷ total complete cycles. Types with zero occurrences are included with value 0.0 (UI decides whether to show them).

---

## 3. Providers

File: `lib/providers/use_case_providers.dart` (existing file, add entries)

```dart
getCycleSummariesProvider   // FutureProvider<GetCycleSummaries>
computeCycleStatsProvider   // FutureProvider<ComputeCycleStats>
```

Both depend on `dailyLogRepositoryProvider.future` and `cycleEntryRepositoryProvider.future`, consistent with existing provider patterns.

---

## 4. Timeline + Table screen (F-03 + F-04)

### 4.1 State

File: `lib/features/timeline/state/timeline_controller.dart`

```dart
final timelineProvider = AutoDisposeAsyncNotifierProvider<TimelineNotifier, List<CycleSummary>>(...)

class TimelineNotifier extends AutoDisposeAsyncNotifier<List<CycleSummary>> {
  @override
  Future<List<CycleSummary>> build() async {
    final uc = await ref.read(getCycleSummariesProvider.future);
    // Completer + stream subscription pattern (same as DailyEntryNotifier).
    ...
  }
}
```

### 4.2 Screen

File: `lib/features/timeline/timeline_screen.dart` (replaces placeholder)

- `ConsumerStatefulWidget` with local `_ViewMode` enum (`{timeline, table}`.
- Header: screen title + `SegmentedControlMetra` (reuse `lib/core/widgets/segmented_control_metra.dart`).
- Body switches on `_ViewMode` between `TimelineView` and `TableView`.
- Handles `AsyncLoading` → `CircularProgressIndicator`, `AsyncError` → generic error text.

### 4.3 `TimelineView`

File: `lib/features/timeline/widgets/timeline_view.dart`

- `ListView.builder` over `List<CycleSummary>`, newest-first.
- Empty state: centered `Column` with a thin-wave SVG icon + `AppLocalizations.timeline_empty_hint`.

### 4.4 `TimelineCard`

File: `lib/features/timeline/widgets/timeline_card.dart`

- **Header row:** date range string (e.g. "13–18 apr 2026") + badge ("In corso" if `endDate == null`, else cycle length "28 g").
- **Bar area:** a `LayoutBuilder`-driven `Container` with terracotta fill. Width = `(cycleLength ?? elapsed_days) / 35 * maxWidth`, clamped to `[0.0, 1.0]`. The 35-day denominator is a visual reference (cycles >35 days show a full bar). Color: `MetraColors.light.accentFlow` (terracotta).
- **Meta row:** "Ciclo: N g" or "Ciclo: — g (in corso)"; symptom chips if `symptoms.isNotEmpty`.
- **Semantics:** `Semantics(label: l10n.timeline_card_a11y(startDate, endDate, length))`.
- Tap → `context.push('/daily-entry/${startDate.toIso8601String().substring(0, 10)}')` (navigates to the historical entry for the first day).

### 4.5 `TableView`

File: `lib/features/timeline/widgets/table_view.dart`

- `SingleChildScrollView` (horizontal if needed on small screens) wrapping a semantic `Table`.
- Columns: **Inizio** · **Ciclo** · **Mestr.** · **Sintomi** (widths: flex 2 · 1 · 1 · 2).
- Header row: `TableRow` with `Semantics(header: true)` cells.
- Data rows: one per `CycleSummary`, newest-first.
- Symptoms cell: comma-joined localized symptom names, truncated with ellipsis at 2 names + "…" if > 2.
- Empty state: identical to `TimelineView`.

---

## 5. Stats screen (F-05)

### 5.1 State

File: `lib/features/stats/state/stats_controller.dart`

```dart
final statsProvider = AutoDisposeAsyncNotifierProvider<StatsNotifier, CycleStatsData?>(...)
```

Same Completer + stream subscription pattern.

### 5.2 Screen

File: `lib/features/stats/stats_screen.dart` (replaces placeholder)

- `ConsumerWidget`.
- `SingleChildScrollView` > `Column` of `StatCard` widgets.
- Loading: `CircularProgressIndicator` centered.
- Error: generic error text.
- Data with `null` `CycleStatsData`: each card renders title + "Dati insufficienti" body.
- Data with non-null: cards render their respective chart widgets.

### 5.3 `StatCard`

File: `lib/features/stats/widgets/stat_card.dart`

- `Card`-like container: `MetraSpacing.md` padding, `MetraShapes.cardRadius` border radius, `MetraColors.light.bgSurface` background.
- Props: `title: String`, `child: Widget`.

### 5.4 `CycleLengthChart`

File: `lib/features/stats/widgets/cycle_length_chart.dart`

- `fl_chart LineChart`. X axis: `startDate` month abbreviations. Y axis: auto-range ± 5 days around mean. Terracotta line (`MetraColors.light.accentFlow`), 4pt dots.
- `Semantics` wrapper: label = comma-joined "N giorni" values for screen reader.

### 5.5 `PeriodLengthChart`

File: `lib/features/stats/widgets/period_length_chart.dart`

- Same structure as `CycleLengthChart`. Ochre line (`MetraColors.light.accentWarmth`).
- Data points: `CycleDataPoint.periodLength`; null points are gaps in the line (fl_chart supports this via `isVisible: false` spot).

### 5.6 `SymptomFrequencyChart`

File: `lib/features/stats/widgets/symptom_frequency_chart.dart`

- Custom widget (no fl_chart): a `Column` of rows, each row = label + `LinearProgressIndicator`-style bar + percentage text.
- Shows only symptom types with frequency > 0, sorted descending.
- "Dati insufficienti" if map is all zeros.
- Bar color: `MetraColors.light.accentFlow`.
- Semantics: each row = `Semantics(label: "${symptomName}, ${pct}%")`.

### 5.7 `FlowIntensityChart`

File: `lib/features/stats/widgets/flow_intensity_chart.dart`

- `fl_chart BarChart`. One bar per cycle (X = month abbreviation). Bar height = `FlowIntensity` ordinal value (none=0, light=1, medium=2, heavy=3, veryHeavy=4). Terracotta fill.
- Semantics wrapper: label = comma-joined flow level per cycle.

---

## 6. L10n additions

Keys to add to `lib/l10n/app_it.arb` and `app_en.arb`:

| Key | IT | EN |
|---|---|---|
| `tab_timeline` | Timeline | Timeline |
| `timeline_view_toggle` | Timeline | Timeline |
| `table_view_toggle` | Tabella | Table |
| `timeline_empty_hint` | Registra il tuo primo ciclo per vedere la timeline | Log your first cycle to see the timeline |
| `timeline_cycle_in_progress` | In corso | In progress |
| `timeline_cycle_length_days` | {n} g | {n} d |
| `timeline_card_a11y` | Ciclo dal {start} al {end}, {n} giorni | Cycle from {start} to {end}, {n} days |
| `table_col_start` | Inizio | Start |
| `table_col_cycle` | Ciclo | Cycle |
| `table_col_period` | Mestr. | Period |
| `table_col_symptoms` | Sintomi | Symptoms |
| `stats_title` | Statistiche | Statistics |
| `stats_cycle_length_title` | Lunghezza ciclo | Cycle length |
| `stats_period_length_title` | Durata mestruazione | Period length |
| `stats_symptoms_title` | Sintomi frequenti | Frequent symptoms |
| `stats_flow_title` | Intensità flusso | Flow intensity |
| `stats_insufficient_data` | Dati insufficienti | Insufficient data |
| `stats_cycle_length_avg` | {n} g in media | {n} d on average |
| `stats_period_length_avg` | {n} g in media | {n} d on average |

Symptom label keys already present in `app_it.arb` (`symptom_cramps`, etc.) — reuse them.

---

## 7. Accessibility

- Every interactive element ≥ 44×44pt tap target.
- All charts wrapped in `Semantics(label: ..., child: ...)` with a human-readable description; chart internals are visually only.
- `TimelineCard` tap target covers the full card height.
- Table rows: minimum 48dp height.
- SegmentedControl: `Semantics(selected: isActive, label: viewName)` on each tab button.
- Reduce-motion: fl_chart charts initialized with `swapAnimationDuration: Duration.zero` when `MediaQuery.of(context).disableAnimations`.

---

## 8. Testing

### Domain (unit tests)
- `GetCycleSummaries`: 0 cycles → empty list; 1 cycle with symptoms; 3 cycles newest-first order; in-progress cycle (no endDate) included with `dominantFlow` computed up to today.
- `ComputeCycleStats`: 0 complete cycles → null; 1 cycle; N cycles average correct; symptom frequency fractions sum to ≤ N_symptoms; in-progress cycle excluded.

### Widget tests
- `TimelineScreen`: loading → spinner; error → error text; empty data → empty state; data → cards rendered.
- `StatsScreen`: loading → spinner; null data → "Dati insufficienti" in cards; data → charts rendered.
- `TimelineCard`: semantics label correct; tap navigates to daily-entry route.
- `TableView`: header cells have `semanticsHeader: true`; correct row count.

All widget tests use fake notifiers extending the real notifier classes (same pattern as P-1).

---

## 9. Wave structure

| Wave | Streams | Barrier |
|---|---|---|
| A (parallel) | domain entities + use cases + tests; l10n strings | Both compile, use-case tests green |
| B (parallel) | timeline/table UI + notifier; stats UI + notifier; all widget tests | All tests pass, analyze clean |
| C | security gate (appsec-engineer); tag v0.1.0-p2 | MASVS delta + tag |

---

## 10. Definition of Done

- [ ] `flutter analyze` clean, `dart format` clean.
- [ ] All tests pass; ≥ 80% coverage on `lib/features/timeline/**` and `lib/features/stats/**`.
- [ ] No hardcoded UI strings — all via `AppLocalizations`.
- [ ] `GetCycleSummaries` and `ComputeCycleStats` have no Flutter/Drift imports.
- [ ] Empty states render for 0 cycles; "Dati insufficienti" renders inside each stat card for null `CycleStatsData`.
- [ ] All charts wrapped in semantic labels readable by TalkBack/VoiceOver.
- [ ] Reduce-motion: fl_chart animations disabled when `MediaQuery.disableAnimations`.
- [ ] `appsec-engineer` post-merge: zero critical findings.
- [ ] Tag `v0.1.0-p2` pushed.
