# Métra — Screenshot Comparison Issues (2026-05-01)

**Source:** side-by-side screenshots in `~/Immagini/Schermate/` — mockup on the **left**, implementation on the **right**.
**Authority:** `design/DESIGN-BIBLE.md` is the orthodox spec; deltas listed below are deviations of the implementation from the bible.

> **Critical methodological correction:** The user-supplied screenshot 02 carries the annotation *"We removed this from the design. We have just 2 onboard screens."* This contradicts what the design bible currently states (it claims a 3-step flow). The HTML canvas in `Métra Screens Light.html` only renders Manifesto + Primo Ciclo as the onboarding row; `ScreenOnboarding2` (Privacy) is defined in the file but **never rendered in the canvas**. The canvas is canon → onboarding is **2 screens**. The bible must be patched, and the implementation must remove the privacy step.

---

## Index

| Block | Topic |
|---|---|
| **A** | Cross-cutting: bible + status corrections |
| **B** | Onboarding 1 — Manifesto |
| **C** | Onboarding 2 (privacy) — REMOVE |
| **D** | Onboarding (now step 2 of 2) — Primo Ciclo |
| **E** | Calendario |
| **F** | Tab bar (cross-cutting; visible in 04 + 06) |
| **G** | Daily entry / Modifica giornata |
| **H** | Today / Oggi |

Severity tags:
- 🔴 **blocker** — visible content is wrong or missing
- 🟠 **high** — visible style departs significantly from spec
- 🟡 **medium** — geometry / spacing / minor variant
- 🔵 **low** — polish, edge case, copy nuance

---

## Block A — Cross-cutting

### A1 🔴 Patch design bible: onboarding is 2 screens, not 3
- **File:** `design/DESIGN-BIBLE.md`
- **Sections to patch:** § 0.3 wordmark callout (note "Mētra" in 2 hero contexts), § 12 (rename header to "Onboarding screens (2 of 2)"), § 12.2 (mark privacy out-of-scope), § 12.3 (renumber as Step 2 / 2), § 12.4 (the 2-step pattern is canonical, the 3-step example is removed).
- **Authoritative phrasing to use:** *"The HTML defines `ScreenOnboarding2` but does not render it in the canvas; it is therefore non-canonical and must not ship."*

### A2 🟠 Update STATUS.md "Key architecture decisions"
- Line 45: `Onboarding flow: 3-step (welcome → privacy → data entry); _PrivacyPage is step 2/3.` → must read `2-step (welcome → first cycle).`

### A3 🟡 Update memory entry
- `~/.claude/projects/-home-paolo-Sviluppo-metra/memory/project_design_bible.md` already exists; add a note that the privacy screen is non-canonical, to prevent reintroduction.

---

## Block B — Onboarding 1 (Manifesto) — `01-manifesto.png`

What matches: wordmark "Mētra" with macron, headline "Il tuo ritmo, custodito.", subhead, "Inizia" CTA on inchiostro.

### B1 🟠 Missing terracotta radial halo behind the wordmark
- **Spec (§ 12.1):** outer radial gradient `ellipse 90% × 60% @ 50% 30%, rgba(200,116,86,0.05) → transparent 80%`; centered halo `220 × 220 radius 50%, radial rgba(200,116,86,0.12) → transparent 70%`.
- **Implementation:** the right side appears flat sabbia behind the wordmark — neither the outer nor the inner glow is visible.

### B2 🟡 Hero proportions
- **Spec:** hero block `flex 0 0 340 px`; text block `flex 1` with padding `0 / 36 / 28`.
- **Implementation:** the wordmark sits noticeably closer to the headline than in the mockup; suggests the hero block is shorter than 340 px or the text block padding-top is not 0.

### B3 🟡 Macron + 3-dot ornament position and weight
- **Spec (§ 12.1):** SVG `48 × 22`. Line `(6,4)→(42,4)` terracotta `strokeWidth 4 round`. Three circles cy 16, r 3, fillOpacity 0.40 / 0.65 / 0.40.
- **Implementation:** the ornament is present but the macron line appears thinner / the dots smaller than in the mockup. Verify exact SVG.

