# Archivio audit — DESIGN-BIBLE.md § 10 conformance

Severity summary (counts): **12 HIGH · 11 MEDIUM · 4 LOW**.
The current `lib/features/timeline/` predates § 10; it implements a different visual model entirely (date-range header + proportional duration bar + status badge) — none of which exist in the bible. The audit below should be read as motivation for a rebuild, not pixel-tweaks.
Two cross-cutting issues: the shared `SegmentedControlMetra` widget violates § 5.4 (affects every consumer, not just Archivio); and the domain entity `CycleSummary` is missing the pain aggregate required for the AR-01 pain pill — fixing the timeline card cosmetically is not enough.

---

## Header (§ 10.1)

### [BIBLE § 10.1] — Header missing "Archivio" title
- **File**: `lib/features/timeline/timeline_screen.dart:53-65`
- **Issue**: header jumps directly to the segmented control; no title is rendered.
- **Bible says**: `DM Serif Display 26 inchiostro` text "Archivio" with marginBottom 12, then segmented control.
- **Code does**: `Padding(...)` wraps `SegmentedControlMetra` only — there is no `Text("Archivio")` above it.
- **Fix**: prepend a `Text(l10n.archive_title)` with `MetraTypography.displayMd` (DM Serif Display 26, inchiostro) and a `SizedBox(height: 12)` before the segmented control.
- **Severity**: HIGH

### [BIBLE § 10.1] — Header padding wrong on all four sides
- **File**: `lib/features/timeline/timeline_screen.dart:54-59`
- **Issue**: padding uses `s4 / s4 / s4 / s2` (16 / 16 / 16 / 8).
- **Bible says**: `padding 12 / 24 / 14` (top 12, horizontal 24, bottom 14).
- **Code does**: top 16, left 16, right 16, bottom 8.
- **Fix**: `EdgeInsets.fromLTRB(24, 12, 24, 14)`.
- **Severity**: MEDIUM

### [BIBLE § 10.1] — Default segment is correct but stored value is title-cased
- **File**: `lib/features/timeline/timeline_screen.dart:29,39`
- **Issue**: enum is `_ViewMode { timeline, table }` (default `.timeline`). Storage key is fine, but rendered labels come from l10n strings already pre-capitalized ("Timeline" / "Tabella") rather than relying on CSS `text-transform: capitalize` — which is acceptable in Flutter (no equivalent), but worth noting that the lowercase-storage / capitalize-display contract is collapsed.
- **Bible says**: labels stored lowercase (`timeline`, `tabella`), displayed capitalized.
- **Code does**: stores enum, displays `l10n.timeline_view_toggle` = "Timeline" and `l10n.table_view_toggle` = "Tabella".
- **Fix**: no functional change required — Flutter has no `text-transform`, displaying pre-capitalized strings is the canonical Flutter mapping. Document this divergence inline.
- **Severity**: LOW

---

## Segmented control (§ 5.4) — shared widget

### [BIBLE § 5.4] — Track radius is `pill` (999) not 10
- **File**: `lib/core/widgets/segmented_control_metra.dart:59`
- **Issue**: `BorderRadius.circular(MetraRadius.pill)` = 999.
- **Bible says**: track radius 10.
- **Code does**: 999 (full pill).
- **Fix**: use `BorderRadius.circular(10)` (or add a token).
- **Severity**: HIGH (also violates § 15 anti-pattern 10: "no 999px pill radius")

### [BIBLE § 5.4] — Active segment radius is `pill` (999) not 8
- **File**: `lib/core/widgets/segmented_control_metra.dart:86`
- **Issue**: active segment uses `MetraRadius.pill`.
- **Bible says**: each segment radius 8.
- **Code does**: 999.
- **Fix**: `BorderRadius.circular(8)`.
- **Severity**: HIGH (anti-pattern 10)

### [BIBLE § 5.4] — Track padding is 2, missing inter-segment gap of 2
- **File**: `lib/core/widgets/segmented_control_metra.dart:61`
- **Issue**: `padding: const EdgeInsets.all(2)`; row has no `gap` between segments.
- **Bible says**: track padding 3, gap 2 between segments.
- **Code does**: padding 2, gap 0.
- **Fix**: `padding: EdgeInsets.all(3)`; insert a 2px `SizedBox(width: 2)` between segments (or use `Wrap(spacing: 2)` / Row + intersperse).
- **Severity**: MEDIUM

