# Today / Daily entry — audit findings (Design Bible 2026-05-01)

**Severity summary**
- HIGH: 11 — section-frame structure missing (bg/dividers), choice-chip radius/height, inline-add affordance off-spec, save CTA height/icon/padding, flow/pain dot SVG geometry off, notes hint ellipsis ASCII, symptom row missing 44dp tap-target wrapper, hint-box styling missing, header padding wrong.
- MEDIUM: 9 — section-label spacing/letter-spacing off, secondary-color use for inline-add label, flow halo opacity, spotting/assente hints missing background and icon-spec, notes textarea border/min-height, today_notes_hint l10n ellipsis, custom-symptom mechanics, flow-chip text colour idle uses textSecondary not rgba(0.42), assente confirmation icon colour.
- LOW: 5 — semantics/divider niceties, custom-symptom dedupe, ConstrainedBox on input width, wordmark-unrelated cosmetic mismatches.

---

## Container / Header

### [BIBLE § 9.1] — Screen container missing 100 px bottom padding
- **File**: `lib/features/daily_entry/today_screen.dart:213`
- **Issue**: `SingleChildScrollView` only sets `EdgeInsets.symmetric(horizontal: 24)`; bottom padding `100` (bible § 9.1) is replaced by a fixed-height save button outside the scroll view. The scroll body therefore has no breathing room behind the tab bar.
- **Bible says**: `padding-bottom 100` on the scrolling container so content can scroll past the 84 px tab-bar overlay.
- **Code does**: zero bottom padding inside scroll; save CTA is in the layout column instead of overlaying.
- **Fix**: Move save CTA into the scroll content (or a `Stack`) and set `padding: EdgeInsets.fromLTRB(24, 0, 24, 100)` on the scroll view. Remove the `Column` + `Expanded` wrapper that pins the CTA above the tab bar.
- **Severity**: HIGH

### [BIBLE § 9.2] — Header padding wrong
- **File**: `lib/features/daily_entry/today_screen.dart:214-220`
- **Issue**: Header (`dateStr`, `today_how_are_you`) shares the screen's `horizontal: 24` and adds a generic `s6 (24)` top spacer before subtitle and `s6 (24)` after the title. Bible § 9.2 specifies `padding 12 / 24 / 16` (top/horiz/bottom) for the header block, distinct from the section frames.
- **Bible says**: Header padding `12 / 24 / 16` — i.e. 12 above subtitle, 16 below title.
- **Code does**: 24 above subtitle (`SizedBox s6`), 16 below the title (`s6` not s4 — but actually `s6 = 24`).
- **Fix**: Set top spacer to `12`, bottom-of-header spacer to `16`. Consider extracting a header widget that renders its own padding.
- **Severity**: HIGH

### [BIBLE § 9.2] — Subtitle uses `MetraTypography.caption` (Inter 13 letterSpacing 0.13) instead of plain Inter 13
- **File**: `lib/features/daily_entry/today_screen.dart:221-226`
- **Issue**: Bible specifies `Inter 13 rgba(0.68)` for the subtitle. `MetraTypography.caption` adds `letterSpacing 0.13` and `height 1.4`; these are not in the bible spec.
- **Bible says**: `Inter 13 rgba(43,37,33,0.68)` (no extra letter-spacing called out for body/caption).
- **Code does**: `MetraTypography.caption` (Inter 13, lineHeight 1.4, letterSpacing 0.13) coloured `textSecondary` (`#5A4F47`, ~rgba(0.65)). Letter-spacing `0.13` adds visible tracking.
- **Fix**: Drop `letterSpacing` for header subtitle; use `GoogleFonts.inter(fontSize: 13)` directly or strip `letterSpacing` from `caption` for this site.
- **Severity**: MEDIUM

### [BIBLE § 9.2] — Title uses `displayMd` (32 px) instead of `titleLg` (26 px)
- **File**: `lib/features/daily_entry/today_screen.dart:228-233`
- **Issue**: Bible says title is `DM Serif Display 26 inchiostro`. `MetraTypography.displayMd` is 32 px (per `metra_typography.dart:37-41`). The correct token is `titleLg` (26 px).
- **Bible says**: `DM Serif Display 26 inchiostro` ("Come stai oggi?").
- **Code does**: `displayMd` = 32 px.
- **Fix**: Replace `MetraTypography.displayMd` with `MetraTypography.titleLg`.
- **Severity**: HIGH

