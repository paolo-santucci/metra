// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:metra/data/services/backup/cloud_backup_provider.dart';
import 'package:metra/domain/entities/sync_log_entity.dart';

import 'fake_google_drive_provider.dart';

void main() {
  group('FakeGoogleDriveProvider', () {
    test('id == SyncProvider.googleDrive', () {
      final fake = FakeGoogleDriveProvider();
      expect(fake.id, SyncProvider.googleDrive);
    });

    test('implements CloudBackupProvider', () {
      final fake = FakeGoogleDriveProvider();
      expect(fake, isA<CloudBackupProvider>());
    });

    test('listFiles() returns empty list and does not throw', () async {
      final fake = FakeGoogleDriveProvider();
      final result = await fake.listFiles();
      expect(result, isEmpty);
    });

    test('upload() does not throw', () async {
      final fake = FakeGoogleDriveProvider();
      final blob = Uint8List.fromList([1, 2, 3]);
      expect(
        fake.upload(blob, 'metra_backup_X.enc'),
        completes,
      );
    });
  });
}
