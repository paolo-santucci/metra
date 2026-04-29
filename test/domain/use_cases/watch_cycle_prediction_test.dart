// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
//
// Métra is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
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
import 'package:metra/domain/services/cycle_prediction_service.dart';
import 'package:metra/domain/use_cases/watch_cycle_prediction.dart';

import '../../helpers/fake_cycle_entry_repository.dart';

void main() {
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

  late FakeCycleEntryRepository fakeRepo;
  late WatchCyclePrediction useCase;

  setUp(() {
    fakeRepo = FakeCycleEntryRepository();
    useCase = WatchCyclePrediction(fakeRepo, const CyclePredictionService());
  });

  // Test 1: empty list → stream emits null
  test('emits null when repository is empty', () async {
    // fakeRepo.entries is empty by default
    expect(await useCase.call().first, isNull);
  });

  // Test 2: 2 complete cycles → stream emits null (insufficient data)
  test('emits null when only 2 complete cycles are available', () async {
    final anchor = DateTime(2026, 1, 1);
    fakeRepo.entries.addAll([
      makeEntry(id: 1, startDate: anchor, cycleLength: 28),
      makeEntry(
        id: 2,
        startDate: anchor.add(const Duration(days: 28)),
        cycleLength: 30,
      ),
    ]);

    expect(await useCase.call().first, isNull);
  });

  // Test 3: 3 complete cycles (lengths 28, 30, 27) → prediction matches WMA
  // WMA = (28*1 + 30*2 + 27*3) / (1+2+3)
  //     = (28 + 60 + 81) / 6
  //     = 169 / 6
  //     ≈ 28.167 → rounds to 28
  // expectedStart = start2 + 28 days
  test(
    'emits CyclePrediction with correct expectedStart for 3 cycles (28, 30, 27)',
    () async {
      final anchor = DateTime(2026, 1, 1);
      final start1 = anchor.add(const Duration(days: 28));
      final start2 = start1.add(const Duration(days: 30));

      fakeRepo.entries.addAll([
        makeEntry(id: 1, startDate: anchor, cycleLength: 28),
        makeEntry(id: 2, startDate: start1, cycleLength: 30),
        makeEntry(id: 3, startDate: start2, cycleLength: 27),
      ]);

      final prediction = await useCase.call().first;

      expect(prediction, isNotNull);
      expect(prediction!.cyclesUsed, equals(3));

      final expectedStart = start2.add(const Duration(days: 28));
      expect(prediction.expectedStart, equals(expectedStart));
      expect(
        prediction.windowStart,
        equals(expectedStart.subtract(const Duration(days: 2))),
      );
      expect(
        prediction.windowEnd,
        equals(expectedStart.add(const Duration(days: 2))),
      );
    },
  );
}