### [BIBLE § 9.3] — Section frame structure missing
- **File**: `lib/features/daily_entry/today_screen.dart:236-415`
- **Issue**: Sections are flat content separated by `Divider`s and `SizedBox(s6)` whitespace. Bible § 9.3 requires each section to be a discrete frame: `bg surface (#FBF6EC)`, top + bottom `1 px rgba(0.07)` borders, padding `18 / 24`, `gap 1` between sections (so the borders touch). The current screen has no surface backing for sections — the sand background bleeds through.
- **Bible says**: `bg surface · borderTop/borderBottom 1px solid rgba(43,37,33,0.07) · padding 18/24 · gap 1`.
- **Code does**: No surface fill; no inner padding 18/24; vertical separation `s6 + 1px divider + s6 = 49 px` instead of 1 px between adjacent sections.
- **Fix**: Wrap each section (Flusso, Dolore, Sintomi, Nota) in a `Container(color: bgSurface, padding: EdgeInsets.symmetric(vertical:18, horizontal:24), decoration: ... topBorder + bottomBorder)`. Set `gap 1` between sections.
- **Severity**: HIGH

### [BIBLE § 9.3] — Section-label letter-spacing wrong
- **File**: `lib/features/daily_entry/today_screen.dart:201-205`
- **Issue**: Section labels use `MetraTypography.caption` (Inter 13) `+ fontWeight 600 + letterSpacing 1.2`. Bible says `Inter 12 weight 600 letter-spacing 0.06em UPPERCASE rgba(0.40)`. 0.06em on 12 px = `0.72` — code uses absolute `1.2` which equals 0.10em, ~67 % too wide; size is 13, not 12.
- **Bible says**: `Inter 12 weight 600 letter-spacing 0.06em color rgba(43,37,33,0.40)`, marginBottom 14 (12 for note section).
- **Code does**: Inter 13 weight 600 letter-spacing 1.2 colored `textSecondary` (`#5A4F47`, rgba ~0.65 — too dark).
- **Fix**: Build a dedicated style: `GoogleFonts.inter(fontSize: 12, fontWeight: w600, letterSpacing: 12 * 0.06, color: textPrimary.withValues(alpha: 0.40))`. Use `s4 (16)` margin (close to spec 14) or introduce a `s14` token; use `s3 (12)` for note section.
- **Severity**: MEDIUM

### [BIBLE § 9.3] — Section-label margin uses `s4 (16)` not 14
- **File**: `lib/features/daily_entry/today_screen.dart:241,300,314,384`
- **Issue**: All section labels use `SizedBox(height: MetraSpacing.s4)` (16 px) before content. Bible says `marginBottom 14` for Flusso/Dolore/Sintomi and `12` for Nota. Code uses 16/16/16/16.
- **Bible says**: 14 px between section label and content (12 for Nota).
- **Code does**: 16 px everywhere.
- **Fix**: Hard-code `SizedBox(height: 14)` for Flusso/Dolore/Sintomi; `12` for Nota. Or add `s_label_gap` constants.
- **Severity**: LOW

---

## FlowTypeChips (§ 7.1)

### [BIBLE § 7.1] — Idle text colour not rgba(0.42)
- **File**: `lib/features/daily_entry/widgets/flow_type_chips.dart:182`
- **Issue**: Idle chip text uses `textSecondary` = `#5A4F47` (rgba(0.65)). Bible says idle text is `rgba(43,37,33,0.42)`.
- **Bible says**: Idle text `rgba(43,37,33,0.42) weight 400`.
- **Code does**: `textSecondary` (alpha ≈ 0.65) and weight 500 (via `_ChipContent` which forces `w500`).
- **Fix**: Use `textPrimary.withValues(alpha: 0.42)` and `FontWeight.w400` for idle; only switch to `w500` when selected.
- **Severity**: MEDIUM

### [BIBLE § 7.1] — Selected chip text colour wrong for mestruazioni / spotting
- **File**: `lib/features/daily_entry/widgets/flow_type_chips.dart:182`
- **Issue**: Selected `mestruazioni` and `spotting` chips render text in `textPrimary` (ink). Bible says those two chips' selected text is `tc_scura` (terracottaDeep `#9B4E32`).
- **Bible says**: Selected text `tc_scura` for `mestruazioni` and `spotting`; `inchiostro` only for `assente`.
- **Code does**: All three selected variants use `textPrimary`.
- **Fix**: Pass a per-variant colour into `_ChipContent`: `assente → textPrimary`, `mestruazioni / spotting → accentFlowStrong`.
- **Severity**: MEDIUM

### [BIBLE § 7.1 + § 15 ¶11] — Tap target lacks `transition all 0.15s`
- **File**: `lib/features/daily_entry/widgets/flow_type_chips.dart:140-185`
- **Issue**: Chip uses a static `Container`; selection switches instantly. Bible explicitly allows (only) `transition all 0.15s` on chips.
- **Bible says**: `transition all 0.15s` permitted on chip backgrounds.
- **Code does**: No `AnimatedContainer`; selection flips instantly.
- **Fix**: Use `AnimatedContainer(duration: Duration(milliseconds: 150), curve: Curves.linear)` for the bg and border to honour the only sanctioned animation.
- **Severity**: LOW

---

## FlowIntensityDots (§ 7.2)

