## Module: Persistence + Wiring

**Path**: `lib/data/database/`, `lib/data/repositories/`, `lib/domain/repositories/`, `lib/providers/`, `lib/app.dart`
**Agent**: code-reviewer

---

### Findings

#### 1. Backup compatibility — the premise in the brief is wrong (call this out)

The brief states: *"The new schema column will be in the encrypted SQLite blob."* **This is incorrect.** The Métra backup payload is **not** the SQLite database file — it is a JSON-encoded `BackupSnapshot` that is then AES-encrypted.

Evidence chain:

- `lib/data/services/backup/backup_service.dart:14-28` — `buildSnapshot()` only loads `DailyLog` rows + their `PainSymptom` rows. **AppSettings is never serialized into the snapshot.**
- `lib/data/services/backup/sync_orchestrator.dart:68-70`:
  ```dart
  final snapshot = await _backupService.buildSnapshot();
  final bytes = Uint8List.fromList(utf8.encode(snapshot.encode()));
  final blob = await _encryption.encrypt(bytes, passphrase);
  ```
  Backup blob = `AES(JSON(logs + symptoms))`.
- `sync_orchestrator.dart:87-88` only *writes back* `dropboxEmail` / `lastBackupAt` to AppSettings *after* a successful upload — settings are never *read into* the blob.
- `BackupSnapshot.currentVersion = 2` (`lib/domain/entities/backup_snapshot.dart:32`); restore decodes JSON (line 66) — never touches AppSettings.

**Implication**: the new `notificationTime` column has **zero backup-format impact**. Old backups restore unchanged; the new column is created on the local DB at migration time and uses its `withDefault(...)` for existing AppSettings rows. **No bump to `BackupSnapshot.currentVersion` is needed.** This is the single biggest risk-reducer for the rewrite — flag it before downstream work spends effort on a non-problem.

(Side note: settings being local-only — including the new time-of-day — is consistent with the local-first principle: notification preferences are per-device, not portable.)

---

#### 2. Drift schema — current AppSettings columns (in declaration order)

`lib/data/database/app_database.dart:87-108`:

| # | Column | Type | Default |
|---|---|---|---|
| 1 | `id` | `IntColumn` | autoIncrement (always 1 — singleton) |
| 2 | `languageCode` | `TextColumn` | `'it'` (overridden to `''` by `getOrCreateSettings`) |
| 3 | `darkMode` | `BoolColumn` | nullable, no default (null = follow system) |
| 4 | `painEnabled` | `BoolColumn` | `true` |
| 5 | `notesEnabled` | `BoolColumn` | `true` |
| 6 | `notificationDaysBefore` | `IntColumn` | `2` |
| 7 | `notificationsEnabled` | `BoolColumn` | `false` |
| 8 | `dropboxEmail` | `TextColumn` | nullable, no default |
| 9 | `lastBackupAt` | `DateTimeColumn` | nullable, no default |
| 10 | `onboardingCompleted` | `BoolColumn` | `false` |
| 11 | `declaredCycleLength` | `IntColumn` | nullable, no default |

**Schema version**: `6` — declared at `app_database.dart:141`: `int get schemaVersion => 6;`.

---

#### 3. Migration pattern — v5 is the clean precedent to copy

Migrations live **inside** `app_database.dart` as a step-migration chain in `MigrationStrategy.onUpgrade` (`app_database.dart:144-235`). There are no external migration files. The pattern:

```dart
onUpgrade: (m, from, to) async {
  if (from < 2) { ... }
  if (from < 3) { ... }
  ...
  if (from < 6) { ... }
}
```

The cleanest precedent for adding a defaulted scalar column to AppSettings is the `from < 5` block (`declaredCycleLength`):

```dart
if (from < 5) {
  // Strategy B: store user-declared average cycle length separately
  // from the measured gaps computed by RecomputeCycleEntries.
  await m.addColumn(
    appSettings,
    appSettings.declaredCycleLength,
  );
}
```

**Single `m.addColumn(...)` is sufficient. No `customStatement` is required for a defaulted scalar column** — Drift relies on the column's declared `withDefault(...)` to populate existing rows when the schema migrator runs `ALTER TABLE ADD COLUMN`. (Compare with `from < 4`, which uses `customStatement` only because it reshapes existing data, not because it adds a column.)

For the new `notificationTime`, the migration block becomes:

```dart
if (from < 7) {
  await m.addColumn(
    appSettings,
    appSettings.notificationTimeMinutes, // see #4 for column choice
  );
}
```

…and bump `schemaVersion` to `7`.