### [BIBLE § 5.4] — Segment height is 36, paddingInline is s4 (16)
- **File**: `lib/core/widgets/segmented_control_metra.dart:76-83`
- **Issue**: `minHeight: 36`, `padding.horizontal: s4` (16), `padding.vertical: s2` (8).
- **Bible says**: each segment `height 34, paddingInline 18`.
- **Code does**: 36 / 16.
- **Fix**: set `minHeight: 34`, `padding: EdgeInsets.symmetric(horizontal: 18, vertical: 0)` (let height drive vertical centering).
- **Severity**: MEDIUM

### [BIBLE § 5.4] — Active shadow has wrong blur radius
- **File**: `lib/core/widgets/segmented_control_metra.dart:88-97`
- **Issue**: `BoxShadow(blurRadius: 2, offset: Offset(0,1))`.
- **Bible says**: `0 1px 4px rgba(43,37,33,0.12)` — i.e. blur 4, offset (0,1), color `inchiostro 12%`.
- **Code does**: blur 2 (color is approximately right at `0x142B2521`).
- **Fix**: `blurRadius: 4`.
- **Severity**: LOW

### [BIBLE § 5.4] — Active label weight is 600, idle weight is 500
- **File**: `lib/core/widgets/segmented_control_metra.dart:100-105`
- **Issue**: active `FontWeight.w600`, idle `FontWeight.w500`.
- **Bible says**: active `weight 500 inchiostro`, idle `weight 400 rgba(0.5)`.
- **Code does**: active 600 / idle 500.
- **Fix**: active `w500`, idle `w400`.
- **Severity**: MEDIUM

### [BIBLE § 5.4] — Idle label color uses `textSecondary` token, not `rgba(0.5)`
- **File**: `lib/core/widgets/segmented_control_metra.dart:49-51,103`
- **Issue**: idle text uses `MetraColors.{light|dark}.textSecondary`.
- **Bible says**: idle label `rgba(43,37,33,0.5)` — inchiostro at 50% alpha.
- **Code does**: a token whose nominal value may be 60% / 65%.
- **Fix**: idle color should be `inchiostro.withOpacity(0.5)` — verify tokens, possibly add `textMuted50` or use raw alpha.
- **Severity**: LOW

---

## Scroll body (§ 10.2)

### [BIBLE § 10.2] — Scroll body has no padding-bottom of 90
- **File**: `lib/features/timeline/widgets/timeline_view.dart:34-39`, `lib/features/timeline/widgets/table_view.dart:51-52`
- **Issue**: timeline `ListView.separated` uses `EdgeInsets.all(s4)` (16); table `SingleChildScrollView` uses `EdgeInsets.all(s4)`. Neither reserves space for the 84-px tab bar.
- **Bible says**: `padding-bottom 90` on the scroll body to clear the 84-px tab bar.
- **Code does**: bottom padding 16; last card / row will sit under the tab bar.
- **Fix**: timeline `padding: EdgeInsets.fromLTRB(20, 4, 20, 90)`; table `padding: EdgeInsets.fromLTRB(20, 0, 20, 90)`.
- **Severity**: HIGH

---

## Timeline view (§ 10.3)

### [BIBLE § 10.3] — Timeline outer padding is `16` all sides, not `4/20`
- **File**: `lib/features/timeline/widgets/timeline_view.dart:35`
- **Issue**: `EdgeInsets.all(s4)` = 16 / 16 / 16 / 16.
- **Bible says**: `padding 4 / 20` (vertical 4, horizontal 20).
- **Code does**: 16 / 16.
- **Fix**: `EdgeInsets.symmetric(vertical: 4, horizontal: 20)` (combined with bottom-90 from the prior finding).
- **Severity**: MEDIUM

