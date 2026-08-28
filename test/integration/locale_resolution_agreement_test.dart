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

// T-03 integration agreement test (QP qp-20260627-m5-locale-fallback-fix).
//
// Cross-seam agreement check: proves that the notification-string path
// (resolveLocaleFromPlatform in app.dart) and the UI localeResolutionCallback
// (also delegating to resolveLocaleFromPlatform) resolve IDENTICALLY for the
// same platformDispatcher.locales (the BUG-002 divergence guard).
//
// Two test groups:
//   1. Behavioral agreement — drive BOTH seams with identical localesTestValue
//      and assert they return the same Locale. The critical [de, it] scenario
//      guards against any regression that reads only the single primary locale
//      (which would incorrectly resolve 'de' instead of scanning the full list
//      to find 'it').
//   2. Source-grep guards — read lib/app.dart as text and assert the absence of
//      the old buggy identifiers (platformDispatcher.locale.languageCode,
//      _effectiveLangCode) and the presence of the shared-seam references
//      (delegate.load(resolveLocaleFromPlatform, localeResolutionCallback +
//      resolveLocaleFromPlatform, supportedLocales: AppLocalizations.supportedLocales).
//
// NO production code is modified here — this task contains only test code.
// MetraApp is NOT mounted; no DB is touched; no LD_LIBRARY_PATH required.
// If any assertion fails the gap belongs to T-01 or T-02 — report it there.

