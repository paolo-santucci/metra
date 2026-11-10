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

import 'package:flutter_test/flutter_test.dart';
import 'package:metra/domain/entities/cycle_entry_entity.dart';
import 'package:metra/domain/services/cycle_date_range.dart';

void main() {
  CycleEntryEntity cycle({
    int id = 1,
    required DateTime startDate,
    DateTime? endDate,
  }) {
    return CycleEntryEntity(id: id, startDate: startDate, endDate: endDate);
  }

  group('CycleDateRange.resolve', () {
    test('given_trailingCycle_when_resolved_then_endIsTodayNorm', () {
      final todayNorm = DateTime.utc(2026, 11, 10);
      final entry = cycle(
        startDate: DateTime.utc(2026, 10, 20),
        endDate: DateTime.utc(2026, 10, 25),
      );

      final range = CycleDateRange.resolve(
        cycle: entry,
        trailingStart: entry.startDate,
        todayNorm: todayNorm,
      );

      expect(range.end, todayNorm);
    });

    test('given_nonTrailingCycle_when_resolved_then_endIsItsEndDate', () {
      final todayNorm = DateTime.utc(2026, 11, 10);
      final entry = cycle(
        startDate: DateTime.utc(2026, 9, 1),
        endDate: DateTime.utc(2026, 9, 6),
      );

      final range = CycleDateRange.resolve(
        cycle: entry,
        trailingStart: DateTime.utc(2026, 10, 20),
        todayNorm: todayNorm,
      );

      expect(range.end, DateTime.utc(2026, 9, 6));
    });

    test('given_nonTrailingNullEnd_when_resolved_then_endIsTodayNorm', () {
      final todayNorm = DateTime.utc(2026, 11, 10);
      final entry = cycle(startDate: DateTime.utc(2026, 9, 1));

      final range = CycleDateRange.resolve(
        cycle: entry,
        trailingStart: DateTime.utc(2026, 10, 20),
        todayNorm: todayNorm,
      );

      expect(range.end, todayNorm);
    });

    test('given_anyCycle_when_resolved_then_startIsCycleStart', () {
      final entry = cycle(
        startDate: DateTime.utc(2026, 9, 1),
        endDate: DateTime.utc(2026, 9, 6),
      );

      final range = CycleDateRange.resolve(
        cycle: entry,
        trailingStart: DateTime.utc(2026, 10, 20),
        todayNorm: DateTime.utc(2026, 11, 10),
      );

      expect(range.start, DateTime.utc(2026, 9, 1));
    });
  });

  group('CycleDateRange.contains', () {
    final range = CycleDateRange(
      start: DateTime.utc(2026, 10, 20),
      end: DateTime.utc(2026, 10, 25),
    );

    test('given_dateAtRangeStart_when_contains_then_true', () {
      expect(range.contains(DateTime.utc(2026, 10, 20)), isTrue);
    });

    test('given_dateAtRangeEnd_when_contains_then_true', () {
      expect(range.contains(DateTime.utc(2026, 10, 25)), isTrue);
    });

    test('given_dayBeforeStart_when_contains_then_false', () {
      expect(range.contains(DateTime.utc(2026, 10, 19)), isFalse);
    });

    test('given_dayAfterEnd_when_contains_then_false', () {
      expect(range.contains(DateTime.utc(2026, 10, 26)), isFalse);
    });
  });

  group('CycleDateRange.trailingStartOf', () {
    test('given_manyCycles_when_trailingStartOf_then_greatestStart', () {
      final cycles = [
        cycle(id: 1, startDate: DateTime.utc(2026, 9, 1)),
        cycle(id: 2, startDate: DateTime.utc(2026, 11, 5)),
        cycle(id: 3, startDate: DateTime.utc(2026, 10, 3)),
      ];

      expect(
        CycleDateRange.trailingStartOf(cycles),
        DateTime.utc(2026, 11, 5),
      );
    });

    test('given_emptyList_when_trailingStartOf_then_throwsStateError', () {
      expect(() => CycleDateRange.trailingStartOf(const []), throwsStateError);
    });
  });

  group('CycleDateRange.todayNorm', () {
    test('given_nowWithTime_when_todayNorm_then_utcMidnight', () {
      expect(
        CycleDateRange.todayNorm(DateTime(2026, 11, 10, 14, 30, 9)),
        DateTime.utc(2026, 11, 10),
      );
    });

    test('given_injectedNow_when_todayNorm_then_sameDay', () {
      expect(
        CycleDateRange.todayNorm(DateTime.utc(2026, 3, 5)),
        DateTime.utc(2026, 3, 5),
      );
    });
  });
}
