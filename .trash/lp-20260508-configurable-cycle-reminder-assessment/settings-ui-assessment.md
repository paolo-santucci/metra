## Module: Settings UI

**Path**: `lib/features/settings/`
**Agent**: code-reviewer

### Findings

#### 1. Architecture & coverage gaps

**1.1 The Settings screen has only two layers — no row-level widget extraction yet.**

`settings_screen.dart` (932 lines) defines exactly one screen widget (`SettingsScreen`, lines 42–671) plus a small flat hierarchy of private sub-widgets at the bottom of the file (`_MetraToggle`, `_SectionHeader`, `_GroupCard`, `_SettingsDivider`, `_SettingsRow`, `_KoFiPill`, lines 677–932). **There is no per-section widget** (`_NotificationsSection`, `_PreferencesSection`, etc.). The entire screen body — header, five `_GroupCard` sections, footer — is inlined in `SettingsScreen.build()` (lines 46–281, ~235 lines of `Widget` tree). The five pickers / handlers (`_showLanguagePicker`, `_showThemePicker`, `_showAdvancePicker`, `_showDeleteConfirmation`, `_handleExport`, `_handleImport`) are static methods on `SettingsScreen` (lines 285–670). This means there is no obvious "drop-in slot" for a new time-of-day picker — it will be a sixth static method, and the notification section will grow from two rows to three (settings_screen.dart:108–138).

**1.2 The advance-day picker uses the `Column(mainAxisSize: MainAxisSize.min)` + `isScrollControlled: true` pattern, identical to the language and theme pickers.**

After the two May-7 fixes, all three pickers in this file follow the same shape (settings_screen.dart:303–349 language, 351–407 theme, 409–442 advance). The contract is:
- `showModalBottomSheet<void>(context: …, isScrollControlled: true, builder: (sheetCtx) => Column(mainAxisSize: MainAxisSize.min, children: [for / ListTile…]))`
- Each `ListTile` shows `title:` + `trailing: selected ? Icon(Icons.check) : null` and `onTap:` does `Navigator.of(sheetCtx).pop()` then `_save(ref, settings.copyWith(...))`.
- `useSafeArea` is intentionally omitted — comments at lines 309–312, 357–358, 415–416 explain it leaves a dim-overlay band on real Android devices under the ShellRoute Scaffold.

The advance picker ends with a `for (int i = 0; i < 7; i++)` loop (line 425). To extend to 14 the loop bound becomes 14 — but see Risk R-3 below for height implications.

**1.3 No reusable picker primitive — all three pickers duplicate the modal scaffolding.**

There is no `_OptionsPicker` / `_RadioListPicker` widget. Each picker repeats the `showModalBottomSheet` + `Column` + `ListTile` boilerplate (settings_screen.dart:313–348, 359–406, 419–441). The duplication is small (~30 lines each) but real. A new time picker will *not* be a fourth `ListTile` list — it needs a `TimeOfDay` continuous input, so the existing pattern doesn't cover it. **There is no precedent in this file for a `showTimePicker` integration.**

**1.4 Riverpod wiring writes through to Drift on every interaction with no debouncing or coalescing.**

`SettingsNotifier.save` (settings_notifier.dart:48–52) does an unconditional `await repo.updateSettings(settings); state = AsyncData(settings);`. Every tap on a row — toggle flip, picker tile selection — calls `_save` (settings_screen.dart:285–287) which in turn calls `save`. There is **no debouncing, no batching, no coalescing**, and `state = AsyncData(settings)` is set *unconditionally* even if the saved object is identical to the prior state. Calls are also unguarded against re-entry: a fast double-tap on the toggle issues two parallel writes whose order is not guaranteed.

For the new feature, a `TimePicker` returns `TimeOfDay` once (per OK tap) and the advance picker fires once per ListTile tap, so the "every keystroke" concern doesn't directly apply. But the **app-wide `ref.listen` on `settingsNotifierProvider` in `app.dart:133–183` reschedules the notification on every save** — meaning each picker confirmation triggers a cancel+reschedule round trip. This is fine functionally but worth noting: the rewrite must not regress this behaviour, and any "preview" / "dry-run" UI must not save until the user confirms.

**1.5 `SettingsNotifier.build()` has dual-source ambiguity that can mask staleness during the rewrite.**

`build()` (settings_notifier.dart:30–46) tries the stream first (`appSettingsStreamProvider`), falls back to the one-shot `repo.getOrCreate()` if the stream hasn't emitted yet. The fallback exists for tests that override `appSettingsRepositoryProvider` only. This is **fine for the existing fields** but worth flagging: when adding a new column, both paths must surface the new field, otherwise tests that exercise only the fallback path could pass while the production stream silently drops the new column. Verify the stream provider re-emits after schema migration.

#### 2. Code health

