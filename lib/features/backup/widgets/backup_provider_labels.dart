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

// TASK-03 (M4) — Provider display-name helper.
//
// Provides a single, exhaustive mapping from each SyncProvider member to its
// l10n string.  All consumers (picker rows, connected-view name row) must use
// this helper — never derive the display name from dropboxEmail or any other
// account-specific field.
//
// The switch is exhaustive (no default) so that adding a new SyncProvider
// member produces a compile error instead of a silent empty string.

import '../../../domain/entities/sync_log_entity.dart';
import '../../../l10n/app_localizations.dart';

/// Returns the localised display name for [id] using the canonical
/// `backupProviderName*` l10n keys.
///
/// The switch is intentionally exhaustive with no `default` clause — adding a
/// new [SyncProvider] member without updating this function is a compile error.
String backupProviderDisplayName(AppLocalizations l10n, SyncProvider id) {
  switch (id) {
    case SyncProvider.dropbox:
      return l10n.backupProviderNameDropbox;
    case SyncProvider.googleDrive:
      return l10n.backupProviderNameGoogleDrive;
    case SyncProvider.iCloud:
      return l10n.backupProviderNameICloud;
  }
}
