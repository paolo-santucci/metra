# Métra — UI Alignment Sprint Status

**Last updated**: 2026-05-01  
**Active plan**: DESIGN-BIBLE Conformance Rebuild (2026-05-01)  
**Plan location**: `.claude/docs/plans/2026-05-01-bible-conformance-rebuild.md`

---

## DESIGN-BIBLE Conformance Rebuild (current)

| Phase | Description | Status | Commits |
|---|---|---|---|
| Phase 0 · Foundation | Token files, icon system, tab bar | ✅ done | `9656b58`…`7316fc2` |
| Phase 1 · Daily entry | Section frames, dot geometry, typography | ✅ done | `5ad0202` |
| Phase 2 · Calendar | Indicator icons, grid, legend | ✅ done | `774d9dd` |
| Phase 3 · Onboarding | MetraWordmark, manifesto, stepper, ARB | ✅ done | `f3d2114` |
| Phase 4 · Archivio rebuild | Domain extension + full timeline rebuild | ⏳ next | — |
| Phase 5 · Statistics rebuild | Stats screens | ⏳ queued | — |
| Phase 6 · Brand | Métra/Mētra resolution (needs user decision) | ⏳ queued | — |
| Phase 7 · Final | Golden walk + ship | ⏳ queued | — |

425 tests green, 0 analyzer warnings after Phases 0–3. 4 pre-existing encryption timeouts in full-suite run (pass in isolation).

> **🕮 Canonical UI source of truth: [`design/DESIGN-BIBLE.md`](design/DESIGN-BIBLE.md)** — transcribes `design/Métra Screens Light.html`. Read at every session boot. All UI changes must conform; deviation requires updating the HTML mockup first.

---

## Sprint 3 — Screenshot comparison blocks A+C+D+E+F+G (2026-05-01)

| Block | Task | Status | Commit |
|---|---|---|---|
| A | Patch DESIGN-BIBLE.md (2-screen onboarding), STATUS.md, memory | ✅ done | `b6047af` |
| C | Remove privacy screen entirely; onboarding is now 2-step | ✅ done | `b6047af` |
| D | Rebuild Primo Ciclo: headline, subhead, micro-labels, range track, "giorni", CTA | ✅ done | `b6047af` |
| E | Calendar header (DM Serif, left-aligned, cycle-day row), indicator dots | ✅ done | `b6047af` |
| F | NavBar: remove active-pill indicator, terracotta active icon/label | ✅ done | `b6047af` |
| G | HistoricalEntryScreen: bare scaffold, CirclePainPicker, ChoiceChipMetra wrap, inline add | ✅ done | `b6047af` |
| B | Manifesto polish: terracotta radial halo in hero (outer + centered 220×220) | ✅ done | `aae8ece` |
| H | Today screen: pain picker opacities, gap-14, flow chip borders 1.5px | ✅ done | `aae8ece` |

All 403 tests green, 0 analyzer warnings after Sprint 3 commit.

---

## Sprint 2 — Design Alignment Fixes (2026-05-01)

| Phase | Task | Status | Commit |
|---|---|---|---|
| Phase 1 | Calendar: rounded-square days, remove FAB, default selection | ✅ done | `bf4173d` |
| Phase 2 | Widgets: soft halo dots/pain picker, terracotta chips, no checkmark | ✅ done | `a81cc11` |
| Phase 3 | Entry+Calendar: inline symptom input, symptom chips in day card | ✅ done | `ba9ad63` |
| Phase 4 | Onboarding: privacy screen step (reverted — screen removed in Sprint 3) | ✅ done | `5b7ec8e` |

All 7 issues from `what-you-MUST-fix.md` resolved. All 405 tests green.

---

## Sprint 1 — UI Alignment to HTML Design Mockups (2026-04-30)

| Phase | Task | Status | Commit |
|---|---|---|---|
| P-A | Foundation reconciliation (theme tokens, wordmark) | ✅ done | `214d2ad` |
| P-B | Flow domain migration (FlowType enum, schema v4) | ✅ done | `0f5b8b1` |
| P-C | Daily entry widget overhaul (FlowTypeChips + FlowIntensityDots) | ✅ done | `c4f86de` |
| P-D | Pain picker null state | ✅ done | `4fc46d8` |
| P-E | Calendar visual + navigation | ✅ done | `d4a0e29` |
| P-F | Archive timeline + Stats label fix | ✅ done | `3d197c1` |
| P-G | Onboarding fixes | ✅ done | `c974baf` |
| P-H | Symptom defaults + l10n | ✅ done | — |
| P-I | Final visual QA pass | ✅ done | `5ecd523` |

---

## Key architecture decisions

- **FlowType enum**: `assente=0, mestruazioni=1, spotting=2` (persisted as `flow_type INT` in DB schema v4).
- **DM-02 invariant**: `flowIntensity` must be null unless `flowType == FlowType.mestruazioni` — enforced in `SaveDailyLog`.
- **BackupSnapshot v2**: added `flow_type` field; reads v1 snapshots via old-spotting-bool derivation.
- **UX-02 intensity preservation**: `_lastMensIntensity` local state in today/historical screens — persists last-known intensity when switching away from mestruazioni; restores on switch-back.
- **Calendar selection**: `_selectedDate` is non-nullable `DateTime`, initialized to today UTC; `_DayDetailCard` always rendered.
- **Onboarding flow**: 2-step (welcome → first cycle). `_PrivacyPage` removed; canvas only renders Manifesto + Primo Ciclo.

## Key files reference

| File | Role |
|---|---|
| `lib/domain/entities/flow_type.dart` | FlowType enum |
| `lib/domain/entities/daily_log_entity.dart` | Main log entity (flowType, flowIntensity, painEnabled, painIntensity) |
| `lib/features/daily_entry/widgets/flow_type_chips.dart` | Flow type selector |
| `lib/features/daily_entry/widgets/flow_intensity_dots.dart` | Soft halo dot selector |
| `lib/features/daily_entry/widgets/circle_pain_picker.dart` | Pain picker (int? selected, malva, soft halo) |
| `lib/features/daily_entry/today_screen.dart` | Today entry with inline symptom input |
| `lib/features/calendar/widgets/calendar_day.dart` | Rounded-square day cells |
| `lib/features/calendar/calendar_screen.dart` | Default selection, symptom chips in day card |
| `lib/core/widgets/choice_chip_metra.dart` | Terracotta chip, no checkmark |
| `lib/features/onboarding/onboarding_screen.dart` | 2-step onboarding: Manifesto → Primo Ciclo (privacy screen removed) |
| `lib/core/theme/metra_colors.dart` | Token source — `accentPain` = malva |
| `lib/l10n/app_it.arb` | All Italian copy |
