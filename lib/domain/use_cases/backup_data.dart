// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
// SPDX-License-Identifier: GPL-3.0-or-later

import '../../core/errors/metra_exception.dart';
import '../../core/utils/result.dart';

/// Abstract interface keeping domain/ free of data-layer imports.
/// Implemented by [SyncOrchestrator].
abstract class BackupRunner {
  Future<void> backup();

  /// Restores data from the backup identified by [filename].
  ///
  /// Returns the number of daily-log rows restored from the snapshot
  /// (NOT including symptom rows — a date can carry both, and counting
  /// them separately would double-count user-facing days).
  ///
  /// When [filename] is null, the runner falls back to the newest-file
  /// legacy path — unchanged from FR-14.
  Future<int> restore({String? filename});
}

class BackupData {
  const BackupData(this._runner);
  final BackupRunner _runner;

  Future<Result<void>> call() async {
    try {
      await _runner.backup();
      return const Ok(null);
    } on MetraException catch (e) {
      return Err(e);
    } catch (e) {
      return Err(SyncException('Backup failed: $e'));
    }
  }
}
