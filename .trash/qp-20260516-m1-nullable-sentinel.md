> **⚠ ARCHIVED — NOT current truth.** This document captured state at planning time. Current behavior may have diverged. Consult the current codebase or active spec docs.

# [QP] M1 — Nullable<T> sentinel: introduce wrapper and update `AppSettingsData.copyWith` to be sentinel-aware

**Date**: 2026-05-16
**Author**: sp-architect
**Status**: archived
**Archived-date**: 2026-05-16
**Estimated effort**: ≤2h total
**Origin**: LP `lp-20260516-next-patch-issues-plan.md` §6 Milestone 1; assessment `sp-20260516-m1-nullable-sentinel-assessment/consolidated-inputs.md`

<!-- Quick Plan: for implementations ≤2h effort and ≤6 tasks.
     If scope grows beyond this during planning, escalate to the canonical
     short-plan path (sp-spec + sp-plan). -->

---

## 1. Goal

Introduce a `Nullable<T>` sentinel wrapper in `lib/core/utils/nullable.dart` and change `AppSettingsData.copyWith`'s `darkMode` parameter from `bool?` to `Nullable<bool>?` so callers can express "set `darkMode` to null" distinctly from "leave `darkMode` unchanged", migrating the two existing light/dark `copyWith(darkMode: ...)` call-sites to the new syntax with zero behavior change.

---

## 2. Constraints