### [BIBLE § 10.3] — Timeline left rail (dot + connecting line) is missing entirely
- **File**: `lib/features/timeline/widgets/timeline_card.dart` (entire file)
- **Issue**: cards render as a flat list; no rail column, no terracotta dot, no vertical line linking entries.
- **Bible says**: each entry is a `row · gap 16 · alignItems stretch` with a 20-wide left rail containing a `12×12 radius 50%` terracotta dot (`marginTop 18`) and a `2px wide flex-1` line `bg rgba(43,37,33,0.10)` (`marginTop 2`, omitted on last entry).
- **Code does**: no rail; the card is the only child.
- **Fix**: rebuild card as `Row(children: [_TimelineRail(isLast), Expanded(child: _CardBody)])`. Pass `isLast` from `TimelineView` (`i == summaries.length - 1`).
- **Severity**: HIGH

### [BIBLE § 10.3] — Card content model is wrong (date range + status badge + duration bar instead of month/Durata header + footer)
- **File**: `lib/features/timeline/widgets/timeline_card.dart:111-176`
- **Issue**: card renders (a) a header row with date range "1 Apr – 28 Apr" + a pill-shaped "28 g" / "In corso" badge, then (b) a proportional 8-px terracotta progress bar against a `_kBarMaxDays = 35` track. None of this is in § 10.3.
- **Bible says**: card content top→bottom is (1) row space-between baseline marginBottom 6 with `DM Serif Display 17 inchiostro` month label (e.g. "Apr 2025") and `Inter 12 rgba(0.40)` "Durata Ng"; (2) wrap of mini-pills; (3) footer `Inter 12 rgba(0.40) marginTop 8` "Ciclo Xg · dal Y".
- **Code does**: see timeline_card.dart:118-176 — completely different layout, including the proportional bar (lines 153-176) and the `_kBarMaxDays` constant (line 35) which has no bible counterpart.
- **Fix**: rewrite `_CardBody` per § 10.3; remove progress bar, status badge, `_kBarMaxDays`. Format month label with `DateFormat.yMMM('it')`; "Durata Ng" uses `cycle.periodLength`; footer uses `cycle.cycleLength` and `DateFormat.d('it')`.
- **Severity**: HIGH

### [BIBLE § 10.3] — Card border-radius is 12 (md), bible says 14
- **File**: `lib/features/timeline/widgets/timeline_card.dart:102,106`
- **Issue**: `BorderRadius.circular(MetraRadius.md)` = 12.
- **Bible says**: card radius 14.
- **Code does**: 12.
- **Fix**: `BorderRadius.circular(14)` (or add `MetraRadius.lg = 14` token — current `lg = 16`, so a new alias like `card` may be cleanest).
- **Severity**: MEDIUM

### [BIBLE § 10.3] — Card padding is `16` all sides, not `14/16`
- **File**: `lib/features/timeline/widgets/timeline_card.dart:112`
- **Issue**: `EdgeInsets.all(MetraSpacing.s4)` = 16 all sides.
- **Bible says**: padding `14 / 16` (vertical 14, horizontal 16).
- **Code does**: 16 / 16.
- **Fix**: `EdgeInsets.symmetric(vertical: 14, horizontal: 16)`.
- **Severity**: MEDIUM

### [BIBLE § 10.3] — Card marginBottom is `s2` (8), bible says 12
- **File**: `lib/features/timeline/widgets/timeline_view.dart:37`
- **Issue**: `separatorBuilder` returns `SizedBox(height: s2)` = 8.
- **Bible says**: card marginBottom 12.
- **Code does**: 8.
- **Fix**: `SizedBox(height: 12)`.
- **Severity**: LOW

### [BIBLE § 10.3 / § 15-9] — Card is interactive (`InkWell` + `context.push('/daily-entry/...')`); bible says display-only
- **File**: `lib/features/timeline/widgets/timeline_card.dart:105-110`
- **Issue**: each archive card is a tappable `InkWell` that navigates to the daily-entry editor.
- **Bible says**: § 15 anti-pattern 9 — "No swipe-to-archive / long-press menus on archive cards. Cards are display-only in this bible." § 10.3 also has no tap target description.
- **Code does**: full-card tap navigation.
- **Fix**: remove the `InkWell` wrapper; archive cards are read-only. (If the parent app needs an editor entry point, add a discrete navigation outside the card.)
- **Severity**: HIGH

