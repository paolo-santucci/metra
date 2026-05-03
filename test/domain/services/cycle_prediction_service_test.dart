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
import 'package:metra/domain/services/cycle_prediction_service.dart';
import 'package:metra/domain/entities/cycle_entry_entity.dart';
import 'package:metra/domain/entities/cycle_prediction.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  CycleEntryEntity makeEntry({
    required int id,
    required DateTime startDate,
    required int cycleLength,
    int periodLength = 5,
  }) {
    return CycleEntryEntity(
      id: id,
      startDate: startDate,
      endDate: startDate.add(Duration(days: cycleLength)),
      cycleLength: cycleLength,
      periodLength: periodLength,
    );
  }

  // ---------------------------------------------------------------------------
  // Group: CyclePrediction.containsDate
  // ---------------------------------------------------------------------------

  group('CyclePrediction.containsDate', () {
    final base = DateTime(2026, 1, 15);
    final prediction = CyclePrediction(
      windowStart: base.subtract(const Duration(days: 2)),
      windowEnd: base.add(const Duration(days: 2)),
      expectedStart: base,
      cyclesUsed: 3,
    );

    test('returns true for windowStart (boundary inclusive)', () {
      expect(prediction.containsDate(prediction.windowStart), isTrue);
    });

    test('returns true for windowEnd (boundary inclusive)', () {
      expect(prediction.containsDate(prediction.windowEnd), isTrue);
    });

    test('returns true for a date strictly inside the window', () {
      expect(prediction.containsDate(base), isTrue);
    });

    test('returns false for one day before windowStart', () {
      expect(
        prediction.containsDate(
          prediction.windowStart.subtract(const Duration(days: 1)),
        ),
        isFalse,
      );
    });

    test('returns false for one day after windowEnd', () {
      expect(
        prediction.containsDate(
          prediction.windowEnd.add(const Duration(days: 1)),
        ),
        isFalse,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Group: CyclePrediction equality
  // ---------------------------------------------------------------------------

  group('CyclePrediction equality', () {
    final base = DateTime(2026, 3, 1);

    CyclePrediction makePrediction({DateTime? expectedStart}) {
      final start = expectedStart ?? base;
      return CyclePrediction(
        windowStart: start.subtract(const Duration(days: 2)),
        windowEnd: start.add(const Duration(days: 2)),
        expectedStart: start,
        cyclesUsed: 3,
      );
    }

    test('two predictions with same fields are equal', () {
      expect(makePrediction(), equals(makePrediction()));
    });

    test('two predictions with different expectedStart are not equal', () {
      expect(
        makePrediction(),
        isNot(
          equals(
            makePrediction(expectedStart: base.add(const Duration(days: 1))),
          ),
        ),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Group: CyclePredictionService.predict — null cases
  // ---------------------------------------------------------------------------

  group('CyclePredictionService.predict — null cases', () {
    const service = CyclePredictionService();
    final anchor = DateTime(2026, 1, 1);

    test('returns null for empty list', () {
      expect(service.predict([]), isNull);
    });

    test('returns null for 1 complete cycle', () {
      final cycles = [makeEntry(id: 1, startDate: anchor, cycleLength: 28)];
      expect(service.predict(cycles), isNull);
    });

    test('returns null for 2 complete cycles', () {
      final cycles = [
        makeEntry(id: 1, startDate: anchor, cycleLength: 28),
        makeEntry(
          id: 2,
          startDate: anchor.add(const Duration(days: 28)),
          cycleLength: 30,
        ),
      ];
      expect(service.predict(cycles), isNull);
    });

    test(
      'returns null when 3 cycles are present but only 1 has cycleLength (2 are incomplete)',
      () {
        final cycles = [
          makeEntry(id: 1, startDate: anchor, cycleLength: 28),
          // incomplete — no cycleLength
          CycleEntryEntity(
            id: 2,
            startDate: anchor.add(const Duration(days: 28)),
          ),
          CycleEntryEntity(
            id: 3,
            startDate: anchor.add(const Duration(days: 56)),
          ),
        ];
        expect(service.predict(cycles), isNull);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Group: CyclePredictionService.predict — Strategy B declared fallback
  // ---------------------------------------------------------------------------

  group('CyclePredictionService.predict — declared fallback (Strategy B)', () {
    const service = CyclePredictionService();
    final anchor = DateTime(2026, 1, 1);

    test(
      'returns null for empty list even with declaredCycleLength provided',
      () {
        expect(
          service.predict([], declaredCycleLength: 28),
          isNull,
        );
      },
    );

    test(
      'returns null for 1 cycle when declaredCycleLength is null',
      () {
        final cycles = [makeEntry(id: 1, startDate: anchor, cycleLength: 28)];
        expect(service.predict(cycles), isNull);
      },
    );

    test(
      'returns fallback prediction for 1 cycle anchor with declaredCycleLength',
      () {
        // Only one anchor entry (null cycleLength, as inserted by CompleteOnboarding).
        final cycles = [
          CycleEntryEntity(id: 1, startDate: anchor),
        ];
        final result = service.predict(
          cycles,
          declaredCycleLength: 28,
        );

        expect(result, isNotNull);
        final expectedStart = anchor.add(const Duration(days: 28));
        expect(result!.expectedStart, equals(expectedStart));
        expect(
          result.windowStart,
          equals(expectedStart.subtract(const Duration(days: 2))),
        );
        expect(
          result.windowEnd,
          equals(expectedStart.add(const Duration(days: 2))),
        );
        // cyclesUsed == 0 signals "estimated, not measured".
        expect(result.cyclesUsed, equals(0));
      },
    );

    test(
      'fallback anchors on the most-recent cycle when 2 entries exist',
      () {
        final start1 = anchor;
        final start2 = anchor.add(const Duration(days: 30));
        final cycles = [
          CycleEntryEntity(id: 1, startDate: start1),
          CycleEntryEntity(id: 2, startDate: start2),
        ];
        final result = service.predict(
          cycles,
          declaredCycleLength: 28,
        );

        // Anchor must be start2 (most recent).
        expect(result, isNotNull);
        expect(
          result!.expectedStart,
          equals(start2.add(const Duration(days: 28))),
        );
      },
    );

    test(
      'WMA path takes over once 3 measured cycles exist, ignoring declaredCycleLength',
      () {
        // 3 complete cycles with measured lengths 30, 30, 30.
        final cycles = [
          makeEntry(id: 1, startDate: anchor, cycleLength: 30),
          makeEntry(
            id: 2,
            startDate: anchor.add(const Duration(days: 30)),
            cycleLength: 30,
          ),
          makeEntry(
            id: 3,
            startDate: anchor.add(const Duration(days: 60)),
            cycleLength: 30,
          ),
        ];
        // declaredCycleLength is 28 but WMA gives 30 — WMA must win.
        final result = service.predict(
          cycles,
          declaredCycleLength: 28,
        );

        expect(result, isNotNull);
        expect(result!.cyclesUsed, equals(3));
        expect(
          result.expectedStart,
          equals(anchor.add(const Duration(days: 90))),
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Group: CyclePredictionService.predict — core algorithm
  // ---------------------------------------------------------------------------

  group('CyclePredictionService.predict — core algorithm', () {
    const service = CyclePredictionService();
    final anchor = DateTime(2026, 1, 1);

    test('3 cycles: WMA produces correct expectedStart', () {
      // lengths [28, 30, 27], weights [1, 2, 3]
      // WMA = (28*1 + 30*2 + 27*3) / (1+2+3)
      //     = (28 + 60 + 81) / 6
      //     = 169 / 6
      //     ≈ 28.166... → rounds to 28
      final start0 = anchor;
      final start1 = start0.add(const Duration(days: 28));
      final start2 = start1.add(const Duration(days: 30));

      final cycles = [
        makeEntry(id: 1, startDate: start0, cycleLength: 28),
        makeEntry(id: 2, startDate: start1, cycleLength: 30),
        makeEntry(id: 3, startDate: start2, cycleLength: 27),
      ];

      final result = service.predict(cycles);
      expect(result, isNotNull);

      final expectedStart = start2.add(const Duration(days: 28));
      expect(result!.expectedStart, equals(expectedStart));
      expect(
        result.windowStart,
        equals(expectedStart.subtract(const Duration(days: 2))),
      );
      expect(
        result.windowEnd,
        equals(expectedStart.add(const Duration(days: 2))),
      );
      expect(result.cyclesUsed, equals(3));
    });

    test('3 cycles: window width is always exactly 5 days', () {
      final start0 = anchor;
      final start1 = start0.add(const Duration(days: 28));
      final start2 = start1.add(const Duration(days: 28));

      final cycles = [
        makeEntry(id: 1, startDate: start0, cycleLength: 28),
        makeEntry(id: 2, startDate: start1, cycleLength: 28),
        makeEntry(id: 3, startDate: start2, cycleLength: 28),
      ];

      final result = service.predict(cycles);
      expect(result, isNotNull);

      final widthDays = result!.windowEnd.difference(result.windowStart).inDays;
      // windowEnd - windowStart = 4 days → 5 distinct calendar days
      expect(widthDays, equals(4));
    });

    test('6-cycle cap: 10 complete cycles provided → cyclesUsed == 6', () {
      var start = anchor;
      final cycles = List.generate(10, (i) {
        final entry = makeEntry(id: i + 1, startDate: start, cycleLength: 28);
        start = start.add(const Duration(days: 28));
        return entry;
      });

      final result = service.predict(cycles);
      expect(result, isNotNull);
      expect(result!.cyclesUsed, equals(6));
    });

    test(
      'prediction anchors on the LATEST cycle even when it has cycleLength=null '
      '(incomplete current cycle)',
      () {
        // Simulates user with 4 cycles Jan-Apr — April is the current/incomplete cycle.
        final start0 = DateTime(2026, 1, 1);
        final start1 = start0.add(const Duration(days: 28));
        final start2 = start1.add(const Duration(days: 28));
        final start3 =
            start2.add(const Duration(days: 28)); // most recent, incomplete

        final cycles = [
          makeEntry(id: 1, startDate: start0, cycleLength: 28),
          makeEntry(id: 2, startDate: start1, cycleLength: 28),
          makeEntry(id: 3, startDate: start2, cycleLength: 28),
          // most recent cycle: incomplete — cycleLength is null
          CycleEntryEntity(id: 4, startDate: start3),
        ];

        final result = service.predict(cycles);
        expect(result, isNotNull);
        // expectedStart must be anchored on start3, not start2
        expect(
          result!.expectedStart,
          equals(start3.add(const Duration(days: 28))),
        );
        expect(result.cyclesUsed, equals(3)); // 3 complete cycles used for WMA
      },
    );

    test(
      '6-cycle cap: WMA uses only the most recent 6 when 10 cycles are provided',
      () {
        // First 4 cycles have length 99 (should be ignored).
        // Last 6 cycles all have length 28 → WMA = 28 → expectedStart = last.startDate + 28.
        var start = anchor;

        final cycles = <CycleEntryEntity>[];
        for (var i = 0; i < 4; i++) {
          cycles.add(makeEntry(id: i + 1, startDate: start, cycleLength: 99));
          start = start.add(const Duration(days: 99));
        }
        for (var i = 4; i < 10; i++) {
          cycles.add(makeEntry(id: i + 1, startDate: start, cycleLength: 28));
          start = start.add(const Duration(days: 28));
        }

        final result = service.predict(cycles);
        expect(result, isNotNull);
        expect(result!.cyclesUsed, equals(6));

        // Last cycle's startDate + 28 days
        final lastStart = cycles.last.startDate;
        expect(
          result.expectedStart,
          equals(lastStart.add(const Duration(days: 28))),
        );
      },
    );

    test(
      'given_two_cycles_share_startDate_when_predict_called_with_reversed_order_then_expectedStart_is_identical',
      () {
        // Regression for tie-break determinism in anchor reduce.
        // Two cycles share the same startDate: one complete (has cycleLength),
        // one incomplete (cycleLength null). The reduce tie-break must be
        // deterministic — both list orderings must produce the same expectedStart.
        final start0 = anchor;
        final start1 = start0.add(const Duration(days: 28));
        final start2 = start1.add(const Duration(days: 28));
        final tiedDate = start2.add(const Duration(days: 28));

        final completeAtTied =
            makeEntry(id: 4, startDate: tiedDate, cycleLength: 28);
        final incompleteAtTied =
            CycleEntryEntity(id: 5, startDate: tiedDate); // cycleLength null

        final base = [
          makeEntry(id: 1, startDate: start0, cycleLength: 28),
          makeEntry(id: 2, startDate: start1, cycleLength: 28),
          makeEntry(id: 3, startDate: start2, cycleLength: 28),
        ];

        final forwardOrder = [...base, completeAtTied, incompleteAtTied];
        final reversedOrder = [...base, incompleteAtTied, completeAtTied];

        final resultForward = service.predict(forwardOrder);
        final resultReversed = service.predict(reversedOrder);

        expect(resultForward, isNotNull);
        expect(resultReversed, isNotNull);
        expect(resultForward!.expectedStart,
            equals(resultReversed!.expectedStart));
      },
    );
  });
}