### [BIBLE § 7.2] — Dot SVG geometry off
- **File**: `lib/features/daily_entry/widgets/flow_intensity_dots.dart:126-152`
- **Issue**: Bible: `SVG box 50 × 50, R 18, padding 7` ⇒ filled circle has diameter 36 inside a 50 box; halo radius `r 23` ⇒ diameter 46. Code uses outer 46 box (halo) and inner 36 circle. The outer SVG box should be **50 × 50**, not 46 × 46. The halo (when present) is r=23 (46 dia) inside that 50 × 50 box, not the box itself.
- **Bible says**: Outer box 50 × 50; halo diameter 46; filled circle diameter 36.
- **Code does**: Outer box 46 × 46; halo and box conflated.
- **Fix**: Wrap dot in a `SizedBox(width: 50, height: 50)`; halo `Container(width: 46, height: 46)`; inner circle `Container(width: 36, height: 36)`.
- **Severity**: HIGH

### [BIBLE § 7.2] — Filled circle missing terracotta stroke (1.4)
- **File**: `lib/features/daily_entry/widgets/flow_intensity_dots.dart:144-151`
- **Issue**: The filled circle has no border. Bible: `stroke terracotta · strokeWidth 1.4` on the filled circle (in addition to the halo).
- **Bible says**: Filled circle: fill terracotta (with opacity), stroke terracotta width 1.4.
- **Code does**: BoxDecoration without `border`.
- **Fix**: Add `border: Border.all(color: accentFlow, width: 1.4)` to the filled circle's `BoxDecoration`.
- **Severity**: HIGH

### [BIBLE § 7.2] — Label gap above is 4 px, bible says 7 px
- **File**: `lib/features/daily_entry/widgets/flow_intensity_dots.dart:155`
- **Issue**: `SizedBox(height: 4)` between dot and label. Bible says `gap 7`.
- **Bible says**: Label `Inter 10 · gap 7 above`.
- **Code does**: `SizedBox(height: 4)`.
- **Fix**: Change to `SizedBox(height: 7)`.
- **Severity**: LOW

### [BIBLE § 7.2] — Label uses `tiny` (12 px) not Inter 10
- **File**: `lib/features/daily_entry/widgets/flow_intensity_dots.dart:158`
- **Issue**: `MetraTypography.tiny` is `fontSize: 12`. Bible says label is `Inter 10`.
- **Bible says**: `Inter 10`.
- **Code does**: 12 px (`tiny`) with weight 500 baseline.
- **Fix**: Use `GoogleFonts.inter(fontSize: 10)`; override weight to w400 idle / w600 selected.
- **Severity**: MEDIUM

### [BIBLE § 7.2] — Selected label uses `accentFlowStrong`, bible says `tc_scura`
- **File**: `lib/features/daily_entry/widgets/flow_intensity_dots.dart:160`
- **Issue**: `accentFlowStrong` *is* `terracottaDeep` so this matches by alias (`tc_scura == terracottaDeep`). No deviation. **No deviations found** for this point. *(Kept here to acknowledge investigation.)*

### [BIBLE § 7.2] — Halo opacity / strokeWidth correct, but halo r should be 23 not 46/2
- **File**: `lib/features/daily_entry/widgets/flow_intensity_dots.dart:132-143`
- **Issue**: Halo container is 46 × 46 with border 1.2 alpha 0.30 ⇒ visual radius 23. Matches.
- **No deviations found.**

### [BIBLE § 7.2 / DM-02 / UX-02] — `_lastMensIntensity` correctly preserved across flow type switches
- **File**: `lib/features/daily_entry/today_screen.dart:246-257`
- **Issue**: When switching away from `mestruazioni`, `_flowIntensity` is preserved in `_lastMensIntensity` and restored on return. Save handler nulls `flowIntensity` unless `flowType == mestruazioni` (line 115). Matches DM-02 and UX-02.
- **No deviations found.**

---

## PainDots (§ 7.3)

### [BIBLE § 7.3] — Dot SVG geometry off (same as flow dots)
- **File**: `lib/features/daily_entry/widgets/circle_pain_picker.dart:107-133`
- **Issue**: Outer container 48 × 48, halo 46 × 46, filled circle 36. Bible specifies outer SVG box `50 × 50` (matching flow dots), halo `r 23` (46 dia), filled `r 18` (36 dia). 48 vs 50 is close but inconsistent; bible explicitly says "Same SVG geometry as flow dots".
- **Bible says**: Outer box 50 × 50.
- **Code does**: Outer box 48 × 48.
- **Fix**: `SizedBox(width: 50, height: 50)`.
- **Severity**: LOW

### [BIBLE § 7.3] — Filled circle missing malva stroke (1.5)
- **File**: `lib/features/daily_entry/widgets/circle_pain_picker.dart:107-117`
- **Issue**: Filled pain circle has only a `borderColor` for level 0 (`showBorder=true` and not selected) and no stroke for levels 1–3. Bible: `strokeWidth 1.5`, color `malva` on the filled circle.
- **Bible says**: Filled circle stroke = malva, strokeWidth 1.5.
- **Code does**: No stroke for levels 1–3; the `Black26` border at level 0 differs from spec (level 0 fill is opacity 0, but stroke must still be malva 1.5).
- **Fix**: Always render the filled circle with `Border.all(color: accent, width: 1.5)`. For level 0, set fill alpha 0 (= transparent) but keep the malva stroke.
- **Severity**: HIGH

