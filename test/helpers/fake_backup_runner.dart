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

import 'package:metra/domain/use_cases/backup_data.dart';

/// Shared test double for [BackupRunner].
///
/// Captures [lastFilename] and [restoreCallCount] so tests can assert that
/// [RestoreData] and [BackupNotifier] forward the `filename` parameter
/// through the stack without modification.
///
/// Inject errors via [restoreError] / [backupError] to exercise exception
/// paths.
class FakeBackupRunner implements BackupRunner {
  Object? backupError;
  Object? restoreError;

  bool backupCalled = false;
  int backupCallCount = 0;
  int restoreCallCount = 0;

  /// Configurable count returned by [restore] on the happy path.
  ///
  /// Defaults to 0; set to a positive value to test callers that propagate
  /// the restored-log count (e.g. [RestoreData], [BackupNotifier.restore]).
  int restoreReturnValue = 0;

  /// The `filename` argument last received by [restore]. Stays `null` when
  /// [restore] has not been called, or when it was called with `filename: null`
  /// (legacy newest-path).
  String? lastFilename;

  @override
  Future<void> backup() async {
    backupCalled = true;
    backupCallCount++;
    if (backupError != null) throw backupError!;
  }

  @override
  Future<int> restore({String? filename}) async {
    restoreCallCount++;
    lastFilename = filename;
    if (restoreError != null) throw restoreError!;
    return restoreReturnValue;
  }
}
