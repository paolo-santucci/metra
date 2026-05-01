# Calendar screen audit — findings vs DESIGN-BIBLE.md (§ 8.1–8.6, § 13, § 15)

**Severity summary**
- HIGH: 11 (day cells use 5×5 dots instead of 4 typed icons; missing symptom indicator; missing CL-01 lavanda hollow drop for predicted; symptom chips use wrong color/shape; missing "Giorno N del ciclo" sub-row in day-detail; wrong header typography token; edit-CTA uses wrong icon/typography/color; day-of-week header wrong size/letter-spacing; day cells use raw `fontFamily: 'Inter'` not registered → fallback font; grid horizontal padding wrong; flow-pill geometry wrong)
- MEDIUM: 8 (header padding order; day-headers padding; day-detail card padding/margin; "no data" hint typography; flow pill alpha minor; symptom chip text color; today-cell font weight; predicted text alpha)
- LOW: 4 (chevron icon size 24 vs 22; cycle-day caption never wired in MonthNavigator; semantic widget wraps `IconButton` redundantly; legend item gap 4 vs 5)

---

## Header (§ 8.1)

### [BIBLE § 8.1] — Title typography token wrong (HIGH)
- **File**: `lib/features/calendar/widgets/month_navigator.dart:81`
- **Issue**: Title style uses `MetraTypography.displayMd` which is `DM Serif Display 32`.
- **Bible says**: `Display 26 inchiostro · line 1.1` (i.e. `titleLg` = 26 fontSize, height 1.3).
- **Code does**: `displayMd` → 32 fontSize, height 1.2, with negative letterSpacing.
- **Fix**: Switch to `MetraTypography.titleLg` (26 / 1.3) or define a dedicated calendar-header style. Remove negative letterSpacing.
- **Severity**: HIGH

### [BIBLE § 8.1] — Header padding values wrong (MEDIUM)
- **File**: `lib/features/calendar/widgets/month_navigator.dart:64–69`
- **Issue**: Padding is `EdgeInsets.fromLTRB(s4, s3, s2, s2)` = `(16, 12, 8, 8)`.
- **Bible says**: `padding 12 / 24 / 0` → `top 12, horizontal 24, bottom 0`.
- **Code does**: `top 12, left 16, right 8, bottom 8`.
- **Fix**: `EdgeInsets.fromLTRB(24, 12, 24, 0)`.
- **Severity**: MEDIUM

### [BIBLE § 8.1] — Cycle-day sub-row never rendered (LOW)
- **File**: `lib/features/calendar/calendar_screen.dart:119–128` and `month_navigator.dart:50, 83–102`
- **Issue**: `MonthNavigator.cycleDay` is supported but `CalendarScreen` never passes it. The "Giorno 14" caption with moon-phase icon never appears.
- **Bible says**: Sub-row is required when in a known cycle (moon phase=2 size 14 inchiostro + Inter 13 rgba(0.68) "Giorno 14").
- **Code does**: Always omitted.
- **Fix**: Compute current cycle day from `cyclePredictionProvider` / latest period start and pass as `cycleDay:`.
- **Severity**: LOW (functional gap — also affects § 8.1 sub-row spec)

### [BIBLE § 8.1] — Sub-row icon is `brightness_2_rounded` (LOW)
- **File**: `lib/features/calendar/widgets/month_navigator.dart:88`
- **Issue**: When the cycle-day row IS rendered, the icon is `brightness_2_rounded`, not the spec's "Moon phase=2" icon (which in HTML mockups is a custom phase glyph).
- **Bible says**: `Moon phase=2 size 14 inchiostro`.
- **Code does**: Generic Material moon icon.
- **Fix**: Either substitute a moon-phase asset/SVG that matches the HTML mockup, or document that Material `brightness_2` is the chosen Flutter equivalent.
- **Severity**: LOW

### [BIBLE § 8.1] — Chevron icon size 24, spec 22 (LOW)
- **File**: `lib/features/calendar/widgets/month_navigator.dart:114, 130`
- **Issue**: `iconSize: 24`.
- **Bible says**: `chevron_left 22 / chevron_right 22`.
- **Code does**: 24.
- **Fix**: `iconSize: 22`.
- **Severity**: LOW