**2.1 `settings_screen.dart` at 932 lines is far past the project's "split if >150 lines" rule.**

The CLAUDE.md threshold is 150 lines per widget. `SettingsScreen.build()` alone is ~235 lines (settings_screen.dart:46–281). The picker static methods together are ~360 lines (settings_screen.dart:285–670). Six private widgets at the bottom add ~260 lines (settings_screen.dart:677–932). The current structure works but each new feature compounds the violation. Adding a time picker will push the file to ~1000+ lines.

**Concrete extraction candidates** (ordered by leverage):
- `_NotificationsSection` widget — currently settings_screen.dart:108–138, will host two existing rows + the new time row.
- `_OptionPickerSheet<T>` reusable widget — collapses the three identical `Column`+`ListTile` pickers into one.
- `_handleExport` and `_handleImport` (settings_screen.dart:493–670, ~178 lines) — these belong in a service / use-case, not on the screen widget.

**2.2 Naming for the new field — recommend `notificationTime` over `notificationTimeOfDay` or `reminderTime`.**

Current convention in this codebase:
- DB column: `notificationDaysBefore` (lib/data/database/app_database.dart:93–94, snake_case `notification_days_before` in SQL).
- Domain field: `notificationDaysBefore` (lib/domain/entities/app_settings_data.dart:42).
- l10n key: `settings_advance_value`, `settings_advance_label` (lib/l10n/app_it.arb:368–374, lib/l10n/app_en.arb:144–150) — the *English* word is "advance notice", *Italian* is "Preavviso".

The pair should mirror the existing names exactly:
- DB: `notificationTime` → snake `notification_time` (TEXT or INT minutes-since-midnight; see Risk R-2).
- Domain: `notificationTime` (type `TimeOfDay` in the entity *or* `String 'HH:mm'` — domain layer must remain Flutter-free per CLAUDE.md §4 layering rules; `TimeOfDay` is from `package:flutter/material.dart`, so storing as `String 'HH:mm'` or `int minutes` and converting at the UI boundary is the orthodox choice).
- l10n: `settings_notification_time_label` ("Orario notifica" / "Notification time"), `settings_notification_time_value` (formatted via `MaterialLocalizations.formatTimeOfDay`).

Avoid `reminderTime`: it diverges from the existing `notification*` prefix on the sibling fields. Avoid `notificationTimeOfDay`: redundant given the type.

**2.3 The `notificationDaysBefore` upper bound is hard-coded in three places — splitting into a constant is overdue.**

- `_showAdvancePicker` loop bound `i < 7` (settings_screen.dart:425).
- `assert` in `SchedulePredictionNotification.execute` `>= 1 && <= 7` (lib/domain/use_cases/schedule_prediction_notification.dart:36–40).
- The l10n plural `settings_advance_value` works for any `n` but the message file has no upper-bound documentation.

For 14, all three sites must change. There is no shared `kMaxAdvanceDays` constant — adding one in `core/constants/app_constants.dart` is a clean path. Likewise the new time field needs a default constant (the rewrite spec should pick a default, e.g., 09:00 to match the current hardcoded value).

**2.4 `AppSettingsData.copyWith` cannot null-out fields — pattern duplicated in the theme picker.**

settings_screen.dart:371–383: `_showThemePicker`'s "system" option uses the full `AppSettingsData(...)` constructor because `copyWith` cannot set `darkMode` back to `null`. If the new time field is nullable (e.g., null = "use default 09:00"), the same workaround will apply. Recommend that the rewrite either makes the field non-null with an explicit default, or extends `copyWith` with a sentinel (`Object? notificationTime = _kSentinel`) — but that's a domain-entity change outside this module's scope.

**2.5 Const correctness — clean.**

Spot-checked: `const Icon(Icons.check)` (line 322, 331, 340, 368, 388, 397, 429), `const SizedBox` (multiple), `const _SettingsDivider()` (lines 97, 128, 156, 183, 188, 208, 218), `const EdgeInsets` everywhere. The lint `prefer_const_constructors` is on per CLAUDE.md and there are no obvious misses to flag.

**2.6 Accessibility — partial.**

