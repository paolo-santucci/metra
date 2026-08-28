// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:typed_data';

import 'package:metra/data/services/backup/backup_file_entry.dart';
import 'package:metra/data/services/backup/cloud_backup_provider.dart';
import 'package:metra/domain/entities/sync_log_entity.dart';

/// In-memory [CloudBackupProvider] for Google Drive tests.
///
/// A minimal test double that implements the [CloudBackupProvider] interface
/// with [id == SyncProvider.googleDrive]. Used by orchestrator and sync-log
/// tests that need to assert on Google Drive provider interactions without
/// mocking the full provider implementation.
class FakeGoogleDriveProvider implements CloudBackupProvider {
  @override
  SyncProvider get id => SyncProvider.googleDrive;

  @override
  Future<void> authorize() async {}

  @override
  Future<String?> currentEmail() async => 'user@example.com';

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> upload(Uint8List blob, String filename) async {}

  @override
  Future<Uint8List> download(String filename) async => Uint8List(0);

  @override
  Future<List<BackupFileEntry>> listFiles() async => <BackupFileEntry>[];

  @override
  Future<void> deleteFile(String filename) async {}
}