### [BIBLE § 8.1] — Chevron disabled style hides instead of greys (LOW)
- **File**: `lib/features/calendar/widgets/month_navigator.dart:122–125`
- **Issue**: When `canGoNext == false`, the next button is wrapped in `Opacity(0.0)` + `IgnorePointer`, making it invisible.
- **Bible says**: "idle / disabled = no extra style; only color" — both chevrons stay visible; idle/disabled is conveyed via colour only (left chevron is rgba(0.40), right is inchiostro).
- **Code does**: Hides the chevron entirely.
- **Fix**: Render the next chevron with `chevronInactive` colour when disabled rather than 0-opacity, and keep the prev chevron always at `chevronInactive` per spec.
- **Severity**: LOW

---

## Day headers row (§ 8.2)

### [BIBLE § 8.2] — Wrong padding (MEDIUM)
- **File**: `lib/features/calendar/calendar_screen.dart:181`
- **Issue**: Padding is `EdgeInsets.symmetric(horizontal: MetraSpacing.s2)` = horizontal 8 only; no top/bottom asymmetry.
- **Bible says**: `padding 16 / 12 / 4 / 12` → top 16, right 12, bottom 4, left 12.
- **Code does**: top 0, horizontal 8, bottom 0.
- **Fix**: `EdgeInsets.fromLTRB(12, 16, 12, 4)`.
- **Severity**: MEDIUM

### [BIBLE § 8.2] — Header label typography wrong size/letter-spacing (HIGH)
- **File**: `lib/features/calendar/calendar_screen.dart:188–191`
- **Issue**: Style is `MetraTypography.caption.copyWith(fontWeight: w600)` → fontSize 13, letterSpacing 0.13 (caption defaults).
- **Bible says**: `Inter 12 weight 600 rgba(0.35) letter-spacing 0.04em` → 12px, 0.04em ≈ 0.48 absolute, weight 600.
- **Code does**: 13px font, ≈0.13 letter-spacing.
- **Fix**: Define inline `GoogleFonts.inter(fontSize: 12, fontWeight: w600, letterSpacing: 0.48)` and apply `textPrimary.withValues(alpha: 0.35)`. Note `textColor` source is `MetraColors.light.textSecondary` which is not 0.35 alpha of inchiostro.
- **Severity**: HIGH

### [BIBLE § 8.2] — Label color uses textSecondary, not rgba(inchiostro,0.35) (MEDIUM)
- **File**: `lib/features/calendar/calendar_screen.dart:80–82, 189`
- **Issue**: Color is `MetraColors.light.textSecondary` (a fixed token), not the spec's `rgba(43,37,33,0.35)` (35% inchiostro).
- **Bible says**: `rgba(0.35)` (i.e. inchiostro at 35% alpha).
- **Code does**: textSecondary token (likely 0.65 alpha or different colour).
- **Fix**: `textPrimary.withValues(alpha: 0.35)`.
- **Severity**: MEDIUM

### [BIBLE § 8.2] — Labels derived from locale, not fixed `L M M G V S D` (LOW)
- **File**: `lib/features/calendar/calendar_screen.dart:64–70`
- **Issue**: Headers are computed via `intl.DateFormat.E(locale)` and uppercased to one char. For `it_IT` this produces `L M M G V S D` (correct), but for any other locale it diverges from the bible.
- **Bible says**: Italian-primary `L M M G V S D` are the canonical labels.
- **Code does**: Locale-derived; non-Italian locales may produce wrong labels.
- **Fix**: Hard-code `['L','M','M','G','V','S','D']` or read from a localised constant in `app_it.arb`. (Métra is Italian-primary per CLAUDE.md.)
- **Severity**: LOW (works in default locale, wrong elsewhere)

---

## Day cells (§ 8.3 / 8.3.1) — most violated rule

