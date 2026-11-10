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
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ARB parity — new backup screen keys', () {
    test('every new backup key exists in both app_it.arb and app_en.arb', () {
      final it = jsonDecode(
        File('lib/l10n/app_it.arb').readAsStringSync(),
      ) as Map<String, dynamic>;
      final en = jsonDecode(
        File('lib/l10n/app_en.arb').readAsStringSync(),
      ) as Map<String, dynamic>;

      const newBackupKeys = [
        'backupEmptyHeading',
        'backupEmptyBody',
        // backupConnectDropbox retired in TASK-03 (M4) — replaced by backupConnectAction.
        'backupConnectAction',
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
        'commonCancel',
      ];

      for (final k in newBackupKeys) {
        expect(it.containsKey(k), isTrue, reason: 'IT missing $k');
        expect(en.containsKey(k), isTrue, reason: 'EN missing $k');
      }
    });
  });

  // TASK-05 (FR-01, FR-02, FR-10, FR-11, FR-15, FR-17, NFR-06): the six
  // Archivio filter/search keys, added to the IT template and mirrored in EN.
  group('ARB parity — Archivio filter/search keys', () {
    late Map<String, dynamic> it;
    late Map<String, dynamic> en;

    const keys = [
      'timeline_search_hint',
      'timeline_search_clear_a11y',
      'timeline_filters_toggle_a11y',
      'timeline_filter_results_count',
      'timeline_filter_clear_all',
      'timeline_filter_no_match',
      'timeline_filter_no_match_action',
    ];

    setUpAll(() {
      it = jsonDecode(File('lib/l10n/app_it.arb').readAsStringSync())
          as Map<String, dynamic>;
      en = jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
          as Map<String, dynamic>;
    });

    test('every key exists in both ARBs with @-metadata (NFR-06)', () {
      for (final k in keys) {
        expect(it.containsKey(k), isTrue, reason: 'IT missing $k');
        expect(en.containsKey(k), isTrue, reason: 'EN missing $k');
        expect(
          it.containsKey('@$k'),
          isTrue,
          reason: 'IT missing @$k metadata',
        );
        expect(
          en.containsKey('@$k'),
          isTrue,
          reason: 'EN missing @$k metadata',
        );
      }
    });

    test('the funnel toggle label is mirrored with its copy', () {
      // §10.1 operator decision: the funnel beside the search field names the
      // surface it reveals.
      expect(it['timeline_filters_toggle_a11y'], 'Filtri sintomi');
      expect(en['timeline_filters_toggle_a11y'], 'Symptom filters');
    });

    test('the plural key declares an int count placeholder (NFR-06)', () {
      for (final arb in [it, en]) {
        final meta =
            arb['@timeline_filter_results_count'] as Map<String, dynamic>;
        final placeholders = meta['placeholders'] as Map<String, dynamic>;
        final count = placeholders['count'] as Map<String, dynamic>;

        expect(count['type'], 'int');
      }
    });

    test('the plural message keeps its ICU shape in both ARBs', () {
      expect(
        it['timeline_filter_results_count'],
        '{count, plural, =1{{count} ciclo} other{{count} cicli}}',
      );
      expect(
        en['timeline_filter_results_count'],
        '{count, plural, =1{{count} cycle} other{{count} cycles}}',
      );
    });

    test('copy follows the §13 register — no "!" and no emoji', () {
      final emojiPattern = RegExp(
        r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{2190}-\u{21FF}'
        r'\u{2B00}-\u{2BFF}\u{FE0F}]',
        unicode: true,
      );

      for (final arb in [it, en]) {
        for (final k in keys) {
          final value = arb[k] as String;

          expect(value.contains('!'), isFalse, reason: '$k has a "!"');
          expect(
            emojiPattern.hasMatch(value),
            isFalse,
            reason: '$k has an emoji',
          );
        }
      }
    });
  });
}
