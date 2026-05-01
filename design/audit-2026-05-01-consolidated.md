# Métra — DESIGN-BIBLE Conformance Audit (Consolidated)

**Date:** 2026-05-01
**Source of truth:** `design/DESIGN-BIBLE.md` (canonical) + `design/Métra Screens Light.html` (super-canon)
**Scope:** Foundation tokens, Calendar, Today/Daily entry, Archivio, Statistiche, Onboarding, Tab bar, Primary CTAs.
**Method:** 6 parallel read-only audit agents, one per area. Each produced a per-finding file; this document consolidates and prioritises.

## Per-area detail files

| Area | File | HIGH | MEDIUM | LOW |
|---|---|---:|---:|---:|
| Foundation tokens | `audit-findings-foundation.md` | 9 | 14 | 7 |
| Calendar | `audit-findings-calendar.md` | 11 | 8 | 4 |
| Today / Daily entry | `audit-findings-daily-entry.md` | 11 | 9 | 5 |
| Archivio | `audit-findings-archive.md` | 12 | 11 | 4 |
| Statistiche | `audit-findings-statistics.md` | 14 | 5 | 3 |
| Onboarding + Tab bar + CTAs | `audit-findings-onboarding-nav.md` | 9 | 11 | 3 |
| **Total** | — | **66** | **58** | **26** |

≈ **150 deviations** between the implementation and the bible. Three areas are not pixel-tweak situations — Archivio, Statistiche, and the tab bar require **rebuilds**, not edits.

---

## 1 · Cross-cutting blockers (fix these first — they touch every screen)

These are foundation-layer breaks. Every per-screen fix below depends on these landing first.

### 1.1 Missing icon system (HIGH, blocks ≥7 surfaces)
- **File:** Material `Icons.*` used everywhere; no `MetraIcon` widget exists.
- **Impact:** Tab bar icons, calendar legend, calendar indicator dots (5×5 colored circles instead of typed icons), pain pickers (`Icons.bolt` instead of `zap`), edit-day CTA (`Icons.edit_outlined` instead of `note`), moon phase (Material crescent instead of phased moon), every chart icon.
- **Bible:** § 2.1 + § 2.2 — fixed catalog of 22 stroke icons + 5 filled DataIcons (`drop, drop_outline, moon_crescent, star_small, zap`), explicit SVG paths in HTML lines 124–182, `stroke-width 1.5/2/1.4/1.8` per icon.
- **Fix:** Build `MetraIcon` widget rendering bible SVGs via `flutter_svg` or `CustomPainter`, expose `MetraIcons.{drop,dropOutline,moonCrescent,starSmall,zap,wave,note,calendar,...}` constants, replace every `Icons.*` consumer.

### 1.2 `MetraRadius.pill = 999` violates anti-pattern §15¶10 (HIGH, blocks chips/segmented control)
- **File:** `lib/core/theme/metra_spacing.dart:37`
- **Impact:** Used in `choice_chip_metra.dart:75`, `segmented_control_metra.dart:59,86`, `historical_entry_screen.dart:593–603`, `timeline_card.dart:138,159,169`. Bible: *"Never use 999px. Chip pill rule: radius = ½ × height."*
- **Fix:** Delete `pill`; per consumer use `radius = height ÷ 2` (chip 36 → 18, segmented track → 10, segment → 8).

### 1.3 Tab bar uses Material 3 `NavigationBar` defaults (HIGH)
- **File:** `lib/router/app_router.dart:154`
- **Impact:** Wrong height (Material default 80 vs spec 84), no `BackdropFilter blur(16)`, ships an animated indicator pill (anti-pattern), wrong icon strokes/labels/typography. Bible § 4 + § 1.7.
- **Fix:** Replace with custom `Container(height:84) + BackdropFilter(ImageFilter.blur(16,16)) + ColoredBox(sabbia.withAlpha(0xF5))` and 5 `GestureDetector` tabs. Disable Material indicator entirely.

