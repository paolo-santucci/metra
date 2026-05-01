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

import '../../../domain/entities/daily_log_entity.dart';
import '../../../providers/repository_providers.dart';
import '../../../providers/use_case_providers.dart';

class CalendarMonthState {
  const CalendarMonthState({
    required this.year,
    required this.month,
    this.logs = const {},
    this.daysWithSymptoms = const {},
  });

  final int year;
  final int month;
  final Map<DateTime, DailyLogEntity> logs;

  /// UTC-midnight dates in this month that have at least one symptom logged.
  final Set<DateTime> daysWithSymptoms;
}

final calendarMonthProvider =
    AsyncNotifierProvider<CalendarMonthNotifier, CalendarMonthState>(
  CalendarMonthNotifier.new,
);

class CalendarMonthNotifier extends AsyncNotifier<CalendarMonthState> {
  StreamSubscription<List<DailyLogEntity>>? _logSub;

  @override
  Future<CalendarMonthState> build() async {
    final now = DateTime.now();
    ref.onDispose(() => _logSub?.cancel());
    return _subscribeToMonth(now.year, now.month);
  }

  Future<CalendarMonthState> _subscribeToMonth(int year, int month) async {
    // Cancel the previous subscription before creating a new one.
    await _logSub?.cancel();
    _logSub = null;

    final getMonthLogs = await ref.read(getMonthLogsProvider.future);
    final repo = await ref.read(dailyLogRepositoryProvider.future);

    // Load symptom dates once per month navigation (one query, not N per cell).
    final symptomDates = await repo.getSymptomDatesForMonth(year, month);

    // Seed the initial state, then keep updating via the stream.
    final completer = Completer<CalendarMonthState>();
    _logSub = getMonthLogs(year, month).listen((logs) {
      final mapped = <DateTime, DailyLogEntity>{
        for (final l in logs) l.date: l,
      };
      final next = CalendarMonthState(
        year: year,
        month: month,
        logs: mapped,
        daysWithSymptoms: symptomDates,
      );
      if (!completer.isCompleted) {
        completer.complete(next);
      } else {
        state = AsyncData(next);
      }
    });

    return completer.future;
  }

  void goToPrevMonth() {
    final current = state.valueOrNull;
    if (current == null) return;

    int year = current.year;
    int month = current.month - 1;
    if (month < 1) {
      month = 12;
      year -= 1;
    }
    state = AsyncData(CalendarMonthState(year: year, month: month));
    _subscribeToMonth(year, month).then(
      (s) => state = AsyncData(s),
      onError: (Object e, StackTrace st) => state = AsyncError(e, st),
    );
  }

  void goToNextMonth() {
    final current = state.valueOrNull;
    if (current == null) return;

    // Do not navigate past the current calendar month.
    final now = DateTime.now();
    if (current.year >= now.year && current.month >= now.month) return;

    int year = current.year;
    int month = current.month + 1;
    if (month > 12) {
      month = 1;
      year += 1;
    }
    state = AsyncData(CalendarMonthState(year: year, month: month));
    _subscribeToMonth(year, month).then(
      (s) => state = AsyncData(s),
      onError: (Object e, StackTrace st) => state = AsyncError(e, st),
    );
  }
}
