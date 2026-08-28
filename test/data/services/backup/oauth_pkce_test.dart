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

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/data/services/backup/oauth_pkce.dart';

// Pre-refactor reference implementations, copied verbatim from the inline
// GoogleDriveProvider/DropboxProvider private methods (identical in both
// files) so this test can assert byte-identical output for a seeded Random
// (NFR-06) without importing the provider classes.
String _referenceOauthState(Random random) {
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

String _referenceCodeVerifier(Random random) {
  const chars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
  return List.generate(64, (_) => chars[random.nextInt(chars.length)]).join();
}

String _referenceCodeChallenge(String verifier) {
  final digest = sha256.convert(utf8.encode(verifier)).bytes;
  return base64Url
      .encode(digest)
      .replaceAll('=', '')
      .replaceAll('+', '-')
      .replaceAll('/', '_');
}

void main() {
  group('generateOauthState', () {
    test(
      'is byte-identical to the pre-refactor provider logic for a seeded '
      'Random (NFR-06)',
      () {
        final expected = _referenceOauthState(Random(1234));
        final actual = generateOauthState(Random(1234));

        expect(actual, expected);
      },
    );

    test('produces a 32-hex-char string', () {
      final state = generateOauthState(Random(7));

      expect(state, hasLength(32));
      expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(state), isTrue);
    });
  });

  group('generateCodeVerifier', () {
    test(
      'is byte-identical to the pre-refactor provider logic for a seeded '
      'Random (NFR-06)',
      () {
        final expected = _referenceCodeVerifier(Random(4321));
        final actual = generateCodeVerifier(Random(4321));

        expect(actual, expected);
      },
    );

    test('produces a 64-char string', () {
      final verifier = generateCodeVerifier(Random(9));

      expect(verifier, hasLength(64));
    });
  });

  group('codeChallenge', () {
    test(
      'equals base64Url(sha256(verifier)) with only "=" padding stripped '
      '— no +/- or //_ substitution (those transforms were no-ops on '
      'base64Url output)',
      () {
        // Exercise many verifiers (deterministic via seeded Random) so the
        // absence of the two dropped replaceAll steps is proven across a
        // wide sample, not just one lucky verifier.
        final random = Random(99);
        for (var i = 0; i < 200; i++) {
          final verifier = _referenceCodeVerifier(random);
          final expected = base64Url
              .encode(sha256.convert(utf8.encode(verifier)).bytes)
              .replaceAll('=', '');

          expect(codeChallenge(verifier), expected);
        }
      },
    );

    test(
      'matches the pre-refactor reference implementation (which included '
      'the now-dropped no-op replaceAll steps)',
      () {
        const verifier = 'fixed-test-verifier-value-1234567890';

        expect(codeChallenge(verifier), _referenceCodeChallenge(verifier));
      },
    );
  });

  group('source-grep guards', () {
    late String source;

    setUpAll(() {
      source = File(
        'lib/data/services/backup/oauth_pkce.dart',
      ).readAsStringSync();
    });

    test('begins with the GPL-3.0 header block', () {
      expect(source.trimLeft(), startsWith('// Copyright (C) 2026'));
      expect(source, contains('GNU General Public License'));
    });

    test('Random parameters carry no default value', () {
      // Split across the boundary so this guard does not self-match, and so
      // it does not false-positive on prose that merely *mentions*
      // Random.secure() (e.g. doc-comment guidance for callers) without
      // using it as an actual parameter default.
      const forbiddenDefault = '= Random.secure' '()';
      expect(source.contains(forbiddenDefault), isFalse);
      // No "Random random = <anything>" default-value parameter syntax
      // anywhere in a function signature.
      expect(RegExp(r'Random\s+random\s*=').hasMatch(source), isFalse);
    });

    test(
      'imports only dart:convert, dart:math, and package:crypto/crypto.dart',
      () {
        final importLines = source
            .split('\n')
            .where((line) => line.trim().startsWith('import '))
            .toList();

        const allowList = {
          "import 'dart:convert';",
          "import 'dart:math';",
          "import 'package:crypto/crypto.dart';",
        };

        for (final line in importLines) {
          expect(allowList.contains(line.trim()), isTrue, reason: line);
        }
        expect(source.contains('package:flutter/'), isFalse);
        expect(source.contains('package:http/'), isFalse);
      },
    );
  });
}
