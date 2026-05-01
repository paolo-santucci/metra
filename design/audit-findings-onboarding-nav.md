# Audit findings — Onboarding, Tab bar, Primary CTAs

**Severity summary**
- HIGH: 9 (NavigationBar substitutes Material 3 default for the bible's bespoke tab bar; period-day text uses `Colors.white` not `sabbia`; cycle stepper uses default Material `IconButton` not § 5.2 micro-button; manifesto subhead uses `Métra` acute violating § 0.3 + anti-pattern 8; missing `metra_wordmark.dart` widget referenced by bible § 17; date-picker `firstDate` arbitrarily caps to 6 months back; non-canonical `onboarding_privacy_*` strings still shipped in ARB; Manifesto headline font-size 32 instead of 34; Primo Ciclo headline font-size 32 instead of 28).
- MEDIUM: 11 (progress-strip layout/order/track-color/gap/margins; section-label rendered after strip not before headline; date placeholder content "Seleziona data" is not the bible's "10 aprile 2025"; period-day cell idle border colour wrong; period-day cell gap 4 not 8; cycle stepper inactive track 0.08 OK but track height/labels alignment issues; manifesto hero capped via LayoutBuilder vs `flex 0 0 340`; missing terracotta variant CTA component for Today's "Salva giornata"; ornament marginBottom 24 vs code 40; CTAs lack disabled-state spec compliance check; `displayMd` constant 32 used for two different mock sizes).
- LOW: 3 (`onboarding_start` ARB key duplicates `onboarding_get_started`; `_StepProgressBar` accepts arbitrary `total` while bible fixes 2; tooltip strings on stepper IconButton not in ARB).

---

## Tab bar (§ 4)

### [BIBLE § 4] — NavigationBar uses Material 3 defaults instead of bespoke tab bar
- **File**: `/home/paolo/Sviluppo/metra/lib/router/app_router.dart:154`
- **Issue**: Uses Flutter `NavigationBar` widget. Material 3 `NavigationBar` defaults: height 80, surface elevated background, animated pill indicator behind active icon, label/icon styling driven by theme.
- **Bible says**: Height 84; bg `rgba(244,237,226,0.96)` + `BackdropFilter blur(16)`; top border `1px rgba(43,37,33,0.08)`; top inner padding 10; per-tab icon size 24 (active stroke 2 terracotta, inactive 1.5 `rgba(43,37,33,0.30)`); label `Inter 10` (active w600 terracotta, inactive w400 `rgba(43,37,33,0.55)`); icon-label gap 3; **no slide indicator**, **no center-FAB**, **no badges**; active state is colour + weight only.
- **Code does**: Default Material 3 NavigationBar with animated indicator pill and Material default heights/colors/typography. The pill behind selected destination is itself an anti-pattern (§ 4: "There is no center-FAB, no badges, no slide indicator").
- **Fix**: Replace with a custom `Container` (height 84, decoration `sabbia.withOpacity(0.96)` + `Border(top: BorderSide(...))`) wrapped in `BackdropFilter(filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16))`. Five `GestureDetector` tabs each rendering a 24-px icon with weighted stroke + 10-px Inter label, gap 3. Disable Material indicator (`indicatorColor: Colors.transparent` is not enough — replace the whole widget).
- **Severity**: HIGH

### [BIBLE § 4] — Tab icons mismatch spec glyph names
- **File**: `/home/paolo/Sviluppo/metra/lib/router/app_router.dart:113-134`
- **Issue**: Spec uses bespoke pictograms `cal`, `note`, `wave`, `chart`, `settings`. Code uses `Icons.calendar_today_outlined` (cal-ish, OK), `Icons.edit_note_outlined` (note → close), `Icons.view_timeline_outlined` (instead of `wave`), `Icons.bar_chart_outlined` (chart, OK), `Icons.settings_outlined` (settings, OK).
- **Bible says**: `wave` icon for `history` (Archivio) tab.
- **Code does**: `view_timeline_outlined` — a horizontal-bar/timeline icon, not a wave.
- **Fix**: Replace with a wave SVG (matching the HTML `wave` glyph at `mockup/scripts/components/icons.js`) or the closest Material approximation `Icons.waves_outlined`. Confirm against the HTML asset.
- **Severity**: MEDIUM

### [BIBLE § 4] — No Italian-label assertion against canonical strings; tab labels are hard-coded
- **File**: `/home/paolo/Sviluppo/metra/lib/router/app_router.dart:117,121,125,129,133`
- **Issue**: Labels `'Calendario'`, `'Oggi'`, `'Archivio'`, `'Statistiche'`, `'Impostazioni'` hard-coded in Dart string literals — not pulled through `AppLocalizations`.
- **Bible says**: § 14 IT vocabulary is canonical; ARB already defines `nav_oggi`, `nav_archivio`. Other tab labels (`Calendario`, `Statistiche`, `Impostazioni`) should also be ARB-backed.
- **Code does**: String literals; no l10n binding for tab labels.
- **Fix**: Bind each label via `AppLocalizations.of(context)!.nav_*` (extend ARB with `nav_calendario`, `nav_statistiche`, `nav_impostazioni`).
- **Severity**: LOW

---

## Primary CTAs (§ 5.1)

### [BIBLE § 5.1] — Today screen "Salva giornata" not in scope of this audit, but verify Terracotta variant exists
- **File**: `/home/paolo/Sviluppo/metra/lib/core/widgets/button_primary.dart` (out-of-audit)
- **Issue**: This audit covers onboarding only; flagged for cross-team confirmation that the **terracotta** primary variant with leading 18-px check icon (gap 8) is implemented for `daily_entry_save_action`. Onboarding 1 ("Inizia") and Onboarding 3 ("Tutto pronto →") MUST be **inchiostro** variant.
- **Bible says**: § 5.1 — only two variants: `Inchiostro` (brand entry/completion) and `Terracotta` (commit/save).
- **Code does**: Onboarding 1 (line 184) and Onboarding 3 (line 355) use `FilledButton.styleFrom(backgroundColor: textPrimary)` — inchiostro on sabbia. Geometry: height 56 ✓, radius 16 ✓.
- **Fix**: No code change for onboarding. Note that `_WelcomePage` and `_DataPage` build their own raw `FilledButton`s rather than reusing a shared `MetraPrimaryCta` widget — this duplicates geometry constants and risks drift.
- **Severity**: LOW

### [BIBLE § 5.1] — Inline button typography not asserted (`Inter 16 / weight 500`)
- **File**: `/home/paolo/Sviluppo/metra/lib/features/onboarding/onboarding_screen.dart:184-196,355-369`
- **Issue**: `FilledButton` uses Material default `labelLarge` text style. Bible specifies `Inter 16 / weight 500`. Without explicit `textStyle`, the active theme's button text style applies — no guarantee it is Inter 16/500.
- **Bible says**: `Inter 16 weight 500`, height 56, radius 16, centered content.
- **Code does**: Sets shape and minimum size, but no explicit text style.
- **Fix**: Add `textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500)` to `FilledButton.styleFrom`, or extract a `_buildPrimaryCta(...)` helper.
- **Severity**: MEDIUM

---

## Onboarding 1 — Manifesto (§ 12.1)

### [BIBLE § 12.1] — Headline font size 32 instead of 34
- **File**: `/home/paolo/Sviluppo/metra/lib/features/onboarding/onboarding_screen.dart:165-167`
- **Issue**: Headline uses `MetraTypography.displayMd` which is `fontSize 32` (`metra_typography.dart:38`).
- **Bible says**: DM Serif Display **34** inchiostro line 1.2.
- **Code does**: 32 px.
- **Fix**: Either widen `displayMd` to 34 (touches every consumer) or override locally: `style: MetraTypography.displayMd.copyWith(color: textPrimary, fontSize: 34, height: 1.2)`. Prefer local override since the existing scale stops at 32/40/48.
- **Severity**: HIGH

### [BIBLE § 0.3 / § 15.8] — Subhead string uses "Métra" (acute) instead of "Mētra" (macron)
- **File**: `/home/paolo/Sviluppo/metra/lib/l10n/app_it.arb:782` (also bible quote at line 883)
- **Issue**: `onboarding_privacy_line` says: `"Métra è un quaderno silenzioso..."` with acute `é` (U+00E9). § 0.3 marks the macron form `Mētra` (U+0113) as the only valid form for product UI; § 15 anti-pattern 8 forbids `Métra` in product hero contexts.
- **Bible says**: § 0.3 — "Use this in every hero / splash / brand context inside the app". The Manifesto subhead is in-app body copy referring to the product brand.
- **Code does**: ARB ships acute `Métra`; rendered verbatim by `_WelcomePage` line 170.
- **Note**: The bible itself at line 883 quotes the subhead with acute `Métra` — this is a self-contradiction inside the bible. Per bible rule § 0 ("HTML is canon"), the source of truth is the HTML mockup. **Action for user**: verify which glyph the HTML actually renders in the manifesto subhead and propagate. If macron, fix the ARB; if acute, document an explicit exception in § 0.3 ("body-copy mention of the brand name is the acute variant — only the rendered wordmark uses macron").
- **Fix**: Conditional on user decision. Recommend macron for consistency; update both `app_it.arb` (and `app_en.arb` if it mirrors).
- **Severity**: HIGH

### [BIBLE § 12.1] — Hero block uses LayoutBuilder cap (160–340) instead of fixed flex `0 0 340`
- **File**: `/home/paolo/Sviluppo/metra/lib/features/onboarding/onboarding_screen.dart:90-150`
- **Issue**: `heroHeight = (constraints.maxHeight * 0.56).clamp(160.0, 340.0)`. On standard phone heights (~700–800 dp), this gives 340 ✓; on smaller (<606 dp), it shrinks below the spec. The HTML uses `flex: 0 0 340` (fixed 340 px regardless).
- **Bible says**: `hero block (flex 0 0 340)` — fixed 340.
- **Code does**: Variable 160…340 with proportional clamp.
- **Fix**: Use a fixed `SizedBox(height: 340, ...)`. If small-screen overflow is a concern, that is a separate concern to negotiate with the design owner — the bible does not authorise a responsive override.
- **Severity**: MEDIUM

### [BIBLE § 12.1] — Outer ellipse gradient geometry approximated, not faithful
- **File**: `/home/paolo/Sviluppo/metra/lib/features/onboarding/onboarding_screen.dart:104-115`
- **Issue**: HTML radial is `ellipse 90% × 60% @ 50% 30%`. Code uses `RadialGradient(center: Alignment(0, -0.4), radius: 0.85, ...)` — circular not elliptical, center offset 0.3 vs 0.4, radius approximated.
- **Bible says**: `radial gradient ellipse 90 % × 60 % @ 50 % 30 %, rgba(200,116,86,0.05) → transparent 80 %`.
- **Code does**: Circular `RadialGradient` with single radius value. Flutter's `RadialGradient` does support `focalRadius` but not native ellipse aspect — typical fix is to wrap in a `Transform.scale(scaleX: 1.0, scaleY: 60/90)`.
- **Fix**: Wrap the gradient `DecoratedBox` in `Transform.scale(scaleY: 0.667)` aligned to top-30%, or use `ShaderMask` with `RadialGradient` and a scale matrix. Adjust center to `Alignment(0, -0.4)` corresponds to y=30% only when the box is square — re-derive against actual hero box.
- **Severity**: MEDIUM

### [BIBLE § 12.1] — Ornament marginBottom mis-spec'd
- **File**: `/home/paolo/Sviluppo/metra/lib/features/onboarding/onboarding_screen.dart:176-177`
- **Issue**: Code: `SizedBox(height: 40)` then ornament. Spec: ornament `marginBottom 24` (between ornament and CTA). Code structure: text → SizedBox 40 → ornament → ScrollView ends → Padding(0,0,0,28) → CTA. Spacing between ornament and CTA is 28 (CTA padding bottom) + scroll padding bottom 16 = 44, not 24.
- **Bible says**: ornament `marginBottom 24`.
- **Code does**: Effective ornament-to-CTA gap ≈ 16 + 0 (no spacer) + 28 padding = ~44.
- **Fix**: Restructure: text block + 24 gap + ornament + 24 gap then CTA at fixed 28-bottom padding. Replace `SingleChildScrollView`'s padding-bottom 16 with explicit ornament marginBottom 24.
- **Severity**: MEDIUM

### [BIBLE § 12.1] — Wordmark style does not assert letter-spacing -0.02em
- **File**: `/home/paolo/Sviluppo/metra/lib/features/onboarding/onboarding_screen.dart:140-146`
- **Issue**: Renders `MetraTypography.wordmark` with `MetraTypography.displayXl`. `displayXl` is `fontSize 48` (typography.dart:26) — bible says wordmark is **56 px** with `letterSpacing -0.02em`. `displayXl` already sets `letterSpacing: -0.01 * 48 = -0.48` (i.e. -0.01em not -0.02em).
- **Bible says**: `wordmark "Mētra" DM Serif Display 56 inchiostro letter-spacing -0.02em white-space nowrap`.
- **Code does**: 48 px, letterSpacing -0.01em.
- **Fix**: Override locally: `style: MetraTypography.displayXl.copyWith(color: textPrimary, fontSize: 56, letterSpacing: -0.02 * 56)`. Add `softWrap: false, maxLines: 1, overflow: TextOverflow.visible` for `nowrap`.
- **Severity**: HIGH

---

## Onboarding 2 (Privacy) — non-canonical (§ 12.2)

### [BIBLE § 12.2] — Non-canonical privacy strings still present in ARB
- **File**: `/home/paolo/Sviluppo/metra/lib/l10n/app_it.arb:826-845`
- **Issue**: ARB keys `onboarding_privacy_heading`, `onboarding_privacy_item1_title/body`, `onboarding_privacy_item2_*`, `onboarding_privacy_item3_*`, `onboarding_privacy_continue` exist. They drove the deprecated Privacy onboarding screen.
- **Bible says**: § 12.2: "NON-CANONICAL — REMOVED FROM PRODUCT FLOW. Do not resurrect this screen." The product flow is exactly two screens.
- **Code does**: Strings remain in ARB; no current Dart consumer (verified by absence in `onboarding_screen.dart`), but their presence is a footgun.
- **Fix**: Delete the seven `onboarding_privacy_*` keys from `app_it.arb` and matching entries from `app_en.arb`. Run `flutter gen-l10n` and ensure no consumers.
- **Severity**: HIGH

### [BIBLE § 12.2] — `onboarding_start` is dead and confusable with `onboarding_get_started`
- **File**: `/home/paolo/Sviluppo/metra/lib/l10n/app_it.arb:807-810`
- **Issue**: Two distinct ARB keys, both rendering "Inizia". `onboarding_start` is unused.
- **Bible says**: One CTA per screen: Onboarding 1 = "Inizia"; Onboarding 3 = "Tutto pronto →".
- **Code does**: Two redundant keys.
- **Fix**: Delete `onboarding_start`; keep `onboarding_get_started`.
- **Severity**: LOW

---

## Onboarding 3 — Primo Ciclo (§ 12.3)

### [BIBLE § 12.3] — Headline font size 32 instead of 28
- **File**: `/home/paolo/Sviluppo/metra/lib/features/onboarding/onboarding_screen.dart:297-303`
- **Issue**: Uses `MetraTypography.displayMd` (32). Bible says 28.
- **Bible says**: DM Serif Display **28** inchiostro line 1.25.
- **Code does**: 32 px, height 1.25 ✓ (override).
- **Fix**: Override fontSize to 28: `MetraTypography.displayMd.copyWith(color: textPrimary, height: 1.25, fontSize: 28)`.
- **Severity**: HIGH

### [BIBLE § 12.3] — Subhead uses caption (Inter 13) instead of Inter 14
- **File**: `/home/paolo/Sviluppo/metra/lib/features/onboarding/onboarding_screen.dart:305-311`
- **Issue**: Uses `MetraTypography.caption` (`fontSize 13`).
- **Bible says**: `Inter 14 rgba(0.68) line 1.5 marginBottom 28`.
- **Code does**: Inter 13.
- **Fix**: Build inline: `GoogleFonts.inter(fontSize: 14, height: 1.5, color: textPrimary.withValues(alpha: 0.68))`.
- **Severity**: MEDIUM

### [BIBLE § 12.3 / § 12.4] — Progress bar order/layout inverted vs spec
- **File**: `/home/paolo/Sviluppo/metra/lib/features/onboarding/onboarding_screen.dart:288-296`
- **Issue**: Code renders `_StepProgressBar` which has the strip THEN the "Passo 2 di 2" label below it (line 575-578). Spec puts the strip on its own with `marginBottom 24`, then a separate section-label `"Passo 2 di 2"` `marginBottom 8` BEFORE the headline.
- **Bible says**: progress strip → marginBottom 24 → section label "Passo 2 di 2" (Inter 12 w600 letter-spacing 0.06em UPPERCASE rgba(0.40)) → marginBottom 8 → headline.
- **Code does**: strip → 6 px → label (caption style, no uppercase) → 24 px → headline.
- **Fix**: Split: render the strip (no label) at `marginBottom 24`, then a `Text("Passo 2 di 2".toUpperCase(), style: microLabelStyle)` (already defined at line 276) with `marginBottom 8`, then headline.
- **Severity**: MEDIUM

### [BIBLE § 12.4] — Progress strip unfilled track color and gap wrong
- **File**: `/home/paolo/Sviluppo/metra/lib/features/onboarding/onboarding_screen.dart:561-572`
- **Issue**: Unfilled segment uses `accentColor.withValues(alpha: 0.25)` (terracotta @ 25%); inter-stripe gap uses `margin right 4`.
- **Bible says**: § 12.4 — Track `rgba(43,37,33,0.12)` (inchiostro 12%, NOT terracotta), gap `6`. Filled `terracotta`.
- **Code does**: Track is terracotta @ 25%; gap 4.
- **Fix**: `color: i < current ? accentColor : textPrimary.withValues(alpha: 0.12)`; `margin right: 6`.
- **Severity**: MEDIUM

### [BIBLE § 12.3] — Step counter visible on screen 2 — bible omits it from screen 2 layout
- **File**: `/home/paolo/Sviluppo/metra/lib/features/onboarding/onboarding_screen.dart:289-294, 575-578`
- **Issue**: `_StepProgressBar` always renders the `label` text (e.g. "Passo 2 di 2") underneath the strip. § 12.3 spec for Primo Ciclo specifically calls out a section-label `"Passo 2 di 2"` BEFORE the headline (per layout block) — i.e. once, in the right place. With the current code, when split (per fix above), there is one place to surface it. Confirm the strip's bottom-label is removed once the section-label is moved.
- **Bible says**: One occurrence, between strip and headline.
- **Code does**: Single occurrence currently, but in wrong position.
- **Fix**: Tied to the previous finding's fix.
- **Severity**: LOW

---

## Date input row (§ 6.3)

### [BIBLE § 6.3] — Placeholder string "Seleziona data" not bible content
- **File**: `/home/paolo/Sviluppo/metra/lib/l10n/app_it.arb:859-860`, consumed at `onboarding_screen.dart:421-423`
- **Issue**: When no date selected, shows `l10n.onboarding_date_placeholder` = "Seleziona data". § 6.3 mock content is `"10 aprile 2025"` (a sample date — implying the field should always have a value, not a placeholder).
- **Bible says**: Date input row content is the formatted date `"10 aprile 2025"`.
- **Code does**: Renders "Seleziona data" placeholder until tapped. The default is null on first run.
- **Fix**: Either (a) initialise `state.lastPeriodDate` to a sensible default (e.g. today minus 28d) so the field always shows a formatted date, or (b) accept the mockup never modeled an empty state and pre-fill. Recommend prefilling so the layout is bible-faithful, with the date picker still allowing user override.
- **Severity**: MEDIUM

### [BIBLE § 6.3] — `firstDate` arbitrarily caps at 6 months back
- **File**: `/home/paolo/Sviluppo/metra/lib/features/onboarding/onboarding_screen.dart:469-473`
- **Issue**: `firstDate: now.subtract(const Duration(days: 182))` — only allows last-period dates within 6 months. A real user whose last period ended 7+ months ago (perimenopause, post-pregnancy, amenorrhea) cannot enter their actual date.
- **Bible says**: No range constraint specified. Domain task ON-03 says wording is "Primo giorno dell'ultima mestruazione" but does not cap range.
- **Code does**: Hard 182-day floor.
- **Fix**: Remove the cap or extend to e.g. 730 days (2 y). Discuss with product — but the current cap is undocumented.
- **Severity**: HIGH

### [BIBLE § 6.3] — Border alpha 0.14 ✓ but verify width 1.5
- **File**: `/home/paolo/Sviluppo/metra/lib/features/onboarding/onboarding_screen.dart:436-440`
- **Issue**: Border `width: 1.5` ✓; alpha 0.14 ✓; radius 12 ✓; height 52 ✓; padding-inline 16 ✓; calendar icon size 18 ✓; icon alpha 0.40 ✓. Text style `MetraTypography.body` is Inter 16 ✓ but height defaults to 1.5 — bible says Inter 16 plain. Acceptable.
- **Bible says**: As above.
- **Code does**: All geometry matches except the placeholder content (covered separately).
- **Fix**: No deviation found.
- **Severity**: (clean)

---

## Number stepper (§ 6.4) — Cycle length

### [BIBLE § 5.2 / § 6.4] — Cycle stepper buttons are Material `IconButton`, not § 5.2 micro-button
- **File**: `/home/paolo/Sviluppo/metra/lib/features/onboarding/onboarding_screen.dart:621-665`
- **Issue**: Both `−` and `+` rendered as `IconButton(Icon(Icons.remove/add))` inside `SizedBox(width: 48, height: 48)`. Material default styling: round splash, no fill, theme-driven icon color.
- **Bible says**: § 5.2 stepper micro-button: `40 × 40 · radius 10 · background rgba(43,37,33,0.07) · glyph "−" or "+" font-size 20 color inchiostro`.
- **Code does**: 48×48, no rounded-rectangle fill, Material icon glyphs.
- **Fix**: Replace each with `GestureDetector → Container(width: 40, height: 40, decoration: BoxDecoration(color: textPrimary.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(10)), alignment: Alignment.center, child: Text('−', style: GoogleFonts.inter(fontSize: 20, color: textPrimary)))`. Plus disabled state when at clamp.
- **Severity**: HIGH

### [BIBLE § 6.4] — Number stepper row gap 16 not honoured
- **File**: `/home/paolo/Sviluppo/metra/lib/features/onboarding/onboarding_screen.dart:629-665`
- **Issue**: Code uses `MetraSpacing.s4` (presumably 4 px) between each button and the number block.
- **Bible says**: `row gap 16`.
- **Code does**: 4 px gaps.
- **Fix**: Replace `SizedBox(width: MetraSpacing.s4)` with `SizedBox(width: 16)` on both sides.
- **Severity**: MEDIUM

### [BIBLE § 6.4] — Center number font size 40 forced from displayXl (48)
- **File**: `/home/paolo/Sviluppo/metra/lib/features/onboarding/onboarding_screen.dart:638-643`
- **Issue**: Uses `MetraTypography.displayXl.copyWith(... fontSize: 40)`. `displayXl` letterSpacing is `-0.01 * 48 = -0.48`. Override changes fontSize to 40 but keeps the -0.48 absolute letter-spacing — proportionally that becomes -0.012em for 40 px text, slightly off-spec.
- **Bible says**: `<Display 40 inchiostro>{n}` — DM Serif Display 40 with the standard 1.2 line height (no special letter-spacing called out for the stepper).
- **Code does**: 40 px ✓ but inherited absolute letterSpacing -0.48.
- **Fix**: Either reset letter-spacing: `.copyWith(... fontSize: 40, letterSpacing: -0.01 * 40)` or use `MetraTypography.displayLg` which is already 40 and proportionally correct.
- **Severity**: LOW

### [BIBLE § 6.4] — Track / labels otherwise correct
- **File**: `/home/paolo/Sviluppo/metra/lib/features/onboarding/onboarding_screen.dart:670-705`
- **Issue**: Track height 4 ✓, color `rgba(0.08)` ✓, radius 2 ✓, fill terracotta ✓, fraction `(n-21)/(45-21)` ✓, range 21–45 ✓, labels Inter 11 alpha 0.35 ✓, marginTop 4 ✓, justified ✓.
- **Fix**: No deviations found.
- **Severity**: (clean)

---

## Period-day cell (§ 5.3)

### [BIBLE § 5.3] — Active text uses `Colors.white` instead of `sabbia`
- **File**: `/home/paolo/Sviluppo/metra/lib/features/onboarding/onboarding_screen.dart:527`
- **Issue**: Active cell text color is hard-coded `Colors.white` (#FFFFFF). Sabbia is `#F4EDE2`. The selected pill is terracotta — `Colors.white` over terracotta is technically legible but breaks the token system (and looks slightly cooler than the warm sabbia mockup).
- **Bible says**: `text sabbia` weight 500.
- **Code does**: `Colors.white`.
- **Fix**: `color: isSelected ? bgPrimary : textPrimary` (where `bgPrimary` resolves to `sabbia` in light theme via `MetraColors.light.bgPrimary`).
- **Severity**: HIGH

### [BIBLE § 5.3] — Idle border colour uses `Colors.black12` not the spec alpha
- **File**: `/home/paolo/Sviluppo/metra/lib/features/onboarding/onboarding_screen.dart:514-518`
- **Issue**: Idle cell border `Colors.black12` (≈ rgba(0,0,0,0.12)). Spec uses `rgba(43,37,33,0.12)` (inchiostro 12%) — same alpha but black vs ink-brown.
- **Bible says**: `border 1px solid rgba(43,37,33,0.12)`.
- **Code does**: `Colors.black12`.
- **Fix**: `border: Border.all(color: isSelected ? Colors.transparent : textPrimary.withValues(alpha: 0.12), width: 1)`.
- **Severity**: MEDIUM

### [BIBLE § 5.3] — Idle background is `bgSurface` not `rgba(43,37,33,0.07)`
- **File**: `/home/paolo/Sviluppo/metra/lib/features/onboarding/onboarding_screen.dart:512`
- **Issue**: Idle cell uses `bgSurface` (`#FAF5EE`). Bible says `rgba(43,37,33,0.07)`.
- **Bible says**: `bg rgba(43,37,33,0.07)`.
- **Code does**: `bgSurface`.
- **Fix**: `color: isSelected ? accentFlow : textPrimary.withValues(alpha: 0.07)`.
- **Severity**: MEDIUM

### [BIBLE § 5.3] — Inter-cell gap is 4 px not 8
- **File**: `/home/paolo/Sviluppo/metra/lib/features/onboarding/onboarding_screen.dart:510`
- **Issue**: `margin right: 4`. Bible (§ 12.3 field 3) says `row · gap 8 of 8 cells`.
- **Bible says**: `gap 8`.
- **Code does**: 4.
- **Fix**: `margin: EdgeInsets.only(right: i < 7 ? 8 : 0)`.
- **Severity**: MEDIUM

### [BIBLE § 5.3] — Cell text not asserting Inter 15
- **File**: `/home/paolo/Sviluppo/metra/lib/features/onboarding/onboarding_screen.dart:521-528`
- **Issue**: Hard-coded `TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w500, ...)`. Bible doesn't pin a size for this cell text — but consistency suggests the cell should inherit the same Inter weight. 15 is plausible. Note: `fontFamily: 'Inter'` may not pick up the GoogleFonts variant if the asset isn't bundled — should use `GoogleFonts.inter(...)`.
- **Bible says**: weight 500 + colour. Size unspecified.
- **Code does**: 15 px.
- **Fix**: Use `GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500, color: ...)` for consistency with elsewhere in the file.
- **Severity**: LOW

### [BIBLE ON-02] — Range 1–8 ✓
- **File**: `/home/paolo/Sviluppo/metra/lib/features/onboarding/onboarding_screen.dart:502-503`
- **Issue**: `List.generate(8, ...)` with `day = i + 1` → days 1..8 ✓ matches FIGO upper bound.
- **Fix**: No deviation found.
- **Severity**: (clean)

---

## Wordmark (WM-01)

### [BIBLE § 17] — Missing `lib/core/widgets/metra_wordmark.dart`
- **File**: `/home/paolo/Sviluppo/metra/lib/core/widgets/` (does not contain `metra_wordmark.dart`)
- **Issue**: § 17 cross-references list `lib/core/widgets/metra_wordmark.dart` as the canonical wordmark widget. The file does not exist — the wordmark is rendered by inline `Text(MetraTypography.wordmark, ...)` in `onboarding_screen.dart:140-146`.
- **Bible says**: Implies a reusable widget.
- **Code does**: Inline use only.
- **Fix**: Create `lib/core/widgets/metra_wordmark.dart` with a `MetraWordmark` widget that renders `MetraTypography.wordmark` with the spec font size 56 + letter-spacing -0.02em + nowrap. Replace the inline use in onboarding. This also centralises the macron `Mētra` literal.
- **Severity**: HIGH

### [BIBLE § 0.3] — Wordmark constant is correct macron (✓)
- **File**: `/home/paolo/Sviluppo/metra/lib/core/theme/metra_typography.dart:84`
- **Issue**: `static const String wordmark = 'Mētra';` — literal U+0113 ✓.
- **Fix**: No deviation found.
- **Severity**: (clean)

---

## Cross-cutting — Anti-patterns sweep (§ 15)

### [BIBLE § 15.7] — No badges on tab icons
- **File**: `/home/paolo/Sviluppo/metra/lib/router/app_router.dart:113-134`
- **Issue**: No badge usage detected ✓.
- **Fix**: No deviation found.
- **Severity**: (clean)

### [BIBLE § 15.1] — No FAB
- **File**: All routes — none of the audited screens defines a `FloatingActionButton` ✓.
- **Fix**: No deviation found.
- **Severity**: (clean)

### [BIBLE § 15.8] — `Mētra` macron everywhere except subhead — see Manifesto subhead finding above.

### [BIBLE § 14] — L10n vocabulary checks
- **Verified**: `Inizia` ✓ (`onboarding_get_started`), `Tutto pronto →` ✓ (`onboarding_all_set`), `Passo n di m` ✓ (`onboarding_step_label` plural form OK; **but** the placeholder rendering "Passo 2 di 2" is sentence-cased per spec — the bible at § 14 explicitly notes "lowercase except the leading word and 'P'"; current `.toUpperCase()` for the section label conflict — the bible at § 12.3 says micro-label is UPPERCASE while § 14 says "Passo n di m" mixed case. Resolve: § 12.3 wins since it specifies the styling for that exact field).
- **Status**: ARB strings are lowercase "Passo 2 di 2"; code calls `.toUpperCase()` to render `PASSO 2 DI 2` per the micro-label rule. ✓
- **Fix**: No deviation found.
- **Severity**: (clean)

---

## Misc / consistency

### [BIBLE § 14] — Tooltip strings on cycle stepper not localized
- **File**: `/home/paolo/Sviluppo/metra/lib/features/onboarding/onboarding_screen.dart:625, 661`
- **Issue**: `tooltip: 'Diminuisci durata ciclo'` and `'Aumenta durata ciclo'` are hard-coded Italian strings.
- **Bible says**: Italian-primary L10n; all user-visible strings via ARB.
- **Code does**: Hard-coded.
- **Fix**: Add `onboarding_cycle_decrement_tooltip` / `onboarding_cycle_increment_tooltip` ARB keys.
- **Severity**: LOW

### [BIBLE § 12.3] — Date picker semantics label is hard-coded Italian
- **File**: `/home/paolo/Sviluppo/metra/lib/features/onboarding/onboarding_screen.dart:427`
- **Issue**: `Semantics(label: 'Primo giorno ultima mestruazione, ...non selezionato')` — hard-coded.
- **Bible says**: All Italian user-visible copy in ARB.
- **Code does**: Hard-coded.
- **Fix**: Add ARB key for the screen-reader label.
- **Severity**: LOW
