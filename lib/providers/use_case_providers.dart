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

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/notification_service.dart';
import '../domain/services/cycle_prediction_service.dart';
import '../domain/services/notification_service.dart';
import '../domain/use_cases/complete_onboarding.dart';
import '../domain/use_cases/compute_cycle_stats.dart';
import '../domain/use_cases/get_cycle_summaries.dart';
import '../domain/use_cases/get_month_logs.dart';
import '../domain/use_cases/delete_all_data.dart';
import '../domain/use_cases/export_daily_logs.dart';
import '../domain/use_cases/import_daily_logs.dart';
import '../domain/use_cases/recompute_cycle_entries.dart';
import '../domain/use_cases/save_daily_log.dart';
import '../domain/use_cases/schedule_prediction_notification.dart';
import '../domain/use_cases/watch_cycle_prediction.dart';
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

final getCycleSummariesProvider = FutureProvider<GetCycleSummaries>((
  ref,
) async {
  final logRepo = await ref.watch(dailyLogRepositoryProvider.future);
  final cycleRepo = await ref.watch(cycleEntryRepositoryProvider.future);
  return GetCycleSummaries(logRepo, cycleRepo);
});

final computeCycleStatsProvider = FutureProvider<ComputeCycleStats>((
  ref,
) async {
  final getCycleSummaries = await ref.watch(getCycleSummariesProvider.future);
  return ComputeCycleStats(getCycleSummaries);
});

// ── P-3 prediction ──

final cyclePredictionServiceProvider = Provider<CyclePredictionService>(
  (_) => const CyclePredictionService(),
);

final watchCyclePredictionProvider = FutureProvider<WatchCyclePrediction>(
  (ref) async {
    final cycleRepo = await ref.watch(cycleEntryRepositoryProvider.future);
    final service = ref.watch(cyclePredictionServiceProvider);
    return WatchCyclePrediction(cycleRepo, service);
  },
);

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

final deleteAllDataProvider = FutureProvider<DeleteAllData>((ref) async {
  final logRepo = await ref.watch(dailyLogRepositoryProvider.future);
  final cycleRepo = await ref.watch(cycleEntryRepositoryProvider.future);
  return DeleteAllData(logRepo, cycleRepo);
});

// ── P-5a CSV export / import ──

final exportDailyLogsProvider = FutureProvider<ExportDailyLogs>((ref) async {
  final logRepo = await ref.watch(dailyLogRepositoryProvider.future);
  return ExportDailyLogs(logRepo);
});

final importDailyLogsProvider = FutureProvider<ImportDailyLogs>((ref) async {
  final logRepo = await ref.watch(dailyLogRepositoryProvider.future);
  final recompute = await ref.watch(recomputeCycleEntriesProvider.future);
  return ImportDailyLogs(logRepo, recompute);
});

// ── Calendar: current cycle day ──

/// Returns today's day-of-cycle (1 = period start day), or null if no cycle
/// entry exists yet.  Day 1 is inclusive: startDate → day 1, startDate+1 → day 2 …
final currentCycleDayProvider = FutureProvider<int?>((ref) async {
  final cycleRepo = await ref.watch(cycleEntryRepositoryProvider.future);
  final recent = await cycleRepo.getRecent(1);
  if (recent.isEmpty) return null;
  final startDate = recent.first.startDate;
  final today = DateTime.utc(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );
  final diff = today.difference(startDate).inDays;
  if (diff < 0) return null;
  return diff + 1;
});

/// Returns the day-of-cycle number for an arbitrary [date], or null when the
/// date falls before any known cycle start.
///
/// Scans all cycle entries in-memory (typically < 100) to find the cycle whose
/// startDate ≤ date < next cycle's startDate, then returns (date - startDate) + 1.
final cycleDayForDateProvider =
    FutureProvider.family<int?, DateTime>((ref, date) async {
  final cycleRepo = await ref.watch(cycleEntryRepositoryProvider.future);
  // 256 is a safe upper bound; typical users have < 50 cycle entries.
  final entries = await cycleRepo.getRecent(256);
  if (entries.isEmpty) return null;

  // entries are ordered newest-first from getRecent; sort oldest-first for scan.
  final sorted = [...entries]..sort((a, b) => a.startDate.compareTo(b.startDate));

  for (int i = 0; i < sorted.length; i++) {
    final start = sorted[i].startDate;
    if (date.isBefore(start)) continue;
    final nextStart = (i + 1 < sorted.length) ? sorted[i + 1].startDate : null;
    if (nextStart != null && !date.isBefore(nextStart)) continue;
    return date.difference(start).inDays + 1;
  }
  return null;
});

// ── P-7 onboarding ──

final completeOnboardingProvider = FutureProvider<CompleteOnboarding>((
  ref,
) async {
  final cycleRepo = await ref.watch(cycleEntryRepositoryProvider.future);
  final settingsRepo = await ref.watch(appSettingsRepositoryProvider.future);
  final logRepo = await ref.watch(dailyLogRepositoryProvider.future);
  final recompute = await ref.watch(recomputeCycleEntriesProvider.future);
  return CompleteOnboarding(cycleRepo, settingsRepo, logRepo, recompute);
});
