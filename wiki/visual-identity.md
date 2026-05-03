# Visual identity and design system

<!-- Table of contents -->

- [Design process and authority chain](#design-process-and-authority-chain)
- [Wordmark](#wordmark)
- [Color tokens](#color-tokens)
  - [Alpha stops](#alpha-stops)
  - [Accent tints](#accent-tints)
- [Typography](#typography)
- [Spacing and radius](#spacing-and-radius)
- [Borders and shadows](#borders-and-shadows)
- [Iconography](#iconography)
  - [Stroke icons](#stroke-icons)
  - [Filled data icons](#filled-data-icons)
  - [Moon phases](#moon-phases)
- [Components](#components)
  - [Primary CTA button](#primary-cta-button)
  - [FlowTypeChips](#flowtypechips)
  - [FlowIntensityDots](#flowintensitydots)
  - [PainDots](#paindots)
  - [Choice chip](#choice-chip)
  - [MetraToggle](#metratoggle)
  - [Tab bar](#tab-bar)
- [Accessibility](#accessibility)
- [Anti-patterns](#anti-patterns)
- [Language and copy](#language-and-copy)

---

## Design process and authority chain

Every UI change must follow this order without exception:

1. Update `wiki/design/Métra Screens Light.html` — the HTML mockup is the ultimate source of truth.
2. Update `design/DESIGN-BIBLE.md` — the canonical written transcription of the mockup.
3. Update Flutter code — never the reverse.

**If `DESIGN-BIBLE.md` and the HTML mockup contradict each other, the HTML wins.** Patch the bible to match; never patch the HTML to match the bible or the Flutter code.

The interactive HTML mockup files are:

| File | Purpose |
|---|---|
| `wiki/design/Métra Screens Light.html` | Canonical light-theme mockup — the super-canon |
| `wiki/design/Métra Design System.html` | Design-system catalog (reference; superseded by DESIGN-BIBLE.md on conflict) |
| `wiki/design/Métra App Icon.html` | App icon variants |

Dark-theme, Quick Entry, and Prototype HTML files exist in the repo but are **out of scope for the current bible** — do not derive new product tokens from them.

The `TweaksPanel` in the HTML mockup (`palette`, `voce`, `respiro`) is a design-exploration tool. The only canonical defaults are `terracotta + romantico + respiro=1.0`. Alternative palettes (`lavanda`, `pietra`) and fonts (`netto`, `editoriale`) **must not ship**.

---

## Wordmark

| Property | Value |
|---|---|
| Product name in UI | **Mētra** (ē = U+0113, macron) |
| Font | DM Serif Display, 56px, weight 400 |
| Letter spacing | −0.02em |
| Color | `inchiostro` |
| Widget | `lib/core/widgets/metra_wordmark.dart` |
| String constant | `MetraTypography.wordmark` = `'Mētra'` |

Use the **literal Unicode glyph** (`ē`, U+0113) everywhere the wordmark appears. Never compose it with CSS `::before`, `position`, or any other trick. A past session spent three attempts on pseudo-element approaches before falling back to the literal character; do not repeat that path.

`Métra` (acute é, U+00E9) appears only in GPL license headers and design-file names — not in product UI.

---

## Color tokens

These nine tokens are the only colors permitted in product code. No custom hex values outside this list.

| Token | Hex | Flutter constant | Role |
|---|---|---|---|
| `sabbia` | `#F4EDE2` | `Color(0xFFF4EDE2)` | Primary screen background; tab-bar base |
| `surface` | `#FAF5EE` | `Color(0xFFFAF5EE)` | Card and section backgrounds (above sabbia) |
| `inchiostro` | `#2B2521` | `Color(0xFF2B2521)` | Primary text; selected-day fill |
| `terracotta` | `#C87456` | `Color(0xFFC87456)` | Primary accent; active tab; flow indicator; CTA |
| `tc_scura` | `#9A4D32` | `Color(0xFF9A4D32)` | Dark accent; body text on tinted backgrounds |
| `ocra` | `#D4A26A` | `Color(0xFFD4A26A)` | Symptom marker |
| `lavanda` | `#5B4E7A` | `Color(0xFF5B4E7A)` | Predicted-period outline |
| `malva` | `#9E7488` | `Color(0xFF9E7488)` | Pain marker |
| `muschio` | `#7A8471` | `Color(0xFF7A8471)` | Reserved — not used in shipped screens |

Flutter source: `lib/core/theme/metra_colors.dart` — `MetraColors.light.*` (semantic aliases) and `MetraColors.dark.*`. Use semantic aliases (`MetraColors.light.bgPrimary`, `.accentFlow`, etc.) in widget code, not raw hex values.

### Alpha stops

Translucent ink uses these exact stops. Do not invent intermediate values.

| `rgba(43,37,33, α)` | Use |
|---|---|
| `0.04` | Note-area placeholder fill; faintest neutral chip ground |
| `0.07` | Card border; section divider; segmented-control background |
| `0.08` | Tab-bar top border; segmented-control track |
| `0.12` | Note textarea border; number-stepper inactive track |
| `0.35` | Today-cell ring (unselected); day-number faded text |
| `0.40` | Section labels; captions |
| `0.45–0.68` | Body secondary text (range — pick the stop that matches the specific use in the bible) |

### Accent tints

Tints are expressed as the token hex with a two-character alpha suffix. Flutter helper: `const Color(0xFFC87456).withAlpha(0x22)` for terracotta at alpha `0x22`.

| Stop | Alpha % | Use |
|---|---|---|
| `${terracotta}0D` | ≈ 5 % | Spotting hint background; inline symptom field background; edit-day CTA |
| `${terracotta}22` | ≈ 13 % | Mestruazioni selected chip background; flow-day cell background |
| `${terracotta}44` | ≈ 27 % | Flow-day cell border; flow chip border; stat-card accent border |
| `${terracotta}BB` | ≈ 73 % | Mestruazioni selected chip border |
| `${lavanda}66` | ≈ 40 % | Predicted-period day-cell border |

---

## Typography

Two families are loaded via `google_fonts`. **Cormorant Garamond is loaded in the repo but must not ship in the product.**

- **DM Serif Display** — display, hero, large numbers, screen titles, archive month labels
- **Inter** — body, labels, numerals, buttons, tabs

Flutter source: `lib/core/theme/metra_typography.dart` — `MetraTypography.*` static getters.

| Token | Family | Size | Weight | Line-height | Letter-spacing | Notes |
|---|---|---|---|---|---|---|
| `displayHero` / wordmark | DM Serif Display | 56 | 400 | 1.0 | −0.02em | Single line, never wrap |
| `headlineLg` (onboarding manifesto) | DM Serif Display | 34 | 400 | 1.2 | default | |
| `headlineSm` (onboarding 2) | DM Serif Display | 28 | 400 | 1.25 | default | |
| `screenTitle` | DM Serif Display | 26 | 400 | 1.1 | default | Calendar / Archive / Stats / Settings headers |
| `statCard` value | DM Serif Display | 32 | 400 | 1.0 | default | Numeric KPI |
| `archiveMonth` | DM Serif Display | 17 | 400 | 1.2 | default | |
| `body` | Inter | 16 | 400 | 1.55 | default | |
| `listTitle` | Inter | 15 | 500 | 1.55 | default | Settings rows, list items |
| `sectionLabel` | Inter | 12 | 600 | 1.4 | 0.06em | UPPERCASE; color `rgba(43,37,33,0.40)` |
| `dotLabel` | Inter | 10 | 400 idle / 600 selected | 1.4 | default | Under flow/pain dots |
| `tabLabel` | Inter | 10 | 400 idle / 600 active | 1.4 | default | Tab bar |

Italic is permitted only on Inter (e.g. empty-state hints: *"Nessun dato registrato"*). Italic DM Serif Display is reserved — not used in any shipped screen.

---

## Spacing and radius

Full canonical scale (logical pixels):

```
0 · 2 · 3 · 4 · 5 · 6 · 7 · 8 · 10 · 12 · 14 · 16 · 18 · 20 · 24 · 28 · 32 · 36 · 44 · 48 · 56 · 72 · 84 · 90 · 100
```

Flutter source: `lib/core/theme/metra_spacing.dart` — `MetraSpacing.sp*` and `MetraRadius.*` constants. Use the canonical `sp{value}` names in new code; the legacy `s0–s12` aliases exist only for backward compatibility and will be removed.

Key patterns:

| Pattern | Value |
|---|---|
| Screen-edge horizontal padding | 24px |
| Section padding (Today screen) | 18px top/bottom, 24px left/right |
| Bottom safe area (lists with tab-bar overlay) | 90–100px |
| Tab-bar height | 84px |

Corner radii:

| Radius | Where |
|---|---|
| 6 | Archive-table cells and header pills |
| 10 | Segmented-control track; stepper micro-buttons |
| 12 | Calendar day cell; flow-type chip; note textarea; stat-card edges |
| 14 | Archive timeline card |
| 16 | Stat card; privacy info card; all primary CTAs |
| 18 | Symptom chip (capsule) |
| 20 | Day-detail card |
| 50 % | Dots, circles, timeline nodes |

**Chip pill rule: `radius = ½ × height`.** A chip with `height 36` uses `radius 18`. Never use `999px`.

---

## Borders and shadows

Universal border recipes:

```
Card edge:      1px solid rgba(43,37,33,0.07)   // surface card on sabbia
Section divider: 1px solid rgba(43,37,33,0.07)   // Today-screen section separators
Strong outline:  1.5px solid rgba(43,37,33,0.14) // onboarding date-input
```

Dashed borders appear in exactly two contexts:

- `1.5px dashed rgba(43,37,33,0.32)` — Assente flow chip when selected
- `1px dashed rgba(43,37,33,0.25)` — inline "Aggiungi" chip in the symptom row

**Shadows are used in two places only:**

| Shadow | Where |
|---|---|
| `0 1px 4px rgba(43,37,33,0.12)` | Active segmented-control button |
| Phone-shell shadow | Mockup chrome only — do not ship |

No drop shadows on cards, sheets, or dialogs. Depth is communicated through borders and surface-color contrast.

---

## Iconography

Flutter source: `lib/core/widgets/metra_icon.dart` — `MetraIcon` widget and `MetraIcons.*` SVG fragments.

### Stroke icons

24×24 viewBox · `stroke-linecap: round` · `stroke-linejoin: round` · `fill: none` · default stroke width 1.5 (active tab: 2).

Full catalog — do not add icons outside this list without first updating the HTML mockup:

```
chevron_right  chevron_left   chevron_down   x
lock           cloud          drop           wave
plus           check          settings       chart
calendar       note           wifi           battery
filter         info           leaf           export
moon_crescent  star_small
```

There is no `open_in_new` / `arrow_up_right` in the catalog. External-link rows in Settings use `chevron_right` uniformly; the row label disambiguates the destination. If a future revision needs a distinct external-link glyph, add it to the HTML mockup first.

### Filled data icons

11–14px default · viewBox 24×24 · single color fill. These are the semantic markers of the system.

| Name | Constant | Semantic meaning |
|---|---|---|
| `drop` (filled) | `MetraIcons.dropFilled` | Mestruazioni |
| `drop_outline` | `MetraIcons.dropOutline` | Predicted period |
| `moon_crescent` (filled) | `MetraIcons.moonCrescentFilled` | Cycle-day affordance |
| `star_small` (filled) | `MetraIcons.starSmallFilled` | Symptom |
| `zap` (filled) | `MetraIcons.zapFilled` | Pain |

Calendar grid color rules:

| Indicator | Color when cell is NOT selected | Color when cell IS selected |
|---|---|---|
| `drop` | `tc_scura` | `sabbia` |
| `drop_outline` | `lavanda` | `sabbia` |
| `star_small` | `ocra` | `sabbia` |
| `zap` | `malva` | `sabbia` |

Indicator order within a cell is fixed: drop → drop_outline → star_small → zap.

### Moon phases

`MetraMoon` widget renders 5 phases (0 = new moon through 4 = full moon) as SVG. Used at 14px in the calendar header. The five fill paths are defined verbatim in the HTML mockup — do not redraw them.

---

## Components

### Primary CTA button

`height 56 · radius 16 · Inter 16 weight 500`

Two variants selected by screen role, not user preference:

| Variant | Background | Label color | Used on |
|---|---|---|---|
| **Inchiostro** | `inchiostro` | `sabbia` | "Inizia", "Tutto pronto →" — brand entry and completion actions |
| **Terracotta** | `terracotta` | `sabbia` | "Salva giornata", "Continua" — commit and save actions |

There is no third variant. No outline, ghost, or destructive buttons.

### FlowTypeChips

Three chips in a row. `height 44 · radius 12 · Inter 13 · flex: 1`

| Chip | Idle bg | Idle border | Idle text | Selected bg | Selected border | Selected text |
|---|---|---|---|---|---|---|
| Assente | `rgba(43,37,33,0.04)` | `1px solid rgba(43,37,33,0.10)` | `rgba(43,37,33,0.42)` | `rgba(43,37,33,0.08)` | `1.5px dashed rgba(43,37,33,0.32)` | `inchiostro` w500 |
| Mestruazioni | same | same | same | `${terracotta}22` | `1.5px solid ${terracotta}BB` | `tc_scura` w500 |
| Spotting | same | same | same | `${terracotta}14` | `1.5px solid ${terracotta}66` | `tc_scura` w500 |

No checkmarks on selected chips. Selection is colour-only. Tapping an already-selected chip clears the selection (`onChange(null)`).

### FlowIntensityDots

Visible only when `flowType === 'mestruazioni'`. Three 50×50 dots (R = 18), terracotta fill, centered.

| Level | Label | Fill opacity | Selected label color |
|---|---|---|---|
| 1 | Leggero | 0.30 | `tc_scura` w600 |
| 2 | Moderato | 0.65 | `tc_scura` w600 |
| 3 | Abbondante | 0.94 | `tc_scura` w600 |

Selected halo: outer ring r 23, terracotta stroke 1.2, opacity 0.30. Idle label: `rgba(43,37,33,0.40)` w400. Label style: Inter 10.

### PainDots

Always visible in the "Intensità dolore" section. Four 50×50 dots (R = 18), malva fill.

| Level | Label | Fill opacity |
|---|---|---|
| 0 | Nessuno | 0.00 (transparent) |
| 1 | Lieve | 0.28 |
| 2 | Moderato | 0.60 |
| 3 | Intenso | 0.92 |

Selected label: `malva` w600. Idle label: `rgba(43,37,33,0.38)` w400. Tapping the selected dot clears the selection.

### Choice chip

`height 36 · paddingInline 14 · radius 18 · Inter 13 weight 500`

| State | Background | Text color | Border |
|---|---|---|---|
| Selected | `terracotta` | `sabbia` | `1px transparent` |
| Unselected | `rgba(43,37,33,0.07)` | `inchiostro` | `1px solid rgba(43,37,33,0.12)` |

Transition: `all 0.15s`. No checkmarks — selection is colour-only.

### MetraToggle

The binary-state control used in Settings.

```
Track:    48 × 28 · radius 14
Dot:      22 × 22 · radius 11 · fill surface · sits 3px inside the track
Off:      track background rgba(43,37,33,0.08)   dot translateX(3)
On:       track background terracotta             dot translateX(23)
Transitions: track background 0.15s · dot position 0.15s
```

No shadow, no halo, no checkmark glyph. No indeterminate state. Tap inverts state.

### Tab bar

Widget: `lib/core/widgets/metra_tab_bar.dart` — `MetraTabBar`

```
Height:     84dp
Background: sabbia @ 0.96 + BackdropFilter blur(16, 16)
Top border: 1px solid rgba(43,37,33,0.08)
Inner top padding: 10px
```

Four tabs, in this order:

| Index | Icon | Italian label |
|---|---|---|
| 0 | `calendar` | Calendario |
| 1 | `wave` | Archivio |
| 2 | `chart` | Statistiche |
| 3 | `settings` | Impostazioni |

Active tab: icon stroke 2, color `terracotta`; label Inter 10 w600 `terracotta`.  
Idle tab: icon stroke 1.5, color `rgba(43,37,33,0.30)`; label Inter 10 w400 `rgba(43,37,33,0.55)`.

No FAB, no badge counts, no animated indicator pill. Active state is colour and weight only.

---

## Accessibility

**Standard:** WCAG 2.2 AA minimum across all screens. AAA where achievable. An inaccessible screen is an incomplete screen — accessibility is a ship requirement, not a backlog item.

### Interactive widget requirements

Every interactive widget must have:

- `Semantics` widget (or equivalent Flutter accessibility annotation) describing its role, label, and current state.
- Minimum tap target of **44 × 44 dp**. This applies to chips (height 36 → wrap in a `SizedBox` or `Semantics` with `minTouchTargetSize`), dots, toggle, and tab bar items. The calendar day cell (48 × 48) already meets this threshold.

### Specific patterns

| Widget | Required semantics |
|---|---|
| `MetraTabBar` items | `label: "<tab name>"`, `selected: true/false` |
| `FlowTypeChips` | `label: "<chip name>"`, `selected: true/false`, `button: true` |
| `FlowIntensityDots` / `PainDots` | `label: "<level name>"`, `selected: true/false`, `button: true` |
| Choice chip | `label: "<chip name>"`, `selected: true/false` |
| `MetraToggle` | `label: "<row label>"`, `toggled: true/false`, `button: true` |
| Calendar day cell | `label: "<day> <month>"`, include flow/symptom state if present |
| Primary CTA | `label: "<button label>"`, `button: true` |

### Color contrast

`terracotta` (#C87456) on `sabbia` (#F4EDE2) yields a contrast ratio below 4.5:1 for normal-size body text. Use `tc_scura` (#9A4D32) for body text on tinted backgrounds — it passes AA (4.68:1 on sabbia). The `MetraColors.light.accentFlowText` semantic alias resolves to `tc_scura` for this reason.

### Motion

Two sanctioned animations exist in the system (chip background 0.15s; toggle track and dot 0.15s). Both are below the WCAG 2.2 threshold for vestibular-triggering motion and do not require a reduced-motion branch. Any future animation that exceeds 0.25s or covers substantial screen area must check `MediaQuery.of(context).disableAnimations` and fall back to instant transitions.

---

## Anti-patterns

The following are forbidden until the HTML mockup is updated to include them. They are listed because past iterations have introduced each one:

1. **No FAB.** The only log-entry path is the day-card CTA button. No floating action button anywhere.
2. **No checkmarks on chips.** Selection is colour-only — no `✓` glyph on `FlowTypeChips` or choice chips.
3. **No drop shadows on cards or sheets.** The only permitted shadow is on the active segmented-control button (`0 1px 4px rgba(43,37,33,0.12)`).
4. **No circular day cells.** Calendar days are 48 × 48 rounded squares (radius 12), never circles.
5. **No colors outside the nine tokens.** Do not introduce new accent colors, tints, or hex values not in the palette table above.
6. **No emoji in copy or chips.** Symptom labels are plain text.
7. **No badge counts on tab-bar icons.**
8. **No `Métra` (acute é) in product UI.** The wordmark and all in-app references use `Mētra` (macron ē, U+0113).
9. **No `999px` radius on chips.** Use `radius = ½ × height`.
10. **No unsanctioned animations.** The only permitted motion specs are: chip background `0.15s` (§ FlowTypeChips, § Choice chip) and MetraToggle track background + dot position `0.15s`. Do not add transitions, page animations, or spring effects beyond these two.

---

## Language and copy

Italian is the primary language (`lib/l10n/app_it.arb` — source of truth). English is a mirror (`lib/l10n/app_en.arb`).

Key vocabulary (enforce these terms verbatim):

| Concept | Correct term | Never use |
|---|---|---|
| Product name in UI | `Mētra` | `Métra` |
| Flow section | `Flusso` | — |
| Pain section | `Intensità dolore` | — |
| Symptom section | `Sintomi` | — |
| Free note section | `Nota libera` | — |
| Save day CTA | `Salva giornata` | — |
| Edit day CTA | `Modifica giornata` | — |
| Add day CTA | `Aggiungi giornata` | — |
| Destructive section header | `Azioni irreversibili` | `Zona pericolosa` |
| Delete action | `Elimina` | `Cancella` |
| Backup: connected state | `Configurato` | `Connesso`, `Attivo` |
| Backup: disconnected state | `Non configurato` | `Nessuna connessione`, `Aggiungi` |
| Help link | `Guida` | `Centro assistenza` |

Canonical empty-state strings (use exactly as written, including ellipsis character `…` and accented characters):

| String | Where |
|---|---|
| `Nessun dato registrato` | Calendar day-detail — no entry (italic) |
| `Nessun flusso oggi` | Today screen — Assente hint |
| `Piccola perdita fuori dal flusso mestruale. Non è necessariamente l'inizio del ciclo.` | Today screen — Spotting hint box |
| `Scrivi qualcosa…` | Note textarea placeholder |
| `es. Vertigini` | Inline-add symptom input placeholder |

---

<!-- author notes

Voice: developer reference (not end-user how-to). Register mirrors DESIGN-BIBLE.md — declarative, rule-first, zero ceremony. No "welcome", no outcome-framing prose.

Path discrepancy flagged in the authority chain section (task spec says `wiki/design/Métra Screens Light.html`; CLAUDE.md and DESIGN-BIBLE.md cross-reference the path without the `wiki/` prefix as `design/Métra Screens Light.html`). [VERIFY: confirm which directory the HTML mockups actually live in, and update cross-references in DESIGN-BIBLE.md § 17 if the wiki/ path is the authoritative one.]

Sections cut or compressed from the full bible:
- Phone shell / status bar spec (§ 3 of bible) — mockup chrome only, zero product relevance to UI contributors.
- Per-screen layout specs (Calendar grid system, Today screen, Archivio, Statistiche, Onboarding, Impostazioni) — these are in DESIGN-BIBLE.md; this document is a design-system reference, not a per-screen spec.
- Tabella view row geometry and fixture data — per-screen detail for DESIGN-BIBLE.md, not the design system.
- `MetraMotion` durations beyond the two sanctioned animation specs — legacy/off-canvas values, excluded per advisor guidance.
- Legacy `s0–s12` spacing aliases — excluded per advisor guidance; only canonical `sp*` scale surfaced.
- `bianco` color token — excluded per task spec (nine tokens, not ten).
- Full inchiostro alpha stop table (16 stops) — compressed to the seven stops in the task spec.
- Full accent tint table (13 stops) — compressed to the five most commonly cited stops; full table remains in DESIGN-BIBLE.md § 1.1.2.

-->
