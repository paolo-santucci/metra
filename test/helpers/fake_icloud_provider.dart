// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:typed_data';

import 'package:metra/core/errors/metra_exception.dart';
import 'package:metra/data/services/backup/backup_file_entry.dart';
import 'package:metra/data/services/backup/cloud_backup_provider.dart';
import 'package:metra/domain/entities/sync_log_entity.dart';

/// In-memory [CloudBackupProvider] for iCloud tests.
///
/// A minimal test double that implements the [CloudBackupProvider] interface
/// with [id == SyncProvider.iCloud]. Used by connected-predicate, orchestrator,
/// and sync-log tests that need to assert on iCloud provider interactions
/// without instantiating the real [IcloudProvider] or native iCloud backend.
class FakeICloudProvider implements CloudBackupProvider {
  /// Constructs a fake iCloud provider.
  ///
  /// If [authorizeThrows] is true, [authorize] will throw a [SyncException].
  FakeICloudProvider({this.authorizeThrows = false});

  /// When true, [authorize] throws a [SyncException].
  final bool authorizeThrows;

  @override
  SyncProvider get id => SyncProvider.iCloud;

  @override
  Future<void> authorize() async {
    if (authorizeThrows) {
      throw const SyncException('iCloud authorization failed');
    }
  }

  @override
  Future<String?> currentEmail() async => null;

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
