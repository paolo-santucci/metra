# Canon Design-Surface Review — M1 Configurable Cycle Reminder

**Date**: 2026-05-08
**Reviewer**: code-reviewer (read-only, pre-implementation)
**Scope**: design-canon surface only — `metra-screens-light.html` (M1 edit target) plus `metra-screens-dark.html`, `metra-design-system.html`, `.claude/docs/canon/ui-design-bible.md` (assess-only at M1; mirrored at M2)
**Spec ref**: `.claude/docs/specs/lp-20260508-configurable-cycle-reminder-spec.md`
**Plan ref**: `.claude/docs/plans/lp-20260508-configurable-cycle-reminder-plan.md` MC-1.1 / MC-1.2 / MC-1.3

---

## Summary

The canon design surface is internally consistent and ready for a clean three-row mockup edit at M1. The only true risk is the regression-net invariant `find.byType(Scrollable) findsNothing` (`settings_screen_test.dart:402,519`), which is structurally incompatible with a 14-option ListTile-stack picker on a 360×640 viewport. The conflict is not stylistic — it must be resolved at M1 in design-space and locked into the mockup before M2 / M3 can proceed. The new "time of day" row is a stock SettingsRow value variant; no new atom is required and no bible-§15 anti-pattern is implicated by the row itself.

---

## Findings

### Critical

**C-1 — `metra-screens-light.html:1199-1207` (Notifiche group: 2 → 3 rows).** The Notifiche `_GroupCard` currently renders only `Promemoria ciclo` (toggle) and `Preavviso` (value). M1 must add a third value-row for the new "time of day" choice between line 1206 (existing `<SettingsRow label="Preavviso" .../>`) and line 1207 (closing `</SettingsCard>`). The third row must reuse the existing `SettingsRow` value variant verbatim — `<SettingsDivider />` then `<SettingsRow label="Orario" value="alle 09:00" />`. *Why it matters*: MC-1.1 requires three rows; MC-1.3 requires no new component. *Concrete fix (do not apply at M1, this is a finding for the implementer)*: insert two lines after 1206, mirroring the structure of line 1206 — same row geometry, same value-variant trailing, no extra variant.

**C-2 — Picker no-Scrollable invariant is structurally unsatisfiable at 14 options (R-01).** 14 ListTile-style options at ~56 dp each ≈ 784 dp of stacked content; smallest viewport in scope is 360×640 (used by `qp-real-device-clipping`). `settings_screen_test.dart:402` (`qp-combobox-glitch`) and `settings_screen_test.dart:519` (`qp-real-device-clipping`) both assert `find.byType(Scrollable) findsNothing` inside the picker sheet. With the current ListTile-stack pattern, this invariant cannot survive at 14 options. M1 must commit to an OQ-A resolution and the mockup must reflect it (Option B only). *Concrete fix*: lock the lean below (scrollable bottom sheet → relax invariant) into the M1 mockup commit message and into spec §8 OQ-A.

**C-3 — Bible disposition must be locked before M2 begins (R-02 / OQ-F).** §15.13 (line 1094) says *"No bottom sheet patterns in this bible's scope"* and §18.8 (line 1251) says pickers are *"implementation-side concerns"*. The Flutter implementation already uses `showModalBottomSheet` (existing settings advance-picker). Adding a second picker silently widens the canon/code drift. M1 must pick Option A (one-line acknowledgment in §18.8) or Option B (promote pickers to canon §19 + new design-system component) — picking neither and shipping is the failure mode flagged by R-02. *Concrete fix*: encode the lean (Option A) in the M1 mockup commit message; M2 mechanically applies it.

### Important