import 'dart:io' show File;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/app.dart' show resolveLocaleFromPlatform;
import 'package:metra/core/l10n/locale_resolver.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  // ===========================================================================
  // 1. Behavioral agreement
  //    Both the notification-string path and the localeResolutionCallback
  //    route through resolveLocaleFromPlatform, which reads
  //    platformDispatcher.locales (the full ordered preferred list — C-02).
  //    Driving both with identical localesTestValue proves they can never
  //    diverge (BUG-002 guard).
  //
  //    The critical scenario is [de, it]: the single primary locale is 'de'
  //    (no Italian), but the full list contains 'it'. Any regression that
  //    reads only the primary would resolve 'en' here — failing the test.
  // ===========================================================================

  group(
      '1. Behavioral agreement — notification path == resolver (BUG-002 guard)',
      () {
    tearDown(binding.platformDispatcher.clearLocalesTestValue);

    void assertAgreement({
      required String stored,
      required List<Locale> locales,
      required String expectedLangCode,
    }) {
      binding.platformDispatcher.localesTestValue = locales;

      // Notification-path seam: resolveLocaleFromPlatform reads
      // WidgetsBinding.instance.platformDispatcher.locales (full list).
      final notificationLocale = resolveLocaleFromPlatform(stored);

      // Direct resolver call with the same full list (mirrors what
      // localeResolutionCallback does when it calls resolveLocaleFromPlatform).
      final resolverLocale = resolveAppLocale(
        stored: stored,
        systemLocales: binding.platformDispatcher.locales,
      );

      expect(
        notificationLocale.languageCode,
        equals(expectedLangCode),
        reason:
            'resolveLocaleFromPlatform (notification path) must resolve $expectedLangCode '
            'for stored="$stored" locales=$locales',
      );
      expect(
        resolverLocale.languageCode,
        equals(expectedLangCode),
        reason: 'resolveAppLocale (resolver) must resolve $expectedLangCode '
            'for stored="$stored" locales=$locales',
      );
      expect(
        notificationLocale,
        equals(resolverLocale),
        reason:
            'notification path and resolver must agree for stored="$stored" locales=$locales',
      );
    }

    test(
      'given_de_en_locales_and_stored_empty_then_both_resolve_en',
      () {
        // No Italian anywhere in the list → English.
        assertAgreement(
          stored: '',
          locales: [const Locale('de'), const Locale('en')],
          expectedLangCode: 'en',
        );
      },
    );

    test(
      'given_it_CH_locale_and_stored_empty_then_both_resolve_it',
      () {
        // it-CH: languageCode == 'it' (region-stripped, C-05) → Italian.
        assertAgreement(
          stored: '',
          locales: [const Locale('it', 'CH')],
          expectedLangCode: 'it',
        );
      },
    );

    test(
      'given_de_it_locales_and_stored_empty_then_both_resolve_it_full_list_not_primary',
      () {
        // BUG-002 guard: Italian is NOT the primary locale but IS in the full
        // list. Pre-regression: reading only the primary 'de' would give 'en'.
        // Post-fix: scanning the full list finds 'it' → Italian.
        assertAgreement(
          stored: '',
          locales: [const Locale('de'), const Locale('it')],
          expectedLangCode: 'it',
        );
      },
    );

    test(
      'given_stored_it_and_de_system_locale_then_both_resolve_it',
      () {
        // Explicit 'it' → Italian regardless of system locale (FR-29 / C-03).
        assertAgreement(
          stored: 'it',
          locales: [const Locale('de')],
          expectedLangCode: 'it',
        );
      },
    );

    test(
      'given_stored_en_and_it_system_locale_then_both_resolve_en',
      () {
        // Explicit 'en' → English regardless of system locale (FR-29 / C-03).
        assertAgreement(
          stored: 'en',
          locales: [const Locale('it')],
          expectedLangCode: 'en',
        );
      },
    );
  });

  // ===========================================================================
  // 2. Source-grep guards — lib/app.dart anti-divergence
  //    Text-level assertions that the buggy patterns are gone and the shared
  //    seam is in place at both call sites.
  // ===========================================================================

  group('2. Source-grep guards — lib/app.dart (anti-divergence)', () {
    late String appDartSource;

    setUpAll(() {
      appDartSource = File('lib/app.dart').readAsStringSync();
    });

    test(
      'NO platformDispatcher.locale.languageCode — single-primary read removed (BUG-002)',
      () {
        expect(
          appDartSource.contains('platformDispatcher.locale.languageCode'),
          isFalse,
          reason: 'BUG-002: the single-primary locale read must be absent; '
              'only platformDispatcher.locales (the full ordered list) is permitted',
        );
      },
    );

    test(
      'NO _effectiveLangCode — private helper must have been deleted in T-02',
      () {
        expect(
          appDartSource.contains('_effectiveLangCode'),
          isFalse,
          reason:
              '_effectiveLangCode must have been deleted and its callers inlined '
              'to resolveLocaleFromPlatform (C-01 single-seam rule)',
        );
      },
    );

    test(
      'notification delegate.load path uses resolveLocaleFromPlatform',
      () {
        // The call is split across two lines in app.dart:
        //   AppLocalizations.delegate
        //       .load(resolveLocaleFromPlatform(...))
        // so we match on the method-call fragment, not "delegate.load(…".
        expect(
          appDartSource.contains('.load(resolveLocaleFromPlatform'),
          isTrue,
          reason:
              'AppLocalizations.delegate.load(...) notification call sites must pass '
              'resolveLocaleFromPlatform(...) as the locale argument',
        );
      },
    );

    test(
      'localeResolutionCallback references resolveLocaleFromPlatform (UI path)',
      () {
        expect(
          RegExp(
            r'localeResolutionCallback[^;]*resolveLocaleFromPlatform',
            dotAll: true,
          ).hasMatch(appDartSource),
          isTrue,
          reason:
              'The MaterialApp.router localeResolutionCallback must delegate to '
              'resolveLocaleFromPlatform (the shared seam — C-01)',
        );
      },
    );

    test(
      'supportedLocales: AppLocalizations.supportedLocales is unchanged (C-04)',
      () {
        expect(
          appDartSource.contains(
            'supportedLocales: AppLocalizations.supportedLocales',
          ),
          isTrue,
          reason:
              'C-04: supportedLocales must remain AppLocalizations.supportedLocales '
              '(not reordered to English-first, which would reverse the it-CH→it match)',
        );
      },
    );
  });
}