### [BIBLE § 8.3] — Day-number font is unregistered `Inter` (HIGH)
- **File**: `lib/features/calendar/widgets/calendar_day.dart:117–122`
- **Issue**: `TextStyle(fontFamily: 'Inter', fontSize: 15, …)`. The `Inter` family is loaded only via `GoogleFonts.inter(...)` elsewhere; using `fontFamily: 'Inter'` directly looks for an asset/declared family in `pubspec.yaml`. Result: Flutter falls back to platform default sans-serif for day numbers, so cells render in a different typeface from everything else.
- **Bible says**: `text Inter 15 color inchiostro weight 400`.
- **Code does**: 15 px in fallback font.
- **Fix**: Use `GoogleFonts.inter(fontSize: 15, fontWeight: fontWeight, color: textColor)` or expose a `MetraTypography.calendarDay` style.
- **Severity**: HIGH

### [BIBLE § 8.3.1] — Today (unselected) text weight 500, spec 400 (MEDIUM)
- **File**: `lib/features/calendar/widgets/calendar_day.dart:202`
- **Issue**: Today branch returns `FontWeight.w500`.
- **Bible says**: text weight `400` for today.
- **Code does**: w500.
- **Fix**: Change to `FontWeight.w400`.
- **Severity**: MEDIUM

### [BIBLE § 8.3.1] — Default (no-state) text alpha 0.60, spec inchiostro 100% (MEDIUM)
- **File**: `lib/features/calendar/widgets/calendar_day.dart:208–212`
- **Issue**: Default branch returns text colour `textPrimary.withValues(alpha: 0.60)`.
- **Bible says**: `text color inchiostro` (full 100% alpha) for the default state.
- **Code does**: 60% alpha → days look dimmed.
- **Fix**: Use `textPrimary` directly (no alpha).
- **Severity**: MEDIUM

### [BIBLE § 8.3.1] — Predicted text dimmed, spec inchiostro full (MEDIUM)
- **File**: `lib/features/calendar/widgets/calendar_day.dart:190`
- **Issue**: Predicted branch dims text to `textPrimary.withValues(alpha: 0.60)`.
- **Bible says**: text colour `inchiostro` weight 400 (full alpha) for predicted; only the border is the lavanda halo.
- **Code does**: 60% alpha.
- **Fix**: Use `textPrimary` directly.
- **Severity**: MEDIUM

### [BIBLE § 8.3.1] — Flow text weight w500, spec w400 (MEDIUM)
- **File**: `lib/features/calendar/widgets/calendar_day.dart:167`
- **Issue**: Flow branch returns `FontWeight.w500`.
- **Bible says**: weight 400 for flow cells.
- **Code does**: w500.
- **Fix**: Change to `FontWeight.w400`.
- **Severity**: MEDIUM

### [BIBLE § 8.3.1] — Spotting state has its own decoration (not in spec) (LOW)
- **File**: `lib/features/calendar/widgets/calendar_day.dart:171–181`
- **Issue**: A separate "spotting" branch renders bg `terracotta×0.07` + border `terracotta×0.22`, distinct from the flow branch.
- **Bible says**: Section 8.3.1 only enumerates Selected / Flow / Predicted / Today / Default. Spotting is part of the broader flow concept (the only flow window indicator). No separate visual is specified.
- **Code does**: Distinct lighter pill.
- **Fix**: Either fold spotting into the flow branch (treat any `flowType != null` as flow) or document this as an intentional extension to the bible. Surface for design review.
- **Severity**: LOW (spec ambiguity, not a clear violation but undocumented)

### [BIBLE § 8.3] — Calendar grid horizontal padding 8, spec 12 (HIGH)
- **File**: `lib/features/calendar/calendar_screen.dart:277–280`
- **Issue**: `padding: EdgeInsets.symmetric(horizontal: MetraSpacing.s2, vertical: MetraSpacing.s1)` = horizontal 8, vertical 4.
- **Bible says**: `padding 0 / 12 · row-gap 2`.
- **Code does**: horizontal 8, vertical 4 — squeezes the 7×48 grid by 8px and adds vertical 4 the spec doesn't request.
- **Fix**: `EdgeInsets.symmetric(horizontal: 12, vertical: 0)`. Use `mainAxisSpacing: 2` on the grid delegate to apply row-gap 2.
- **Severity**: HIGH

