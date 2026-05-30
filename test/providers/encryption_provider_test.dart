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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/providers/encryption_provider.dart';

void main() {
  group('secureStorageProvider', () {
    test(
        'configures iOS keychain accessibility to first_unlock (afterFirstUnlock)',
        () {
      // FR-16 + NFR-04 + BUG-D05
      // Background auto-backup needs to read the cached passphrase while the
      // screen is locked. first_unlock = kSecAttrAccessibleAfterFirstUnlock:
      // accessible after the first post-boot device unlock, even when screen
      // is locked. This is the OQ-05 trade-off accepted by the user.
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final storage = container.read(secureStorageProvider);

      // iOptions is a public field on FlutterSecureStorage (v9.2.x).
      // toMap() serialises accessibility via describeEnum — returns the bare
      // enum name, e.g. 'first_unlock'.
      expect(
        storage.iOptions.toMap()['accessibility'],
        'first_unlock',
        reason:
            'FR-16: iOS Keychain must use kSecAttrAccessibleAfterFirstUnlock '
            'so unattended background backup can read the passphrase while the '
            'screen is locked (BUG-D05).',
      );
    });

    test(
        'uses default AndroidOptions without deprecated encryptedSharedPreferences',
        () {
      // Regression guard: flutter_secure_storage v10 deprecated
      // encryptedSharedPreferences (backed by the now-deprecated Jetpack
      // Security library). The production provider intentionally omits the
      // option, letting the library default to false and rely on its own
      // AES-GCM cipher with migrateOnAlgorithmChange: true (the default).
      // This test verifies the provider initialises without error and that the
      // deprecated field is NOT explicitly set to true (NFR-04).
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final storage = container.read(secureStorageProvider);

      // v10 default: encryptedSharedPreferences is false (deprecated, not set).
      expect(
        storage.aOptions.toMap()['encryptedSharedPreferences'],
        isNot('true'),
        reason: 'flutter_secure_storage v10: encryptedSharedPreferences is '
            'deprecated and must not be explicitly enabled (NFR-04).',
      );
    });
  });
}