### B4 🔵 CTA bottom margin
- **Spec:** the CTA sits inside `padding 0 / 36 / 28` — i.e. 28 px above the screen bottom edge.
- **Implementation:** the CTA looks closer to the bottom edge than the mockup. Verify the bottom padding of the text block.

---

## Block C — Onboarding 2 (Privacy) — REMOVE

User annotation in `02-this-is-not-in-the-design-docs.png`: *"We removed this from the design. We have just 2 onboard screens."*

### C1 🔴 Remove the entire privacy step from the onboarding flow
- **File:** `lib/features/onboarding/onboarding_screen.dart` — remove `_PrivacyPage` widget class and any references in the page list / PageView.
- **Other references:** any imports, route bindings, `STATUS.md` text claiming step 2/3.
- **Tests:** any test asserting privacy step content (`test/features/onboarding/...`) must be deleted, not skipped.

### C2 🔴 Update progress indicator to 2 stripes
- **File(s):** the progress strip widget shared by onboarding pages must default to **2 segments**, currently **3**.
- **Strings:** the "Passo X di 3" copy must become "Passo X di 2".

### C3 🟡 Verify analytics / first-run state machine
- The onboarding state machine / completion flag must consider 2 steps as the full flow (no privacy ack to record / persist).

### C4 🔵 Note: the impl privacy texts also diverged from the design copy (e.g. *"Tutto sul tuo dispositivo"* vs spec *"Solo sul tuo dispositivo"*). Moot once removed; documented here to avoid resurrection elsewhere.

---

## Block D — Onboarding step 2 of 2 (Primo Ciclo) — `03-primo-ciclo.png`

This is the screen that, after C1, becomes step 2/2.

### D1 🔴 Progress strip: 2 segments, both filled
- **Implementation:** shows **3 segments**, label *"Passo 3 di 3"*.
- **Spec (§ 12.3):** **2 segments**, both terracotta-filled, label *"Passo 2 di 2"*.

### D2 🔴 Missing headline "Raccontami\nil tuo ciclo."
- **Spec:** `DM Serif Display 28 inchiostro line-height 1.25`, two lines via manual `\n`.
- **Implementation:** the screen lacks this headline entirely; "Primo giorno dell'ultima mestruazione" is currently used as the hero text — but that string is the **micro-label of field 1**, not the screen headline.

### D3 🔴 Missing subhead
- **Spec:** *"Puoi sempre modificarlo dopo. Non servono risposte precise."* Inter 14 rgba(0.68) line 1.5 marginBottom 28.
- **Implementation:** no subhead present.

### D4 🔴 Missing micro-label "PRIMO GIORNO DELL'ULTIMA MESTRUAZIONE" above the date input
- **Spec (§ 12.3 field 1):** Inter 12 weight 600 letter-spacing 0.06em UPPERCASE rgba(0.40) marginBottom 10.

### D5 🟠 Date input: wrong shape and styling
- **Spec (§ 6.3):** rectangle `height 52 · radius 12 · bg surface · border 1.5px solid rgba(43,37,33,0.14)`, paddingInline 16, with calendar icon at right colored rgba(0.40).
- **Implementation:** rendered as a pill with terracotta-tinted border and terracotta-tinted calendar icon; copy is in English ("Select date").

### D6 🔴 Date input copy: should be Italian formatted date, not English "Select date"
- **Spec:** literal example "10 aprile 2025"; localization must display Italian month names lowercase.

### D7 🔴 Missing micro-label "DURATA MEDIA CICLO" above the stepper
- **Implementation:** uses a question-style title *"Quanto dura di solito il tuo ciclo?"* (DM Serif large) — wrong. Replace with the small uppercase micro-label.

### D8 🔴 Missing "giorni" suffix next to the stepper value
- **Spec (§ 6.4):** `<Display 40 inchiostro>{n}</Display>` + `Inter 16 rgba(0.68) "giorni"` (left margin 6).
- **Implementation:** only the number is shown.

### D9 🔴 Missing range track (21–45) below the stepper
- **Spec (§ 6.4):** track `4 px` tall, `radius 2`, bg `rgba(43,37,33,0.08)`, terracotta fill width `(n − 21) / 24 × 100 %`.

