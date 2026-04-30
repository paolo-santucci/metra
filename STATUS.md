# Métra — UI Alignment Sprint Status

**Last updated**: 2026-04-30  
**Active plan**: Flutter UI Alignment to Design HTML Mockups (9-phase)  
**Plan location**: `.claude/docs/plans/2026-04-30-ui-alignment-design-mockups.md`

---

## Phase completion

| Phase | Task | Status | Commit |
|---|---|---|---|
| P-A | Foundation reconciliation (theme tokens, wordmark) | ✅ done | `214d2ad` |
| P-B | Flow domain migration (FlowType enum, schema v4) | ✅ done | `0f5b8b1` |
| P-C | Daily entry widget overhaul (FlowTypeChips + FlowIntensityDots) | ✅ done | `c4f86de` |
| P-D | Pain picker null state | 🔲 next | — |
| P-E | Calendar visual + navigation | 🔲 pending | — |
| P-F | Archive timeline + Stats label fix | 🔲 pending | — |
| P-G | Onboarding fixes | 🔲 pending | — |
| P-H | Symptom defaults + l10n | 🔲 pending | — |
| P-I | Final visual QA pass | 🔲 pending | — |

---

## P-D — Pain picker null state (next task)

**Goal**: Pain field distinguishes `null` (not logged) from `0` (Nessuno, explicit). Align color from lavanda → malva.

### What's already true in the domain
- `DailyLogEntity` has `painEnabled: bool` and `painIntensity: int?` (0–3).
- Null-state semantics: `painEnabled=false, painIntensity=null` = not logged; `painEnabled=true, painIntensity=0` = Nessuno (explicit).

### `CirclePainPicker` changes needed (`lib/features/daily_entry/widgets/circle_pain_picker.dart`)
- Delete the `PainLevel` enum.
- Change signature to `int? selected` + `ValueChanged<int?> onChanged`.
- 4 circles: 0=Nessuno, 1=Lieve, 2=Moderato, 3=Intenso. Null = nothing selected (no ring).
- Tap-to-deselect: tapping already-selected circle calls `onChanged(null)`.
- Color: change `accentPrediction` → `accentPain` (malva token already exists in `MetraColors`).
- Dot size: reduce from 56dp to 36dp diameter (R=18, matching `FlowIntensityDots`).
- Fill opacities: Nessuno = white/outlined only, Lieve ≈ 0.25, Moderato ≈ 0.55, Intenso ≈ 0.90.

### `today_screen.dart` changes needed (`lib/features/daily_entry/today_screen.dart`)
- Remove `PainLevel _painLevel = PainLevel.none`.
- Add `int? _painIntensity;` (null = not logged).
- Remove `_toPainLevel()` / `_painLevelToIntensity()` helper methods.
- In `_initFromLog(log)`: `_painIntensity = log.painEnabled ? log.painIntensity : null`.
- In `_buildEntity()`: `painEnabled: _painIntensity != null, painIntensity: _painIntensity`.
- Wire `CirclePainPicker(selected: _painIntensity, onChanged: (v) => setState(() => _painIntensity = v))`.

### `historical_entry_screen.dart` — no widget change needed
- Already uses `PainIntensitySlider` (0–3 slider) with `_painEnabled` toggle.
- The `_painEnabled=false` path correctly saves `painEnabled: false, painIntensity: null`.
- No regression expected; verify `_initFromLog` reads `log.painEnabled` correctly (line 112–113).

### Tests to add/update
- `test/features/daily_entry/widgets/circle_pain_picker_test.dart` (new):
  - null state: no circle has selection ring.
  - Tap circle 2: `onChanged(2)` called.
  - Tap already-selected circle 2 again: `onChanged(null)` called.
  - Circle 0 (Nessuno) tap: `onChanged(0)`.
- Update `today_screen` widget test if it existed (check: `test/features/daily_entry/`).

---

## P-E — Calendar visual + navigation (after P-D)

- Replace dashed prediction outline with solid 1.5px lavanda border + lavanda `drop_outline` icon.
- Add calendar legend row (4 chips).
- Fix "Modifica giornata" to pass selected date.
- Files: `lib/features/calendar/widgets/calendar_day.dart`, `lib/features/calendar/calendar_screen.dart`.

## P-F — Archive timeline + Stats label fix

- AR-01: verify timeline card icons (drop/zap/star_small) at `lib/features/timeline/widgets/timeline_card.dart`.
- ST-01: pain axis label → "Intensità dolore (0–3)"; trend labels gated behind ≥3 complete cycles.

## P-G — Onboarding fixes

- Menstruation duration range: 1..8 days (was 3..7).
- Label: "Primo giorno dell'ultima mestruazione" (was "Quando è iniziato l'ultimo ciclo?").
- Verify Mētra Unicode `ē` on first screen.

## P-H — Symptom defaults + l10n

- Default symptom list order: Crampi, Mal di testa, Stanchezza, Mal di schiena, Nausea, Gonfiore, Tensione mammaria.
- Rename `Schiena` → `Mal di schiena`. Add `Gonfiore`, `Tensione mammaria`.

---

## Key architecture decisions made this sprint

- **FlowType enum**: `assente=0, mestruazioni=1, spotting=2` (persisted as `flow_type INT` in DB schema v4).
- **DM-02 invariant**: `flowIntensity` must be null unless `flowType == FlowType.mestruazioni` — enforced in `SaveDailyLog`.
- **BackupSnapshot v2**: added `flow_type` field; reads v1 snapshots via old-spotting-bool derivation.
- **UX-02 intensity preservation**: `_lastMensIntensity` local state in today/historical screens — persists last-known intensity when switching away from mestruazioni; restores on switch-back.

## Key files reference

| File | Role |
|---|---|
| `lib/domain/entities/flow_type.dart` | FlowType enum (new in P-B) |
| `lib/domain/entities/daily_log_entity.dart` | Main log entity (flowType, flowIntensity, painEnabled, painIntensity) |
| `lib/features/daily_entry/widgets/flow_type_chips.dart` | New P-C widget |
| `lib/features/daily_entry/widgets/flow_intensity_dots.dart` | New P-C widget |
| `lib/features/daily_entry/widgets/circle_pain_picker.dart` | P-D target — needs null state + color fix |
| `lib/features/daily_entry/today_screen.dart` | P-D target — remove PainLevel, use int? |
| `lib/features/calendar/widgets/calendar_day.dart` | P-E target — prediction visual |
| `lib/core/theme/metra_colors.dart` | Token source — `accentPain` = malva |
| `lib/l10n/app_it.arb` | All Italian copy |
| `design/design-review-tasks.md` | Authoritative task list with DM/UX/CL codes |
