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

import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/constants/app_constants.dart';

void main() {
  group('AppConstants', () {
    // kAppVersion was removed: version is now read at runtime from the native
    // bundle via appVersionProvider (package_info_plus) to stay in sync with
    // pubspec.yaml automatically across releases.

    test('kUrlHelp points to the help index', () {
      expect(
        AppConstants.kUrlHelp,
        'https://paolo-santucci.github.io/metra/help/',
      );
    });

    test('kUrlGitHub points to the GitHub repository', () {
      expect(
        AppConstants.kUrlGitHub,
        'https://github.com/paolo-santucci/metra',
      );
    });

    test('kUrlPrivacy points to the privacy policy page', () {
      expect(
        AppConstants.kUrlPrivacy,
        'https://paolo-santucci.github.io/metra/privacy/',
      );
    });

    test('kUrlKoFi points to the Ko-fi support page', () {
      expect(AppConstants.kUrlKoFi, 'https://ko-fi.com/D1D31YPYRX');
    });

    test('kUrlKoFiBadge points to the Ko-fi badge image', () {
      expect(
        AppConstants.kUrlKoFiBadge,
        'https://storage.ko-fi.com/cdn/kofi2.png?v=6',
      );
    });

    test('tapTargetMin satisfies WCAG minimum touch target of 44dp', () {
      expect(AppConstants.tapTargetMin, 44.0);
    });

    test('tapTargetMd is 48dp', () {
      expect(AppConstants.tapTargetMd, 48.0);
    });

    test('contentPad is 24dp', () {
      expect(AppConstants.contentPad, 24.0);
    });

    test('maxWidth is 420dp', () {
      expect(AppConstants.maxWidth, 420.0);
    });
  });
}
