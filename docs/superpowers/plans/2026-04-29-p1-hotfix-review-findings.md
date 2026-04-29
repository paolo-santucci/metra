# Métra — Sprint Plan: P-1 Hotfix — Code review findings

> **For agentic workers:** Use `superpowers:dispatching-parallel-agents` for Wave 1. Tracks A/B/C/D touch disjoint files and have no shared state — dispatch all four in parallel. Wave 2 is a sequential gate.

**Goal:** Fix three Critical findings from the P-1 code review (silent data loss, hardwired Italian locale, hardcoded UI strings) plus the actionable Important and Minor findings.

**Architecture:** No design changes. Each track is a localized fix to existing files. TDD where the change is non-trivial (Track A); refactor-first elsewhere.

**Source:** Review findings recorded in conversation transcript (2026-04-29) on branch `main` at `9b52e31`. Verdict: REQUEST CHANGES.

---

## What is already done (do not recreate)

- All P-1 source files exist and compile.
- `flutter test` and `flutter analyze` pass on `main` at HEAD.
- Test helpers (`FakeDailyLogRepository`, `FakeCycleEntryRepository`) are stable and do not need changes.

---

## Wave structure

```
Wave 1 (4 parallel agents — disjoint files):
  Track A — historical_entry_screen.dart       (C-1, I-1, I-2, I-4)
  Track B — calendar_screen.dart                (C-2, C-3, S-1, S-5)
  Track C — DAO refactor                        (I-3)
  Track D — small fixes                         (I-5, S-2, S-4)

Wave 2 (sequential gate):
  Track E — verification, build-number bump, tag
```

S-3 (`copyWith` cannot null-clear) is documented as a tracking note in Track E but **not implemented** — the reviewer flagged it as not urgent and the fix would require a sentinel-object refactor that is out of scope for a hotfix.

---

## Wave 1 — Tracks (parallel)

### Track A — `historical_entry_screen.dart` (C-1 + I-1 + I-2 + I-4)

**Owns:**
- `lib/features/daily_entry/historical_entry_screen.dart` (modify)
- `test/features/daily_entry/historical_entry_screen_test.dart` (create)

**Order is TDD:** write the failing round-trip test first, then fix.

#### Step A.1 — Write failing widget test (I-1)

Create `test/features/daily_entry/historical_entry_screen_test.dart`. Mirror the structure of `test/features/daily_entry/quick_entry_modal_test.dart`. Required test cases:

```dart
testWidgets('round-trip: existing log with otherDischarge=true preserves flag on save',
    (tester) async {
  // Seed FakeDailyLogRepository with a log that has otherDischarge: true.
  // Pump HistoricalEntryScreen for that date.
  // Tap save without modifying any field.
  // Assert: the saved log still has otherDischarge == true.
});

testWidgets('round-trip: pain section hidden when painEnabled toggled off and saved',
    (tester) async {
  // Seed log with painEnabled: true, painIntensity: 2.
  // Toggle painEnabled off.
  // Save.
  // Assert: saved log has painEnabled == false, painIntensity == null.
});

testWidgets('error state has Semantics liveRegion: true (I-4)', (tester) async {
  // Override dailyEntryProvider to return AsyncError.
  // Pump.
  // Find the error Text widget.
  // Assert it is wrapped by a Semantics widget with liveRegion: true.
});
```

Run `flutter test test/features/daily_entry/historical_entry_screen_test.dart` — expected: the first test FAILS (otherDischarge dropped); the third FAILS (no liveRegion).

#### Step A.2 — Fix C-1 (otherDischarge data loss)

In `_HistoricalEntryScreenState`:

1. Add field `bool _otherDischarge = false;` next to the other form-field declarations (around line 67).
2. In `_initFromLog` add `_otherDischarge = log.otherDischarge;` after the `_isSpotting` line (around line 96).
3. In `_buildEntity` add `otherDischarge: _otherDischarge,` to the `DailyLogEntity(...)` constructor (between `spotting` and `painEnabled`).

Re-run the round-trip test → it should PASS.

#### Step A.3 — Fix I-2 (side effects in build)

Replace the `whenData` calls inside `build()` with `ref.listenManual` set up in `initState`. Pattern:

```dart
@override
void initState() {
  super.initState();
  _notesController = TextEditingController();
  // Seed form once when first data arrives. fireImmediately handles the case
  // where the provider already has data (cache hit).
  ref.listenManual<AsyncValue<DailyLogEntity?>>(
    dailyEntryProvider(widget.date),
    (_, next) => next.whenData(_initFromLog),
    fireImmediately: true,
  );
  ref.listenManual<AsyncValue<List<PainSymptomData>>>(
    painSymptomsProvider(widget.date),
    (_, next) => next.whenData(_initSymptoms),
    fireImmediately: true,
  );
}
```