| ID | Constraint |
|----|-----------|
| C-01 | `lib/core/utils/nullable.dart` is pure Dart. No `package:flutter/*`, no `package:drift/*`, no `package:http/*` imports. Verified via `flutter analyze` (NFR-07 layering) and by reading the import block. |
| C-02 | `pubspec.yaml` is not modified. No new runtime dependency. (NFR-07) |
| C-03 | GPL-3.0 license header is present at the top of every new source file (`nullable.dart`). |
| C-04 | `darkMode` is the **only** `copyWith` parameter that changes type. All other `copyWith` parameters (`languageCode`, `painEnabled`, …) keep their current `T?` shape. |
| C-05 | The bare `AppSettingsData(...)` constructor in `_showThemePicker` (System-theme path, `lib/features/settings/settings_screen.dart` ~lines 421–429) is **out of scope for M1**. That call-site rewrite is M2 (#13 fix). M1 only migrates the two `copyWith(darkMode: bool)` call-sites (Light/Dark paths). |
| C-06 | After M1, no caller in `lib/` or `test/` passes a bare `bool` literal as `darkMode:` to `copyWith` — every call uses `const Nullable(true)` / `const Nullable(false)` / `const Nullable(null)` or omits the argument entirely. Verified by `flutter analyze` (would otherwise fail to compile) and by the new tests. |
| C-07 | The "set to null via `Nullable(null)`" regression test (MC-02 case 2) must fail on pre-fix `copyWith` and pass on post-fix code (FR-15 / NFR-08). |
| C-08 | Every commit in this plan ends with `dart format .` and `flutter analyze` clean. No intermediate broken-build state. |

---

## 3. Contract

### 3.1 Shared types / signatures

**Contract file**: `lib/core/utils/nullable.dart` (created as part of authoring this plan; T-01 owns subsequent maintenance, T-02 imports from it).

```dart
// lib/core/utils/nullable.dart  (full body — already written to source)
//
// GPL-3.0 header omitted from this excerpt for brevity; see the actual file.

/// Sentinel wrapper that distinguishes "do not change this field" from
/// "set this field to null" in `copyWith` signatures.
class Nullable<T> {
  const Nullable(this.value);
  final T? value;
}
```

**Consuming signature** in `lib/domain/entities/app_settings_data.dart` (T-02 owns):

```dart
AppSettingsData copyWith({
  String? languageCode,
  Nullable<bool>? darkMode,        // <-- changed from `bool? darkMode`
  bool? painEnabled,
  bool? notesEnabled,
  int? notificationDaysBefore,
  bool? notificationsEnabled,
  String? dropboxEmail,
  DateTime? lastBackupAt,
  bool? onboardingCompleted,
  int? notificationTimeMinutes,
  FirstDayOfWeekSetting? firstDayOfWeek,
}) {
  return AppSettingsData(
    languageCode: languageCode ?? this.languageCode,
    darkMode: darkMode != null ? darkMode.value : this.darkMode,  // <-- sentinel-aware
    painEnabled: painEnabled ?? this.painEnabled,
    notesEnabled: notesEnabled ?? this.notesEnabled,
    notificationDaysBefore: notificationDaysBefore ?? this.notificationDaysBefore,
    notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    dropboxEmail: dropboxEmail ?? this.dropboxEmail,
    lastBackupAt: lastBackupAt ?? this.lastBackupAt,
    onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    declaredCycleLength: declaredCycleLength,
    notificationTimeMinutes: notificationTimeMinutes ?? this.notificationTimeMinutes,
    firstDayOfWeek: firstDayOfWeek ?? this.firstDayOfWeek,
    lastLogOrSymptomWriteAt: lastLogOrSymptomWriteAt,
  );
}
```

**Semantics table** (the binding contract for T-02 tests):

| Caller expression | Resulting `darkMode` |
|-------------------|----------------------|
| `copyWith()` (argument omitted) | unchanged — `this.darkMode` |
| `copyWith(darkMode: const Nullable(true))` | `true` |
| `copyWith(darkMode: const Nullable(false))` | `false` |
| `copyWith(darkMode: const Nullable(null))` | `null` |

### 3.2 File boundaries

| Task | Owns (create/modify) | Reads (no modify) |
|------|---------------------|-------------------|
| T-01 | `lib/core/utils/nullable.dart` (already written by architect — T-01 verifies it exists, has GPL-3.0 header, and compiles); `test/core/utils/nullable_test.dart` (new) | — |
| T-02 | `lib/domain/entities/app_settings_data.dart` (copyWith signature + body, `darkMode` only); `lib/features/settings/settings_screen.dart` (Light/Dark `copyWith(darkMode: bool)` lines only — currently lines 439 and 448); `test/domain/entities/app_settings_data_test.dart` (line 470 caller migration + 3 new MC-02 cases); **any additional file in `lib/` or `test/` that contains a `copyWith(darkMode:` caller surfaced by `flutter analyze` after the signature change — purely syntactic migration to `const Nullable(true/false)`, no behavior change** | `lib/core/utils/nullable.dart` |

Zero file overlap between T-01 and T-02. The broadened third bullet in T-02's `Owns` is deliberate: the architect could not exhaustively grep the repo while authoring this plan, so the compile-time gate (`flutter analyze`) is the final authority on caller surface. Any expansion must be logged in §8 Plan Changes.

---

## 4. Tasks

### T-01 — `Nullable<T>` source + identity test `[serial; precedes T-02]`

**Agent**: general-purpose
**Owns**:
- `lib/core/utils/nullable.dart` — already written by the architect during plan authoring. T-01 verifies header, doc comment, and compilation.
- `test/core/utils/nullable_test.dart` — new file.

**Reads**: —
**Contract refs**: `Nullable<T>` class signature from §3.1.
**Tech context**: pure Dart value object (no Flutter, no Drift). Test harness uses `package:flutter_test/flutter_test.dart` for `expect`/`test` consistency with rest of suite.

**Failing test first** — **EXCEPTION** (see project memory `feedback_qp_refactor_no_failing_test.md`):
Per the QP-rules requirement that the architect write contract types into the source file as part of plan authoring (§3.1), `lib/core/utils/nullable.dart` already exists when T-01 begins. The TDD "failing-first" gate **cannot** apply to T-01 — the source is the contract delivery itself. The real failing-first regression test lives in T-02 (MC-02 Case 2 — `copyWith(darkMode: const Nullable(null))` returns `null`).

T-01 still adds a smoke test that documents the contract; it is expected to pass on first run:

```
// File: test/core/utils/nullable_test.dart
// (group: 'Nullable<T> contract')
//
// Test name: Nullable wraps a non-null value and exposes it via .value
// Setup: const wrapped = Nullable<bool>(false);
// Act:   final inner = wrapped.value;
// Assert: expect(inner, isFalse);
//
// Test name: Nullable wraps a null value and exposes null via .value
// Setup: const wrapped = Nullable<bool>(null);
// Act:   final inner = wrapped.value;
// Assert: expect(inner, isNull);
//
// Test name: Nullable supports const construction for use in copyWith literals
// Setup: const wrapped = Nullable<int>(0);
// Act:   // const construction itself is the property under test —
//        // if `const Nullable<int>(0)` did not compile, the file would not parse.
// Assert: expect(wrapped.value, 0);
```

Expected first-run state: all three tests pass. This is the documented exception, not a failing-first gate.

**Then implement**:
The `Nullable<T>` class body is already authored in `lib/core/utils/nullable.dart` (architect-written, per QP rules). T-01 only ensures the file is present, has the GPL-3.0 header, has a class-level doc comment naming it the project-standard pattern for nullable preference fields, and that `flutter analyze` reports zero issues for the file.

**Done when** (refactor-exception checklist — no failing-first gate per `feedback_qp_refactor_no_failing_test.md`):
- [x] `lib/core/utils/nullable.dart` exists, has GPL-3.0 header, has class-level doc comment matching the description in §3.1, and contains no imports of `package:flutter/*`, `package:drift/*`, or `package:http/*` (C-01).
- [x] Class signature matches §3.1 exactly (`class Nullable<T>`, `const Nullable(this.value)`, `final T? value`).
- [x] `test/core/utils/nullable_test.dart` exists with the three smoke tests above and they all pass on first run (`flutter test test/core/utils/nullable_test.dart`).
- [x] `flutter analyze` reports zero issues for both files.
- [x] `dart format .` reports zero diff for both files.
- [x] No files outside "Owns" are modified.
- [x] The real FR-01 regression gate (MC-02 Case 2 in T-02) is acknowledged as the failing-first carrier for this plan.

---

### T-02 — Sentinel-aware `copyWith` + caller migration + MC-02 tests `[serial; after T-01]`

**Agent**: general-purpose
**Owns**:
- `lib/domain/entities/app_settings_data.dart` — change `darkMode` parameter type and assignment in `copyWith` only.
- `lib/features/settings/settings_screen.dart` — migrate the two existing `copyWith(darkMode: bool)` call-sites (currently lines 439 and 448) to `const Nullable(false)` / `const Nullable(true)`. **Do not touch** the bare `AppSettingsData(...)` constructor in the System-theme path (~lines 421–429) — that is M2.
- `test/domain/entities/app_settings_data_test.dart` — migrate the existing `copyWith(darkMode: true)` caller at line 470; add the three MC-02 regression tests.
- **Any additional file in `lib/` or `test/` that `flutter analyze` flags after the signature change** because it passes a bare `bool` literal to `copyWith(darkMode: ...)`. Migration is purely syntactic: `bool` → `const Nullable(bool)`. No behavior change. Every such file added to the working set must be appended to §8 Plan Changes with a one-line note (`expanded T-02 Owns to include <path> — surfaced by analyzer`).

**Reads**: `lib/core/utils/nullable.dart`.
**Contract refs**: `Nullable<T>` from §3.1; `copyWith` signature + semantics table from §3.1.
**Tech context**: Dart domain entity refactor + companion test file extension. No Flutter widget code edited beyond the two `_save(...)` call-site lines in `settings_screen.dart` (no UI behavior change).

**Failing test first**:
```
// File: test/domain/entities/app_settings_data_test.dart
// Group: 'AppSettingsData copyWith — darkMode sentinel (FR-01, MC-02)'

// --- MC-02 Case 1: explicit non-null value via Nullable ---
// Test name: copyWith with Nullable(false) sets darkMode to false (Light theme path)
// Setup: final s = makeSettings(darkMode: null);
// Act:   final copy = s.copyWith(darkMode: const Nullable(false));
// Assert: expect(copy.darkMode, isFalse);

// --- MC-02 Case 2: explicit null via Nullable(null) — THE regression test for FR-01 ---
// Test name: copyWith with Nullable(null) resets darkMode to null (System theme path)
// Setup: final s = makeSettings(darkMode: true);
// Act:   final copy = s.copyWith(darkMode: const Nullable(null));
// Assert: expect(copy.darkMode, isNull);
// Note:  This test MUST fail on pre-fix code (current `??` pattern silently
//        ignores `null`) and pass on post-fix code. This is the FR-15
//        regression-test gate for FR-01.

// --- MC-02 Case 3: argument omitted leaves darkMode unchanged ---
// Test name: copyWith with darkMode omitted preserves current value
// Setup: final s = makeSettings(darkMode: true);
// Act:   final copy = s.copyWith(languageCode: 'en');  // touch an unrelated field
// Assert: expect(copy.darkMode, isTrue);

// --- Caller migration of pre-existing test (line 470) ---
// The existing test `'updates darkMode'` is updated in-place:
//   BEFORE: settings.copyWith(darkMode: true)
//   AFTER:  settings.copyWith(darkMode: const Nullable(true))
// Test name unchanged, assertion unchanged.
```

The three new tests fail to compile on pre-fix code (signature mismatch) — that is the failing-first state. After T-02's signature change + body change, they all pass; Case 2 is the regression check for FR-01.

**Then implement**:
1. In `lib/domain/entities/app_settings_data.dart`: change the `darkMode` parameter declaration in `copyWith` from `bool? darkMode` to `Nullable<bool>? darkMode`; change the corresponding body line from `darkMode: darkMode ?? this.darkMode,` to `darkMode: darkMode != null ? darkMode.value : this.darkMode,`. Add `import 'package:metra/core/utils/nullable.dart';` to the imports block. No other field touched.
2. In `lib/features/settings/settings_screen.dart`: replace `settings.copyWith(darkMode: false)` (Light path) with `settings.copyWith(darkMode: const Nullable(false))` and `settings.copyWith(darkMode: true)` (Dark path) with `settings.copyWith(darkMode: const Nullable(true))`. Add `import '../../core/utils/nullable.dart';`. Do **not** touch the `AppSettingsData(...)` bare-constructor block in the System path — M2 owns it.
3. In `test/domain/entities/app_settings_data_test.dart`: migrate the line-470 caller as above; add the three MC-02 cases to the `'AppSettingsData copyWith'` group; add `import 'package:metra/core/utils/nullable.dart';`.

**Done when**:
- [x] Failing tests (MC-02 Case 1/2/3) exist before the signature/body changes — verified by `flutter test test/domain/entities/app_settings_data_test.dart` showing the three new tests fail to compile or fail to assert.
- [x] After implementation, the three new tests pass; the migrated line-470 test passes; all other tests in `app_settings_data_test.dart` continue to pass.
- [x] Signature in `app_settings_data.dart` matches §3.1 exactly.
- [x] Semantics table from §3.1 holds — verified by Case 1 (value), Case 2 (null), Case 3 (omitted).
- [x] No bare `bool` literal is passed as `darkMode:` to `copyWith` anywhere in `lib/` or `test/` (compile-time guarantee from the new signature).
- [x] The bare `AppSettingsData(...)` constructor in `_showThemePicker` System-theme path is unchanged (M2 scope).
- [x] `flutter analyze` clean; `dart format .` clean.
- [x] No files outside "Owns" are modified (deviations logged in §8: additional callers within broadened Owns; trailing-comma fix in daily_log_repository_test.dart).

---

<!-- No integration task: T-01 and T-02 are serial, not parallel. The QP-template
     "integration task is MANDATORY when ≥2 parallel tasks exist" rule does not
     apply. T-02's MC-02 Case 2 test already exercises the full T-01 → T-02
     contract end-to-end (Nullable(null) → copyWith → darkMode is null). -->

---

## 5. Execution Order

```
┌────────────────────────────────────────────────────────────────┐
│  T-01  Nullable<T> source file + identity test                 │
│        (creates lib/core/utils/nullable.dart                   │
│         + test/core/utils/nullable_test.dart)                  │
└────────────────────────────┬───────────────────────────────────┘
                             │   serial — T-02 imports Nullable
                             ▼
┌────────────────────────────────────────────────────────────────┐
│  T-02  copyWith signature change + caller migration            │
│        + MC-02 regression tests                                │
│        (modifies app_settings_data.dart,                       │
│         settings_screen.dart, app_settings_data_test.dart)     │
└────────────────────────────────────────────────────────────────┘
```

Strictly sequential. No parallelism. No integration step (T-02 already exercises the T-01 contract through Case 2).

---

## 6. Verification

Run from `/home/paolo/Sviluppo/metra` after T-02 completes, before reporting done. Every command must exit 0.

1. **Format**: `dart format .`
   Expected: zero diff (or auto-fixes already committed).
2. **Lint**: `flutter analyze`
   Expected: `No issues found!`. A bare-`bool` `darkMode:` argument anywhere would fail here — that is the compile-time guarantee for C-06.
3. **Scoped tests (entity)**: `flutter test test/domain/entities/app_settings_data_test.dart`
   Expected: all pre-existing tests pass; the three new MC-02 cases pass; Case 2 is the FR-01 regression gate.
4. **Scoped tests (Nullable)**: `flutter test test/core/utils/nullable_test.dart`
   Expected: T-01's three identity tests pass.
5. **Full suite**: `flutter test`
   Expected: no regressions. The signature change is compile-time visible — any caller of `copyWith(darkMode: ...)` missed by T-02 would have failed step 2 already, but a green full suite is the final acceptance check.
6. **`pubspec.yaml` audit**: `git diff pubspec.yaml`
   Expected: zero diff (C-02 / NFR-07).

---

## 7. Preflight Checklist

- [x] §3.1 contract is complete — no TBDs. `Nullable<T>` body + new `copyWith` signature + semantics table are all spelled out.
- [x] §3.1 contract file path is specified (`lib/core/utils/nullable.dart`) and the file exists (architect wrote it during plan authoring).
- [x] §3.2 file boundaries have zero overlap between T-01 and T-02 (tasks are serial in any case; the boundary table is still strict).
- [x] Each task references its contract types explicitly (`Nullable<T>` and the §3.1 `copyWith` signature).
- [x] Failing tests are specified precisely enough for an agent to write them without guessing — test names, setup, act, assert, and the "must fail pre-fix / pass post-fix" gate for Case 2 are all named.
- [x] Integration task: **N/A** — T-01 and T-02 are serial; no parallel tasks exist. The QP-template rule fires only on ≥2 parallel tasks. T-02 Case 2 is the end-to-end contract test that an integration task would otherwise carry.

---

## 8. Plan Changes

<!-- Append-only. Any scope change during execution is logged here first. -->

<!-- - YYYY-MM-DD | T-XX | added/removed/changed | reason -->
- 2026-05-16 | T-02 | expanded T-02 Owns to include `test/data/repositories/app_settings_repository_test.dart` — surfaced by grep; caller `before.copyWith(darkMode: true)` at line 197 migrated to `const Nullable(true)`.
- 2026-05-16 | T-02 | expanded T-02 Owns to include additional caller in `test/domain/entities/app_settings_data_test.dart` at line 253 — `a.copyWith(darkMode: true)` migrated to `const Nullable(true)`; plan named only line 470, grep revealed this second caller.
- 2026-05-16 | T-02 | trailing comma lint fix in `test/data/repositories/daily_log_repository_test.dart` line 293–294 — pre-existing lint issue latently exposed when `dart format` reformatted the file; fixed to keep `flutter analyze` clean per C-08.

---

<!-- §9 Spec Impact — OMITTED.
     Rationale: this plan introduces a new internal type (`Nullable<T>`) and
     refines a private domain-entity method signature. It does not change
     user-visible behavior, public contracts, declared limits, or enumerated
     providers/dependencies. FR-01 in the parent LP-spec already declares the
     `Nullable<T>` pattern; M1 implements that requirement rather than
     producing a delta against it. Per `spec-impact-trigger.md` §3, the
     section is omitted entirely — leaving an empty block would invite
     fabricated deltas (premortem F4). -->
