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
import 'package:metra/domain/entities/daily_log_entity.dart';
import 'package:metra/domain/use_cases/get_month_logs.dart';

import '../../helpers/fake_daily_log_repository.dart';

void main() {
  late FakeDailyLogRepository repo;
  late GetMonthLogs useCase;

  setUp(() {
    repo = FakeDailyLogRepository();
    useCase = GetMonthLogs(repo);
  });

  test('returns empty stream for a month with no logs', () async {
    final result = await useCase(2026, 3).first;
    expect(result, isEmpty);
  });

  test('returns only logs matching the requested month', () async {
    await repo.saveDailyLog(
      DailyLogEntity(date: DateTime.utc(2026, 1, 10)),
    );
    await repo.saveDailyLog(
      DailyLogEntity(date: DateTime.utc(2026, 2, 5)),
    );
    await repo.saveDailyLog(
      DailyLogEntity(date: DateTime.utc(2026, 1, 20)),
    );

    final janLogs = await useCase(2026, 1).first;
    expect(janLogs, hasLength(2));
    expect(janLogs.map((l) => l.date.month), everyElement(equals(1)));

    final febLogs = await useCase(2026, 2).first;
    expect(febLogs, hasLength(1));
  });
}