Then in `build()` remove the two `whenData(_initFromLog)` / `whenData(_initSymptoms)` lines and replace the `logAsync.when(...)` shape if it existed only to drive seeding (preserve the `loading` / `error` UI branches).

If `dailyEntryProvider` and `painSymptomsProvider` are not `family` providers in the actual code, adapt the type parameters accordingly — read the file before editing.

#### Step A.4 — Fix I-4 (live region on error state)

Find the `error: (_, __) => Center(child: Text(l10n.common_error_generic))` block in `historical_entry_screen.dart` (the loading path is already correct). Wrap the `Text` in `Semantics(liveRegion: true, ...)`:

```dart
error: (_, __) => Center(
  child: Semantics(
    liveRegion: true,
    child: Text(l10n.common_error_generic),
  ),
),
```

#### Step A.5 — Verify and commit

```bash
flutter test test/features/daily_entry/
flutter analyze lib/features/daily_entry/
```

Both must pass. Commit:

```
fix(daily-entry): preserve otherDischarge in HistoricalEntryScreen + a11y live region

C-1: HistoricalEntryScreen._initFromLog and _buildEntity now read/write
otherDischarge, fixing silent data loss when editing a log that had the flag set.
I-2: form-seeding side effects moved out of build() into ref.listenManual in
initState.
I-4: error state wrapped in Semantics(liveRegion: true) so screen readers
announce transition from loading to error.
I-1: adds historical_entry_screen_test.dart with round-trip coverage.
```

---

### Track B — `calendar_screen.dart` (C-2 + C-3 + S-1 + S-5)

**Owns:**
- `lib/features/calendar/calendar_screen.dart` (modify)
- `test/features/calendar/calendar_screen_test.dart` (modify if existing tests assume Italian month names)

#### Step B.1 — Fix C-2 (hardwired `'it'` locale)

Two call sites in `calendar_screen.dart`:

1. Line ~104 in `build()`:

```dart
// BEFORE
final monthName = intl.DateFormat.MMMM('it').format(
  DateTime(monthState.year, monthState.month),
);

// AFTER
final locale = Localizations.localeOf(context).toString();
final monthName = intl.DateFormat.MMMM(locale).format(
  DateTime(monthState.year, monthState.month),
);
```

2. Line ~231 in `_CalendarGrid._buildSemantics` (or wherever `DateFormat.yMMMMd('it')` appears):

```dart
// BEFORE
final dateStr = intl.DateFormat.yMMMMd('it').format(date);

// AFTER (locale must be threaded into _CalendarGrid — see B.2 below or pass
// from parent build())
final dateStr = intl.DateFormat.yMMMMd(locale).format(date);
```

Since `_CalendarGrid` is a child widget that does not receive `BuildContext` directly in `_buildSemantics`, add `final String locale` to its constructor and pass it from `CalendarScreen.build()`.

#### Step B.2 — Fix C-3 + S-5 (hardcoded day headers)

Replace the `static const List<String> _dayHeaders = ['L','M','M','G','V','S','D'];` with a build-time generator that uses the resolved locale:

```dart
List<String> _buildDayHeaders(String locale) {
  // 2024-01-01 is a Monday — generate Mon..Sun first-letter abbreviations.
  final fmt = intl.DateFormat.E(locale);
  return List.generate(7, (i) {
    final d = DateTime(2024, 1, i + 1);
    return fmt.format(d).substring(0, 1).toUpperCase();
  });
}
```

In `build()`:

```dart
final dayHeaders = _buildDayHeaders(locale);
// ...
_DayOfWeekHeader(labels: dayHeaders, isDark: isDark, textColor: textColor),
```

Delete the `static const _dayHeaders` block.

**Note on `intl` initialization:** `DateFormat.E('en')` and `DateFormat.E('it')` both work without explicit `initializeDateFormatting()` because `intl` ships those locales by default. If the user later picks a non-bundled locale, init would be needed in `main.dart`. Out of scope for this hotfix.

#### Step B.3 — Optional: extract `_buildSemantics` (S-1)

If `_CalendarGrid` is now > 150 lines after B.2 changes, extract `_buildSemantics` to a top-level helper:

