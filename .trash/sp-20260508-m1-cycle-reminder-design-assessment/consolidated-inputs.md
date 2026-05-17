# Consolidated Assessment Inputs — M1 Configurable Cycle Reminder

**Date**: 2026-05-08
**Source reports**: `canon-design-surface-review.md` (single agent — canon design surface is one cohesive module)
**Spec ref**: `.claude/docs/specs/lp-20260508-configurable-cycle-reminder-spec.md`
**Plan ref**: `.claude/docs/plans/lp-20260508-configurable-cycle-reminder-plan.md`

---

## Verdict

**APPROVE WITH NOTES.** Canon design surface is internally consistent and ready for a 2-line mockup edit. The single hard risk is the structural conflict between the 14-option picker and the no-`Scrollable` regression invariants — it must be resolved at M1 in design-space (OQ-A) and locked into the mockup before M2/M3 can proceed.

---

## Cross-cutting concerns

The four open questions OQ-A / OQ-B / OQ-D / OQ-F are tightly coupled and resolved together:
- OQ-A (1–14 day picker) and OQ-B (time-of-day picker) together determine whether the M1 mockup must render picker open-state or only the closed third row.
- OQ-F (bible disposition) is the gate: Option A → mockup edit is 2 lines; Option B → mockup must render picker open-state in three files (≈5× M2 effort).
- OQ-D (minute granularity) is downstream of OQ-B — only material if a custom wheel is chosen.

---

## Spec Inputs (merged, deduplicated)

### Files M1 modifies

- `docs/design/metra-screens-light.html` lines **1206 → 1207** — insert `<SettingsDivider />` and `<SettingsRow label="Orario" value="alle 09:00" />`. **Scope: this single insertion only.**

### Files M1 assesses but does NOT modify (deferred to M2)

- `docs/design/metra-screens-dark.html` (parallel area at line 1213)
- `docs/design/metra-design-system.html` §14 `S14_Impostazioni` (lines 860–865)
- `.claude/docs/canon/ui-design-bible.md` §14 (lexicon row), §18.6 (row count `2 → 3`), §18.8 (one-line picker disposition note per OQ-F resolution)

### Italian copy (bible §14 register)

- **Row label**: `Orario` — single-word, formal, value-explicit; parallels `Preavviso` precedent (line 1060 of bible). Rejected: `Ora` (under-specified, homonym), `Quando` (interrogative, off-voice), `Ora del promemoria` (length breaks 56dp row parity).
- **Value-text**: `alle 09:00` — trailing-preposition pattern parallels `{n} giorni prima` (line 1074). Numeric portion is locale-rendered at M3 via `MaterialLocalizations.formatTimeOfDay`.

### Recommended OQ resolutions (committed leans)

| OQ | Lean | Primary justification |
|---|---|---|
| **OQ-A** (1–14 day picker UX) | **Scrollable bottom sheet** (relax the no-Scrollable invariant; flip 2 assert lines at M3) | Same SettingsRow/ListTile pattern as today; alternatives all introduce new canon components. 784 dp content vs 640 dp viewport ≠ stylistic — no-Scrollable is structurally unsatisfiable |
| **OQ-B** (time-of-day picker UX) | **Material `showTimePicker`** | Native, locale-aware (IT 24h / EN 12h+AM-PM via `formatTimeOfDay`), per-minute granularity built in, structurally outside the no-Scrollable invariant (it's a dialog, not a sheet) |
| **OQ-D** (minute granularity) | **Every minute (0–59)** | Platform-native; constraining is paternalistic (violates core principle 5) and requires custom UX with no a11y win |
| **OQ-F** (bible disposition) | **Option A** — one-line clarification in §18.8 acknowledging pickers as implementation-side | §15.13 + §18.8 already disown bottom-sheet/picker patterns; Option A formalises the existing gap; Option B forces ~5× M2 expansion (open-picker rendering in 3 files + new bible §19) for one downstream consumer |

### M1 mockup rendering decision

Under recommended **Option A**: the M1 mockup renders **only the closed third row** — no open-picker state. If the user rejects Option A and selects Option B, M1 scope expands to render an open-picker state in the light mockup, with M2 mirroring to dark + design system. This is the single conditional that flips M1 effort.

### Constraints the mockup edit must respect

- **Bible §15 anti-patterns**: no FAB, no checkmarks, no purple/blue/pink/green outside the seven accent tokens, no emoji, no badge counts, no drop shadows, no `999px` pill radius, no glassmorphism.
- **§18.4 GroupCard tokens**: `margin 0 24`, `bg surface`, `radius 16`, `border 1px rgba(43,37,33,0.07)`, `overflow hidden` — untouched.
- **§18.5 row geometry**: `height 56`, `paddingInline 20`, label `Inter 15 weight 500 inchiostro`, divider `1px rgba(43,37,33,0.07)` — inherited from existing `SettingsRow` atom.
- **§18.5.1 value variant trailing**: value-text `Inter 14 rgba(0.68)` + `chevron_right 16 rgba(0.40)` — atom-enforced; do not add leading icon, accent colour, or extra widget.

### M3 ripple constraints from the recommended M1 leans

- `settings_screen_test.dart:402` (`qp-combobox-glitch`) and `settings_screen_test.dart:519` (`qp-real-device-clipping`) — both assert `find.byType(Scrollable) findsNothing`. Under Option A both literals flip (likely to `findsOneWidget`) with a rationale comment citing 14-option overflow. Do not silently delete the tests.
- `MaterialLocalizations.formatTimeOfDay` raw call in widget tree fails NFR-07 (no untranslated literal); must be wrapped in an ARB key (e.g. `settings_time_value` with `{time}` placeholder) so the trailing `alle {time}` is part of the i18n surface.
- The new third row is independent of the `Promemoria ciclo` toggle — do **not** let M3 collapse them into a §6.7 compound affordance.

### Cross-module concerns

None — the canon design surface is a single cohesive module. The light/dark/design-system parallel structure is enforced by parity convention; M2 mirrors verbatim.

---

## Per-module detail

<details>
<summary><b>canon-design-surface-review.md</b> (123 lines)</summary>

Full report: `.claude/docs/specs/sp-20260508-m1-cycle-reminder-design-assessment/canon-design-surface-review.md`

Findings: 3 Critical (C-1 row-count edit, C-2 no-Scrollable structural conflict, C-3 bible disposition lock), 4 Important (I-1 Italian label register, I-2 value-text trailing-preposition, I-3 dark+design-system out-of-M1-scope parity, I-4 §6.7 compound-affordance non-issue), 2 Suggestion (S-1 closed-row-only mockup under Option A, S-2 expected canon inconsistency between M1 and M2).

</details>
