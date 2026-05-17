// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Métra contributors

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
