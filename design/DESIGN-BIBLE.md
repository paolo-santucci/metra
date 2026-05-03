# Métra — Design Bible

> **Status:** Canonical source of truth for UI design.
> **Authored:** 2026-05-01.
> **Replaces:** all prior visual decisions. If older specs in `design/`, `lib/theme/`, `STATUS.md`, or any plan contradict this document, **this document wins** — until the HTML mockup itself is updated.

---

## 0. Foreword — Orthodoxy Clause

This bible is a verbatim transcription of the visual language defined in:

```
wiki/design/Métra Screens Light.html
```

Three rules govern its use:

1. **The HTML is canon.** If this bible and the HTML diverge, the HTML wins. Patch the bible to match — never the reverse.
2. **Deviation requires upstream change first.** Any UI change that does not match what is in `wiki/design/Métra Screens Light.html` is forbidden until the HTML mockup itself is updated, reviewed, and committed. Code follows mockup, mockup follows decision — never the reverse.
3. **Read at session start.** Every Claude Code session MUST load this file via `CLAUDE.md` § *Session boot*. No work on UI may begin without it being loaded into context.

### 0.1 Scope

This bible documents the **Light theme** as expressed in `wiki/design/Métra Screens Light.html`. The following files are explicitly **out of scope** for this document:

| File | Status |
|---|---|
| `design/Métra Screens Dark.html` | Future bible (dark variant) — not yet canonised. |
| `design/Métra Quick Entry.html` | Companion sub-flow — derive its tokens from this bible; do not invent new ones. |
| `wiki/design/Métra Design System.html` | Reference catalog — superseded by this bible for any conflict. |
| `design/Métra Prototype.html` | Historical exploration — non-authoritative. |
| `wiki/design/Métra App Icon.html` | Icon-only — separate concern. |

### 0.2 The Tweaks panel is **exploration, not canon**

The HTML mockup ships a `TweaksPanel` (palette / voce / respiro) defaulted to:

```js
{ palette: "terracotta", voce: "romantico", respiro: 1.0 }
```

**Only those three defaults are canonical.** The alternative palettes (`lavanda`, `pietra`), alternative fonts (`netto`, `editoriale`), and the `respiro` slider exist as design-room exploration only. **They MUST NOT ship in the product.** All values in this bible assume `terracotta + romantico + respiro=1.0`.

### 0.3 Wordmark — read this twice

| Glyph | Codepoint | Where it appears |
|---|---|---|
| **`Mētra`** (ē with macron) | U+0113 | The **product wordmark.** Use this in every hero / splash / brand context inside the app. |
| `Métra` (é with acute) | U+00E9 | Canvas chrome only (design-tool labels at lines 1069, 1101 of the HTML). **Not a product variant.** Do not use in app UI. |

A past session burned three attempts implementing the macron via CSS `::before` pseudo-elements before falling back to the literal Unicode glyph. **Use the literal `Mētra` Unicode string** — never compose it with positioning tricks.

---

## 1. Foundation Tokens

### 1.1 Color tokens

The HTML defines these in `const C = { … }` (lines 116–121). Treat them as the **only** colors that may appear in the product. RGBA opacity stops are listed where the mockup actually uses them — do not invent new stops.

| Token | Hex | RGB | Flutter | Role |
|---|---|---|---|---|
| `sabbia` | `#F4EDE2` | 244, 237, 226 | `Color(0xFFF4EDE2)` | Primary screen background. Tab-bar base (with alpha). Text on dark CTAs. |
| `surface` | `#FAF5EE` | 250, 245, 238 | `Color(0xFFFAF5EE)` | Card / section / panel background — sits **above** sabbia. |
| `bianco` | `#FDFAF6` | 253, 250, 246 | `Color(0xFFFDFAF6)` | Reserved white. (Defined; rarely used in screens.) |
| `inchiostro` | `#2B2521` | 43, 37, 33 | `Color(0xFF2B2521)` | Primary text. Selected-day fill. Inchiostro CTA. |
| `terracotta` | `#C87456` | 200, 116, 86 | `Color(0xFFC87456)` | Primary accent. Active tab. Primary CTA. Flow indicator. |
| `tc_scura` | `#9A4D32` | 154, 77, 50 | `Color(0xFF9A4D32)` | Dark accent. Filled-drop icon. Accent text on tinted backgrounds. |
| `ocra` | `#D4A26A` | 212, 162, 106 | `Color(0xFFD4A26A)` | Symptom marker (star). |
| `lavanda` | `#5B4E7A` | 91, 78, 122 | `Color(0xFF5B4E7A)` | Predicted-period outline. |
| `malva` | `#9E7488` | 158, 116, 136 | `Color(0xFF9E7488)` | Pain marker (zap & dots). |
| `muschio` | `#7A8471` | 122, 132, 113 | `Color(0xFF7A8471)` | Defined; reserved (not used in shipped screens). |

#### 1.1.1 Inchiostro alpha stops

Wherever the mockup uses translucent ink, it picks from this fixed scale. **Do not invent intermediate values.**

| `rgba(43,37,33, α)` | Use |
|---|---|
| `0.04` | Note placeholder fill. Faintest neutral chip ground. |
| `0.07` | Card border (the universal "card edge"). Section divider. Stepper-button background. Segmented-control background. Generic neutral chip ground. |
| `0.08` | Tab-bar top border. Calendar-legend top border. Segmented-control track. |
| `0.10` | Selected neutral-flow chip border. Timeline rail line. |
| `0.12` | Note textarea border. Onboarding date-input border (with extra `0.02` weight = `0.14`). Number-stepper inactive track. Phone shadow ring. |
| `0.14` | Onboarding date-input border. |
| `0.22` | Home indicator pill. |
| `0.25` | Inline-add chip dashed border (× 1px). |
| `0.30` | Inactive tab icon. Note-divider mid-tone. |
| `0.32` | "Assente" (neutral) selected dashed border. Pain "Lieve"-step dim text equivalent. |
| `0.35` | Today (unselected) ring suggestion. Day-cell faded text. Onboarding range-marks. |
| `0.38` | Row label (canvas). Empty-state italic hint. |
| `0.40` | Section label. Calendar-icon faded. Caption text. |
| `0.42` | Unselected flow-type chip text. |
| `0.45` | "Assente" hint text. |
| `0.50` | Segmented inactive label. |
| `0.55` | Tab-bar inactive label. |
| `0.58` | Onboarding manifesto subhead text. |
| `0.60` | Symptom chip secondary text in archive. |
| `0.65` | Spotting hint text. |
| `0.68` | Standard subtitle / body-secondary text. Battery icon fill (semi-opaque). |

#### 1.1.2 Accent tints — the canonical recipe

The mockup uses **3-character hex alpha appended to a 6-character hex** (`#RRGGBB` + `AA`). The complete repertoire actually used by the file:

| Stop (8-digit hex) | Alpha % | Use |
|---|---|---|
| `${terracotta}0D` | ≈ 5 % | Spotting hint background. Inline-symptom-input field background. Edit-day CTA (calendar). |
| `${terracotta}10` | ≈ 6 % | Edit-day CTA fill (calendar day card). |
| `${terracotta}14` | ≈ 8 % | Spotting selected chip background. |
| `${terracotta}15` | ≈ 8 % | Archive flow-pill background. |
| `${terracotta}18` | ≈ 9 % | Calendar day-detail flow chip background. |
| `${terracotta}22` | ≈ 13 % | Mestruazioni selected chip background. Calendar flow-day cell background. |
| `${terracotta}28` | ≈ 16 % | Spotting hint border. |
| `${terracotta}44` | ≈ 27 % | Calendar flow-day cell border. Calendar flow chip border. Stat-card accent border. |
| `${terracotta}66` | ≈ 40 % | Spotting selected chip border. |
| `${terracotta}BB` | ≈ 73 % | Mestruazioni selected chip border. |
| `${ocra}18` | ≈ 9 % | Archive symptom chip / day-card symptom chip background. |
| `${ocra}55` | ≈ 33 % | Day-card symptom chip border. |
| `${lavanda}66` | ≈ 40 % | Predicted-period day-cell border. |
| `rgba(158,116,136,0.12)` | 12 % | Archive pain-pill background (literal — not a hex tint). |