### [BIBLE § 10.3 / AR-01] — Pain pill is missing from the chip row
- **File**: `lib/features/timeline/widgets/timeline_card.dart:178-225`, `lib/domain/entities/cycle_summary.dart:23-38`
- **Issue**: only flow chip and symptom chips render; no pain pill.
- **Bible says**: when `pain > 0`, render a pain pill bg `rgba(158,116,136,0.12)`, `DataIcon zap 11 malva`, label `Inter 11 malva` from `["", "Lieve", "Moderato", "Intenso"]`. AR-01 lists pain explicitly as part of the unified chip vocabulary.
- **Code does**: no pain field exists on `CycleSummary` (entity exposes only `cycle`, `symptoms`, `dominantFlow`); chip row never instantiates a pain pill.
- **Fix**: (1) extend `CycleSummary` with `int? dominantPainIntensity` (or `maxPain`) and update `getCycleSummariesProvider` use-case to compute it from per-day entries; (2) add `_TimelinePainChip` widget; (3) render between flow and symptoms when `pain != null && pain > 0`.
- **Severity**: HIGH (data-layer change required)

### [BIBLE § 10.3 / AR-01] — Symptom chip uses `Icons.star_border` (outlined), bible says `star_small` filled
- **File**: `lib/features/timeline/widgets/timeline_card.dart:210`
- **Issue**: `icon: Icons.star_border` (outlined, hollow center).
- **Bible says**: AR-01 — `star_small` filled, color ocra. The unified vocabulary requires filled glyphs.
- **Code does**: outlined star.
- **Fix**: use `Icons.star` (filled) at 11dp; long-term, expose a `DataIcon` widget and use the `star_small` token.
- **Severity**: MEDIUM

### [BIBLE § 10.3 / AR-01] — Flow chip icon color uses `accentFlowStrong` token (verify `tc_scura` mapping)
- **File**: `lib/features/timeline/widgets/timeline_card.dart:198-202`
- **Issue**: icon color `MetraColors.{light|dark}.accentFlowStrong`.
- **Bible says**: flow icon and label both `tc_scura` (terracotta dark).
- **Code does**: `accentFlowStrong` — likely correct semantically; verify it resolves to the same hex as `tc_scura`.
- **Fix**: confirm token mapping; if mismatch, retarget to the canonical `tc_scura` token.
- **Severity**: LOW (verification)

### [BIBLE § 10.3 / AR-01] — Flow chip background is 8% alpha, bible says 15 (`${terracotta}15`)
- **File**: `lib/features/timeline/widgets/timeline_card.dart:203-206`
- **Issue**: `accentFlow.withValues(alpha: 0.08)`.
- **Bible says**: bg `${terracotta}15` — i.e. terracotta at hex alpha 15 ≈ 8.2% (`0x15 / 0xFF`). Wait — `${terracotta}15` is the `RRGGBB + 15` 8-digit hex pattern, where `15` = 0x15 alpha = 21/255 ≈ 0.082. 8% ≈ 0.08, which matches.
- **Code does**: 0.08 ≈ correct.
- **Fix**: change to exact `0x15 / 0xFF ≈ 0.0824` (`Color.fromARGB(0x15, ...)`); cosmetic.
- **Severity**: LOW

### [BIBLE § 10.3] — Symptom chip background is 10% alpha, bible says 18 (`${ocra}18`)
- **File**: `lib/features/timeline/widgets/timeline_card.dart:215-218`
- **Issue**: `accentWarmth.withValues(alpha: 0.10)`.
- **Bible says**: `${ocra}18` = ocra with hex alpha 18 ≈ 9.4% — actually 0x18/0xFF = 0.094.
- **Code does**: 0.10 (vs 0.094 bible). Within 1% — minor.
- **Fix**: `Color.fromARGB(0x18, ...)` if exactness matters.
- **Severity**: LOW

