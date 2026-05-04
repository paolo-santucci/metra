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
  Future<void> restore();
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
