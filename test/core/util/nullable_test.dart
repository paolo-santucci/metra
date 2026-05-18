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
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/util/nullable.dart';

void main() {
  group('Nullable<T>', () {
    test('Nullable<bool>(null) stores null as .value', () {
      const wrapper = Nullable<bool>(null);
      expect(wrapper.value, isNull);
    });

    test('Nullable<bool>(true) stores true as .value', () {
      const wrapper = Nullable<bool>(true);
      expect(wrapper.value, isTrue);
    });

    test('Nullable<String>("x") stores "x" as .value', () {
      const wrapper = Nullable<String>('x');
      expect(wrapper.value, 'x');
    });

    test(
        'domain-purity — source file imports nothing from flutter/drift/http/flutter_local_notifications',
        () {
      final source = File('lib/core/util/nullable.dart').readAsStringSync();
      expect(source, isNot(contains('package:flutter')));
      expect(source, isNot(contains('package:drift')));
      expect(source, isNot(contains('package:http')));
      expect(source, isNot(contains('package:flutter_local_notifications')));
    });

    test('SPDX header present in source file', () {
      final source = File('lib/core/util/nullable.dart').readAsStringSync();
      expect(source, contains('SPDX-License-Identifier: GPL-3.0-or-later'));
    });
  });
}
