<!-- SPDX-License-Identifier: GPL-3.0-only — Métra components spec -->

# Métra — Specifica Componenti (Wave 1)

> Questo documento è il complemento di `mockup/styles/components.css` e `mockup/styles/tokens.css`. Ogni componente qui descritto:
> - Si trova nel mockup HTML in Wave 1 e Wave 2.
> - Mappa a un widget Flutter target (path indicato).
> - Ha stati documentati (default, hover, active, disabled, focus visible).
> - Ha vincoli di accessibilità verificati (CLAUDE.md §10).
> - Ha indicazioni dark mode (CLAUDE.md §8.1: dark mode designed, NOT inverted).

**Lingua dell'output:** italiano (decisione utente, CLAUDE.md §17 e piano §"Note operative").

**Convenzione classi:** BEM puro `block__element--modifier`. Niente classi utility-first.

**Convenzione token:** i componenti referenziano SEMPRE alias semantici (`--bg-*`, `--text-*`, `--accent-*`, `--border-*`). Mai colori grezzi (`--color-terracotta`) direttamente. Questo permette di ridefinire la mappatura tra light e dark senza toccare i componenti.

**Convenzione tap target (CLAUDE.md §10):** ogni elemento interattivo ha hit area minima `44×44pt` (iOS) o `48×48dp` (Android). Quando il visivo è più piccolo, l'area è estesa via `::before` invisibile.

---

## 1. `.btn` — Pulsante

**Modifier:** `--primary` · `--secondary` · `--ghost` · `--danger` · `--block`

**Mapping Flutter target:**
- `→ ButtonPrimary` (`lib/core/widgets/button_primary.dart`)
- `→ ButtonSecondary` (`lib/core/widgets/button_secondary.dart`)
- `→ ButtonGhost` (`lib/core/widgets/button_ghost.dart`)

### Stati

| Stato | Comportamento |
|---|---|
| Default | Riempimento (primary) o outline (secondary/danger) o solo testo (ghost). |
| Hover | Primary scurisce verso `--color-ink`. Secondary mostra `--bg-sunken`. Ghost ottiene `--bg-sunken`. |
| Active | `transform: scale(0.98)` (150ms) — feedback tattile sobrio. |
| Focus visible | `outline: 2px solid var(--focus-ring-color)` + `offset: 2px`. **Mai color-only.** |
| Disabled | `opacity: 0.5` + `cursor: not-allowed` + `pointer-events: none`. La trasparenza fa da cue secondario; il vero gating è `aria-disabled` per a11y. |
| Loading | (Da gestire in JS Wave 2) sostituire label con spinner SVG, mantenere larghezza per evitare layout shift. |

### Token usati

`--accent-flow-strong` (primary bg), `--text-on-accent` (primary fg), `--bg-sunken` (hover), `--border-strong` (secondary border), `--text-on-sand` (ghost fg), `--color-state-error` (danger), `--focus-ring-color`, `--radius-md`, `--font-weight-medium`, `--layout-tap-target`, `--duration-fast`, `--easing-standard`.

### Vincoli A11y

- **Semantics label richiesto** in Flutter: `Semantics(button: true, label: '...')`. Etichette mai generiche tipo "OK"; preferire forma verbo+oggetto ("Salva la giornata", "Annulla l'inserimento"). Decisione confermata dal `reproductive-health-advisor` in Wave 2.
- **Tap target verificato:** `min-height: 44pt` su `.btn`.
- **Stato disabled accessibile:** `aria-disabled="true"` sull'elemento, **non** rimuovere il pulsante dal flusso di tab.
- **Mai usare colore come unico cue** per "primary vs secondary": il primary ha riempimento solido, il secondary outline. Distinguibili in monocromatico.
- **Decisione di contrast:** primary usa `--accent-flow-strong` (`#9B4E32`), non `--color-terracotta` (`#C87456`). Quest'ultimo ha 3:1 con sand, sufficiente per UI grandi ma non per il testo del pulsante. Annotato in `tokens.css`.

### Dark mode