### D10 🟠 Missing range markers "21" / "45"
- **Spec:** Inter 11 rgba(0.35), justified, marginTop 4.

### D11 🔴 CTA label wrong: "Inizia" → "Tutto pronto →"
- **Spec (§ 12.3):** the literal label is `"Tutto pronto →"` (the arrow is part of the label).
- **Implementation:** label reads `"Inizia"`.

### D12 🔴 CTA color wrong: appears greyed/disabled
- **Spec (§ 5.1 inchiostro variant):** `bg inchiostro #2B2521`, label `sabbia` Inter 16 weight 500.
- **Implementation:** light beige fill, washed-out label — looks disabled. Cannot ship in this state.

### D13 🟡 Period-day buttons (1..8): visual is roughly correct (3 selected, terracotta) — keep.

### D14 🟡 Verify the screen scrolls or uses `marginTop: auto` on the CTA so the button stays bottom-pinned regardless of content height.

---

## Block E — Calendario — `04-calendario.png`

### E1 🔴 Header layout: month name LEFT-aligned + cycle-day caption + moon icon
- **Spec (§ 8.1):** left column = `DM Serif Display 26 inchiostro` month + `row gap 6 marginTop 3 [Moon phase=2 size 14] [Inter 13 rgba(0.68) "Giorno N"]`. Right column = chevron-left (rgba 0.40) + chevron-right (inchiostro), gap 10.
- **Implementation:** month text is **centered**, no cycle-day caption, no moon icon.

### E2 🔴 Stray back-arrow in the top-left
- **Implementation:** there is a `←` chevron in the top-left as if this were a routed sub-screen.
- **Spec:** Calendario is a tab. **No back-arrow.** Remove.

### E3 🔴 Day cells: 48×48 rounded squares with proper state coloring
- **Spec (§ 8.3):** `48 × 48`, `radius 12`, state table:
  - **Selected** = bg `inchiostro`, text `sabbia` weight 600, no border
  - **Flow** = bg `${terracotta}22`, border `1px solid ${terracotta}44`
  - **Predicted** = transparent, border `1.5px solid ${lavanda}66`
  - **Today (unselected)** = transparent, ring `1.5px solid rgba(43,37,33,0.35)`
- **Implementation:** day cells appear smaller / unstyled; only the "today" cell shows an inchiostro fill. No flow tint, no predicted outline.

### E4 🔴 Missing indicator dots under day numbers
- **Spec (§ 8.3.2):** under each day number, a row gap-2 of `DataIcon size 11`:
  - `drop` (tc_scura) for flow days
  - `drop_outline` (lavanda) for predicted
  - `star_small` (ocra) for symptoms logged
  - `zap` (malva) for pain logged
- **Implementation:** none of these indicators are rendered. The dots one would expect under days 7-13 (predicted) and 10-14 (flow) are absent.

### E5 🟠 Predicted-period range not rendered
- **Spec:** days 7-9 in April 2025 example carry the `drop_outline` + lavender border treatment.
- **Implementation:** no visual difference between predicted and default days.

### E6 🟢 Legend strip is present and largely correct (Mestruazioni · Previsione · Sintomi · Dolore). Verify the 4 icons used match the bible's `drop / drop_outline / star_small / zap` set, sized 14, with the right colors.

### E7 🟡 Day-detail card on the empty state (May 1, 2026 in screenshot)
- The "Venerdì 1 maggio · Nessun dato registrato" rendering looks broadly correct; verify it follows § 8.5 exactly:
  - left title `DM Serif Display 20`
  - right italic hint *"Nessun dato registrato"* `Inter 12 rgba(0.38) italic`
  - the *"Modifica giornata"* row CTA: `height 44, bg ${terracotta}10, border ${terracotta}22, label tc_scura`.

---

## Block F — Tab bar (cross-cutting — observed in 04 and 06)

### F1 🟠 Active tab: NO pill background behind icon
- **Spec (§ 4):** active state = color (`terracotta`) + weight (icon stroke 2, label 600) only.
- **Implementation:** active "Calendario" / "Oggi" tab carries a **terracotta-tinted rounded-rectangle pill behind the icon**. Remove that fill.