### [BIBLE § 10.3] — Chip text color uses `textSecondary` for both flow and symptom; bible differentiates
- **File**: `lib/features/timeline/widgets/timeline_card.dart:284-303`
- **Issue**: `_TimelineChip` always uses `textSecondary` for the label, regardless of chip type.
- **Bible says**: flow label `Inter 11 tc_scura`, pain label `Inter 11 malva`, symptom label `Inter 11 rgba(43,37,33,0.60)`.
- **Code does**: every label is `textSecondary` (likely close to rgba 0.60, but flow should be `tc_scura`, not secondary).
- **Fix**: thread a `labelColor` parameter through `_TimelineChip`; pass `tc_scura` for flow, `malva` for pain, `rgba(0.60)` for symptoms.
- **Severity**: MEDIUM

### [BIBLE § 10.3] — Chip padding is 8/4, bible specifies height 24 + paddingInline (implicit)
- **File**: `lib/features/timeline/widgets/timeline_card.dart:289`
- **Issue**: `padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4)`. Total height ≈ 8 + ~14 (Inter 11 line) + 8 ≈ 22-23.
- **Bible says**: mini-pill height 24, radius 6.
- **Code does**: radius is 6 (correct); height not explicitly constrained.
- **Fix**: wrap chip in `SizedBox(height: 24)` or set explicit padding to hit 24px including the 11px text.
- **Severity**: LOW

### [BIBLE § 10.3] — Chip wrap spacing is `s2` (8), correct, but row spacing should be 8 between chips horizontally and unspecified vertically
- **File**: `lib/features/timeline/widgets/timeline_card.dart:193-194`
- **Issue**: `Wrap(spacing: s2, runSpacing: s2)` — 8 / 8.
- **Bible says**: `row wrap gap 8` — single gap of 8 in both axes acceptable.
- **Code does**: matches.
- **Fix**: no change.
- **Severity**: clean

### [BIBLE § 10.3] — Footer "Ciclo Xg · dal Y" is absent
- **File**: `lib/features/timeline/widgets/timeline_card.dart:111-228`
- **Issue**: card has no footer line.
- **Bible says**: third row (after chips) is `Inter 12 rgba(0.40) marginTop 8` reading `"Ciclo {len}g · dal {day}"`.
- **Code does**: no footer; the cycle length is encoded in the top-right badge instead.
- **Fix**: add a footer `Text("Ciclo ${cycle.cycleLength}g · dal ${day}", style: Inter 12 inchiostro/40%)` with `marginTop: 8`. Add l10n string `archive_card_footer`.
- **Severity**: HIGH

---

## Tabella view (§ 10.4)

### [BIBLE § 10.4] — Column set wrong: code is `Inizio | Ciclo | Mestr. | Sintomi`, bible is `Mese | Ciclo | Dur. | Flusso`
- **File**: `lib/features/timeline/widgets/table_view.dart:60-85`, `lib/l10n/app_it.arb:510-520`
- **Issue**: code defines four columns whose semantics partially overlap with the bible but the labels and the last column are different.
- **Bible says**: header labels are `"Mese", "Ciclo", "Dur.", "Flusso"`; the fourth column is dominant flow text, not symptoms.
- **Code does**: `table_col_start = "Inizio"`, `table_col_period = "Mestr."`, `table_col_symptoms = "Sintomi"`. The "Sintomi" column has no bible counterpart; "Flusso" column is missing entirely.
- **Fix**: (1) rename l10n keys: `table_col_start → table_col_month` ("Mese"), `table_col_period → table_col_duration` ("Dur."), drop `table_col_symptoms`, add `table_col_flow` ("Flusso"). Mark the old keys deprecated until all references migrate. (2) change month cell to `DateFormat.yMMM('it')` rendering of `cycle.startDate`. (3) add a `flowLabel(s.dominantFlow)` cell.
- **Severity**: HIGH

### [BIBLE § 10.4] — Grid widths wrong: code uses `2:1:1:2` flex, bible specifies `1fr 60px 50px 80px`
- **File**: `lib/features/timeline/widgets/table_view.dart:54-59`
- **Issue**: `columnWidths: {0: FlexColumnWidth(2), 1: FlexColumnWidth(1), 2: FlexColumnWidth(1), 3: FlexColumnWidth(2)}`.
- **Bible says**: `grid "1fr 60px 50px 80px" gap 8` — col 0 flexes, cols 1-3 are fixed widths.
- **Code does**: all four flex.
- **Fix**: `columnWidths: {0: FlexColumnWidth(1), 1: FixedColumnWidth(60), 2: FixedColumnWidth(50), 3: FixedColumnWidth(80)}`.
- **Severity**: MEDIUM

