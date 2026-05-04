// Copyright (C) 2024 Paolo Santucci
//
// This file is part of Métra.
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:metra/data/services/backup/backup_service.dart';
import 'package:metra/domain/entities/daily_log_entity.dart';
import 'package:metra/domain/entities/pain_symptom_data.dart';
import 'package:metra/domain/entities/pain_symptom_type.dart';

import '../../../helpers/fake_daily_log_repository.dart';

void main() {
  test('buildSnapshot with empty repo returns empty snapshot', () async {
    final repo = FakeDailyLogRepository();
    final svc = BackupService(repo);
    final snap = await svc.buildSnapshot();
    expect(snap.version, 2);
    expect(snap.logsWithSymptoms, isEmpty);
  });

  test('buildSnapshot pulls logs and their symptoms', () async {
    final repo = FakeDailyLogRepository();
    final log1 = DailyLogEntity(date: DateTime.utc(2026, 4, 28));
    final log2 = DailyLogEntity(
      date: DateTime.utc(2026, 4, 29),
      painEnabled: true,
    );
    final symptoms2 = [
      const PainSymptomData(symptomType: PainSymptomType.headache),
    ];
    repo.savedLogs.addAll([log1, log2]);
    repo.symptoms[log2.date] = symptoms2;

    final svc = BackupService(repo);
    final snap = await svc.buildSnapshot();

    expect(snap.version, 2);
    expect(snap.logsWithSymptoms, hasLength(2));
    expect(snap.logsWithSymptoms[0].log, log1);
    expect(snap.logsWithSymptoms[0].symptoms, isEmpty);
    expect(snap.logsWithSymptoms[1].log, log2);
    expect(snap.logsWithSymptoms[1].symptoms, symptoms2);
  });
}
