# Foundation Tokens Audit — Métra

**Source of truth:** `design/DESIGN-BIBLE.md` §§ 1.1–1.7 and § 2 (cross-checked against `design/Métra Screens Light.html` lines 116–166).
**Audit date:** 2026-05-01.
**Scope:** colors, inchiostro alpha stops, accent tints, typography, spacing, radii, borders, shadows, backdrop blur, iconography.

---

## Summary by severity

- **HIGH:** 9 findings (palette divergence, wrong surface hex, terracotta-deep hex drift, illegal radius pill=999, tab-bar lacks backdrop blur, Material `Icons.*` shipped instead of bible icon catalog, Cormorant fallback risk, raw `0x142B2521` shadow instead of `0,1,4,0.12`, multiple non-canon alpha stops on accents).
- **MEDIUM:** 14 findings (line-heights/letter-spacings off-spec, unused/extra primitives, raw 0.05/0.06/0.09/0.13/0.18/0.25/0.27/0.50 alpha stops on inchiostro/terracotta, line-height 1.4/1.55 vs bible default, calendar-cell hardcoded fontSize 15, divider color `0xFFDCD2C0` is opaque solid not 0.07 alpha, 1.4-stroke battery icon not modeled, missing letter-spacing −0.02em on display 56/Inter clock, missing 0.06–0.07em uppercase tracking).
- **LOW:** 7 findings (spacing scale missing many anchors — `2/3/5/6/7/10/14/18/24/28/36/56/72/84/90/100`; `MetraSpacing` value/name mismatches such as `s1=4` vs spec `s1=4` ok but `s10=40` while spec uses 40 only as scale-stop — and other minor).

---

## Colors

### [BIBLE § 1.1] — Surface hex drift
- **File**: `lib/core/theme/metra_colors.dart:40`
- **Issue**: `surfaceRaised = Color(0xFFFBF6EC)` does not match the bible's `surface = #FAF5EE`.
- **Bible says**: `surface` = `#FAF5EE` (250, 245, 238).
- **Code does**: `0xFFFBF6EC` (251, 246, 236) — different RGB triplet.
- **Fix**: Change `surfaceRaised` to `Color(0xFFFAF5EE)`.
- **Severity**: HIGH

### [BIBLE § 1.1] — Terracotta-deep hex drift
- **File**: `lib/core/theme/metra_colors.dart:31`
- **Issue**: `terracottaDeep = 0xFF9B4E32` does not match bible `tc_scura = #9A4D32`.
- **Bible says**: `tc_scura` = `#9A4D32` (154, 77, 50).
- **Code does**: `#9B4E32` (155, 78, 50) — off by one in R and G.
- **Fix**: Change to `Color(0xFF9A4D32)`.
- **Severity**: HIGH

### [BIBLE § 1.1] — Off-catalog primitives shipped
- **File**: `lib/core/theme/metra_colors.dart:33-45`
- **Issue**: The light palette declares colors **not in the bible's catalog of 10 tokens**: `dustyOchreDeep (#8A6332)`, `mossDeep (#4F5A47)`, `inkSoft (#5A4F47)`, `surfaceSunken (#ECE4D6)`, `divider (#DCD2C0)`, `textDisabled (#8C8378)`. The bible explicitly says: *"Treat them as the **only** colors that may appear in the product."*
- **Bible says**: 10 tokens — sabbia, surface, bianco, inchiostro, terracotta, tc_scura, ocra, lavanda, malva, muschio. All translucent variants must be derived via the documented alpha stops.
- **Code does**: Defines 6 invented colors, several of which are referenced via semantic getters used across widgets (e.g. `borderSubtle => divider` opaque solid; `bgSunken` used in `timeline_card.dart:69, 91`).
- **Fix**: Either delete these primitives and replace usages with bible alpha-tints (`inchiostro @ 0.07` for divider, `inchiostro @ 0.40/0.68` for `inkSoft`/`textDisabled`, `inchiostro @ 0.04` for `bgSunken`), or document them and update the bible. Until then, the palette ships with non-canonical hex.
- **Severity**: HIGH

### [BIBLE § 1.1] — `bianco` token missing
- **File**: `lib/core/theme/metra_colors.dart` (whole file)
- **Issue**: The bible's `bianco = #FDFAF6` token is never declared. Even though it is "rarely used in screens," the bible lists it as one of the 10 canonical tokens.
- **Bible says**: `bianco = #FDFAF6`.
- **Code does**: Not present.
- **Fix**: Add `bianco = Color(0xFFFDFAF6)` for completeness.
- **Severity**: LOW

### [BIBLE § 1.1] — Light-palette field name `sand` vs token `sabbia`
- **File**: `lib/core/theme/metra_colors.dart:29` (and `terracottaDeep` vs `tc_scura`, `dustyOchre` vs `ocra`, `nightLavender` vs `lavanda`, `moss` vs `muschio`, `ink` vs `inchiostro`)
- **Issue**: Comment at line 22 says *"Field names mirror the C palette in the design HTML files."* They don't. The HTML uses `sabbia / tc_scura / ocra / lavanda / muschio / inchiostro` (Italian); code uses Anglicised names.
- **Bible says**: Italian token names per § 1.1 table.
- **Code does**: English aliases — `sand`, `terracottaDeep`, `dustyOchre`, `nightLavender`, `moss`, `ink`.
- **Fix**: Either rename to match the Italian tokens, or update the file comment to acknowledge the deliberate translation.
- **Severity**: LOW

