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

import 'dart:io';
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/l10n/locale_resolver.dart';

void main() {
  group('resolveAppLocale (FR-28/29/30, BUG-002/003)', () {
    // -------------------------------------------------------------------------
    // Follow-system sentinel ('') — Italian system (incl. region)
    // -------------------------------------------------------------------------

    test(
      'given_follow_system_sentinel_when_system_is_it_then_resolves_it',
      () {
        expect(
          resolveAppLocale(
            stored: '',
            systemLocales: [const Locale('it')],
          ).languageCode,
          'it',
        );
      },
    );

    test(
      'given_follow_system_sentinel_when_system_is_it_CH_then_resolves_it',
      () {
        expect(
          resolveAppLocale(
            stored: '',
            systemLocales: [const Locale('it', 'CH')],
          ).languageCode,
          'it',
        );
      },
    );

    test(
      'given_follow_system_sentinel_when_system_is_it_IT_then_resolves_it',
      () {
        expect(
          resolveAppLocale(
            stored: '',
            systemLocales: [const Locale('it', 'IT')],
          ).languageCode,
          'it',
        );
      },
    );

    // -------------------------------------------------------------------------
    // Follow-system sentinel ('') — non-Italian system -> English (inverted-default fix)
    // -------------------------------------------------------------------------

    test(
      'given_follow_system_sentinel_when_system_is_de_then_resolves_en',
      () {
        expect(
          resolveAppLocale(
            stored: '',
            systemLocales: [const Locale('de')],
          ).languageCode,
          'en',
        );
      },
    );

    test(
      'given_follow_system_sentinel_when_system_is_fr_then_resolves_en',
      () {
        expect(
          resolveAppLocale(
            stored: '',
            systemLocales: [const Locale('fr')],
          ).languageCode,
          'en',
        );
      },
    );

    test(
      'given_follow_system_sentinel_when_system_is_es_then_resolves_en',
      () {
        expect(
          resolveAppLocale(
            stored: '',
            systemLocales: [const Locale('es')],
          ).languageCode,
          'en',
        );
      },
    );

    test(
      'given_follow_system_sentinel_when_system_is_ja_then_resolves_en',
      () {
        expect(
          resolveAppLocale(
            stored: '',
            systemLocales: [const Locale('ja')],
          ).languageCode,
          'en',
        );
      },
    );

    // -------------------------------------------------------------------------
    // Divergence guard (BUG-002) — full preferred list, Italian not primary
    // -------------------------------------------------------------------------

    test(
      'given_follow_system_sentinel_when_full_list_is_de_en_then_resolves_en',
      () {
        expect(
          resolveAppLocale(
            stored: '',
            systemLocales: [const Locale('de'), const Locale('en')],
          ).languageCode,
          'en',
        );
      },
    );

    test(
      'given_follow_system_sentinel_when_full_list_is_de_it_then_resolves_it',
      () {
        expect(
          resolveAppLocale(
            stored: '',
            systemLocales: [const Locale('de'), const Locale('it')],
          ).languageCode,
          'it',
        );
      },
    );

    test(
      'given_follow_system_sentinel_when_system_list_is_empty_then_resolves_en',
      () {
        expect(
          resolveAppLocale(
            stored: '',
            systemLocales: [],
          ).languageCode,
          'en',
        );
      },
    );

    // -------------------------------------------------------------------------
    // Explicit choice (FR-29) — exact render, system list ignored
    // -------------------------------------------------------------------------

    test(
      'given_stored_it_when_system_is_de_then_resolves_it',
      () {
        expect(
          resolveAppLocale(
            stored: 'it',
            systemLocales: [const Locale('de')],
          ).languageCode,
          'it',
        );
      },
    );

    test(
      'given_stored_en_when_system_is_it_then_resolves_en',
      () {
        expect(
          resolveAppLocale(
            stored: 'en',
            systemLocales: [const Locale('it')],
          ).languageCode,
          'en',
        );
      },
    );

    // -------------------------------------------------------------------------
    // Unsupported explicit code clamp (BUG-003)
    // -------------------------------------------------------------------------

    test(
      'given_stored_de_when_system_is_it_then_clamps_to_en',
      () {
        expect(
          resolveAppLocale(
            stored: 'de',
            systemLocales: [const Locale('it')],
          ).languageCode,
          'en',
        );
      },
    );

    // -------------------------------------------------------------------------
    // Invariant: never throws, never returns a langCode outside {'it','en'}
    // -------------------------------------------------------------------------

    test(
      'given_any_valid_input_when_called_then_never_throws_and_result_is_it_or_en',
      () {
        final inputs = [
          (stored: '', systemLocales: <Locale>[const Locale('it')]),
          (stored: '', systemLocales: <Locale>[const Locale('de')]),
          (stored: '', systemLocales: <Locale>[]),
          (stored: 'it', systemLocales: <Locale>[const Locale('de')]),
          (stored: 'en', systemLocales: <Locale>[const Locale('it')]),
          (stored: 'de', systemLocales: <Locale>[const Locale('it')]),
          (stored: 'zh', systemLocales: <Locale>[const Locale('zh')]),
        ];

        for (final input in inputs) {
          Locale result;
          // must not throw
          result = resolveAppLocale(
            stored: input.stored,
            systemLocales: input.systemLocales,
          );
          expect(
            {'it', 'en'},
            contains(result.languageCode),
            reason:
                'stored="${input.stored}" systemLocales=${input.systemLocales} '
                'returned unexpected languageCode "${result.languageCode}"',
          );
        }
      },
    );

    // -------------------------------------------------------------------------
    // Domain-purity guard
    // -------------------------------------------------------------------------

    test(
      'given_source_file_when_inspected_then_no_flutter_import_present',
      () {
        final source =
            File('lib/core/l10n/locale_resolver.dart').readAsStringSync();
        expect(
          source,
          isNot(contains('package:flutter')),
          reason:
              'C-06: locale_resolver.dart must be dart:ui-only, no Flutter import',
        );
      },
    );
  });
}
