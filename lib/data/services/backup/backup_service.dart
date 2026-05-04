// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
// SPDX-License-Identifier: GPL-3.0-or-later

import '../../../domain/entities/backup_snapshot.dart';
import '../../../domain/entities/daily_log_with_symptoms.dart';
import '../../../domain/repositories/daily_log_repository.dart';

class BackupService {
  const BackupService(this._logRepo);
  final DailyLogRepository _logRepo;

  Future<BackupSnapshot> buildSnapshot() async {
    final logs = await _logRepo.getAllOrderedByDate();
    final logsWithSymptoms = <DailyLogWithSymptoms>[];
    for (final log in logs) {
      final symptoms = await _logRepo.getPainSymptoms(log.date);
      logsWithSymptoms.add(
        DailyLogWithSymptoms(log: log, symptoms: symptoms),
      );
    }
    return BackupSnapshot(
      version: BackupSnapshot.currentVersion,
      exportedAt: DateTime.now().toUtc(),
      logsWithSymptoms: logsWithSymptoms,
    );
  }
}