### [BIBLE § 7.3] — "Nessuno" circle uses `bgPrimary` fill + black26 border
- **File**: `lib/features/daily_entry/widgets/circle_pain_picker.dart:66`
- **Issue**: Level 0 dot is rendered with `bgPrimary` (sand) fill and `Colors.black26` border. Bible: level 0 is malva-stroked outlined circle with fillOpacity 0.00 (i.e. transparent fill, malva stroke).
- **Bible says**: Level 0 = `fillOpacity 0.00`, stroke malva 1.5 (same as the others, just with transparent fill).
- **Code does**: Sand-coloured fill, `Colors.black26` border (1.5 px).
- **Fix**: Use `Colors.transparent` (or `accent.withValues(alpha:0)`) as fill; drop the `showBorder` branch and always border with malva 1.5.
- **Severity**: HIGH

### [BIBLE § 7.3] — Halo opacity 0.28 — matches; ✓
- **No deviations found.**

### [BIBLE § 7.3] — Idle label colour rgba(0.40), bible says rgba(0.38)
- **File**: `lib/features/daily_entry/widgets/circle_pain_picker.dart:150`
- **Issue**: Code uses `textPrimary.withValues(alpha: 0.38)` — actually matches bible (`rgba(43,37,33,0.38)`). ✓
- **No deviations found.**

### [BIBLE § 7.3 / CL-02] — Pain levels labels match
- **Bible says**: 0 Nessuno (0.00) / 1 Lieve (0.28) / 2 Moderato (0.60) / 3 Intenso (0.92).
- **Code does**: Matches at `circle_pain_picker.dart:66-72`.
- **No deviations found.**

### [BIBLE § 7.3] — Label uses `tiny` (12 px) — bible says Inter 10
- **File**: `lib/features/daily_entry/widgets/circle_pain_picker.dart:149`
- **Issue**: `MetraTypography.tiny` = 12 px; flow dots and pain dots both render labels via `tiny`. Bible (§ 7.2) says label is `Inter 10`. § 7.3 inherits geometry "same as flow dots" — implies same Inter-10 label.
- **Bible says**: Inter 10.
- **Code does**: 12 px (`tiny`).
- **Fix**: Use `GoogleFonts.inter(fontSize: 10)`.
- **Severity**: MEDIUM

---

## Hint boxes (§ 7.4)

### [BIBLE § 7.4 — Spotting hint] — Box styling missing entirely
- **File**: `lib/features/daily_entry/today_screen.dart:267-275`
- **Issue**: The spotting note is rendered as a plain `Text` styled with `caption + textSecondary`. Bible mandates a styled hint box: `marginTop 14 · padding 11/14 · radius 10 · bg ${terracotta}0D · border 1px ${terracotta}28 · text Inter 12 line-height 1.55 rgba(0.65)`.
- **Bible says**: Filled / bordered hint box, terracotta-tinted background, with specific paddings and typography.
- **Code does**: Plain `Text(l10n.daily_entry_spotting_note, style: caption + textSecondary)` with only `s3 (12)` top spacer.
- **Fix**: Wrap in `Container(margin: EdgeInsets.only(top:14), padding: EdgeInsets.symmetric(vertical:11, horizontal:14), decoration: BoxDecoration(color: accentFlow.withValues(alpha:0.05), border: Border.all(color: accentFlow.withValues(alpha:0.157), width:1), borderRadius: BorderRadius.circular(10)))` with `Inter 12 height 1.55 color textPrimary.withValues(alpha:0.65)` text.
- **Severity**: HIGH

### [BIBLE § 7.4 — Spotting hint copy] — CL-04 verbatim copy
- **File**: `lib/l10n/app_it.arb:902`
- **Issue**: ARB string equals bible verbatim ("Piccola perdita fuori dal flusso mestruale. Non è necessariamente l'inizio del ciclo."). ✓
- **No deviations found.**

### [BIBLE § 7.4 — Assente hint] — Icon colour wrong
- **File**: `lib/features/daily_entry/today_screen.dart:280`
- **Issue**: `Icon(Icons.check, color: accentFlow, size: 16)` — bible says icon is `check 16 stroke rgba(0.35) weight 2`. Code uses terracotta (accentFlow), wrong colour and weight not configurable on Material icons.
- **Bible says**: stroke `rgba(43,37,33,0.35)` weight 2.
- **Code does**: Terracotta filled Material icon.
- **Fix**: Use a stroke-style icon (`Icons.check` is filled by default). Either swap to Cupertino `CupertinoIcons.check_mark` or a custom 2-px-stroke SVG, with `color: textPrimary.withValues(alpha:0.35)`.
- **Severity**: MEDIUM

