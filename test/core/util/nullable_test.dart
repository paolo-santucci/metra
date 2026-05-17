// SPDX-License-Identifier: GPL-3.0-or-later
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
