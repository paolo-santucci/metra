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

// Tests that CI workflow YAML files have the required pub cache and
// --no-pub configuration to avoid redundant pub resolution on every run.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CI workflow structural assertions', () {
    test(
      'quality.yml contains cache: pub exactly once '
      'and flutter test --coverage --no-pub exactly once',
      () {
        final content = File(
          '.github/workflows/quality.yml',
        ).readAsStringSync();

        final cacheCount = "cache: 'pub'".allMatches(content).length;
        expect(
          cacheCount,
          equals(1),
          reason: "quality.yml must contain exactly one \"cache: 'pub'\" entry "
              "(got $cacheCount)",
        );

        final noPubCount =
            'flutter test --coverage --no-pub'.allMatches(content).length;
        expect(
          noPubCount,
          equals(1),
          reason: 'quality.yml must contain exactly one '
              '"flutter test --coverage --no-pub" invocation '
              '(got $noPubCount)',
        );
      },
    );

    test('android.yml contains cache: pub exactly once', () {
      final content = File(
        '.github/workflows/android.yml',
      ).readAsStringSync();

      final cacheCount = "cache: 'pub'".allMatches(content).length;
      expect(
        cacheCount,
        equals(1),
        reason: "android.yml must contain exactly one \"cache: 'pub'\" entry "
            "(got $cacheCount)",
      );
    });

    test('ios.yml contains cache: pub exactly twice (two flutter-action jobs)',
        () {
      final content = File('.github/workflows/ios.yml').readAsStringSync();

      final cacheCount = "cache: 'pub'".allMatches(content).length;
      expect(
        cacheCount,
        equals(2),
        reason: "ios.yml must contain exactly two \"cache: 'pub'\" entries "
            '(build_ios + deploy_testflight jobs; got $cacheCount)',
      );
    });
  });
}