### [BIBLE § 8.3] — Row gap 2 not configured (MEDIUM)
- **File**: `lib/features/calendar/calendar_screen.dart:281–284`
- **Issue**: `SliverGridDelegateWithFixedCrossAxisCount` uses defaults; no `mainAxisSpacing`.
- **Bible says**: `row-gap 2` between week rows.
- **Code does**: 0 spacing.
- **Fix**: `mainAxisSpacing: 2`.
- **Severity**: MEDIUM

### [BIBLE § 8.3.1 / CL-01] — Flow alpha 0.13/0.27, spec 0.13/0.27 (LOW)
- **File**: `lib/features/calendar/widgets/calendar_day.dart:160–168`
- **Issue**: Spec `${terracotta}22` = ~0.133 and `${terracotta}44` = ~0.267. Code uses `0.13` and `0.27`.
- **Bible says**: `0.133` / `0.267`.
- **Code does**: 0.13 / 0.27.
- **Fix**: Acceptable rounding. No change required (informational).
- **Severity**: LOW

### [BIBLE § 8.3.1] — Predicted border alpha 0.40, spec 0.40 (`66`/0xFF=0.40) — OK
- No deviation. `${lavanda}66` = 102/255 ≈ 0.40, code uses 0.40.

---

## Indicator dots row (§ 8.3.2) — CRITICAL

### [BIBLE § 8.3.2 / CL-01] — Indicators are 5×5 colored dots, not typed icons (HIGH)
- **File**: `lib/features/calendar/widgets/calendar_day.dart:91–94, 219–234`
- **Issue**: Implementation renders generic `Container` circles (5×5 px) instead of the spec's typed `DataIcon`s (`drop`, `drop_outline`, `star_small`, `zap`).
- **Bible says**: `each indicator: DataIcon size 11 color (see below)` with fixed icon mapping per predicate.
- **Code does**: Plain coloured circles, size 5, no icon shape information.
- **Fix**: Replace `_Dot` with a small `Icon` row using Material equivalents: `Icons.water_drop` (flow, terracotta), `Icons.water_drop_outlined` (predicted, lavanda), `Icons.star_border` or a star icon (symptom, ocra), `Icons.bolt` (pain, malva). Set `size: 11`.
- **Severity**: HIGH

### [BIBLE § 8.3.2] — Indicator size 5, spec 11 (HIGH)
- **File**: `lib/features/calendar/widgets/calendar_day.dart:226–227`
- **Issue**: `width: 5, height: 5`.
- **Bible says**: `DataIcon size 11`.
- **Code does**: 5×5 circles.
- **Fix**: 11 px once converted to Icon (above).
- **Severity**: HIGH (subsumed by the icon-vs-dot fix but listed separately)

### [BIBLE § 8.3.2 / CL-01] — `hasSymptom` indicator entirely missing (HIGH)
- **File**: `lib/features/calendar/widgets/calendar_day.dart:91–94`
- **Issue**: Indicator list is built from `isFlow/isSpotting`, `hasPrediction`, and `hasPain` only. There is no `hasSymptom`/symptom-indicator path despite the bible mandating one (`star_small ocra` for "Sintomi"). The screen even has `painSymptomsProvider` but doesn't surface symptom presence per cell.
- **Bible says**: Predicate `hasSymptom` → `star_small` icon, `ocra` colour.
- **Code does**: No symptom indicator anywhere.
- **Fix**: Compute a `hasSymptom` flag per day (any `PainSymptomData` entry whose date matches that day) and add it to the indicator row, ordered after flow/prediction and before pain per spec priority `drop, drop_outline, star_small, zap`.
- **Severity**: HIGH

### [BIBLE § 8.3.2 / CL-01] — Predicted-day uses solid dot, not hollow drop (HIGH)
- **File**: `lib/features/calendar/widgets/calendar_day.dart:93`
- **Issue**: Predicted indicator is a solid lavanda 5×5 circle. CL-01 explicitly requires `drop_outline` (hollow drop) for the predicted period, paired with the lavanda border.
- **Bible says**: `isPred → drop_outline lavanda`.
- **Code does**: Solid lavanda circle.
- **Fix**: Replace with `Icons.water_drop_outlined` size 11, lavanda colour. Aligns with CL-01.
- **Severity**: HIGH

