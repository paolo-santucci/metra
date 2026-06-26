// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
// SPDX-License-Identifier: GPL-3.0-or-later

import '../../../domain/entities/sync_log_entity.dart';

sealed class BackupState {
  const BackupState();
}

class BackupNotConnected extends BackupState {
  const BackupNotConnected();
}

class BackupConnected extends BackupState {
  const BackupConnected({
    required this.provider,
    required this.email,
    required this.autoBackupActive,
    required this.passphraseSet,
    this.lastBackupAt,
  });

  /// The cloud backup provider that is currently connected (FR-15, OQ-06).
  ///
  /// Populated in [BackupNotifier.build()] from [AppSettingsData.activeProvider]
  /// so that the connected view can render the active provider's display name
  /// without re-reading settings (single read, no stale-read hazard).
  final SyncProvider provider;
  final String? email;
  final bool autoBackupActive; // true ⇔ !backupSuspended && passphraseSet
  final bool passphraseSet; // derived from secure-storage read in build()
  final DateTime? lastBackupAt;
}

/// Transient UI enum tracking which backup operation is in progress.
///
/// NEVER persisted in the database or included in any [_toCompanion] /
/// serialisation path.  Member order is irrelevant — always resolve via
/// exhaustive switch, never by index.
enum BackupOperation {
  connecting,
  backingUp,
  restoring,
  disconnecting,

  /// A provider-switch is in progress (TASK-04 / OQ-07).
  ///
  /// Transient — surfaced to the UI so running-body shows the in-progress
  /// overlay during [BackupNotifier.switchProvider].  Never written to the DB.
  switching,
}

class BackupRunning extends BackupState {
  const BackupRunning(this.operation);
  final BackupOperation operation;
}

class BackupErrorState extends BackupState {
  const BackupErrorState(this.message);
  final String message;
}
