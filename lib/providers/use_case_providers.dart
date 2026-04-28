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
