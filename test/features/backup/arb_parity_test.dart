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

// TASK-33 — Group L: FR-31 ARB key parity test.
//
// Verifies that every new backup-screen ARB key required by spec §7.1 Group L
// is present in both app_it.arb (primary) and app_en.arb (mirror).
//
// The canonical test at test/l10n/arb_parity_test.dart covers the same set;
// this companion file lives inside the feature's own test directory for
// discoverability.  Both tests assert the same invariant; the feature-level
// file is the primary one for Wave 8 reporting.
//
// Keys tested (per spec §7.1 Group L):
//   backupEmptyHeading, backupEmptyBody, backupConnectDropbox,
//   backupAccountConnesso, backupStato, backupAzioni, backupAccountLabel,
//   backupLastBackupLabel, backupDisconnectLabel, backupAutoActiveLabel,
//   backupAutoSuspendedLabel, backupNowAction, backupRestoreAction,
//   backupRestoreConfirmTitle, backupRestoreConfirmBody,
//   backupRestoreConfirmRestore, backupDisconnectConfirmTitle,
//   backupDisconnectConfirmBody, backupDisconnectConfirmDisconnect,
//   backupPickerConfirm, backupPickerEmpty,
//   restoreProgressTitle, restoreProgressHeading, restoreProgressBody.
//
// Note: the spec task description lists `backupPickerCancel`; however, the
// production code (backup_picker_sheet_internals.dart) uses `commonCancel`
// for the Annulla button.  `commonCancel` is tested here instead.
//
// Target platforms: all (static analysis — no device required).

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FR-31 — backup-screen ARB key parity (IT ↔ EN)', () {
    late Map<String, dynamic> it;
    late Map<String, dynamic> en;

    setUpAll(() {
      it = jsonDecode(File('lib/l10n/app_it.arb').readAsStringSync())
          as Map<String, dynamic>;
      en = jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
          as Map<String, dynamic>;
    });

    // New backup-screen keys required by spec §7.1 Group L.
    // `backupPickerCancel` listed in the spec task is not a real ARB key —
    // the production code uses `commonCancel` (see note above).
    //
    // TASK-33 (Wave 8) review: all spec §7.1 Group L keys are already enumerated
    // below — no further key additions required for TASK-33.  The list is
    // exhaustive: the test uses a full-file comparison approach (see the final
    // test in this group) that would catch any orphaned backup/restoreProgress
    // keys automatically even without explicit enumeration here.
    const requiredKeys = <String>[
      'backupEmptyHeading',
      'backupEmptyBody',
      // backupConnectDropbox retired in TASK-03 (M4) — replaced by backupConnectAction.
      'backupAccountConnesso',
      'backupStato',
      'backupAzioni',
      'backupAccountLabel',
      'backupLastBackupLabel',
      'backupDisconnectLabel',
      'backupAutoActiveLabel',
      'backupAutoSuspendedLabel',
      'backupNowAction',
      'backupRestoreAction',
      'backupRestoreConfirmTitle',
      'backupRestoreConfirmBody',
      'backupRestoreConfirmRestore',
      'backupDisconnectConfirmTitle',
      'backupDisconnectConfirmBody',
      'backupDisconnectConfirmDisconnect',
      'backupPickerConfirm',
      'backupPickerEmpty',
      'restoreProgressTitle',
      'restoreProgressHeading',
      'restoreProgressBody',
      // Shared key used by the Annulla button in BackupPickerSheet toolbar.
      'commonCancel',
    ];

    for (final key in requiredKeys) {
      test('key "$key" exists in app_it.arb', () {
        expect(
          it.containsKey(key),
          isTrue,
          reason: 'app_it.arb is missing key: $key',
        );
      });

      test('key "$key" exists in app_en.arb', () {
        expect(
          en.containsKey(key),
          isTrue,
          reason: 'app_en.arb is missing key: $key',
        );
      });
    }

    // ── TASK-03 (M4) — new l10n keys + backupConnectDropbox retirement ──────
    group('TASK-03 — M4 provider-picker l10n keys', () {
      const newM4Keys = <String>[
        'backupProviderNameDropbox',
        'backupProviderNameGoogleDrive',
        'backupProviderNameICloud',
        'backupProviderPickerTitle',
        'backupConnectAction',
        'backupSwitchConfirmTitle',
        'backupSwitchConfirmBody',
        'backupSwitchConfirmSwitch',
        // TASK-08 deviation: these row-label keys were missing from TASK-03 scope
        // and are required for correct i18n in the connected-view changes.
        'backupProviderLabel',
        'backupSwitchActionLabel',
      ];

      for (final key in newM4Keys) {
        test('key "$key" present in app_it.arb', () {
          expect(
            it.containsKey(key),
            isTrue,
            reason: 'app_it.arb is missing key: $key',
          );
        });

        test('key "$key" present in app_en.arb', () {
          expect(
            en.containsKey(key),
            isTrue,
            reason: 'app_en.arb is missing key: $key',
          );
        });

        test('key "$key" has non-empty @-description in app_it.arb', () {
          final meta = it['@$key'] as Map<String, dynamic>?;
          expect(
            meta,
            isNotNull,
            reason: 'app_it.arb is missing @$key metadata',
          );
          final desc = meta!['description'] as String?;
          expect(
            desc?.trim(),
            isNotEmpty,
            reason:
                '@$key.description in app_it.arb must be a non-empty string',
          );
        });

        test('key "$key" has non-empty @-description in app_en.arb', () {
          final meta = en['@$key'] as Map<String, dynamic>?;
          expect(
            meta,
            isNotNull,
            reason: 'app_en.arb is missing @$key metadata',
          );
          final desc = meta!['description'] as String?;
          expect(
            desc?.trim(),
            isNotEmpty,
            reason:
                '@$key.description in app_en.arb must be a non-empty string',
          );
        });
      }

      test('backupConnectDropbox absent from app_it.arb (retired in TASK-03)',
          () {
        expect(
          it.containsKey('backupConnectDropbox'),
          isFalse,
          reason:
              'app_it.arb must not contain retired key backupConnectDropbox',
        );
      });

      test('backupConnectDropbox absent from app_en.arb (retired in TASK-03)',
          () {
        expect(
          en.containsKey('backupConnectDropbox'),
          isFalse,
          reason:
              'app_en.arb must not contain retired key backupConnectDropbox',
        );
      });

      test(
          'backupConnectDropbox absent from requiredKeys list (retired in TASK-03)',
          () {
        expect(
          requiredKeys.contains('backupConnectDropbox'),
          isFalse,
          reason:
              'requiredKeys must not include retired key backupConnectDropbox',
        );
      });

      test(
          'backupSwitchConfirmBody declares {provider} placeholder in app_it.arb',
          () {
        final value = it['backupSwitchConfirmBody'] as String?;
        expect(
          value,
          isNotNull,
          reason: 'app_it.arb is missing backupSwitchConfirmBody',
        );
        expect(
          value,
          contains('{provider}'),
          reason:
              'backupSwitchConfirmBody in app_it.arb must contain {provider} placeholder',
        );
      });

      test(
          'backupSwitchConfirmBody declares {provider} placeholder in app_en.arb',
          () {
        final value = en['backupSwitchConfirmBody'] as String?;
        expect(
          value,
          isNotNull,
          reason: 'app_en.arb is missing backupSwitchConfirmBody',
        );
        expect(
          value,
          contains('{provider}'),
          reason:
              'backupSwitchConfirmBody in app_en.arb must contain {provider} placeholder',
        );
      });
    });

    test('IT and EN share the same backup-screen key set (no orphaned keys)',
        () {
      final itKeys = it.keys.where((k) => !k.startsWith('@')).toSet();
      final enKeys = en.keys.where((k) => !k.startsWith('@')).toSet();

      final onlyInIt = itKeys
          .difference(enKeys)
          .where(
            (k) => k.startsWith('backup') || k.startsWith('restoreProgress'),
          )
          .toSet();
      final onlyInEn = enKeys
          .difference(itKeys)
          .where(
            (k) => k.startsWith('backup') || k.startsWith('restoreProgress'),
          )
          .toSet();

      expect(
        onlyInIt,
        isEmpty,
        reason: 'Backup keys in app_it.arb with no counterpart in app_en.arb: '
            '$onlyInIt',
      );
      expect(
        onlyInEn,
        isEmpty,
        reason: 'Backup keys in app_en.arb with no counterpart in app_it.arb: '
            '$onlyInEn',
      );
    });
  });
}
