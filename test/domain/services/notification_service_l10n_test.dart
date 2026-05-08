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

// Tests for TASK-19 (FR-14, NFR-07):
//   notification_prediction_body ICU plural resolves correctly for EN and IT
//   at the singular boundary (days=1) and the plural branch (days=5).

import 'package:flutter_test/flutter_test.dart';
import 'package:metra/l10n/app_localizations_en.dart';
import 'package:metra/l10n/app_localizations_it.dart';

void main() {
  group('notification_prediction_body ICU plural', () {
    final en = AppLocalizationsEn();
    final it = AppLocalizationsIt();

    test(
      'given_locale_EN_when_days_is_1_then_returns_tomorrow',
      () {
        expect(en.notification_prediction_body(1), 'tomorrow');
      },
    );

    test(
      'given_locale_IT_when_days_is_1_then_returns_domani',
      () {
        expect(it.notification_prediction_body(1), 'domani');
      },
    );

    test(
      'given_locale_EN_when_days_is_5_then_returns_in_5_days',
      () {
        expect(en.notification_prediction_body(5), 'in 5 days');
      },
    );

    test(
      'given_locale_IT_when_days_is_5_then_returns_tra_5_giorni',
      () {
        expect(it.notification_prediction_body(5), 'tra 5 giorni');
      },
    );
  });
}
