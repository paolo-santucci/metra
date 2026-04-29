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

import '../../core/errors/metra_exception.dart';
import '../../core/utils/result.dart';

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
