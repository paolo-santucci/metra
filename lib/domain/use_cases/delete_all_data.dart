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

import '../../core/constants/app_constants.dart';
import '../entities/sync_log_entity.dart';
import '../repositories/app_settings_repository.dart';
import '../repositories/cycle_entry_repository.dart';
import '../repositories/daily_log_repository.dart';

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
    // EC-08: provider reset + suspended sentinel are written atomically before
    // the secure-storage passphrase wipe, ensuring the persisted state is always
    // "disconnected, no passphrase, default provider" after a delete-all.
    // FR-21: reset activeProvider to default via dedicated writer (NOT bulk save).
    await _settingsRepo.setActiveProvider(SyncProvider.dropbox);
    await _settingsRepo.updateBackupSuspended(true);
    // BUG-B03: wipe cached passphrase so a fresh post-wipe install does not
    // read a stale value and report 'Backup automatico attivo' without a
    // user-entered passphrase. HC-2 ordering: both sentinel writes above have
    // completed before this delete fires, so the read-time guard is consistent.
    // FR-23: key from shared constant — no inline literal.
    await _secureStorage.delete(key: AppConstants.kBackupPassphraseKey);
  }
}