Gli alias semantici cambiano automaticamente. Il primary in dark usa `--color-muted-terracotta-soft` (`#D88B6E`) come `--accent-flow-strong`, contrasto 6:1 su `--bg-primary` (`#1A1410`) — AA confermato. Hover scurisce verso `--text-primary` (ivory) — invertito rispetto a light per coerenza percettiva.

---

## 2. `.chip` — Chip selezionabile

**Modifier:** `--selected` · `--prediction`

**Mapping Flutter target:**
- `→ ChoiceChipMetra` (`lib/core/widgets/choice_chip_metra.dart`)

### Stati

| Stato | Comportamento |
|---|---|
| Default | Outline sottile su `--bg-surface`. Pill radius. |
| Hover | `--bg-sunken` di sfondo. |
| Selected | Riempimento `--accent-warmth` (ochre) + bordo strong. **Aggiungere icona check inline** (`<svg>` 12×12 prima dell'etichetta) per avere un cue di forma indipendente dal colore. |
| Active | (gestito dal browser come hover su mobile) |
| Focus visible | Outline 2pt lavender + offset 2pt. |
| Disabled | `opacity: 0.5` + `pointer-events: none`. |

### Token usati

`--bg-surface`, `--bg-sunken`, `--border-subtle`, `--accent-warmth`, `--accent-warmth-strong`, `--accent-prediction`, `--text-primary`, `--font-size-caption`, `--radius-pill`, `--focus-ring-color`.

### Vincoli A11y

- **Hit area estesa via `::before`** a `44×44pt` (visivo è 36pt). Vedi `.chip::before { inset: -4px -4px; }`.
- **Semantics in Flutter:** `Semantics(toggled: isSelected, label: '...')`. Lo screen reader deve annunciare lo stato (es. "Crampi, selezionato").
- **Cue di forma + colore:** la sola differenza di tonalità non è sufficiente per color-blind. Aggiungere check icon inline in selected. **Già documentato in components.css**, l'icona è inserita dal frontend-developer in Wave 2 come `<svg class="chip__check">`.

### Dark mode

`--accent-warmth` in dark = `--color-warm-ochre-dark` (`#C09060`). Su `--bg-primary` (`#1A1410`) ha contrast 5.6:1 — AA su small text. Selected usa testo `--text-on-accent` (deep-night) per coerenza.

---

## 3. `.list-row` — Riga di lista

**Sub-elementi:** `__leading` · `__content` · `__title` · `__caption` · `__trailing`

**Modifier:** `--header` (riga di intestazione, non interattiva)

**Mapping Flutter target:**
- `→ ListRowMetra` (`lib/core/widgets/list_row_metra.dart`)

### Stati

| Stato | Comportamento |
|---|---|
| Default | Background `--bg-surface`, divisore inferiore `--border-subtle`. |
| Hover | `--bg-sunken`. |
| Active | Stesso del hover su touch (no animazione transform — sarebbe rumore in una lista lunga). |
| Focus visible | Outline inset 2pt lavender (offset negativo per non rompere l'allineamento dei divisori). |
| Disabled | `opacity: 0.5` (raro su questo componente). |

### Token usati

`--bg-surface`, `--bg-sunken`, `--border-subtle`, `--text-primary`, `--text-secondary`, `--font-size-body`, `--font-size-caption`, `--layout-tap-target-md`.

### Vincoli A11y

- **Tap target ≥48dp** (Android-first per liste).
- **Semantics:** se la riga apre un dettaglio, è `button: true`; se è solo informativa, `button: false`. Non confondere i due.
- **Truncation:** `__title` e `__caption` possono troncare con `text-overflow: ellipsis` quando IT è del 20-30% più lungo di EN (CLAUDE.md §10). Il container ha `min-width: 0` per permetterlo.
- **Modifier `--header`** rimuove `pointer-events`. Lo screen reader la legge come testo. Su Flutter mappa a un `Padding`, non a un `InkWell`.

### Dark mode

Cambia solo il bg/border; gerarchia tipografica preservata.

---

## 4. `.segmented-control` — Toggle 2-3 opzioni

**Sub-elementi:** `__option` (con modifier `--active`)

**Mapping Flutter target:**
- `→ SegmentedControlMetra` (`lib/core/widgets/segmented_control_metra.dart`)

### Stati

| Stato | Comportamento |
|---|---|
| Default option | Sfondo trasparente sul track `--bg-sunken`, testo `--text-secondary`. |
| Active option | Sfondo `--bg-surface`, testo `--text-primary`, ombra `--shadow-card`. Transizione 240ms. |
| Hover (non-active) | Lieve schiarimento — limitato perché lo stato è già denso visivamente. |
| Focus visible | Outline 2pt sull'option focalizzata. |
| Disabled (option) | `opacity: 0.5`. |

### Token usati

`--bg-sunken` (track), `--bg-surface` (active option), `--shadow-card`, `--radius-pill`, `--font-weight-medium`, `--font-weight-semibold` (active), `--duration-base`.

### Vincoli A11y

- **Semantics:** `role="tablist"` su `.segmented-control`, `role="tab"` con `aria-selected` su ogni option.
- **Navigazione tastiera:** frecce ←/→ per spostarsi tra option, conformemente al pattern WAI-ARIA. Implementazione in `scripts/router.js` (Wave 2).
- **Tap target:** ogni option ha `min-height: 36px` visivo + `min-width: 44pt` per garantire l'hit area orizzontale.

### Dark mode

Stessa struttura, l'option attiva si stacca leggermente dal track grazie a `--bg-surface` (deep-night-raised) vs `--bg-sunken` (deep-night-sunken). Verifica che la differenza percepibile sia ≥3:1 per UI components — confermato in tokens contrast checks.

---

## 5. `.day-circle` — Cella calendario (componente identitario)

**Sub-elementi:** `__shape` · `__label` · `__dot`

**Modifier:** `--flow-solid` · `--flow-light` · `--prediction` · `--has-notes` · `--today` · `--selected` · `--disabled` · `--out-of-month`

**Mapping Flutter target:**
- `→ CalendarDayWidget` (`lib/features/calendar/widgets/calendar_day.dart`)

### Encoding semantico (CLAUDE.md §8.2) — color-blind safe

| Stato | Forma (cue NON-colore) | Colore |
|---|---|---|
| Mestruazione confermata | Cerchio **pieno** | terracotta |
| Spotting / luce | Cerchio **outline** (bordo 2pt) | terracotta |
| Predizione | Cerchio **outline tratteggiato** (`border-style: dashed`) | lavender |
| Ha note/sintomi | **Dot 4×4** sotto il cerchio (presenza/assenza) | ochre |
| Oggi | **Anello sottile esterno** (box-shadow doppio) | ink (light) / ivory (dark) |
| Selezionato | **Anello spesso esterno** | lavender |

**Validazione color-blind safety (CLAUDE.md §10):** ogni stato è distinguibile in monocromatico dalla sola forma:
- Pieno vs outline vs outline tratteggiato → 3 stati di cerchio chiaramente diversi.
- Dot presente/assente → cue indipendente.
- Anello esterno spesso/sottile/assente → terzo asse di distinzione.

Tre assi di forma indipendenti (cerchio interno, dot, anello esterno) permettono di rappresentare combinazioni complesse (es. "oggi, mestruazione, con note") senza sovraccaricare il colore.

### Stati interattivi

| Stato | Comportamento |
|---|---|
| Default | Solo numero su sfondo trasparente. |
| Hover | Schiarimento del fondo cerchio (cambia `background-color` del `__shape`). |
| Active (tap) | Senza animazione di scala (sarebbe rumore in griglia di 35 celle). Solo cambio colore. |
| Focus visible | Outline 2pt lavender attorno al `__shape`. |
| Disabled | `opacity: 0.4`, `pointer-events: none`. Per giorni futuri non interagibili. |

### Token usati

`--accent-flow`, `--accent-flow-strong`, `--accent-prediction`, `--accent-warmth-strong`, `--bg-primary` (per il "buco" tra anello e cerchio interno), `--text-primary`, `--font-display`, `--layout-tap-target`, `--radius-circle`.

### Vincoli A11y

- **Hit area 44×44pt** sull'elemento `.day-circle` esterno (il cerchio visivo è 36pt, ma il container è 44pt).
- **Semantics critica (CLAUDE.md §10):** la label dello screen reader **MAI** deve essere "cerchio rosso". Sempre forma testuale completa: `"Flusso medio, 15 aprile 2026"` o `"Previsione, 28 aprile 2026"` o `"15 aprile, nessuna registrazione"`. La label è composta in Dart in `CalendarDayWidget`.
- **Numeri tabular:** `font-variant-numeric: tabular-nums` per allineamento verticale colonna.
- **Reduce motion:** transizioni di entrata/uscita sostituite da cross-fade <80ms (gestito automaticamente via `--duration-base` override in `[data-reduced-motion="true"]`).

### Dark mode

- `--flow-solid` in dark: `--accent-flow` = `--color-muted-terracotta` (`#B86848`). Etichetta interna usa ivory invece di sand (override esplicito in components.css).
- `--prediction` in dark: lavender sale a `--color-light-lavender` (`#9B8FBF`) — più chiaro, mantiene 5.5:1 su deep-night.
- Tratteggio del bordo `dashed` resta identico — è una proprietà di forma, non di colore.

---

## 6. `.input-text` — Input testuale singola riga

**Modifier:** `--error`

**Mapping Flutter target:**
- `→ TextFieldMetra` (`lib/core/widgets/text_field_metra.dart`)

### Stati

| Stato | Comportamento |
|---|---|
| Default | Bordo `--border-subtle`, sfondo `--bg-surface`. |
| Hover | Bordo `--border-strong`. |
| Focus / Focus visible | Outline 2pt lavender + bordo lavender. Lo stesso outline serve sia per focus tastiera sia per click — il pattern web è di accettarlo, in Flutter useremo solo il "focus visible". |
| Filled (con valore) | Stessa estetica, ma il placeholder scompare. |
| Error | Bordo `--color-state-error`, eventualmente messaggio di errore in caption sotto. |
| Disabled | `opacity: 0.5`, `cursor: not-allowed`, sfondo `--bg-sunken`. |

### Token usati

`--bg-surface`, `--bg-sunken`, `--border-subtle`, `--border-strong`, `--focus-ring-color`, `--color-state-error`, `--text-primary`, `--text-secondary`, `--radius-sm`, `--font-size-body`, `--layout-tap-target`.

### Vincoli A11y

- **Label sempre presente** (visibile o `aria-label` se l'input è inline). Mai input nudo.
- **Placeholder ≠ label** (CLAUDE.md §10 indirettamente, principio WCAG): il placeholder è solo un esempio, non descrive l'input.
- **Error message** associato via `aria-describedby` all'input. In Flutter: `decoration.errorText`.
- **Tap target** `min-height: 44pt`.
- **Mai disabilitare zoom** sui form mobile (preserva `font-size: 16px` per non scatenare zoom iOS automatico — già rispettato dal nostro `--font-size-body`).

### Dark mode

Sfondo `--bg-surface` = `#241D17`, bordo `#382E26`. Verifica contrast del testo a riposo: ivory su `#241D17` = 11.8:1 ✓ AAA.

---

## 7. `.input-textarea` — Input multilinea

**Mapping Flutter target:**
- `→ TextFieldMetra` con `maxLines: null` (`lib/core/widgets/text_field_metra.dart`)

Stati e vincoli identici a `.input-text`. Differenze:
- `min-height: 96px`, `resize: vertical`.
- Padding `--space-4` (più generoso, dato che il contenuto può essere lungo).
- Radius `--radius-md` invece di `--radius-sm` (il box è più grande, il radius proporzionalmente cresce).
- Usato esclusivamente per il campo "note" del giornaliero. **Anti-pattern (CLAUDE.md §9):** mai aggiungere "AI suggestions" in questo campo.

---

## 8. `.section-title` — Titolo di sezione

**Modifier:** `--display` · `--lg`

**Sub-elementi:** `__caption`

**Mapping Flutter target:**
- `→ SectionTitleMetra` (`lib/core/widgets/section_title_metra.dart`)

### Stati

Componente non interattivo. Stati visuali = solo le varianti di scala.

| Variante | Uso | Token |
|---|---|---|
| Default | Sezione interna | `--font-size-title-md` (22px), `--font-display` |
| `--lg` | Sezione principale | `--font-size-title-lg` (26px), `--font-display` |
| `--display` | Hero / wordmark | `--font-size-display-md` (32px), `--font-display` |
| `__caption` | Sottotitolo opzionale | `--font-size-caption`, `--font-body`, `--text-secondary` |

### Vincoli A11y

- **Semantics in Flutter:** `Semantics(header: true)`. Mappato a livelli di heading H1/H2/H3 in HTML del mockup, da definire dal frontend-developer per ogni schermata.
- **Mai più di 4 livelli di gerarchia** (CLAUDE.md §8.3).
- **Niente bold per gerarchia.** La gerarchia è data dal mix font (display vs body) + size. Coerente con CLAUDE.md §8.3.
- **Wordmark "Mētra":** quando il `--display` mostra il wordmark, il macron sopra la "e" è grafico (parte del logo SVG separato), **mai** carattere Unicode `ē` (CLAUDE.md §8.3).

### Dark mode

Solo cambio colore (`--text-primary`). Tipografia identica.

---

## 9. `.privacy-banner` — Banner inline privacy

**Sub-elementi:** `__icon` · `__content` · `__title` · `__body`

**Modifier:** `--inline` (variante senza bordo, più discreta)

**Mapping Flutter target:**
- `→ PrivacyBannerMetra` (`lib/core/widgets/privacy_banner_metra.dart`)

### Stati

Componente informativo, non interattivo nel default. Variante futura potrebbe avere CTA "Scopri di più" — in tal caso si compone con un `.btn--ghost`.

| Variante | Uso |
|---|---|
| Default | Onboarding step 2 ("I tuoi dati restano qui."). Bordo lavender per richiamare la prevedibilità, non l'allarme. |
| `--inline` | Settings → Backup, sotto la lista dei provider. Discreto. |

### Token usati

`--bg-sunken`, `--accent-prediction` (bordo + icona), `--text-primary`, `--text-secondary`, `--font-display` (titolo), `--radius-md`.

### Vincoli A11y

- **Semantics:** `Semantics(label: '$title. $body', container: true)` o equivalente role `note` in HTML.
- **Niente icone-emoji** (CLAUDE.md §9). L'icona è SVG line-icon stroke 1.5pt, stile "scudo" o "chiave" o "casa", coerente con CLAUDE.md §8.4 (riferimenti botanici, moon phases, spirali, stelle minute). Decisione finale icona da `ui-designer` in Wave 2 mockup.
- **Tono:** mai allarmistico. Mai "Attenzione!" o "Pericolo!". Esempio microcopy approvabile in P-M Wave 2: "I tuoi dati vivono solo qui, sul tuo dispositivo. Il backup viaggia cifrato — solo tu puoi rileggerlo."

### Dark mode

Sfondo `--bg-sunken` (`#15100C`), bordo `--color-light-lavender` — il bordo lavender chiaro su sfondo scuro è cue forte ma non aggressivo. Coerente con la regola "dark mode designed".

---

## Linee guida trasversali per dark mode

Oltre allo swap automatico degli alias semantici:

1. **Mai bianco puro** sul testo principale (sempre `--color-ivory` `#EDE4D3`, mai `#FFFFFF`).
2. **Mai nero puro** sullo sfondo (sempre `--color-deep-night` `#1A1410`, marrone-nero caldo).
3. **Tonalità decorative ammorbidite:** `terracotta` light → `muted-terracotta` dark (più desaturato), perché in dark gli accenti vivaci diventano abbaglianti.
4. **Ombre più diffuse:** `--shadow-card` in dark usa `rgba(0,0,0,0.4)` invece di `rgba(43,37,33,0.08)` — l'ombra in dark deve "scavare", in light deve "alzare".
5. **Bordi più sottili:** `--border-subtle` in dark è `#382E26` su `#1A1410` (3.2:1 — sufficiente per UI), non i `#DCD2C0` luminosi del light mode.
6. **Niente effetti glow / neon.** Glassmorphism e neumorphism sono già vietati (CLAUDE.md §8.5); aggiungiamo: in dark mode niente glow lavender attorno alle predizioni — il bordo tratteggiato è già sufficiente.

---

## Checklist di review per ogni componente (in Wave 2 e Phase P-1)

Prima di considerare "done" un componente nel mockup:

- [ ] Usato esclusivamente `--bg-*` / `--text-*` / `--accent-*` / `--border-*` (alias). Nessun riferimento diretto a `--color-*`.
- [ ] Hit area ≥44×44pt verificata con devtools.
- [ ] Focus visible con outline ≥2pt, non color-only.
- [ ] Stato disabled distinguibile senza colore (`opacity` + `cursor`).
- [ ] Contrast verificato con Stark / Polypane su tutte le coppie testo-bg.
- [ ] Test in dark mode tramite `data-theme="dark"` su `<html>`.
- [ ] Test in reduced motion tramite `data-reduced-motion="true"` su `<html>` o impostazione di sistema.
- [ ] Microcopy passato dal `reproductive-health-advisor` (no "Hey girl!", no "le donne", "tu" sempre).
- [ ] Mapping Flutter documentato in questa spec.
- [ ] BEM corretto (block__element--modifier), niente classi utility.

---

## Decisioni di design prese autonomamente in Wave 1

Durante questa wave, in assenza di specifica esplicita, sono state prese le seguenti decisioni — da validare con l'utente alla gate del mockup:

1. **Variante `terracotta-deep` (`#9B4E32`)** introdotta come token primario per testo accent e per pulsanti `.btn--primary`. Il `terracotta` "decorativo" `#C87456` resta per fill grandi (calendar day, banner) ma non passa AA per body text su sand (3:1). Questa variante è AA-compliant (5.6:1).
2. **Varianti `dusty-ochre-deep` e `moss-deep`** introdotte per le stesse ragioni (testo AA-safe quando l'accent decorativo non basta).
3. **`text-disabled` definito esplicitamente** (`#8C8378` light, `#6B6358` dark) — CLAUDE.md non specifica un valore, ma è necessario per il pattern disabled accessibile.
4. **Spacing scale estesa fino a `--space-16` (64px)** — CLAUDE.md menziona valori espliciti fino a 48px (`--space-12`); 64px serve per spacing hero in onboarding.
5. **Modifier `--prediction` su `.day-circle`** usa `border-style: dashed` (cue di forma), non solo cambio colore. Decisione coerente con CLAUDE.md §8.2 + §10 color-blind safety.
6. **Icona check inline su `.chip--selected`** (cue di forma indipendente dal colore). L'icona SVG sarà inserita dal frontend-developer in Wave 2 — il CSS lascia spazio per essa con `gap: var(--space-2)`.
7. **Stati funzionali (`error`/`success`/`warning`)** mappati su tonalità della palette esistente, non su rosso/giallo/verde clinici. Mantiene l'identità non-clinica del prodotto (CLAUDE.md §9).

## Possibili contraddizioni / ambiguità individuate in CLAUDE.md

1. **§8.1 vs §10:** la palette light dichiara `#C87456` come "Primary accent, current flow", ma §10 richiede 4.5:1 per testo small. La coppia non passa AA. Risolto introducendo `--color-terracotta-deep` (`#9B4E32`) e documentando esplicitamente in `tokens.css` quale variabile usare per testo vs fill. CLAUDE.md §8.1 lo segnala già con un warning, ma non fornisce il valore concreto della variante: l'ho proposto io.
2. **§8.3 dichiara una scala tipografica** che parte da "Display 32-48pt", ma poi nel CLAUDE.md base (sezione "Typography Scale" all'inizio del file generale) c'è una scala diversa "Display: 36/40, H1: 30/36...". Ho seguito la **§8.3** (specifica del progetto Métra, con DM Serif Display 32-48 + 22-26 + 16 + 13). Le due scale sono entrambe ragionevoli ma non identiche: per evitare conflitti ho aggiunto `body-lg` (18) come ponte.
3. **§8.5 menziona "max 1 perceivable elevation level"** ma il pattern segmented-control attivo richiede una `box-shadow`. L'ho mantenuta — è l'unico shadow fuori dalle card, e serve a comunicare "questa è la pill attiva". Da validare con l'utente alla gate del mockup.
