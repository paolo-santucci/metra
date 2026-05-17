# Pre-Implementation Review — Cupertino Picker UX Refinement

**Date:** 2026-05-09 · **Branch:** main · **Scope:** iOS-only refinement of the two Cupertino pickers in the Settings screen.

## Summary

The current iOS Cupertino pickers (added in rc12, polished in rc13-rc14) follow a consistent pattern: `showCupertinoModalPopup` → 44 dp toolbar Row with `Annulla` / `OK` → wheel column. The two functions `_showTimePickerIOS` (L435-517) and `_showDaysPickerIOS` (L560-655) are 90% duplicates of each other. Required behaviour change: (1) wheel-stop autosave with debounce, (2) `Annulla` becomes `Ripristina` for these two pickers only, (3) `Ripristina` resets the wheel without dismissing. The change is well-scoped: one screen, two functions, no domain or repository edits, no schema work, no design-bible amendment (§ 18.8 explicitly disowns picker visual treatment from canon).

## Findings

### Critical

**C-1. Semantic ambiguity the spec must lock down before build.**
Three points the brief leaves open — flag them in the spec OQs so the planner does not invent answers:
- **Barrier-dismiss / drag-down behaviour with autosave**: `showCupertinoModalPopup` is barrier-dismissible by default. Once wheel-stop autosave is wired, "drag down / tap outside" silently keeps the auto-saved value. This is a substantive change from today's "Annulla = no write" semantic — must be spelled out (and the picker title-bar narrative may want a hint, e.g. semantics label).
- **OK's new role**: with autosave, OK is purely "close" — the value was already saved on wheel-stop. Spec must say so or it gets reinvented as "confirm-then-save" later.
- **What is "original (pre-open) value" for Ripristina?** `_showTimePickerIOS` (L441) seeds the wheel with `_roundTo5(settings.notificationTimeMinutes)` — if stored value is 542, the wheel opens on 540. **Recommendation: Ripristina restores the displayed initial (post-roundTo5), not the raw stored minute** — that is what the user actually saw on open.

**C-2. Every save triggers a notification reschedule via the global listener.**
`lib/app.dart:133-183` listens to `settingsNotifierProvider` and calls `scheduler.execute()` on every emission, which in turn calls `_notifService.cancelPredictionNotifications()` + `schedulePredictionNotification()` (`schedule_prediction_notification.dart:34, 68`) — both are platform-channel calls. With 250 ms debounce after wheel-settle the cost is bounded to ~1 reschedule per scroll session (not a "storm"), but Ripristina also fires a save → second reschedule. Idempotent and recoverable on Android (`AndroidScheduleMode.inexactAllowWhileIdle` per rc14), but the spec must acknowledge the cost so the planner does not get surprised when reading the diff. The save itself is a single SQL UPDATE (`drift_app_settings_repository.dart:48-57`) — cheap.

### Important

**I-1. The two iOS picker functions are 90% duplicates and the new feature triples the duplication.**
`_showTimePickerIOS` (L435-517) and `_showDaysPickerIOS` (L560-655) share: `showCupertinoModalPopup` shell, 310 px container, 44 px toolbar Row, two `CupertinoButton`s with identical styling (`fontSize: 17`, `accentFlow` for OK, `textSecondary` for Annulla — load-bearing per rc13 commit). Adding debounced autosave + Ripristina-without-close to two near-identical functions is an anti-pattern (clean-code Rule of Three: this is the third reason to refactor). **Recommendation: extract `_CupertinoPickerScaffold` (or `_buildPickerToolbar`) holding toolbar + container chrome + debounce timer**; the wheel and the "what to save" callback are the only per-picker variables. This both simplifies the build phase AND keeps the new behaviour in one place.

**I-2. iOS HIG departure — make the spec explicit.**
"Cancel" → "Restore (without close)" is a non-native iOS pattern. rc11-rc14 polished *toward* iOS conventions (17 pt label pinning, `MediaQuery.alwaysUse24HourFormatOf`, `CupertinoDatePicker.minuteInterval`). The spec should call out this is a deliberate, user-driven departure so reviewers do not flag it as a regression.

**I-3. l10n key needs gen-l10n run.**
After adding `common_restore` to both `app_it.arb` (key proposed: "Ripristina") and `app_en.arb` (proposed: "Restore"), `flutter gen-l10n` must run and the generated `lib/l10n/app_localizations*.dart` files must be committed in the same commit. (Not novel — rc12 already established this rhythm.) **Final key naming is a planner decision** — `common_restore` matches the existing `common_cancel` / `common_ok` / `common_save` / `common_delete` register and is the recommended pick.

