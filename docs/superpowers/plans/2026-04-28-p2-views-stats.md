# P-2: Views + Stats Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement F-03 (vertical timeline), F-04 (dense table with segmented toggle), and F-05 (statistics with fl_chart) replacing the placeholder `TimelineScreen` and `StatsScreen`.

**Architecture:** New domain use cases (`GetCycleSummaries`, `ComputeCycleStats`) aggregate `CycleEntryRepository` + `DailyLogRepository` into value objects consumed by `AutoDisposeAsyncNotifier` controllers. Two feature trees — `lib/features/timeline/` and `lib/features/stats/` — each own their state and widgets; neither imports from the other. All new files carry the GPL-3.0 header.

**Tech Stack:** Flutter 3.x, Riverpod 2.x (hand-written providers, no riverpod_generator), fl_chart ^0.68.0, intl, AppLocalizations (gen_l10n), existing `MetraColors`/`MetraSpacing`/`MetraRadius`/`MetraMotion` tokens.

---

## File map

**New domain files:**
- `lib/domain/entities/cycle_summary.dart` — `CycleSummary` value object
- `lib/domain/entities/cycle_stats_data.dart` — `CycleStatsData` + `CycleDataPoint` value objects
- `lib/domain/use_cases/get_cycle_summaries.dart` — `GetCycleSummaries` use case
- `lib/domain/use_cases/compute_cycle_stats.dart` — `ComputeCycleStats` use case

**Modified:**
- `lib/providers/use_case_providers.dart` — add two new `FutureProvider`s
- `lib/l10n/app_it.arb` — add timeline/table/stats keys (template)
- `lib/l10n/app_en.arb` — matching EN translations

**New feature files:**
- `lib/features/timeline/state/timeline_controller.dart`
- `lib/features/timeline/widgets/timeline_card.dart`
- `lib/features/timeline/widgets/timeline_view.dart`
- `lib/features/timeline/widgets/table_view.dart`
- `lib/features/timeline/timeline_screen.dart` (replaces placeholder)
- `lib/features/stats/state/stats_controller.dart`
- `lib/features/stats/widgets/stat_card.dart`
- `lib/features/stats/widgets/cycle_length_chart.dart`
- `lib/features/stats/widgets/period_length_chart.dart`
- `lib/features/stats/widgets/symptom_frequency_chart.dart`
- `lib/features/stats/widgets/flow_intensity_chart.dart`
- `lib/features/stats/stats_screen.dart` (replaces placeholder)

**New test files:**
- `test/domain/use_cases/get_cycle_summaries_test.dart`
- `test/domain/use_cases/compute_cycle_stats_test.dart`
- `test/features/timeline/timeline_screen_test.dart`
- `test/features/stats/stats_screen_test.dart`

---

## Task 1 — Domain entities

**Files:**
- Create: `lib/domain/entities/cycle_summary.dart`
- Create: `lib/domain/entities/cycle_stats_data.dart`

- [ ] **Step 1: Create `cycle_summary.dart`**

```dart
// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
//
// Métra is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License,
// or (at your option) any later version.
//
// Métra is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Métra. If not, see <https://www.gnu.org/licenses/>.

import 'cycle_entry_entity.dart';
import 'flow_intensity.dart';
import 'pain_symptom_type.dart';

/// Aggregated view of one cycle entry enriched with symptom and flow data
/// sourced from the corresponding daily logs.
class CycleSummary {
  const CycleSummary({
    required this.cycle,
    required this.symptoms,
    this.dominantFlow,
  });

  final CycleEntryEntity cycle;

  /// Distinct fixed symptom types recorded on any day within this cycle's range.
  /// Never contains [PainSymptomType.custom].
  final List<PainSymptomType> symptoms;

  /// Most-frequent non-null [FlowIntensity] across the cycle's range.
  /// Highest ordinal wins on ties. Null when no flow was logged.
  final FlowIntensity? dominantFlow;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CycleSummary &&
          runtimeType == other.runtimeType &&
          cycle == other.cycle &&
          _listEquals(symptoms, other.symptoms) &&
          dominantFlow == other.dominantFlow;

  @override
  int get hashCode => cycle.hashCode ^ symptoms.hashCode ^ dominantFlow.hashCode;

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
```

- [ ] **Step 2: Create `cycle_stats_data.dart`**

```dart
// Copyright (C) 2026  Paolo Santucci
//
// [same license header as above]

import 'flow_intensity.dart';
import 'pain_symptom_type.dart';

/// One data point per complete cycle, used for chart rendering.
class CycleDataPoint {
  const CycleDataPoint({
    required this.startDate,
    required this.cycleLength,
    this.periodLength,
    this.dominantFlow,
  });

  /// UTC-midnight start date — used as X-axis label.
  final DateTime startDate;

  /// Total cycle length in days (always non-null: only complete cycles included).
  final int cycleLength;

  /// Flow period length in days; null if not recorded.
  final int? periodLength;

  /// Most-frequent non-null flow intensity in this cycle; null if none logged.
  final FlowIntensity? dominantFlow;
}

/// Aggregated statistics derived from all complete cycles.
/// Null means zero complete cycles — UI shows "Dati insufficienti".
class CycleStatsData {
  const CycleStatsData({
    required this.points,
    required this.symptomFrequencies,
  });

  /// One entry per complete cycle, oldest-first.
  final List<CycleDataPoint> points;

  /// Fraction [0.0–1.0] of complete cycles in which each fixed symptom type
  /// was recorded. All five fixed types are always present (value 0.0 if none).
  final Map<PainSymptomType, double> symptomFrequencies;
}
```

- [ ] **Step 3: Verify compile**

```bash
flutter analyze lib/domain/entities/cycle_summary.dart lib/domain/entities/cycle_stats_data.dart
```
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/domain/entities/cycle_summary.dart lib/domain/entities/cycle_stats_data.dart
git commit -m "feat(domain): add CycleSummary and CycleStatsData value objects"
```

---

## Task 2 — GetCycleSummaries use case (TDD)

**Files:**
- Create: `lib/domain/use_cases/get_cycle_summaries.dart`
- Create: `test/domain/use_cases/get_cycle_summaries_test.dart`

- [ ] **Step 1: Write the failing tests**

```dart
// test/domain/use_cases/get_cycle_summaries_test.dart
// Copyright (C) 2026  Paolo Santucci
// [license header]

import 'package:flutter_test/flutter_test.dart';
import 'package:metra/domain/entities/cycle_entry_entity.dart';
import 'package:metra/domain/entities/daily_log_entity.dart';
import 'package:metra/domain/entities/flow_intensity.dart';
import 'package:metra/domain/entities/pain_symptom_data.dart';
import 'package:metra/domain/entities/pain_symptom_type.dart';
import 'package:metra/domain/use_cases/get_cycle_summaries.dart';

import '../../helpers/fake_cycle_entry_repository.dart';
import '../../helpers/fake_daily_log_repository.dart';