### 1.4 Off-catalog colours shipped (HIGH)
- **File:** `lib/core/theme/metra_colors.dart`
- **Impact:** 6 invented primitives (`inkSoft, divider #DCD2C0, surfaceSunken, dustyOchreDeep, mossDeep, textDisabled`) used widely. Two existing tokens drift from the bible hex: `surfaceRaised = #FBF6EC` (bible: `#FAF5EE`); `terracottaDeep = #9B4E32` (bible: `#9A4D32`).
- **Bible:** § 1.1 — *"only colors that may appear in the product"* are 10 named tokens. Translucency must be derived via documented alpha stops.
- **Fix:** Correct the two hexes; delete invented primitives; replace usages (e.g. `divider` → `inchiostro.withAlpha(0x12)`, `inkSoft` → `inchiostro.withAlpha(0x68)`/`0xAD`).

### 1.5 Typography role/size table missing (HIGH)
- **File:** `lib/core/theme/metra_typography.dart`
- **Impact:** No tokens for sizes **56, 34, 30, 28, 17, 15, 11, 10**; multiple screens use the wrong nearest neighbour (e.g. Manifesto headline at 32 vs spec 34, Today title at 32 vs spec 26, Calendar header at 32 vs spec 26, Day-detail card title at 22 vs spec 20, Primo Ciclo headline at 32 vs spec 28). `titleSm` (20) currently uses Inter w600 — bible says DM Serif Display 400. Line-heights and letter-spacings are uniform formulas instead of per-role.
- **Fix:** Replace abstract scale with role-named tokens matching § 1.2 verbatim (`displayHero=56, headlineLg=34, headlineMd=30, headlineSm=28, dayDetailTitle=20, archiveMonth=17, listTitle=15, ...`) and bible-correct line-heights/letter-spacings.

### 1.6 Raw `fontFamily: 'Inter'` strings bypass `google_fonts` (HIGH)
- **File:** `calendar_day.dart:118`, `metra_theme.dart:83/90/158/165`, plus several inline styles in onboarding/calendar/etc.
- **Impact:** Inter is loaded only via `GoogleFonts.inter(...)`; passing `fontFamily: 'Inter'` falls back to the platform sans-serif. Day numbers in the calendar render in a different typeface from the rest of the app.
- **Fix:** Replace every `fontFamily: 'Inter'` site with `GoogleFonts.inter(...).copyWith(...)`.

### 1.7 Spacing scale missing 16 of 25 anchors; ships off-scale `40` and `64` (HIGH)
- **File:** `lib/core/theme/metra_spacing.dart`
- **Impact:** Forces consumers to either hardcode literals or use the wrong value. Bible: full enumerated scale `0·2·3·4·5·6·7·8·10·12·14·16·18·20·24·28·32·36·44·48·56·72·84·90·100`.
- **Fix:** Replace `MetraSpacing` with the canonical scale. Remove 40 and 64.

### 1.8 Card-edge / divider painted opaque, not translucent (HIGH)
- **File:** `metra_theme.dart:56,67,132,143` and several widget call sites use `colors.divider = #DCD2C0` opaque.
- **Bible:** § 1.5 — `1px solid rgba(43,37,33,0.07)` (translucent ink).
- **Fix:** Use `inchiostro.withAlpha(0x12)` (= 0.07).

### 1.9 Segmented-control shadow blur wrong (HIGH)
- **File:** `metra_theme.dart:47`, `segmented_control_metra.dart:88-97`
- **Impact:** `blurRadius: 2` and color `0x142B2521` (≈ 0.078 alpha). Bible § 1.6: *the* product shadow is `0 1px 4px rgba(43,37,33,0.12)` — i.e. blur **4**, alpha **0x1F**.
- **Fix:** `BoxShadow(offset: Offset(0,1), blurRadius: 4, color: Color(0x1F2B2521))`.

---

## 2 · Per-screen HIGH-severity items

### 2.1 Calendar (`audit-findings-calendar.md`)