### [BIBLE § 8.3.2] — Indicator priority/ordering not enforced (MEDIUM)
- **File**: `lib/features/calendar/widgets/calendar_day.dart:91–94`
- **Issue**: Code adds flow first, then prediction (only if not flow), then pain. The bible requires order `drop, drop_outline, star_small, zap` regardless. With multiple predicates true (flow + pain), order is preserved here, but the gating `if (hasPrediction && !isFlow)` silently drops the predicted indicator when flow is logged on the same cell; the bible state table doesn't prescribe this.
- **Bible says**: Indicator pack shows any of `[isFlow, isPred, hasSymptom, hasPain]` independently in fixed order.
- **Code does**: Mutually excludes prediction when flow present.
- **Fix**: Always render each indicator independently; only the cell *background/border* state is mutually exclusive (selection > flow > predicted > today).
- **Severity**: MEDIUM

### [BIBLE § 8.3.2] — Indicator gap 2 ✓ (no deviation)
- Code uses `SizedBox(width: 2)` which matches `gap 2`.

### [BIBLE § 8.3.2] — Selected-cell indicator color uses bgPrimary (≈ sabbia) ✓
- `bgPrimary` resolves to `sand` `#F4EDE2` in light, which equals sabbia. No deviation in light mode. Dark-mode equivalent (`deepNight`) likely intentional.

---

## Legend strip (§ 8.4)

### [BIBLE § 8.4] — Legend item ordering wrong (HIGH)
- **File**: `lib/features/calendar/widgets/calendar_legend.dart:57–84`
- **Issue**: Order is `Mestruazioni, Previsione, Sintomi, Dolore`.
- **Bible says**: `drop tc_scura Mestruazioni · star_small ocra Sintomi · zap malva Dolore · drop_outline lavanda Previsione`. Previsione comes last.
- **Code does**: Previsione is in slot 2.
- **Fix**: Reorder to Mestruazioni → Sintomi → Dolore → Previsione.
- **Severity**: HIGH (CL-01 specifically calls out the legend reorder)

### [BIBLE § 8.4] — Legend padding `10 / 24`, code uses `16 / 10` (MEDIUM)
- **File**: `lib/features/calendar/widgets/calendar_legend.dart:53`
- **Issue**: `EdgeInsets.symmetric(horizontal: 16, vertical: 10)`.
- **Bible says**: `padding 10 / 24` → vertical 10, horizontal 24.
- **Code does**: horizontal 16, vertical 10.
- **Fix**: `EdgeInsets.symmetric(horizontal: 24, vertical: 10)`.
- **Severity**: MEDIUM

### [BIBLE § 8.4] — Legend icon-to-label gap 4, spec 5 (LOW)
- **File**: `lib/features/calendar/widgets/calendar_legend.dart:111`
- **Issue**: `SizedBox(width: 4)` between icon and label.
- **Bible says**: `gap 5`.
- **Code does**: 4.
- **Fix**: `SizedBox(width: 5)`.
- **Severity**: LOW

### [BIBLE § 8.4] — Legend label typography (MEDIUM)
- **File**: `lib/features/calendar/widgets/calendar_legend.dart:114`
- **Issue**: Style is `MetraTypography.tiny` → fontSize 12, weight 500, letterSpacing 0.12.
- **Bible says**: `Inter 11 rgba(0.68)` (no weight specified, implicitly 400).
- **Code does**: 12 px, weight 500.
- **Fix**: Inline `GoogleFonts.inter(fontSize: 11, fontWeight: w400)` and color `textPrimary.withValues(alpha: 0.68)`.
- **Severity**: MEDIUM

### [BIBLE § 8.4] — Label color uses textSecondary, not rgba(inchiostro,0.68) (LOW)
- **File**: `lib/features/calendar/widgets/calendar_legend.dart:43–45, 114`
- **Issue**: Color is `textSecondary` token, not the literal 68% inchiostro.
- **Bible says**: `rgba(0.68)`.
- **Code does**: token may differ.
- **Fix**: `textPrimary.withValues(alpha: 0.68)`.
- **Severity**: LOW