Flutter helper:

```dart
// Multiply 6-hex base × alpha-byte using Color.withAlpha or Color.fromARGB.
// Example: terracotta @ 22 hex → withAlpha(0x22) (decimal 34).
Color terracottaTint22 = const Color(0xFFC87456).withAlpha(0x22);
```

### 1.2 Typography

Three families, loaded from Google Fonts:

```
DM Serif Display    — display / hero / large numbers   (italic 0,1)
Inter               — body / labels / numerals         (300, 400, 500, 600)
Cormorant Garamond  — exploration only — DO NOT SHIP
```

Canonical usage:

| Role | Family | Size | Weight | Line-height | Letter-spacing | Notes |
|---|---|---|---|---|---|---|
| Hero wordmark (Onboarding 1) | `DM Serif Display` | 56 | 400 | 1.0 | -0.02em | Single line, no wrap. Color `inchiostro`. |
| Onboarding 1 headline | `DM Serif Display` | 34 | 400 | 1.2 | default | Two lines, manual `<br>`. |
| Onboarding 2 headline | `DM Serif Display` | 30 | 400 | 1.2 | default | |
| Onboarding 3 headline | `DM Serif Display` | 28 | 400 | 1.25 | default | |
| Stepper big number | `DM Serif Display` | 40 | 400 | 1.0 | default | Onboarding cycle-length value. |
| Stat card value | `DM Serif Display` | 32 | 400 | 1.0 | default | Numeric KPI. |
| Screen-title (Calendar / Today / Archive / Stats) | `DM Serif Display` | 26 | 400 | 1.1 | default | Sometimes accompanies a 13px subtitle. |
| Day-detail card title | `DM Serif Display` | 20 | 400 | default | default | "Lunedì 10 aprile". |
| Archive timeline month | `DM Serif Display` | 17 | 400 | default | default | |
| Status-bar clock | `Inter` | 15 | 600 | default | -0.02em | Mockup-only. |
| Body / button label / nav | `Inter` | 16 | 500 (CTA) / 400 (body) | 1.55–1.6 | default | All primary CTAs. |
| Onboarding subhead | `Inter` | 15–16 | 400 | 1.55–1.6 | default | |
| List item title | `Inter` | 15 | 500 | default | default | Privacy-card title. |
| Date subtitle (Today) | `Inter` | 13 | 400 | default | default | "Mercoledì 23 aprile". |
| Body secondary | `Inter` | 13 | 400 | 1.5 | default | Privacy-card sub. |
| Filter / chip label | `Inter` | 13 | 400 (idle) / 500 (selected) | default | default | |
| Cycle-day caption (Calendar header) | — | — | — | — | — | Removed: redundant with day-detail card. |
| Inline note placeholder | `Inter` | 15 | 400 | default | default | |
| Pill text (flow / pain / symptom) | `Inter` | 11–12 | 500 | default | default | Smaller in archive (`11`), larger in day card (`12`). |
| Section label (uppercase) | `Inter` | 12 | 600 | default | **0.06–0.07em** | All caps. Color rgba(43,37,33,0.4). |
| Day-header letters (L M M G V S D) | `Inter` | 12 | 600 | default | 0.04em | Color rgba(43,37,33,0.35). |
| Range marker (Onboarding 3 numerals) | `Inter` | 11 | 400 | default | default | Color 0.35 alpha. |
| Indicator-dot label (under flow / pain dots) | `Inter` | 10 | 400 (idle) / 600 (selected) | default | default | |
| Tab-bar label | `Inter` | 10 | 400 (idle) / 600 (active) | default | default | |
| Row-label (canvas chrome — NOT product) | `Inter` | 11 | 600 | default | 0.08em | Out of scope. |

#### 1.2.1 Italic policy

Italic `DM Serif Display` is loaded by the mockup but **not used** in any screen. Empty-state hint text uses `font-style: italic` on **Inter** (e.g. "Nessun dato registrato"). Italic on display fonts is reserved.

### 1.3 Spacing

The mockup uses a soft, eight-anchored scale. The values that actually appear:

`0 · 2 · 3 · 4 · 5 · 6 · 7 · 8 · 10 · 12 · 14 · 16 · 18 · 20 · 24 · 28 · 32 · 36 · 44 · 48 · 56 · 72 · 84 · 90 · 100`

Memorise the **canvas-gap** (`72px`) for design-tool layout only — it is `--canvas-gap` and irrelevant in product.

Interior padding patterns (memorise these — they recur):

| Pattern | Value | Where |
|---|---|---|
| Screen-edge horizontal (calendar / archive / stats / today header) | `24px` | |
| Screen-edge horizontal (onboarding 2 / 3) | `28px` | |
| Section vertical padding (today screen) | `18px` | |
| Section horizontal padding (today screen) | `24px` | |
| Card padding (privacy, stat, archive) | `14–18px` | |
| Day-detail card padding | `16px / 20px` (V / H) | |
| Calendar-grid horizontal padding | `12px` | |
| Tab-bar height | `84px` | |
| Tab-bar inner top-pad | `10px` | |
| Bottom CTA-row padding (today) | `20px / 24px` | |
| Bottom safe area (lists with tab-bar overlay) | `90–100px` | Equivalent to tab-bar height + inset. |

### 1.4 Corner radii

| Radius | Where |
|---|---|
| `6px` | Archive-table cells & header pills (`borderRadius: 6`). |
| `8px` | Archive segmented-control inner buttons. Day-card symptom chip. |
| `10px` | Range-track. Stepper button. Segmented-control track. Onboarding period-day buttons. Spotting hint box. |
| `12px` | **Calendar day cell.** Flow-type chip. Date input row. Note textarea. Stat-card edges. Edit-day CTA. Privacy-card icon tile. |
| `14px` | Archive timeline card. |
| `16px` | Stat card. Privacy info card. **All primary CTAs.** Cycle-length container. |
| `18px` | Symptom chip (capsule — `paddingInline: 14, height: 36, radius: 18`). |
| `20px` | Day-detail card. |
| `44px` | Phone shell (mockup chrome only). |
| `50%` | Halo dots, timeline node, checkbox circle, moon icon. |

`Chip pill rule: radius = ½ × height` is **always** true for chips and circular indicators. Never use `999px`.

### 1.5 Borders

Three universal recipes:

```
Card edge:       1px solid rgba(43,37,33,0.07)     // surface card on sabbia
Section divider: 1px solid rgba(43,37,33,0.07)     // both top & bottom of today sections
Strong outline:  1.5px solid rgba(43,37,33,0.14)   // onboarding date-input
```

Plus state-specific accent borders enumerated under each component below.

Dashed borders appear in exactly two places:

* `1.5px dashed rgba(43,37,33,0.32)` — Assente (neutral) flow chip when **selected**.
* `1.5px dashed ${lavanda}66` (predicted-period day cell) — but in the canvas the predicted cell is rendered with **solid** lavender 66 at 1.5px. Implementation reference says "dashed lavender" — defer to the canvas: **solid** unless the HTML changes.
* `1px dashed rgba(43,37,33,0.25)` — inline "Aggiungi" chip in symptom row.

### 1.6 Shadows

The mockup uses depth in two places only:

| Shadow | Where |
|---|---|
| `0 0 0 1px rgba(43,37,33,0.14), 0 4px 16px rgba(43,37,33,0.12), 0 16px 56px rgba(43,37,33,0.2)` | Phone shell — **mockup chrome only**, do not ship in product. |
| `0 1px 4px rgba(43,37,33,0.12)` | Active segmented-control button. |

No drop-shadows on cards, buttons, sheets, or dialogs. Elevation is communicated through borders and surface-color contrast, not shadow.

### 1.7 Backdrop blur

Exactly one location: tab-bar background uses `backdrop-filter: blur(16px)` over `rgba(244,237,226,0.96)`. Reproduce in Flutter via `BackdropFilter(filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16), child: ColoredBox(color: sabbia.withOpacity(0.96)))`.

---

## 2. Iconography

### 2.1 Stroke icons (`Icon` component, line 124)

24×24 viewBox · `stroke-linecap: round` · `stroke-linejoin: round` · `fill: none` · default `stroke = 1.5` (active tab `2`, status-bar wifi `1.8`, battery `1.4`).

Catalog (all of them — do not add icons that are not in this list without updating the mockup first):

```
chevron_right · chevron_left · chevron_down · x
lock · cloud · drop · wave · plus · check
settings · chart · calendar · note
wifi · battery · filter · info
leaf · export · moon_crescent · star_small
```

**Catalog gap — external-link glyph.** The catalog has no `open_in_new` / `arrow_up_right`. The Impostazioni external-link rows (§19) use `chevron_right` uniformly, identical to internal-navigation rows; the row label disambiguates the destination. If a future revision needs to distinguish internal vs external clearly, add a glyph here first — never inline a Material `Icons.open_in_new` in the product.

### 2.2 Filled data icons (`DataIcon` component, line 154)

12–14 px default · viewBox 24×24 · `fill = color` (single colour pass).

```
drop          — filled drop          (mestruazioni)
drop_outline  — outline drop         (predicted period)
moon_crescent — filled crescent      (cycle-day affordance)
star_small    — filled 4-point star  (symptom)
zap           — filled lightning     (pain)
```

These five icons are the **semantic markers** of the system. They appear:

* Under day numbers in the calendar grid (size 11).
* Inside flow / pain / symptom pills in archive and day-detail (size 11–14).
* In the calendar legend strip (size 14).

### 2.3 Bespoke moon

`Moon` component (line 166) renders 5 phases (0 = new through 4 = full) over a stroked circle. Used at 14 px in the calendar header (phase 2). The five fill paths are defined verbatim in the HTML; do not redraw.

---

## 3. Phone shell & status bar (mockup chrome — non-product)

For completeness only: `393×760` rounded `44`, status bar `54` tall, dynamic island `120×36` rounded `20`, home indicator `134×5` rounded `3`. **None of this ships.** It exists to frame screens in the design canvas.

The canonical clock value in the mockup is `20:14`. Do not surface this anywhere outside design previews.

---

## 4. Tab bar

Four tabs, in this order:

| ID | Icon | Italian label |
|---|---|---|
| `cal` | `calendar` | Calendario |
| `history` | `wave` | Archivio |
| `stats` | `chart` | Statistiche |
| `settings` | `settings` | Impostazioni |

Geometry:

* Height `84`.
* Background `rgba(244, 237, 226, 0.96)` + `backdrop-filter: blur(16)`.
* Top border `1px solid rgba(43, 37, 33, 0.08)`.
* Top inner padding `10`.

Per tab:

* Icon size `24`. Active stroke `2`, color `terracotta`. Inactive stroke `1.5`, color `rgba(43,37,33,0.30)`.
* Label `Inter 10`. Active `weight 600` color `terracotta`. Inactive `weight 400` color `rgba(43,37,33,0.55)`.
* Gap between icon and label `3`.

There is **no center-FAB**, **no badges**, **no slide indicator**. The active state is colour + weight only.

---

## 5. Buttons

### 5.1 Primary CTA (the only "button" in the system)

Geometry: `height 56` · `radius 16` · centered content · `Inter 16 / weight 500`.

Two variants — chosen by **screen role**, not user preference:

| Variant | Background | Label color | Used on |
|---|---|---|---|
| **Inchiostro** | `inchiostro` `#2B2521` | `sabbia` | Onboarding 1 ("Inizia"), Onboarding 3 ("Tutto pronto →"). Use for **brand entry / completion** actions. |
| **Terracotta** | `terracotta` `#C87456` | `sabbia` | Onboarding 2 ("Continua"), Today ("Salva giornata" — with leading 18 px check icon, gap 8). Use for **commit / save** actions. |

There is no third variant. No outline buttons, no ghost buttons, no destructive buttons in scope.

### 5.2 Stepper micro-button (Onboarding 3 ± controls)

`40 × 40` · radius `10` · background `rgba(43,37,33,0.07)` · glyph `−` or `+` `font-size 20` color `inchiostro`. Hover/active state not defined; do not invent one.

### 5.3 Period-day cell (Onboarding 3 — "Durata mestruazioni")

8 cells in a row, `flex: 1, height: 44, radius: 10`. Active = bg `terracotta`, text `sabbia` 500. Idle = bg `rgba(43,37,33,0.07)`, text `inchiostro` 500, border `1px solid rgba(43,37,33,0.12)` (transparent border on active).

### 5.4 Segmented control (Archivio)

Track `inline-flex`, `bg rgba(43,37,33,0.08)`, `radius 10`, `padding 3`, `gap 2`. Each segment `paddingInline 18, height 34, radius 8`. Active `bg sabbia`, shadow `0 1px 4px rgba(43,37,33,0.12)`, label `weight 500 inchiostro`. Idle `bg transparent`, label `weight 400 rgba(43,37,33,0.5)`. Labels are CSS `text-transform: capitalize` — they store as lowercase keys (`timeline`, `tabella`).

---

## 6. Form atoms

### 6.1 Choice chip

```
height 36 · paddingInline 14 · radius 18
font Inter 13 weight 500
selected:    bg terracotta,            text sabbia,      border 1px transparent
unselected:  bg rgba(43,37,33,0.07),   text inchiostro,  border 1px solid rgba(43,37,33,0.12)
transition all 0.15s
```

There is **no checkmark** on selected chips. Selection is communicated by colour and border-disappearance. Implementations that draw a `✓` glyph violate the bible.

### 6.2 Inline "Aggiungi" affordance (in symptoms row)

Idle:

```
inline-flex · paddingInline 14 · height 36 · radius 18
border 1px dashed rgba(43,37,33,0.25)
glyph "+" Inter 18 color rgba(43,37,33,0.35)
label "Aggiungi" Inter 13 color rgba(43,37,33,0.40)
```

Editing (`addingSymptom = true`):

```
inline-flex · height 36 · radius 18
border 1.5px solid terracotta
bg ${terracotta}0D
input: Inter 13 inchiostro · width 110 · transparent · placeholder "es. Vertigini"
trailing OK pill: paddingInline 12 · height 36 · bg terracotta · text sabbia 13/500
```

Pressing `Enter` confirms; `Escape` discards. Empty / duplicate inputs silently dismiss.

### 6.3 Date input row (Onboarding 3)

```
height 52 · radius 12 · bg surface · border 1.5px solid rgba(43,37,33,0.14)
paddingInline 16 · justify space-between
left:  text Inter 16 inchiostro                  ("10 aprile 2025")
right: Icon calendar 18 rgba(43,37,33,0.40)
```

### 6.4 Number stepper (Onboarding 3 — "Durata media ciclo")

```
row gap 16
left  : stepper micro-button "−"
center: <Display 40 inchiostro>{n}</Display>  +  Inter 16 rgba(0.68) "giorni" (left margin 6)
right : stepper micro-button "+"
below : 4-tall track rgba(43,37,33,0.08) radius 2
        filled width = (n - 21) / (45 - 21) × 100 %, terracotta
        labels "21" / "45" Inter 11 rgba(0.35) at 4 top-margin, justified
range : [21, 45]
```