1. **Indicator dots are 5×5 colored circles**, not typed icons. Predicted day uses solid lavanda dot instead of CL-01 hollow `drop_outline`. **`hasSymptom` indicator is entirely missing** (`star_small ocra` never rendered) even though `painSymptomsProvider` is wired. → `calendar_day.dart:91-94, 219-234`
2. **Symptom chips** in the day-detail card render as solid terracotta pills (radius 20, no border) — bible: `bg ${ocra}18, border 1px ${ocra}55, radius 8, height 28, text Inter 12 tc_scura`. → `calendar_screen.dart:507-533`
3. **Day-detail card lacks the "Giorno N del ciclo" sub-row** — l10n key exists but never used. → `calendar_screen.dart:386-404`
4. **Edit-day CTA** uses `Icons.edit_outlined` + `body 16` + inchiostro — bible: `note 16 terracotta + Inter 14 w500 tc_scura`. → `calendar_screen.dart:442-450`
5. **Header title** uses `displayMd` (32) instead of 26. → `month_navigator.dart:81`
6. **Day-number font** uses unregistered `fontFamily: 'Inter'` → falls back to platform sans. → `calendar_day.dart:118`
7. **Legend ordering wrong** — Previsione is in slot 2; should be last (CL-01 explicitly). → `calendar_legend.dart:57-84`
8. **Day-headers row** wrong padding and typography (caption 13 instead of Inter 12 letter-spacing 0.04em). → `calendar_screen.dart:181, 188-191`
9. **Grid horizontal padding 8**, spec 12. **Row gap 2 not configured.** → `calendar_screen.dart:277-284`
10. **Day-detail card not `flex 1`** — grid expands instead, inverting the spec. → `calendar_screen.dart:117-158`
11. **Flow pill geometry** — symmetric padding `12/6` instead of fixed height 32 + paddingInline 12 + radius 10. → `calendar_screen.dart:489-504`

### 2.2 Today / Daily entry (`audit-findings-daily-entry.md`)

1. **Section frame structure missing**: sections render flat with `Divider`s instead of `bg surface + 1px borders + 18/24 padding + gap 1`. → `today_screen.dart:236-415`
2. **Title** uses `displayMd` (32) instead of 26 (`titleLg`). → `today_screen.dart:228-233`
3. **Header padding wrong**: `12/24/16` per spec; code is `s6/s6` (24/24). → `today_screen.dart:214-220`
4. **Screen container missing `padding-bottom: 100`** — save CTA pinned outside scroll instead of overlaying. → `today_screen.dart:213`
5. **Choice chip uses `pill = 999`** + padding `16/8` instead of `height 36 / paddingInline 14 / radius 18`. → `choice_chip_metra.dart:60-82`
6. **Inline "Aggiungi" affordance off-spec** — single Text label instead of separate `+` glyph + label; editing border is grey instead of `1.5px terracotta + ${terracotta}0D` fill; OK is grey TextButton instead of terracotta filled pill. → `today_screen.dart:467-545`
7. **Symptom row missing 44dp tap-target wrapper** (UX-03). → `today_screen.dart:315-374`
8. **Flow & Pain dots** SVG geometry off (outer 46/48 box vs spec 50; missing terracotta/malva 1.4–1.5 stroke on filled circles). → `flow_intensity_dots.dart:126-152`, `circle_pain_picker.dart:107-133`
9. **Pain "Nessuno"** uses sand fill + `Colors.black26` border instead of malva-stroked transparent. → `circle_pain_picker.dart:66`
10. **Spotting hint has zero box styling** (plain `Text`); spec mandates filled bordered box `${terracotta}0D` / `${terracotta}28`. → `today_screen.dart:267-275`
11. **Notes textarea** has no border (focus-only), wrong fill, padding 16/16 instead of 12/14, hint at Inter 16 instead of 15. → `today_screen.dart:387-413`
12. **Save CTA**: height 52 (spec 56), padding `0/24/16` (spec `20/24/0`), missing radius 16, icon size 20 (spec 18). → `today_screen.dart:430-431`
13. **`today_notes_hint` ARB uses ASCII `...`** — bible § 13 mandates the U+2026 `…`. → `app_it.arb:923`

### 2.3 Archivio (`audit-findings-archive.md`) — **REBUILD REQUIRED**

The current `lib/features/timeline/` predates § 10 and ships a different visual model entirely (date-range header + proportional duration bar + "In corso" status badge — none in the bible).

