# Statistiche screen — Design Bible audit (2026-05-01)

**Severity summary**
- HIGH: 14 findings — header missing entirely; StatCard grid (§ 11.3) not implemented (no 2x2 summary cards, no values/units/trend subs); MiniBar chart (§ 11.4) not implemented (uses fl_chart line/bar charts instead of the spec'd 80-px column-bar primitive); symptom-frequency card uses `%` not `count/max` and wrong color (accentFlow instead of ocra); pain-scale axis still flow-shaped (CL-02 not honored).
- MEDIUM: 5 findings — card padding 16/16 not 16/18, missing `marginBottom 16` between grid and charts, no overflow-y/`padding 0/16/90`, accent border tint missing, l10n strings absent (`Statistiche`, `Ultimi 6 cicli`, four card titles, units, trend sub).
- LOW: 3 findings — title typography uses `MetraTypography.titleSm` (presumably Inter) not `DM Serif Display 26`, screen has no `Padding 12/24/16` around heading area, locale-driven month labels diverge from mockup's letter labels (A M F G D N).

---

## Header (§ 11.1)

### [BIBLE-REF § 11.1] — Header is entirely missing
- **File**: `lib/features/stats/stats_screen.dart:40-97`
- **Issue**: The screen has no header at all. `Scaffold` body goes straight from `SafeArea` into a `SingleChildScrollView` containing four `StatCard`s. No "Statistiche" title, no "Ultimi 6 cicli" subtitle, no `padding 12 / 24 / 16` heading container.
- **Bible says**: `padding 12/24/16`; title `DM Serif Display 26 inchiostro` "Statistiche"; subtitle `Inter 13 rgba(0.68) marginTop 2` "Ultimi 6 cicli".
- **Code does**: Renders only the body (loading/error/data switch).
- **Fix**: Add a `Padding(EdgeInsets.fromLTRB(24, 12, 24, 16), Column(...))` block above the scroll view containing two `Text` widgets — title `MetraTypography.displayMd` (or whichever maps to DM Serif Display 26) and subtitle Inter 13 rgba(0.68) with 2px top spacing.
- **Severity**: HIGH

### [BIBLE-REF § 11.1] — l10n keys for `Statistiche` / `Ultimi 6 cicli` missing
- **File**: `lib/l10n/app_it.arb` (no occurrence of `stats_screen_title` / `stats_subtitle`); `lib/router/app_router.dart:128` hardcodes `'Statistiche'` for nav.
- **Issue**: § 14 requires `Statistiche` and `Ultimi 6 cicli` in the l10n catalog. Neither exists.
- **Bible says**: § 14 lists `Statistiche` and `Ultimi 6 cicli` as required IT strings.
- **Code does**: `app_it.arb` has only `stats_cycle_length_title`, `stats_period_length_title`, `stats_symptoms_title`, `stats_flow_title`, `stats_insufficient_data`, `stats_cycle_length_avg`, `stats_period_length_avg`, `stats_n_days`. Title hardcoded in `app_router.dart`.
- **Fix**: Add `stats_screen_title: "Statistiche"` and `stats_screen_subtitle: "Ultimi 6 cicli"` (plus `_en` mirrors) and consume them in the new header.
- **Severity**: MEDIUM

---

## Body (§ 11.2)

### [BIBLE-REF § 11.2] — Body padding and overflow region wrong
- **File**: `lib/features/stats/stats_screen.dart:62`
- **Issue**: `SingleChildScrollView` uses `EdgeInsets.symmetric(vertical: MetraSpacing.s4)` (16/0/16/0). Should be `padding 0 / 16 / 90` (top 0, horizontal 16, bottom 90 for nav bar clearance).
- **Bible says**: `flex 1 · overflow-y auto · padding 0 / 16 / 90`.
- **Code does**: `EdgeInsets.symmetric(vertical: 16)` — no horizontal inset on the scroll view (the inset is currently provided by each `StatCard.margin` instead), no extra bottom inset for the nav bar.
- **Fix**: `padding: const EdgeInsets.fromLTRB(16, 0, 16, 90)`, and remove the horizontal margin from `StatCard` (cards should fill the body width minus the body padding).
- **Severity**: MEDIUM

---

## StatCard grid (§ 11.3)

### [BIBLE-REF § 11.3] — 2×2 StatCard summary grid is not implemented
- **File**: `lib/features/stats/stats_screen.dart:63-92`, `lib/features/stats/widgets/stat_card.dart:30-60`
- **Issue**: The Bible defines four headline summary cards in a wrap grid ("Durata media ciclo / Durata media flusso / Dolore medio / Cicli tracciati") with `value + unit + sub`. The code instead uses `StatCard` as a generic wrapper around a chart widget — there are exactly four `StatCard`s but they wrap charts (line/bar) and a symptom list, not the four scalar metrics specified.
- **Bible says**: Grid `flex wrap · gap 10 · marginBottom 16`; each card `flex 1 1 calc(50% - 6px)`, `bg surface · radius 16 · border 1px solid (accent ? terracotta44 : rgba(0.07)) · padding 16/18`. Order: (1) accent "Durata media ciclo" 28 giorni "Range: 27–30g"; (2) "Durata media flusso" 4.8 giorni "Range: 4–6g"; (3) "Dolore medio" 2.4 /3 "Trend in calo"; (4) "Cicli tracciati" 6 totali.
- **Code does**: Stacks four full-width cards vertically; each contains a chart, not a scalar. None of the four required metrics is rendered as a value+unit+sub.
- **Fix**: Introduce a new `_StatSummaryCard(title, value, unit, sub, accent)` widget and a `Wrap(spacing:10, runSpacing:10)` parent or `Row+Row` with `Expanded` children. Render the four metrics in the spec'd order. Compute `cycleLengthAvg`, `cycleLengthRange`, `periodLengthAvg`, `periodLengthRange`, `painAvg`, `painTrend`, `cyclesTrackedCount` in the stats use case and surface them on `CycleStatsData`.
- **Severity**: HIGH

### [BIBLE-REF § 11.3] — `Dolore medio` card / pain average not computed or rendered
- **File**: `lib/domain/entities/cycle_stats_data.dart:42-56`, `lib/domain/use_cases/compute_cycle_stats.dart`
- **Issue**: `CycleStatsData` exposes `points` (cycle length, period length, dominant flow) and `symptomFrequencies`, but no `painIntensityAvg` aggregate. There is no UI for "Dolore medio" anywhere on the stats screen.
- **Bible says**: Card 3 — `"Dolore medio"`, value `2.4`, unit `/3`, sub `"Trend in calo"` (subject to ST-01 gating).
- **Code does**: Pain intensity does not appear on the stats screen at all.
- **Fix**: Add `final double? painIntensityAvg; final PainTrend painTrend;` to `CycleStatsData`; aggregate from logs in `ComputeCycleStats`. Render with unit literally `"/3"` (CL-02). Pain trend only when ≥3 cycles (ST-01).
- **Severity**: HIGH

### [BIBLE-REF § 11.3 + CL-02] — Pain unit/axis must be `/3`, never `/5` or `/4`
- **File**: `lib/features/stats/widgets/flow_intensity_chart.dart:75` (pain proxy via flow ordinal — see next finding) and any future pain card.
- **Issue**: Once a pain card and pain mini-bar are added (currently absent), they must use unit `/3`. The Bible mockup labels the pain mini-bar `"Intensità dolore (0–3)"`, max axis 5 (display headroom), but card unit is `/3`.
- **Bible says**: Pain unit `/3`. CL-02: "All statistics, charts, and axis labels must reflect 0–3 range (not 1–5 or any other)."
- **Code does**: No pain card; the closest analogue (`FlowIntensityChart`) is a flow chart (max = `FlowIntensity.values.length - 1`), not pain.
- **Fix**: When implementing the `Dolore medio` card and the `Intensità dolore (0–3)` mini-bar, hardcode `unit: '/3'` and series clamped 0..3 (axis maxY 5 OK per Bible series sample 4 — but data must be from `painIntensity` field, never derived from flow).
- **Severity**: HIGH

### [BIBLE-REF § 11.3] — Cycles-tracked counter not rendered
- **File**: `lib/features/stats/stats_screen.dart` (no card), `lib/domain/entities/cycle_stats_data.dart`
- **Issue**: Card 4 ("Cicli tracciati N totali") missing.
- **Bible says**: `"Cicli tracciati"`, value `6`, unit `totali`, no sub.
- **Code does**: Not rendered. `CycleStatsData.points.length` would supply the value but no UI surfaces it.
- **Fix**: Add 4th summary card; value = `points.length`, unit `totali`, no sub.
- **Severity**: HIGH

### [BIBLE-REF § 11.3] — Card 1 must be accent (terracotta value + tinted border)
- **File**: `lib/features/stats/widgets/stat_card.dart:33-43`
- **Issue**: `StatCard` has no `accent` parameter; border is implicit (no `BoxDecoration.border` set), value text style is uniform.
- **Bible says**: Border `1px solid (accent ? ${terracotta}44 : rgba(43,37,33,0.07))`. Value color terracotta when accent else inchiostro.
- **Code does**: No `border` at all (`BoxDecoration` only sets color + radius). No accent variant.
- **Fix**: Add `final bool accent;` to summary card; set `border: Border.all(color: accent ? terracotta.withValues(alpha:.27) : ink.withValues(alpha:.07), width: 1)`. Render value with `terracotta` when accent, otherwise inchiostro.
- **Severity**: HIGH

### [BIBLE-REF § 11.3] — StatCard padding is 16/16 not 16/18
- **File**: `lib/features/stats/widgets/stat_card.dart:38`
- **Issue**: `padding: EdgeInsets.all(MetraSpacing.s4)` → 16/16/16/16 (assuming s4=16).
- **Bible says**: `padding 16 / 18` (top/bottom 16, left/right 18).
- **Code does**: 16 on all sides.
- **Fix**: `padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18)`.
- **Severity**: MEDIUM

### [BIBLE-REF § 11.3] — StatCard horizontal margin must come from grid gap, not from card itself
- **File**: `lib/features/stats/widgets/stat_card.dart:34-37`
- **Issue**: Card sets `margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8)`. The Bible expects the layout (Wrap with `gap 10`, parent `padding 0/16/90`) to provide horizontal insets. Cards themselves have no margin.
- **Bible says**: Card has no margin; grid uses `gap 10 · marginBottom 16`.
- **Code does**: 16/8 margin per card.
- **Fix**: Remove `margin` from `StatCard`. Body provides 16px lateral padding; `Wrap(spacing:10, runSpacing:10)` provides intra-grid gap; bottom-of-grid spacing comes from a 16-px `SizedBox` after the grid.
- **Severity**: MEDIUM

### [BIBLE-REF § 11.3] — Title typography is Inter 12, body uses 13
- **File**: `lib/features/stats/widgets/stat_card.dart:48-53`
- **Issue**: Card title rendered with `MetraTypography.titleSm` (presumably Inter 13/15 bold) instead of `Inter 12 rgba(0.68) marginBottom 6`.
- **Bible says**: Title `Inter 12 rgba(0.68)`, then `marginBottom 6`.
- **Code does**: `titleSm`, primary text color, then `SizedBox(height: MetraSpacing.s3)` (12 if s3=12).
- **Fix**: Use Inter 12 with `textSecondary` (rgba ~0.68); follow with `SizedBox(height:6)`. (Note: this is the *summary* card spec; the chart wrapper card § 11.4 uses `Inter 13 weight 500 inchiostro` — different — see below.)
- **Severity**: LOW (title style); HIGH if conflated across summary vs. chart cards.

---

## MiniBar chart (§ 11.4)

### [BIBLE-REF § 11.4] — MiniBar chart primitive does not exist
- **File**: `lib/features/stats/widgets/cycle_length_chart.dart`, `period_length_chart.dart`, `flow_intensity_chart.dart`
- **Issue**: Bible defines a custom 6-bar chart (28-wide bars, top-rounded radius `4 4 0 0`, opacity 0.85, height = `value/max × 80px`, with label below in Inter 10 and value below in Inter 13/500). Code instead uses `fl_chart`'s `LineChart` (cycle length, period length) and `BarChart` (flow). No MiniBar primitive exists.
- **Bible says**: Two charts: (1) `Durata ciclo (giorni)` color terracotta max 35 series `28,27,29,28,30,28`; (2) `Intensità dolore (0–3)` color malva max 5 series `3,2,3,1,4,2`. Each bar 28 wide, top-rounded, 0.85 opacity, height `value/max × 80`. Period-length and flow-intensity charts are NOT in the Bible.
- **Code does**: Renders Lunghezza ciclo (LineChart, accentFlow), Durata mestruazione (LineChart, accentWarmth), Intensità flusso (BarChart of flow ordinal). No "Intensità dolore" chart.
- **Fix**: Replace `cycle_length_chart.dart` with a `MiniBarChart` (custom widget): `Row(crossAxisAlignment: end, children: bars.map((b) => Expanded(child: Column(children: [SizedBox(height: 80, child: Align(alignment: bottomCenter, child: Container(width: 28, height: value/max*80, decoration: BoxDecoration(color: color.withValues(alpha:.85), borderRadius: BorderRadius.vertical(top: Radius.circular(4))))))), SizedBox(height:5), Text(value, Inter 13/500), Text(label, Inter 10/.68)])))`. Drop period-length and flow charts; add the pain mini-bar (malva, max 5, axis label "Intensità dolore (0–3)").
- **Severity**: HIGH

### [BIBLE-REF § 11.4] — Wrong chart inventory (period-length and flow-intensity present, pain absent)
- **File**: `lib/features/stats/stats_screen.dart:71-90`
- **Issue**: Code renders "Durata mestruazione" (period length) and "Intensità flusso" (flow intensity) as charts. Bible specifies *two* charts only: cycle length and pain intensity.
- **Bible says**: § 11.4 charts list = `Durata ciclo (giorni)` + `Intensità dolore (0–3)`. Period length and flow intensity are surfaced only via the summary cards (period length avg in card 2; flow appears nowhere on stats screen).
- **Code does**: Period length and flow charts shipped; pain chart missing.
- **Fix**: Delete `period_length_chart.dart` and `flow_intensity_chart.dart`. Add `pain_intensity_chart.dart` (MiniBar over `painIntensity` 0–3 per cycle, color malva).
- **Severity**: HIGH

### [BIBLE-REF § 11.4] — Chart wrapper border, padding, and title style not implemented
- **File**: `lib/features/stats/widgets/stat_card.dart` (used as the chart wrapper)
- **Issue**: Bible's chart card has `border 1px rgba(0.07)`, `padding 18/16`, `title row Inter 13 weight 500 inchiostro · marginBottom 16`. Code's `StatCard` has no border, padding `16/16`, and uses titleSm color textPrimary with `SizedBox 12` underneath.
- **Bible says**: see § 11.4 wrapper spec.
- **Code does**: No border; padding 16/16; title style/weight not specified to Inter 13/500.
- **Fix**: Either (a) introduce a separate `_ChartCard` widget with the spec'd wrapper, or (b) extend `StatCard` to support a `chart` mode with border, padding 18/16, title Inter 13/500/inchiostro, marginBottom 16 between title and chart.
- **Severity**: MEDIUM

### [BIBLE-REF § 11.4] — Chart cards have no `marginBottom 12` between consecutive charts
- **File**: `lib/features/stats/widgets/stat_card.dart:35-37`
- **Issue**: Per-card `vertical: MetraSpacing.s2` (8) margin doesn't match the spec'd `marginBottom 12` (and creates 8 above too, which is not in the spec).
- **Bible says**: Chart wrapper `marginBottom 12`.
- **Code does**: `vertical: 8` margin.
- **Fix**: Use `Padding(EdgeInsets.only(bottom: 12))` between cards (and between grid and first chart).
- **Severity**: LOW

### [BIBLE-REF § 11.4] — Bottom-axis label format diverges from mockup
- **File**: `lib/features/stats/widgets/cycle_length_chart.dart:114-130`, `period_length_chart.dart:130-146`, `flow_intensity_chart.dart:86-101`
- **Issue**: Code shows month abbreviation via `DateFormat.MMM(locale)` ("apr", "mag", …). The mockup labels are Italian month *initials* "A M F G D N" (apparently april, may, … or possibly aprile/maggio/febbraio/gennaio/dicembre/novembre). For the spec'd 6-bar series (28,27,29,28,30,28), labels should be the single-letter initials per the table.
- **Bible says**: Labels (A M F G D N) — Italian month initials matching the 6 cycles.
- **Code does**: 3-letter month abbreviations from `intl`.
- **Fix**: When data points are present, render label as `DateFormat('LLLLL', 'it').format(date).toUpperCase()` (single-letter narrow form) — and fall back to a static A/M/F/G/D/N sequence for design verification when fixtures match the mockup.
- **Severity**: LOW

---

## Symptom-frequency card (§ 11.5)

### [BIBLE-REF § 11.5] — Count rendered as percentage instead of `count/max`
- **File**: `lib/features/stats/widgets/symptom_frequency_chart.dart:60, 92`
- **Issue**: `final pct = (entry.value * 100).round();` then `Text('$pct%', …)`. Bible expects `Inter 13 rgba(0.68) "{count}/{max}"` (e.g. `5/6`).
- **Bible says**: Right-hand label `"{count}/{max}"` per row (e.g. `Crampi 5/6`, `Stanchezza 4/6`).
- **Code does**: `"42%"`-style rendering.
- **Fix**: Pass raw `count` and `cyclesTracked` (max) into the widget; render `'${count}/${max}'`. Update `CycleStatsData.symptomFrequencies` to expose absolute counts (or pass max separately to the widget).
- **Severity**: HIGH

### [BIBLE-REF § 11.5] — Fill color is accentFlow (terracotta) instead of ocra
- **File**: `lib/features/stats/widgets/symptom_frequency_chart.dart:34-35`
- **Issue**: `barColor = accentFlow`. Bible explicitly sets fill bg to `ocra`.
- **Bible says**: `fill: bg ocra`.
- **Code does**: `accentFlow` (terracotta).
- **Fix**: Use `MetraColors.{light,dark}.ocra` (or whichever token maps to ocra). If the token doesn't exist yet, add it.
- **Severity**: HIGH

### [BIBLE-REF § 11.5] — Track height/radius/color wrong; uses `LinearProgressIndicator`
- **File**: `lib/features/stats/widgets/symptom_frequency_chart.dart:78-86`
- **Issue**: Code uses `LinearProgressIndicator(minHeight: 8, backgroundColor: bgSunken, …)` with `BorderRadius.circular(4)`. Bible: track `height 6 · radius 3 · bg rgba(43,37,33,0.08)`, fill `height 6 · radius 3 · bg ocra · width = count/max × 100%`.
- **Bible says**: 6-px height, 3-px radius, track `rgba(0.08)` (not `bgSunken` token), fill ocra.
- **Code does**: 8-px height, 4-px radius, track `bgSunken`, fill accentFlow.
- **Fix**: Build a custom 2-layer `Container` (track + child fill) with explicit heights and radii: `Container(height: 6, decoration: BoxDecoration(color: ink.withValues(alpha:.08), borderRadius: BorderRadius.circular(3)), child: Align(alignment: Alignment.centerLeft, widthFactor: count/max, child: Container(decoration: BoxDecoration(color: ocra, borderRadius: BorderRadius.circular(3)))))`.
- **Severity**: HIGH

### [BIBLE-REF § 11.5] — Row layout: label left, count right (space-between row), bar BELOW
- **File**: `lib/features/stats/widgets/symptom_frequency_chart.dart:66-99`
- **Issue**: Code lays out as `Row(label, bar, count)` — three columns side by side. Bible specifies `Column(Row(label, count) marginBottom 4, track)` — label and count on top, bar full-width beneath.
- **Bible says**: `row space-between marginBottom 4: label / count`, then track full width below; outer row marginBottom 10.
- **Code does**: Single horizontal row with bar between label and count.
- **Fix**: Replace each row with `Column(crossAxisAlignment: stretch, children: [Row(mainAxisAlignment: spaceBetween, children: [labelText, countText]), SizedBox(height:4), trackWithFill])` with parent `Padding(EdgeInsets.only(bottom:10))`.
- **Severity**: HIGH

### [BIBLE-REF § 11.5] — Title text & marginBottom missing
- **File**: `lib/features/stats/stats_screen.dart:78`, `lib/features/stats/widgets/symptom_frequency_chart.dart`
- **Issue**: Title is `stats_symptoms_title` = "Sintomi frequenti". Bible literal is `"Sintomi più frequenti"`. Also, the symptom frequency widget itself does not draw a title — title comes from the wrapping `StatCard`, which uses Inter (titleSm) not the chart-card spec.
- **Bible says**: Title `"Sintomi più frequenti"`, Inter 13 weight 500 inchiostro, marginBottom 14.
- **Code does**: Title `"Sintomi frequenti"`; rendered via `StatCard` titleSm + 12-px gap.
- **Fix**: Update IT/EN ARB to `"Sintomi più frequenti"` / `"Most frequent symptoms"`. Render title with chart-card style and `SizedBox(height:14)` below.
- **Severity**: MEDIUM

### [BIBLE-REF § 11.5 / CL-03] — Symptom series order/labels diverge from mockup
- **File**: `lib/features/stats/widgets/symptom_frequency_chart.dart:42-49, 105-126`
- **Issue**: Widget sorts by descending frequency and excludes zero-count items, so the order is data-dependent. Bible mockup shows a fixed verbatim series: `Crampi 5/6 · Stanchezza 4/6 · Mal di testa 3/6 · Mal di schiena 2/6`. Order in mockup is also descending, so behavior matches when sample data matches; however, the Bible labels are spec'd literally and CL-03 dictates the canonical IT labels. Quick check: cramps, fatigue, headache, backPain match `Crampi / Stanchezza / Mal di testa / Mal di schiena`. Verify ARB strings are exactly these (no synonyms).
- **Bible says**: Series exactly as listed.
- **Code does**: Data-driven order; labels come from `daily_entry_symptom_*` ARB keys (verify content matches CL-03).
- **Fix**: No code change to ordering (descending matches). Confirm in `app_it.arb` that `daily_entry_symptom_cramps = "Crampi"`, `_fatigue = "Stanchezza"`, `_headache = "Mal di testa"`, `_backPain = "Mal di schiena"` (per CL-03, "Mal di schiena" not "Schiena").
- **Severity**: LOW

---

## ST-01 (trend gating)

### [BIBLE-REF § 11.3 + ST-01] — Trend sub gating partially correct (≥3 cycles), but no trend label exists yet
- **File**: `lib/features/stats/stats_screen.dart:67, 73, 79, 87`
- **Issue**: Each chart card already gates rendering on `statsData.points.length < 3` → shows `_InsufficientData`. That satisfies the *chart* gate. But the Bible's `Dolore medio` card has a directional sub `"Trend in calo"` that ST-01 says must NOT appear unless ≥3 complete cycles — and currently this sub doesn't exist anywhere. When implemented, the sub MUST be gated.
- **Bible says**: ST-01: "Do not show directional trend labels ('Trend in calo', 'Trend in aumento') unless the user has at minimum 3 complete cycles logged."
- **Code does**: Chart gating exists; trend label not implemented yet.
- **Fix**: When adding the `Dolore medio` summary card, only set `sub` when `cyclesTracked >= 3` AND a trend direction can be computed; otherwise omit the sub entirely.
- **Severity**: MEDIUM (gating logic must land *with* the new card)

---

## L10n (§ 14)

### [BIBLE-REF § 14] — Required IT strings not present in `app_it.arb`
- **File**: `lib/l10n/app_it.arb`
- **Issue**: § 14 lists `Statistiche`, `Ultimi 6 cicli`, plus the per-card titles/units/subs/range labels (`Durata media ciclo`, `Range: 27–30g`, `Durata media flusso`, `Range: 4–6g`, `Dolore medio`, `Trend in calo`, `Cicli tracciati`, units `giorni`, `/3`, `totali`, chart titles `Durata ciclo (giorni)`, `Intensità dolore (0–3)`, `Sintomi più frequenti`). None of these strings exists.
- **Bible says**: see § 14.
- **Code does**: Only `stats_cycle_length_title` ("Lunghezza ciclo"), `stats_period_length_title` ("Durata mestruazione"), `stats_symptoms_title` ("Sintomi frequenti"), `stats_flow_title` ("Intensità flusso"), `stats_insufficient_data`, two `_avg` ICU plurals, `stats_n_days`. None of these matches the Bible literals.
- **Fix**: Add ARB keys (and EN mirrors) for: `stats_screen_title`, `stats_screen_subtitle`, `stats_card_avg_cycle_title/value/unit/sub`, `stats_card_avg_period_title/value/unit/sub`, `stats_card_pain_title/unit`, `stats_card_pain_trend_decreasing/increasing/stable`, `stats_card_cycles_tracked_title/unit`, `stats_chart_cycle_length_title`, `stats_chart_pain_intensity_title`, `stats_symptom_frequency_title`. Keep range-string format flexible (`"Range: {min}–{max}g"` ICU).
- **Severity**: HIGH

---

## Summary of structural gap

The implementation is at roughly the level of a generic "charts dump" — four `StatCard`s wrapping `fl_chart` widgets — whereas § 11 specifies a two-tier layout: (a) a 2×2 grid of *summary scalar cards* on top, then (b) two *MiniBar chart cards* (cycle length + pain intensity), then (c) a *symptom-frequency card* with horizontal bars. Recommend re-implementing § 11 from scratch following the Bible literally:

1. Add header (§ 11.1).
2. Compute scalar aggregates in `ComputeCycleStats`: `cycleLengthAvg/Range`, `periodLengthAvg/Range`, `painIntensityAvg`, `painTrend`, `cyclesTrackedCount`, plus per-cycle `cycleLength` and `painIntensity` series for the two mini-bars, plus absolute symptom counts.
3. Build a `_StatSummaryCard` (with `accent` variant) and a `Wrap` grid (§ 11.3).
4. Build a `_MiniBarChart` primitive (§ 11.4) and a `_ChartCard` wrapper.
5. Rewrite `SymptomFrequencyChart` per § 11.5 (column-row layout, count/max label, ocra fill, 6-px track).
6. Add all l10n strings (§ 14) and replace hardcoded `'Statistiche'` in the nav.
7. Honor ST-01 and CL-02 in the new card/chart logic.