- `Semantics(header: true, …)` on screen title (line 75) and section headers (line 751). Good.
- `_SettingsRow` wraps in `Semantics(label: semanticsLabel ?? label, button: true)` (line 853). Good.
- `_MetraToggle` uses `Semantics(toggled: value, excludeSemantics: true)` (line 698). Good.
- **Tap target audit**: `_SettingsRow` is `height: 56` (line 859). 56 dp ≥ 44 pt → meets WCAG 2.2 / Apple 44 pt. OK.
- `_MetraToggle` is `width: 48, height: 28` (line 705–706). **The visible touch target is 28 dp tall — below 44 pt**. Tapping the toggle directly fails the WCAG 2.5.5 / Apple HIG 44 pt minimum. The wrapping `_SettingsRow` (`height: 56`) absorbs the tap via `onTap` (settings_screen.dart:121–126, 151–154, 164–167), so practically the row is the hit target — but the bare `_MetraToggle` `GestureDetector` at line 701 has no padding to inflate its hit area. **Carry-over issue, not introduced by the rewrite, but worth noting since the rewrite touches the same section.**
- Picker `ListTile` widgets — relying on Flutter defaults. The default `ListTile` height is 56 dp (one-line). OK.
- **No `Semantics` on the bottom-sheet container itself** — VoiceOver/TalkBack will announce the first ListTile, not the sheet purpose. Carry-over issue.

**2.7 Localization completeness — IT/EN parity is correct for current strings.**

Both arb files have `settings_advance_label` and `settings_advance_value` (settings_advance_value uses ICU plural). The new feature needs: `settings_notification_time_label`, `settings_notification_time_value` (or display the localized formatted time directly via `MaterialLocalizations.formatTimeOfDay(time, alwaysUse24HourFormat: …)`). Italian primary, English mirror — that's the project rule (CLAUDE.md tech-stack table mentions IT primary, EN mirror).

#### 3. The picker invocation is a `static` method on a `ConsumerWidget` — consistent with the rest of the file but worth flagging.

`_showAdvancePicker` is `static void` (settings_screen.dart:409–442), called as a closure on `onTap`. Static methods avoid implicit `this`/state coupling, which is fine. The new time picker should follow the same shape (`static Future<void> _showTimePicker(...)` since `showTimePicker` returns `Future<TimeOfDay?>`).

### Affected files

- `/home/paolo/Sviluppo/metra/lib/features/settings/settings_screen.dart` — adds the new time row in the notifications `_GroupCard` (settings_screen.dart:108–138), adds a new picker method (~line 442 area), references new l10n keys. If extraction is in scope: split into per-section widgets and an `_OptionPickerSheet<T>` reusable.
- `/home/paolo/Sviluppo/metra/lib/features/settings/state/settings_notifier.dart` — no behavioural change required; the new field flows through `AppSettingsData.copyWith` automatically (settings_notifier.dart:48–52). But re-verify that `appSettingsStreamProvider` re-emits after the schema migration carries the new column.
- `/home/paolo/Sviluppo/metra/test/features/settings/settings_screen_test.dart` — new test groups: (a) advance picker now shows 14 options, scroll if needed; (b) time picker invocation, default state, persistence; (c) narrow viewport (360×640) regression for the longer advance list.
- `/home/paolo/Sviluppo/metra/test/features/settings/settings_notifier_test.dart` — round-trip the new field.

Out of this module's scope but the planner needs to track them (mentioned for completeness, do not assess here):
- `lib/domain/entities/app_settings_data.dart` — add the new field to constructor / copyWith / `==` / hashCode / `_AppSettingsDataDefaults`.
- `lib/data/database/app_database.dart` — new column + bump `schemaVersion` from 6 to 7, add migration step.
- `lib/data/repositories/drift_app_settings_repository.dart` — extend mapping in both directions (drift_app_settings_repository.dart:37, 51).
- `lib/l10n/app_it.arb`, `lib/l10n/app_en.arb` — new keys.
- `lib/domain/use_cases/schedule_prediction_notification.dart` — relax the `>= 1 && <= 7` assert to `<= 14`, replace the hardcoded 09:00 (which currently lives downstream in the platform notification service — verify) with `settings.notificationTime`.
- `lib/app.dart:104–183` — the `ref.listen` callbacks already pass `currentSettings` whole; nothing to change *unless* the body string also references the time, which it currently does not.

### Risks

- **R-1 — Bottom-sheet height clipping with 14 advance options on narrow viewports.** Already burned us once: qp-20260507-advance-picker-real-device-clipping.md added `isScrollControlled: true` to fix 7 ListTiles (~426 dp) on a 408 dp tall device. With 14 ListTiles (~14 × ~56 dp ≈ 784 dp) the sheet **must scroll** even on average viewports (640 dp tall device, after status / nav bars). The current `Column(mainAxisSize: MainAxisSize.min)` pattern (settings_screen.dart:422–440) does **not** scroll — the 7-item version barely fits. The rewrite will need either a `SingleChildScrollView` wrapper (loses the QP-20260507 `findsNothing` Scrollable invariant), `ListView.shrinkWrap`, or `DraggableScrollableSheet`. The combobox-glitch QP previously argued *against* `ListView.builder` because of its Android glow / iOS bounce affordance; that argument needs to be re-litigated now that scrolling is genuinely required, not an artefact. Plan to add an explicit narrow-viewport widget test (360×640) for the 14-item version, mirroring the test in qp-20260507-advance-picker-real-device-clipping.md §T-01.