### F2 🟡 Verify icon set
- **Spec icons:** `calendar / note / wave / chart / settings`.
- **Implementation:** "Oggi" tab uses what looks like a pencil-on-document or filled-doc icon — verify it is the `note` icon from § 2.1.

### F3 🟡 Inactive icon and label colors
- **Spec:** inactive icon `rgba(43,37,33,0.30)` stroke 1.5; inactive label `rgba(43,37,33,0.55)` weight 400.

### F4 🟡 Tab bar height + blur
- **Spec:** height 84, top inner padding 10, bg `rgba(244,237,226,0.96)`, `backdrop-filter: blur(16)`, top border `1px solid rgba(43,37,33,0.08)`.

---

## Block G — Daily entry / Modifica giornata — `05-modifica-giornata.png`

User annotation: *"This opens when you tap on the 'modifica giornata' button."*

### G1 🔴 Remove the AppBar with title "Registro giornaliero"
- **Spec (§ 9.2):** the daily-entry screen has no AppBar — only its own bare header `padding 12 / 24 / 16` with `Inter 13 rgba(0.68)` date subtitle + `DM Serif Display 26 inchiostro "Come stai oggi?"`.
- **Implementation:** shows a Material AppBar with `←` back arrow + title `"Registro giornaliero"`. Remove.

### G2 🔴 Section labels: UPPERCASE Inter 12 weight 600 letter-spacing 0.06em — not DM Serif large
- **Spec (§ 9.3):** section label `Inter 12 weight 600 letter-spacing 0.06em UPPERCASE color rgba(43,37,33,0.40) marginBottom 14`.
- **Implementation:** "Flusso", "Dolore", "Sintomi", "Note" rendered in DM Serif Display large lowercase. Wrong typeface, wrong size, wrong case, wrong color.

### G3 🔴 Dolore section: replace the toggle switch with the 4-dot PainDots picker
- **Implementation:** Dolore is currently a single iOS-style toggle switch.
- **Spec (§ 7.3):** four malva circles labeled `Nessuno · Lieve · Moderato · Intenso` with halo on selected.

### G4 🔴 Note section: replace the toggle switch with a textarea
- **Implementation:** Note is currently a single iOS-style toggle switch.
- **Spec (§ 6.5):** `min-height 72, radius 12, bg rgba(43,37,33,0.04), border 1.5px solid rgba(43,37,33,0.12)`, padding 12/14, placeholder `Scrivi qualcosa…` Inter 15 rgba(0.35).

### G5 🔴 Sintomi chips: horizontal wrap, NOT vertical stack
- **Implementation:** chips are stacked vertically, one per row, with single chip horizontally centered/right.
- **Spec (§ 9.6):** `display flex wrap gap 8` — chips flow horizontally and wrap onto new rows when full.

### G6 🔴 Sintomi chip style: filled terracotta when selected
- **Spec (§ 6.1):** selected = `bg terracotta, text sabbia, border 1px transparent`. Unselected = `bg rgba(43,37,33,0.07), text inchiostro, border 1px solid rgba(43,37,33,0.12)`. Height 36, radius 18, paddingInline 14.
- **Implementation:** all chips are pill outlined neutrals — no chip is shown selected. The "Crampi"-as-selected mockup state is missing.

### G7 🔴 Add the inline "+ Aggiungi" affordance after the symptom list
- **Spec (§ 6.2):** dashed-border chip `border 1px dashed rgba(43,37,33,0.25)` with `+` glyph + label "Aggiungi" rgba(0.40).
- **Implementation:** the "+ Aggiungi" chip is missing in this view.

### G8 🔴 Remove the "Annulla" text button
- **Spec (§ 5):** the system has no outline / ghost / cancel button. Save is the only button on this screen.
- **Implementation:** shows "Annulla" as a tertiary text button next to "Salva giornata". Remove.

### G9 🟠 Pre-select the day's existing values when opened in edit mode
- **Spec / behavior:** "Modifica giornata" loads the saved log for the selected day; flow type, intensity, pain, symptoms, note must be hydrated, otherwise the user has to re-enter their data.
- **Implementation:** the screen renders all fields blank/idle.