**I-1 — Italian label register: pick "Orario" (bible §14, line 1054 / 1060).** §14 register is single-word, noun-on-toggle / value-explicit; "Anticipo" was rejected for "Preavviso" because it was under-specified. Of the candidates: "Ora" is under-specified (homonym with *now / hour*); "Ora del promemoria" is too long for the 56 dp Inter-15 row and breaks parity with one-word neighbors; "Quando" is interrogative register, off-voice. **"Orario"** parallels "Preavviso" exactly — single-word, formal, value-explicit. *Concrete fix*: M1 mockup uses `label="Orario"`; M2 adds a row to bible §14 between lines 1060 and 1061: `| Time of day | Orario | Notification time-of-day row label. **Never** "Ora" alone — under-specified (homonym with "now/hour"). |`.

**I-2 — Value-text should match the §14 trailing-preposition pattern.** §14 line 1074 documents the *Preavviso* value pattern as `1 giorno prima / {n} giorni prima` — the trailing word makes the temporal relation explicit. The new row should render `alle 09:00` (preposition leading), not bare `09:00`. The numeric formatting is locale-driven via `MaterialLocalizations.formatTimeOfDay` at M3 (already established convention, no project-wide `alwaysUse24HourFormat` override). *Concrete fix*: M1 mockup uses `value="alle 09:00"`; M2 adds value-text guidance to bible §14 alongside the *Preavviso* row.

**I-3 — `metra-screens-dark.html:1206-1214` and `metra-design-system.html:851-889` are out of M1 scope but contain the parallel structures M2 must mirror.** Dark mockup line 1213 carries the same `Preavviso` row; design-system §14 `S14_Impostazioni` line 864 ditto. M1 changes only the light mockup; M2 mirrors verbatim. Confirm M1 does not edit these files. *Concrete fix*: M1 PR diff must show changes to `metra-screens-light.html` only.

**I-4 — Bible §6.7 (line 501) compound-affordance constraint is preserved.** §6.7 says: *"If a setting requires a three-state UX, model it as a value-row with a chevron — not a toggle."* The new row is not a compound toggle+sub-choice — it is a separate value-row distinct from the `Promemoria ciclo` toggle. The existing two-row split (toggle + Preavviso) is already canon-coherent; adding a third value-row keeps the split. *No fix needed* — flagged so the M2 bible edit (§18.6 row count `2 → 3`) is the only change required, not a compound-affordance redesign.

### Suggestion

**S-1 — Mockup must render closed picker state only (lean: Option A).** If OQ-F resolves Option A, the M1 mockup renders only the closed third row (`label="Orario"` + `value="alle 09:00"` + chevron). It does NOT render an open picker sheet. If OQ-F resolves Option B, the mockup must additionally render the picker open state in three files (light + dark + design-system), which is a 3× work expansion at M2. The work-cost asymmetry is the single biggest argument for Option A. *Concrete suggestion*: lock Option A in the M1 commit; deferred picker rendering means the M1 deliverable is a 2-line insert instead of a multi-component canon expansion.

**S-2 — Design-system `S14_Impostazioni` (line 864) and dark mockup (line 1213) drift by row count after M1.** Until M2 lands, the canon set is internally inconsistent (light shows 3 rows, dark + design-system show 2). This is expected and gated by the M1→M2 user-approval edge per `feedback_ui_change_protocol.md` and plan §6 MC-1.2. *No fix*; flagged so reviewers don't false-positive the temporary inconsistency.

---

## What was done well

- **The SettingsRow value variant is already the canonical answer** for the new row (bible §18.5.1 / mockup `metra-screens-light.html:1152-1176`). No new atom or variant is needed — confirmed.
- **Bible §14 lexicon discipline is rigorous** (e.g. the "Anticipo → Preavviso" rejection note at line 1060), giving clear precedent for picking "Orario" over weaker candidates.
- **Cross-file parity is well-enforced**: light, dark, and design-system §14 use identical SettingsRow / SettingsCard / SettingsDivider / MetraToggle structure, so M2 mirroring is mechanical line-for-line work — no architectural surprise.

---

## Verdict

**APPROVE WITH NOTES** — the canon design surface is sound; M1 can proceed once OQ-A, OQ-B, OQ-D, OQ-F resolutions below are confirmed by the user.