void main() {
  final jan15 = DateTime.utc(2026, 1, 15);
  final jan20 = DateTime.utc(2026, 1, 20);
  final feb12 = DateTime.utc(2026, 2, 12);
  final feb17 = DateTime.utc(2026, 2, 17);

  group('GetCycleSummaries', () {
    test('returns empty list when no cycles', () async {
      final uc = GetCycleSummaries(
        FakeDailyLogRepository(),
        FakeCycleEntryRepository(),
      );
      expect(await uc().first, isEmpty);
    });

    test('returns one summary for one cycle with no logs', () async {
      final cycleRepo = FakeCycleEntryRepository();
      cycleRepo.entries.add(CycleEntryEntity(
        id: 1,
        startDate: jan15,
        endDate: jan20,
        cycleLength: 28,
        periodLength: 6,
      ));
      final uc = GetCycleSummaries(FakeDailyLogRepository(), cycleRepo);
      final result = await uc().first;
      expect(result, hasLength(1));
      expect(result.first.symptoms, isEmpty);
      expect(result.first.dominantFlow, isNull);
    });

    test('extracts distinct symptoms from logs in range', () async {
      final logRepo = FakeDailyLogRepository();
      final cycleRepo = FakeCycleEntryRepository();
      cycleRepo.entries.add(CycleEntryEntity(
        id: 1, startDate: jan15, endDate: jan20, cycleLength: 28, periodLength: 6,
      ));
      for (int d = 15; d <= 20; d++) {
        logRepo.savedLogs.add(DailyLogEntity(
          date: DateTime.utc(2026, 1, d),
          flowIntensity: FlowIntensity.medium,
        ));
      }
      logRepo.symptoms[jan15] = [PainSymptomData(symptomType: PainSymptomType.cramps)];
      logRepo.symptoms[jan16] = [PainSymptomData(symptomType: PainSymptomType.cramps)];
      logRepo.symptoms[jan17] = [PainSymptomData(symptomType: PainSymptomType.backPain)];

      final uc = GetCycleSummaries(logRepo, cycleRepo);
      final result = await uc().first;

      expect(result.first.symptoms, containsAll([PainSymptomType.cramps, PainSymptomType.backPain]));
      expect(result.first.symptoms, hasLength(2));
    });

    test('computes dominant flow as mode; highest ordinal wins on tie', () async {
      final logRepo = FakeDailyLogRepository();
      final cycleRepo = FakeCycleEntryRepository();
      cycleRepo.entries.add(CycleEntryEntity(
        id: 1, startDate: jan15, endDate: jan20, cycleLength: 28, periodLength: 6,
      ));
      // 2 × light, 2 × medium → tie → medium wins (higher ordinal)
      logRepo.savedLogs.addAll([
        DailyLogEntity(date: jan15, flowIntensity: FlowIntensity.light),
        DailyLogEntity(date: jan16, flowIntensity: FlowIntensity.light),
        DailyLogEntity(date: jan17, flowIntensity: FlowIntensity.medium),
        DailyLogEntity(date: jan18, flowIntensity: FlowIntensity.medium),
      ]);

      final uc = GetCycleSummaries(logRepo, cycleRepo);
      final result = await uc().first;
      expect(result.first.dominantFlow, FlowIntensity.medium);
    });

    test('sorts newest-first when multiple cycles', () async {
      final cycleRepo = FakeCycleEntryRepository();
      cycleRepo.entries.addAll([
        CycleEntryEntity(id: 1, startDate: jan15, endDate: jan20, cycleLength: 28, periodLength: 6),
        CycleEntryEntity(id: 2, startDate: feb12, endDate: feb17, cycleLength: null, periodLength: 6),
      ]);
      final uc = GetCycleSummaries(FakeDailyLogRepository(), cycleRepo);
      final result = await uc().first;
      expect(result.first.cycle.startDate, feb12);
      expect(result.last.cycle.startDate, jan15);
    });

    test('in-progress cycle (endDate null) included with today as upper bound', () async {
      final logRepo = FakeDailyLogRepository();
      final cycleRepo = FakeCycleEntryRepository();
      final today = DateTime.now().toUtc();
      final todayNorm = DateTime.utc(today.year, today.month, today.day);
      cycleRepo.entries.add(CycleEntryEntity(
        id: 1, startDate: todayNorm, endDate: null, cycleLength: null, periodLength: null,
      ));
      logRepo.savedLogs.add(DailyLogEntity(date: todayNorm, flowIntensity: FlowIntensity.heavy));

      final uc = GetCycleSummaries(logRepo, cycleRepo);
      final result = await uc().first;
      expect(result, hasLength(1));
      expect(result.first.dominantFlow, FlowIntensity.heavy);
    });

    test('does not include custom symptom type', () async {
      final logRepo = FakeDailyLogRepository();
      final cycleRepo = FakeCycleEntryRepository();
      cycleRepo.entries.add(CycleEntryEntity(
        id: 1, startDate: jan15, endDate: jan20, cycleLength: 28, periodLength: 6,
      ));
      logRepo.savedLogs.add(DailyLogEntity(date: jan15, flowIntensity: FlowIntensity.light));
      logRepo.symptoms[jan15] = [PainSymptomData(symptomType: PainSymptomType.custom, customLabel: 'nausea')];

      final uc = GetCycleSummaries(logRepo, cycleRepo);
      final result = await uc().first;
      expect(result.first.symptoms, isEmpty);
    });
  });
}

// Helpers used in this test file only.
final jan16 = DateTime.utc(2026, 1, 16);
final jan17 = DateTime.utc(2026, 1, 17);
final jan18 = DateTime.utc(2026, 1, 18);
```

- [ ] **Step 2: Run tests to see them fail**

```bash
flutter test test/domain/use_cases/get_cycle_summaries_test.dart --no-pub
```
Expected: compilation error — `GetCycleSummaries` not found.

- [ ] **Step 3: Implement `GetCycleSummaries`**

```dart
// lib/domain/use_cases/get_cycle_summaries.dart
// Copyright (C) 2026  Paolo Santucci
// [license header]

import '../entities/cycle_entry_entity.dart';
import '../entities/cycle_summary.dart';
import '../entities/flow_intensity.dart';
import '../entities/pain_symptom_type.dart';
import '../repositories/cycle_entry_repository.dart';
import '../repositories/daily_log_repository.dart';

class GetCycleSummaries {
  const GetCycleSummaries(this._logRepo, this._cycleRepo);

  final DailyLogRepository _logRepo;
  final CycleEntryRepository _cycleRepo;

  Stream<List<CycleSummary>> call() {
    return _cycleRepo.watchAll().asyncMap(_enrich);
  }

  Future<List<CycleSummary>> _enrich(List<CycleEntryEntity> cycles) async {
    if (cycles.isEmpty) return const [];

    final allLogs = await _logRepo.getAllOrderedByDate();

    final summaries = await Future.wait(cycles.map((cycle) async {
      final today = DateTime.now().toUtc();
      final todayNorm = DateTime.utc(today.year, today.month, today.day);
      final rangeEnd = cycle.endDate ?? todayNorm;

      final logsInRange = allLogs.where((l) =>
          !l.date.isBefore(cycle.startDate) && !l.date.isAfter(rangeEnd)).toList();

      // Collect distinct fixed symptom types.
      final symptomSet = <PainSymptomType>{};
      for (final log in logsInRange) {
        final symptoms = await _logRepo.getPainSymptoms(log.date);
        for (final s in symptoms) {
          if (s.symptomType != PainSymptomType.custom) {
            symptomSet.add(s.symptomType);
          }
        }
      }

      // Compute dominant flow; highest ordinal wins on tie.
      final flowCounts = <FlowIntensity, int>{};
      for (final log in logsInRange) {
        final fi = log.flowIntensity;
        if (fi != null && fi != FlowIntensity.none) {
          flowCounts[fi] = (flowCounts[fi] ?? 0) + 1;
        }
      }
      FlowIntensity? dominant;
      var maxCount = 0;
      for (final entry in flowCounts.entries) {
        if (entry.value > maxCount ||
            (entry.value == maxCount &&
                (dominant == null || entry.key.index > dominant.index))) {
          maxCount = entry.value;
          dominant = entry.key;
        }
      }

      return CycleSummary(
        cycle: cycle,
        symptoms: symptomSet.toList(),
        dominantFlow: dominant,
      );
    }));

    summaries.sort(
        (a, b) => b.cycle.startDate.compareTo(a.cycle.startDate));
    return summaries;
  }
}
```

- [ ] **Step 4: Run tests to verify pass**

```bash
flutter test test/domain/use_cases/get_cycle_summaries_test.dart --no-pub
```
Expected: all 6 tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/use_cases/get_cycle_summaries.dart \
        test/domain/use_cases/get_cycle_summaries_test.dart
git commit -m "feat(domain): add GetCycleSummaries use case"
```

---

## Task 3 — ComputeCycleStats use case (TDD)

**Files:**
- Create: `lib/domain/use_cases/compute_cycle_stats.dart`
- Create: `test/domain/use_cases/compute_cycle_stats_test.dart`

- [ ] **Step 1: Write the failing tests**

