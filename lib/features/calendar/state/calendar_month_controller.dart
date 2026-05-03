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
  StreamSubscription<Set<DateTime>>? _symptomSub;

  @override
  Future<CalendarMonthState> build() async {
    final now = DateTime.now();
    ref.onDispose(() {
      _logSub?.cancel();
      _symptomSub?.cancel();
    });
    return _subscribeToMonth(now.year, now.month);
  }

  Future<CalendarMonthState> _subscribeToMonth(int year, int month) async {
    // Cancel both subscriptions before creating new ones.
    await _logSub?.cancel();
    await _symptomSub?.cancel();
    _logSub = null;
    _symptomSub = null;

    final getMonthLogs = await ref.read(getMonthLogsProvider.future);
    final repo = await ref.read(dailyLogRepositoryProvider.future);

    // One-shot seed so the first log emission has a valid symptomDates set.
    // The live stream below will then keep this in sync without navigation.
    final seedDates = await repo.getSymptomDatesForMonth(year, month);
    // Captured by both closures; symptom stream updates it so the log stream
    // always sees the latest value even if the two streams fire close together.
    var currentSymptomDates = seedDates;

    final completer = Completer<CalendarMonthState>();

    _logSub = getMonthLogs(year, month).listen((logs) {
      final mapped = <DateTime, DailyLogEntity>{
        for (final l in logs) l.date: l,
      };
      final next = CalendarMonthState(
        year: year,
        month: month,
        logs: mapped,
        daysWithSymptoms: currentSymptomDates,
      );
      if (!completer.isCompleted) {
        completer.complete(next);
      } else {
        state = AsyncData(next);
      }
    });

    // Live symptom updates — re-emitted whenever pain_symptoms rows change
    // within this month. Keeps daysWithSymptoms fresh without month navigation.
    _symptomSub = repo.watchSymptomDatesForMonth(year, month).listen((dates) {
      currentSymptomDates = dates;
      final current = state.valueOrNull;
      if (current == null) return;
      state = AsyncData(
        CalendarMonthState(
          year: current.year,
          month: current.month,
          logs: current.logs,
          daysWithSymptoms: dates,
        ),
      );
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