### 6.5 Note textarea

```
min-height 72 · radius 12
bg rgba(43,37,33,0.04)
border 1.5px solid rgba(43,37,33,0.12)
padding 12 / 14 (V / H)
placeholder "Scrivi qualcosa…" Inter 15 rgba(0.35)
```

### 6.6 Privacy-card checkbox

`36×36` outer SVG · circle radius `16`. Checked = fill `terracotta`, stroke `terracotta`, white check path (stroke `sabbia`, weight 1.8). Unchecked = transparent fill, stroke `rgba(43,37,33,0.20)`. Tap toggles in-place; no animation specified.

### 6.7 MetraToggle (binary state)

The settings-screen on/off control. Used wherever a setting is a true binary state (Mostra dolore, Mostra note, Promemoria ciclo).

```
track:      48 × 28 · radius 14                       (chip rule: ½ × height)
dot:        22 × 22 · radius 11 · fill C.surface      (sits 3 px inside the track)
dot offset: off → translateX(3) · on → translateX(23)
track on:   background C.terracotta
track off:  background rgba(43,37,33,0.08)            // §1.1.1 segmented-control track stop
transitions:
  - track background 0.15s
  - dot horizontal position 0.15s
no shadow, no halo, no checkmark glyph
```

Tap inverts state; no long-press or drag affordance.

There is no third state (no indeterminate, no "off-but-temporarily-locked"). If a setting requires a three-state UX, model it as a value-row with a chevron — not a toggle.

---

## 7. Specialized data-entry atoms

### 7.1 FlowTypeChips — three-state

Three chips in a row, each `flex: 1, height: 44, radius: 12, fontSize 13`.

| ID | Label | Variant | Selected bg | Selected border | Selected text |
|---|---|---|---|---|---|
| `assente` | Assente | `neutral` | `rgba(43,37,33,0.08)` | `1.5px dashed rgba(43,37,33,0.32)` | `inchiostro` |
| `mestruazioni` | Mestruazioni | `flow` | `${terracotta}22` | `1.5px solid ${terracotta}BB` | `tc_scura` |
| `spotting` | Spotting | `spot` | `${terracotta}14` | `1.5px solid ${terracotta}66` | `tc_scura` |

Idle state (all three): bg `rgba(43,37,33,0.04)`, border `1px solid rgba(43,37,33,0.10)`, text `rgba(43,37,33,0.42)` weight 400. Selected text always weight 500.

Tapping an already-selected chip clears (`onChange(null)`).

### 7.2 FlowIntensityDots — three dots

Visible **only when `flowType === 'mestruazioni'`**. Three dots, `paddingTop 16, paddingBottom 2, gap 10`, centered horizontally.

Each dot:
```
SVG box = 50 × 50      (R = 18, padding 7)
filled circle: r 18 · fill terracotta · fillOpacity per level · stroke terracotta · strokeWidth 1.4
selected halo (outside): r 23 · stroke terracotta · strokeWidth 1.2 · opacity 0.3
label below: Inter 10 · gap 7 above
```

Levels:

| ID | Label | fillOpacity | Label color (sel) | Label weight (sel) |
|---|---|---|---|---|
| 1 | Leggero | 0.30 | `tc_scura` | 600 |
| 2 | Moderato | 0.65 | `tc_scura` | 600 |
| 3 | Abbondante | 0.94 | `tc_scura` | 600 |

Idle label: color `rgba(43,37,33,0.40)` weight 400.

### 7.3 PainDots — four dots

Always visible inside the "Intensità dolore" section. Four dots, `gap 14`. Same SVG geometry as flow dots (R 18, halo r 23, halo strokeWidth 1.2 opacity 0.28). Color = **`malva`**. `strokeWidth 1.5`.

| ID | Label | fillOpacity |
|---|---|---|
| 0 | Nessuno | 0.00 |
| 1 | Lieve | 0.28 |
| 2 | Moderato | 0.60 |
| 3 | Intenso | 0.92 |

Selected label: `malva` weight 600. Idle label: `rgba(43,37,33,0.38)` weight 400.

Tapping selected clears (`onChange(null)`).

### 7.4 Hint boxes (within Flusso section)

Spotting selected hint:
```
marginTop 14 · padding 11/14 · radius 10
bg ${terracotta}0D · border 1px solid ${terracotta}28
text Inter 12 line-height 1.55 color rgba(43,37,33,0.65)
copy: "Piccola perdita fuori dal flusso mestruale. Non è necessariamente l'inizio del ciclo."
```

Assente selected hint:
```
marginTop 14 · row · gap 8
icon: 16-px check stroke rgba(43,37,33,0.35) weight 2
text Inter 12 color rgba(43,37,33,0.45)
copy: "Nessun flusso oggi"
```

---

## 8. Calendar grid system

### 8.1 Header

```
padding 12 / 24 / 0
left:
  Display 26 inchiostro · line 1.1            (e.g. "Aprile 2025")
right: row gap 2 · alignItems center:
  Icon chevron_left  22 inchiostro            (always enabled; no past limit)
  "Oggi" · Inter 13 weight 500 inchiostro     (always visible; minWidth 44 minHeight 44 centered)
           tap → navigate to current month AND select today's cell
  Icon chevron_right 22 inchiostro / rgba(0.40) when disabled
           (disabled only when displayed month = current month + 1; active otherwise)
```

Swipe gesture (supplementary to the chevrons): a horizontal drag on the calendar grid navigates prev/next month. Left swipe = next month (guarded by the same right-chevron limit); right swipe = previous month (no limit). Velocity threshold ≥ 200 px/s. This is a progressive-enhancement behavior — no visual affordance is added for it.

### 8.2 Day-headers row

`grid 7 columns · padding 16 / 12 / 4 / 12`. Cells:

```
text-align center
Inter 12 weight 600 rgba(0.35) letter-spacing 0.04em
labels: L M M G V S D    (Italian, week starts Monday)
```

### 8.3 Day cells

Container: `grid 7 columns · padding 0 / 12 · row-gap 2`. Each cell:

```
48 × 48 · radius 12
display flex column · centered · gap 1
text Inter 15 color inchiostro weight 400
```

#### 8.3.1 State table (read this carefully — it is the most violated rule)

| State | bg | border | text color | text weight |
|---|---|---|---|---|
| **Selected** | `inchiostro` | none | `sabbia` | 600 |
| **Flow** | `${terracotta}22` | `1px solid ${terracotta}44` | `inchiostro` | 400 |
| **Predicted** | transparent | `1.5px solid ${lavanda}66` | `inchiostro` | 400 |
| **Today** (unselected) | transparent | `1.5px solid rgba(43,37,33,0.35)` (rounded square) | `inchiostro` | 400 |
| **Default** | transparent | `1px solid transparent` | `inchiostro` | 400 |
| **Empty (offset)** | — | — | — | (slot is just `48×48` blank) |

Selection wins over flow which wins over predicted which wins over today.

#### 8.3.2 Indicator dots row

If any of `[isFlow, isPred, hasSymptom, hasPain]` are true, a 1-row pack appears under the day number:

```
row · gap 2 · alignItems center
each indicator: DataIcon size 11 color (see below)
```

Color rule: when the cell is **selected**, every indicator becomes `sabbia` (`#F4EDE2`). Otherwise:

| Predicate | Icon | Color |
|---|---|---|
| `isFlow` | `drop` | `tc_scura` |
| `isPred` | `drop_outline` | `lavanda` |
| `hasSymptom` | `star_small` | `ocra` |
| `hasPain` | `zap` | `malva` |

