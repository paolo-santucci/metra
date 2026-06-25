// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:metra/core/errors/metra_exception.dart';
import 'package:metra/domain/entities/sync_log_entity.dart';
import 'package:metra/providers/backup_providers.dart';

import 'fake_icloud_provider.dart';

void main() {
  group('FakeICloudProvider', () {
    test('id returns SyncProvider.iCloud', () {
      expect(FakeICloudProvider().id, equals(SyncProvider.iCloud));
    });

    test('currentEmail returns null', () async {
      expect(await FakeICloudProvider().currentEmail(), isNull);
    });

    test('all 8 members callable on default instance without throwing',
        () async {
      final provider = FakeICloudProvider();

      // All these should complete without throwing
      expect(provider.authorize(), completes);
      expect(provider.disconnect(), completes);
      expect(provider.upload(Uint8List(0), 'test.txt'), completes);
      expect(provider.download('test.txt'), completes);
      expect(provider.listFiles(), completes);
      expect(provider.deleteFile('test.txt'), completes);
    });

    test('authorize configured to throw throws SyncException', () async {
      final provider = FakeICloudProvider(authorizeThrows: true);
      expect(
        provider.authorize(),
        throwsA(isA<SyncException>()),
      );
    });

    test('overrideWithValue compiles and reads back the fake', () {
      final container = ProviderContainer(
        overrides: [
          cloudBackupProvider.overrideWithValue(FakeICloudProvider()),
        ],
      );
      expect(
        container.read(cloudBackupProvider).id,
        equals(SyncProvider.iCloud),
      );
    });
  });
}