### [BIBLE § 8.4] — Top-border thickness OK, color OK (no deviation)
- `Divider(color: black12, thickness: 1, height: 1)` — black12 = rgba(0, 0, 0, 0.12). Spec is rgba(43,37,33,0.07). Slightly different (uses pure black 12% vs inchiostro 7%). Note as borderline.
- **Severity**: LOW (note rgba mismatch — see "Day-detail card border" below for same issue)

---

## Day-detail card (§ 8.5)

### [BIBLE § 8.5] — Card padding asymmetric in spec, symmetric in code (MEDIUM)
- **File**: `lib/features/calendar/calendar_screen.dart:376`
- **Issue**: `padding: EdgeInsets.all(16)`.
- **Bible says**: `padding 16 / 20` (vertical 16, horizontal 20).
- **Code does**: 16 on all sides.
- **Fix**: `EdgeInsets.symmetric(horizontal: 20, vertical: 16)`.
- **Severity**: MEDIUM

### [BIBLE § 8.5] — Card margin bottom 8, spec 4 (LOW)
- **File**: `lib/features/calendar/calendar_screen.dart:375`
- **Issue**: `EdgeInsets.fromLTRB(16, 4, 16, 8)`.
- **Bible says**: `margin 4 / 16` (vertical 4, horizontal 16).
- **Code does**: extra bottom 8.
- **Fix**: `EdgeInsets.symmetric(horizontal: 16, vertical: 4)`.
- **Severity**: LOW

### [BIBLE § 8.5] — Card border color uses Colors.black12 not rgba(inchiostro,0.07) (LOW)
- **File**: `lib/features/calendar/calendar_screen.dart:366, 380`
- **Issue**: `borderColor = Colors.black12` (rgba(0,0,0,0.12)).
- **Bible says**: `border 1px rgba(43,37,33,0.07)`.
- **Code does**: pure black 0.12.
- **Fix**: `Border.all(color: textPrimary.withValues(alpha: 0.07))` (textPrimary = inchiostro 0x2B2521).
- **Severity**: LOW

### [BIBLE § 8.5] — Card not flex 1 (does not fill remaining space) (MEDIUM)
- **File**: `lib/features/calendar/calendar_screen.dart:117–158, 374`
- **Issue**: The card is appended after `CalendarLegend()` in a `Column`, so it sizes to its intrinsic height (`MainAxisSize.min`). The grid is wrapped in `Expanded`.
- **Bible says**: Day-detail card is `flex 1 (always fills remaining vertical space)`.
- **Code does**: Card is intrinsic-height; the grid fills remaining space.
- **Fix**: Reverse the layout — wrap `_DayDetailCard` in `Expanded` and let the grid be intrinsic-height (or `Flexible`). This matches the HTML mockup where the grid is fixed-height and the detail card consumes residual space.
- **Severity**: MEDIUM (significant layout deviation; impacts overall screen feel)

### [BIBLE § 8.5] — Title typography 22, spec 20 (HIGH)
- **File**: `lib/features/calendar/calendar_screen.dart:391`
- **Issue**: Date title uses `MetraTypography.titleMd` = DM Serif Display 22.
- **Bible says**: `DM Serif Display 20 inchiostro`.
- **Code does**: 22 px.
- **Fix**: Define a 20-px DM Serif Display style or use a custom `GoogleFonts.dmSerifDisplay(fontSize: 20)` here.
- **Severity**: HIGH (titleMd is reused widely; create a dedicated 20 token rather than mutating titleMd).

### [BIBLE § 8.5] — Title format wrong: "Lunedì 10 aprile" vs code "Lunedì 10 aprile 2025" (LOW)
- Code derives `'d MMMM'` so year is omitted. ✓ Matches spec. (No deviation.)

