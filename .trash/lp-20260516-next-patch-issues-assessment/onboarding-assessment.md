# Module: Onboarding

**Path**: `lib/domain/use_cases/complete_onboarding.dart`, `lib/features/onboarding/`
**Agent**: bug-hunter

---

## Issue #28 — `CompleteOnboarding.execute` lacks a transactional wrapper — crash mid-execution produces duplicate anchor cycle entries

### Root cause

`CompleteOnboarding.execute` performs four sequential `await` calls with no rollback boundary:

```dart
// lib/domain/use_cases/complete_onboarding.dart:46–59
await _cycleRepo.insert(anchor);          // 1. writes CycleEntry
final logs = await _logRepo.getAllOrderedByDate();
final hasFlowLogs = logs.any((l) => ...);
if (hasFlowLogs) await _recompute();      // 2. optionally replaces CycleEntries
await _settingsRepo.saveDeclaredCycleLength(cycleLength); // 3. settings write
await _settingsRepo.markOnboardingComplete();             // 4. guard write
```

Step 1 inserts the anchor cycle entry unconditionally. Steps 3 and 4 are the only persistent markers that onboarding has completed. If the app crashes or is force-killed at any point between step 1 and step 4 (inclusive of step 4 failing), the next cold-start re-evaluates `onboardingCompleted == false` and re-displays the onboarding flow. The user can re-submit, producing a second anchor insert with the same `startDate`. After N forced-kill cycles, N anchor entries accumulate in `CycleEntries`.

**Crash window**: steps 1 → 4 run on the Dart UI isolate while `NativeDatabase.createInBackground` owns a background SQLite worker. The app can be killed by the OS during a background I/O flush at any await point.

**No-log branch is worse**: when `hasFlowLogs` is false (the common new-user case), `_recompute()` is skipped, so `CycleEntryRepository.replaceAll` never runs. The duplicate anchor is never cleaned up by a subsequent recompute. Each re-submission appends another entry; `WatchCyclePrediction` will then see multiple anchors on the same date and behave incorrectly (non-deterministic prediction start date).

**When `hasFlowLogs` is true**: `_recompute()` calls `_cycleRepo.replaceAll(entries)` which deletes all cycle entries and re-inserts only log-derived entries. So the anchor inserted at step 1 is wiped in the same recompute call — duplicates do not accumulate in this branch. The hazard is confined to the no-log branch.

### Affected files

| File | Lines | Role |
|---|---|---|
| `lib/domain/use_cases/complete_onboarding.dart` | 38–60 | Defective `execute` method — no transaction |
| `lib/data/database/daos/cycle_entry_dao.dart` | 38–39 | `insertCycleEntry` — no uniqueness guard on `startDate` |
| `lib/domain/repositories/cycle_entry_repository.dart` | 26 | `insert` interface — no upsert variant |
| `test/domain/use_cases/complete_onboarding_test.dart` | 29–153 | No crash/retry test; does not cover duplicate anchor scenario |

### Fix sketch

Two viable approaches under this codebase's strict `domain/ → data/` layering rule (domain must not import Drift):

**Option A — domain `TransactionRunner` interface (canonical for a "transactional wrapper" fix)**

Add `lib/domain/repositories/transaction_runner.dart`:
```dart
abstract class TransactionRunner {
  Future<T> run<T>(Future<T> Function() body);
}
```

Add `lib/data/repositories/drift_transaction_runner.dart`:
```dart
class DriftTransactionRunner implements TransactionRunner {
  const DriftTransactionRunner(this._db);
  final AppDatabase _db;
  @override
  Future<T> run<T>(Future<T> Function() body) => _db.transaction(body);
}
```

Inject into `CompleteOnboarding` as a 5th constructor argument and wrap steps 1+3+4 (or 1–4) inside `_txRunner.run(...)`. Wire in `use_case_providers.dart`. This is the minimal invasive fix and keeps the domain layer clean.

**Option B — idempotent insert (no new abstraction required)**

Add a `insertOrIgnoreByStartDate` method (or upsert-on-conflict) to `CycleEntryRepository` and its Drift implementation. Before inserting the anchor, check if a null-`cycleLength` entry already exists for `lastPeriodDate` and skip if so. This makes re-submission safe without a transaction but does not atomically bind the settings writes.

Option A is preferred because Option B does not prevent the settings calls from failing independently — a crash between a successful idempotent insert and `markOnboardingComplete` still leaves the user in a retry loop (though without accumulating extra entries after the first).

**Mandatory regression test**: add a test to `complete_onboarding_test.dart` that calls `execute` twice and asserts `cycleRepo.entries` has length 1 (not 2), simulating a re-entry after a partial failure.

---

## Issue #29 — `OnboardingNotifier.setDate` does not validate against future dates

### Root cause

`setDate` accepts any `DateTime` without validation:

```dart
// lib/features/onboarding/state/onboarding_notifier.dart:49
void setDate(DateTime date) => state = state.copyWith(lastPeriodDate: date);
```

The only guard in the flow is the date-picker's `lastDate: now` parameter set in `_DatePickerField._pickDate`:

```dart
// lib/features/onboarding/onboarding_screen.dart:476–484
final picked = await showDatePicker(
  context: context,
  firstDate: DateTime(2000),
  lastDate: now,                 // UI-only guard — bypassed if setDate called directly
  ...
);
if (picked != null) {
  onDateSelected(DateTime.utc(picked.year, picked.month, picked.day));
}
```