Order is fixed in that priority: drop, drop_outline, star_small, zap.

### 8.4 Legend strip

```
row · gap 16 · padding 10 / 24 · border-top 1px solid rgba(43,37,33,0.07)
each item: row · gap 5
  DataIcon size 14
  Inter 11 rgba(0.68)
items in order:
  drop          tc_scura  Mestruazioni
  star_small    ocra      Sintomi
  zap           malva     Dolore
  drop_outline  lavanda   Previsione
```

### 8.5 Day-detail card

```
margin 4 / 16 · radius 20 · bg surface · border 1px rgba(43,37,33,0.07)
padding 16 / 20  · flex 1   (always fills remaining vertical space)
```

Content rows (top to bottom):

1. **Header** (full-width, no right badge):
   - `DM Serif Display 20 inchiostro` — `"{Lunedì} {sel} {aprile}"`.
   - If selected day is in flow window: `Inter 13 rgba(0.68)` `"Giorno {n} del ciclo"` marginTop 2.
   - If `!hasEntry`: `Inter 12 rgba(0.38) italic` `"Nessun dato registrato"` marginTop 4.
   - `marginBottom 10` when `hasEntry`, `12` otherwise.

2. **Pills row** (only if `hasEntry` and at least one data point) — `Wrap gap 6 runGap 4, marginBottom 10`:
   Each pill: `height 24, radius 6, paddingInline 8, DataIcon filled size 11, gap 4, Inter 11`
   - **Flow pill** (if flow logged): `bg ${terracotta}15`, icon `drop` terracotta, text tc_scura. Label: "Abbondante" / "Moderato" / "Leggero" / "Spotting" / "Assente".
   - **Pain pill** (if `painIntensity > 0`): `bg ${malva}1F`, icon `zap` malva, text malva. Label: "Lieve" / "Moderato" / "Forte".
   - **Symptom pills** (one per symptom): `bg ${ocra}18`, icon `star_small` dustyOchre, text tc_scura.

3. **Note text** (if notes non-empty and notes enabled): `Inter 13 rgba(0.68) lineHeight 1.5, marginBottom 10`.

4. **CTA button**:
   ```
   height 44 · radius 12
   bg ${terracotta}10 · border 1px solid ${terracotta}22
   centered icon `note` 16 terracotta + label Inter 14 weight 500 tc_scura, gap 6
   label: "Modifica giornata" if entry exists; "Aggiungi giornata" otherwise
   ```

There is **no FAB** anywhere on the calendar screen. The only mutation entry point is this CTA.

### 8.6 Italian L10n (calendar)

```js
WEEKDAYS = ['Lunedì','Martedì','Mercoledì','Giovedì','Venerdì','Sabato','Domenica']
DAY_HEADERS = ['L','M','M','G','V','S','D']
MONTHS_IT = ['gennaio','febbraio','marzo','aprile','maggio','giugno','luglio','agosto','settembre','ottobre','novembre','dicembre']
```

Week starts **Monday**. Month names are lowercase, day-of-week names capitalised.

---

## 9. Today / Daily entry screen

### 9.1 Screen container

```
overflow-y auto · padding-bottom 100
bg sabbia
```

The tab bar overlays the bottom 84 px; the 100 px bottom padding gives breathing room.

### 9.2 Header

```
padding 12 / 24 / 16
Inter 13 rgba(0.68)               "Mercoledì 23 aprile"
DM Serif Display 26 inchiostro    "Come stai oggi?"
```

### 9.3 Section frame (used for Flusso, Dolore, Sintomi, Nota)

```
bg surface
borderTop / borderBottom 1px solid rgba(43,37,33,0.07)   (top border on first section, bottom on every section)
padding 18 / 24
column · gap 1                                            (between sections)
```

Section label:

```
Inter 12 weight 600 letter-spacing 0.06em UPPERCASE color rgba(43,37,33,0.40)
margin-bottom 14   (12 for the Note section)
```

### 9.4 Section: Flusso

Label: `FLUSSO`. Content:

1. `FlowTypeChips` (§ 7.1).
2. **If `flowType === 'mestruazioni'`** → `FlowIntensityDots` (§ 7.2).
3. **If `flowType === 'spotting'`** → spotting hint box (§ 7.4).
4. **If `flowType === 'assente'`** → assente hint row (§ 7.4).

### 9.5 Section: Intensità dolore

Label: `INTENSITÀ DOLORE`. Content: `PainDots` (§ 7.3) — always rendered.

### 9.6 Section: Sintomi

Label: `SINTOMI`. Content: `wrap, gap 8`:

* Each predefined symptom rendered as a § 6.1 choice chip wrapped in `min-height 44 row centered` to keep tap targets even when chip wraps to multi-line.
* Trailing inline-add affordance (§ 6.2).

Default symptom list (preserve order):

```
Crampi · Mal di testa · Stanchezza · Mal di schiena · Nausea · Gonfiore · Tensione mammaria
```

Custom symptoms append after the predefined list.

### 9.7 Section: Nota libera

Label: `NOTA LIBERA`. Content: § 6.5 textarea. Margin-bottom on label = 12 (slightly tighter than the 14 of other sections).

### 9.8 Save CTA

Padding `20 / 24 / 0`. Terracotta-variant primary CTA (§ 5.1) with leading `check` icon (`size 18`, `stroke 2`, color `sabbia`) and label `Salva giornata` (gap 8).

---

## 10. Archivio screen

### 10.1 Header

```
padding 12 / 24 / 14
Display 26 inchiostro   "Archivio"
margin-bottom 12
segmented control (§ 5.4) with two segments: "timeline" / "tabella"
```

Default selection: `timeline`.

### 10.2 Scroll body

`flex 1, overflow-y auto, padding-bottom 90`.

### 10.3 Timeline view

`padding 4 / 20 · column gap 0`. Each entry:

```
row · gap 16 · alignItems stretch
left rail (width 20 · column · centered):
  dot:  12 × 12 · radius 50% · bg terracotta · marginTop 18
  line: 2px wide · flex 1 · bg rgba(43,37,33,0.10) · marginTop 2
        (omitted on the last entry)
right card (flex 1):
  bg surface · radius 14 · border 1px rgba(43,37,33,0.07)
  padding 14 / 16 · marginBottom 12
```

Card content (top to bottom):

1. Row `space-between baseline marginBottom 6`: `DM Serif Display 17 inchiostro` month label + `Inter 12 rgba(0.40)` "Durata {n}g".
2. Row `wrap gap 8` of mini-pills (height 24, radius 6):
   * **Flow pill** (always): bg `${terracotta}15`, `DataIcon drop 11 tc_scura`, label `Inter 11 tc_scura`.
   * **Pain pill** (if `pain > 0`): bg `rgba(158,116,136,0.12)`, `DataIcon zap 11 malva`, label `Inter 11 malva` from `["", "Lieve", "Moderato", "Intenso"]`.
   * **Symptom pills** (first two only): bg `${ocra}18`, `DataIcon star_small 11 ocra`, label `Inter 11 rgba(0.60)`.
3. Footer: `Inter 12 rgba(0.40), marginTop 8` — `"Ciclo {len}g · dal {day}"`.

### 10.4 Tabella view

```
padding 0 / 20
header: grid "1fr 60px 50px 80px" · gap 8 · padding 10 / 12
        bg rgba(43,37,33,0.05) · radius 10 · marginBottom 6
        cells: Inter 11 weight 600 rgba(0.68) letter-spacing 0.04em
        labels: "Mese", "Ciclo", "Dur.", "Flusso"
rows:   same grid · padding 14 / 12 · bg surface · radius 12 · marginBottom 4
        border 1px solid rgba(43,37,33,0.06)
        cells:
          mese:   Inter 14 inchiostro
          ciclo:  Inter 14 rgba(0.6)         (suffixed "g" — e.g. "28g")
          dur.:   Inter 14 rgba(0.6)         (suffixed "g")
          flusso: Inter 13 tc_scura
```