### [BIBLE § 10.4] — Header has no background, no radius, no padding, no marginBottom
- **File**: `lib/features/timeline/widgets/table_view.dart:61-85`
- **Issue**: header row is a bare `TableRow` with cells in `Padding(EdgeInsets.symmetric(vertical: s2))` only.
- **Bible says**: header `bg rgba(43,37,33,0.05) · radius 10 · padding 10 / 12 · marginBottom 6`.
- **Code does**: no background, no radius, no horizontal padding, no marginBottom.
- **Fix**: replace `Table` with a custom layout (`Column` of `Row` widgets, each with its own decoration) — `Table` does not support per-row decoration. Header `Row` with `Container(decoration: BoxDecoration(color: inchiostro.withOpacity(0.05), borderRadius: BorderRadius.circular(10)), padding: EdgeInsets.symmetric(vertical: 10, horizontal: 12), child: Row(...))` and `SizedBox(height: 6)` after.
- **Severity**: HIGH

### [BIBLE § 10.4] — Header text style: missing letter-spacing 0.04em, weight should be 600 ✓ but font size is wrong
- **File**: `lib/features/timeline/widgets/table_view.dart:39-44`
- **Issue**: header style is `MetraTypography.caption.copyWith(... fontWeight: w600)`. No letter-spacing override; size depends on `caption` token (likely 12).
- **Bible says**: `Inter 11 weight 600 rgba(0.68) letter-spacing 0.04em`.
- **Code does**: weight 600 ✓; size and letter-spacing unverified / absent; color uses `textSecondary` (likely 0.6 not 0.68).
- **Fix**: explicit `TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: w600, letterSpacing: 0.44 /* 0.04em × 11 */, color: inchiostro.withOpacity(0.68))`.
- **Severity**: MEDIUM

### [BIBLE § 10.4] — Rows have no surface background, no border, no radius, no marginBottom
- **File**: `lib/features/timeline/widgets/table_view.dart:86-115`
- **Issue**: data rows are bare `TableRow` cells with `Padding(EdgeInsets.symmetric(vertical: s3))` only.
- **Bible says**: rows `bg surface · radius 12 · padding 14 / 12 · marginBottom 4 · border 1px solid rgba(43,37,33,0.06)`.
- **Code does**: no decoration whatsoever.
- **Fix**: rebuild each row as `Container(margin: EdgeInsets.only(bottom: 4), padding: EdgeInsets.symmetric(vertical: 14, horizontal: 12), decoration: BoxDecoration(color: bgSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: inchiostro.withOpacity(0.06))), child: Row(...))`. Will require abandoning the `Table` widget.
- **Severity**: HIGH

### [BIBLE § 10.4] — Cell text styles wrong (size, color)
- **File**: `lib/features/timeline/widgets/table_view.dart:45-49,99-114`
- **Issue**: all four cells use the same `cellStyle` (Inter ~14, primary text).
- **Bible says**: per-cell typography:
  - Mese: `Inter 14 inchiostro` (matches)
  - Ciclo: `Inter 14 rgba(43,37,33,0.6)` suffixed `g`
  - Dur.: `Inter 14 rgba(43,37,33,0.6)` suffixed `g`
  - Flusso: `Inter 13 tc_scura`
- **Code does**: every cell uses primary text colour and size 14. Cycle/period rows do append `g` (`'${...} g'`).
- **Fix**: differentiate styles per column; ciclo/dur use 60% opacity; flusso uses 13pt with `tc_scura`.
- **Severity**: MEDIUM

### [BIBLE § 10.4] — Tabella outer padding is `s4` (16) all sides, bible says `0 / 20`
- **File**: `lib/features/timeline/widgets/table_view.dart:52`
- **Issue**: `padding: EdgeInsets.all(s4)`.
- **Bible says**: `padding 0 / 20` (vertical 0, horizontal 20).
- **Code does**: 16 all.
- **Fix**: `EdgeInsets.fromLTRB(20, 0, 20, 90)` (combining with bottom-90 from § 10.2).
- **Severity**: MEDIUM

