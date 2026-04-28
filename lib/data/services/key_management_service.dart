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

import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class KeyManagementService {
  static const _dbKeyStorageKey = 'metra_db_encryption_key_v1';

  final FlutterSecureStorage _storage;

  const KeyManagementService(this._storage);

  /// Returns the DB key as a 64-char hex string.
  /// Generates and persists it on first call.
  Future<String> getOrCreateDatabaseKey() async {
    final existing = await _storage.read(key: _dbKeyStorageKey);
    if (existing != null && _isValidHexKey(existing)) return existing;

    final key = _generateHexKey();
    await _storage.write(key: _dbKeyStorageKey, value: key);
    return key;
  }

  bool _isValidHexKey(String key) =>
      key.length == 64 && RegExp(r'^[0-9a-f]+$').hasMatch(key);

  /// Deletes the DB key from secure storage.
  /// Call only during full data wipe / factory reset — data becomes irrecoverable.
  Future<void> deleteDatabaseKey() => _storage.delete(key: _dbKeyStorageKey);

  String _generateHexKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
