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

// T-02 wiring seam test (QP qp-20260627-m5-locale-fallback-fix).
//
// MetraApp is NOT mounted in these tests. They assert the wiring seam:
// that both the notification-string path and the localeResolutionCallback
// in app.dart route through resolveLocaleFromPlatform → resolveAppLocale,
// consuming platformDispatcher.locales (the full ordered preferred list),
// NOT the single primary .locale.languageCode (BUG-002 fix).
//
// PARALLEL-BUILD NOTE: T-01 (flutter-domain-tdd) implements the body of
// resolveAppLocale. Until T-01 lands, resolveAppLocale throws
// UnimplementedError. Tests in groups 1 and 2 are expected to throw
// UnimplementedError in that state — that is the correct parallel state.
// The full scoped suite goes green once both T-01 and T-02 are merged.
// Group 3 (supportedLocales regression guard) does NOT call resolveAppLocale
// and passes immediately.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/app.dart' show resolveLocaleFromPlatform;
import 'package:metra/l10n/app_localizations.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(binding.platformDispatcher.clearLocalesTestValue);

  // =========================================================================
  // 1. Notification-path agreement — reads platformDispatcher.locales (full
  //    list), NOT .locale.languageCode (single primary). BUG-002 fix.
  //
  //    Pre-fix: _effectiveLangCode read .locale.languageCode = 'de' (the
  //    primary from [de, en]), found 'de' not in supportedLocales, and
  //    defaulted to 'it'. Post-fix: resolveLocaleFromPlatform over the full
  //    preferred list [de, en] finds no 'it' → 'en'.
  // =========================================================================

  group('1. notification-path: resolves over locales (not .locale)', () {
    test(
      'given_de_en_system_and_stored_empty_then_notification_locale_is_en_not_it',
      () {
        binding.platformDispatcher.localesTestValue = [
          const Locale('de'),
          const Locale('en'),
        ];
        // Was 'it' (pre-fix: .locale.languageCode='de', not in supported, default it).
        // Post-fix: resolveLocaleFromPlatform('') → resolveAppLocale over [de,en] → 'en'.
        expect(
          resolveLocaleFromPlatform('').languageCode,
          equals('en'),
        );
      },
    );
  });

  // =========================================================================
  // 2. localeResolutionCallback seam — resolveLocaleFromPlatform is the
  //    single seam that the callback delegates to. Asserting its behaviour
  //    with localesTestValue set proves the callback wiring without mounting
  //    the full MaterialApp (C-01 single-seam rule).
  // =========================================================================

  group('2. localeResolutionCallback seam', () {
    test(
      'given_it_CH_system_and_stored_empty_then_resolves_to_Locale_it',
      () {
        binding.platformDispatcher.localesTestValue = [
          const Locale('it', 'CH'),
        ];
        // it-CH: languageCode == 'it' → resolves Italian (C-05 region-strip).
        expect(
          resolveLocaleFromPlatform(''),
          equals(const Locale('it')),
        );
      },
    );

    test(
      'given_de_system_and_stored_empty_then_resolves_to_Locale_en',
      () {
        binding.platformDispatcher.localesTestValue = [
          const Locale('de'),
        ];
        // No 'it' in list → English fallback.
        expect(
          resolveLocaleFromPlatform(''),
          equals(const Locale('en')),
        );
      },
    );

    test(
      'given_stored_it_then_resolves_to_Locale_it_regardless_of_system',
      () {
        binding.platformDispatcher.localesTestValue = [
          const Locale('de'),
        ];
        // Explicit 'it' → Italian, system locale ignored (FR-29 / C-03).
        expect(
          resolveLocaleFromPlatform('it'),
          equals(const Locale('it')),
        );
      },
    );

    test(
      'given_stored_en_then_resolves_to_Locale_en_regardless_of_system',
      () {
        binding.platformDispatcher.localesTestValue = [
          const Locale('it'),
        ];
        // Explicit 'en' → English, system locale ignored (FR-29 / C-03).
        expect(
          resolveLocaleFromPlatform('en'),
          equals(const Locale('en')),
        );
      },
    );
  });

  // =========================================================================
  // 3. supportedLocales regression guard (C-04).
  //
  //    supportedLocales must remain [Locale('it'), Locale('en')] in that
  //    exact order. Reordering to English-first is an explicit anti-pattern
  //    (it reverses the it-CH→it match asymmetry). This test passes even in
  //    the parallel-stub state because it does NOT call resolveAppLocale.
  // =========================================================================

  group('3. supportedLocales regression guard (C-04)', () {
    test(
      'supportedLocales_is_exactly_it_en_in_that_order',
      () {
        expect(
          AppLocalizations.supportedLocales,
          equals(const [Locale('it'), Locale('en')]),
          reason: 'C-04: supportedLocales must remain [it, en] in that order — '
              'reordering to en-first reverses the it-CH→it match asymmetry',
        );
      },
    );
  });
}
