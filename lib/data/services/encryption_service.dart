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
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../../core/errors/metra_exception.dart';

/// Encrypts and decrypts cloud backup blobs using AES-256-GCM with Argon2id key derivation.
///
/// Blob format: [16-byte salt][12-byte IV/nonce][ciphertext][16-byte GCM MAC]
/// This service is ONLY for cloud backup encryption, not database encryption.
class EncryptionService {
  static const _saltLength = 16;
  static const _ivLength = 12;
  static const _macLength = 16; // AES-GCM MAC is always 16 bytes

  static final _argon2id = Argon2id(
    memory: 65536, // 64 MB
    iterations: 3,
    parallelism: 4,
    hashLength: 32,
  );

  static final _aesGcm = AesGcm.with256bits();

  final Random _random;

  EncryptionService({Random? random}) : _random = random ?? Random.secure();

  /// Encrypts [plaintext] with a key derived from [passphrase].
  /// Returns blob: [16-byte salt][12-byte nonce][ciphertext][16-byte MAC].
  Future<Uint8List> encrypt(Uint8List plaintext, String passphrase) async {
    final salt = _randomBytes(_saltLength);
    final iv = _randomBytes(_ivLength);

    final secretKey = await _deriveKey(passphrase, salt);
    final secretBox = await _aesGcm.encrypt(
      plaintext,
      secretKey: secretKey,
      nonce: iv,
    );

    final result = BytesBuilder(copy: false);
    result.add(salt);
    result.add(iv);
    result.add(secretBox.cipherText);
    result.add(secretBox.mac.bytes);
    return result.toBytes();
  }

  /// Decrypts a blob produced by [encrypt].
  /// Throws [CryptoException] if the passphrase is wrong or the blob is corrupted.
  Future<Uint8List> decrypt(Uint8List blob, String passphrase) async {
    if (blob.length < _saltLength + _ivLength + _macLength) {
      throw const CryptoException('Blob too short');
    }

    final salt = blob.sublist(0, _saltLength);
    final iv = blob.sublist(_saltLength, _saltLength + _ivLength);
    final body = blob.sublist(_saltLength + _ivLength);
    final cipherText = body.sublist(0, body.length - _macLength);
    final mac = body.sublist(body.length - _macLength);

    final secretKey = await _deriveKey(passphrase, salt);
    try {
      final secretBox = SecretBox(cipherText, nonce: iv, mac: Mac(mac));
      final plaintext = await _aesGcm.decrypt(secretBox, secretKey: secretKey);
      return Uint8List.fromList(plaintext);
    } on SecretBoxAuthenticationError {
      throw const CryptoException(
        'Decryption failed: wrong passphrase or corrupted data',
      );
    }
  }

  Future<SecretKey> _deriveKey(String passphrase, List<int> salt) =>
      _argon2id.deriveKeyFromPassword(password: passphrase, nonce: salt);

  List<int> _randomBytes(int length) =>
      List<int>.generate(length, (_) => _random.nextInt(256));
}
