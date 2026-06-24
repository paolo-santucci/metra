// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
// SPDX-License-Identifier: GPL-3.0-or-later

// ignore_for_file: avoid_print

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // ── Test 3 (BUG-B05, updated by M1 FR-23) — single passphrase-key source ────
  //
  // Guards against re-introduction of the literal 'metra_backup_passphrase_v1'
  // outside its single source of truth. M1 FR-23 moved that single source from
  // backup_notifier.dart to lib/core/constants/app_constants.dart
  // (AppConstants.kBackupPassphraseKey), so it is import-safe from both the
  // domain (delete_all_data.dart) and feature (backup_notifier.dart) layers.
  // After FR-23 the literal must appear exactly ONCE across lib/ — in
  // app_constants.dart only; every consumer references the constant.
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
      final constantsFile = File(
        'lib/core/constants/app_constants.dart',
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
      expect(
        constantsFile.existsSync(),
        isTrue,
        reason: 'app_constants.dart must exist',
      );

      // Count occurrences of the literal string in each file.
      final orchestratorCount =
          orchestratorFile.readAsStringSync().split(literal).length - 1;
      final notifierCount =
          notifierFile.readAsStringSync().split(literal).length - 1;
      final constantsCount =
          constantsFile.readAsStringSync().split(literal).length - 1;

      // After FR-23: the literal lives ONLY in app_constants.dart (exactly once,
      // at kBackupPassphraseKey). Both consumers — sync_orchestrator.dart and
      // backup_notifier.dart — must reference the constant, never the literal.
      expect(
        orchestratorCount,
        equals(0),
        reason: 'sync_orchestrator.dart must not contain the literal '
            "'$literal' — it must reference the shared constant instead",
      );
      expect(
        notifierCount,
        equals(0),
        reason: 'backup_notifier.dart must not contain the literal '
            "'$literal' — FR-23 moved it to AppConstants.kBackupPassphraseKey; "
            'kPassphraseKey must reference that constant',
      );
      expect(
        constantsCount,
        equals(1),
        reason: "app_constants.dart must contain the literal '$literal' "
            'exactly once (the kBackupPassphraseKey definition — the single '
            'source of truth after FR-23)',
      );
    },
  );
}