### [BIBLE § 10.4] — Sintomi column needs to be removed; "Mese" cell currently shows "d MMM" (e.g. "1 apr"), bible expects "Mese" (e.g. "Apr 2025")
- **File**: `lib/features/timeline/widgets/table_view.dart:87-89`
- **Issue**: `intl.DateFormat('d MMM', 'it')` produces "1 apr".
- **Bible says**: column label is "Mese" — implies "Apr 2025" (month + year), aligning with the timeline-card month label per § 10.3 sample fixtures.
- **Code does**: "1 apr".
- **Fix**: `intl.DateFormat.yMMM('it')` → "apr 2025"; capitalize first letter to match mock ("Apr 2025").
- **Severity**: MEDIUM

### [BIBLE § 10.5] — Sample fixture not used for visual QA / golden tests
- **File**: (missing) `test/features/timeline/`
- **Issue**: no golden test seeded with the § 10.5 fixture (Apr/Mar/Feb/Gen/Dic 2025 sample rows).
- **Bible says**: § 10.5 provides a 5-row sample for visual QA.
- **Code does**: no fixture-based test exists.
- **Fix**: add a golden test that builds the screen with the bible's exact sample and asserts the rendered output matches the mockup.
- **Severity**: LOW

---

## L10n vocabulary (§ 14)

### [BIBLE § 14] — Missing l10n key for screen title "Archivio"
- **File**: `lib/l10n/app_it.arb` (no `archive_title` / `timeline_title` key)
- **Issue**: the screen title "Archivio" is not in the ARB; `timeline_screen.dart` does not display a title at all (see § 10.1 finding above).
- **Bible says**: § 14 — "Archive | Archivio | Tab + screen title."
- **Code does**: no key.
- **Fix**: add `"archive_title": "Archivio"` (and `app_en.arb` mirror "Archive").
- **Severity**: HIGH

### [BIBLE § 14] — Tabella column key naming + values misaligned with bible
- **File**: `lib/l10n/app_it.arb:510-520`
- **Issue**: keys `table_col_start = "Inizio"`, `table_col_period = "Mestr."`, `table_col_symptoms = "Sintomi"`. None of these strings appears in § 14 / § 10.4.
- **Bible says**: header labels are `"Mese", "Ciclo", "Dur.", "Flusso"`.
- **Code does**: only "Ciclo" matches; the other three are wrong strings.
- **Fix**: rename / repurpose keys to `table_col_month = "Mese"`, `table_col_cycle = "Ciclo"` (unchanged), `table_col_duration = "Dur."`, `table_col_flow = "Flusso"`. Update both `app_it.arb` and `app_en.arb`. Migrate references in `table_view.dart`.
- **Severity**: HIGH

### [BIBLE § 14 / § 10.3] — Missing l10n strings for "Durata Ng" header line and "Ciclo Xg · dal Y" footer
- **File**: `lib/l10n/app_it.arb`
- **Issue**: no plurals/format keys for `archive_card_duration_days` ("Durata {n}g") or `archive_card_footer` ("Ciclo {len}g · dal {day}"). The closest existing key is `timeline_cycle_length_days` ("{n} g") used by the now-incorrect status badge.
- **Bible says**: § 10.3 prescribes both strings on the timeline card.
- **Code does**: keys absent.
- **Fix**: add `archive_card_duration_days` and `archive_card_footer` (Italian primary, English mirror).
- **Severity**: MEDIUM

### [BIBLE § 14 / § 10.3] — Pain-pill labels need an array `["", "Lieve", "Moderato", "Intenso"]`
- **File**: `lib/l10n/app_it.arb` (no archive-specific pain labels), `daily_entry_pain_label_*` exist but cover different copy
- **Issue**: pain pill text per bible is indexed `["", "Lieve", "Moderato", "Intenso"]`; need a centralized lookup. Existing `daily_entry_pain_label_lieve / moderato / intenso` may suffice if reused.
- **Bible says**: § 10.3 — pain label `Inter 11 malva` from `["", "Lieve", "Moderato", "Intenso"]`.
- **Code does**: no archive consumer of pain labels (chip not implemented).
- **Fix**: when adding the pain pill, reuse `daily_entry_pain_label_*` strings (verify exact text match) or add `archive_pain_label_{1,2,3}` aliases.
- **Severity**: MEDIUM