**Cold-start safety check**: `AppSettingsDao.getOrCreateSettings()` (`app_settings_dao.dart:36-46`) inserts with only `languageCode: Value('')`, relying on every other column's `withDefault` to populate. This means: **as long as the new column has `withDefault(Constant(540))` (or equivalent), `getOrCreate` keeps working unchanged on a brand-new DB**, and `m.addColumn` populates the singleton row on an upgraded DB. No code change to `getOrCreateSettings` required. This is the property that makes the "only one row, id=1" simplification work.

---

#### 4. Column type — single `IntColumn` of minutes-since-midnight (recommended)

Three options were considered. The recommendation, anchored in this codebase's patterns, is **one `IntColumn` storing minutes-since-midnight (0–1439), default `540` = 9×60**:

```dart
IntColumn get notificationTimeMinutes =>
    integer().withDefault(const Constant(540))();
```

Justification:

| Option | Verdict | Why |
|---|---|---|
| **Single `IntColumn` (minutes 0–1439), default 540** | **Recommended** | Matches `notificationDaysBefore` shape exactly. Atomic write/read. One range check (`0..1439`). Trivial `TimeOfDay` ↔ minutes helpers (4 lines each direction). `withDefault(540)` backfills existing rows for free. |
| Two `IntColumn` (hour 0–23, minute 0–59) | Acceptable, second-best | Doubles the surface area of `_fromRow`, `_toCompanion`, `copyWith`, `==`, `hashCode`. Two consistency invariants instead of one. Only attractive if a downstream layer wants direct `TimeOfDay(hour, minute)` field-by-field — but the conversion helper is cheap regardless. |
| `TextColumn "HH:mm"` | Reject | No precedent — every structured value in this schema is encoded as `IntColumn` (`FlowType.index`, `flowIntensity`, `symptomType`, `notificationDaysBefore`). Forces parse/format on every read. Validation per-row instead of at the boundary. |

The codebase pattern is unambiguous: enum/structured values → `IntColumn`. A TimeOfDay is structured-but-numeric; minutes-since-midnight collapses the 2-D structure into one well-ordered scalar.

**Backfill logic**: none — `withDefault(const Constant(540))` populates existing rows during `addColumn`. No `customStatement` needed.

---

#### 5. DAO + repository mapping

**`AppSettingsDao.watchSettings()`** (`app_settings_dao.dart:30-31`):

```dart
Stream<AppSetting?> watchSettings() =>
    (select(appSettings)..where((t) => t.id.equals(1))).watchSingleOrNull();
```

This handles row absence by emitting `null` — **it does NOT auto-create**. The `getOrCreate` semantics live in `getOrCreateSettings()` (separate method, transactional). Callers must call `getOrCreate` once at app boot if they need the row guaranteed to exist; otherwise the stream's first emission is `null`. The `appSettingsStreamProvider` (`repository_providers.dart:57-61`) correctly preserves this `null` semantic and relays it to `SettingsNotifier.build` (`settings_notifier.dart:36-46`), which falls back to `getOrCreate` when the stream has no value yet.

**`DriftAppSettingsRepository._fromRow`** (`drift_app_settings_repository.dart:32-43`) maps every column → entity field. Add the new field at the end:

```dart
notificationTimeMinutes: row.notificationTimeMinutes,
// or, if exposing as TimeOfDay-shaped value object:
notificationTime: NotificationTime.fromMinutes(row.notificationTimeMinutes),
```

**`DriftAppSettingsRepository._toCompanion`** (lines 45-53) maps the entity → companion for the **general settings update** path. The exclusion invariant is documented inline by what's *missing*: `dropboxEmail`, `lastBackupAt`, `onboardingCompleted`, `declaredCycleLength` are **deliberately not in `_toCompanion`** because they have dedicated writers (`updateBackupState`, `markOnboardingComplete`, `saveDeclaredCycleLength`) and would otherwise be clobbered by a general settings save. See also the comment in `AppSettingsData.copyWith` (`app_settings_data.dart:82-86`).

**The new `notificationTimeMinutes` belongs IN `_toCompanion` and IN `copyWith`**, alongside `notificationDaysBefore` and `notificationsEnabled` — it is a general settings field written by the settings screen via `SettingsNotifier.save`, not an out-of-band field. **No analogous exclusion protection is needed**; a single round-trip is safe and correct.

Concrete change to `_toCompanion`:

```dart
static AppSettingsCompanion _toCompanion(AppSettingsData data) =>
    AppSettingsCompanion(
      languageCode: Value(data.languageCode),
      darkMode: Value(data.darkMode),
      painEnabled: Value(data.painEnabled),
      notesEnabled: Value(data.notesEnabled),
      notificationDaysBefore: Value(data.notificationDaysBefore),
      notificationsEnabled: Value(data.notificationsEnabled),
      notificationTimeMinutes: Value(data.notificationTimeMinutes), // NEW
    );
```

`AppSettingsData` (`lib/domain/entities/app_settings_data.dart`) needs:

- New required `final int notificationTimeMinutes;` (or a small `NotificationTime` value object).
- Add to constructor (required, after `notificationsEnabled`).
- Add to `copyWith` (named, optional `int?`).
- Add to `==` and `hashCode`.
- Add to `_AppSettingsDataDefaults` with value `540`.

---

#### 6. Riverpod provider graph

`lib/providers/use_case_providers.dart:83-93`:

```dart
final notificationServiceProvider = Provider<NotificationService>(
  (_) => FlutterNotificationService(),
);

final schedulePredictionNotificationProvider =
    FutureProvider<SchedulePredictionNotification>(
  (ref) async {
    final notifService = ref.watch(notificationServiceProvider);
    return SchedulePredictionNotification(notifService);
  },
);
```

**Lifecycle**:
- `notificationServiceProvider` is a plain `Provider` (singleton, **not** `autoDispose`). Correct as-is. `FlutterNotificationService` holds a `FlutterLocalNotificationsPlugin` instance and is initialized exactly once via `initState` in `_MetraInnerState` (`app.dart:65-68`).
- `tz.initializeTimeZones()` and `_plugin.initialize()` are idempotent (timezone DB is a no-op on re-initialise; channel create is documented as no-op on re-creates — `notification_service.dart:74-83`). Hot-restart in dev rebuilds `ProviderScope` → re-runs `initState` → `.initialize()` re-runs → fine.
- Tests override `notificationServiceProvider` with a fake to avoid the platform channel; that pattern stays.

**Threading the new field**: **no provider needs to change**. The notification time travels through the existing `AppSettingsData` → `SettingsNotifier` → app-level listener → `scheduler.execute(settings: currentSettings, ...)` → use case path. The use case (`SchedulePredictionNotification.execute`, signature at `schedule_prediction_notification.dart:27-32`) already receives the entire `AppSettingsData`, so adding a field is a pure read on the consumer side — no new wiring.

(Out-of-scope-for-this-module note: the use case's hardcoded 09:00 — see Risks #2 — and the `NotificationService.schedulePredictionNotification` signature need to evolve to carry the time. Those are downstream changes for the orchestrator agent; **this module's wiring already supports them** because the entity flows through end-to-end.)

---

#### 7. App-level listeners (`lib/app.dart`)

##### 7a. Prediction listener (`app.dart:104-129`)

```dart
ref.listen<AsyncValue<CyclePrediction?>>(
  cyclePredictionProvider,
  (_, next) async {
    final prediction = next.valueOrNull;
    final currentSettings = ref.read(settingsNotifierProvider).valueOrNull;
    if (currentSettings == null) return;
    final l10n = await AppLocalizations.delegate
        .load(Locale(_effectiveLangCode(currentSettings.languageCode)));
    final scheduler =
        await ref.read(schedulePredictionNotificationProvider.future);
    try {
      await scheduler.execute(
        prediction: prediction,
        settings: currentSettings,
        title: l10n.notification_prediction_title,
        body: prediction != null
            ? l10n.notification_prediction_body(
                currentSettings.notificationDaysBefore,
              )
            : '',
      );
    } on PlatformException {
      // BUG-002: SCHEDULE_EXACT_ALARM revoked; silently no-op.
    }
  },
);
```

Fires when the predicted next cycle date changes. Reads the current settings via `ref.read` (one-shot). Does **not** fire on a settings change.

##### 7b. Settings listener (`app.dart:131-183`)

