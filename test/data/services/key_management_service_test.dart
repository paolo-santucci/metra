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
import 'package:metra/data/services/key_management_service.dart';

import '../../helpers/in_memory_secure_storage.dart';

final _kHexRegex = RegExp(r'^[0-9a-f]+$');

void main() {
  const storageKey = 'metra_db_encryption_key_v1';

  late InMemorySecureStorage storage;
  late KeyManagementService service;

  setUp(() {
    storage = InMemorySecureStorage();
    service = KeyManagementService(storage);
  });

  group('KeyManagementService', () {
    test(
      'getOrCreateDatabaseKey generates a 64-char hex key and persists it '
      'when storage is empty',
      () async {
        // Arrange — storage is empty (no pre-existing key)

        // Act
        final key = await service.getOrCreateDatabaseKey();

        // Assert
        expect(key.length, 64);
        expect(_kHexRegex.hasMatch(key), isTrue);
        expect(storage.values[storageKey], key);
      },
    );

    test(
      'getOrCreateDatabaseKey returns the same key on a second call',
      () async {
        // Arrange
        final firstKey = await service.getOrCreateDatabaseKey();

        // Act
        final secondKey = await service.getOrCreateDatabaseKey();

        // Assert
        expect(secondKey, firstKey);
      },
    );

    test(
      'getOrCreateDatabaseKey generates a new valid key when existing key '
      'has wrong length (corrupt storage)',
      () async {
        // Arrange — pre-seed storage with a too-short key
        storage.values[storageKey] = 'tooshort';

        // Act
        final key = await service.getOrCreateDatabaseKey();

        // Assert — new key must be valid and replace the corrupt one
        expect(key.length, 64);
        expect(_kHexRegex.hasMatch(key), isTrue);
        expect(storage.values[storageKey], key);
      },
    );

    test(
      'deleteDatabaseKey removes the key from storage',
      () async {
        // Arrange — ensure a key exists
        await service.getOrCreateDatabaseKey();
        expect(storage.values.containsKey(storageKey), isTrue);

        // Act
        await service.deleteDatabaseKey();

        // Assert
        expect(storage.values.containsKey(storageKey), isFalse);
      },
    );
  });
}