### G10 🟠 When `flowType === mestruazioni`, show FlowIntensityDots
- **Spec (§ 9.4):** the 3-dot intensity picker (Leggero / Moderato / Abbondante) appears immediately under the FlowTypeChips row whenever Mestruazioni is selected.
- **Implementation:** missing (related to G9 — nothing is selected, so no intensity picker is conditionally shown).

### G11 🟠 Save CTA layout
- **Spec (§ 9.8):** terracotta full-width button with leading `check` icon (size 18 stroke 2 sabbia, gap 8) + label "Salva giornata", padding 20/24/0 wrapping, height 56, radius 16.
- **Implementation:** the button is present but is paired with the Annulla text button; verify it matches §9.8 once Annulla is removed.

### G12 🟡 Section frame: `bg surface`, top + bottom `1px solid rgba(43,37,33,0.07)`, padding 18/24, gap 1 between sections
- **Implementation:** sections look like they sit directly on the sabbia background without the surface frame.

---

## Block H — Today / Oggi — `06-oggi.png`

Many of the issues mirror Block G; listed only where they're additional or differ.

### H1 🔴 Sintomi chips: horizontal wrap, NOT vertical stack
- Same as G5. Verified again on this screen.

### H2 🔴 Sintomi chip style: filled terracotta when selected
- Same as G6. Crampi should be visibly selected (terracotta filled) per the mockup.

### H3 🔴 Missing "+ Aggiungi" inline-add chip
- Same as G7.

### H4 🔴 Missing "Nota libera" section
- **Spec (§ 9.7):** below Sintomi there must be a *NOTA LIBERA* section with the textarea.
- **Implementation:** the section is not visible (and it's not below the fold either — the CTA appears immediately under symptoms). Add the section and its textarea.

### H5 🟠 PainDots geometry
- **Spec (§ 7.3):** 4 dots, R 18, halo 23, gap 14, sized to fit a single row centered.
- **Implementation:** the dots look more spread out and the labels seem larger; verify exact geometry. Specifically, halo strokeWidth 1.2 opacity 0.28, fillOpacity values 0.00 / 0.28 / 0.60 / 0.92.

### H6 🟡 Verify mestruazioni → FlowIntensityDots wiring
- The screenshot shows Mestruazioni selected and Moderato highlighted — looks broadly correct. Check fillOp values (0.30 / 0.65 / 0.94) and halo on selected.

### H7 🟡 Flow chip border thickness for the selected mestruazioni state
- **Spec (§ 7.1):** mestruazioni-selected border = `1.5px solid ${terracotta}BB`.
- **Implementation:** verify the border weight is 1.5 px (not 1 px) and the color matches `${terracotta}BB`.

### H8 — see Block F for tab bar issues (active-tab pill background, etc.).

---

## Suggested execution order

1. **A1 + A2** — patch the bible & STATUS.md so the rest of the work has a correct spec to align to. *(15 min)*
2. **C1–C3** — remove the privacy onboarding screen and any related state/tests. *(30 min)*
3. **D-block** — rebuild Primo Ciclo with the correct headline, subhead, micro-labels, date input shape, range track, "giorni" suffix, and CTA. *(half-day)*
4. **G-block** — overhaul "Modifica giornata": kill the AppBar, fix section labels, swap toggles for PainDots/textarea, fix chip wrap and selected style, add inline-add, remove Annulla. *(half-day)*
5. **H-block** — finish parity on the Today screen (most fixes overlap with G via shared widgets). *(2-4 h)*
6. **E-block** — calendar header, day cells, indicator dots, predicted-range outlines. *(half-day)*
7. **F-block** — tab bar visual cleanup. *(1-2 h)*
8. **B-block** — manifesto polish (halo, proportions, ornament). *(1-2 h)*

---

## Notes for whoever picks this up

- **No widget invention.** Every fix above maps to a section of `design/DESIGN-BIBLE.md`. If you need a token or component that isn't in the bible, **stop**. Update the HTML mockup first and patch the bible before writing Flutter code.
- **Italian copy is canonical.** Do not paraphrase any of the strings in this doc. Lift them verbatim into `lib/l10n/app_it.arb`.
- **Tests:** keep `flutter test` green after every block. Onboarding tests will need rewriting after C1; calendar widget tests will need updating after E3-E5.