```dart
ref.listen<AsyncValue<AppSettingsData>>(
  settingsNotifierProvider,
  (prev, next) async {
    final currentSettings = next.valueOrNull;
    if (currentSettings == null) return;

    // BUG-002 fix: only request OS permission when the user explicitly
    // enables notifications (AsyncData → AsyncData transition). The
    // AsyncLoading → AsyncData cold-start transition must NOT trigger
    // requestPermission(); the previous state is not a user action.
    // Without this guard, a cold start with notificationsEnabled: true
    // and OS permission revoked would silently write notificationsEnabled:
    // false to the DB, destroying the user's persisted preference (FR-04,
    // FR-05, EC-05).
    if (prev is AsyncData<AppSettingsData>) {
      final wasEnabled = prev.value.notificationsEnabled;
      if (currentSettings.notificationsEnabled && !wasEnabled) {
        final granted =
            await ref.read(notificationServiceProvider).requestPermission();
        if (!granted) {
          // User denied the OS dialog — revert the toggle so the displayed
          // state matches reality (no notification will fire while denied).
          await ref.read(settingsNotifierProvider.notifier).save(
                currentSettings.copyWith(notificationsEnabled: false),
              );
          return;
        }
      }
    }

    final prediction = ref.read(cyclePredictionProvider).valueOrNull;
    final l10n = await AppLocalizations.delegate
        .load(Locale(_effectiveLangCode(currentSettings.languageCode)));
    final scheduler =
        await ref.read(schedulePredictionNotificationProvider.future);
    try {
      await scheduler.execute(
        prediction: prediction,
        settings: currentSettings,
        title: l10n.notification_prediction_title,
        body: prediction != null
            ? l10n.notification_prediction_body(
                currentSettings.notificationDaysBefore,
              )
            : '',
      );
    } on PlatformException {
      // BUG-002: SCHEDULE_EXACT_ALARM revoked; silently no-op.
    }
  },
);
```

##### 7c. BUG-002 guard — **must survive the rewrite**

The `if (prev is AsyncData<AppSettingsData>) { ... }` block (lines 147-161) is the BUG-002 fix. Its purpose:

- The settings notifier transitions `AsyncLoading → AsyncData` exactly once at cold-start. That transition is **not** a user action; the previous state was simply "not yet loaded."
- Without the type-narrowing guard, cold-start with `notificationsEnabled: true` and OS permission revoked (e.g. user revoked it from system Settings between sessions) would call `requestPermission()`, get `false` back, and silently flip the user's persisted preference to `false`.
- The guard ensures the permission re-prompt only happens on a genuine user-driven `false → true` toggle.

**Any rewrite touching this listener must preserve this guard verbatim.** The new `notificationTime` field does not interact with the guard's semantics — but if the rewrite restructures the listener body, the guard must be relocated, not removed. Add it to the regression test list.

##### 7d. Listener idempotency on time-of-day changes

When the user changes only `notificationTimeMinutes`:

- The prediction listener does **not** fire (it's keyed on `cyclePredictionProvider`).
- The settings listener fires **once**, calls `scheduler.execute(...)`.
- `SchedulePredictionNotification.execute` calls `cancelPredictionNotifications()` first (use case line 33), then schedules. Idempotent.

**No double-schedule risk on time-of-day change.** The only "double-fire" window is at cold-start when both providers may resolve in the same frame; cancel-then-schedule makes the last call win. Mitigated; no fix required.

##### 7e. Settings listener fires on every field — tech debt

Today, changing `languageCode`, `darkMode`, `painEnabled`, `notesEnabled` triggers a full reschedule (cancel + zonedSchedule). It's wasteful (extra platform-channel hop, AlarmManager churn on Android) but **not buggy** — `cancelPredictionNotifications` + `zonedSchedule` is idempotent.

**Recommendation**: during the rewrite, add a notification-relevance gate at the top of the settings listener:

```dart
final notifChanged = prev is! AsyncData<AppSettingsData> ||
    prev.value.notificationsEnabled != currentSettings.notificationsEnabled ||
    prev.value.notificationDaysBefore != currentSettings.notificationDaysBefore ||
    prev.value.notificationTimeMinutes != currentSettings.notificationTimeMinutes;
if (!notifChanged) return;
```

…placed **after** the BUG-002 permission-grant block, since that block must run on `notificationsEnabled` transitions (which the gate already includes). Classify as **Important tech debt** to address opportunistically inside this rewrite — the new field widens the notification-relevant set anyway, so this is the natural moment.

---

### Affected files

- `lib/data/database/app_database.dart` — add `notificationTimeMinutes` column to `AppSettings` table (line 87-108); add `from < 7` migration step (line 234); bump `schemaVersion` 6→7 (line 141).
- `lib/data/database/app_database.g.dart` — auto-regenerated by `dart run build_runner build`; never hand-edit.
- `lib/data/database/daos/app_settings_dao.dart` — **no changes**. `getOrCreateSettings` already relies on column defaults; `watchSettings` and `updateSettings` are field-agnostic.
- `lib/data/database/daos/app_settings_dao.g.dart` — auto-regenerated.
- `lib/data/repositories/drift_app_settings_repository.dart` — add field to `_fromRow` (line 32-43) and `_toCompanion` (line 45-53). No new method needed.
- `lib/domain/repositories/app_settings_repository.dart` — **no changes**. The new field flows through the existing `updateSettings` path.
- `lib/domain/entities/app_settings_data.dart` — add `notificationTimeMinutes` field to constructor, `copyWith`, `==`, `hashCode`, and `_AppSettingsDataDefaults` (default `540`).
- `lib/providers/use_case_providers.dart` — **no changes**.
- `lib/providers/repository_providers.dart` — **no changes**.
- `lib/app.dart` — preserve BUG-002 guard verbatim. Optionally add notification-relevance gate to settings listener (see Finding #7e); strictly tech debt, can be deferred.

**Out-of-scope for this module but flagged as cross-module dependencies** (orchestrator's call to assign to other agents):

- `lib/domain/use_cases/schedule_prediction_notification.dart:35-40` — `assert(notificationDaysBefore >= 1 && <= 7)` will fire on legal new values when the range widens to 1–14. Must be relaxed. Use case must also consume `settings.notificationTimeMinutes`.
- `lib/domain/services/notification_service.dart:33-37` — interface doc-string says "fires at 09:00 local time". Signature must be widened to accept time-of-day, or the use case must pass a fully-resolved `DateTime` (preferred — keeps the platform service free of policy).
- `lib/data/services/notification_service.dart:86-109` — `computeScheduledTz` hardcodes hour `9`; must accept the time from above.

---

### Risks

1. **Schema version bump (low risk, well-precedented).** Bumping `schemaVersion` 6→7 with a single `m.addColumn` and a column-level `withDefault(Constant(540))` mirrors the v5 migration exactly (declaredCycleLength). Backfill is automatic; no `customStatement` is required. Risk surface is bounded to: (a) forgetting to bump `schemaVersion`, (b) forgetting `withDefault` and getting NULLs in existing rows. Both are caught by an upgrade-from-v6 integration test.

2. **Out-of-scope `assert` will trip the new range (cross-module).** `SchedulePredictionNotification.execute` asserts `notificationDaysBefore` is in `[1, 7]`. The rewrite widens to 1–14. If the orchestrator schedules persistence work first and ships before the use-case work, debug builds will crash and release builds will silently fail the assertion's intent. Coordinate the use-case relaxation in the same PR or land it first.

3. **Listener double-fire at cold-start (mitigated).** Both listeners can fire in the same frame at cold-start (prediction first emission + settings first emission). `scheduler.execute` calls `cancelPredictionNotifications` → `zonedSchedule`, so last write wins idempotently. No fix needed; document for the test plan.

4. **Provider lifecycle on hot-restart (mitigated).** `notificationServiceProvider` is a singleton `Provider`. `tz.initializeTimeZones()`, `tz.setLocalLocation(...)`, `_plugin.initialize()`, and `createNotificationChannel(...)` are all idempotent or no-op on re-call. Hot-restart works.

5. **AppSettings is local-only (by design, not a risk).** AppSettings is **not** in the backup blob (`BackupSnapshot` carries logs+symptoms only). The new `notificationTime` is a per-device preference and stays local. **No backup format version bump needed.** This is the single most common false-alarm source for schema changes — explicitly noted to prevent wasted work.

---

### Tech debt

1. **Settings listener has no notification-relevance gate** (`app.dart:131-183`). Today every settings field change triggers `cancelPredictionNotifications` + `zonedSchedule` (a platform-channel round-trip on Android). Add a 5-line `if (!notifChanged) return;` guard immediately after the BUG-002 block. The new field is the natural prompt to address this. Flagged as **Important** — not blocking, but cheaper to do during this rewrite than later.

2. **`AppSettingsData.copyWith` deliberately omits some fields** (`declaredCycleLength`, `dropboxEmail`, `lastBackupAt`, `onboardingCompleted`). The pattern is documented but easy to misread — the absence of a parameter looks like a bug to a fresh reader. **Not a regression to fix** during this rewrite, but worth a one-line summary comment on the class header listing which fields go through dedicated writers vs. `copyWith`. Out-of-scope; recording for future cleanup.

3. **`_toCompanion` exclusion is implicit** (`drift_app_settings_repository.dart:45-53`). The exclusion is enforced by *which fields appear in the function*, not by an explicit list or test. Adding `notificationTimeMinutes` is safe (it belongs in the general path), but a future engineer adding another out-of-band field could accidentally include it. Consider promoting the exclusion to an explicit `// Excluded from general save: ...` comment block. Out-of-scope.