### 10.5 Sample fixture data (for visual QA only)

```
Apr 2025 · day 10 · len 28 · dur 5 · flow Abbondante · pain 3 · symptoms [Crampi, Stanchezza]
Mar 2025 · day 11 · len 27 · dur 4 · flow Moderato   · pain 2 · symptoms [Mal di testa]
Feb 2025 · day 12 · len 29 · dur 5 · flow Moderato   · pain 3 · symptoms [Crampi, Mal di schiena]
Gen 2025 · day 14 · len 28 · dur 4 · flow Leggero    · pain 1 · symptoms []
Dic 2024 · day 17 · len 30 · dur 6 · flow Abbondante · pain 3 · symptoms [Crampi, Nausea]
```

---

## 11. Statistiche screen

### 11.1 Header

```
padding 12 / 24 / 16
Display 26 inchiostro   "Statistiche"
Inter 13 rgba(0.68) marginTop 2   "Ultimi 6 cicli"
```

### 11.2 Body

`flex 1 · overflow-y auto · padding 0 / 16 / 90`.

### 11.3 StatCard grid

`flex wrap · gap 10 · marginBottom 16`. Each card:

```
flex: 1 1 calc(50% - 6px)
bg surface · radius 16
border 1px solid (accent ? `${terracotta}44` : rgba(43,37,33,0.07))
padding 16 / 18
```

Card content:

```
title: Inter 12 rgba(0.68) · marginBottom 6
row baseline gap 4:
  value: DM Serif Display 32 (terracotta if accent else inchiostro)
  unit:  Inter 14 rgba(0.68)
sub:   Inter 12 rgba(0.68) marginTop 4    (optional)
```

Order on screen and contents (verbatim from mockup):

1. **accent** — title `"Durata media ciclo"`, value `28`, unit `giorni`, sub `"Range: 27–30g"`.
2. title `"Durata media flusso"`, value `4.8`, unit `giorni`, sub `"Range: 4–6g"`.
3. title `"Dolore medio"`, value `2.4`, unit `/3`, sub `"Trend in calo"`.
4. title `"Cicli tracciati"`, value `6`, unit `totali`, no sub.

### 11.4 MiniBar chart

Wrapper card:

```
bg surface · radius 16 · border 1px rgba(43,37,33,0.07) · padding 18 / 16 · marginBottom 12
title row: Inter 13 weight 500 inchiostro · marginBottom 16
```

Bar group: `row · gap 4 · alignItems flex-end`. Each bar:

```
column · alignItems center · gap 5 · flex 1
height 80 box flex-end:
  bar 28 wide · radius 4 / 4 / 0 / 0 · color = chart color · opacity 0.85
  height = value / max × 80   (px)
label below: Inter 10 rgba(0.68)
value below: Inter 13 weight 500 inchiostro
```

Two charts in this order:

| Chart | Color | Max | Series (A M F G D N) |
|---|---|---|---|
| `Durata ciclo (giorni)` | `terracotta` | 35 | 28, 27, 29, 28, 30, 28 |
| `Intensità dolore (0–3)` | `malva` | 5 | 3, 2, 3, 1, 4, 2 |

### 11.5 Symptom-frequency card

Wrapper card same as 11.4. Title `"Sintomi più frequenti"` · marginBottom 14.

Each row (`marginBottom 10`):

```
row space-between marginBottom 4:
  Inter 13 inchiostro          (label)
  Inter 13 rgba(0.68)          ("{count}/{max}")
track: height 6 · radius 3 · bg rgba(43,37,33,0.08)
fill:  height 6 · radius 3 · bg ocra · width = count / max × 100 %
```

Series:

```
Crampi          5/6
Stanchezza      4/6
Mal di testa    3/6
Mal di schiena  2/6
```

---

## 12. Onboarding screens (2 of 2)

### 12.1 Onboarding 1 — Manifesto

```
bg sabbia · column · height 100%
hero block (flex 0 0 340):
  centered overflow-hidden
  radial gradient ellipse 90 % × 60 % @ 50 % 30 %, rgba(200,116,86,0.05) → transparent 80 %
  centered halo: 220 × 220 radius 50% · radial rgba(200,116,86,0.12) → transparent 70 %
  wordmark "Mētra" DM Serif Display 56 inchiostro letter-spacing -0.02em white-space nowrap
text block (flex 1 · padding 0 / 36 / 28):
  headline DM Serif Display 34 inchiostro line 1.2 marginBottom 14:
    "Il tuo ritmo,⏎custodito."
  subhead Inter 16 rgba(0.58) line 1.6:
    "Mētra è un quaderno silenzioso per conoscerti, ciclo dopo ciclo.\n\n
     Tutto rimane sul tuo telefono: nessun account, nessun cloud richiesto."
  ornament (column · gap 6 · marginBottom 24):
    SVG 48 × 22:
      line  (6,4)→(42,4) terracotta strokeWidth 4 round
      circle  cx 12 cy 16 r 3 fill terracotta opacity 0.40
      circle  cx 24 cy 16 r 3 fill terracotta opacity 0.65
      circle  cx 36 cy 16 r 3 fill terracotta opacity 0.40
  CTA (§ 5.1 inchiostro variant): "Inizia"
```

### 12.2 Onboarding 2 — Privacy [NON-CANONICAL — REMOVED FROM PRODUCT FLOW]

> **The HTML canvas (`Métra Screens Light.html`) defines `ScreenOnboarding2` but does not render it. It is therefore non-canonical and must not ship.** The onboarding flow is Manifesto → Primo Ciclo only (2 steps). Do not resurrect this screen.

### 12.3 Onboarding 2 — Primo Ciclo

```
bg sabbia · padding 20 / 28 · column
progress: 2 segments height 3 radius 2 gap 6 · both filled terracotta · marginBottom 24
section label "Passo 2 di 2" (§ 12.2 typography) marginBottom 8
headline DM Serif Display 28 inchiostro line 1.25 marginBottom 8:
  "Raccontami⏎il tuo ciclo."
subhead Inter 14 rgba(0.68) line 1.5 marginBottom 28:
  "Puoi sempre modificarlo dopo. Non servono risposte precise."

field 1 — last period (marginBottom 24):
  micro-label Inter 12 weight 600 letter-spacing 0.06em UPPERCASE rgba(0.40) marginBottom 10
    "PRIMO GIORNO DELL'ULTIMA MESTRUAZIONE"
  date input row (§ 6.3) — content "10 aprile 2025"

field 2 — cycle length (marginBottom 24):
  micro-label "DURATA MEDIA CICLO"
  number stepper (§ 6.4) — default 28

field 3 — period duration (marginBottom 28):
  micro-label "DURATA MESTRUAZIONI"
  row · gap 8 of 8 cells (§ 5.3) numbered 1..8 · default 5

CTA (§ 5.1 inchiostro variant) at marginTop auto: "Tutto pronto →"
```

> The mockup canvas only renders Manifesto + Primo Ciclo. `ScreenOnboarding2` (Privacy) is defined in the file but not rendered — it is non-canonical. The product flow is **2 screens**: Manifesto → Primo Ciclo.

### 12.4 Progress bar pattern

* Stripe `flex 1 height 3 radius 2`. Track `rgba(43,37,33,0.12)`. Filled `terracotta`. Inter-stripe gap `6`.
* Margin below the strip: 24–32 depending on screen (Onboarding 2 = 32, Onboarding 3 = 24).
* Filled count = current step number; total stripes = total steps.

---

## 13. Empty-state and edge-case copy

