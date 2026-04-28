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

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/errors/metra_exception.dart';
import 'package:metra/data/services/encryption_service.dart';

void main() {
  // Argon2id with 64 MB + 3 iterations is intentionally slow.
  // Allow up to 3 minutes per test.
  const kTimeout = Timeout(Duration(minutes: 3));

  late EncryptionService service;

  setUp(() {
    service = EncryptionService();
  });

  group('EncryptionService', () {
    test(
      'round-trip: encrypt then decrypt returns original plaintext',
      () async {
        final plaintext = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
        const passphrase = 'correct-horse-battery-staple';

        final blob = await service.encrypt(plaintext, passphrase);
        final decrypted = await service.decrypt(blob, passphrase);

        expect(decrypted, equals(plaintext));
      },
      timeout: kTimeout,
    );

    test(
      'IV uniqueness: two encryptions of the same plaintext produce different blobs',
      () async {
        final plaintext = Uint8List.fromList([10, 20, 30]);
        const passphrase = 'same-passphrase';

        final blob1 = await service.encrypt(plaintext, passphrase);
        final blob2 = await service.encrypt(plaintext, passphrase);

        // Both blobs must decrypt correctly, but they must not be identical
        // because the salt and IV are independently randomised each time.
        expect(blob1, isNot(equals(blob2)));
      },
      timeout: kTimeout,
    );

    test(
      'wrong passphrase throws CryptoException',
      () async {
        final plaintext = Uint8List.fromList([42, 43, 44]);
        const passphraseA = 'correct-passphrase';
        const passphraseB = 'wrong-passphrase';

        final blob = await service.encrypt(plaintext, passphraseA);

        await expectLater(
          () => service.decrypt(blob, passphraseB),
          throwsA(isA<CryptoException>()),
        );
      },
      timeout: kTimeout,
    );

    test(
      'truncated blob (43 bytes) throws CryptoException before KDF',
      () async {
        // Minimum valid blob is 44 bytes (16 salt + 12 IV + 0 cipher + 16 MAC).
        // A 43-byte blob must be rejected by the length guard immediately.
        final shortBlob = Uint8List(43);

        // This should NOT be slow — it must throw before any Argon2id work.
        await expectLater(
          () => service.decrypt(shortBlob, 'any-passphrase'),
          throwsA(isA<CryptoException>()),
        );
      },
      // Short timeout: this branch throws before KDF so it must be instant.
      timeout: const Timeout(Duration(seconds: 5)),
    );

    test(
      'empty plaintext round-trip: encrypt/decrypt Uint8List(0)',
      () async {
        final plaintext = Uint8List(0);
        const passphrase = 'passphrase-for-empty';

        final blob = await service.encrypt(plaintext, passphrase);

        // The blob must be exactly salt + IV + MAC = 44 bytes.
        expect(blob.length, equals(44));

        final decrypted = await service.decrypt(blob, passphrase);
        expect(decrypted, isEmpty);
      },
      timeout: kTimeout,
    );

    test(
      'Unicode passphrase round-trips correctly',
      () async {
        final plaintext = Uint8List.fromList([0xDE, 0xAD, 0xBE, 0xEF]);
        const passphrase = 'pässwörð';

        final blob = await service.encrypt(plaintext, passphrase);
        final decrypted = await service.decrypt(blob, passphrase);

        expect(decrypted, equals(plaintext));
      },
      timeout: kTimeout,
    );
  });
}
