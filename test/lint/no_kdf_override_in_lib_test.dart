// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
//
// Métra is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Métra is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Métra. If not, see <https://www.gnu.org/licenses/>.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lib/ contains no kdfOverride usage', () {
    final offending = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((entity) => entity.path.endsWith('.dart'))
        .where((entity) => entity.readAsStringSync().contains('kdfOverride:'))
        .map((entity) => entity.path)
        .toList();

    expect(
      offending,
      isEmpty,
      reason: 'kdfOverride is FOR-TESTING-ONLY and must never appear in lib/. '
          'Offending files:\n${offending.join('\n')}',
    );
  });

  test('test/ contains kdfOverride — meta self-verification', () {
    final matches = Directory('test')
        .listSync(recursive: true)
        .whereType<File>()
        .where((entity) => entity.path.endsWith('.dart'))
        .where((entity) => entity.readAsStringSync().contains('kdfOverride:'))
        .map((entity) => entity.path)
        .toList();

    expect(
      matches.length,
      greaterThanOrEqualTo(2),
      reason: 'Expected at least 2 test files using kdfOverride: '
          '(sync_orchestrator_test.dart + encryption_service_kdf_override_test.dart). '
          'Actually found (${matches.length}): ${matches.join(', ')}',
    );
  });
}
