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

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/result.dart';
import '../../../domain/entities/daily_log_entity.dart';
import '../../../providers/repository_providers.dart';
import '../../../providers/use_case_providers.dart';

// Family key is always a UTC-midnight DateTime (normalized before calling).
// Using a family so each date gets its own isolated, auto-disposed notifier.
final dailyEntryProvider = AutoDisposeAsyncNotifierProviderFamily<
  DailyEntryNotifier,
  DailyLogEntity?,
  DateTime
>(DailyEntryNotifier.new);

class DailyEntryNotifier
    extends AutoDisposeFamilyAsyncNotifier<DailyLogEntity?, DateTime> {
  @override
  Future<DailyLogEntity?> build(DateTime date) async {
    // arg is already UTC-midnight by contract at every call site.
    // ref.read, not ref.watch: the DB is initialized once and never re-opened
    // during the app lifetime. Using watch would trigger a spurious rebuild
    // each time the FutureProvider transitions from loading to data.
    final repo = await ref.read(dailyLogRepositoryProvider.future);

    // Use a Completer to seed the first value: if both the completer
    // completion and the stream listener fired sequentially, setting state
    // inside build() before it returns would throw on AsyncNotifier.
    final completer = Completer<DailyLogEntity?>();
    final sub = repo.watchDay(date).listen((log) {
      if (!completer.isCompleted) {
        completer.complete(log);
      } else {
        state = AsyncData(log);
      }
    });
    ref.onDispose(sub.cancel);

    return completer.future;
  }

  /// Saves [log] to the repository, then triggers cycle recomputation.
  /// On validation or storage failure, transitions state to [AsyncError].
  Future<void> save(DailyLogEntity log) async {
    // Do not log DailyLogEntity fields — security requirement.
    final saveUseCase = await ref.read(saveDailyLogProvider.future);
    final result = await saveUseCase(log);

    switch (result) {
      case Ok():
        // Cycle entries must be recomputed after every mutation.
        final recompute = await ref.read(recomputeCycleEntriesProvider.future);
        await recompute();
      case Err(:final error):
        state = AsyncError(error, StackTrace.current);
    }
  }

  /// Deletes the log for this notifier's date and recomputes cycles.
  Future<void> delete() async {
    final repo = await ref.read(dailyLogRepositoryProvider.future);
    try {
      await repo.deleteDailyLog(arg);
      final recompute = await ref.read(recomputeCycleEntriesProvider.future);
      await recompute();
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}
