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
  test('ARB keys parity: every new picker key is present in both IT and EN',
      () async {
    final it =
        json.decode(await File('lib/l10n/app_it.arb').readAsString()) as Map;
    final en =
        json.decode(await File('lib/l10n/app_en.arb').readAsString()) as Map;
    const newKeys = [
      'restorePickerTitle',
      'restorePickerBody',
      'restorePickerRowTemplate',
      'restorePickerUseNewest',
      'restorePickerRestoreThisVersion',
      'restorePickerEmpty',
      'restorePickerError',
    ];
    for (final k in newKeys) {
      expect(it.containsKey(k), isTrue, reason: 'IT missing key: $k');
      expect(en.containsKey(k), isTrue, reason: 'EN missing key: $k');
    }
  });
}
