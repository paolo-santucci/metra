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

// Tests for TASK-02 (FR-10, FR-07, NFR-03, spec §7.1 Group N):
//   notification_channel_name + onboarding_language_selector_label exist in
//   both app_it.arb and app_en.arb, both files parse as valid JSON, the
//   selector label carries its @-metadata a11y description, and the
//   channel-name values comply with the §13 voice register (factual noun
//   phrase, no exclamation mark, no emoji).

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Group N — Localization parity (#27/#34, NFR-03)', () {
    late Map<String, dynamic> it;
    late Map<String, dynamic> en;

    setUpAll(() {
      // GIVEN app_it.arb and app_en.arb, WHEN parsed → both are valid JSON.
      it = jsonDecode(File('lib/l10n/app_it.arb').readAsStringSync())
          as Map<String, dynamic>;
      en = jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
          as Map<String, dynamic>;
    });

    test('both ARB files parse as valid JSON', () {
      expect(it, isNotEmpty);
      expect(en, isNotEmpty);
    });

    test(
      'both locales contain notification_channel_name and '
      'onboarding_language_selector_label — 0 missing keys across the pair',
      () {
        const keys = [
          'notification_channel_name',
          'onboarding_language_selector_label',
        ];

        for (final k in keys) {
          expect(it.containsKey(k), isTrue, reason: 'IT missing key: $k');
          expect(en.containsKey(k), isTrue, reason: 'EN missing key: $k');
        }
      },
    );

    test(
      'onboarding_language_selector_label carries its @-metadata a11y '
      'description in both locales',
      () {
        for (final locale in [
          MapEntry('IT', it),
          MapEntry('EN', en),
        ]) {
          final meta = locale.value['@onboarding_language_selector_label']
              as Map<String, dynamic>?;
          expect(
            meta,
            isNotNull,
            reason: '${locale.key} missing @onboarding_language_selector_label '
                'metadata',
          );
          expect(
            meta!['description'],
            isA<String>(),
            reason: '${locale.key} @onboarding_language_selector_label missing '
                'a description',
          );
          expect(
            (meta['description'] as String).trim(),
            isNotEmpty,
            reason: '${locale.key} @onboarding_language_selector_label '
                'description is empty',
          );
        }
      },
    );

    test(
      'GIVEN the two channel-name string values, WHEN content-asserted → '
      'each is a factual noun phrase with no "!" and no emoji (§13 register)',
      () {
        // Literal-value check: exact §13-compliant strings from spec §4.3/EC-18.
        expect(it['notification_channel_name'], 'Mētra — Ciclo');
        expect(en['notification_channel_name'], 'Mētra — Cycle');
      },
    );

    test(
      'channel-name values contain no exclamation marks and no emoji '
      '(voice-register content assertion, not a literal-value check)',
      () {
        final emojiPattern = RegExp(
          r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{2190}-\u{21FF}'
          r'\u{2B00}-\u{2BFF}\u{FE0F}]',
          unicode: true,
        );

        for (final value in [
          it['notification_channel_name'] as String,
          en['notification_channel_name'] as String,
        ]) {
          expect(
            value.contains('!'),
            isFalse,
            reason: '"$value" contains an exclamation mark (§13 violation)',
          );
          expect(
            emojiPattern.hasMatch(value),
            isFalse,
            reason: '"$value" contains an emoji (§13 violation)',
          );
        }
      },
    );

    test(
      'onboarding_language_selector_label values are "Lingua" (IT) / '
      '"Language" (EN)',
      () {
        expect(it['onboarding_language_selector_label'], 'Lingua');
        expect(en['onboarding_language_selector_label'], 'Language');
      },
    );
  });
}
