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
| P-D | Pain picker null state | ✅ done | `4fc46d8` |
| P-E | Calendar visual + navigation | 🔲 next | — |
| P-F | Archive timeline + Stats label fix | 🔲 pending | — |
| P-G | Onboarding fixes | 🔲 pending | — |
| P-H | Symptom defaults + l10n | 🔲 pending | — |
| P-I | Final visual QA pass | 🔲 pending | — |

---

## P-E — Calendar visual + navigation (next task)

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
| `lib/features/daily_entry/widgets/circle_pain_picker.dart` | P-D done — int? selected, malva, 36dp, tap-to-deselect |
| `lib/features/daily_entry/today_screen.dart` | P-D done — int? _painIntensity replaces PainLevel |
| `lib/features/calendar/widgets/calendar_day.dart` | P-E target — prediction visual |
| `lib/core/theme/metra_colors.dart` | Token source — `accentPain` = malva |
| `lib/l10n/app_it.arb` | All Italian copy |
| `design/design-review-tasks.md` | Authoritative task list with DM/UX/CL codes |