```dart
String calendarDaySemanticsLabel({
  required DateTime date,
  required DailyLogEntity? log,
  required bool hasPrediction,
  required AppLocalizations l10n,
  required String locale,
}) { ... }
```

If the extraction adds risk without clear benefit, skip and leave a TODO referencing this plan. The reviewer flagged S-1 as a suggestion, not blocking.

#### Step B.4 — Update existing widget tests if they assume Italian

Run:

```bash
flutter test test/features/calendar/
```

If any test asserts a literal Italian month string (`'aprile'`, `'maggio'`, etc.) the test must either (a) set the test app's locale to `it` explicitly via `MaterialApp(locale: const Locale('it'))` if not already, or (b) be loosened to assert a regex. Most tests in this project already pin the locale to `it` for determinism — confirm by reading the test file.

#### Step B.5 — Verify and commit

```bash
flutter test test/features/calendar/
flutter analyze lib/features/calendar/
```

Commit:

```
fix(calendar): respect device locale for month names and day headers

C-2: replaces hardcoded DateFormat('it') with Localizations.localeOf(context),
fixing Italian month names being shown to English-locale users in both the
header and the screen-reader label.
C-3: removes hardcoded ['L','M','M','G','V','S','D'] day-header array; headers
now derive from DateFormat.E for the active locale.
S-5: static const _dayHeaders block removed.
```

---

### Track C — DAO refactor (I-3)

**Owns:**
- `lib/data/database/daos/daily_log_dao.dart` (modify)
- `lib/data/database/daos/cycle_entry_dao.dart` (modify)
- `lib/data/repositories/drift_daily_log_repository.dart` (modify)
- `lib/data/repositories/drift_cycle_entry_repository.dart` (modify)

#### Step C.1 — Move `getAllOrderedByDate` to `DailyLogDao`

Add to `daily_log_dao.dart` (inside the DAO class):

```dart
Future<List<DailyLog>> getAllOrderedByDate() =>
    (select(dailyLogs)..orderBy([(t) => OrderingTerm.asc(t.date)])).get();
```

Also add the corresponding `g.dart` regen if Drift code-gen is required (`dart run build_runner build --delete-conflicting-outputs`).

In `drift_daily_log_repository.dart`, replace the body of `getAllOrderedByDate`:

```dart
@override
Future<List<DailyLogEntity>> getAllOrderedByDate() async {
  final rows = await _dao.getAllOrderedByDate();
  return rows.map(_rowToEntity).toList();
}
```

Delete the inline `attachedDatabase` query and the "DAO is frozen" comment.

#### Step C.2 — Move `replaceAll` to `CycleEntryDao`

Read the current implementation in `drift_cycle_entry_repository.dart` `replaceAll`. Move the transaction body into a new method on `CycleEntryDao`:

```dart
Future<void> replaceAll(List<CycleEntriesCompanion> companions) =>
    transaction(() async {
      await delete(cycleEntries).go();
      await batch((b) => b.insertAll(cycleEntries, companions));
    });
```

In the repository:

```dart
@override
Future<void> replaceAll(List<CycleEntryEntity> entries) {
  final companions = entries.map(_entityToCompanion).toList();
  return _dao.replaceAll(companions);
}
```

#### Step C.3 — Verify and commit

```bash
flutter test test/data/
flutter analyze lib/data/
```

Commit:

```
refactor(data): move getAllOrderedByDate and replaceAll into DAOs (I-3)

Repositories now delegate query construction to the DAO layer instead of
reaching through `attachedDatabase`. Restores the DAO as the single
choke-point for SQL — DriftDailyLogRepository and DriftCycleEntryRepository
no longer build queries directly.
```

---

### Track D — Small fixes (I-5 + S-2 + S-4)

**Owns:**
- `lib/features/calendar/state/calendar_month_controller.dart` (modify) — I-5
- `lib/domain/use_cases/recompute_cycle_entries.dart` (modify) — S-2
- `lib/features/daily_entry/widgets/pain_intensity_slider.dart` (modify) — S-4

These three fixes are tiny and unrelated. One agent handles all three.

#### Step D.1 — Fix I-5 (swallowed errors in month navigation)

In `calendar_month_controller.dart`, find every `.then((s) { state = AsyncData(s); })` chain in `goToPrevMonth` and `goToNextMonth`. Add an `onError` callback:

```dart
_subscribeToMonth(year, month).then(
  (s) => state = AsyncData(s),
  onError: (Object e, StackTrace st) {
    state = AsyncError(e, st);
  },
);
```

Run the controller tests to confirm no regression:

```bash
flutter test test/features/calendar/state/
```

