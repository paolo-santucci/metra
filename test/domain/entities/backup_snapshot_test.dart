// Copyright (C) 2024 Paolo Santucci
//
// This file is part of Métra.
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/errors/metra_exception.dart';
import 'package:metra/domain/entities/backup_snapshot.dart';
import 'package:metra/domain/entities/daily_log_entity.dart';
import 'package:metra/domain/entities/daily_log_with_symptoms.dart';
import 'package:metra/domain/entities/flow_intensity.dart';
import 'package:metra/domain/entities/flow_type.dart';
import 'package:metra/domain/entities/pain_symptom_data.dart';
import 'package:metra/domain/entities/pain_symptom_type.dart';

void main() {
  group('BackupSnapshot encode/decode round-trip', () {
    test('empty snapshot', () {
      final s = BackupSnapshot(
        version: 1,
        exportedAt: DateTime.utc(2026, 4, 29),
        logsWithSymptoms: const [],
      );
      final decoded = BackupSnapshot.decode(s.encode());
      expect(decoded.version, 1);
      expect(decoded.exportedAt, s.exportedAt);
      expect(decoded.logsWithSymptoms, isEmpty);
    });

    test('snapshot with log and symptoms survives round-trip', () {
      final log = DailyLogEntity(
        date: DateTime.utc(2026, 4, 29),
        flowType: FlowType.mestruazioni,
        flowIntensity: FlowIntensity.medium,
        painEnabled: true,
        painIntensity: 2,
      );
      final symptoms = [
        const PainSymptomData(symptomType: PainSymptomType.cramps),
        const PainSymptomData(
          symptomType: PainSymptomType.custom,
          customLabel: 'jaw',
        ),
      ];
      final s = BackupSnapshot(
        version: BackupSnapshot.currentVersion,
        exportedAt: DateTime.utc(2026, 4, 29),
        logsWithSymptoms: [DailyLogWithSymptoms(log: log, symptoms: symptoms)],
      );
      final decoded = BackupSnapshot.decode(s.encode());
      expect(decoded.logsWithSymptoms, hasLength(1));
      final dlws = decoded.logsWithSymptoms.first;
      expect(dlws.log.date, log.date);
      expect(dlws.log.flowIntensity, FlowIntensity.medium);
      expect(dlws.log.painIntensity, 2);
      expect(dlws.symptoms, hasLength(2));
      expect(dlws.symptoms[1].customLabel, 'jaw');
    });
  });

  group('BackupSnapshot.decode rejects invalid input', () {
    test('non-JSON throws BackupFormatException', () {
      expect(
        () => BackupSnapshot.decode('not json'),
        throwsA(isA<BackupFormatException>()),
      );
    });
    test('missing version throws', () {
      expect(
        () => BackupSnapshot.decode('{}'),
        throwsA(isA<BackupFormatException>()),
      );
    });
    test('unsupported version throws', () {
      expect(
        () => BackupSnapshot.decode(
          '{"version":99,"exported_at":"2026-04-29T00:00:00.000Z","daily_logs":[]}',
        ),
        throwsA(isA<BackupFormatException>()),
      );
    });
    test('invalid date throws', () {
      expect(
        () => BackupSnapshot.decode(
          '{"version":1,"exported_at":"not-a-date","daily_logs":[]}',
        ),
        throwsA(isA<BackupFormatException>()),
      );
    });
    test('out-of-range flow_intensity throws', () {
      const bad =
          '{"version":1,"exported_at":"2026-04-29T00:00:00.000Z","daily_logs":[{"date":"2026-04-29T00:00:00.000Z","flow_intensity":99,"pain_symptoms":[]}]}';
      expect(
        () => BackupSnapshot.decode(bad),
        throwsA(isA<BackupFormatException>()),
      );
    });
  });
}
