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

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/data/services/backup/icloud_gateway.dart';

import '../../../helpers/fake_icloud_gateway.dart';

void main() {
  group('Group B — IcloudGateway structural-consistency', () {
    test('fresh FakeIcloudGateway: happy path without throw', () async {
      final fake = FakeIcloudGateway();
      final bytes = Uint8List.fromList([1, 2, 3]);

      await fake.ensureAvailable();
      await fake.upload(bytes, 'p');
      final entries = await fake.gather();
      expect(entries.any((e) => e.relativePath == 'p'), isTrue);
      final downloaded = await fake.download('p');
      expect(downloaded, equals(bytes));
      await fake.delete('p');
    });

    test('signedIn=false: ensureAvailable() throws PlatformException',
        () async {
      final fake = FakeIcloudGateway(signedIn: false);
      expect(
        fake.ensureAvailable,
        throwsA(isA<PlatformException>()),
      );
    });

    test('kQuotaExceededCode is a non-empty static const String', () {
      expect(IcloudGateway.kQuotaExceededCode, isA<String>());
      expect(IcloudGateway.kQuotaExceededCode, isNotEmpty);
    });

    test(
      'visibility model: invisible for 2 gather() calls then visible on 3rd',
      () async {
        final fake = FakeIcloudGateway(invisibleForGatherCalls: 2);
        final bytes = Uint8List.fromList([4, 5, 6]);

        await fake.upload(bytes, 'p');

        // Call 1 — 'p' must be absent
        final result1 = await fake.gather();
        expect(result1.any((e) => e.relativePath == 'p'), isFalse);

        // Call 2 — 'p' must still be absent
        final result2 = await fake.gather();
        expect(result2.any((e) => e.relativePath == 'p'), isFalse);

        // Call 3 — 'p' must be present
        final result3 = await fake.gather();
        expect(result3.any((e) => e.relativePath == 'p'), isTrue);
      },
    );

    test(
      'throwQuotaOnNextUpload: upload throws PlatformException with kQuotaExceededCode',
      () async {
        final fake = FakeIcloudGateway()..throwQuotaOnNextUpload = true;
        final bytes = Uint8List.fromList([1]);
        expect(
          () => fake.upload(bytes, 'p'),
          throwsA(
            isA<PlatformException>().having(
              (e) => e.code,
              'code',
              IcloudGateway.kQuotaExceededCode,
            ),
          ),
        );
      },
    );
  });
}