#### Step D.2 — Fix S-2 (`_CycleGroup` → record)

In `recompute_cycle_entries.dart`:

```dart
// BEFORE
class _CycleGroup {
  const _CycleGroup({required this.start, required this.end});
  final DateTime start;
  final DateTime end;
}

// AFTER
typedef _CycleGroup = ({DateTime start, DateTime end});
```

Update construction sites:
- `_CycleGroup(start: x, end: y)` → `(start: x, end: y)`

Field access `group.start` and `group.end` is unchanged for record types.

#### Step D.3 — Fix S-4 (dead default in PainIntensitySlider._label)

In `pain_intensity_slider.dart`, find the `_label` switch and remove the `default` case. The reviewer noted the input is clamped to 0–3 before the switch is called, so `default` is unreachable. If the lint requires exhaustiveness, replace `default` with an explicit `case 3` or use a switch expression.

#### Step D.4 — Verify and commit

```bash
flutter test
flutter analyze
```

Commit:

```
chore(p1-hotfix): error propagation, record refactor, dead-code removal

I-5: goToPrevMonth/goToNextMonth in CalendarMonthNotifier no longer swallow
errors from _subscribeToMonth; failures now surface as AsyncError.
S-2: replaces private _CycleGroup data class with a Dart 3 record in
RecomputeCycleEntries.
S-4: removes unreachable default case in PainIntensitySlider._label
(input is clamped 0–3 before the switch).
```

---

## Wave 2 — Track E (sequential gate)

**Owns:**
- `pubspec.yaml` (build-number bump)
- `docs/security/p1-hotfix-review-findings.md` (create — log of what was fixed)

#### Step E.1 — Full verification

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test --coverage
```

All three must exit 0. If `dart format` changes anything, it goes into a follow-up commit.

#### Step E.2 — Document S-3 as a known limitation

Add a one-paragraph note to `docs/security/p1-hotfix-review-findings.md`:

> **S-3 (deferred):** `DailyLogEntity.copyWith` cannot clear nullable fields back to `null` because of the standard `??` pattern. This is a known Dart limitation and not exploited by current callers. Revisit before the `copyWith` pattern proliferates — proposed fix is sentinel objects (e.g. `Object _sentinel`) per field, or a `copyWithClear({clearFlowIntensity: true, ...})` companion.

Also list the three Critical findings as RESOLVED with commit SHAs.

#### Step E.3 — Build-number bump (no new tag)

This is a hotfix to existing P-1 code that was tagged at `v0.1.0-p1`-era. Bump only the build number — no new phase tag is appropriate.

In `pubspec.yaml`:

```yaml
# BEFORE
version: 0.1.0-p5a+5
# AFTER
version: 0.1.0-p5a+6
```

Commit:

```
chore(release): P-1 hotfix review findings, bump build to 0.1.0-p5a+6

C-1, C-2, C-3 fixed; I-1..I-5 fixed; S-1, S-2, S-4, S-5 fixed; S-3 deferred
with documented justification.
```

#### Step E.4 — Push (only on user confirmation)

Do **not** push or tag without explicit user approval. Stop here and report back.

---

## Definition of Done

- [ ] All three Critical findings resolved (C-1, C-2, C-3) with test coverage proving the fix.
- [ ] All Important findings (I-1..I-5) addressed.
- [ ] Suggestions S-1 (or skipped with justification), S-2, S-4, S-5 addressed; S-3 documented as deferred.
- [ ] `dart format --set-exit-if-changed .` exits 0.
- [ ] `flutter analyze` exits 0.
- [ ] `flutter test` full suite exits 0.
- [ ] No new dependencies added.
- [ ] No layering violations introduced (`domain/` still has zero Drift/Flutter imports).
- [ ] `pubspec.yaml` build-number bumped to `0.1.0-p5a+6`.
- [ ] `docs/security/p1-hotfix-review-findings.md` lists each finding with status (RESOLVED + SHA, or DEFERRED + reason).

---

## Resolved decisions

- **No new tag.** This is a hotfix on existing P-1 code; build-number bump only. The next tag will be `v0.1.0-p6` after cloud sync ships.
- **S-3 deferred.** Sentinel-object refactor of `copyWith` is out of scope for a hotfix. Tracked in the security review doc.
- **Track A is TDD; Tracks B/C/D are refactor-first.** Track A has a real bug to lock in; the others are mechanical changes where test verification is sufficient.
- **Track ownership is by file, not by finding.** Each track has exclusive write access to its file set so parallel agents cannot collide.