### [BIBLE § 8.5] — Missing "Giorno N del ciclo" sub-row (HIGH)
- **File**: `lib/features/calendar/calendar_screen.dart:386–404`
- **Issue**: When the selected day is in a flow window, the bible requires a sub-row `Inter 13 rgba(0.68)` "Giorno {n} del ciclo" beneath the date title. The code never renders this, despite l10n `calendar_day_detail_cycle_day` being defined.
- **Bible says**: "If selected day is in flow window: `Inter 13 rgba(0.68)` `"Giorno {n} del ciclo"` with marginTop 2."
- **Code does**: Sub-row absent.
- **Fix**: When `prediction` indicates the selected date is within a known cycle, compute cycle-day n and render `Text(l10n.calendar_day_detail_cycle_day(n))` beneath the title with `marginTop: 2`, style `Inter 13 rgba(0.68)`.
- **Severity**: HIGH

### [BIBLE § 8.5] — Flow pill geometry: spec `height 32 paddingInline 12`, code `paddingHorizontal 12, paddingVertical 6` (HIGH)
- **File**: `lib/features/calendar/calendar_screen.dart:489–504`
- **Issue**: Pill uses symmetric padding (12, 6) yielding intrinsic height ~28 (depends on text); spec mandates a fixed 32-dp tall pill via `paddingInline 12, height 32, radius 10`.
- **Bible says**: `paddingInline 12, height 32, radius 10`.
- **Code does**: 12 horizontal × 6 vertical, height ~28.
- **Fix**: Wrap pill in `SizedBox(height: 32, …)`, set `padding: EdgeInsets.symmetric(horizontal: 12)` and align label centre.
- **Severity**: HIGH

### [BIBLE § 8.5] — Flow pill text color (MEDIUM)
- **File**: `lib/features/calendar/calendar_screen.dart:498–501`
- **Issue**: Label uses `MetraTypography.caption.copyWith(color: accentFlow, fontWeight: w500)`. caption is 13 px; spec is 12.
- **Bible says**: `Inter 12 weight 500 tc_scura` where `tc_scura = terracottaDeep` (deeper terracotta).
- **Code does**: 13 px, color `accentFlow` = standard terracotta (not deep).
- **Fix**: Inline `GoogleFonts.inter(fontSize: 12, fontWeight: w500, color: accentFlowText)` (accentFlowText is terracottaDeep / tc_scura).
- **Severity**: MEDIUM

### [BIBLE § 8.5] — "Nessun dato registrato" hint typography wrong (MEDIUM)
- **File**: `lib/features/calendar/calendar_screen.dart:393–400`
- **Issue**: Hint uses `MetraTypography.caption` (13 px) + `textSecondary`.
- **Bible says**: `Inter 12 rgba(0.38) italic`.
- **Code does**: 13 px, italic, textSecondary.
- **Fix**: Inline `GoogleFonts.inter(fontSize: 12, fontStyle: italic, color: textPrimary.withValues(alpha: 0.38))`.
- **Severity**: MEDIUM

### [BIBLE § 8.5] — Symptom chip wrong colour (HIGH)
- **File**: `lib/features/calendar/calendar_screen.dart:507–533`
- **Issue**: `_SymptomPill` uses `bg = accentFlow` (solid terracotta) and `color: bgPrimary` text. No border. Radius 20.
- **Bible says**: `paddingInline 10, height 28, radius 8, bg ${ocra}18, border 1px solid ${ocra}55, text Inter 12 tc_scura` (note: bg/border are ocra-tinted, not terracotta).
- **Code does**: Solid terracotta filled chip, sand text, radius 20.
- **Fix**: Reskin `_SymptomPill`: `SizedBox(height: 28)`, `padding: EdgeInsets.symmetric(horizontal: 10)`, `borderRadius: 8`, `bg: accentWarmth.withValues(alpha: 0.094)`, `border: accentWarmth.withValues(alpha: 0.333)`, text style `GoogleFonts.inter(fontSize: 12, color: accentFlowText)` (tc_scura = terracottaDeep).
- **Severity**: HIGH (visual identity of the chip is completely wrong)

