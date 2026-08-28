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

import 'dart:typed_data';

import 'package:metra/domain/entities/sync_log_entity.dart';

import 'backup_file_entry.dart';

/// Abstract interface for all cloud backup providers.
///
/// Implementations must NOT leak provider-specific types (HTTP clients,
/// OAuth libraries, crypto packages) through this interface — that
/// isolation is the whole point of FR-01. The interface imports only
/// domain types ([SyncProvider]) and sibling data types ([BackupFileEntry]).
abstract class CloudBackupProvider {
  Future<void> upload(Uint8List blob, String filename);
  Future<Uint8List> download(String filename);
  Future<List<BackupFileEntry>> listFiles();
  Future<void> deleteFile(String filename);

  // Widening additions (C-08: additive-only)
  Future<void> authorize();
  Future<String?> currentEmail();
  Future<void> disconnect();

  /// The [SyncProvider] enum value identifying this provider.
  ///
  /// Used by [SyncOrchestrator] to stamp log entries with the active provider
  /// without relying on `runtimeType` (FR-02, FR-17).
  SyncProvider get id;
}
