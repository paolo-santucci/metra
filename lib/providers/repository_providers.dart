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

import '../data/repositories/drift_cycle_entry_repository.dart';
import '../data/repositories/drift_daily_log_repository.dart';
import '../domain/entities/pain_symptom_data.dart';
import '../domain/repositories/cycle_entry_repository.dart';
import '../domain/repositories/daily_log_repository.dart';
import 'database_provider.dart';

final dailyLogRepositoryProvider = FutureProvider<DailyLogRepository>((
  ref,
) async {
  final db = await ref.watch(databaseProvider.future);
  return DriftDailyLogRepository(db.dailyLogDao);
});

final cycleEntryRepositoryProvider = FutureProvider<CycleEntryRepository>((
  ref,
) async {
  final db = await ref.watch(databaseProvider.future);
  return DriftCycleEntryRepository(db.cycleEntryDao);
});

/// One-shot load of pain symptoms for a given UTC-midnight date.
///
/// Parameterized by date (family key). Auto-disposed when no longer watched.
/// Used by HistoricalEntryScreen to seed the SymptomChipsRow exactly once
/// without triggering rebuild loops.
final painSymptomsProvider = FutureProvider.autoDispose
    .family<List<PainSymptomData>, DateTime>((ref, date) async {
  final repo = await ref.watch(dailyLogRepositoryProvider.future);
  return repo.getPainSymptoms(date);
});