1. **Header has no "Archivio" title** at all. → `timeline_screen.dart:53-65`
2. **Timeline left rail (terracotta dot + connecting line) is missing entirely** — foundational visual of § 10.3. → `timeline_card.dart`
3. **Card content model wrong end-to-end**: no month label, no "Durata Ng", no footer "Ciclo Xg · dal Y". Uses date-range "1 Apr – 28 Apr" + status pill + proportional bar against `_kBarMaxDays = 35`.
4. **Pain pill not rendered, and `CycleSummary` doesn't carry a pain aggregate** — fix requires a domain-entity change. → `cycle_summary.dart:23-38`
5. **Cards are interactive (`InkWell` + nav)** — explicitly forbidden by § 15 anti-pattern 9. → `timeline_card.dart:105-110`
6. **Tabella columns wrong**: code `Inizio | Ciclo | Mestr. | Sintomi`; bible `Mese | Ciclo | Dur. | Flusso`. "Sintomi" column doesn't exist; "Flusso" missing. → `table_view.dart:60-85` + ARB
7. **Tabella `Table` widget cannot deliver per-row backgrounds/borders/radius/margins** — needs to become decorated `Row`s. → `table_view.dart:53-117`
8. **Shared `SegmentedControlMetra` violates § 5.4**: `pill` track + `pill` segments (also anti-pattern §15¶10), padding 2 instead of 3, no inter-segment gap, blur 2 vs spec 4, active w600/idle w500 vs spec w500/w400. Affects every screen using it. → `segmented_control_metra.dart`
9. **Scroll body has no `padding-bottom: 90`** — last card sits under tab bar. → `timeline_view.dart`, `table_view.dart`
10. **Symptom chip uses `Icons.star_border` (outlined)**; AR-01 mandates filled `star_small`. → `timeline_card.dart:210`
11. **Missing l10n keys**: `archive_title`, `archive_card_duration_days`, `archive_card_footer`, plus rename of `table_col_*`. → `app_it.arb`
12. **Timeline card border-radius 12 (md), spec 14**; padding `16/16` instead of `14/16`. → `timeline_card.dart:102-112`

### 2.4 Statistiche (`audit-findings-statistics.md`) — **REBUILD REQUIRED**

The screen is structurally divergent. Bible specifies header + 2×2 scalar summary grid + two MiniBar charts + symptom-frequency card; code ships four generic `StatCard`s wrapping `fl_chart` line/bar widgets.

1. **Header (§11.1) entirely missing** — no "Statistiche" title or "Ultimi 6 cicli" subtitle. → `stats_screen.dart:40-97`
2. **2×2 StatCard summary grid not implemented** — none of the four required scalar cards exist (`Durata media ciclo` / `Durata media flusso` / `Dolore medio` / `Cicli tracciati`). → `stats_screen.dart:63-92`
3. **No accent variant** on first card (bible: terracotta value + `${terracotta}44` border). → `stat_card.dart:33-43`
4. **Pain average not computed or rendered** — `CycleStatsData` has no `painIntensityAvg` aggregate. CL-02 unit `/3` not honoured. → `cycle_stats_data.dart:42-56`, `compute_cycle_stats.dart`
5. **MiniBar primitive doesn't exist** — uses `fl_chart` LineChart/BarChart instead of bible's 80-px column bars (28-wide, top-radius 4, opacity 0.85). → `cycle_length_chart.dart` etc.
6. **Wrong chart inventory**: ships period-length and flow-intensity charts (not in bible); pain-intensity chart missing. → `stats_screen.dart:71-90`
7. **Symptom-frequency card** uses `%` instead of `count/max`, `accentFlow` instead of `ocra`, `LinearProgressIndicator` 8-px instead of custom 6-px track, side-by-side layout instead of label/count above bar. Title `"Sintomi frequenti"` instead of bible's `"Sintomi più frequenti"`. → `symptom_frequency_chart.dart:34-99`
8. **Required IT strings missing from ARB**: title, subtitle, all four card titles/values/units/subs, two chart titles, symptom-card title. → `app_it.arb`

### 2.5 Onboarding + Tab bar + CTAs (`audit-findings-onboarding-nav.md`)

