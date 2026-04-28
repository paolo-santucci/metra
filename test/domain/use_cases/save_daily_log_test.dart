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
import 'package:metra/core/errors/metra_exception.dart';
import 'package:metra/core/utils/result.dart';
import 'package:metra/domain/entities/daily_log_entity.dart';
import 'package:metra/domain/entities/flow_intensity.dart';
import 'package:metra/domain/use_cases/save_daily_log.dart';

import '../../helpers/fake_daily_log_repository.dart';

void main() {
  late FakeDailyLogRepository repo;
  late SaveDailyLog useCase;

  setUp(() {
    repo = FakeDailyLogRepository();
    useCase = SaveDailyLog(repo);
  });

  DailyLogEntity makeLog({
    DateTime? date,
    FlowIntensity? flow,
    bool spotting = false,
    int? painIntensity,
  }) =>
      DailyLogEntity(
        date: date ?? DateTime.utc(2026, 1, 15),
        flowIntensity: flow,
        spotting: spotting,
        painEnabled: painIntensity != null,
        painIntensity: painIntensity,
      );

  group('flow + spotting mutual exclusivity', () {
    test('flow and spotting=true → Err(ValidationException)', () async {
      final result = await useCase(
        makeLog(flow: FlowIntensity.medium, spotting: true),
      );
      expect(result, isA<Err<DailyLogEntity>>());
      expect(
        (result as Err<DailyLogEntity>).error,
        isA<ValidationException>(),
      );
    });

    test('FlowIntensity.none + spotting=true → Ok', () async {
      final result = await useCase(
        makeLog(flow: FlowIntensity.none, spotting: true),
      );
      expect(result, isA<Ok<DailyLogEntity>>());
    });

    test('flow only (no spotting) → Ok', () async {
      final result = await useCase(makeLog(flow: FlowIntensity.heavy));
      expect(result, isA<Ok<DailyLogEntity>>());
    });

    test('spotting only (no flow) → Ok', () async {
      final result = await useCase(makeLog(spotting: true));
      expect(result, isA<Ok<DailyLogEntity>>());
    });
  });

  group('future date rejection', () {
    test('tomorrow → Err(ValidationException)', () async {
      final tomorrow = DateTime.now().toUtc().add(const Duration(days: 1));
      final result = await useCase(makeLog(date: tomorrow));
      expect(result, isA<Err<DailyLogEntity>>());
      expect(
        (result as Err<DailyLogEntity>).error,
        isA<ValidationException>(),
      );
    });

    test('today → Ok', () async {
      final today = DateTime.now().toUtc();
      final result = await useCase(makeLog(date: today));
      expect(result, isA<Ok<DailyLogEntity>>());
    });

    test('yesterday → Ok', () async {
      final yesterday =
          DateTime.now().toUtc().subtract(const Duration(days: 1));
      final result = await useCase(makeLog(date: yesterday));
      expect(result, isA<Ok<DailyLogEntity>>());
    });
  });

  group('painIntensity validation', () {
    test('painIntensity 0 → Ok', () async {
      final result = await useCase(makeLog(painIntensity: 0));
      expect(result, isA<Ok<DailyLogEntity>>());
    });

    test('painIntensity 3 → Ok', () async {
      final result = await useCase(makeLog(painIntensity: 3));
      expect(result, isA<Ok<DailyLogEntity>>());
    });

    test('painIntensity 4 → Err(ValidationException)', () async {
      final result = await useCase(makeLog(painIntensity: 4));
      expect(result, isA<Err<DailyLogEntity>>());
      expect(
        (result as Err<DailyLogEntity>).error,
        isA<ValidationException>(),
      );
    });

    test('painIntensity -1 → Err(ValidationException)', () async {
      final result = await useCase(makeLog(painIntensity: -1));
      expect(result, isA<Err<DailyLogEntity>>());
    });

    test('null painIntensity → Ok', () async {
      final result = await useCase(makeLog(painIntensity: null));
      expect(result, isA<Ok<DailyLogEntity>>());
    });
  });

  group('date normalization', () {
    test('date with time component is normalized to UTC midnight', () async {
      final withTime = DateTime.utc(2026, 3, 10, 14, 30, 0);
      final result = await useCase(makeLog(date: withTime));
      expect(result, isA<Ok<DailyLogEntity>>());
      final saved = (result as Ok<DailyLogEntity>).value;
      expect(saved.date, DateTime.utc(2026, 3, 10));
    });

    test('repo receives UTC-midnight date', () async {
      final withTime = DateTime.utc(2026, 3, 10, 14, 30, 0);
      await useCase(makeLog(date: withTime));
      expect(repo.savedLogs.last.date, DateTime.utc(2026, 3, 10));
    });
  });

  test('valid log is persisted to repository', () async {
    final log = makeLog(flow: FlowIntensity.medium);
    await useCase(log);
    expect(repo.savedLogs, hasLength(1));
  });
}
