# Design Review — Implementation Tasks for App Codebase

Tasks derived from design review session 2026-04-30.
Apply during the relevant implementation phase (P-1 through P-4).

---

## Data Model

### DM-01 · PainDots null state (P-1)
The pain field must distinguish `null` (not logged) from `0` (Nessuno, explicitly confirmed).
- DB column: `pain_level INTEGER NULL` — `NULL` = not logged, `0` = confirmed no pain
- Currently the mock defaults to 0; real model must default to NULL
- Related: tap-to-deselect in UI returns to null (see UX-01)

### DM-02 · Flow intensity not persisted unless type = mestruazioni (P-1)
When `flow_type` is saved as `assente` or `spotting`, `flow_intensity` must be stored as NULL.
The UI preserves intensity in memory for the session (to restore if user switches back to mestruazioni),
but the persisted row must never store an intensity value without a matching `mestruazioni` type.

### DM-03 · Spotting classification (P-1)
`flow_type` column: enum `{ null, assente, mestruazioni, spotting }`.
`spotting` maps to FIGO PALM-COEIN IMB — do NOT store it as a flow intensity level.
Archive queries that compute "cycle flow" should exclude spotting days from HMB/intensity averages.

---

## UI Components

### UX-01 · Tap-to-deselect everywhere (P-1)
All selection widgets (FlowTypeChips, FlowIntensityDots, PainDots, symptom chips) must support
tap-to-deselect (tap selected item → returns to null). Implement as a consistent pattern:
`onTap: value == thisId ? onChange(null) : onChange(thisId)`
Validate discoverability in user testing — no additional affordance planned unless testing shows confusion.

### UX-02 · Flow type switching — preserve pending intensity (P-1)
When user switches from Mestruazioni to another type and back, restore the last-entered intensity.
Use a local ephemeral variable (not persisted) — e.g., a `ValueNotifier` or Riverpod local state.
Only persist intensity when the final save action fires with type = mestruazioni.

### UX-03 · Symptom chip touch target (P-1)
Visual chip height can stay ≤36dp. Implement touch target via GestureDetector / InkWell with
minimum tap area extended to 44dp using `ConstrainedBox(constraints: BoxConstraints(minHeight: 44))`.
Do not increase visual/layout height.

### UX-04 · Calendar day-detail card — data-driven (P-2)
Day-detail card must display data for the tapped date, not hardcoded data.
Provide a fallback "Nessun dato registrato" state for days with no entry.

### UX-05 · "Modifica giornata" navigation (P-2)
Tapping "Modifica giornata" on a past calendar day must:
1. Open the daily entry screen pre-populated with that day's data
2. Pass the target date explicitly (not default to today)
3. Show a back/close button that returns to the calendar at the same date

---

## Scope & Clinical Correctness

### CL-01 · Remove ovulation/fertile-window visual language from Calendar (P-2)
The "Previsione" feature (predicted period start) must use neutral visual language.
Do NOT use lunar icons, day-14 highlights, or any imagery associated with ovulation/fertile windows.
Approved visual: **hollow lavanda drop** — same drop path as the Mestruazioni indicator, stroke-only
(no fill), color = Lavanda token. Communicates "same event type, not yet happened."
- Calendar day cells: lavanda border + drop_outline indicator icon in the icon row
- Calendar legend: drop_outline icon in Lavanda next to "Previsione" label
Reference: FIGO PALM-COEIN scope — app is cycle awareness only, no fertility tracking.

### CL-02 · Pain scale (P-1)
Pain scale: 4 levels — null (not logged), 0 Nessuno, 1 Lieve, 2 Moderato, 3 Intenso.
All statistics, charts, and axis labels must reflect 0–3 range (not 1–5 or any other).

### CL-03 · Symptom defaults (P-1)
Default symptom list (localizable):
`['Crampi', 'Mal di testa', 'Stanchezza', 'Mal di schiena', 'Nausea', 'Gonfiore', 'Tensione mammaria']`
Note: "Mal di schiena" not "Schiena". "Gonfiore" and "Tensione mammaria" added per DRSP/PSST.

### CL-04 · Spotting contextual note — string asset (P-1)
The note shown when Spotting is selected:
> "Piccola perdita fuori dal flusso mestruale. Non è necessariamente l'inizio del ciclo."
Store as a localizable string. Clinically vetted — do not rewrite without domain expert sign-off.

---

## Onboarding

### ON-01 · Step count: 2 steps only (P-4)
Onboarding must show exactly 2 screens. Progress indicator: "Passo 1 di 2" / "Passo 2 di 2".

### ON-02 · Menstruation duration range (P-4)
Duration picker: 1–8 days (FIGO-valid range). Previous range 3–7 truncates valid edge cases
(1–2 days: hormonal IUD, perimenopause; 8 days: upper FIGO limit).

### ON-03 · Cycle start question wording (P-4)
Use "Primo giorno dell'ultima mestruazione" — not "Quando è iniziato l'ultimo ciclo?"
Reason: "ciclo" in Italian colloquial usage refers to the flow itself, not the full cycle (day 1).

### ON-04 · No forced cycle length for irregular users (deferred — post-MVP consideration)
Consider adding "Non lo so / ciclo irregolare" option in cycle length onboarding.
Affects: PCOS, post-pill amenorrhoea, perimenopause, recent menarche.
Current decision: skip in MVP (scope noted for v1.1).

---

## Wordmark

### WM-01 · ē Unicode (all text rendering) (P-4)
The wordmark "Mētra" uses ē (U+0113, Latin Small Letter E with Macron).
In Flutter: use the exact Unicode string `"Mētra"` or the literal character.
Ensure the chosen display font (DM Serif Display) includes this glyph; if not, use a fallback
with a combining macron or custom SVG wordmark asset.

---

## Statistics

### ST-01 · "Trend" label minimum cycle gate (P-3)
Do not show directional trend labels ("Trend in calo", "Trend in aumento") unless the user has
at minimum 3 complete cycles logged. Show "Dati insufficienti" or no trend label otherwise.

---

## Archive / History

### AR-01 · Timeline chips — semantic icons (P-3)
Each chip in the Archivio timeline cards must show its semantic icon before the label text.
Icon map (same tokens as calendar legend and day-cell indicators):
- Flow chip → `drop` filled, color Terracotta Dark (`tc_scura`)
- Pain chip → `zap` filled, color Malva
- Symptom chip → `star_small` filled, color Ocra

Icon size: 11dp. Gap between icon and label: 4dp.
This creates a unified icon vocabulary across calendar cells, calendar legend, and archive timeline.

---

## Minor / Copy

### CP-01 · Day-of-week correctness (P-2)
When displaying dates in the app, always compute day-of-week from the actual date — never hardcode.
(April 23 2025 is a Wednesday, not Tuesday — caught as a mockup error.)

### CP-02 · Save CTA canonical label (P-1)
The save action on the daily entry screen: "Salva giornata". Use this string everywhere.
Do not use "Salva — Tutto ok →" or other variants.
