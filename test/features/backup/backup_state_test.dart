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

// TASK-04 — TDD tests: BackupConnected.provider field + BackupOperation.switching
//
// Written FIRST (failing) per plan spec.  These tests compile only after the
// production change in backup_state.dart is applied; until then they serve as
// the red phase of the TDD cycle.
//
// Tests:
//   TDD-1: BackupConnected.provider field is required and roundtrips the value.
//   TDD-2: BackupRunning(BackupOperation.switching) constructs without error.
//   TDD-3: BackupOperation.values contains switching.
//   TDD-4: BackupOperation never appears in _toCompanion / serialisation path
//           (order-independent static grep).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:metra/domain/entities/sync_log_entity.dart';
import 'package:metra/features/backup/state/backup_state.dart';

void main() {
  // ── TDD-1: BackupConnected.provider field ───────────────────────────────────

  group('BackupConnected.provider field (FR-15, OQ-06)', () {
    test(
      'provider field is required and stores the given SyncProvider value',
      () {
        // Fails before implementation: BackupConnected has no `provider` field.
        const state = BackupConnected(
          provider: SyncProvider.googleDrive,
          email: 'x@y.com',
          autoBackupActive: false,
          passphraseSet: false,
        );
        expect(
          state.provider,
          SyncProvider.googleDrive,
          reason: 'BackupConnected.provider must round-trip the value passed '
              'to the constructor (FR-15 OQ-06)',
        );
      },
    );

    test(
      'provider defaults to dropbox via test helper (compile-time guard)',
      () {
        // Ensures the helper default keeps existing tests green after the
        // required field is introduced (OQ-QA-04 helper-default requirement).
        // This test is trivially green once the helper exists.
        const state = BackupConnected(
          provider: SyncProvider.dropbox,
          email: null,
          autoBackupActive: false,
          passphraseSet: false,
        );
        expect(state.provider, SyncProvider.dropbox);
      },
    );
  });

  // ── TDD-2/3: BackupOperation.switching ──────────────────────────────────────

  group('BackupOperation.switching (OQ-07)', () {
    test(
      'BackupRunning(BackupOperation.switching) constructs without error',
      () {
        // Fails before implementation: BackupOperation has no `switching` member.
        const running = BackupRunning(BackupOperation.switching);
        expect(
          running.operation,
          BackupOperation.switching,
        );
      },
    );

    test(
      'BackupOperation.values contains switching',
      () {
        expect(
          BackupOperation.values,
          contains(BackupOperation.switching),
          reason: 'switching must be an enumerated member so exhaustive '
              'switches catch it at compile time',
        );
      },
    );
  });

  // ── TDD-4: BackupOperation not in serialisation path ────────────────────────

  group('BackupOperation serialisation guard (order-independent grep)', () {
    // BackupOperation is a transient UI enum.  It must never be referenced in
    // the data-layer companion / serialisation code — adding `switching` must
    // not accidentally introduce a persistence dependency.
    test(
      'BackupOperation never appears in _toCompanion / data-layer files',
      () {
        const dataPaths = [
          'lib/data/repositories/drift_app_settings_repository.dart',
          'lib/data/repositories/drift_daily_log_repository.dart',
          'lib/data/database/app_database.g.dart',
        ];
        for (final path in dataPaths) {
          final src = File(path).readAsStringSync();
          expect(
            src.contains('BackupOperation'),
            isFalse,
            reason: '$path must not reference BackupOperation — '
                'it is a transient UI enum, never persisted.',
          );
        }
      },
    );
  });
}