### [BIBLE § 8.5] — Symptom-row gap 8, marginBottom 10 not honoured (MEDIUM)
- **File**: `lib/features/calendar/calendar_screen.dart:405–426`
- **Issue**: Wrap uses `spacing: 6, runSpacing: 4`. Top gap is `SizedBox(height: 8)`. No bottom margin on the chip row before the CTA (CTA gets `SizedBox(height: 12)` above instead).
- **Bible says**: `gap 8 wrap, marginBottom 10`.
- **Code does**: spacing 6 / runSpacing 4 / no marginBottom 10.
- **Fix**: `Wrap(spacing: 8, runSpacing: 8, …)`, then `SizedBox(height: 10)` after the wrap, and remove the now-redundant 12-px gap.
- **Severity**: MEDIUM

### [BIBLE § 8.5] — Edit-day CTA icon wrong (HIGH)
- **File**: `lib/features/calendar/calendar_screen.dart:442`
- **Issue**: Icon is `Icons.edit_outlined`.
- **Bible says**: `note 16 terracotta` (a note/notepad icon, not a pencil).
- **Code does**: Pencil/edit icon.
- **Fix**: `Icons.note_outlined` (or `Icons.edit_note_outlined`) in terracotta, size 16.
- **Severity**: HIGH

### [BIBLE § 8.5] — Edit-day CTA label typography wrong (HIGH)
- **File**: `lib/features/calendar/calendar_screen.dart:444–450`
- **Issue**: Label uses `MetraTypography.body` (16 px) + `textPrimary` + weight 500.
- **Bible says**: `Inter 14 weight 500 tc_scura`.
- **Code does**: 16 px, weight 500, inchiostro.
- **Fix**: Inline `GoogleFonts.inter(fontSize: 14, fontWeight: w500, color: accentFlowText)`.
- **Severity**: HIGH

### [BIBLE § 8.5] — Edit-day CTA bg/border alphas (LOW)
- **File**: `lib/features/calendar/calendar_screen.dart:435–436`
- **Issue**: bg `accentFlow.withValues(alpha: 0.06)`, border `0.13`.
- **Bible says**: `bg ${terracotta}10` = 0.0625, `border ${terracotta}22` = 0.133.
- **Code does**: 0.06 / 0.13.
- **Fix**: Acceptable rounding.
- **Severity**: LOW

### [BIBLE § 8.5] — Symptom chip caps at first 2 + "+N" overflow (LOW)
- **File**: `lib/features/calendar/calendar_screen.dart:411–423`
- **Issue**: Code shows only 2 chips, then `+N`.
- **Bible says**: No cap is mentioned; spec is `gap 8 wrap, marginBottom 10` implying full wrap.
- **Code does**: Truncates at 2.
- **Fix**: Either drop the 2-chip limit and let chips wrap freely, or document this as an intentional UX cap.
- **Severity**: LOW

### [BIBLE § 15 anti-pattern 1] — No FAB (no deviation)
- Verified: no FloatingActionButton in `calendar_screen.dart`.

---

## L10n (§ 8.6)

### [BIBLE § 8.6] — Months lowercase ✓
- `intl.DateFormat.MMMM('it')` produces lowercase Italian month names. Header re-capitalises the first letter (line 114), which matches the bible's display pattern (title-case word at sentence start).
- **Severity**: no deviation.

### [BIBLE § 8.6] — Weekdays capitalised ✓
- `intl.DateFormat.EEEE('it')` plus first-letter upper-case at line 372 matches `Lunedì, Martedì, …`.
- **Severity**: no deviation.

### [BIBLE § 8.6] — Day-headers `L M M G V S D` ✓ (in `it_IT` locale only — see § 8.2 finding above)

### [BIBLE § 8.6] — Week starts Monday ✓
- `_leadingBlanks = firstDayWeekday - 1` enforces Monday-first.

---

## Anti-patterns (§ 15 #1, #4, #14)

### [BIBLE § 15 #1] — No FAB ✓
No FloatingActionButton on calendar.

### [BIBLE § 15 #4] — Day cells rounded square 48×48 ✓
Constants `_cellSize = 48.0`, `_borderRadius = 12.0`. Not circular.

### [BIBLE § 15 #14] — No center-stage today pill ✓
Today is rendered as a 1.5-px ring on transparent bg, not a filled pill.

### Empty-state copy (§ 13)
- `calendar_day_detail_no_data` string in `app_it.arb` reads "Nessun dato registrato". ✓ Matches bible.
