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

// Tests for TASK-05 (FR-01, FR-02, FR-10, FR-11, FR-15, FR-17, NFR-06):
//   the six Archivio filter/search keys render the §5.1.H copy through the
//   generated localizations delegate, and the ICU plural key yields
//   "1 ciclo"/"2 cicli" (IT) and "1 cycle"/"2 cycles" (EN).

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('timeline_filter_results_count — ICU plural rendering (FR-11)', () {
    test('IT renders the singular and the plural form', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('it'));

      expect(l10n.timeline_filter_results_count(1), '1 ciclo');
      expect(l10n.timeline_filter_results_count(2), '2 cicli');
    });

    test('EN renders the singular and the plural form', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      expect(l10n.timeline_filter_results_count(1), '1 cycle');
      expect(l10n.timeline_filter_results_count(2), '2 cycles');
    });
  });

  group('Archivio filter/search string surfaces (FR-01/FR-02/FR-10/FR-17)', () {
    test('IT copy matches spec §5.1.H', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('it'));

      expect(l10n.timeline_search_hint, 'Cerca nelle note');
      expect(l10n.timeline_search_clear_a11y, 'Cancella la ricerca');
      expect(l10n.timeline_filter_clear_all, 'Rimuovi filtri');
      expect(
        l10n.timeline_filter_no_match,
        'Nessun ciclo corrisponde ai filtri',
      );
      expect(l10n.timeline_filter_no_match_action, 'Rimuovi filtri');
    });

    test('EN copy matches spec §5.1.H', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      expect(l10n.timeline_search_hint, 'Search in notes');
      expect(l10n.timeline_search_clear_a11y, 'Clear search');
      expect(l10n.timeline_filter_clear_all, 'Clear filters');
      expect(l10n.timeline_filter_no_match, 'No cycles match the filters');
      expect(l10n.timeline_filter_no_match_action, 'Clear filters');
    });
  });
}