**I-4. Debounce primitive — pick the simple one.**
The codebase has zero `Timer`/`debounce` primitives today (`grep -r 'Timer(' lib/` returns empty). Two viable options:
- **(a) `Timer? _debounce; _debounce?.cancel(); _debounce = Timer(Duration(milliseconds: 250), () => _save(...))`** driven by `onSelectedItemChanged`. **Recommended** — simplest possible; no new abstraction.
- (b) `NotificationListener<ScrollEndNotification>` wrapping the wheel for true "stopped" detection. More semantically correct but more code; harder to test (requires a real scroll-end pump).

Both pickers must `_debounce?.cancel()` on dismiss/close so a closed-modal save does not race the next open. Place in the new `_CupertinoPickerScaffold` from I-1.

### Suggestion

**S-1. Tap-OK with autosave still pending.**
If the user scrolls and immediately taps OK before the 250 ms debounce fires, the pending Timer must `_save()` synchronously (or call `_save()` and cancel the Timer). Trivial but worth a one-liner in the spec.

**S-2. Semantics labels for new toolbar.**
`Ripristina` button must carry `Semantics(label: ...)` with the action verb (TalkBack/VoiceOver) — every interactive widget in this codebase already does this for the value-row chevrons. Keep parity.

## What was done well

- The picker pair already follows a consistent, narrow pattern with shared CupertinoTheme wrap, fixed 17 pt labels, and `accentFlow`/`textSecondary` color split — refactoring to a shared scaffold will be straightforward.
- `SettingsNotifier.save` (`settings_notifier.dart:48-52`) and `_save` (`settings_screen.dart:308-310`) are already idempotent and cheap — no notifier work needed for this feature.
- `_roundTo5` (L326-327) and `seedMinutes` capture pattern (L441) cleanly separate "raw stored" from "displayed initial" — the planner can lean on this to define Ripristina's reference value.

**Verdict: APPROVE WITH NOTES** — the existing code is clean and the change is well-scoped. The four open semantic questions in C-1 (and the test rewrite in Spec Inputs) must be resolved before build, but no Critical defect blocks the work.

---

## Spec Inputs

### Components and files affected (with line ranges)

- `lib/features/settings/settings_screen.dart`
  - `_showTimePickerIOS` L435-517 — refactor toolbar Row, add debounce + Ripristina
  - `_showDaysPickerIOS` L560-655 — same
  - Callsites: time picker L156, advance picker L138 — unchanged
  - Helpers `_save` L308-310, `_roundTo5` L326-327 — unchanged
  - Recommended new helper: `_CupertinoPickerScaffold` (or `_buildPickerToolbar`) — single source of truth for chrome + debounce + Ripristina
- `lib/l10n/app_it.arb` — add `common_restore: "Ripristina"` after L33
- `lib/l10n/app_en.arb` — add `common_restore: "Restore"` after L11
- `lib/l10n/app_localizations*.dart` — regenerated by `flutter gen-l10n`; commit alongside ARB edits
- **Out of scope**: Material/Android `_showTimePicker` Material branch (L533-558), `_showAdvancePicker` `SimpleDialog` branch (L666-688), `_showLanguagePicker`, `_showThemePicker`, `_showDeleteConfirmation`, `lib/app.dart` listener, `lib/data/`, `lib/domain/`, schema, design bible.

### Patterns to follow

- **Reuse seam**: `showDialog`-style "Builder + ConsumerStatefulWidget" is overkill for two CupertinoButtons; a closure with a captured mutable `int? confirmedMinutes` (existing pattern at L444) is sufficient. **Wrap the modal builder in a `StatefulBuilder`** so the wheel can be reset (Ripristina path) by calling `setState`.
- **Anti-pattern present** (do not propagate to new code): toolbar Row is duplicated verbatim across the two pickers — extract per I-1.
- **Existing 17 pt label fix from rc13**: every label must keep `style: TextStyle(fontSize: 17, ...)` and `padding: EdgeInsets.symmetric(horizontal: 16)` — DO NOT use the default `CupertinoButton` vertical padding (rc13 explicitly removed it). Carry into the scaffold.
- **debugDefaultTargetPlatformOverride pattern** (lessons cr-cupertino-04): all new tests must `setUp { debugDefaultTargetPlatformOverride = TargetPlatform.iOS } / tearDown { = null }`.

### Integration constraints