1. **Tab bar uses Material 3 NavigationBar default + animated pill** — see § 1.3 above.
2. **Manifesto headline at 32 vs spec 34**; **wordmark at 48 vs spec 56** with letter-spacing -0.01em vs -0.02em. → `onboarding_screen.dart:140-167`
3. **Primo Ciclo headline at 32 vs spec 28**. → `onboarding_screen.dart:297-303`
4. **Cycle stepper buttons are Material `IconButton` (48×48)** — spec § 5.2 micro-button: 40×40 / radius 10 / `rgba(0.07)` fill / `−`/`+` Inter 20. → `onboarding_screen.dart:621-665`
5. **Period-day cell active text uses `Colors.white`** — spec `sabbia` (`#F4EDE2`). → `onboarding_screen.dart:527`
6. **Date-picker `firstDate` capped to 6 months back** — undocumented constraint excluding perimenopause/post-pregnancy/amenorrhoea users. → `onboarding_screen.dart:469-473`
7. **Non-canonical `onboarding_privacy_*` ARB keys still ship** — § 12.2 explicitly removes the privacy screen. Footgun. → `app_it.arb:826-845`
8. **Wordmark widget `lib/core/widgets/metra_wordmark.dart` referenced in bible §17 does not exist** — wordmark used inline. → file missing
9. **Tab bar `Archivio` icon is `view_timeline_outlined`**; spec `wave`. → `app_router.dart:113-134`

### 2.6 Foundation — additional HIGH items

(Already covered in § 1 above. Listed there because they are cross-cutting.)

---

## 3 · Open question (bible self-contradiction — needs user decision)

### Métra (acute) vs Mētra (macron) in the Manifesto subhead
- **Bible § 0.3 + § 15¶8** mandate `Mētra` (U+0113, macron) in **every** product hero/splash/brand context.
- **Bible § 12.1 line 883** quotes the Manifesto subhead as `Métra è un quaderno silenzioso...` (acute U+00E9).
- **ARB:** `app_it.arb:782` ships acute `Métra`.
- **Per § 0 the HTML is canon**. Action: open `design/Métra Screens Light.html` and confirm which glyph the manifesto subhead actually renders. Then either:
  - (a) Fix the ARB to macron + patch bible § 12.1 line 883, or
  - (b) Document an explicit exception in § 0.3 ("body-copy mention of the brand uses the acute; only the rendered wordmark uses the macron").

---

## 4 · Recommended fix sequence

Sequential phases — each gates the next. Within a phase, parallelise.

### Phase 0 — Foundation (1.5 days)
**Cannot parallelise per-screen until this lands.** Delivers all 9 cross-cutting blockers in § 1.
- 0a. Fix the 2 hex drifts + delete 6 invented primitives + replace `divider` opaque → `inchiostro.withAlpha(0x12)`.
- 0b. Replace `MetraSpacing` with full canonical scale; delete `pill` from `MetraRadius`, add `xs=6, smm=10, mmd=14, lgg=18, xl=20, phone=44`.
- 0c. Rebuild `MetraTypography` with role-named tokens, correct line-heights and letter-spacings.
- 0d. Replace every `fontFamily: 'Inter'` with `GoogleFonts.inter(...)`.
- 0e. Build `MetraIcon` widget + bible icon catalog (SVG paths). Implement `Moon(phase)` widget.
- 0f. Fix segmented-control shadow blur and color.
- 0g. Replace `NavigationBar` with custom `BackdropFilter` tab bar; use `MetraIcons.{calendar,note,wave,chart,settings}`.

### Phase 1 — Today / Daily entry (1 day, parallelisable into 4 sub-tasks)
1a. Section frame wrapper + header padding/typography.
1b. Choice chip + inline-add affordance + symptom row tap target.
1c. Flow & Pain dot SVG geometry + Pain "Nessuno" stroke.
1d. Spotting/Assente hint boxes + Notes textarea + Save CTA.
1e. ARB: `today_notes_hint` ASCII `...` → `…`.

### Phase 2 — Calendar (0.5 day, parallelisable into 3)
2a. Header (typography + padding) + day-headers row.
2b. Day cell (font, weights, borders, indicator dots row using `MetraIcon`s).
2c. Day-detail card (flex 1, "Giorno N del ciclo" sub-row, flow pill geometry, ocra symptom chips, edit-CTA icon/typography).
2d. Legend reorder + padding + label typography.

