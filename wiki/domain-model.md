# Domain model

This document reflects the code as of commit `59c2a35`; all signatures were
verified against `lib/domain/`. The original task brief contained divergences
from the code — this document follows the code, not the brief.

The domain layer (`lib/domain/`) is pure Dart — no Flutter imports, no Drift
imports. It is fully testable in isolation.

## Table of contents

1. [Entities](#entities)
   - [DailyLogEntity](#dailylogentity)
   - [CycleEntryEntity](#cycleentryentity)
   - [CyclePrediction](#cycleprediction)
   - [AppSettingsData](#appsettingsdata)
   - [FlowType](#flowtype)
   - [FlowIntensity](#flowintensity)
   - [PainSymptomData + PainSymptomType](#painsymptomdata--painsymptomtype)
   - [Supporting entities](#supporting-entities)
2. [Repository interfaces](#repository-interfaces)
   - [DailyLogRepository](#dailylogrepository)
   - [CycleEntryRepository](#cycleentryrepository)
   - [AppSettingsRepository](#appsettingsrepository)
   - [SyncLogRepository](#synclogrepository)
3. [Use cases](#use-cases)
4. [Domain services](#domain-services)
   - [CyclePredictionService](#cyclepredictionservice)
   - [CsvCodec](#csvcodec)
   - [NotificationService](#notificationservice)

---

## Entities

### DailyLogEntity

One row per calendar day. Primary key: `date` (UTC midnight).

```dart
class DailyLogEntity {
  final DateTime date;           // UTC midnight; normalize before use
  final FlowType? flowType;      // null = user has not logged today
  final FlowIntensity? flowIntensity; // only meaningful when flowType == mestruazioni
  final bool otherDischarge;     // default false
  final bool painEnabled;        // default false
  final int? painIntensity;      // 0–3: none/mild/moderate/severe; null = not logged
  final bool notesEnabled;       // default false
  final String? notes;
}
```

**DM-02 invariant**: `flowIntensity` must be `null` unless
`flowType == FlowType.mestruazioni`. This is enforced by `SaveDailyLog` —
persisting a non-null intensity alongside any other flow type corrupts the model.

**Derived getter**: `bool get spotting => flowType == FlowType.spotting`
— retained for backward compatibility.

**`copyWith`** supports `clearFlowType`, `clearFlowIntensity`,
`clearPainIntensity`, and `clearNotes` boolean flags for setting fields to
`null` without Dart's optional-parameter limitations.

---

### CycleEntryEntity

Derived from `DailyLog` records; recomputed on every mutation by
`RecomputeCycleEntries`. The table is never written directly by UI code.

```dart
class CycleEntryEntity {
  final int id;                  // autoincrement; 0 is a placeholder for new entries
  final DateTime startDate;      // first flow day of this cycle (UTC midnight)
  final DateTime? endDate;       // last flow day; null if the cycle is ongoing
  final int? cycleLength;        // gap in days to the next cycle's startDate
  final int? periodLength;       // count of logged mestruazioni days (not calendar span)
}
```

The most-recent cycle always has `cycleLength = null` because the next cycle
has not started. `CyclePredictionService` anchors predictions on the
most-recent entry by `startDate` regardless of `cycleLength` nullability.

---

### CyclePrediction

Output of the WMA algorithm. Represents a 5-day uncertainty window.

```dart
class CyclePrediction {
  final DateTime windowStart;   // expectedStart - 2 days
  final DateTime windowEnd;     // expectedStart + 2 days
  final DateTime expectedStart; // WMA result, rounded to nearest day
  final int cyclesUsed;         // complete cycles used in WMA (3–6); 0 = estimated from declared length
}

bool containsDate(DateTime d); // true if d ∈ [windowStart, windowEnd] (inclusive)
```

`cyclesUsed == 0` signals that the prediction was derived from the
user-declared average cycle length rather than measured cycle gaps.

---

### AppSettingsData

Singleton settings row.

```dart
class AppSettingsData {
  final String languageCode;          // 'it' | 'en'
  final bool? darkMode;               // null = follow system
  final bool painEnabled;
  final bool notesEnabled;
  final int notificationDaysBefore;   // 1–7
  final bool notificationsEnabled;
  final String? dropboxEmail;         // connected Dropbox account, or null
  final DateTime? lastBackupAt;
  final bool onboardingCompleted;
  final int? declaredCycleLength;     // user-set during onboarding; fallback for prediction
}
```

**Defaults** (`AppSettingsData.defaults()`):
`languageCode='it'`, `darkMode=null`, `painEnabled=true`, `notesEnabled=true`,
`notificationDaysBefore=2`, `notificationsEnabled=false`,
`onboardingCompleted=false`, `declaredCycleLength=null`.

**`copyWith` omits `declaredCycleLength`** — it is always preserved from the
receiver unchanged, because it is updated exclusively via
`AppSettingsRepository.saveDeclaredCycleLength()` and must never be silently
reset to `null` by a general settings update.

---

### FlowType

```dart
enum FlowType { assente, mestruazioni, spotting }
// persisted as index: 0 | 1 | 2
```

Three mutually exclusive states for a logged day. `null` (an absent
`DailyLogEntity`) means the user has not logged the day at all.

---

### FlowIntensity

```dart
enum FlowIntensity { light, medium, heavy, veryHeavy }
// persisted as index: 0 | 1 | 2 | 3
```

Valid only when `flowType == FlowType.mestruazioni`. `veryHeavy` is retained
for backward compatibility with schema-v3 rows; the UI exposes only three
levels (light / medium / heavy) for new entries.

---

### PainSymptomData + PainSymptomType

Each symptom tag on a day is stored as a `PainSymptomData`:

```dart
class PainSymptomData {
  final PainSymptomType symptomType;
  final String? customLabel;   // non-null only when symptomType == PainSymptomType.custom
}
```

```dart
enum PainSymptomType {
  cramps,
  backPain,
  headache,
  migraine,
  bloating,
  custom,
  fatigue,
  nausea,
  breastTenderness,
}
```

Custom symptoms set `symptomType = PainSymptomType.custom` and populate
`customLabel`. All 9 values are persisted by index.

---

### Supporting entities

**`DailyLogWithSymptoms`** — container pairing a `DailyLogEntity` with
its `List<PainSymptomData>`. Used by `upsertAllLogs` and `BackupSnapshot` for
atomic import/restore operations.

```dart
class DailyLogWithSymptoms {
  final DailyLogEntity log;
  final List<PainSymptomData> symptoms;
}
```

**`CycleSummary`** — enriched view of one cycle for the Archive screen.

```dart
class CycleSummary {
  final CycleEntryEntity cycle;
  final List<PainSymptomData> symptoms;  // distinct across the cycle's date range
  final FlowIntensity? dominantFlow;     // modal; highest ordinal wins on ties
  final int? dominantPainIntensity;      // modal (1–3); highest value wins on ties
}
```

**`CycleStatsData`** — aggregated statistics for the Stats screen.

```dart
class CycleStatsData {
  final List<CycleDataPoint> points;     // chronological (oldest first)
  final int cycleLengthAvg;             // rounded mean
  final int cycleLengthMin;
  final int cycleLengthMax;
  final double? periodLengthAvg;
  final int? periodLengthMin;
  final int? periodLengthMax;
  final double? painIntensityAvg;
  final PainTrend? painTrend;            // null if fewer than 3 pain data points
  final int cyclesTrackedCount;
  final Map<PainSymptomType, int> symptomCounts; // all 8 fixed types always present
}
```

`PainTrend` is `increasing | stable | decreasing`, determined by comparing the
mean of the first half of cycle pain values against the second half (threshold
±0.3).

**`BackupSnapshot`** — serializable blob of all user data for cloud backup.
Current write version: 2. Reads accept both v1 and v2; writes always emit v2.
The v1→v2 migration (splitting `spotting` boolean + v3 flow index into
`flow_type` + v4 `flow_intensity`) is handled inside `BackupSnapshot._parseLog`.

**`SyncLogEntity`** — local audit record of a backup or restore operation.

```dart
class SyncLogEntity {
  final int? id;
  final DateTime timestamp;
  final SyncProvider provider;    // SyncProvider.dropbox (v1.1: googleDrive, oneDrive)
  final SyncOperation operation;  // backup | restore
  final bool success;
  final String? errorMessage;
}
```

---

## Repository interfaces

All in `lib/domain/repositories/`. Abstract classes — no Drift, no SQLite.

### DailyLogRepository

```dart
abstract class DailyLogRepository {
  Stream<DailyLogEntity?> watchDay(DateTime date);
  Stream<List<DailyLogEntity>> watchMonth(int year, int month);
  Future<List<DailyLogEntity>> getAllOrderedByDate();
  Future<void> saveDailyLog(DailyLogEntity log);
  Future<void> deleteDailyLog(DateTime date);
  Future<List<PainSymptomData>> getPainSymptoms(DateTime date);
  Future<Set<DateTime>> getSymptomDatesForMonth(int year, int month);
  Stream<Set<DateTime>> watchSymptomDatesForMonth(int year, int month);
  Future<void> replacePainSymptoms(DateTime date, List<PainSymptomData> symptoms);
  Future<void> deleteAll();
  Future<void> deleteAllAndReplace(
    List<DailyLogEntity> logs,
    Map<DateTime, List<PainSymptomData>> symptoms,
  );
  Future<void> upsertAllLogs(List<DailyLogWithSymptoms> entries);
}
```

`deleteAllAndReplace` is atomic — used by `ImportDailyLogs` in
`deleteAndImport` mode to guarantee no partial-state on write failure.
`upsertAllLogs` overwrites existing rows for the same date; rows absent from
the input are untouched.

---

### CycleEntryRepository

```dart
abstract class CycleEntryRepository {
  Stream<List<CycleEntryEntity>> watchAll();
  Future<List<CycleEntryEntity>> getRecent(int n);
  Future<CycleEntryEntity> insert(CycleEntryEntity entry);
  Future<void> update(CycleEntryEntity entry);
  Future<void> delete(int id);
  Future<void> replaceAll(List<CycleEntryEntity> entries);
  Future<void> deleteAll();
}
```

`replaceAll` replaces the entire table in a single transaction. It is called
only by `RecomputeCycleEntries`.

---

### AppSettingsRepository

```dart
abstract class AppSettingsRepository {
  Stream<AppSettingsData?> watchSettings();
  Future<AppSettingsData> getOrCreate();
  Future<void> updateSettings(AppSettingsData settings);
  Future<void> markOnboardingComplete();
  Future<void> updateBackupState({
    required String? dropboxEmail,
    required DateTime? lastBackupAt,
  });
  Future<void> saveDeclaredCycleLength(int cycleLength);
}
```

`updateBackupState` accepts explicit `null` to clear either field. Callers must
use this method — not `updateSettings` — because `AppSettingsData.copyWith`
cannot reset nullable fields to `null`.

---

### SyncLogRepository

```dart
abstract class SyncLogRepository {
  Future<void> append(SyncLogEntity log);
  Future<List<SyncLogEntity>> getRecent({int limit = 50});
  Future<void> deleteAll();
}
```

---

## Use cases

All in `lib/domain/use_cases/`.

| Class | Method | Signature | Description |
|---|---|---|---|
| `SaveDailyLog` | `call` | `(DailyLogEntity) → Future<Result<DailyLogEntity>>` | Enforces DM-02 invariant, the no-future-date rule, `painEnabled=true` requires non-null `painIntensity`, and `painIntensity ∈ [0, 3]`; normalizes `date` to UTC midnight before persisting |
| `RecomputeCycleEntries` | `call` | `() → Future<Result<List<CycleEntryEntity>>>` | Recomputes the cycle table from all `DailyLog` rows via `replaceAll`. Two bleeding episodes separated by ≥ 21 days (FIGO `_kNewCycleGapDays`) are treated as distinct cycles. Serialized with a Future-chain mutex. Also exposes `static compute(List<DailyLogEntity>)` for pure unit testing |
| `CompleteOnboarding` | `execute` | `({DateTime lastPeriodDate, int cycleLength, int periodLength}) → Future<void>` | Inserts an anchor `CycleEntryEntity`, saves `declaredCycleLength`, marks onboarding complete |
| `ComputeCycleStats` | `call` | `() → Stream<CycleStatsData?>` | Delegates to `GetCycleSummaries`; computes cycle-length stats, period-length stats, pain trend, and symptom counts |
| `GetCycleSummaries` | `call` | `() → Stream<List<CycleSummary>>` | Watches `CycleEntryRepository.watchAll()`, enriches each cycle with logs + symptoms; returns newest-first |
| `DeleteAllData` | `execute` | `() → Future<void>` | Deletes all logs and cycle entries; does not reset settings |
| `ExportDailyLogs` | `execute` | `() → Future<String>` | Fetches all logs + symptoms, computes cycle start dates via `RecomputeCycleEntries.compute`, encodes to CSV |
| `ImportDailyLogs` | `execute` | `({List<DailyLogRow> rows, ImportMode mode}) → Future<ImportResult>` | Applies rows according to `mode`; calls `RecomputeCycleEntries` after every mode |
| `WatchCyclePrediction` | `call` | `({int? declaredCycleLength}) → Stream<CyclePrediction?>` | Watches `CycleEntryRepository.watchAll()`, maps each emission through `CyclePredictionService.predict` |
| `BackupData` | `call` | `() → Future<Result<void>>` | Delegates to `BackupRunner.backup()`; the actual serialisation, encryption, and upload live in the data layer |
| `RestoreData` | `call` | `() → Future<Result<void>>` | Delegates to `BackupRunner.restore()` |
| `SchedulePredictionNotification` | `execute` | `({CyclePrediction? prediction, AppSettingsData settings, String title, String body}) → Future<void>` | Cancels any existing prediction notification; schedules a new one `notificationDaysBefore` days before `prediction.windowStart`. Skips silently if the calculated date is already past |

**`ImportMode`**:
- `deleteAndImport` — atomic: wipe all existing logs, insert new rows.
- `overwrite` — upsert: new rows replace existing rows with the same date; other rows are untouched.
- `keepExisting` — skip any row whose date already exists in the DB.

**`BackupRunner`** is a domain-layer abstract interface (`lib/domain/use_cases/backup_data.dart`) that keeps `BackupData` and `RestoreData` free of data-layer imports. The concrete implementation is `SyncOrchestrator` in `data/services/`.

**`SchedulePredictionNotification` — UTC/local note** (BUG-003): the notification
date is compared against today using local calendar dates, not raw `DateTime`
comparison. This avoids a UTC-midnight-vs-local-time mismatch that would
silently drop a same-day delivery in UTC+ timezones.

---

## Domain services

### CyclePredictionService

Pure, side-effect-free. No constructor dependencies.

```dart
class CyclePredictionService {
  CyclePrediction? predict(
    List<CycleEntryEntity> cycles, {
    int? declaredCycleLength,
  });
}
```

**Algorithm**:

1. Filter to complete cycles (`cycleLength != null`), sort ascending by
   `startDate`.
2. **Fallback path** (fewer than 3 complete cycles): if `declaredCycleLength`
   is set and at least one cycle exists, anchor on the most-recent
   `CycleEntryEntity` by `startDate`. Add `declaredCycleLength` days
   repeatedly until `expectedStart` is in the future (handles the case where
   the user opens the app weeks after onboarding). Returns a
   `CyclePrediction` with `cyclesUsed = 0`.
3. **WMA path** (3+ complete cycles): take the most recent min(n, 6) complete
   cycles. Weight `i+1` for the cycle at position `i` (oldest = 1, most
   recent = n). Compute `avg = weightedSum / weightTotal`.
4. Anchor on the most-recent `CycleEntryEntity` overall (by `startDate`),
   regardless of `cycleLength` nullability — decoupled from the WMA window so
   an in-progress cycle does not push the prediction into the past.
5. `expectedStart = anchor.startDate + avg.round() days`.
6. Return `CyclePrediction(windowStart: expectedStart - 2, windowEnd: expectedStart + 2, cyclesUsed: n)`.

**Tie-break**: `cycles.reduce((a, b) => b.startDate.isBefore(a.startDate) ? a : b)` — keeps the first-encountered entry when two entries share the same `startDate`.

Returns `null` when both the measured cycle count and `declaredCycleLength`
are insufficient (no cycles at all, or fewer than 3 complete and no declared
length set).

---

### CsvCodec

Encodes/decodes `DailyLogRow` lists to and from CSV. Located in
`lib/domain/services/csv_codec.dart`.

**Column order** (schema v4):
`date`, `flow_type`, `flow`, `pain_intensity`, `symptoms`, `notes`,
`cycle_start`

- `date`: `YYYY-MM-DD` (UTC).
- `flow_type`: `FlowType` index (0–2).
- `flow`: `FlowIntensity` index (0–3); empty unless `flow_type == 1`
  (mestruazioni). Defaults to `medium` on decode if the column is empty for a
  mestruazioni row.
- `symptoms`: semicolon-separated symptom names (`PainSymptomType.name`) or
  `custom:<label>` for custom symptoms.
- `cycle_start`: export-only; always ignored on decode.

The decoder also accepts legacy v3 CSVs that have a `spotting` boolean column
instead of `flow_type`, and a v3 `flow` index (0–4, where 0 = none). The
migration logic mirrors the v1→v2 `BackupSnapshot` path.

**`DailyLogRow`** — the type threaded through `ExportDailyLogs` and
`ImportDailyLogs`:

```dart
class DailyLogRow {
  final DailyLogEntity log;
  final List<PainSymptomData> symptoms;
  final bool cycleStart; // export-only; always false after decode
}
```

**`CsvDecodeResult`** — returned by `CsvCodec.decode`:

```dart
class CsvDecodeResult {
  final List<DailyLogRow> rows;
  final List<CsvParseError> errors;
}
```

Parse errors are per-row with `rowNumber`, `column`, `rawValue`, and `reason`.
Rows with errors are dropped; clean rows are returned alongside the error list.

---

### NotificationService

Abstract interface in `lib/domain/services/notification_service.dart`.
Concrete implementation: `FlutterNotificationService` in `data/services/`.

```dart
abstract class NotificationService {
  Future<void> initialize();
  Future<void> schedulePredictionNotification(
    DateTime notifyAt,
    String title,
    String body,
  );
  Future<void> cancelPredictionNotifications();
  Future<bool> requestPermission();
}
```

`initialize()` must be called once before any other method (typically from
`main()`). `schedulePredictionNotification` fires at 09:00 local time on the
date given by `notifyAt`; any previously scheduled prediction notification is
replaced via a stable notification ID. `requestPermission()` is relevant for
Android 13+ / API 33+; on iOS it returns `true` immediately because iOS
permissions are handled during `initialize()`.

<!-- author notes
Voice calibration: no VOICE.md or STYLEGUIDE.md in this repo; defaulted to
second-person-off (reference doc register), contractions off, formality 3/5,
dry and precise. Developer audience implies grade 10–12 reading level.
Sections: closely follows source code structure. 
Verification gaps: none — all signatures confirmed against source files.
Cuts: removed the appendix structure proposed in the brief; all verified
content inlined. Did not produce a BackupSnapshot section separate from
Supporting Entities since the decode logic lives entirely in the entity itself.
-->