```dart
// test/domain/use_cases/compute_cycle_stats_test.dart
// Copyright (C) 2026  Paolo Santucci
// [license header]

import 'package:flutter_test/flutter_test.dart';
import 'package:metra/domain/entities/cycle_entry_entity.dart';
import 'package:metra/domain/entities/daily_log_entity.dart';
import 'package:metra/domain/entities/flow_intensity.dart';
import 'package:metra/domain/entities/pain_symptom_data.dart';
import 'package:metra/domain/entities/pain_symptom_type.dart';
import 'package:metra/domain/use_cases/compute_cycle_stats.dart';
import 'package:metra/domain/use_cases/get_cycle_summaries.dart';

import '../../helpers/fake_cycle_entry_repository.dart';
import '../../helpers/fake_daily_log_repository.dart';

GetCycleSummaries _makeGetCycleSummaries({
  List<CycleEntryEntity> cycles = const [],
}) {
  final cycleRepo = FakeCycleEntryRepository();
  cycleRepo.entries.addAll(cycles);
  return GetCycleSummaries(FakeDailyLogRepository(), cycleRepo);
}

void main() {
  group('ComputeCycleStats', () {
    test('returns null when no cycles', () async {
      final uc = ComputeCycleStats(_makeGetCycleSummaries());
      expect(await uc().first, isNull);
    });

    test('returns null when only in-progress cycle (no cycleLength)', () async {
      final uc = ComputeCycleStats(_makeGetCycleSummaries(cycles: [
        CycleEntryEntity(
          id: 1,
          startDate: DateTime.utc(2026, 4, 13),
          endDate: null,
          cycleLength: null,
          periodLength: null,
        ),
      ]));
      expect(await uc().first, isNull);
    });

    test('returns one data point for one complete cycle', () async {
      final uc = ComputeCycleStats(_makeGetCycleSummaries(cycles: [
        CycleEntryEntity(
          id: 1,
          startDate: DateTime.utc(2026, 1, 15),
          endDate: DateTime.utc(2026, 1, 20),
          cycleLength: 28,
          periodLength: 6,
        ),
      ]));
      final result = await uc().first;
      expect(result, isNotNull);
      expect(result!.points, hasLength(1));
      expect(result.points.first.cycleLength, 28);
      expect(result.points.first.periodLength, 6);
    });

    test('points are oldest-first', () async {
      final uc = ComputeCycleStats(_makeGetCycleSummaries(cycles: [
        CycleEntryEntity(id: 1, startDate: DateTime.utc(2026, 2, 12),
            endDate: DateTime.utc(2026, 2, 17), cycleLength: 28, periodLength: 6),
        CycleEntryEntity(id: 2, startDate: DateTime.utc(2026, 1, 15),
            endDate: DateTime.utc(2026, 1, 20), cycleLength: 28, periodLength: 6),
      ]));
      final result = await uc().first;
      expect(result!.points.first.startDate, DateTime.utc(2026, 1, 15));
      expect(result.points.last.startDate, DateTime.utc(2026, 2, 12));
    });

    test('excludes in-progress cycle from points', () async {
      final uc = ComputeCycleStats(_makeGetCycleSummaries(cycles: [
        CycleEntryEntity(id: 1, startDate: DateTime.utc(2026, 1, 15),
            endDate: DateTime.utc(2026, 1, 20), cycleLength: 28, periodLength: 6),
        CycleEntryEntity(id: 2, startDate: DateTime.utc(2026, 4, 13),
            endDate: null, cycleLength: null, periodLength: null),
      ]));
      final result = await uc().first;
      expect(result!.points, hasLength(1));
    });

    test('symptomFrequencies contains all 5 fixed types', () async {
      final uc = ComputeCycleStats(_makeGetCycleSummaries(cycles: [
        CycleEntryEntity(id: 1, startDate: DateTime.utc(2026, 1, 15),
            endDate: DateTime.utc(2026, 1, 20), cycleLength: 28, periodLength: 6),
      ]));
      final result = await uc().first;
      expect(result!.symptomFrequencies.keys, containsAll([
        PainSymptomType.cramps,
        PainSymptomType.backPain,
        PainSymptomType.headache,
        PainSymptomType.migraine,
        PainSymptomType.bloating,
      ]));
      expect(result.symptomFrequencies.containsKey(PainSymptomType.custom), isFalse);
    });

    test('symptom frequency is 1.0 when symptom present in all cycles', () async {
      final cycleRepo = FakeCycleEntryRepository();
      final logRepo = FakeDailyLogRepository();
      final start = DateTime.utc(2026, 1, 15);
      final end = DateTime.utc(2026, 1, 20);
      cycleRepo.entries.add(CycleEntryEntity(
          id: 1, startDate: start, endDate: end, cycleLength: 28, periodLength: 6));
      logRepo.savedLogs.add(DailyLogEntity(date: start, flowIntensity: FlowIntensity.medium));
      logRepo.symptoms[start] = [PainSymptomData(symptomType: PainSymptomType.cramps)];

      final uc = ComputeCycleStats(GetCycleSummaries(logRepo, cycleRepo));
      final result = await uc().first;
      expect(result!.symptomFrequencies[PainSymptomType.cramps], 1.0);
    });
  });
}
```

- [ ] **Step 2: Run tests to see them fail**

```bash
flutter test test/domain/use_cases/compute_cycle_stats_test.dart --no-pub
```
Expected: compilation error — `ComputeCycleStats` not found.

- [ ] **Step 3: Implement `ComputeCycleStats`**

```dart
// lib/domain/use_cases/compute_cycle_stats.dart
// Copyright (C) 2026  Paolo Santucci
// [license header]

import '../entities/cycle_stats_data.dart';
import '../entities/cycle_summary.dart';
import '../entities/pain_symptom_type.dart';
import 'get_cycle_summaries.dart';

class ComputeCycleStats {
  const ComputeCycleStats(this._getCycleSummaries);

  final GetCycleSummaries _getCycleSummaries;

  Stream<CycleStatsData?> call() => _getCycleSummaries().map(_compute);

  static CycleStatsData? _compute(List<CycleSummary> summaries) {
    final complete = summaries
        .where((s) => s.cycle.endDate != null && s.cycle.cycleLength != null)
        .toList();
    if (complete.isEmpty) return null;

    // Points: oldest-first (summaries arrive newest-first).
    final points = complete.reversed
        .map((s) => CycleDataPoint(
              startDate: s.cycle.startDate,
              cycleLength: s.cycle.cycleLength!,
              periodLength: s.cycle.periodLength,
              dominantFlow: s.dominantFlow,
            ))
        .toList();

    // Frequencies: for each of the 5 fixed types, fraction of complete cycles.
    const fixedTypes = [
      PainSymptomType.cramps,
      PainSymptomType.backPain,
      PainSymptomType.headache,
      PainSymptomType.migraine,
      PainSymptomType.bloating,
    ];
    final frequencies = <PainSymptomType, double>{
      for (final type in fixedTypes)
        type: complete.where((s) => s.symptoms.contains(type)).length /
            complete.length,
    };

    return CycleStatsData(points: points, symptomFrequencies: frequencies);
  }
}
```

- [ ] **Step 4: Run tests to verify pass**

```bash
flutter test test/domain/use_cases/compute_cycle_stats_test.dart --no-pub
```
Expected: all 7 tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/use_cases/compute_cycle_stats.dart \
        test/domain/use_cases/compute_cycle_stats_test.dart
git commit -m "feat(domain): add ComputeCycleStats use case"
```

---

## Task 4 — Providers

**Files:**
- Modify: `lib/providers/use_case_providers.dart`

- [ ] **Step 1: Add two providers at the end of the file**

Append to `lib/providers/use_case_providers.dart` (after the existing `recomputeCycleEntriesProvider`):

```dart
import '../domain/use_cases/compute_cycle_stats.dart';
import '../domain/use_cases/get_cycle_summaries.dart';

// Add these imports at the top of the file with the others:
// import '../domain/use_cases/get_cycle_summaries.dart';
// import '../domain/use_cases/compute_cycle_stats.dart';

final getCycleSummariesProvider = FutureProvider<GetCycleSummaries>((ref) async {
  final logRepo = await ref.watch(dailyLogRepositoryProvider.future);
  final cycleRepo = await ref.watch(cycleEntryRepositoryProvider.future);
  return GetCycleSummaries(logRepo, cycleRepo);
});

final computeCycleStatsProvider = FutureProvider<ComputeCycleStats>((ref) async {
  final getCycleSummaries = await ref.watch(getCycleSummariesProvider.future);
  return ComputeCycleStats(getCycleSummaries);
});
```

The full updated `use_case_providers.dart`:

```dart
// Copyright (C) 2026  Paolo Santucci
// [license header]

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/use_cases/compute_cycle_stats.dart';
import '../domain/use_cases/get_cycle_summaries.dart';
import '../domain/use_cases/get_month_logs.dart';
import '../domain/use_cases/recompute_cycle_entries.dart';
import '../domain/use_cases/save_daily_log.dart';
import 'repository_providers.dart';

final saveDailyLogProvider = FutureProvider<SaveDailyLog>((ref) async {
  final repo = await ref.watch(dailyLogRepositoryProvider.future);
  return SaveDailyLog(repo);
});

final getMonthLogsProvider = FutureProvider<GetMonthLogs>((ref) async {
  final repo = await ref.watch(dailyLogRepositoryProvider.future);
  return GetMonthLogs(repo);
});

final recomputeCycleEntriesProvider = FutureProvider<RecomputeCycleEntries>((
  ref,
) async {
  final logRepo = await ref.watch(dailyLogRepositoryProvider.future);
  final cycleRepo = await ref.watch(cycleEntryRepositoryProvider.future);
  return RecomputeCycleEntries(logRepo, cycleRepo);
});

final getCycleSummariesProvider = FutureProvider<GetCycleSummaries>((ref) async {
  final logRepo = await ref.watch(dailyLogRepositoryProvider.future);
  final cycleRepo = await ref.watch(cycleEntryRepositoryProvider.future);
  return GetCycleSummaries(logRepo, cycleRepo);
});

final computeCycleStatsProvider = FutureProvider<ComputeCycleStats>((ref) async {
  final getCycleSummaries = await ref.watch(getCycleSummariesProvider.future);
  return ComputeCycleStats(getCycleSummaries);
});
```

- [ ] **Step 2: Verify compile**

```bash
flutter analyze lib/providers/use_case_providers.dart
```
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/providers/use_case_providers.dart
git commit -m "feat(providers): register getCycleSummaries and computeCycleStats providers"
```

---

## Task 5 — L10n strings

**Files:**
- Modify: `lib/l10n/app_it.arb`
- Modify: `lib/l10n/app_en.arb`

- [ ] **Step 1: Add keys to `app_it.arb`** (before the final `}`)

Insert before the closing `}` of `app_it.arb`:

