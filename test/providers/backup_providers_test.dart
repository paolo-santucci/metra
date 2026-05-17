// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/errors/metra_exception.dart';
import 'package:metra/data/services/backup/backup_file_entry.dart';
import 'package:metra/data/services/backup/dropbox_provider.dart';
import 'package:metra/providers/backup_providers.dart';

import '../helpers/fake_dropbox_provider.dart';

void main() {
  group('cloudBackupProvider', () {
    test(
      'resolves to a CloudBackupProvider and can be overridden with FakeDropboxProvider',
      () {
        final fake = FakeDropboxProvider();
        final container = ProviderContainer(
          overrides: [cloudBackupProvider.overrideWithValue(fake)],
        );
        addTearDown(container.dispose);

        final result = container.read(cloudBackupProvider);

        expect(result, isA<CloudBackupProvider>());
        expect(result, same(fake));
      },
    );
  });

  group('backupFileListProvider', () {
    test('success: 3 entries -> AsyncData length 3', () async {
      final container = ProviderContainer(
        overrides: [
          cloudBackupProvider.overrideWithValue(
            FakeDropboxProvider(
              seedEntries: [
                BackupFileEntry(
                  name: 'a.enc',
                  timestampUtc: DateTime.utc(2026),
                  sizeBytes: 1,
                ),
                BackupFileEntry(
                  name: 'b.enc',
                  timestampUtc: DateTime.utc(2026, 1, 2),
                  sizeBytes: 1,
                ),
                BackupFileEntry(
                  name: 'c.enc',
                  timestampUtc: DateTime.utc(2026, 1, 3),
                  sizeBytes: 1,
                ),
              ],
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(backupFileListProvider.future);

      expect(result.length, equals(3));
    });

    test('error: listFilesThrows -> AsyncError with SyncException', () async {
      final container = ProviderContainer(
        overrides: [
          cloudBackupProvider.overrideWithValue(
            FakeDropboxProvider()
              ..listFilesThrows = const SyncException('network-error'),
          ),
        ],
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(backupFileListProvider.future),
        throwsA(isA<SyncException>()),
      );
    });
  });
}