### [BIBLE § 14] — Existing key `timeline_cycle_in_progress` ("In corso") and `timeline_cycle_length_days` ("{n} g") are bible-orphans
- **File**: `lib/l10n/app_it.arb:479-490`
- **Issue**: both keys feed the bible-absent status badge.
- **Bible says**: no "In corso" badge anywhere in § 10.
- **Code does**: keys are referenced from `timeline_card.dart:79-80`.
- **Fix**: after rebuild, mark these keys deprecated and remove references; they do not appear in the bible.
- **Severity**: LOW

---

## Anti-patterns (§ 15)

### [BIBLE § 15-9] — Card tap navigation
- **File**: `lib/features/timeline/widgets/timeline_card.dart:105-110`
- **Issue**: `InkWell` + `context.push('/daily-entry/$dateKey')` makes the card a navigation surface.
- **Bible says**: § 15 anti-pattern 9 — archive cards are display-only.
- **Code does**: full-card tap.
- **Fix**: remove `InkWell` (already covered by HIGH finding above); duplicated here for the anti-pattern register.
- **Severity**: HIGH (duplicate)

### [BIBLE § 15-10] — `MetraRadius.pill` (999) on segmented control track and segments
- **File**: `lib/core/widgets/segmented_control_metra.dart:59,86`
- **Issue**: 999-radius pill on both the track and active segment.
- **Bible says**: § 15 anti-pattern 10 — "No 999px pill radius."
- **Code does**: 999.
- **Fix**: 10 / 8 (covered above); duplicated here for the anti-pattern register.
- **Severity**: HIGH (duplicate)

### [BIBLE § 15-3] — Drop shadow on the card?
- **File**: `lib/features/timeline/widgets/timeline_card.dart:98-103`
- **Issue**: `Card(elevation: 0)` — no shadow. ✓
- **Bible says**: § 15 anti-pattern 3 — no drop shadows on cards/sheets.
- **Code does**: clean.
- **Fix**: no change.
- **Severity**: clean

### [BIBLE § 15] — No swipe-to-dismiss / long-press menus
- **File**: `lib/features/timeline/widgets/timeline_view.dart`, `timeline_card.dart`
- **Issue**: not present (no `Dismissible`, no `GestureDetector(onLongPress:)`).
- **Bible says**: § 15-9 forbids them.
- **Code does**: clean.
- **Fix**: no change. Maintain this discipline through the rebuild.
- **Severity**: clean

---

## Cross-cutting / data-layer

### [BIBLE § 10.3] — `CycleSummary` entity lacks pain aggregate
- **File**: `lib/domain/entities/cycle_summary.dart:23-38`, downstream `lib/providers/use_case_providers.dart` and the `GetCycleSummaries` use-case.
- **Issue**: entity exposes only `cycle`, `symptoms`, `dominantFlow`. No aggregate for pain — yet § 10.3 requires a per-cycle pain pill (`pain > 0`).
- **Bible says**: pain pill rendered when `pain > 0`, label keyed by ordinal 1/2/3.
- **Code does**: no pain field.
- **Fix**: add `int? maxPain` (or `dominantPain`) to `CycleSummary`; update use-case and any test fixtures; thread into `TimelineCard`.
- **Severity**: HIGH

### [BIBLE § 10.4] — `Table` widget cannot meet the per-row decoration / margin requirement
- **File**: `lib/features/timeline/widgets/table_view.dart:53-117`
- **Issue**: Flutter's `Table` widget does not support per-row backgrounds, borders, radius, or marginBottom — bible requires all four on every row.
- **Bible says**: § 10.4 spec.
- **Code does**: uses `Table`.
- **Fix**: replace `Table` with a `Column` of decorated `Row`s (header + data); use a shared layout function so the column widths stay aligned.
- **Severity**: MEDIUM (architectural)