```json
  ,

  "timeline_empty_hint": "Registra il tuo primo ciclo per vedere la timeline",
  "@timeline_empty_hint": {
    "description": "Empty-state hint on the timeline and table views"
  },

  "timeline_cycle_in_progress": "In corso",
  "@timeline_cycle_in_progress": {
    "description": "Badge on the current (in-progress) cycle card"
  },

  "timeline_cycle_length_days": "{n} g",
  "@timeline_cycle_length_days": {
    "description": "Cycle length label on a timeline card, e.g. '28 g'",
    "placeholders": {
      "n": { "type": "int" }
    }
  },

  "timeline_card_a11y": "Ciclo dal {start} al {end}, {n} giorni",
  "@timeline_card_a11y": {
    "description": "Accessibility label for a timeline card",
    "placeholders": {
      "start": { "type": "String", "example": "15 gen 2026" },
      "end":   { "type": "String", "example": "20 gen 2026" },
      "n":     { "type": "int" }
    }
  },

  "timeline_card_a11y_in_progress": "Ciclo dal {start}, in corso",
  "@timeline_card_a11y_in_progress": {
    "description": "Accessibility label for an in-progress cycle card",
    "placeholders": {
      "start": { "type": "String", "example": "13 apr 2026" }
    }
  },

  "table_col_start": "Inizio",
  "@table_col_start": { "description": "Table column header: start date" },

  "table_col_cycle": "Ciclo",
  "@table_col_cycle": { "description": "Table column header: cycle length" },

  "table_col_period": "Mestr.",
  "@table_col_period": { "description": "Table column header: period length" },

  "table_col_symptoms": "Sintomi",
  "@table_col_symptoms": { "description": "Table column header: symptoms" },

  "table_cycle_dash": "—",
  "@table_cycle_dash": { "description": "Placeholder shown when cycle length is unknown" },

  "stats_cycle_length_title": "Lunghezza ciclo",
  "@stats_cycle_length_title": { "description": "Stat card title: cycle length chart" },

  "stats_period_length_title": "Durata mestruazione",
  "@stats_period_length_title": { "description": "Stat card title: period length chart" },

  "stats_symptoms_title": "Sintomi frequenti",
  "@stats_symptoms_title": { "description": "Stat card title: symptom frequency chart" },

  "stats_flow_title": "Intensità flusso",
  "@stats_flow_title": { "description": "Stat card title: flow intensity chart" },

  "stats_insufficient_data": "Dati insufficienti",
  "@stats_insufficient_data": { "description": "Shown inside a stat card when there are no complete cycles" },

  "stats_cycle_length_avg": "{n} g in media",
  "@stats_cycle_length_avg": {
    "description": "Average cycle length label below the cycle-length chart",
    "placeholders": { "n": { "type": "int" } }
  },

  "stats_period_length_avg": "{n} g in media",
  "@stats_period_length_avg": {
    "description": "Average period length label below the period-length chart",
    "placeholders": { "n": { "type": "int" } }
  },

  "timeline_view_toggle": "Timeline",
  "@timeline_view_toggle": { "description": "Segmented control label for timeline view" },

  "table_view_toggle": "Tabella",
  "@table_view_toggle": { "description": "Segmented control label for table view" }
```

- [ ] **Step 2: Add matching keys to `app_en.arb`** (before the final `}`)

```json
  ,
  "timeline_empty_hint": "Log your first cycle to see the timeline",
  "timeline_cycle_in_progress": "In progress",
  "timeline_cycle_length_days": "{n} d",
  "timeline_card_a11y": "Cycle from {start} to {end}, {n} days",
  "timeline_card_a11y_in_progress": "Cycle from {start}, in progress",
  "table_col_start": "Start",
  "table_col_cycle": "Cycle",
  "table_col_period": "Period",
  "table_col_symptoms": "Symptoms",
  "table_cycle_dash": "—",
  "stats_cycle_length_title": "Cycle length",
  "stats_period_length_title": "Period length",
  "stats_symptoms_title": "Frequent symptoms",
  "stats_flow_title": "Flow intensity",
  "stats_insufficient_data": "Insufficient data",
  "stats_cycle_length_avg": "{n} d on average",
  "stats_period_length_avg": "{n} d on average",
  "timeline_view_toggle": "Timeline",
  "table_view_toggle": "Table"
```

- [ ] **Step 3: Regenerate and verify**

```bash
flutter gen-l10n && flutter analyze lib/l10n/
```
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/l10n/app_it.arb lib/l10n/app_en.arb \
        lib/l10n/app_localizations.dart \
        lib/l10n/app_localizations_it.dart \
        lib/l10n/app_localizations_en.dart
git commit -m "feat(l10n): add timeline, table, and stats string keys"
```

---

## Task 6 — TimelineNotifier

**Files:**
- Create: `lib/features/timeline/state/timeline_controller.dart`

- [ ] **Step 1: Create the notifier**

```dart
// lib/features/timeline/state/timeline_controller.dart
// Copyright (C) 2026  Paolo Santucci
// [license header]

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/cycle_summary.dart';
import '../../../providers/use_case_providers.dart';

final timelineProvider =
    AutoDisposeAsyncNotifierProvider<TimelineNotifier, List<CycleSummary>>(
  TimelineNotifier.new,
);

class TimelineNotifier
    extends AutoDisposeAsyncNotifier<List<CycleSummary>> {
  @override
  Future<List<CycleSummary>> build() async {
    final uc = await ref.read(getCycleSummariesProvider.future);
    final completer = Completer<List<CycleSummary>>();
    final sub = uc().listen((summaries) {
      if (!completer.isCompleted) {
        completer.complete(summaries);
      } else {
        state = AsyncData(summaries);
      }
    });
    ref.onDispose(sub.cancel);
    return completer.future;
  }
}
```

- [ ] **Step 2: Analyze**

```bash
flutter analyze lib/features/timeline/state/timeline_controller.dart
```
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/features/timeline/state/timeline_controller.dart
git commit -m "feat(timeline): add TimelineNotifier and timelineProvider"
```

---

## Task 7 — TimelineCard widget

**Files:**
- Create: `lib/features/timeline/widgets/timeline_card.dart`

- [ ] **Step 1: Create `TimelineCard`**

```dart
// lib/features/timeline/widgets/timeline_card.dart
// Copyright (C) 2026  Paolo Santucci
// [license header]

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' as intl;

import '../../../core/theme/metra_colors.dart';
import '../../../core/theme/metra_radius.dart';
import '../../../core/theme/metra_spacing.dart';
import '../../../domain/entities/cycle_summary.dart';
import '../../../domain/entities/pain_symptom_type.dart';
import '../../../l10n/app_localizations.dart';

class TimelineCard extends StatelessWidget {
  const TimelineCard({super.key, required this.summary});

  final CycleSummary summary;

  // Visual reference denominator for bar width: cycles > 35 days fill the bar.
  static const int _kBarMaxDays = 35;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = isDark ? MetraColors.dark : MetraColors.light;

    final cycle = summary.cycle;
    final isInProgress = cycle.endDate == null;
    final today = DateTime.now().toUtc();
    final todayNorm = DateTime.utc(today.year, today.month, today.day);

    final displayDays = cycle.cycleLength ??
        todayNorm.difference(cycle.startDate).inDays + 1;
    final barFraction = (displayDays / _kBarMaxDays).clamp(0.0, 1.0);

    final dateFormat = intl.DateFormat('d MMM yyyy', 'it');
    final shortFormat = intl.DateFormat('d MMM', 'it');

    final startStr = shortFormat.format(cycle.startDate);
    final endStr = isInProgress
        ? l10n.timeline_cycle_in_progress
        : shortFormat.format(cycle.endDate!);

    final semanticsLabel = isInProgress
        ? l10n.timeline_card_a11y_in_progress(startStr)
        : l10n.timeline_card_a11y(startStr, endStr, cycle.cycleLength ?? displayDays);

    return Semantics(
      label: semanticsLabel,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(MetraRadius.md),
        onTap: () => context.push(
          '/daily-entry/${cycle.startDate.toIso8601String().substring(0, 10)}',
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MetraSpacing.s4,
            vertical: MetraSpacing.s3,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: date range + badge
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '$startStr – $endStr',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: MetraSpacing.s2,
                      vertical: MetraSpacing.s1,
                    ),
                    decoration: BoxDecoration(
                      color: isInProgress
                          ? colors.accentFlow.withOpacity(0.15)
                          : colors.bgSunken,
                      borderRadius: BorderRadius.circular(MetraRadius.pill),
                    ),
                    child: Text(
                      isInProgress
                          ? l10n.timeline_cycle_in_progress
                          : l10n.timeline_cycle_length_days(cycle.cycleLength!),
                      style: TextStyle(
                        color: isInProgress
                            ? colors.accentFlowStrong
                            : colors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: MetraSpacing.s2),
              // Proportional bar
              LayoutBuilder(
                builder: (_, constraints) => Container(
                  height: 8,
                  width: constraints.maxWidth * barFraction,
                  decoration: BoxDecoration(
                    color: colors.accentFlow,
                    borderRadius: BorderRadius.circular(MetraRadius.pill),
                  ),
                ),
              ),
              if (summary.symptoms.isNotEmpty) ...[
                const SizedBox(height: MetraSpacing.s2),
                Text(
                  _symptomLabels(context, summary.symptoms),
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _symptomLabels(BuildContext context, List<PainSymptomType> symptoms) {
    final l10n = AppLocalizations.of(context)!;
    return symptoms.map((s) => _symptomLabel(l10n, s)).join(', ');
  }

  String _symptomLabel(AppLocalizations l10n, PainSymptomType type) {
    switch (type) {
      case PainSymptomType.cramps:    return l10n.daily_entry_symptom_cramps;
      case PainSymptomType.backPain:  return l10n.daily_entry_symptom_backPain;
      case PainSymptomType.headache:  return l10n.daily_entry_symptom_headache;
      case PainSymptomType.migraine:  return l10n.daily_entry_symptom_migraine;
      case PainSymptomType.bloating:  return l10n.daily_entry_symptom_bloating;
      case PainSymptomType.custom:    return '';
    }
  }
}
```

