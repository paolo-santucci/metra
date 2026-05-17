# Assessment: Domain & Data Layer
## Feature: first-day-of-week-setting
## Date: 2026-05-10

---

## 1. New enum: `FirstDayOfWeekSetting`

**File to create**: `lib/domain/entities/first_day_of_week_setting.dart`

Three values:
```dart
enum FirstDayOfWeekSetting { system, sunday, monday }
```

- `system` (index 0) — delegate to `MaterialLocalizations.of(context).firstDayOfWeekIndex`
- `sunday` (index 1) — always Sunday-first (DateTime.sunday = 7)
- `monday` (index 2) — always Monday-first (DateTime.monday = 1)

Stored in DB as INT (enum.index). Default = 0 (system).

**System resolution** (happens at widget level, not domain level):
`MaterialLocalizations.firstDayOfWeekIndex` returns 0=Sunday, 1=Monday.
- idx == 0 → resolved = DateTime.sunday (7)
- idx == 1 → resolved = DateTime.monday (1)

---

## 2. `AppSettingsData` — `lib/domain/entities/app_settings_data.dart`

**Current state**: no `firstDayOfWeek` field.

**Required change**: add field `final FirstDayOfWeekSetting firstDayOfWeek;`

Default in `_AppSettingsDataDefaults` factory:
```dart
firstDayOfWeek: FirstDayOfWeekSetting.system,
```

`copyWith` addition:
```dart
FirstDayOfWeekSetting? firstDayOfWeek,
// in body:
firstDayOfWeek: firstDayOfWeek ?? this.firstDayOfWeek,
```

`==` and `hashCode` must include the new field (follow existing pattern).

---

## 3. DB schema — `lib/data/database/app_database.dart`

**Current**: `schemaVersion = 7`, `AppSettings` table has 11 columns.

**Required change**: increment to `schemaVersion = 8`, add column:
```dart
IntColumn get firstDayOfWeek => integer().withDefault(const Constant(0))();
```

Migration (append to existing switch/if chain):
```dart
if (from < 8) {
  await m.addColumn(appSettings, appSettings.firstDayOfWeek);
}
```

The `withDefault(const Constant(0))` makes the migration safe for existing rows (system = 0).

---

## 4. `DriftAppSettingsRepository` — `lib/data/repositories/drift_app_settings_repository.dart`

### `_fromRow` addition:
```dart
firstDayOfWeek: FirstDayOfWeekSetting.values[
  row.firstDayOfWeek.clamp(0, FirstDayOfWeekSetting.values.length - 1)
],
```
The `.clamp()` guard protects against out-of-range DB values (defensive).

### `_toCompanion` addition:
```dart
firstDayOfWeek: Value(data.firstDayOfWeek.index),
```

---

## 5. No DAO changes needed

`AppSettingsDao` uses `updateSettings(AppSettingsCompanion)` — Drift auto-generates access to the new column once it's in the table definition. No manual DAO changes.

---

## 6. Files in scope for this layer

| File | Action |
|------|--------|
| `lib/domain/entities/first_day_of_week_setting.dart` | CREATE |
| `lib/domain/entities/app_settings_data.dart` | MODIFY — add field, copyWith, ==/hashCode |
| `lib/data/database/app_database.dart` | MODIFY — new column, schemaVersion=8, migration from<8 |
| `lib/data/repositories/drift_app_settings_repository.dart` | MODIFY — _fromRow and _toCompanion |
