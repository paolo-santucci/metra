// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
// SPDX-License-Identifier: GPL-3.0-or-later
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

// TASK-04 — Shared test helpers for BackupConnected construction.
//
// Provides a single factory function that insulates all test files from direct
// BackupConnected constructor call-sites.  When BackupConnected gains a new
// required field, only this file needs to update the default — existing tests
// that call makeBackupConnected() remain green without modification
// (OQ-QA-04 helper-default requirement).

import 'package:metra/domain/entities/sync_log_entity.dart';
import 'package:metra/features/backup/state/backup_state.dart';

/// Creates a [BackupConnected] state with sensible test defaults.
///
/// Every required field has a default so call-sites that do not care about
/// a particular field need not specify it.  The [provider] defaults to
/// [SyncProvider.dropbox] to preserve the behaviour of tests written before
/// TASK-04 introduced the required field (OQ-QA-04).
BackupConnected makeBackupConnected({
  SyncProvider provider = SyncProvider.dropbox,
  String? email = 'test@example.com',
  bool autoBackupActive = false,
  bool passphraseSet = false,
  DateTime? lastBackupAt,
}) {
  return BackupConnected(
    provider: provider,
    email: email,
    autoBackupActive: autoBackupActive,
    passphraseSet: passphraseSet,
    lastBackupAt: lastBackupAt,
  );
}