---

## Spec Inputs

### Files to modify in M1

- `docs/design/metra-screens-light.html` lines **1206–1207** — insert one `<SettingsDivider />` and one new `<SettingsRow label="Orario" value="alle 09:00" />` so the Notifiche `_GroupCard` becomes a 3-row card. No other file is touched at M1.

### Files to assess but NOT modify in M1 (deferred to M2)

- `docs/design/metra-screens-dark.html` (parallel edit at line 1213 area)
- `docs/design/metra-design-system.html` §14 `S14_Impostazioni` (parallel edit at lines 860–865)
- `.claude/docs/canon/ui-design-bible.md` §14 (lexicon row), §18.6 (row count `2 → 3`), §18.8 (picker disposition note per OQ-F)

### Italian label & value-text recommendation

- **Label**: `Orario`. Justification: §14 register requires single-word, value-explicit nouns (`Preavviso` precedent at line 1060). "Orario" is the parallel: single-word, formal, unambiguous; the alternates "Ora" / "Quando" / "Ora del promemoria" each violate the register on length, ambiguity, or voice.
- **Value-text**: `alle 09:00`. Justification: §14 line 1074 establishes the trailing-preposition pattern (`{n} giorni prima`); leading "alle" makes the temporal relation explicit and parallels "prima". Numeric portion is rendered at M3 via `MaterialLocalizations.formatTimeOfDay` (locale-aware: IT 24h, EN 12h with AM/PM).

### Picker UX decision matrix — OQ-A (1–14 days)

| Candidate | Bible compliance | A11y (≥44 dp / DType 200% / SR) | No-Scrollable conflict | Bible / canon work cost | Lean |
|---|---|---|---|---|---|
| **Scrollable bottom sheet** (relax invariant) | OK — same SettingsRow ListTile pattern as today | Pass — 56 dp tap target, scroll handles overflow at 200% DType | **Relax** the invariant; flip 2 assert lines (`settings_screen_test.dart:402,519`) | Low (Option A) | **★ RECOMMENDED** |
| CupertinoPicker wheel | Imports iOS aesthetic; clashes with flat-descriptive canon register (§13–14 voice) | Pass natively; locale issues neutral | Bypasses (no Scrollable) | Medium — new component to canonise (Option B) | reject |
| Custom NumberPicker | No precedent; reinvention | Requires custom a11y plumbing | Bypasses | High — new component + bible section | reject |
| Two-column ListTile (1–7 / 8–14) | Fragments linear sequence; awkward register | Halves vertical space but adds visual scan complexity | Bypasses | Medium — new variant required | reject |
| Native dialog (`showDatePicker`-style) | Introduces Material dialog chrome the bible never renders | Pass natively | Bypasses | Medium — bible §15.13 amendment required | reject |

### Picker UX decision matrix — OQ-B (time of day)

| Candidate | Bible compliance | A11y | No-Scrollable conflict | Bible / canon work cost | Lean |
|---|---|---|---|---|---|
| **Material `showTimePicker`** (modal dialog) | Material-dialog aesthetic-drift (bible currently renders no Material dialog) — but flagged, not fatal | Pass natively (system widget) | None (dialog not sheet, invariant N/A) | Low — Option A note covers it; no new bible component | **★ RECOMMENDED** |
| Custom wheel sheet | iOS aesthetic; clash with flat-descriptive canon | Pass with custom plumbing | Bypasses | Medium — new component (Option B) | reject |
| Inline within day-picker sheet | Single-sheet UX violates §6.7 spirit (compound affordance discouraged) | Plausible | Becomes worse — more content to fit | Medium | reject |

### OQ-D recommendation (minute granularity)

**Every minute (0–59).** Reasoning: `showTimePicker` exposes per-minute granularity natively; constraining to 5-minute steps or hour-only requires custom UX with no a11y gain. Core principle 5 ("respect the adult user") argues against a constraint the platform does not impose. Picker height / tap-target sizing is platform-managed.

