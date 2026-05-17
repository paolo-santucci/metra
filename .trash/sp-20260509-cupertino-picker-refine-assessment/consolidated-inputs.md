# Consolidated Spec Inputs — Cupertino Picker UX Refinement

Single module under review (`lib/features/settings/settings_screen.dart` + `l10n` + matching tests), so this file is a pointer to the canonical report.

**Source report**: [`settings-screen-review.md`](./settings-screen-review.md)

## Headline (for sp-pm / sp-architect / sp-qa)

- **Verdict**: APPROVE WITH NOTES — code is clean, change is well-scoped, no Critical defect blocks the work.
- **Mandatory pre-build refactor**: extract a shared `_CupertinoPickerScaffold` (toolbar + container + debounce timer); without it the new behaviour lands in two duplicate places. (See finding I-1.)
- **Open semantic questions** (C-1 — spec MUST resolve before build):
  1. Drag-down / barrier-dismiss preserves the auto-saved value (deliberate, not a regression).
  2. OK becomes a pure "close" — value is already saved on wheel-stop.
  3. "Original value" for Ripristina = the displayed initial after `_roundTo5`, not the raw stored minute.
  4. iOS HIG departure ("Cancel" → "Restore (no close)") is intentional and user-driven.
- **Debounce primitive**: `Timer(Duration(milliseconds: 250))` driven by `onSelectedItemChanged`, cancelled on close + on tap-OK (synchronous save if pending). No new abstraction.
- **App-level reschedule listener** (`lib/app.dart:133-183`) fires on every save. With 250 ms debounce ≈ 1 reschedule per scroll session — acceptable.
- **No HTML mockup update needed**: bible § 18.8 explicitly disowns picker visual treatment. Surface to orchestrator so the HTML-mockup-first protocol does not default-trigger.
- **No bible amendment needed**.
- **Build-agent routing**: project memory says "always use flutter-ui-expert for UI"; closest in-repo agent is `flutter-frontend-engineer`. Use it for the picker refactor task.
- **l10n key recommendation**: `common_restore` (it: "Ripristina", en: "Restore"). Final decision = planner.

## Test delta (verbatim from §Test coverage baseline)

- **Rewrite (2)**: `test/features/settings/settings_screen_test.dart` L1085-1114 (time, "Annulla dismisses without saving") and L1183-1209 (days, same) → "Ripristina resets, modal stays open".
- **Reframe (2)**: L1116-1148 and L1211-1243 ("OK confirms" → "OK closes"; autosave covered by new tests).
- **Keep (3)**: L1052-1083, L1151-1181, L1245-1288.
- **Out of scope (3)**: L221, L328, L770 (bottom-sheet language/theme pickers — not the Cupertino refactor).
- **New (~7)**: wheel-stop autosave (time + days), Ripristina resets-without-close (time + days), OK closes (time + days), barrier-dismiss preserves auto-save, optional pending-debounce + tap-OK.

Net iOS-branch test delta: ≈ +7 tests.

## Reference into source report

For full details (findings, line ranges, integration constraints, patterns to follow, tech debt) read `settings-screen-review.md` end-to-end. All sections there are authoritative.