### [BIBLE § 7.4 — Assente hint text] — Colour wrong
- **File**: `lib/features/daily_entry/today_screen.dart:282-287`
- **Issue**: Text uses `MetraTypography.caption + textPrimary`. Bible: `Inter 12 rgba(0.45)`.
- **Bible says**: `Inter 12 color rgba(43,37,33,0.45)`.
- **Code does**: 13 px (`caption`) coloured `textPrimary` (full ink).
- **Fix**: `GoogleFonts.inter(fontSize: 12, color: textPrimary.withValues(alpha:0.45))`.
- **Severity**: MEDIUM

### [BIBLE § 7.4 — Assente hint] — `s2` gap, bible says 8
- **File**: `lib/features/daily_entry/today_screen.dart:281`
- **Issue**: `MetraSpacing.s2 = 8`. Matches.
- **No deviations found.**

### [BIBLE § 7.4 — Assente hint] — marginTop is `s3 (12)`, bible says 14
- **File**: `lib/features/daily_entry/today_screen.dart:277`
- **Issue**: `s3 (12)` between flow chips and the assente hint. Bible says 14.
- **Bible says**: `marginTop 14`.
- **Code does**: 12.
- **Fix**: `SizedBox(height: 14)`.
- **Severity**: LOW

---

## Symptoms / ChoiceChip (§ 6.1, § 9.6)

### [BIBLE § 6.1] — Choice chip height & radius wrong
- **File**: `lib/core/widgets/choice_chip_metra.dart:60-82`
- **Issue**: Chip is built with `ConstrainedBox(minWidth: 44, minHeight: 44)` wrapping a `Padding(symmetric(h:16, v:8))` `Container`. Bible says **chip itself** is `height 36 · paddingInline 14 · radius 18`. The 44 × 44 minimum is correct as the *tap target*, but the chip rectangle should be 36 tall, padded 14 horizontally; the 44dp area should be a transparent expansion (UX-03). Currently the visible chip can be larger than 36 due to vertical 8 padding on caption text whose lineHeight 1.4 × 13 = 18.2; total ≈ 34.2 inside the 44-min. Acceptable visually only if the inner box is forced to 36.
- **Bible says**: Chip: height 36, paddingInline 14, radius 18.
- **Code does**: Chip rectangle has `padding(h:16, v:8)` (16 ≠ 14), no fixed height.
- **Fix**: `Container(height: 36, padding: EdgeInsets.symmetric(horizontal: 14), alignment: Alignment.center)` inside a `SizedBox(height: 44)` tap-target wrapper.
- **Severity**: HIGH

### [BIBLE § 6.1] — Radius `pill` (999) violates anti-pattern 10
- **File**: `lib/core/widgets/choice_chip_metra.dart:75`
- **Issue**: Uses `MetraRadius.pill = 999`. Bible § 15 ¶10: "No `999px` pill radius. Use `½ × height`". For height 36 → radius 18.
- **Bible says**: `radius 18` (= ½ × 36).
- **Code does**: 999.
- **Fix**: `BorderRadius.circular(18)` (or add `MetraRadius.chip = 18`).
- **Severity**: HIGH

### [BIBLE § 6.1] — Unselected text colour `inchiostro`, code uses textPrimary — ✓ but border alpha rounding
- **File**: `lib/core/widgets/choice_chip_metra.dart:79`
- **Issue**: Border alpha 0.12 / bg alpha 0.07 — match bible.
- **No deviations found.**

### [BIBLE § 6.1 / § 15 ¶11] — Missing `transition all 0.15s`
- **File**: `lib/core/widgets/choice_chip_metra.dart:66`
- **Issue**: Chip is a static `Container` — no animation. Bible explicitly mandates `transition all 0.15s`.
- **Bible says**: `transition all 0.15s`.
- **Code does**: Static.
- **Fix**: Use `AnimatedContainer(duration: Duration(milliseconds:150))`.
- **Severity**: LOW

### [BIBLE § 9.6 / UX-03] — Symptom row missing 44dp tap-target wrapper
- **File**: `lib/features/daily_entry/today_screen.dart:315-374`
- **Issue**: The chips are placed directly in a `Wrap`. Bible § 9.6: each chip wrapped in `min-height 44 row centered`. Inside `ChoiceChipMetra` there is a `ConstrainedBox(minWidth/minHeight:44)`, but it pads the *chip* rather than ensuring a row-wide tap-strip; multi-line wraps will still leave 8 px gaps.
- **Bible says**: Each chip wrapped in `min-height 44 row centered`.
- **Code does**: Single ConstrainedBox per chip (the chip itself); no row container.
- **Fix**: Either keep the current `ConstrainedBox` and assert tests, or wrap each `ChoiceChipMetra` in a `SizedBox(height: 44, child: Center(child: …))` and let the chip be 36 tall.
- **Severity**: HIGH

