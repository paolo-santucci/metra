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
import 'backup_data.dart';

class RestoreData {
  const RestoreData(this._runner);
  final BackupRunner _runner;

  /// Executes a restore from the backup identified by [filename].
  ///
  /// When [filename] is `null`, the runner uses the legacy "newest file" path.
  ///
  /// Returns [Ok] with the number of daily-log rows restored on success,
  /// or [Err] with the encountered [MetraException] on failure.
  Future<Result<int>> call({String? filename}) async {
    try {
      final count = await _runner.restore(filename: filename);
      return Ok(count);
    } on MetraException catch (e) {
      return Err(e);
    } catch (e) {
      return Err(SyncException('Restore failed: $e'));
    }
  }
}