| Locale (IT) | Where |
|---|---|
| `Nessun dato registrato` | Calendar day-detail when no flow logged. Italic. |
| `Nessun flusso oggi` | Today screen, "Assente" hint. |
| `Piccola perdita fuori dal flusso mestruale. Non è necessariamente l'inizio del ciclo.` | Today screen, "Spotting" hint box. |
| `Scrivi qualcosa…` | Note textarea placeholder. |
| `es. Vertigini` | Inline-add symptom input placeholder. |

These are **canonical strings**. Surface them in `lib/l10n/app_it.arb` exactly as written (including casing, ellipsis character `…`, and accented apostrophes `'`).

---

## 14. Italian-first L10n vocabulary

| English | Italian | Notes |
|---|---|---|
| Calendar | Calendario | Tab + screen title. |
| Today | Oggi | Tab label. |
| Archive | Archivio | Tab + screen title. |
| Statistics | Statistiche | Tab + screen title. |
| Settings | Impostazioni | Tab. |
| Flow | Flusso | Section label (uppercase). |
| Pain intensity | Intensità dolore | Section label. |
| Symptoms | Sintomi | Section label. |
| Free note | Nota libera | Section label. |
| Save day | Salva giornata | Today CTA. |
| Edit day | Modifica giornata | Calendar day-card CTA (entry already logged). |
| Add day | Aggiungi giornata | Calendar day-card CTA (no prior entry). |
| Continue | Continua | Onboarding 2 CTA. |
| Start | Inizia | Onboarding 1 CTA. |
| All set → | Tutto pronto → | Onboarding 3 CTA. The arrow is part of the label. |
| Step n of m | Passo n di m | Onboarding sub-label, lowercase except the leading word and "P". |
| Cycle day n | Giorno n | Calendar header second line. Also `Giorno n del ciclo` in day-card. |
| Mestruazioni | Mestruazioni | Flow type. |
| Assente | Assente | Flow type (no flow). |
| Spotting | Spotting | Flow type (loanword — keep English). |
| Leggero / Moderato / Abbondante | — | Flow intensity labels. |
| Nessuno / Lieve / Moderato / Intenso | — | Pain levels (NB pain has 0 = Nessuno; flow intensity does not). |
| Preferenze | Preferenze | Impostazioni section: Lingua + Tema. |
| Notifiche | Notifiche | Impostazioni section: Promemoria + Preavviso. |
| Registro | Registro | Impostazioni section: daily-screen sections (Dolore, Note giornaliere). |
| Dati | Dati | Impostazioni section: Backup + CSV import/export. |
| Informazioni | Informazioni | Impostazioni section: Guida, Codice sorgente, Privacy policy. |
| Azioni irreversibili | Azioni irreversibili | Impostazioni section header for destructive controls. **Never** "Zona pericolosa" — alarmist register conflicts with the *quaderno silenzioso* voice. |
| Promemoria ciclo | Promemoria ciclo | Toggle row label. |
| Preavviso | Preavviso | Notification-advance row label. **Never** "Anticipo" alone — under-specified without value. |
| Dolore | Dolore | Toggle row label. **Never** "Traccia dolore" — toggles take nouns, actions take verbs. |
| Note giornaliere | Note giornaliere | Toggle row label. |
| Backup | Backup | Loanword. Value-row label. |
| Esporta CSV / Importa CSV | Esporta CSV / Importa CSV | Action-row labels (imperative). |
| Elimina tutti i dati | Elimina tutti i dati | Destructive-row label. **Never** "Cancella tutti i dati" — the app verb for delete is `Elimina` (consistent with `common_delete`). |
| Guida | Guida | External-link row label. **Never** "Centro assistenza" — implies SaaS help-desk, but the link is a static page. |
| Codice sorgente | Codice sorgente | External-link row label (GitHub). |
| Privacy policy | Privacy policy | External-link row label (loanword). |
| Sostieni il progetto | Sostieni il progetto | Footer support-CTA copy (paired with "Ko-fi" identifier on the affordance itself). |
| Non configurato | Non configurato | Backup-row default value. Flat-descriptive — never imperative ("Aggiungi") or alarming ("Nessuna connessione"). |
| Configurato | Configurato | Backup-row connected value. Flat-descriptive mirror of "Non configurato" — same register, opposite polarity. **Never** "Connesso" (alarmist/intimate-register clash with the *quaderno silenzioso* voice), **never** "Attivo" (battery-icon connotation), **never** the email address (privacy + length). The full account email and last-backup timestamp live on the Backup screen — the Settings row is only a navigation handle. |
| Italiano / Inglese | — | Lingua-row values. |
| Sistema / Chiaro / Scuro | — | Tema-row values. |
| 1 giorno prima / {n} giorni prima | — | Preavviso-row value. The trailing "prima" makes the temporal relation explicit. |

---

## 15. Anti-patterns — forbidden until HTML changes

The following are **explicitly forbidden** because the HTML does not contain them. They are listed here because past iterations have accidentally introduced each one:

1. **No FAB** anywhere. The calendar's only mutation entry is "Modifica giornata" inside the day card. Today saves through its bottom CTA.
2. **No checkmarks on choice chips.** Selection is colour-only.
3. **No drop shadows on cards / sheets.** Only the active segmented-control segment carries a shadow.
4. **No circles for day cells.** Days are 48×48 rounded-square (`radius 12`).
5. **No purple / blue / pink / green outside the seven defined accent tokens.** Especially: do not introduce new symptom tints. Symptoms are always `ocra`.
6. **No emoji** in copy or chips. Symptom labels are pure text.
7. **No badge counts** on tab-bar icons.
8. **No "Métra" with acute** in product hero contexts. Always `Mētra` (macron).
9. **No swipe-to-archive / long-press menus** on archive cards. Cards are display-only in this bible.
10. **No `999px` pill radius.** Use `½ × height` (chips: `18` for `36`-tall).
11. **No animation specs.** Sanctioned motion is enumerated and exhaustive: (a) `transition: all 0.15s` on chip and flow-type-chip backgrounds (§6.1, §7.1); (b) `transition: background 0.15s` and `transition: left 0.15s` on the MetraToggle (§6.7) — track tint and dot position. Everything else is static. Do not invent motion that is not in this list.
12. **No light-mode-only filters / blurs** beyond the tab-bar `blur(16)`. No glassmorphism on cards.
13. **No bottom sheet** patterns in this bible's scope. (May appear in `Métra Quick Entry.html`, which is out of scope.)
14. **No center-stage today indicator on the calendar grid.**
15. **No Oggi tab / FAB / pill.** Daily-log entry is only via the calendar day detail card button. Do not resurface the Oggi tab, a bottom-bar shortcut, or a FAB for log entry. A subtle 1.5 px ring on today's cell is allowed for usability. The one approved "jump to today" affordance is the `"Oggi"` Inter 13 weight 500 text button placed **between the two calendar chevrons** (§ 8.1) — no border, no pill shape, no separate row. No other "today" surface is permitted.

---

## 16. Adherence checklist (run before every UI PR)

A change is bible-compliant only if every box below can be ticked:

- [ ] All colors used resolve to one of the nine `C.*` tokens or one of the catalogued alpha stops in § 1.1.1 / § 1.1.2. **No new hex values.**
- [ ] All font usages map to a row in § 1.2 (size + weight + family). **No new font sizes.**
- [ ] All radii match § 1.4. No `999`. No `BorderRadius.zero` for a chip.
- [ ] All borders match § 1.5. No new alpha stops.
- [ ] Italian copy matches § 13–14 verbatim (including casing, accented characters, ellipses).
- [ ] The wordmark, where rendered, is `Mētra` (U+0113), not `Métra` (U+00E9).
- [ ] No anti-pattern from § 15 is present.
- [ ] If the change implements something not in the HTML — **stop**. Update the HTML mockup first; PR the mockup; only then PR the Flutter implementation. Bible-driven, not aspiration-driven.

