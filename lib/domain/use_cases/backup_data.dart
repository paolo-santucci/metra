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
  /// When [filename] is `null`, the runner falls back to the legacy
  /// "newest file" path — preserving pre-FR-14 behaviour for callers that
  /// do not (yet) supply an explicit file selection.
  Future<void> restore({String? filename});
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
