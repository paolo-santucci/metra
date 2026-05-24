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

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../repositories/app_settings_repository.dart';
import '../repositories/cycle_entry_repository.dart';
import '../repositories/daily_log_repository.dart';

// Same value as BackupNotifier.kPassphraseKey — kept in sync by code review.
// Do NOT import from lib/features/ (CLAUDE.md §4 domain layering).
const _kPassphraseKey = 'metra_backup_passphrase_v1';

class DeleteAllData {
  const DeleteAllData(
    this._logRepo,
    this._cycleRepo,
    this._settingsRepo,
    this._secureStorage, // BUG-B03: injected for passphrase wipe on delete-all
  );

  final DailyLogRepository _logRepo;
  final CycleEntryRepository _cycleRepo;
  final AppSettingsRepository _settingsRepo;
  final FlutterSecureStorage _secureStorage;

  Future<void> execute() async {
    await _logRepo.deleteAll();
    await _cycleRepo.deleteAll();
    await _settingsRepo.updateBackupSuspended(true);
    // BUG-B03: wipe cached passphrase so a fresh post-wipe install does not
    // read a stale value and report 'Backup automatico attivo' without a
    // user-entered passphrase. HC-2 ordering: the suspended-sentinel write
    // already preceded this delete, so the read-time guard is consistent.
    await _secureStorage.delete(key: _kPassphraseKey);
  }
}