---

## 17. Cross-references

| Concern | File |
|---|---|
| Source HTML (canon) | `wiki/design/Métra Screens Light.html` |
| Active alignment fixes (Sprint 2) | `design/implementation-spec-2026-05-01.md` |
| Older-task ledger (DM/UX/CL/ON/AR/ST codes) | `design/design-review-tasks.md` |
| Theme tokens (Flutter) | `lib/theme/app_colors.dart`, `lib/theme/app_typography.dart` |
| Wordmark widget | `lib/core/widgets/metra_wordmark.dart` |
| Calendar day cell | `lib/features/calendar/widgets/calendar_day.dart` |
| Flow type chips | `lib/features/daily_entry/widgets/flow_type_chips.dart` |
| Flow intensity dots | `lib/features/daily_entry/widgets/flow_intensity_dots.dart` |
| Pain picker | `lib/features/daily_entry/widgets/circle_pain_picker.dart` |
| Choice chip | `lib/core/widgets/choice_chip_metra.dart` |
| Onboarding screens | `lib/features/onboarding/onboarding_screen.dart` |
| MetraToggle | (not yet implemented in Flutter) |
| Impostazioni screen | `lib/features/settings/settings_screen.dart` |

The bible is the orthodox layer above all of these. A token in `app_colors.dart` that contradicts § 1.1 is wrong by definition — patch the Flutter, not the bible.

---

## 18. Impostazioni screen

> Numbering note: this section was appended in 2026-05-03 to keep prior § anchors stable. Conceptually it belongs alongside the other main-app screen sections (§ 8–§ 11); a future bible reorganisation may renumber it.

### 18.1 Container

```
overflow-y auto · padding-bottom 100
bg sabbia
```

The tab bar overlays the bottom 84 px (active tab `settings`); 100 px bottom padding gives breathing room. The screen always exceeds the viewport — design for scroll.

### 18.2 Header

Same pattern as Today (§ 9.2) and Statistiche (§ 11.1), no subtitle:

```
padding 12 / 24 / 16
DM Serif Display 26 inchiostro line-height 1.1   "Impostazioni"
```

### 18.3 Section label

Reuses the § 9.3 micro-label recipe verbatim, with screen-specific outer spacing:

```
Inter 12 weight 600 letter-spacing 0.06em UPPERCASE color rgba(43,37,33,0.40)
padding 24 / 24 / 12       (top 24 between sections; first section padding-top 8)
```

### 18.4 GroupCard

Container that stacks list rows. Distinct from the Today section frame (§ 9.3) — that uses borderTop/Bottom on a flush surface; this one is a free-standing card with all four corners rounded.

```
margin 0 / 24                                   (matches screen-edge horizontal padding)
bg surface · radius 16 · border 1px rgba(43,37,33,0.07)
overflow hidden                                 (so the first/last row inherit the rounded edge)
```

Radius 16 (§ 1.4) is shared with stat cards and the privacy info card — cards-of-cards layer. Radius 12 belongs to atom-level surfaces (chips, day cells, the day-detail CTA).

### 18.5 Row geometry

All variants share:

```
height 56 · paddingInline 20 · alignItems center · justifyContent space-between
label: Inter 15 weight 500 inchiostro
between rows in the same card: 1px solid rgba(43,37,33,0.07) divider (full-width inside the card)
cursor pointer
```

#### 18.5.1 Variants

| Variant | Trailing | Background | Label color |
|---|---|---|---|
| **value** | `<value-text>` Inter 14 rgba(0.68) + `chevron_right 16 rgba(0.40)` | transparent | inchiostro |
| **toggle** | `MetraToggle` (§ 6.7) | transparent | inchiostro |
| **action** | nothing | transparent | inchiostro |
| **destructive** | nothing | `${terracotta}0D` | `tc_scura` |
| **link** | `chevron_right 16 rgba(0.40)` (no value text) | transparent | inchiostro |

The destructive variant communicates "proceed with care" through warm-tint background and dark-accent label only — never red, never an alarm icon, never a stripe. The catalog has no destructive icon (§ 2.1) and none should be added.

`action` rows (Esporta / Importa) are left-aligned by virtue of `space-between` collapsing onto a single child. No leading icon; the verb carries the meaning.

`link` rows use `chevron_right` even for external destinations — see § 2.1 catalog gap note.

### 18.6 Section structure

Top-to-bottom order on screen, with verbatim Italian section labels (uppercase rendering applied by the section-label atom):

| # | Section | Rows |
|---|---|---|
| 1 | **Preferenze** | Lingua (value) · Tema (value) |
| 2 | **Notifiche** | Promemoria ciclo (toggle) · Preavviso (value) |
| 3 | **Registro** | Dolore (toggle) · Note giornaliere (toggle) |
| 4 | **Dati** | Backup (value) · Esporta CSV (action) · Importa CSV (action) |
| 5 | **Informazioni** | Guida (link) · Codice sorgente (link) · Privacy policy (link) |
| 6 | **Azioni irreversibili** | Elimina tutti i dati (destructive) |

The **Backup** value row is the only state-aware row on the screen: its trailing value-text reflects `backupNotifierProvider`. `BackupConnected` → `Configurato`. All other states (loading/`AsyncLoading`, `BackupNotConnected`, `BackupRunning`, `BackupErrorState`) → `Non configurato`. The row is purely a navigation handle to the Backup screen, where the email, last-backup timestamp, and operation controls live; the Settings row never surfaces those details.

Above-the-fold (visible viewport ≈ 622 px): header + Preferenze + Notifiche + Registro card visible; Dati label entering at the bottom of the canvas snapshot.

Section ordering rationale (recorded so future iterations don't drift):
- **Preferenze first** — matches Settings convention; orientation aid for first-open.
- **Notifiche second** — highest steady-state revisit (cycle-length changes, schedule shifts).
- **Registro third** — preferences-cluster, lower frequency.
- **Dati fourth** — Backup + CSV merged into one group; ghost CSV buttons promoted to standard rows.
- **Informazioni fifth** — read-only buffer between active sections and the destructive group.
- **Azioni irreversibili last** — maximum scroll distance from entry point.

### 18.7 Footer

Below the last GroupCard. Centered column, no card chrome.

```
paddingTop 32 · paddingBottom 0 · paddingInline 24
display flex · flexDirection column · alignItems center · gap 6
```

Content (top to bottom):

1. Wordmark `Mētra` (U+0113 — § 0.3) · DM Serif Display 20 inchiostro.
2. Version `0.1.0` · Inter 12 rgba(0.40).
3. Support pill (marginTop 14): height 36, paddingInline 18, radius 18, bg `${terracotta}14`, border `1px solid ${terracotta}28`. Label Inter 13 weight 500 `tc_scura`: `Ko-fi · Sostieni il progetto`. The "Ko-fi" prefix preserves the destination signal that the live Flutter conveys via the Ko-Fi PNG badge — which is replaced in the mockup by this bible-coherent pill.

The tab bar's 84 px frosted overlay sits below this footer; the screen's container `paddingBottom 100` (§ 18.1) absorbs the clearance.

### 18.8 What the screen does NOT contain

- No bottom sheets, modals, or confirm dialogs (the mockup never renders these for any screen). Pickers and confirmations are implementation-side concerns.
- No FAB (§ 15.1). No badges (§ 15.7). No drop shadows (§ 15.3). No checkmarks on toggles (§ 15.2 spirit — selection by colour and position).
- No Material `SwitchListTile`, no Material `Icons.chevron_right` / `Icons.open_in_new` in product code. The Flutter implementation must use the catalog (§ 2.1) and the MetraToggle (§ 6.7).