### Phase 3 — Onboarding (0.5 day)
3a. Manifesto headline 34 + wordmark 56 + letter-spacing -0.02em + ornament marginBottom + hero block flex `0 0 340`.
3b. Primo Ciclo headline 28 + subhead Inter 14 + progress strip layout/track-color/gap + section-label position.
3c. § 5.2 stepper micro-buttons (40×40, radius 10, `rgba(0.07)`).
3d. Period-day cell colours (`sabbia` text on selected; `inchiostro 0.07` idle bg) + gap 8.
3e. Lift `firstDate` cap (or document the constraint).
3f. Delete non-canonical `onboarding_privacy_*` ARB keys + dedupe `onboarding_start`.
3g. Build `lib/core/widgets/metra_wordmark.dart`; replace inline use.

### Phase 4 — Archivio rebuild (1.5 days)
4a. Domain: extend `CycleSummary` with `int? maxPain`/`dominantPainIntensity`; update use-case.
4b. Header + l10n: add `archive_title`, rename `table_col_*` keys.
4c. Replace `Table` with decorated `Column` of `Row`s for the Tabella view.
4d. Rebuild `TimelineCard`: left rail (dot+line), month/Durata header row, mini-pills row (flow/pain/symptom with `MetraIcon`s), footer "Ciclo Xg · dal Y". Remove `InkWell`.
4e. Apply correct paddings/radii/marginBottom; scroll body bottom-padding 90.

### Phase 5 — Statistiche rebuild (1.5 days)
5a. Domain: `ComputeCycleStats` to expose `cycleLengthAvg/Range`, `periodLengthAvg/Range`, `painIntensityAvg`, `painTrend` (gated ≥3), `cyclesTrackedCount`, plus per-cycle `cycleLength` + `painIntensity` series, plus absolute symptom counts.
5b. Header (§11.1).
5c. `_StatSummaryCard` (with accent variant) + `Wrap` 2×2 grid (§11.3).
5d. `_MiniBarChart` primitive + `_ChartCard` wrapper (§11.4); ship cycle-length + pain-intensity charts; delete period-length and flow-intensity charts.
5e. Rewrite `SymptomFrequencyChart` per §11.5 (label/count row above ocra-filled 6-px track).
5f. ARB: all required strings; replace hardcoded `'Statistiche'` in nav.

### Phase 6 — Métra/Mētra resolution (5 min)
After user inspects the HTML mockup subhead glyph: patch ARB or bible § 12.1 line 883 accordingly.

### Phase 7 — Verification
- `flutter analyze` (zero warnings).
- `flutter test` (all green; bible-fixture golden tests for Statistiche § 11 series and Archivio § 10.5 fixture).
- Run app and walk every screen against `design/Métra Screens Light.html` side-by-side.

**Total estimate:** ~6.5 working days. Phases 0 → 1, 2, 3 can each parallelise independently after foundation lands; Phases 4 and 5 are the biggest single rebuilds and best done by separate agents.

---

## 5 · MEDIUM and LOW findings

The 84 MEDIUM + LOW findings are not consolidated here individually — see the per-area files. Themes:
- Imprecise alpha floats instead of byte-exact `withAlpha(0xNN)` (≈ 12 sites).
- Wrong base colour for translucency (`textSecondary` instead of `textPrimary`/inchiostro) (≈ 8 sites).
- Off-by-one paddings/margins (e.g. 16 vs 14, 12 vs 8, 4 vs 6).
- Locale-derived weekday/month labels instead of fixed Italian-primary literals.
- Missing `transition all 0.15s` on chips (the only sanctioned animation).
- L10n strings left unlocalised (tooltips, screen-reader labels).

These should be picked up opportunistically inside the per-screen phases above.

---

## 6 · Anti-patterns confirmed clean

The following § 15 anti-patterns are **not** present in the codebase (verified):
- §15¶1 No FAB ✓
- §15¶2 No checkmark on choice chips ✓
- §15¶3 No drop shadows on cards/sheets ✓ (only segmented-control button)
- §15¶4 Day cells are 48×48 rounded square, not circles ✓
- §15¶6 No emoji in copy/chips ✓
- §15¶7 No badges on tab icons ✓
- §15¶9 No swipe-to-archive / long-press menus ✓ (but anti-pattern violated by `InkWell` tap → see Archivio finding 5)
- §15¶13 No bottom-sheet patterns ✓
- §15¶14 No center-stage today pill ✓
- Cormorant Garamond not loaded ✓
