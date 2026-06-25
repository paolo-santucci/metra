// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
// SPDX-License-Identifier: GPL-3.0-or-later

sealed class BackupState {
  const BackupState();
}

class BackupNotConnected extends BackupState {
  const BackupNotConnected();
}

class BackupConnected extends BackupState {
  const BackupConnected({
    required this.email,
    required this.autoBackupActive,
    required this.passphraseSet,
    this.lastBackupAt,
  });
  final String? email;
  final bool autoBackupActive; // true ⇔ !backupSuspended && passphraseSet
  final bool passphraseSet; // derived from secure-storage read in build()
  final DateTime? lastBackupAt;
}

enum BackupOperation { connecting, backingUp, restoring, disconnecting }

class BackupRunning extends BackupState {
  const BackupRunning(this.operation);
  final BackupOperation operation;
}

class BackupErrorState extends BackupState {
  const BackupErrorState(this.message);
  final String message;
}