### [BIBLE § 9.6 / CL-03] — Default symptoms order matches bible verbatim
- **File**: `lib/features/daily_entry/today_screen.dart:155-163`
- **Issue**: Order: cramps, headache, fatigue, backPain, nausea, bloating, breastTenderness ⇒ "Crampi · Mal di testa · Stanchezza · Mal di schiena · Nausea · Gonfiore · Tensione mammaria". ✓
- **No deviations found.**

### [BIBLE § 9.6] — Custom symptom mechanics broken
- **File**: `lib/features/daily_entry/today_screen.dart:354-372`
- **Issue**: Adding a custom symptom adds a single `PainSymptomType.custom` enum value to `_selectedSymptoms`; no chip is shown for it (the `_symptomTypes` whitelist excludes `custom`), and the typed text is discarded. Adding a second custom symptom is impossible (set semantics dedupe). Bible says custom symptoms *append after the predefined list* — implying the user can have multiple distinct custom labels.
- **Bible says**: "Custom symptoms append after the predefined list."
- **Code does**: Custom symptom only adds one opaque enum, no rendering, no name persisted.
- **Fix**: Persist user-typed labels (e.g. as a `List<String>` of customLabels alongside the enum set); render each as an additional choice chip after the predefined list. Update `replacePainSymptoms` to round-trip names.
- **Severity**: MEDIUM (functional bug + bible mismatch)

---

## Inline "Aggiungi" affordance (§ 6.2)

### [BIBLE § 6.2] — Idle affordance missing `+` glyph and proper layout
- **File**: `lib/features/daily_entry/today_screen.dart:520-545`
- **Issue**: `_AddSymptomChip` renders only the localized label (`+ Aggiungi`, embedded as a single string in `app_it.arb:927`). Bible: separate `+` Inter 18 rgba(0.35) and label "Aggiungi" Inter 13 rgba(0.40), both inside a chip-shaped dashed box.
- **Bible says**: Glyph `+` Inter 18 rgba(0.35) AND label "Aggiungi" Inter 13 rgba(0.40) (two separate text spans).
- **Code does**: Single `Text("+ Aggiungi", style: body=16)` in `textSecondary`.
- **Fix**: Render row with `[Text("+", style: Inter 18 rgba(0.35)), SizedBox(width:?), Text("Aggiungi", style: Inter 13 rgba(0.40))]`. Update `today_add_symptom` ARB to just `Aggiungi`.
- **Severity**: HIGH

### [BIBLE § 6.2] — Idle dashed border alpha & radius
- **File**: `lib/features/daily_entry/today_screen.dart:547-587`
- **Issue**: `_DashedBorderPainter` uses `color: textSecondary` (alpha ~0.65) with strokeWidth 1.0 and radius 20. Bible: `1px dashed rgba(43,37,33,0.25)`, radius 18 (chip radius).
- **Bible says**: `border 1px dashed rgba(43,37,33,0.25)`, radius 18.
- **Code does**: alpha ~0.65, radius 20.
- **Fix**: `color: textPrimary.withValues(alpha:0.25)`, `radius: 18`.
- **Severity**: MEDIUM

### [BIBLE § 6.2] — Idle dimensions wrong (height 36, paddingInline 14)
- **File**: `lib/features/daily_entry/today_screen.dart:533-541`
- **Issue**: Padding is `symmetric(h:16, v:8)` and there is no fixed height. Bible: height 36, paddingInline 14.
- **Bible says**: height 36, paddingInline 14.
- **Code does**: padding 16 / 8, intrinsic height.
- **Fix**: `Container(height: 36, padding: EdgeInsets.symmetric(horizontal: 14))` like the choice chip.
- **Severity**: HIGH

### [BIBLE § 6.2 — Editing] — `border 1.5px solid terracotta`, code uses subtle gray
- **File**: `lib/features/daily_entry/today_screen.dart:482-496`
- **Issue**: `_InlineSymptomInput` uses `OutlineInputBorder` with `BorderSide(color: textSecondary.withValues(alpha:0.25))` for enabled and `0.5` for focused. Bible: editing border is `1.5px solid terracotta`, with `bg ${terracotta}0D` fill.
- **Bible says**: `border 1.5px solid terracotta · bg ${terracotta}0D`.
- **Code does**: gray border, no fill.
- **Fix**: Use terracotta border and `accentFlow.withValues(alpha: 0.05)` background.
- **Severity**: HIGH

### [BIBLE § 6.2 — OK pill] — Bible says terracotta filled pill 36 × paddingInline 12, code is plain TextButton
- **File**: `lib/features/daily_entry/today_screen.dart:500-513`
- **Issue**: The trailing OK is a `TextButton` with grey "OK" text — not the spec's terracotta filled pill `paddingInline 12 · height 36 · bg terracotta · text sabbia 13/500`.
- **Bible says**: terracotta filled pill, sabbia text.
- **Code does**: TextButton with grey text.
- **Fix**: Replace with `Container(height:36, padding: EdgeInsets.symmetric(horizontal:12), decoration: BoxDecoration(color: accentFlow, borderRadius: BorderRadius.circular(18)), child: Text("OK", style: Inter 13 w500 sabbia))` wrapped in a `GestureDetector`.
- **Severity**: HIGH

