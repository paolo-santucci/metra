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
import 'package:metra/domain/entities/flow_intensity.dart';
import 'package:metra/domain/entities/flow_type.dart';
import 'package:metra/domain/entities/pain_symptom_data.dart';
import 'package:metra/domain/entities/pain_symptom_type.dart';
import 'package:metra/domain/use_cases/export_daily_logs.dart';

import '../../helpers/fake_daily_log_repository.dart';

void main() {
  late FakeDailyLogRepository fakeRepo;
  late ExportDailyLogs useCase;

  setUp(() {
    fakeRepo = FakeDailyLogRepository();
    useCase = ExportDailyLogs(fakeRepo);
  });

  test('empty repository → header-only CSV string', () async {
    final csv = await useCase.execute();
    final lines = csv.replaceAll('\r\n', '\n').trim().split('\n');
    expect(lines, hasLength(1));
    expect(
      lines.first,
      'date,flow_type,flow,other_discharge,pain_intensity,symptoms,notes,cycle_start,pain_enabled,notes_enabled',
    );
  });

  test('3 logs with symptoms → CSV contains header + 3 data rows', () async {
    await fakeRepo.saveDailyLog(
      DailyLogEntity(
        date: DateTime.utc(2026, 1, 1),
        flowType: FlowType.mestruazioni,
        flowIntensity: FlowIntensity.heavy,
      ),
    );
    await fakeRepo.saveDailyLog(
      DailyLogEntity(
        date: DateTime.utc(2026, 2, 1),
        flowType: FlowType.mestruazioni,
        flowIntensity: FlowIntensity.light,
      ),
    );
    await fakeRepo.saveDailyLog(
      DailyLogEntity(date: DateTime.utc(2026, 3, 1)),
    );
    await fakeRepo.replacePainSymptoms(
      DateTime.utc(2026, 1, 1),
      [const PainSymptomData(symptomType: PainSymptomType.cramps)],
    );

    final csv = await useCase.execute();
    final lines = csv.replaceAll('\r\n', '\n').trim().split('\n');
    // header + 3 data rows
    expect(lines, hasLength(4));
  });

  test('first flow day in a new cycle group has cycle_start = 1', () async {
    // Two cycles: first starts 2026-01-01, second starts 2026-02-05
    // (gap > 21 days so they form separate cycle groups).
    await fakeRepo.saveDailyLog(
      DailyLogEntity(
        date: DateTime.utc(2026, 1, 1),
        flowType: FlowType.mestruazioni,
        flowIntensity: FlowIntensity.medium,
      ),
    );
    await fakeRepo.saveDailyLog(
      DailyLogEntity(
        date: DateTime.utc(2026, 2, 5),
        flowType: FlowType.mestruazioni,
        flowIntensity: FlowIntensity.medium,
      ),
    );

    final csv = await useCase.execute();
    final lines = csv.replaceAll('\r\n', '\n').trim().split('\n');
    // Both flow days are cycle starts (cycle_start is column index 7).
    expect(lines[1].split(',')[7], '1'); // 2026-01-01
    expect(lines[2].split(',')[7], '1'); // 2026-02-05
  });

  test('non-cycle-start day has cycle_start = 0', () async {
    // Only one log with no flow — not a cycle start.
    await fakeRepo.saveDailyLog(DailyLogEntity(date: DateTime.utc(2026, 1, 1)));

    final csv = await useCase.execute();
    final lines = csv.replaceAll('\r\n', '\n').trim().split('\n');
    expect(lines[1].split(',')[7], '0');
  });
}
