// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:typed_data';

import 'package:metra/core/errors/metra_exception.dart';
import 'package:metra/data/services/backup/dropbox_provider.dart';

class FakeDropboxProvider implements CloudBackupProvider {
  final Map<String, Uint8List> files = {};
  bool failNextUpload = false;
  bool failNextDownload = false;

  /// Simulates the email returned by [currentEmail].
  /// Set to null to simulate an email fetch failure.
  String? currentEmailResult = 'user@example.com';

  /// When true, the next [listFiles] call throws once, then resets to false.
  bool failNextList = false;

  @override
  Future<void> authorize() async {}

  @override
  Future<String?> currentEmail() async => currentEmailResult;

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> upload(Uint8List blob, String filename) async {
    if (failNextUpload) {
      failNextUpload = false;
      throw const SyncException('upload failed');
    }
    files[filename] = blob;
  }

  @override
  Future<Uint8List> download(String filename) async {
    if (failNextDownload) {
      failNextDownload = false;
      throw const SyncException('download failed');
    }
    final blob = files[filename];
    if (blob == null) throw SyncException('not found: $filename');
    return blob;
  }

  @override
  Future<List<String>> listFiles() async {
    if (failNextList) {
      failNextList = false;
      throw Exception('list failed');
    }
    return files.keys.toList()..sort((a, b) => b.compareTo(a));
  }

  @override
  Future<void> deleteFile(String filename) async => files.remove(filename);
}
