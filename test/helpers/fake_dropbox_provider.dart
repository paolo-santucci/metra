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
  Future<List<String>> listFiles() async =>
      files.keys.toList()..sort((a, b) => b.compareTo(a));

  @override
  Future<void> deleteFile(String filename) async => files.remove(filename);
}