### [BIBLE § 6.2] — Escape key not handled
- **File**: `lib/features/daily_entry/today_screen.dart:467-498`
- **Issue**: `onSubmitted` confirms (Enter), but Escape is not bound. Bible: `Escape discards`.
- **Bible says**: Pressing `Escape` discards.
- **Code does**: No Escape handler.
- **Fix**: Wrap input in a `Focus` / `KeyboardListener` and call `onCancel()` on `LogicalKeyboardKey.escape`.
- **Severity**: LOW

### [BIBLE § 6.2] — Empty / duplicate dismiss silently — only empty handled
- **File**: `lib/features/daily_entry/today_screen.dart:354-366`
- **Issue**: Empty text dismisses without adding (✓), but duplicate detection is absent (and impossible because typed labels aren't stored).
- **Bible says**: Empty/duplicate inputs silently dismiss.
- **Code does**: Empty: dismiss. Duplicate: not detected.
- **Fix**: Once custom labels are persisted (see § 9.6 fix above), check `customLabels.contains(text)` and dismiss without insert.
- **Severity**: LOW

### [BIBLE § 6.2 — Input] — `width 110 placeholder "es. Vertigini"`
- **File**: `lib/features/daily_entry/today_screen.dart:465-499`
- **Issue**: `ConstrainedBox(minWidth:100, maxWidth:160)` instead of fixed 110. Placeholder hard-coded `"es. Vertigini"` (matches bible) but should ideally be l10n. Style uses caption (13) — matches.
- **Bible says**: `width 110 placeholder "es. Vertigini"`.
- **Code does**: 100–160 range; placeholder copy matches.
- **Fix**: `ConstrainedBox(width: 110)` (or `SizedBox(width: 110)`); add ARB key for the placeholder.
- **Severity**: LOW

---

## Note textarea (§ 6.5)

### [BIBLE § 6.5] — Border missing (1.5px rgba(0.12))
- **File**: `lib/features/daily_entry/today_screen.dart:398-413`
- **Issue**: All non-focused borders use `BorderSide.none`. Bible: `border 1.5px solid rgba(43,37,33,0.12)` always (focused changes are not specified — only the static border).
- **Bible says**: `border 1.5px solid rgba(43,37,33,0.12)`.
- **Code does**: No border in idle/enabled; 1.5 px terracotta on focus.
- **Fix**: Use `BorderSide(color: textPrimary.withValues(alpha:0.12), width:1.5)` for `enabledBorder`/`border`. Keep the focus ring or drop it — bible doesn't specify focus styling.
- **Severity**: HIGH

### [BIBLE § 6.5] — Background should be `rgba(0.04)` (sunken), code uses `bgSurface`
- **File**: `lib/features/daily_entry/today_screen.dart:395-396`
- **Issue**: `fillColor: bgSurface` = `#FBF6EC` (raised surface). Bible: `bg rgba(43,37,33,0.04)` — a thin ink wash, not a paper colour.
- **Bible says**: `bg rgba(43,37,33,0.04)`.
- **Code does**: Solid `bgSurface`.
- **Fix**: `fillColor: textPrimary.withValues(alpha:0.04)`.
- **Severity**: MEDIUM

### [BIBLE § 6.5] — `padding 12/14` not respected
- **File**: `lib/features/daily_entry/today_screen.dart:397`
- **Issue**: `contentPadding: EdgeInsets.all(MetraSpacing.s4)` = 16 all sides. Bible: `padding 12 / 14 (V / H)`.
- **Bible says**: `padding 12 vertical / 14 horizontal`.
- **Code does**: 16 / 16.
- **Fix**: `EdgeInsets.symmetric(vertical:12, horizontal:14)`.
- **Severity**: MEDIUM

### [BIBLE § 6.5] — `min-height 72`
- **File**: `lib/features/daily_entry/today_screen.dart:387-388`
- **Issue**: `minLines: 3, maxLines: 6`. With Inter 16 lineHeight ~24 + content padding 16+16, 3 lines ≈ 24*3 + 32 = 104 px. Bible says min-height 72 — code is taller. Acceptable visually but spec divergence.
- **Bible says**: `min-height 72`.
- **Code does**: ~104 (min) via `minLines:3`.
- **Fix**: Use `minLines: 2` or set explicit `ConstrainedBox(minHeight: 72)`.
- **Severity**: LOW

### [BIBLE § 6.5 / § 13] — Placeholder uses ASCII "..." not "…"
- **File**: `lib/l10n/app_it.arb:923`
- **Issue**: ARB stores `"Scrivi qualcosa..."` (three ASCII dots). Bible § 13 explicitly mandates `Scrivi qualcosa…` with a real ellipsis (U+2026). § 13 line 945 also says: "Surface them in `lib/l10n/app_it.arb` exactly as written (including casing, ellipsis character `…`)."
- **Bible says**: `Scrivi qualcosa…` (single Unicode `…`).
- **Code does**: `Scrivi qualcosa...` (three dots `0x2E 0x2E 0x2E`).
- **Fix**: Edit `app_it.arb` (and `app_en.arb` if mirrored): replace `...` with `…` (U+2026).
- **Severity**: HIGH

### [BIBLE § 6.5] — Placeholder font size: bible says Inter 15 rgba(0.35); code uses `body` (16) and `textSecondary` (~0.65)
- **File**: `lib/features/daily_entry/today_screen.dart:391-394`
- **Issue**: hintStyle = `MetraTypography.body` (16) coloured `textSecondary` (alpha 0.65). Bible: Inter 15, rgba(0.35).
- **Bible says**: `Inter 15 rgba(43,37,33,0.35)`.
- **Code does**: 16 px / alpha ~0.65.
- **Fix**: `GoogleFonts.inter(fontSize: 15, color: textPrimary.withValues(alpha: 0.35))`.
- **Severity**: MEDIUM

---

## Save CTA (§ 9.8)

### [BIBLE § 9.8] — CTA height 52, bible 56
- **File**: `lib/features/daily_entry/today_screen.dart:430-431`
- **Issue**: `minimumSize: Size.fromHeight(52)`. Bible: height 56.
- **Bible says**: height 56.
- **Code does**: 52.
- **Fix**: `Size.fromHeight(56)`.
- **Severity**: HIGH

### [BIBLE § 9.8] — Padding `0 / horiz 24 / bottom 16`, bible says `20 / 24 / 0`
- **File**: `lib/features/daily_entry/today_screen.dart:422-428`
- **Issue**: Wrapper padding: `fromLTRB(24, 0, 24, 16)`. Bible: `padding 20 / 24 / 0` (top 20, sides 24, bottom 0). Top spacing should be 20, bottom 0 (the bible expects the screen bottom-padding 100 to handle the gap).
- **Bible says**: `padding 20 / 24 / 0`.
- **Code does**: `0 / 24 / 16`.
- **Fix**: `EdgeInsets.fromLTRB(24, 20, 24, 0)`.
- **Severity**: HIGH

### [BIBLE § 9.8] — Leading icon size 20, bible 18; stroke 2 not enforced
- **File**: `lib/features/daily_entry/today_screen.dart:435`
- **Issue**: `Icon(Icons.check, size: 20)`. Bible: size 18, stroke 2 (Material `Icons.check` is filled, not stroked).
- **Bible says**: size 18, stroke 2, color sabbia.
- **Code does**: 20, filled, default Material check.
- **Fix**: `Icon(Icons.check, size: 18, color: bgPrimary)` (sabbia). Optionally swap to a stroke-style icon.
- **Severity**: MEDIUM

### [BIBLE § 9.8] — Gap 8 between icon and label not explicit
- **File**: `lib/features/daily_entry/today_screen.dart:429-437`
- **Issue**: `FilledButton.icon` uses Material's default ~8 px gap; bible asks for 8. Acceptable.
- **No deviations found.**

### [BIBLE § 9.8 / CP-02] — Label `Salva giornata` matches
- **File**: `lib/l10n/app_it.arb:912`
- **No deviations found.**

### [BIBLE § 9.8] — Radius 16 not configured
- **File**: `lib/features/daily_entry/today_screen.dart:429-437`
- **Issue**: Default `FilledButton` radius is platform-dependent (Material 3 ≈ 20). Bible: radius 16.
- **Bible says**: `radius 16`.
- **Code does**: Default (`StadiumBorder` or 20-radius depending on theme).
- **Fix**: `style: FilledButton.styleFrom(... shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)))`.
- **Severity**: MEDIUM

---

## Cross-cutting

### [BIBLE § 15 ¶6] — No emoji in code or copy
- **File**: All daily-entry sources & `app_it.arb`
- **Issue**: Searched for emoji; none found.
- **No deviations found.**

### [BIBLE § 15 ¶2] — No checkmark on choice chips
- **File**: `lib/core/widgets/choice_chip_metra.dart`
- **Issue**: No `✓` glyph rendered. ✓
- **No deviations found.**

### [BIBLE § 15 ¶11] — Animation discipline
- **Issue**: Choice chip and flow chip lack the only sanctioned `transition all 0.15s`; flow-intensity / pain-dot transitions are also instant. Adding 150ms BG/border transitions is permitted; everything else stays static. (Captured under chip-specific findings above.)
- **No additional new finding.**

### [BIBLE § 9 + CP-01] — Day-of-week computed from today's date
- **File**: `lib/features/daily_entry/today_screen.dart:197-199`
- **Issue**: Uses `DateFormat('EEEE d MMMM', locale).format(DateTime.now())` and capitalises. ✓
- **No deviations found.**
