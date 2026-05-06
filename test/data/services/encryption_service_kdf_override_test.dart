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

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/errors/metra_exception.dart';
import 'package:metra/data/services/encryption_service.dart';

/// Lightweight KDF for tests: tiny memory, one iteration, one lane.
/// Must never be used in production code.
final _lightKdf = Argon2id(
  memory: 256,
  iterations: 1,
  parallelism: 1,
  hashLength: 32,
);

void main() {
  group('EncryptionService — kdfOverride seam', () {
    // Test 1 — happy round-trip with lightweight KDF (EC-happy, FR-07)
    //   Proves the seam is wired correctly and the lightweight KDF is actually engaged
    //   (wall-clock < 500 ms; production KDF at 64 MB / 3 iter would take several seconds).
    test(
      'round-trip with lightweight KDF completes in < 500 ms',
      () async {
        final svc = EncryptionService(kdfOverride: _lightKdf);
        final plaintext = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
        const passphrase = 'test-passphrase';

        final sw = Stopwatch()..start();
        final blob = await svc.encrypt(plaintext, passphrase);
        final out = await svc.decrypt(blob, passphrase);
        sw.stop();

        expect(out, equals(plaintext));
        expect(
          sw.elapsedMilliseconds,
          lessThan(500),
          reason: 'Lightweight KDF must complete encrypt+decrypt in < 500 ms; '
              'took ${sw.elapsedMilliseconds} ms. '
              'This likely means kdfOverride is not wired to _deriveKey.',
        );
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    // Test 2 — IV uniqueness with lightweight KDF (FR-07, mirrors existing IV-uniqueness test)
    //   Two encrypt() calls on the same plaintext with the same passphrase must produce
    //   different blobs (randomised salt + IV), and both must decrypt back to the original.
    test(
      'IV uniqueness: two encryptions produce different blobs, both decrypt correctly',
      () async {
        final svc = EncryptionService(kdfOverride: _lightKdf);
        final plaintext = Uint8List.fromList([10, 20, 30]);
        const passphrase = 'same-pass';

        final blob1 = await svc.encrypt(plaintext, passphrase);
        final blob2 = await svc.encrypt(plaintext, passphrase);

        expect(blob1, isNot(equals(blob2)));
        expect(await svc.decrypt(blob1, passphrase), equals(plaintext));
        expect(await svc.decrypt(blob2, passphrase), equals(plaintext));
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    // Test 3 — explicit null falls through to default (EC-10)
    //   EncryptionService(kdfOverride: null) and EncryptionService() must use the same
    //   underlying KDF so that a blob encrypted by one can be decrypted by the other.
    test(
      'explicit kdfOverride: null uses the same default KDF as the no-arg constructor',
      () async {
        final a = EncryptionService(kdfOverride: null);
        final b = EncryptionService();
        final plaintext = Uint8List.fromList([42]);
        const passphrase = 'null-falls-through';

        // Encrypt with 'a', decrypt with 'b' — must round-trip.
        final blob = await a.encrypt(plaintext, passphrase);
        final out = await b.decrypt(blob, passphrase);

        expect(out, equals(plaintext));
      },
      // Production-default KDF is slow. Allow up to 3 minutes.
      timeout: const Timeout(Duration(minutes: 3)),
    );

    // Test 4 — cross-KDF security boundary (EC-11)
    //   A blob encrypted with the production default KDF must NOT be decryptable with
    //   the lightweight KDF (different key derivation → different key → authentication failure).
    //   Wrapped in a 3-minute timeout because the encrypt side runs the real Argon2id.
    test(
      'cross-KDF decrypt throws CryptoException',
      () async {
        final production = EncryptionService();
        final lightweight = EncryptionService(kdfOverride: _lightKdf);
        final plaintext = Uint8List.fromList([0xDE, 0xAD]);
        const passphrase = 'secret';

        // Encrypt with production-default KDF.
        final blob = await production.encrypt(plaintext, passphrase);

        // Attempt decrypt with lightweight KDF — must fail with CryptoException.
        await expectLater(
          () => lightweight.decrypt(blob, passphrase),
          throwsA(isA<CryptoException>()),
        );
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });
}
