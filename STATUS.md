# Métra — Status

**Last updated**: 2026-05-01  
**Active plan**: DESIGN-BIBLE Conformance Rebuild  
**Plan**: `.claude/docs/plans/2026-05-01-bible-conformance-rebuild.md`

> **Canonical UI source of truth: [`design/DESIGN-BIBLE.md`](design/DESIGN-BIBLE.md)** — transcribes `design/Métra Screens Light.html`. Read at every session boot. All UI changes must conform; deviation requires updating the HTML mockup first.

---

## DESIGN-BIBLE Conformance Rebuild (active, 2026-05-01)

**Gate**: 425 tests green, `flutter analyze --fatal-infos --fatal-warnings` → 0 issues after Phases 0–3.  
4 pre-existing encryption timeouts in full-suite run (pass in isolation — resource contention).

| Phase | Description | Status | Commits |
|---|---|---|---|
| **0 · Foundation** | Token files (colors/spacing/typography), MetraIcon/MetraMoon, custom tab bar | ✅ done | `9656b58`…`7316fc2` |
| **1 · Daily entry** | Section frames (surfaceRaised + ink@0.07 borders + 18/24 padding + gap 1), screenTitle (26px), bottom padding 100, dot geometry (50×50, stroke 1.4/1.5), notes border, symptom 44dp tap targets | ✅ done | `5ad0202` |
| **2 · Calendar** | Indicator icons (MetraIcons drop/dropOutline/starSmall size 11), symptom indicator added, CL-01 fix, grid padding 12 + rowGap 2, Italian day headers, flow pill height 32 radius 10, edit CTA MetraIcons.note, legend Previsione last | ✅ done | `774d9dd` |
| **3 · Onboarding** | MetraWordmark widget (Mētra U+0113, DM Serif 56/ls-0.02em), manifesto headlineLg (34px), hero fixed 340px, Primo Ciclo headlineSm (28px), stepper GestureDetector 40×40 radius 10, active text → sabbia, firstDate → DateTime(2000), ARB cleanup | ✅ done | `f3d2114` |
| **4 · Archivio rebuild** | Domain: extend CycleSummary (maxPain/dominantPainIntensity). UI: rebuild timeline card per bible § 10 | ⏳ **next** | — |
| **5 · Statistics rebuild** | Stats screen per bible § 11 | ⏳ queued | — |
| **6 · Brand** | Métra/Mētra resolution in product copy — **needs user decision** before proceeding | ⏳ queued | — |
| **7 · Final** | Golden walk + ship | ⏳ queued | — |

---

## Key architecture decisions

- **FlowType enum**: `assente=0, mestruazioni=1, spotting=2` (persisted as `flow_type INT` in DB schema v4).
- **DM-02 invariant**: `flowIntensity` must be null unless `flowType == FlowType.mestruazioni` — enforced in `SaveDailyLog`.
- **BackupSnapshot v2**: added `flow_type` field; reads v1 snapshots via old-spotting-bool derivation.
- **UX-02 intensity preservation**: `_lastMensIntensity` local state in today/historical screens — persists last-known intensity when switching away from mestruazioni; restores on switch-back.
- **Calendar selection**: `_selectedDate` is non-nullable `DateTime`, initialized to today UTC; `_DayDetailCard` always rendered.
- **Onboarding flow**: 2-step (welcome → first cycle). `_PrivacyPage` removed in Sprint 3.
- **Tab bar**: custom `MetraTabBar` (frosted glass, 84dp, BackdropFilter blur 16, MetraIcons) — replaced Material 3 `NavigationBar` in Phase 0 Wave 0.2.
- **Off-catalog primitives**: `inkSoft`, `surfaceSunken`, `divider`, `textDisabled`, `dustyOchreDeep`, `mossDeep` still exist in `metra_colors.dart`; consumer sweep pending during per-screen phases.
- **Brand**: `onboarding_privacy_line` ARB key retains acute `Métra` pending Phase 6 decision. `DESIGN-BIBLE.md` also retains acute in the manifesto subhead (HTML is canon — verify HTML before changing).

## Key files reference

| File | Role |
|---|---|
| `lib/core/theme/metra_colors.dart` | Canonical color tokens (10 primitives + semantic aliases) |
| `lib/core/theme/metra_spacing.dart` | Spacing (legacy sN + canonical spN) and radius catalog |
| `lib/core/theme/metra_typography.dart` | Role-named type tokens (displayHero, screenTitle, headlineLg…) |
| `lib/core/widgets/metra_icon.dart` | MetraIcon widget + MetraIcons SVG constants |
| `lib/core/widgets/metra_tab_bar.dart` | Custom frosted-glass tab bar (Wave 0.2) |
| `lib/core/widgets/metra_wordmark.dart` | MetraWordmark widget — "Mētra" DM Serif 56 |
| `lib/domain/entities/flow_type.dart` | FlowType enum |
| `lib/domain/entities/daily_log_entity.dart` | Main log entity (flowType, flowIntensity, painEnabled, painIntensity) |
| `lib/features/daily_entry/today_screen.dart` | Today entry — section frames, Stack CTA overlay |
| `lib/features/daily_entry/widgets/flow_intensity_dots.dart` | Soft halo dot selector (50×50, stroke 1.4) |
| `lib/features/daily_entry/widgets/circle_pain_picker.dart` | Pain picker (50×50, malva 1.5 stroke, level-0 transparent) |
| `lib/features/calendar/calendar_screen.dart` | Calendar with symptom indicator support |
| `lib/features/calendar/widgets/calendar_day.dart` | Day cells with MetraIcons indicators |
| `lib/features/onboarding/onboarding_screen.dart` | 2-step onboarding: Manifesto → Primo Ciclo |
| `lib/l10n/app_it.arb` | All Italian copy (source of truth) |
| `lib/router/app_router.dart` | go_router config + MetraTabBar shell |