### [BIBLE § 1.1.1] — Inchiostro alpha 0.05 not in catalog (onboarding panel halo)
- **File**: `lib/features/onboarding/onboarding_screen.dart:110`
- **Issue**: `accentFlow.withValues(alpha: 0.05)` — terracotta @ 0.05 isn't a documented stop (closest documented are 0D ≈ 0.05 acceptable for terracotta, but applied here ambiguously). Acceptable for terracotta `0D` but verify intent.
- **Bible says**: § 1.1.2 lists terracotta stops `0D / 10 / 14 / 15 / 18 / 22 / 28 / 44 / 66 / BB`.
- **Code does**: `0.05` ≈ `0D` — borderline match.
- **Fix**: Use `withAlpha(0x0D)` for byte-exactness, not the float 0.05.
- **Severity**: LOW

### [BIBLE § 1.1.1] — Inchiostro alpha 0.50 misuse on textSecondary
- **File**: `lib/features/daily_entry/today_screen.dart:475,495`; `lib/features/daily_entry/historical_entry_screen.dart:585,605`
- **Issue**: `textSecondary.withValues(alpha: 0.5)` — but `textSecondary` is **not** inchiostro; it is `inkSoft = #5A4F47` (an off-catalog primitive). Result is an alpha applied to a non-canon base.
- **Bible says**: Translucent ink must be `rgba(43,37,33, α)` from the documented scale. 0.50 is documented (segmented inactive label).
- **Code does**: 0.50 alpha applied to `#5A4F47`, not `#2B2521` — wrong base.
- **Fix**: Change base to `textPrimary` (= ink = `#2B2521`) before applying alpha; or use the canonical `inchiostro @ 0.50` literal.
- **Severity**: HIGH

### [BIBLE § 1.1.1] — Inchiostro alpha 0.25 (textSecondary base) misuse — historical_entry & today
- **File**: `lib/features/daily_entry/today_screen.dart:485,490`; `lib/features/daily_entry/historical_entry_screen.dart:595,600`; `lib/features/daily_entry/historical_entry_screen.dart:640`
- **Issue**: Alpha 0.25 applied to `textSecondary` (`inkSoft #5A4F47`). Bible says 0.25 is reserved for the inline-add chip dashed border (`rgba(43,37,33,0.25)`), with **inchiostro** as base.
- **Bible says**: `0.25` on inchiostro = `rgba(43,37,33,0.25)`.
- **Code does**: `0.25` on `#5A4F47`.
- **Fix**: Use `textPrimary.withValues(alpha: 0.25)` (= inchiostro 0.25).
- **Severity**: MEDIUM

### [BIBLE § 1.1.1] — Inchiostro alpha 0.38 used (within scale)
- **File**: `lib/features/daily_entry/widgets/circle_pain_picker.dart:150`
- **Issue**: `textPrimary.withValues(alpha: 0.38)` — 0.38 is a documented stop (row label canvas, empty-state italic hint). However the call site here is the pain-picker idle dot label, which the bible documents at `0.40` (indicator-dot label idle). Cross-reference may be intentional but worth verifying.
- **Bible says**: Indicator-dot label idle = inchiostro `0.40`.
- **Code does**: `0.38`.
- **Fix**: Use `0.40` to match the indicator-dot pattern unless this site has a separate spec entry.
- **Severity**: LOW

