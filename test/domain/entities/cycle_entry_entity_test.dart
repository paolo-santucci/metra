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

void main() {
  final start = DateTime.utc(2026, 4, 1);
  final end = DateTime.utc(2026, 4, 28);

  CycleEntryEntity makeEntry({
    int id = 1,
    DateTime? startDate,
    DateTime? endDate,
    int? cycleLength = 28,
    int? periodLength = 5,
  }) => CycleEntryEntity(
    id: id,
    startDate: startDate ?? start,
    endDate: endDate,
    cycleLength: cycleLength,
    periodLength: periodLength,
  );

  group('CycleEntryEntity construction', () {
    test('stores all required fields', () {
      final entity = CycleEntryEntity(id: 42, startDate: start);

      expect(entity.id, 42);
      expect(entity.startDate, start);
      expect(entity.endDate, isNull);
      expect(entity.cycleLength, isNull);
      expect(entity.periodLength, isNull);
    });

    test('stores all optional fields when provided', () {
      final entity = CycleEntryEntity(
        id: 7,
        startDate: start,
        endDate: end,
        cycleLength: 28,
        periodLength: 5,
      );

      expect(entity.endDate, end);
      expect(entity.cycleLength, 28);
      expect(entity.periodLength, 5);
    });
  });

  group('CycleEntryEntity equality', () {
    test('identical instance equals itself', () {
      final entity = makeEntry();
      // ignore: unrelated_type_equality_checks — intentional identity check
      expect(entity == entity, isTrue);
    });

    test('two instances with same field values are equal', () {
      final a = makeEntry(endDate: end);
      final b = makeEntry(endDate: end);

      expect(a, equals(b));
    });

    test('instances with different id are not equal', () {
      final a = makeEntry();
      final b = makeEntry(id: 99);

      expect(a, isNot(equals(b)));
    });

    test('instances with different startDate are not equal', () {
      final a = makeEntry();
      final b = makeEntry(startDate: DateTime.utc(2026, 3, 1));

      expect(a, isNot(equals(b)));
    });

    test('instances with different endDate are not equal', () {
      final a = makeEntry(endDate: end);
      final b = makeEntry(endDate: DateTime.utc(2026, 4, 27));

      expect(a, isNot(equals(b)));
    });

    test('instances with different cycleLength are not equal', () {
      final a = makeEntry(cycleLength: 28);
      final b = makeEntry(cycleLength: 30);

      expect(a, isNot(equals(b)));
    });

    test('instances with different periodLength are not equal', () {
      final a = makeEntry(periodLength: 5);
      final b = makeEntry(periodLength: 7);

      expect(a, isNot(equals(b)));
    });

    test('instance does not equal object of different type', () {
      final entity = makeEntry();

      // ignore: unrelated_type_equality_checks
      expect(entity == 'not an entity', isFalse);
    });
  });

  group('CycleEntryEntity hashCode', () {
    test('equal objects have the same hashCode', () {
      final a = makeEntry(endDate: end);
      final b = makeEntry(endDate: end);

      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('CycleEntryEntity copyWith', () {
    test('returns equal object when no arguments supplied', () {
      final entity = makeEntry(endDate: end);
      final copy = entity.copyWith();

      expect(copy, equals(entity));
    });

    test('updates id', () {
      final entity = makeEntry();
      final copy = entity.copyWith(id: 99);

      expect(copy.id, 99);
      expect(copy.startDate, entity.startDate);
    });

    test('updates startDate', () {
      final entity = makeEntry();
      final newDate = DateTime.utc(2026, 5, 1);
      final copy = entity.copyWith(startDate: newDate);

      expect(copy.startDate, newDate);
    });

    test('updates endDate', () {
      final entity = makeEntry();
      final copy = entity.copyWith(endDate: end);

      expect(copy.endDate, end);
    });

    test('updates cycleLength', () {
      final entity = makeEntry();
      final copy = entity.copyWith(cycleLength: 30);

      expect(copy.cycleLength, 30);
    });

    test('updates periodLength', () {
      final entity = makeEntry();
      final copy = entity.copyWith(periodLength: 7);

      expect(copy.periodLength, 7);
    });

    test('preserves endDate when not specified', () {
      final entity = makeEntry(endDate: end);
      final copy = entity.copyWith(id: 2);

      expect(copy.endDate, end);
    });
  });
}