- **Settings notifier**: `SettingsNotifier.save` is async but fire-and-forget at the call site (`_save` ignores the future). Wheel-stop autosave keeps that pattern — no `await` needed; do NOT add user-visible loading state.
- **App-level reschedule listener** (`lib/app.dart:133-183`) will fire on every save → bounded to ~1 reschedule per scroll session by the 250 ms debounce. Acceptable.
- **Design bible**: § 18.8 (canon `ui-design-bible.md`:1255) explicitly excludes pickers as "implementation-side". **No bible amendment needed.**
- **HTML mockup**: the design system HTML (`docs/design/metra-design-system.html` § S14_Impostazioni L851-889) only renders closed value rows for Notifiche — it does not depict picker chrome. **No HTML mockup update needed for the toolbar label change.** Surface this to the orchestrator so the HTML-mockup-first protocol does not default-trigger.
- **Build agent routing**: project memory says "Always use flutter-ui-expert for UI" — closest match in this repo is `flutter-frontend-engineer`. Flag for the planner.

### Tech debt that complicates the feature

- The two `_show*PickerIOS` functions are 90% duplicate today. Without I-1's scaffold extraction, the build phase will land debounce + Ripristina logic in two places, doubling regression risk. **Mandatory**, not optional.
- No `Timer`/`debounce` primitive exists in `lib/` today — this feature introduces it. Worth a one-line comment at the call site so the next reader knows where to look.
- No relevant blocker from M3 memory (cr-m3-* lessons): `_toCompanion`, schema v7, no-Scrollable test guards, plural ARB — all already shipped in rc12-rc14. Skip.

### Test coverage baseline

**Existing iOS-branch tests in `test/features/settings/settings_screen_test.dart` (in scope):**

| Lines | Group / test | Action |
|---|---|---|
| 1052-1083 | iOS time picker — "tap on enabled row opens CupertinoDatePicker modal" | KEEP unchanged |
| 1085-1114 | iOS time picker — "Annulla dismisses without saving" | **REWRITE** as "Ripristina resets wheel and resaves original, modal stays open" — assert (a) wheel shows seeded value, (b) `stub.savedSettings?.notificationTimeMinutes == seededValue`, (c) `find.byType(CupertinoDatePicker)` still findsOneWidget |
| 1116-1148 | iOS time picker — "OK confirms and saves seeded value without scroll" | **REFRAME** to "OK closes the modal" — autosave is covered by new test below; assert `find.byType(CupertinoDatePicker)` findsNothing after OK |
| 1151-1181 | iOS days picker — "tap on Preavviso row opens CupertinoPicker modal" | KEEP unchanged |
| 1183-1209 | iOS days picker — "Annulla dismisses without saving" | **REWRITE** analogously to L1085-1114 |
| 1211-1243 | iOS days picker — "OK confirms..." | **REFRAME** analogously to L1116-1148 |
| 1245-1288 | iOS days picker — "shows day labels near center of picker" | KEEP unchanged |

**Other "Annulla dismisses" tests (out of scope, do not touch):**
- L221, L328, L770 — these are bottom-sheet language/theme pickers, NOT the two iOS Cupertino pickers under refactor.

**New tests required:**
1. **Wheel-stop autosave (time picker)**: scroll wheel by N minutes; `await tester.pump(Duration(milliseconds: 260))`; assert `stub.savedSettings?.notificationTimeMinutes == initial + N` AND `find.byType(CupertinoDatePicker)` still findsOneWidget.
2. **Wheel-stop autosave (days picker)**: same shape, on the days wheel.
3. **Ripristina resets and resaves original, modal stays open** (time + days, two tests): scroll wheel; pump debounce; tap `Ripristina`; pump; assert wheel shows seeded value, `stub.savedSettings` reverted to seed, modal still mounted.
4. **OK closes the modal (autosave already happened)** (time + days, two tests): scroll wheel; pump debounce; tap OK; pump; assert modal dismissed and last save matches scrolled value.
5. **Barrier-dismiss / drag-down preserves auto-saved value** (one test): scroll wheel; pump debounce; tap outside (`tester.tapAt(Offset(10, 10))` or `barrierDismissible` invocation); assert modal dismissed and `stub.savedSettings` reflects scrolled value (NOT seeded).
6. **Pending-debounce + tap-OK** (one test, optional but cheap): scroll wheel; do NOT pump full 250 ms; tap OK; assert save fires once with scrolled value (Timer cancelled and synchronous save executed).

**Test count delta**: −2 rewritten + 4 reframed + 7 new ≈ +7 net iOS-branch tests. Within budget.