### OQ-F recommendation (Option A vs Option B)

**Option A.** Reasoning:
1. §15.13 already disowns bottom-sheet patterns canon-wide; §18.8 already classifies pickers as implementation-side. The disposition is consistent with the existing canon — Option A is a one-line clarification, not a new stance.
2. The Flutter implementation already uses `showModalBottomSheet` — Option A formalises the existing gap; Option B retroactively requires canon to absorb a pattern with one consumer.
3. Work-cost asymmetry: Option A keeps M2 trivial (lexicon row + §18.6 count + §18.8 one-line note). Option B forces M2 to render picker open-state in three files (`metra-screens-light.html`, `metra-screens-dark.html`, `metra-design-system.html`) plus a new bible §19 — multiplies M2 effort ~5× with zero new downstream consumer.
4. M1 mockup stays a 2-line insert under Option A; under Option B the M1 mockup must additionally render an open-picker state, expanding M1 effort and re-opening UX questions the spec deferred.

### Whether the M1 mockup must render picker open-state

**No — under recommended Option A.** The M1 deliverable is the closed third row only (`label="Orario"` + `value="alle 09:00"` + chevron). If the user rejects Option A and selects Option B, the M1 mockup must additionally render an open-picker state in `metra-screens-light.html` (and M2 mirrors to dark + design-system) — flag this conditional dependency so the M1 author knows the scope flips with the OQ-F resolution.

### Constraints the mockup edit must respect

- **Bible §15 anti-patterns**: no FAB, no checkmarks on toggles/chips, no purple/blue/pink/green outside the seven accent tokens, no emoji, no badge counts, no drop shadows, no `999px` pill radius, no glassmorphism. The new row is a stock SettingsRow value variant — none of these apply unless someone invents a new affordance.
- **§18.4 GroupCard tokens**: `margin 0 24`, `bg surface`, `radius 16`, `border 1px rgba(43,37,33,0.07)`, `overflow hidden`. Untouched by this insert.
- **§18.5 row geometry**: `height 56`, `paddingInline 20`, label `Inter 15 weight 500 inchiostro`, divider `1px rgba(43,37,33,0.07)` between rows in the same card. The new row inherits these from the existing `SettingsRow` atom — do not override.
- **§18.5.1 value variant trailing**: value-text `Inter 14 rgba(0.68)` + `chevron_right 16 rgba(0.40)`. The atom already enforces this — do not introduce a new icon, no leading icon, no colored accent.
- **Wordmark discipline**: not applicable to this edit (the row label is `Orario`, not `Mētra`).

### M3 ripple constraints from the M1 picker-UX choice

- **`settings_screen_test.dart:402` (`qp-combobox-glitch`)** and **`settings_screen_test.dart:519` (`qp-real-device-clipping`)** both assert `find.byType(Scrollable) findsNothing`. Under recommended Option A (relax-invariant), both lines flip to either `findsOneWidget` or are removed with a documented rationale comment citing the 14-option overflow. M3 must update both literals — do not silently delete the test.
- **Time-picker**: `showTimePicker` is a Material dialog → not a `Scrollable` host inside the existing sheet, so the no-Scrollable invariant is structurally not engaged for OQ-B. M3 a11y tests should add a separate widget test for the time-picker dialog (label exposure, locale-formatted value), not piggy-back on the day-picker invariants.
- **`MaterialLocalizations.formatTimeOfDay`** must be wrapped in an ARB string (e.g. `settings_time_value` with `{time}` placeholder) to render the trailing-preposition pattern (`alle {time}`); raw `formatTimeOfDay(...)` calls in the widget tree fail NFR-07 (no untranslated literal).
- **No bible §6.7 compound-affordance refactor**: the third row is independent of the `Promemoria ciclo` toggle — do not let M3 "merge" them into a single compound row.