- [ ] **Step 2: Analyze**

```bash
flutter analyze lib/features/timeline/widgets/timeline_card.dart
```
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/features/timeline/widgets/timeline_card.dart
git commit -m "feat(timeline): add TimelineCard widget"
```

---

## Task 8 — TimelineView, TableView, and empty state

**Files:**
- Create: `lib/features/timeline/widgets/timeline_view.dart`
- Create: `lib/features/timeline/widgets/table_view.dart`

- [ ] **Step 1: Create `TimelineView`**

```dart
// lib/features/timeline/widgets/timeline_view.dart
// Copyright (C) 2026  Paolo Santucci
// [license header]

import 'package:flutter/material.dart';

import '../../../core/theme/metra_colors.dart';
import '../../../core/theme/metra_spacing.dart';
import '../../../domain/entities/cycle_summary.dart';
import '../../../l10n/app_localizations.dart';
import 'timeline_card.dart';

class TimelineView extends StatelessWidget {
  const TimelineView({super.key, required this.summaries});

  final List<CycleSummary> summaries;

  @override
  Widget build(BuildContext context) {
    if (summaries.isEmpty) return _EmptyState();
    return ListView.separated(
      padding: const EdgeInsets.all(MetraSpacing.s4),
      itemCount: summaries.length,
      separatorBuilder: (_, __) => const SizedBox(height: MetraSpacing.s2),
      itemBuilder: (_, i) => TimelineCard(summary: summaries[i]),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = isDark ? MetraColors.dark : MetraColors.light;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MetraSpacing.s8),
        child: Text(
          l10n.timeline_empty_hint,
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.textSecondary, fontSize: 15),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Create `TableView`**

```dart
// lib/features/timeline/widgets/table_view.dart
// Copyright (C) 2026  Paolo Santucci
// [license header]

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import '../../../core/theme/metra_colors.dart';
import '../../../core/theme/metra_spacing.dart';
import '../../../core/theme/metra_typography.dart';
import '../../../domain/entities/cycle_summary.dart';
import '../../../domain/entities/pain_symptom_type.dart';
import '../../../l10n/app_localizations.dart';
import 'timeline_view.dart' show _EmptyState;

class TableView extends StatelessWidget {
  const TableView({super.key, required this.summaries});

  final List<CycleSummary> summaries;

  @override
  Widget build(BuildContext context) {
    if (summaries.isEmpty) return _EmptyState();
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = isDark ? MetraColors.dark : MetraColors.light;
    final headerStyle = MetraTypography.caption(context).copyWith(
      color: colors.textSecondary,
      fontWeight: FontWeight.w600,
    );
    final cellStyle = MetraTypography.body(context).copyWith(
      color: colors.textPrimary,
      fontSize: 14,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(MetraSpacing.s4),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2),
          1: FlexColumnWidth(1),
          2: FlexColumnWidth(1),
          3: FlexColumnWidth(2),
        },
        children: [
          // Header row
          TableRow(
            children: [
              l10n.table_col_start,
              l10n.table_col_cycle,
              l10n.table_col_period,
              l10n.table_col_symptoms,
            ]
                .map((label) => Semantics(
                      header: true,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: MetraSpacing.s2),
                        child: Text(label, style: headerStyle),
                      ),
                    ))
                .toList(),
          ),
          // Data rows
          ...summaries.map((s) {
            final dateStr = intl.DateFormat('d MMM', 'it').format(s.cycle.startDate);
            final cycleLenStr = s.cycle.cycleLength != null
                ? '${s.cycle.cycleLength} g'
                : l10n.table_cycle_dash;
            final periodLenStr = s.cycle.periodLength != null
                ? '${s.cycle.periodLength} g'
                : l10n.table_cycle_dash;
            final symptomsStr = _formatSymptoms(context, s.symptoms, l10n);

            return TableRow(
              children: [dateStr, cycleLenStr, periodLenStr, symptomsStr]
                  .map((text) => Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: MetraSpacing.s3),
                        child: Text(text, style: cellStyle),
                      ))
                  .toList(),
            );
          }),
        ],
      ),
    );
  }

  String _formatSymptoms(
    BuildContext context,
    List<PainSymptomType> symptoms,
    AppLocalizations l10n,
  ) {
    if (symptoms.isEmpty) return '—';
    final labels = symptoms.map((s) => _symptomLabel(l10n, s)).toList();
    if (labels.length <= 2) return labels.join(', ');
    return '${labels.take(2).join(', ')}…';
  }

  String _symptomLabel(AppLocalizations l10n, PainSymptomType type) {
    switch (type) {
      case PainSymptomType.cramps:   return l10n.daily_entry_symptom_cramps;
      case PainSymptomType.backPain: return l10n.daily_entry_symptom_backPain;
      case PainSymptomType.headache: return l10n.daily_entry_symptom_headache;
      case PainSymptomType.migraine: return l10n.daily_entry_symptom_migraine;
      case PainSymptomType.bloating: return l10n.daily_entry_symptom_bloating;
      case PainSymptomType.custom:   return '';
    }
  }
}
```

- [ ] **Step 3: Analyze**

```bash
flutter analyze lib/features/timeline/widgets/
```
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/features/timeline/widgets/timeline_view.dart \
        lib/features/timeline/widgets/table_view.dart
git commit -m "feat(timeline): add TimelineView and TableView widgets"
```

---

## Task 9 — TimelineScreen host

**Files:**
- Modify: `lib/features/timeline/timeline_screen.dart` (replaces placeholder)

- [ ] **Step 1: Replace the placeholder implementation**

```dart
// lib/features/timeline/timeline_screen.dart
// Copyright (C) 2026  Paolo Santucci
// [license header]

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/metra_colors.dart';
import '../../core/theme/metra_spacing.dart';
import '../../core/widgets/segmented_control_metra.dart';
import '../../l10n/app_localizations.dart';
import 'state/timeline_controller.dart';
import 'widgets/table_view.dart';
import 'widgets/timeline_view.dart';

enum _ViewMode { timeline, table }

class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  _ViewMode _mode = _ViewMode.timeline;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = isDark ? MetraColors.dark : MetraColors.light;
    final summariesAsync = ref.watch(timelineProvider);

    return Scaffold(
      backgroundColor: colors.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MetraSpacing.s4,
                MetraSpacing.s4,
                MetraSpacing.s4,
                MetraSpacing.s2,
              ),
              child: SegmentedControlMetra(
                segments: [l10n.timeline_view_toggle, l10n.table_view_toggle],
                selectedIndex: _mode.index,
                onChanged: (i) =>
                    setState(() => _mode = _ViewMode.values[i]),
              ),
            ),
            Expanded(
              child: summariesAsync.when(
                loading: () => Center(
                  child: Semantics(
                    label: l10n.common_loading,
                    child: const CircularProgressIndicator(),
                  ),
                ),
                error: (_, __) => Center(
                  child: Text(
                    l10n.common_error_generic,
                    style: TextStyle(color: colors.textSecondary),
                  ),
                ),
                data: (summaries) => _mode == _ViewMode.timeline
                    ? TimelineView(summaries: summaries)
                    : TableView(summaries: summaries),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Analyze**

```bash
flutter analyze lib/features/timeline/
```
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/features/timeline/timeline_screen.dart
git commit -m "feat(timeline): implement TimelineScreen with segmented toggle (F-03 + F-04)"
```

---

## Task 10 — Timeline widget tests

**Files:**
- Create: `test/features/timeline/timeline_screen_test.dart`

- [ ] **Step 1: Write tests**

```dart
// test/features/timeline/timeline_screen_test.dart
// Copyright (C) 2026  Paolo Santucci
// [license header]

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:metra/core/theme/metra_theme.dart';
import 'package:metra/domain/entities/cycle_entry_entity.dart';
import 'package:metra/domain/entities/cycle_summary.dart';
import 'package:metra/domain/entities/flow_intensity.dart';
import 'package:metra/features/timeline/state/timeline_controller.dart';
import 'package:metra/features/timeline/timeline_screen.dart';
import 'package:metra/features/timeline/widgets/timeline_card.dart';
import 'package:metra/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Fake notifiers
// ---------------------------------------------------------------------------

class _LoadingNotifier extends TimelineNotifier {
  @override
  Future<List<CycleSummary>> build() =>
      Completer<List<CycleSummary>>().future;
}

class _ErrorNotifier extends TimelineNotifier {
  @override
  Future<List<CycleSummary>> build() async => throw Exception('test');
}

class _DataNotifier extends TimelineNotifier {
  _DataNotifier(this._data);
  final List<CycleSummary> _data;
  @override
  Future<List<CycleSummary>> build() async => _data;
}

// ---------------------------------------------------------------------------
// Widget helper
// ---------------------------------------------------------------------------

Widget _wrap(List<Override> overrides) {
  final router = GoRouter(
    initialLocation: '/timeline',
    routes: [
      GoRoute(path: '/timeline', builder: (_, __) => const TimelineScreen()),
      GoRoute(
        path: '/daily-entry/:date',
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('entry-stub'))),
      ),
    ],
  );
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(
      theme: MetraTheme.light(),
      locale: const Locale('it'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

CycleSummary _makeSummary({
  required DateTime start,
  DateTime? end,
  int? cycleLength,
  int? periodLength,
}) =>
    CycleSummary(
      cycle: CycleEntryEntity(
        id: 1,
        startDate: start,
        endDate: end,
        cycleLength: cycleLength,
        periodLength: periodLength,
      ),
      symptoms: const [],
    );

void main() {
  group('TimelineScreen — loading', () {
    testWidgets('shows spinner while loading', (tester) async {
      await tester.pumpWidget(
        _wrap([timelineProvider.overrideWith(_LoadingNotifier.new)]),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('TimelineScreen — error', () {
    testWidgets('shows error text on failure', (tester) async {
      await tester.pumpWidget(
        _wrap([timelineProvider.overrideWith(_ErrorNotifier.new)]),
      );
      await tester.pumpAndSettle();
      expect(find.text('Qualcosa è andato storto. Riprova.'), findsOneWidget);
    });
  });

  group('TimelineScreen — empty data', () {
    testWidgets('shows empty-state hint when no cycles', (tester) async {
      await tester.pumpWidget(
        _wrap([timelineProvider.overrideWith(() => _DataNotifier([]))]),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Registra il tuo primo ciclo'), findsOneWidget);
    });
  });

  group('TimelineScreen — data', () {
    final kSummaries = [
      _makeSummary(
        start: DateTime.utc(2026, 1, 15),
        end: DateTime.utc(2026, 1, 20),
        cycleLength: 28,
        periodLength: 6,
      ),
    ];

    testWidgets('renders TimelineCard widgets in timeline mode', (tester) async {
      await tester.pumpWidget(
        _wrap([timelineProvider.overrideWith(() => _DataNotifier(kSummaries))]),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TimelineCard), findsOneWidget);
    });

    testWidgets('tapping the Table segment switches to table view', (tester) async {
      await tester.pumpWidget(
        _wrap([timelineProvider.overrideWith(() => _DataNotifier(kSummaries))]),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tabella'));
      await tester.pumpAndSettle();
      // TimelineCard is not visible in table view
      expect(find.byType(TimelineCard), findsNothing);
      // Table header visible
      expect(find.text('Inizio'), findsOneWidget);
    });

    testWidgets('tapping a TimelineCard navigates to daily-entry', (tester) async {
      await tester.pumpWidget(
        _wrap([timelineProvider.overrideWith(() => _DataNotifier(kSummaries))]),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TimelineCard).first);
      await tester.pumpAndSettle();
      expect(find.text('entry-stub'), findsOneWidget);
    });

    testWidgets('TimelineCard has correct semantics label', (tester) async {
      await tester.pumpWidget(
        _wrap([timelineProvider.overrideWith(() => _DataNotifier(kSummaries))]),
      );
      await tester.pumpAndSettle();
      // Label includes dates and day count
      expect(
        find.bySemanticsLabel(RegExp(r'Ciclo dal')),
        findsOneWidget,
      );
    });

    testWidgets('in-progress card shows "In corso" badge', (tester) async {
      final inProgress = [
        _makeSummary(start: DateTime.utc(2026, 4, 13)),
      ];
      await tester.pumpWidget(
        _wrap([timelineProvider.overrideWith(() => _DataNotifier(inProgress))]),
      );
      await tester.pumpAndSettle();
      expect(find.text('In corso'), findsWidgets);
    });
  });
}
```

- [ ] **Step 2: Run tests**

```bash
flutter test test/features/timeline/timeline_screen_test.dart --no-pub
```
Expected: all tests pass.

- [ ] **Step 3: Commit**

```bash
git add test/features/timeline/timeline_screen_test.dart
git commit -m "test(timeline): add TimelineScreen widget tests"
```

---

## Task 11 — StatsNotifier

**Files:**
- Create: `lib/features/stats/state/stats_controller.dart`

- [ ] **Step 1: Create the notifier**

```dart
// lib/features/stats/state/stats_controller.dart
// Copyright (C) 2026  Paolo Santucci
// [license header]

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/cycle_stats_data.dart';
import '../../../providers/use_case_providers.dart';

final statsProvider =
    AutoDisposeAsyncNotifierProvider<StatsNotifier, CycleStatsData?>(
  StatsNotifier.new,
);

class StatsNotifier extends AutoDisposeAsyncNotifier<CycleStatsData?> {
  @override
  Future<CycleStatsData?> build() async {
    final uc = await ref.read(computeCycleStatsProvider.future);
    final completer = Completer<CycleStatsData?>();
    final sub = uc().listen((data) {
      if (!completer.isCompleted) {
        completer.complete(data);
      } else {
        state = AsyncData(data);
      }
    });
    ref.onDispose(sub.cancel);
    return completer.future;
  }
}
```

- [ ] **Step 2: Analyze**

```bash
flutter analyze lib/features/stats/state/stats_controller.dart
```
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/features/stats/state/stats_controller.dart
git commit -m "feat(stats): add StatsNotifier and statsProvider"
```

---

## Task 12 — StatCard + StatsScreen host

**Files:**
- Create: `lib/features/stats/widgets/stat_card.dart`
- Modify: `lib/features/stats/stats_screen.dart` (replaces placeholder)

- [ ] **Step 1: Create `StatCard`**

```dart
// lib/features/stats/widgets/stat_card.dart
// Copyright (C) 2026  Paolo Santucci
// [license header]

import 'package:flutter/material.dart';

import '../../../core/theme/metra_colors.dart';
import '../../../core/theme/metra_radius.dart';
import '../../../core/theme/metra_spacing.dart';
import '../../../core/theme/metra_typography.dart';

class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = isDark ? MetraColors.dark : MetraColors.light;
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: MetraSpacing.s4,
        vertical: MetraSpacing.s2,
      ),
      padding: const EdgeInsets.all(MetraSpacing.s4),
      decoration: BoxDecoration(
        color: colors.bgSurface,
        borderRadius: BorderRadius.circular(MetraRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: MetraTypography.sectionTitle(context)
                .copyWith(color: colors.textPrimary, fontSize: 16),
          ),
          const SizedBox(height: MetraSpacing.s3),
          child,
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Replace `stats_screen.dart` placeholder**

```dart
// lib/features/stats/stats_screen.dart
// Copyright (C) 2026  Paolo Santucci
// [license header]

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/metra_colors.dart';
import '../../core/theme/metra_spacing.dart';
import '../../l10n/app_localizations.dart';
import 'state/stats_controller.dart';
import 'widgets/cycle_length_chart.dart';
import 'widgets/flow_intensity_chart.dart';
import 'widgets/period_length_chart.dart';
import 'widgets/stat_card.dart';
import 'widgets/symptom_frequency_chart.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = isDark ? MetraColors.dark : MetraColors.light;
    final statsAsync = ref.watch(statsProvider);

    return Scaffold(
      backgroundColor: colors.bgPrimary,
      body: SafeArea(
        child: statsAsync.when(
          loading: () => Center(
            child: Semantics(
              label: l10n.common_loading,
              child: const CircularProgressIndicator(),
            ),
          ),
          error: (_, __) => Center(
            child: Text(
              l10n.common_error_generic,
              style: TextStyle(color: colors.textSecondary),
            ),
          ),
          data: (statsData) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: MetraSpacing.s4),
            child: Column(
              children: [
                StatCard(
                  title: l10n.stats_cycle_length_title,
                  child: statsData == null
                      ? _InsufficientData(l10n: l10n)
                      : CycleLengthChart(points: statsData.points),
                ),
                StatCard(
                  title: l10n.stats_period_length_title,
                  child: statsData == null
                      ? _InsufficientData(l10n: l10n)
                      : PeriodLengthChart(points: statsData.points),
                ),
                StatCard(
                  title: l10n.stats_symptoms_title,
                  child: statsData == null
                      ? _InsufficientData(l10n: l10n)
                      : SymptomFrequencyChart(
                          frequencies: statsData.symptomFrequencies,
                        ),
                ),
                StatCard(
                  title: l10n.stats_flow_title,
                  child: statsData == null
                      ? _InsufficientData(l10n: l10n)
                      : FlowIntensityChart(points: statsData.points),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InsufficientData extends StatelessWidget {
  const _InsufficientData({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = isDark ? MetraColors.dark : MetraColors.light;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MetraSpacing.s3),
      child: Text(
        l10n.stats_insufficient_data,
        style: TextStyle(color: colors.textSecondary, fontSize: 14),
      ),
    );
  }
}
```

- [ ] **Step 3: Analyze**

```bash
flutter analyze lib/features/stats/
```
Note: will report "target of URI doesn't exist" for chart imports — those files are created in the next task. Ignore those errors; the rest must be clean.

- [ ] **Step 4: Commit**

```bash
git add lib/features/stats/widgets/stat_card.dart \
        lib/features/stats/stats_screen.dart
git commit -m "feat(stats): add StatCard and StatsScreen host"
```

---

## Task 13 — fl_chart line charts

**Files:**
- Create: `lib/features/stats/widgets/cycle_length_chart.dart`
- Create: `lib/features/stats/widgets/period_length_chart.dart`

- [ ] **Step 1: Create `CycleLengthChart`**

```dart
// lib/features/stats/widgets/cycle_length_chart.dart
// Copyright (C) 2026  Paolo Santucci
// [license header]

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import '../../../core/theme/metra_colors.dart';
import '../../../core/theme/metra_spacing.dart';
import '../../../domain/entities/cycle_stats_data.dart';
import '../../../l10n/app_localizations.dart';

class CycleLengthChart extends StatelessWidget {
  const CycleLengthChart({super.key, required this.points});

  final List<CycleDataPoint> points;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = isDark ? MetraColors.dark : MetraColors.light;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    final spots = points
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.cycleLength.toDouble()))
        .toList();

    final lengths = points.map((p) => p.cycleLength);
    final avg = lengths.isEmpty
        ? 0
        : (lengths.reduce((a, b) => a + b) / lengths.length).round();
    final minY = (lengths.isEmpty ? 20 : lengths.reduce((a, b) => a < b ? a : b)) - 5.0;
    final maxY = (lengths.isEmpty ? 35 : lengths.reduce((a, b) => a > b ? a : b)) + 5.0;

    final semanticsLabel = points
        .map((p) => '${intl.DateFormat.MMM('it').format(p.startDate)}: ${p.cycleLength} g')
        .join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: semanticsLabel,
          child: SizedBox(
            height: 120,
            child: LineChart(
              LineChartData(
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: false,
                    color: colors.accentFlow,
                    barWidth: 2,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (_, __, ___, ____) =>
                          FlDotCirclePainter(
                            radius: 4,
                            color: colors.accentFlow,
                            strokeWidth: 0,
                          ),
                    ),
                    belowBarData: BarAreaData(show: false),
                  ),
                ],
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (v, _) => Text(
                        '${v.toInt()}',
                        style: TextStyle(
                            color: colors.textSecondary, fontSize: 10),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 20,
                      getTitlesWidget: (value, _) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= points.length) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          intl.DateFormat.MMM('it')
                              .format(points[idx].startDate),
                          style: TextStyle(
                              color: colors.textSecondary, fontSize: 10),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: false),
                minY: minY,
                maxY: maxY,
                lineTouchData: const LineTouchData(enabled: false),
              ),
              duration: Duration(
                  milliseconds:
                      reduceMotion ? 0 : 240),
            ),
          ),
        ),
        const SizedBox(height: MetraSpacing.s2),
        Text(
          l10n.stats_cycle_length_avg(avg),
          style: TextStyle(color: colors.textSecondary, fontSize: 13),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Create `PeriodLengthChart`** (same structure, ochre line, periodLength)

```dart
// lib/features/stats/widgets/period_length_chart.dart
// Copyright (C) 2026  Paolo Santucci
// [license header]

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import '../../../core/theme/metra_colors.dart';
import '../../../core/theme/metra_spacing.dart';
import '../../../domain/entities/cycle_stats_data.dart';
import '../../../l10n/app_localizations.dart';

class PeriodLengthChart extends StatelessWidget {
  const PeriodLengthChart({super.key, required this.points});

  final List<CycleDataPoint> points;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = isDark ? MetraColors.dark : MetraColors.light;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    // Null periodLength → invisible spot (gap in line).
    final spots = points
        .asMap()
        .entries
        .where((e) => e.value.periodLength != null)
        .map((e) => FlSpot(e.key.toDouble(), e.value.periodLength!.toDouble()))
        .toList();

    final nonNullLengths = points
        .where((p) => p.periodLength != null)
        .map((p) => p.periodLength!);
    final avg = nonNullLengths.isEmpty
        ? 0
        : (nonNullLengths.reduce((a, b) => a + b) / nonNullLengths.length)
            .round();
    final minY = nonNullLengths.isEmpty ? 0.0 : nonNullLengths.reduce((a, b) => a < b ? a : b) - 2.0;
    final maxY = nonNullLengths.isEmpty ? 10.0 : nonNullLengths.reduce((a, b) => a > b ? a : b) + 2.0;

    final semanticsLabel = points
        .map((p) =>
            '${intl.DateFormat.MMM('it').format(p.startDate)}: ${p.periodLength != null ? '${p.periodLength} g' : '—'}')
        .join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: semanticsLabel,
          child: SizedBox(
            height: 120,
            child: spots.isEmpty
                ? Center(
                    child: Text(l10n.stats_insufficient_data,
                        style: TextStyle(
                            color: colors.textSecondary, fontSize: 14)))
                : LineChart(
                    LineChartData(
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: false,
                          color: colors.accentWarmth,
                          barWidth: 2,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (_, __, ___, ____) =>
                                FlDotCirclePainter(
                                  radius: 4,
                                  color: colors.accentWarmth,
                                  strokeWidth: 0,
                                ),
                          ),
                          belowBarData: BarAreaData(show: false),
                        ),
                      ],
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            getTitlesWidget: (v, _) => Text('${v.toInt()}',
                                style: TextStyle(
                                    color: colors.textSecondary,
                                    fontSize: 10)),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 20,
                            getTitlesWidget: (value, _) {
                              final idx = value.toInt();
                              if (idx < 0 || idx >= points.length) {
                                return const SizedBox.shrink();
                              }
                              return Text(
                                intl.DateFormat.MMM('it')
                                    .format(points[idx].startDate),
                                style: TextStyle(
                                    color: colors.textSecondary,
                                    fontSize: 10),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      gridData: const FlGridData(show: false),
                      minY: minY,
                      maxY: maxY,
                      lineTouchData: const LineTouchData(enabled: false),
                    ),
                    duration: Duration(
                        milliseconds: reduceMotion ? 0 : 240),
                  ),
          ),
        ),
        const SizedBox(height: MetraSpacing.s2),
        Text(
          l10n.stats_period_length_avg(avg),
          style: TextStyle(color: colors.textSecondary, fontSize: 13),
        ),
      ],
    );
  }
}
```

- [ ] **Step 3: Analyze**

```bash
flutter analyze lib/features/stats/widgets/cycle_length_chart.dart \
               lib/features/stats/widgets/period_length_chart.dart
```
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/features/stats/widgets/cycle_length_chart.dart \
        lib/features/stats/widgets/period_length_chart.dart
git commit -m "feat(stats): add CycleLengthChart and PeriodLengthChart"
```

---

## Task 14 — SymptomFrequencyChart + FlowIntensityChart

**Files:**
- Create: `lib/features/stats/widgets/symptom_frequency_chart.dart`
- Create: `lib/features/stats/widgets/flow_intensity_chart.dart`

- [ ] **Step 1: Create `SymptomFrequencyChart`** (custom rows, no fl_chart)

```dart
// lib/features/stats/widgets/symptom_frequency_chart.dart
// Copyright (C) 2026  Paolo Santucci
// [license header]

import 'package:flutter/material.dart';

import '../../../core/theme/metra_colors.dart';
import '../../../core/theme/metra_spacing.dart';
import '../../../domain/entities/pain_symptom_type.dart';
import '../../../l10n/app_localizations.dart';

class SymptomFrequencyChart extends StatelessWidget {
  const SymptomFrequencyChart({super.key, required this.frequencies});

  final Map<PainSymptomType, double> frequencies;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = isDark ? MetraColors.dark : MetraColors.light;

    final nonZero = frequencies.entries
        .where((e) => e.key != PainSymptomType.custom && e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (nonZero.isEmpty) {
      return Text(
        l10n.stats_insufficient_data,
        style: TextStyle(color: colors.textSecondary, fontSize: 14),
      );
    }

    return Column(
      children: nonZero.map((entry) {
        final pct = (entry.value * 100).round();
        final label = _symptomLabel(l10n, entry.key);
        return Semantics(
          label: '$label, $pct%',
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: MetraSpacing.s1),
            child: Row(
              children: [
                SizedBox(
                  width: 90,
                  child: Text(
                    label,
                    style: TextStyle(
                        color: colors.textSecondary, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: MetraSpacing.s2),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: entry.value,
                      backgroundColor: colors.bgSunken,
                      color: colors.accentFlow,
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: MetraSpacing.s2),
                SizedBox(
                  width: 36,
                  child: Text(
                    '$pct%',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        color: colors.textSecondary, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  String _symptomLabel(AppLocalizations l10n, PainSymptomType type) {
    switch (type) {
      case PainSymptomType.cramps:   return l10n.daily_entry_symptom_cramps;
      case PainSymptomType.backPain: return l10n.daily_entry_symptom_backPain;
      case PainSymptomType.headache: return l10n.daily_entry_symptom_headache;
      case PainSymptomType.migraine: return l10n.daily_entry_symptom_migraine;
      case PainSymptomType.bloating: return l10n.daily_entry_symptom_bloating;
      case PainSymptomType.custom:   return '';
    }
  }
}
```

- [ ] **Step 2: Create `FlowIntensityChart`**

```dart
// lib/features/stats/widgets/flow_intensity_chart.dart
// Copyright (C) 2026  Paolo Santucci
// [license header]

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import '../../../core/theme/metra_colors.dart';
import '../../../domain/entities/cycle_stats_data.dart';
import '../../../domain/entities/flow_intensity.dart';
import '../../../l10n/app_localizations.dart';

class FlowIntensityChart extends StatelessWidget {
  const FlowIntensityChart({super.key, required this.points});

  final List<CycleDataPoint> points;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = isDark ? MetraColors.dark : MetraColors.light;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    final barGroups = points.asMap().entries.map((e) {
      final ordinal = (e.value.dominantFlow?.index ?? 0).toDouble();
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: ordinal,
            color: colors.accentFlow,
            width: 14,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    }).toList();

    final semanticsLabel = points
        .map((p) =>
            '${intl.DateFormat.MMM('it').format(p.startDate)}: ${_flowLabel(l10n, p.dominantFlow)}')
        .join(', ');

    return Semantics(
      label: semanticsLabel,
      child: SizedBox(
        height: 120,
        child: BarChart(
          BarChartData(
            barGroups: barGroups,
            maxY: FlowIntensity.values.length.toDouble() - 1,
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 20,
                  getTitlesWidget: (value, _) {
                    final idx = value.toInt();
                    if (idx < 0 || idx >= points.length) {
                      return const SizedBox.shrink();
                    }
                    return Text(
                      intl.DateFormat.MMM('it').format(points[idx].startDate),
                      style: TextStyle(
                          color: colors.textSecondary, fontSize: 10),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            gridData: const FlGridData(show: false),
            barTouchData: BarTouchData(enabled: false),
          ),
          duration: Duration(milliseconds: reduceMotion ? 0 : 240),
        ),
      ),
    );
  }

  String _flowLabel(AppLocalizations l10n, FlowIntensity? fi) {
    switch (fi) {
      case FlowIntensity.none:     return l10n.daily_entry_flow_none;
      case FlowIntensity.light:    return l10n.daily_entry_flow_light;
      case FlowIntensity.medium:   return l10n.daily_entry_flow_medium;
      case FlowIntensity.heavy:    return l10n.daily_entry_flow_heavy;
      case FlowIntensity.veryHeavy: return l10n.daily_entry_flow_veryHeavy;
      case null:                   return '—';
    }
  }
}
```

- [ ] **Step 3: Full analyze**

```bash
flutter analyze lib/features/stats/
```
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/features/stats/widgets/symptom_frequency_chart.dart \
        lib/features/stats/widgets/flow_intensity_chart.dart
git commit -m "feat(stats): add SymptomFrequencyChart and FlowIntensityChart"
```

---

## Task 15 — Stats widget tests

**Files:**
- Create: `test/features/stats/stats_screen_test.dart`

- [ ] **Step 1: Write tests**

```dart
// test/features/stats/stats_screen_test.dart
// Copyright (C) 2026  Paolo Santucci
// [license header]

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/theme/metra_theme.dart';
import 'package:metra/domain/entities/cycle_stats_data.dart';
import 'package:metra/domain/entities/pain_symptom_type.dart';
import 'package:metra/features/stats/state/stats_controller.dart';
import 'package:metra/features/stats/stats_screen.dart';
import 'package:metra/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Fake notifiers
// ---------------------------------------------------------------------------

class _LoadingStatsNotifier extends StatsNotifier {
  @override
  Future<CycleStatsData?> build() => Completer<CycleStatsData?>().future;
}

class _ErrorStatsNotifier extends StatsNotifier {
  @override
  Future<CycleStatsData?> build() async => throw Exception('test');
}

class _NullDataNotifier extends StatsNotifier {
  @override
  Future<CycleStatsData?> build() async => null; // 0 complete cycles
}

class _DataNotifier extends StatsNotifier {
  _DataNotifier(this._data);
  final CycleStatsData _data;
  @override
  Future<CycleStatsData?> build() async => _data;
}

// ---------------------------------------------------------------------------
// Widget helper
// ---------------------------------------------------------------------------

Widget _wrap(List<Override> overrides) => ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: MetraTheme.light(),
        locale: const Locale('it'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const StatsScreen(),
      ),
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

CycleStatsData _makeStatsData() => CycleStatsData(
      points: [
        CycleDataPoint(
          startDate: DateTime.utc(2026, 1, 15),
          cycleLength: 28,
          periodLength: 6,
        ),
      ],
      symptomFrequencies: {
        PainSymptomType.cramps: 1.0,
        PainSymptomType.backPain: 0.0,
        PainSymptomType.headache: 0.0,
        PainSymptomType.migraine: 0.0,
        PainSymptomType.bloating: 0.5,
      },
    );

void main() {
  group('StatsScreen — loading', () {
    testWidgets('shows spinner while loading', (tester) async {
      await tester.pumpWidget(
        _wrap([statsProvider.overrideWith(_LoadingStatsNotifier.new)]),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('StatsScreen — error', () {
    testWidgets('shows error text on failure', (tester) async {
      await tester.pumpWidget(
        _wrap([statsProvider.overrideWith(_ErrorStatsNotifier.new)]),
      );
      await tester.pumpAndSettle();
      expect(find.text('Qualcosa è andato storto. Riprova.'), findsOneWidget);
    });
  });

  group('StatsScreen — null data (0 complete cycles)', () {
    testWidgets('shows all four card titles', (tester) async {
      await tester.pumpWidget(
        _wrap([statsProvider.overrideWith(_NullDataNotifier.new)]),
      );
      await tester.pumpAndSettle();
      expect(find.text('Lunghezza ciclo'), findsOneWidget);
      expect(find.text('Durata mestruazione'), findsOneWidget);
      expect(find.text('Sintomi frequenti'), findsOneWidget);
      expect(find.text('Intensità flusso'), findsOneWidget);
    });

    testWidgets('shows "Dati insufficienti" inside each card', (tester) async {
      await tester.pumpWidget(
        _wrap([statsProvider.overrideWith(_NullDataNotifier.new)]),
      );
      await tester.pumpAndSettle();
      expect(find.text('Dati insufficienti'), findsNWidgets(4));
    });
  });

  group('StatsScreen — data', () {
    testWidgets('renders chart widgets when data available', (tester) async {
      await tester.pumpWidget(
        _wrap([statsProvider.overrideWith(() => _DataNotifier(_makeStatsData()))]),
      );
      await tester.pumpAndSettle();
      // Card titles present
      expect(find.text('Lunghezza ciclo'), findsOneWidget);
      // "Dati insufficienti" NOT shown (data exists)
      expect(find.text('Dati insufficienti'), findsNothing);
    });

    testWidgets('symptom frequency chart shows only non-zero symptoms',
        (tester) async {
      await tester.pumpWidget(
        _wrap([statsProvider.overrideWith(() => _DataNotifier(_makeStatsData()))]),
      );
      await tester.pumpAndSettle();
      // Crampi (100%) and Gonfiore (50%) are non-zero
      expect(find.text('Crampi'), findsOneWidget);
      expect(find.text('Gonfiore'), findsOneWidget);
      // Mal di schiena (0%) should not appear in the chart
      expect(find.text('Mal di schiena'), findsNothing);
    });
  });
}
```

- [ ] **Step 2: Run tests**

```bash
flutter test test/features/stats/stats_screen_test.dart --no-pub
```
Expected: all tests pass.

- [ ] **Step 3: Full suite**

```bash
flutter test --no-pub --timeout=120s
```
Expected: all tests pass (may include longer Argon2id tests — use 120s timeout).

- [ ] **Step 4: Analyze + format**

```bash
flutter analyze --no-fatal-infos && dart format --set-exit-if-changed .
```
Expected: `No issues found!` and no format changes.

- [ ] **Step 5: Commit**

```bash
git add test/features/stats/stats_screen_test.dart
git commit -m "test(stats): add StatsScreen widget tests"
```

---

## Task 16 — Security gate + tag

- [ ] **Step 1: Run appsec-engineer review**

Dispatch the `appsec-engineer` agent with this brief:

> Review the P-2 surface for OWASP Mobile Top 10 (M1, M2, M9). New files:
> - `lib/features/timeline/**` — reads CycleSummary (no user input, no credentials)
> - `lib/features/stats/**` — reads CycleStatsData (no user input, no credentials)
> - `lib/domain/use_cases/get_cycle_summaries.dart` — aggregates from repos, no network
> - `lib/domain/use_cases/compute_cycle_stats.dart` — pure aggregation
> Verify: no logging of DailyLogEntity fields, no new network calls, no unprotected storage access. Produce `docs/security/p2-appsec-review.md`.

- [ ] **Step 2: Commit the security review doc**

```bash
git add docs/security/p2-appsec-review.md
git commit -m "docs(security): P-2 appsec review"
```

- [ ] **Step 3: Tag**

```bash
git tag v0.1.0-p2
```

---

## Self-check before starting

- `flutter analyze` baseline: `No issues found!` — run before Task 1.
- All 184 existing tests pass: `flutter test --no-pub --timeout=120s` — run before Task 1.
- Confirm `intl` is in `pubspec.yaml` (it already is — used in calendar). No new deps needed.
- `fl_chart` is already in `pubspec.yaml`. No `pubspec.yaml` changes required for P-2.