- **R-2 — `TimeOfDay` localization & 24h vs 12h locale handling.** `showTimePicker` from Flutter uses `MaterialLocalizations.of(context).timeOfDayFormat()`. Italian defaults to 24h (HH:mm). English (US) defaults to 12h (h:mm a) — but the project supports `en` not `en_US`; the resolution depends on which `MaterialLocalizations` delegate matches. Display strings on the row also need `MaterialLocalizations.formatTimeOfDay(time, alwaysUse24HourFormat: …)` to format consistently with the picker. **Storing the raw `TimeOfDay` in the DB is unsafe** across locale changes — store as `int` (minutes since midnight, 0–1439) or `String 'HH:mm'` (locale-neutral) and only convert to `TimeOfDay` at the UI boundary. This also keeps the domain layer Flutter-free per CLAUDE.md §4.

- **R-3 — Picker UX: 14 options breaks the "no scroll affordance" invariant from qp-20260507-notification-days-combobox-glitch.md.** That QP replaced `ListView.builder` with `Column` *specifically* to remove the false scroll affordance. With 14 items the affordance is no longer false — it's necessary. The planner must update the §3.2 test invariant: `find.descendant(of: sheet, matching: find.byType(Scrollable)) findsNothing` (still on test/features/settings/settings_screen_test.dart per the plan) will fail by design after the rewrite. Either introduce a different picker pattern (compact wheel / two-column "1–14" + "08:00–10:00"?) or accept the scroll. **Ask the design team — don't invent a UX pattern. (CLAUDE.md §8 rule 5: "Ask before inventing".)**

- **R-4 — `app.dart:147–161` revert-on-permission-deny logic could fire spurious reschedule when only the time changes.** The `ref.listen` callback at app.dart:133–183 reschedules on **every** `AppSettingsData` change — including a pure time change while `notificationsEnabled: true`. That's correct behaviour (the user expects the next firing to use the new time), but the cancel+reschedule sequence has not been load-tested for back-to-back saves. If the user opens the time picker, picks 08:00, then immediately picks 09:00, two reschedules fire in quick succession against `flutter_local_notifications`. No known bug, but flagging because the rewrite increases the surface for this race.

- **R-5 — `notificationDaysBefore` range expansion 7 → 14 is a silent behaviour change for existing users.** Existing users have a value in `[1, 7]`; expanding the upper bound is forward-compatible (no migration needed). But if we ever shrink it again, existing rows in `[8, 14]` need clamping. Document the chosen direction explicitly.

### Tech debt

- **TD-1 — Magic number `7` for the advance-day max** (settings_screen.dart:425, schedule_prediction_notification.dart:36–40, plus implicit in arb plural). Lift to `AppConstants.kMaxAdvanceDays`. **Touch during this rewrite** — it's the field being changed, the constant is the natural seam.
- **TD-2 — Three duplicated picker bodies** (settings_screen.dart:303–406 plus 409–442). Extract `_OptionPickerSheet<T>` with `(label, isSelected, onTap)` rows. **Defer unless rewrite already extracts** — the time picker uses `showTimePicker`, not this list-picker shape, so the extraction wouldn't service the new feature.
- **TD-3 — `SettingsScreen.build()` is ~235 lines of inline tree.** Extract one `_NotificationsSection` widget at minimum (settings_screen.dart:108–138) — directly serves the rewrite by giving the new time row a focused home, and keeps the file under 1000 lines.
- **TD-4 — `_handleExport` / `_handleImport` are ~178 lines of side-effectful code on a `ConsumerWidget`** (settings_screen.dart:493–670). Belongs in a `CsvShareService` or use-case behind a provider. **Out of scope for this rewrite** — flag for a future refactor sprint.
- **TD-5 — `_MetraToggle` hit target is 28 dp tall, fails 44 pt minimum** (settings_screen.dart:705–706). The row absorbs the tap so functionally OK, but accessibility audits (TalkBack focus order, VoiceOver) should verify that the toggle widget itself is not exposed as a separate focusable node smaller than 44 pt. **Defer** — pre-existing issue, do not widen scope.
- **TD-6 — `SettingsNotifier.save` writes unconditionally even when `settings == state.value`** (settings_notifier.dart:48–52). For the rewrite this means a tap on the currently-selected option still triggers a Drift write *and* a `ref.listen` notification reschedule (app.dart:133–183). Cheap to add a `if (state.valueOrNull == settings) return;` guard. **Touch during this rewrite** — matches the spirit of "don't widen scope" but is one line and removes a real round trip.
- **TD-7 — Hardcoded 09:00** (referenced in `notification_prediction_body` plural but the actual hour lives downstream in the platform service — verify location during the rewrite). The whole point of the initiative; flagged for completeness.
