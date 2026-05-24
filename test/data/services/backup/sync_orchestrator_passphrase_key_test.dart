// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
// SPDX-License-Identifier: GPL-3.0-or-later

// ignore_for_file: avoid_print

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // ── Test 3 (BUG-B05) — sync_orchestrator references public key constant ────
  //
  // Guards against re-introduction of the literal 'metra_backup_passphrase_v1'
  // in sync_orchestrator.dart. After T-A the literal must appear exactly ONCE
  // across lib/ (in backup_notifier.dart:24 only).
  //
  // This is a source-level assertion, not a runtime test — it reads the actual
  // .dart files on disk and greps for the literal string.
  test(
    'sync_orchestrator_uses_backup_notifier_passphrase_key_constant',
    () {
      const literal = 'metra_backup_passphrase_v1';

      // Paths relative to the project root.
      final orchestratorFile = File(
        'lib/data/services/backup/sync_orchestrator.dart',
      );
      final notifierFile = File(
        'lib/features/backup/state/backup_notifier.dart',
      );

      expect(
        orchestratorFile.existsSync(),
        isTrue,
        reason: 'sync_orchestrator.dart must exist',
      );
      expect(
        notifierFile.existsSync(),
        isTrue,
        reason: 'backup_notifier.dart must exist',
      );

      // Count occurrences of the literal string in both files.
      final orchestratorCount =
          orchestratorFile.readAsStringSync().split(literal).length - 1;
      final notifierCount =
          notifierFile.readAsStringSync().split(literal).length - 1;

      // After T-A: orchestrator must have zero occurrences (deduped to public
      // constant). Notifier must have exactly one (the kPassphraseKey definition
      // at line 24). Total across the two files must be exactly 1.
      expect(
        orchestratorCount,
        equals(0),
        reason: 'sync_orchestrator.dart must not contain the literal '
            "'$literal' — it must reference BackupNotifier.kPassphraseKey instead",
      );
      expect(
        notifierCount,
        equals(1),
        reason: "backup_notifier.dart must contain the literal '$literal' "
            'exactly once (at the kPassphraseKey constant definition)',
      );
    },
  );
}