`lastDate: now` is a local `DateTime`. The value passed to `onDateSelected` (and thus `setDate`) is `DateTime.utc(picked.year, picked.month, picked.day)` — UTC midnight of the picked day. The picker prevents selecting a day after today, but the conversion to UTC midnight can produce a value marginally in the future relative to `DateTime.now().toUtc()` for users in UTC+ time zones near midnight.

More importantly, `setDate` is a public method on the notifier and is completely unguarded. Any caller — including tests or future screen code — can pass a tomorrow or next-year date. If called that way, a future `lastPeriodDate` is stored in state, `canSubmit` returns true (no additional check), and `CompleteOnboarding.execute` is invoked with a future `startDate`. That anchor date flows into `CyclePredictionService` as the reference point, producing a predicted "next period" that is in the past or malformed.

**UTC-midnight subtlety**: the naive fix `if (date.isAfter(DateTime.now().toUtc())) return;` would reject legitimate same-day picks by users in UTC+1 and later during the first hour of the local day, because the stored UTC midnight of "today" is up to UTC+offset hours ahead of the current UTC instant. The validation must compare calendar days in UTC, not instants:

```dart
void setDate(DateTime date) {
  final now = DateTime.now();
  final todayUtc = DateTime.utc(now.year, now.month, now.day);
  if (date.isAfter(todayUtc)) return;   // reject future calendar day (UTC)
  state = state.copyWith(lastPeriodDate: date);
}
```

This is identical in structure to the known `save_daily_log_test.dart` intermittent (see `STATUS.yaml` known-issues), which is caused by the same UTC-midnight pattern.

### Affected files

| File | Lines | Role |
|---|---|---|
| `lib/features/onboarding/state/onboarding_notifier.dart` | 49 | `setDate` — missing future-date guard |
| `lib/features/onboarding/onboarding_screen.dart` | 476–484 | `_pickDate` — `lastDate: now` is local, not UTC; relies on picker UI only |
| `test/features/onboarding/state/onboarding_notifier_test.dart` | 39–46 | `setDate` test does not include a future-date rejection case |

### Fix sketch

In `onboarding_notifier.dart`, guard `setDate` at the notifier boundary (defence in depth: the UI picker already constrains to today, but the notifier must not depend on the UI for correctness):

```dart
void setDate(DateTime date) {
  final now = DateTime.now();
  final todayUtc = DateTime.utc(now.year, now.month, now.day);
  if (date.isAfter(todayUtc)) return;   // silently ignore; UI cannot produce this
  state = state.copyWith(lastPeriodDate: date);
}
```

Add two test cases to `onboarding_notifier_test.dart`:
1. `setDate` with tomorrow → `lastPeriodDate` remains null.
2. `setDate` with today UTC midnight → `lastPeriodDate` is set (regression for the UTC+N near-midnight edge case).

---

## Risks

1. **Duplicate anchor corruption (Issue #28)** is a data-integrity risk affecting all new users on their first install if they encounter any crash or process kill between onboarding submit and the `markOnboardingComplete` write. On Android, OOM kills during DB flush on low-memory devices make this non-theoretical. On the no-log path (all new users), duplicate anchors are permanent and affect cycle prediction correctness indefinitely.

2. **Future-date anchor (Issue #29)** is a logic-correctness risk. The UI picker does constrain to today, so the exposure surface in production is: (a) the UTC+N near-midnight window where UTC midnight of the picked day is marginally ahead of the current UTC instant, or (b) a future caller of the public `setDate` API. Risk (a) is low-frequency but real; risk (b) is a maintenance risk that grows as the codebase evolves.

3. **Transaction option A** requires adding a new provider binding in `use_case_providers.dart` and wiring `DriftTransactionRunner`. This touches the provider graph at a point that is shared across features — test coverage of the wiring is mandatory.

---

## Tech debt

1. **Dead anchor insert on the `hasFlowLogs` branch** (`complete_onboarding.dart:46–54`): when `hasFlowLogs` is true, `_recompute()` immediately calls `_cycleRepo.replaceAll(entries)` which deletes the anchor just inserted. The insert is wasted work. The anchor should only be inserted when `!hasFlowLogs`, or the branch structure should be reorganised so the insert is conditional.

2. **`periodLength` from onboarding is discarded on the `hasFlowLogs` branch**: when `_recompute()` runs, it derives `periodLength` from `flowDayCount` of each log-derived group and calls `replaceAll`, wiping the user's declared `periodLength`. The onboarding answer is silently ignored. This is a product-level correctness question but is technically a silent data drop.

3. **No use-case boundary validation on `cycleLength`/`periodLength`**: only the UI clamps `cycleLength` to `[21, 45]` and `periodLength` to `[1, 8]`. `CompleteOnboarding.execute` passes these values unchecked to the DB. A non-UI caller (future automation, restore path, test) can write out-of-range values. A guard at the use-case boundary would close this.

4. **Test coverage gap**: `complete_onboarding_test.dart` has no test for the transaction/idempotency contract (double-execute should produce one anchor, not two). `onboarding_notifier_test.dart` has no future-date rejection test. Both are regressions waiting to be introduced.
