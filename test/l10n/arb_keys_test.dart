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
  test('every spec key exists in BOTH app_it.arb and app_en.arb', () {
    final keys = [
      'restorePickerTitle',
      'restorePickerBody',
      'restorePickerUseNewest',
      'restorePickerAnnulla',
      'restorePickerRestoreThisVersion',
      'restorePickerEmpty',
      'restorePickerClose',
      'restorePickerBadgeNewest',
      'restorePickerSemanticLabel',
      'backup_error_storage_full',
      'backupAutoActiveLabel',
      'backupAutoSuspendedLabel',
      'notificationPermissionBlockedTitle',
      'notificationPermissionBlockedBody',
      'notificationPermissionOpenSettingsCta',
      'notificationPermissionBlockedDismiss',
    ];
    final it =
        jsonDecode(File('lib/l10n/app_it.arb').readAsStringSync()) as Map;
    final en =
        jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync()) as Map;
    for (final k in keys) {
      expect(it.containsKey(k), isTrue, reason: 'IT missing: $k');
      expect(en.containsKey(k), isTrue, reason: 'EN missing: $k');
    }
  });
}