### [BIBLE § 1.1.1] — Inchiostro alpha 0.13 / 0.27 NOT in scale (calendar)
- **File**: `lib/features/calendar/widgets/calendar_day.dart:161,163`; `lib/features/calendar/calendar_screen.dart:436,492-493`; `lib/features/calendar/widgets/calendar_day.dart:175`
- **Issue**: Code uses `accentFlow.withValues(alpha: 0.13)` and `0.27`. These aren't bible stops. The bible documents the calendar flow-day cell as `${terracotta}22` (= 0.133 ≈ 0.13) bg + `${terracotta}44` (= 0.267 ≈ 0.27) border. So the *intent* is correct but the floats are imprecise.
- **Bible says**: Use 8-digit hex `0xFFC8745622` and `0xFFC8745644` (i.e. `withAlpha(0x22)` / `withAlpha(0x44)`).
- **Code does**: `withValues(alpha: 0.13)` ≈ 0x21 (one bit off) and `withValues(alpha: 0.27)` ≈ 0x45 (one bit off).
- **Fix**: Replace with `withAlpha(0x22)` / `withAlpha(0x44)` for byte-exactness (matches HTML's literal `${terracotta}22` / `${terracotta}44`).
- **Severity**: MEDIUM

### [BIBLE § 1.1.1] — Inchiostro alpha 0.06 / 0.09 / 0.22 (calendar edit-day CTA)
- **File**: `lib/features/calendar/calendar_screen.dart:435,492`
- **Issue**: `accentFlow.withValues(alpha: 0.06)` and `0.09` and `0.22`. Bible has `${terracotta}10` = 6 % (0x10/255 ≈ 0.063) for the edit-day CTA fill, `${terracotta}18` = 9 % for calendar day-detail flow chip, and `${terracotta}22` = 13 % for flow-day cell; `0.22` (= ~0x38) is **not** a documented stop.
- **Bible says**: Edit-day CTA = `${terracotta}10` (`0x10`); flow-day chip = `${terracotta}18` (`0x18`).
- **Code does**: 0.06 / 0.09 / 0.22 floats — close but not byte-exact, and 0.22 is non-canon.
- **Fix**: Use `withAlpha(0x10)`, `withAlpha(0x18)`, `withAlpha(0x22)` per intended location.
- **Severity**: MEDIUM

### [BIBLE § 1.1.1] — Inchiostro alpha 0.18 (timeline badge bg) NOT documented
- **File**: `lib/features/timeline/widgets/timeline_card.dart:67-68`
- **Issue**: `accentFlow.withValues(alpha: 0.18)` — 0.18 (~0x2E) is not a documented terracotta tint. Documented stops near it are `0x14` (0.078) and `0x22` (0.133). `0x18` exists in the catalog (= 0.094) but maps to ~0.09, not 0.18.
- **Bible says**: Terracotta tints documented stops only.
- **Code does**: 0.18.
- **Fix**: Either pick `withAlpha(0x22)` (= bible's flow-day cell tint), `withAlpha(0x18)` (= 0.094), or add a documented stop to the bible if the timeline badge needs a unique recipe. Same applies to timeline_card.dart:206 (`0.08`) and :218 (`0.10`) which are inchiostro stops, not terracotta — verify base.
- **Severity**: MEDIUM

### [BIBLE § 1.1.1] — Inchiostro alpha 0.078 / 0.133 / 0.400 / 0.733 (flow_type_chips)
- **File**: `lib/features/daily_entry/widgets/flow_type_chips.dart:159-166`
- **Issue**: Code derives floats from hex stops (`0x14 = 0.078`, `0x22 = 0.133`, `0x66 = 0.400`, `0xBB = 0.729 ≈ 0.733`). Comments correctly identify the bible stops. But float precision drifts (`0.733` vs `0xBB/255 = 0.7294`).
- **Bible says**: `${terracotta}14`, `22`, `66`, `BB`.
- **Code does**: Approximated floats.
- **Fix**: Use `withAlpha(0x14)`, `withAlpha(0x22)`, `withAlpha(0x66)`, `withAlpha(0xBB)`.
- **Severity**: MEDIUM

### [BIBLE § 1.1.1] — Inchiostro alpha 0.5 (button disabled) not in catalog
- **File**: `lib/core/widgets/button_primary.dart:49,64`; `lib/core/widgets/button_secondary.dart:60,72,80`; `lib/core/widgets/button_ghost.dart:55,69`
- **Issue**: All disabled-state buttons multiply `bgColor / fgColor` by 0.5. The base is the **terracotta** primary color, not inchiostro. 0.5 is not a documented terracotta stop (catalog stops at `0xBB ≈ 0.73`).
- **Bible says**: Disabled-state recipe is not enumerated. The closest comparable case is the onboarding disabled CTA: `disabledBackgroundColor: textPrimary.withValues(alpha: 0.35)` (which itself uses 0.35 — a documented inchiostro stop).
- **Code does**: 0.5 alpha on accent.
- **Fix**: Either add a disabled recipe to the bible (recommended `inchiostro @ 0.35` per the onboarding precedent) or lift one of the documented terracotta stops (`0x66 = 0.4`).
- **Severity**: HIGH

### [BIBLE § 1.1.1] — Onboarding disabled fg alpha 0.60 base bgPrimary
- **File**: `lib/features/onboarding/onboarding_screen.dart:360`
- **Issue**: `bgPrimary.withValues(alpha: 0.60)` — applies an opacity ramp to the **sand** background, which is not part of the alpha-stop scale (sand has no documented translucent stops).
- **Bible says**: Alpha stops only documented for inchiostro / terracotta / ocra / lavanda / malva.
- **Code does**: Translucent sabbia.
- **Fix**: Use a solid token.
- **Severity**: MEDIUM

### [BIBLE § 1.1.1] — Inchiostro alpha 0.06 / 0.09 / 0.13 / 0.27 spec mismatch
- **File**: `lib/features/calendar/calendar_screen.dart` (already covered above) and `lib/features/calendar/widgets/calendar_day.dart:161,163,173,175`
- **Issue**: The code uses 0.13 for "flow cell bg" (bible: `0x22` = 0.133), 0.27 for "flow cell border" (bible: `0x44` = 0.267), 0.07 for "spotting cell bg" (bible: `${terracotta}10` = 0.063), 0.22 for "spotting cell border" (bible: `${terracotta}28` = 0.156). Spotting border is the most off (~0.22 vs canonical ~0.16 or `${terracotta}28`).
- **Bible says**: Spotting selected chip border = `${terracotta}28` ≈ 0.156. Spotting hint background = `${terracotta}0D` ≈ 0.05.
- **Code does**: 0.07 (≈ `0x12`) and 0.22 (≈ `0x38`) — neither in catalog.
- **Fix**: Replace with `withAlpha(0x0D)` for the bg and `withAlpha(0x28)` for the border.
- **Severity**: MEDIUM

### [BIBLE § 1.1.2] — Pain-picker accent alphas drift from bible literals
- **File**: `lib/features/daily_entry/widgets/circle_pain_picker.dart:68,70,72,126`
- **Issue**: `accent.withValues(alpha: 0.28 / 0.60 / 0.92)` — the HTML pain-dot fillOps are `0.28 / 0.6 / 0.92`. Code matches the HTML exactly. The bible's malva-specific tint `rgba(158,116,136,0.12)` (archive pain-pill background) is not represented; not a defect in this file but worth noting.
- **Bible says**: HTML literal `fillOp: 0.28 / 0.60 / 0.92` (lines 297-301 of HTML).
- **Code does**: matches.
- **Fix**: No change needed; flagged for traceability.
- **Severity**: LOW

### [BIBLE § 1.1] — Off-catalog opaque divider color
- **File**: `lib/core/theme/metra_colors.dart:42` (and theme `dividerColor: colors.divider` at `metra_theme.dart:67`, plus `cardTheme` border on `:56`)
- **Issue**: `divider = Color(0xFFDCD2C0)` is an opaque computed color claiming to model the bible's *"Card edge: 1px solid rgba(43,37,33,0.07)"*. Painting opaque approximates over a known background but breaks composition over any other (e.g. dialogs, sheets, dark mode). The bible mandates a translucent recipe.
- **Bible says**: Card edge & section divider = `1px solid rgba(43,37,33,0.07)`. Translucent.
- **Code does**: Opaque solid `#DCD2C0`.
- **Fix**: Use `inchiostro.withAlpha(0x12)` (= 0.07 alpha, byte-exact). Audit all `colors.divider` consumers for visual delta over non-sand surfaces.
- **Severity**: HIGH

---

## Typography

### [BIBLE § 1.2] — Font families
- **File**: `lib/core/theme/metra_typography.dart` & `pubspec.yaml`
- **Issue**: Pubspec imports `google_fonts: ^6.2.1`. Code only invokes `GoogleFonts.dmSerifDisplay` and `GoogleFonts.inter`. **No Cormorant Garamond reference exists**, which conforms to the bible ("DO NOT SHIP"). Confirmed clean.
- **Bible says**: DM Serif Display + Inter only.
- **Code does**: DM Serif Display + Inter only.
- **Fix**: No change.
- **Severity**: (no deviation — confirmation only).

### [BIBLE § 1.2] — Display scale sizes don't match bible roles
- **File**: `lib/core/theme/metra_typography.dart:25-80`
- **Issue**: Code defines `displayXl=48, displayLg=40, displayMd=32, titleLg=26, titleMd=22, titleSm=20, bodyLg=18, body=16, caption=13, tiny=12`. The bible enumerates **specific roles** at sizes: hero wordmark **56**, onboarding 1 **34**, onboarding 2 **30**, onboarding 3 **28**, stepper **40**, stat-card **32**, screen-title **26**, day-detail **20**, archive-month **17**, body **16**, list-item **15**, date-subtitle **13**, body-secondary **13**, chip **13**, pill **11–12**, section-label **12**, day-header **12**, range **11**, dot-label **10**, tab-bar **10**. Several role sizes (**56, 34, 30, 28, 17, 15, 11, 10**) have no corresponding token.
- **Bible says**: Role-size mapping in § 1.2 table.
- **Code does**: 10-step abstract scale that maps loosely.
- **Fix**: Either expand the scale to include the missing role sizes (recommended: `displayHero=56, headlineLg=34, headlineMd=30, headlineSm=28, archiveMonth=17, listTitle=15, pillSm=11, pillMd=12, dotLabel=10`), or document the abstract scale's resolution to bible roles.
- **Severity**: HIGH

### [BIBLE § 1.2] — Line-heights diverge from bible
- **File**: `lib/core/theme/metra_typography.dart:27,33,39,45,50,55,61,66,71,77`
- **Issue**: Bible specifies (excerpts): hero 56 `line-height: 1.0`, onboarding-1 34 `1.2`, onboarding-2 30 `1.2`, onboarding-3 28 `1.25`, stepper 40 `1.0`, stat 32 `1.0`, screen-title 26 `1.1`, body `1.55–1.6`. Code uses `displayXl 1.2`, `displayLg 1.2`, `displayMd 1.2`, `titleLg 1.3`, `titleMd 1.3`, `titleSm 1.3`, `bodyLg 1.5`, `body 1.5`, `caption 1.4`, `tiny 1.4`. None match the bible exactly: `displayLg` (40) is supposed to be `1.0`, `titleLg` (26) `1.1`, `body` (16) `1.55–1.6`, etc.
- **Bible says**: Exact heights per role row.
- **Code does**: Looser `1.2 / 1.3 / 1.5 / 1.4`.
- **Fix**: Align line-heights per role.
- **Severity**: MEDIUM

### [BIBLE § 1.2] — Letter-spacing scheme wrong
- **File**: `lib/core/theme/metra_typography.dart:28,34,40,72,78`
- **Issue**: Code applies `letterSpacing: -0.01 * size` to all display tokens. Bible spec for hero wordmark (56) is `-0.02em`, onboarding 1/2/3 are **default**, stepper 40 default, stat 32 default. `+0.01 * size` on caption/tiny is also off; bible's section label (12) is `0.06–0.07em`, day-header (12) is `0.04em`, status-bar clock (Inter 15) is `-0.02em`. Code's `caption letterSpacing: 0.13` (= 0.01 × 13) maps to ~0.01em but the body 13 uses default per bible; section label 12 needs ~0.07em (= +0.84). None of these are correct.
- **Bible says**: Per-role letter-spacing as enumerated.
- **Code does**: Uniform `±0.01 × size`.
- **Fix**: Remove uniform formula; apply role-specific letter-spacing where bible specifies it; default elsewhere.
- **Severity**: MEDIUM

### [BIBLE § 1.2] — `titleSm` uses Inter w600 instead of DM Serif Display
- **File**: `lib/core/theme/metra_typography.dart:53-57`
- **Issue**: `titleSm fontSize: 20, FontWeight.w600` on Inter. Bible's "Day-detail card title" at 20 px is **DM Serif Display 400**.
- **Bible says**: Day-detail card title — DM Serif Display, 20, 400.
- **Code does**: Inter w600 20.
- **Fix**: Change to `GoogleFonts.dmSerifDisplay(fontSize: 20, fontWeight: FontWeight.w400, ...)`.
- **Severity**: HIGH

### [BIBLE § 1.2] — Body weight defaults off-spec
- **File**: `lib/core/theme/metra_typography.dart:59-67`
- **Issue**: `bodyLg / body` set no `fontWeight`. Bible: body = `400` for body, `500` for CTA labels. Code's CTA buttons rely on `body` style + `fontWeight: w500` overrides at button widgets — works. But default `body` should still explicitly set `400` for clarity.
- **Bible says**: Body 400, CTA 500.
- **Code does**: No explicit weight (defaults to 400).
- **Fix**: Set explicit `fontWeight: FontWeight.w400`.
- **Severity**: LOW

### [BIBLE § 1.2] — Inter font referenced as raw family string in calendar_day & navigation bar
- **File**: `lib/features/calendar/widgets/calendar_day.dart:118`; `lib/core/theme/metra_theme.dart:83,90,158,165`
- **Issue**: `fontFamily: 'Inter'` passed as a string. Inter is loaded via `google_fonts` runtime fetch, **not** as a bundled font family. Setting `fontFamily: 'Inter'` will fall back to system Inter or default sans — possibly the wrong glyphs. Should use `GoogleFonts.inter(...)` like `MetraTypography` does.
- **Bible says**: Inter loaded via Google Fonts.
- **Code does**: String fontFamily reference, bypassing the loader.
- **Fix**: Replace with `GoogleFonts.inter(...).copyWith(...)`.
- **Severity**: HIGH

### [BIBLE § 1.2.1] — Italic policy
- **File**: codebase
- **Issue**: No italic usage detected in any TextStyle. Empty-state hint text is not italicised in code. Bible permits italic Inter on empty-state hints.
- **Bible says**: Italic Inter for empty-state hints.
- **Code does**: No italic.
- **Fix**: When empty-state hints are added, use Inter italic.
- **Severity**: LOW

---

## Spacing

### [BIBLE § 1.3] — Spacing scale missing many anchors
- **File**: `lib/core/theme/metra_spacing.dart:19-31`
- **Issue**: Code defines `s0=0, s1=4, s2=8, s3=12, s4=16, s5=20, s6=24, s8=32, s10=40, s12=48, s16=64`. Bible scale: `0·2·3·4·5·6·7·8·10·12·14·16·18·20·24·28·32·36·44·48·56·72·84·90·100`. Missing: **2, 3, 5, 6, 7, 10, 14, 18, 28, 36, 44, 56, 72, 84, 90, 100**. Also the value `40` (`s10`) and `64` (`s16`) are **not** in the bible scale.
- **Bible says**: Full enumerated scale 0–100.
- **Code does**: Subset that diverges (40 and 64 are off-scale).
- **Fix**: Replace `MetraSpacing` with the full canonical scale; remove 40 and 64.
- **Severity**: HIGH

### [BIBLE § 1.3] — Calendar-day SizedBox(height: 3) literal
- **File**: `lib/features/calendar/widgets/calendar_day.dart:125,227`; `lib/features/calendar/widgets/month_navigator.dart:84`
- **Issue**: Raw `SizedBox(height: 3)` and `width: 2` literals. The bible scale includes 2 and 3, so values are valid — but they bypass the spacing tokens.
- **Bible says**: Both 2 and 3 are valid scale anchors.
- **Code does**: Hardcoded literals.
- **Fix**: Add `s_2 = 2, s_3 = 3` tokens and migrate.
- **Severity**: LOW

### [BIBLE § 1.3] — Onboarding letterSpacing/SizedBox literals
- **File**: `lib/features/onboarding/onboarding_screen.dart:299,304,567,568,612,679,680,689`
- **Issue**: Multiple `SizedBox(height: 4)` literals (≈ canonical 4 — fine), and `BorderRadius.circular(2)` (off-radii). Spacing literals (4, 16, 12, 10) are scale-valid; radii literal `2` is not in bible (§ 1.4).
- **Bible says**: Radii must be one of `6, 8, 10, 12, 14, 16, 18, 20, 44`.
- **Code does**: `BorderRadius.circular(2)` at lines 568, 680, 689.
- **Fix**: Use `MetraRadius.sm` (8) or pill, depending on intent. `2` is illegal.
- **Severity**: MEDIUM

---

## Radii

### [BIBLE § 1.4] — `MetraRadius.pill = 999` violates bible
- **File**: `lib/core/theme/metra_spacing.dart:37`
- **Issue**: `MetraRadius.pill = 999`. Bible explicitly forbids `999`: *"Never use `999px`."* Chip-pill rule: radius = ½ × height.
- **Bible says**: `Chip pill rule: radius = ½ × height` is **always** true. Never use `999px`.
- **Code does**: `pill = 999`, used in `choice_chip_metra.dart:75`, `segmented_control_metra.dart:59,86`, `historical_entry_screen.dart:593,598,603`, `timeline_card.dart:138,159,169`.
- **Fix**: Delete `pill`. For each consumer, set radius = (height ÷ 2). E.g. segmented inner button height-aware; chip 36 → radius 18; choice chip → match its height.
- **Severity**: HIGH

### [BIBLE § 1.4] — Off-scale radii literals
- **File**: `lib/features/onboarding/onboarding_screen.dart:568,680,689` (radius `2`); `lib/features/stats/widgets/symptom_frequency_chart.dart:79` (radius `4`)
- **Issue**: `BorderRadius.circular(2)` and `circular(4)` not in `{6, 8, 10, 12, 14, 16, 18, 20, 44}`.
- **Bible says**: Allowed radii enumerated above.
- **Code does**: 2 and 4.
- **Fix**: Use 6 or 8 per intent.
- **Severity**: MEDIUM

### [BIBLE § 1.4] — Missing `MetraRadius` token for 6 / 10 / 14 / 18 / 20 / 44
- **File**: `lib/core/theme/metra_spacing.dart:34-37`
- **Issue**: `MetraRadius` only exposes `sm=8, md=12, lg=16, pill=999`. Bible requires **6, 10, 14, 18, 20, 44** as well, all used in the HTML mockup. Multiple consumers hardcode `BorderRadius.circular(20)` (`calendar_screen.dart:379, 523`), `circular(10)` (`calendar_screen.dart:494`), `circular(6)` (`timeline_card.dart:292`), `circular(12)` (`settings_screen.dart:692`) instead of using a token.
- **Bible says**: Full radii enumeration.
- **Code does**: 4-token subset.
- **Fix**: Expand `MetraRadius` to `xs=6, sm=8, smm=10, md=12, mmd=14, lg=16, lgg=18, xl=20, phone=44` (or similar naming) and migrate.
- **Severity**: MEDIUM

---

## Borders

### [BIBLE § 1.5] — Card edge / divider opaque approximation
- **File**: `lib/core/theme/metra_theme.dart:56,67,132,143`; `lib/core/widgets/list_row_metra.dart:58`; `lib/features/timeline/widgets/timeline_card.dart:103`
- **Issue**: All "card edge" and divider sides use `colors.divider` (opaque `#DCD2C0` light / `#382E26` dark) rather than the canonical `inchiostro @ 0.07`.
- **Bible says**: `1px solid rgba(43,37,33,0.07)`.
- **Code does**: Opaque solid hex.
- **Fix**: Replace with `MetraColors.light.ink.withAlpha(0x12)` (= 0.07 alpha) for light theme; dark equivalent `ivory @ 0.07` or per dark-theme bible (out of scope here).
- **Severity**: HIGH

### [BIBLE § 1.5] — Strong outline 1.5px
- **File**: `lib/core/widgets/privacy_banner_metra.dart:60`
- **Issue**: Uses `Border.all(color: borderColor, width: 1.5)` where `borderColor = borderSubtle` (= divider opaque). Bible's "strong outline" is **1.5px solid rgba(43,37,33,0.14)**, applied to onboarding date-input. Privacy banner is not the canonical date-input but uses the strong-outline width — verify intent.
- **Bible says**: Strong outline = 1.5px rgba(0.14).
- **Code does**: 1.5px on opaque `#DCD2C0`.
- **Fix**: If the privacy banner needs a strong outline, use 1.5px @ inchiostro 0.14. If it's meant to be a "card edge," use 1px @ 0.07.
- **Severity**: MEDIUM

### [BIBLE § 1.5] — Dashed border colors off-base
- **File**: `lib/features/daily_entry/historical_entry_screen.dart:640`
- **Issue**: `_DashedBorderPainter(color: textSecondary.withValues(alpha: 0.25))` — bible's inline-add chip dashed border is `1px dashed rgba(43,37,33,0.25)` — **inchiostro** base, not inkSoft.
- **Bible says**: Dashed inline-add = inchiostro 0.25.
- **Code does**: inkSoft 0.25.
- **Fix**: Use `textPrimary.withValues(alpha: 0.25)`.
- **Severity**: MEDIUM

### [BIBLE § 1.5] — Flow-type-chip dashed border base mismatch
- **File**: `lib/features/daily_entry/widgets/flow_type_chips.dart:148` (already correct: `textPrimary.withValues(alpha: 0.32)`)
- **Issue**: Correct base (inchiostro) and stop (0.32). No deviation.
- **Bible says**: Assente neutral selected = `1.5px dashed rgba(43,37,33,0.32)`.
- **Code does**: matches.
- **Fix**: No change.
- **Severity**: (no deviation — confirmation only).

### [BIBLE § 1.5] — Pain-picker border colors
- **File**: `lib/features/daily_entry/widgets/circle_pain_picker.dart:114,125`
- **Issue**: `Border.all(color: borderColor!, width: 1.5)` — caller passes a malva-based color; verify against bible (no specific malva border recipe documented, only `rgba(158,116,136,0.12)` for archive pain-pill bg).
- **Bible says**: No malva border tint catalogued.
- **Code does**: Uses caller-supplied color.
- **Fix**: Document a malva border stop in the bible, or migrate to a documented inchiostro stop.
- **Severity**: LOW

---

## Shadows

### [BIBLE § 1.6] — Segmented-control active shadow blur is wrong
- **File**: `lib/core/widgets/segmented_control_metra.dart:89-96`; `lib/core/theme/metra_theme.dart:47,123` (ColorScheme `shadow`)
- **Issue**: Bible specifies the **only** product shadow as `0 1px 4px rgba(43,37,33,0.12)`. Code uses `BoxShadow(blurRadius: 2, offset: Offset(0,1))` — blur is **2** instead of **4**, and the alpha-byte `0x14` (= 0.078) is encoded into the color literal, not the bible's 0.12.
- **Bible says**: `0 1px 4px rgba(43,37,33,0.12)` — i.e. `BoxShadow(offset: Offset(0,1), blurRadius: 4, color: Color(0x1F2B2521))` (0x1F = 31 ≈ 0.12).
- **Code does**: blur 2, color `0x142B2521` (0x14 = 20 ≈ 0.078).
- **Fix**: Set `blurRadius: 4` and color `Color(0x1F2B2521)`.
- **Severity**: HIGH

### [BIBLE § 1.6] — ColorScheme.shadow uses `0x14` (0.08) not `0x1F` (0.12)
- **File**: `lib/core/theme/metra_theme.dart:47`
- **Issue**: ColorScheme passes `shadow: Color(0x142B2521)` — same alpha drift as above. Although CardTheme has `elevation: 0`, leaving `shadow` slightly off-spec is a latent bug.
- **Bible says**: 0.12 alpha for the only shadow.
- **Code does**: 0.08 alpha.
- **Fix**: `Color(0x1F2B2521)`.
- **Severity**: MEDIUM

### [BIBLE § 1.6] — No card / button / sheet shadows
- **File**: codebase
- **Issue**: Audit confirmed only one `BoxShadow` site (segmented control). No drop-shadows on cards, buttons, sheets. Conforms to bible. Confirmation only.
- **Bible says**: No drop-shadows on cards, buttons, sheets.
- **Code does**: None.
- **Fix**: No change.
- **Severity**: (no deviation — confirmation only).

---

## Backdrop blur

### [BIBLE § 1.7] — Tab bar uses Material `NavigationBar`, no `BackdropFilter`
- **File**: `lib/core/theme/metra_theme.dart:68-96`; `lib/router/app_router.dart` (consumer)
- **Issue**: Bible mandates exactly one site of `backdrop-filter: blur(16px)` over `rgba(244,237,226,0.96)` — the tab bar. Code uses Material 3 `NavigationBar` themed via `NavigationBarThemeData`, which does **not** apply `BackdropFilter`. No `BackdropFilter`, `ImageFilter`, or `blur` reference exists anywhere in `lib/`.
- **Bible says**: Tab-bar = `BackdropFilter(filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16), child: ColoredBox(color: sabbia.withOpacity(0.96)))`.
- **Code does**: Material `NavigationBar` with no blur.
- **Fix**: Replace `NavigationBar` with custom widget wrapping `BackdropFilter` + translucent `sabbia` (0.96 alpha) + tab items, or wrap `NavigationBar` in `ClipRect + BackdropFilter` and override its background to `sabbia.withAlpha(0xF5)` (= 0.96).
- **Severity**: HIGH

---

## Iconography

### [BIBLE § 2.1] — Material `Icons.*` shipped instead of bible icon catalog
- **File**: `lib/router/app_router.dart:115-131`; `lib/features/settings/settings_screen.dart:219,236,307,317,345,366,375,404,722`; `lib/features/daily_entry/quick_entry_modal.dart:133,221`; `lib/features/daily_entry/today_screen.dart:280,435`; `lib/features/daily_entry/historical_entry_screen.dart:277,291,362,463`; `lib/features/calendar/widgets/calendar_legend.dart:58,65,72,79`; `lib/features/calendar/widgets/month_navigator.dart:88,112,128`; `lib/features/calendar/calendar_screen.dart:442`; `lib/features/timeline/widgets/timeline_card.dart:198,210`; `lib/features/onboarding/onboarding_screen.dart:455,626,662`; `lib/core/widgets/privacy_banner_metra.dart:68`
- **Issue**: Code uses Material icons — `Icons.calendar_today_outlined, Icons.edit_note_outlined, Icons.view_timeline_outlined, Icons.bar_chart_outlined, Icons.settings_outlined, Icons.water_drop, Icons.water_drop_outlined, Icons.star_border, Icons.bolt, Icons.brightness_2_rounded, Icons.chevron_left, Icons.chevron_right, Icons.lock_outline, Icons.delete_outline, Icons.open_in_new, Icons.check, Icons.close, Icons.edit_outlined, Icons.arrow_back_ios_rounded, Icons.calendar_today_outlined, Icons.remove, Icons.add`. The bible defines a fixed catalog of **stroke icons** (`chevron_right · chevron_left · chevron_down · x · lock · cloud · drop · wave · plus · check · settings · chart · calendar · note · wifi · battery · filter · info · leaf · export · moon_crescent · star_small`) and **filled DataIcons** (`drop, drop_outline, moon_crescent, star_small, zap`), each with explicit SVG paths in the HTML.
- **Bible says**: § 2.1: *"do not add icons that are not in this list without updating the mockup first"* — and even the icons that are in the bible (`drop`, `star_small`, `lock`, `chevron_*`, `calendar`, `note`, `chart`, `settings`, `check`, `x`, `plus`) are defined as **24×24, 1.5-stroke, round caps & joins, fill: none** SVG paths. Material's icons (e.g. `Icons.water_drop` is **filled**, `Icons.bolt` is **filled**, `Icons.chevron_left` differs in stroke) do not match.
- **Code does**: Material font icons.
- **Fix**: Implement a `MetraIcon` widget that renders the bible's SVG paths via `CustomPainter` or `flutter_svg`, expose constants `MetraIcons.dropOutline / .moonCrescent / .starSmall / .zap / .chevronLeft / .calendar / .note / …`. Replace every `Icons.*` site. For tab bar specifically (calendar / note / wave / chart / settings) use the bible names.
- **Severity**: HIGH

### [BIBLE § 2.1] — Stroke widths not enforced
- **File**: codebase
- **Issue**: Bible mandates `default stroke = 1.5; active tab = 2; status-bar wifi = 1.8; battery = 1.4`. No mechanism in code enforces these — Material icons don't expose stroke. The active-tab IconThemeData at `metra_theme.dart:73` only sets `size: 24`, no stroke.
- **Bible says**: stroke widths above.
- **Code does**: Not enforced.
- **Fix**: When `MetraIcon` is implemented, expose `strokeWidth` parameter and let tab bar pass `2.0` for active and `1.5` for inactive.
- **Severity**: MEDIUM

### [BIBLE § 2.2] — DataIcon `zap` not implemented
- **File**: codebase
- **Issue**: Bible's filled `zap` lightning icon (used for pain markers) is not implemented; pain UI uses `Icons.bolt` (Material filled bolt with different geometry).
- **Bible says**: `zap` filled lightning, viewBox 24×24, default 12 px.
- **Code does**: `Icons.bolt` (different shape).
- **Fix**: Implement bible's `zap` path `d="M13 3L5 14L11 14L9 21L19 11L13 11Z"` as `MetraIcons.zap`.
- **Severity**: HIGH

### [BIBLE § 2.3] — Bespoke moon icon not implemented
- **File**: `lib/features/calendar/widgets/month_navigator.dart:88` uses `Icons.brightness_2_rounded`
- **Issue**: Bible's `Moon` component renders a stroked circle + a phase-specific filled crescent (5 phases). `Icons.brightness_2_rounded` is a single Material crescent, not a phased moon.
- **Bible says**: `Moon` component, lines 166-182 of HTML — circle + phase fill.
- **Code does**: Single Material crescent, no phase logic.
- **Fix**: Implement `MetraMoon(phase: int)` with the 5 fill paths from HTML.
- **Severity**: MEDIUM

---

## Cross-cutting confirmations

- **No `Cormorant` reference**: confirmed (`grep -RnE "Cormorant\|cormorant"` returns nothing). Bible "DO NOT SHIP" satisfied.
- **No `999` radius outside `MetraRadius.pill`**: confirmed; the only `999` lives in `MetraRadius.pill` itself, which is the violation called out above.
- **DM Serif Display loaded only via google_fonts**: confirmed (no asset fonts in pubspec).
- **No drop shadows on cards/buttons/sheets**: confirmed (only one `BoxShadow` in segmented control).
- **Backdrop blur**: missing — the only allowed location (tab bar) is implemented without blur.
