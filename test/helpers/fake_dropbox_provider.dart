// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:typed_data';

import 'package:metra/core/errors/metra_exception.dart';
import 'package:metra/data/services/backup/backup_file_entry.dart';
import 'package:metra/data/services/backup/backup_filename.dart';
import 'package:metra/data/services/backup/dropbox_provider.dart';

/// In-memory [CloudBackupProvider] for tests.
///
/// Two list modes:
/// - **Seed mode** (`seedEntries` provided): [listFiles] returns the provided
///   list verbatim; the [files] upload map is still written by [upload] but is
///   not reflected in [listFiles]. Use this mode when a test exercises
///   picker/list behaviour (TASK-05 + TASK-18 tests).
/// - **Files-map mode** (default, `seedEntries` is null): [listFiles]
///   synthesises [BackupFileEntry] objects from the [files] upload map,
///   preserving the original sort-descending behaviour. Use this mode for
///   `SyncOrchestrator` round-trip tests that drive uploads through [upload].
class FakeDropboxProvider implements CloudBackupProvider {
  FakeDropboxProvider({this.seedEntries});

  final Map<String, Uint8List> files = {};

  /// When non-null, [listFiles] returns this list instead of synthesising
  /// entries from [files]. Mutable so tests can assign after construction.
  List<BackupFileEntry>? seedEntries;

  bool failNextUpload = false;
  bool failNextDownload = false;

  /// Simulates the email returned by [currentEmail].
  /// Set to null to simulate an email fetch failure.
  String? currentEmailResult = 'user@example.com';

  /// When true, the next [listFiles] call throws once, then resets to false.
  bool failNextList = false;

  /// When non-null, [listFiles] always throws this exception (not reset after
  /// throwing). Use when a test needs a persistent, typed error from list.
  SyncException? listFilesThrows;

  /// Records the filename argument of the most recent [download] call.
  String? downloadCalledWith;

  /// When non-null and the requested filename is a key, throws the mapped
  /// [SyncException] instead of looking up [files]. Checked before [files].
  Map<String, SyncException>? downloadThrows;

  /// Records every filename passed to [deleteFile] (successes and failures).
  final List<String> deleteCalls = [];

  /// When a key is present, [deleteFile] throws the mapped exception for that
  /// filename instead of removing it from [files]. The call is still recorded
  /// in [deleteCalls].
  Map<String, Exception>? deleteThrows;

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
    downloadCalledWith = filename;
    if (failNextDownload) {
      failNextDownload = false;
      throw const SyncException('download failed');
    }
    final configured = downloadThrows?[filename];
    if (configured != null) throw configured;
    final blob = files[filename];
    if (blob == null) throw SyncException('not found: $filename');
    return blob;
  }

  @override
  Future<List<BackupFileEntry>> listFiles() async {
    if (listFilesThrows != null) throw listFilesThrows!;
    if (failNextList) {
      failNextList = false;
      throw Exception('list failed');
    }
    if (seedEntries != null) {
      return List<BackupFileEntry>.from(seedEntries!);
    }
    // Files-map mode: synthesise BackupFileEntry objects from uploaded files.
    final names = files.keys.toList()..sort((a, b) => b.compareTo(a));
    return names.map((name) {
      final ts = BackupFilename.parseTimestamp(name) ?? DateTime.utc(0);
      return BackupFileEntry(
        name: name,
        timestampUtc: ts,
        sizeBytes: files[name]!.length,
      );
    }).toList();
  }

  @override
  Future<void> deleteFile(String filename) async {
    deleteCalls.add(filename);
    final configured = deleteThrows?[filename];
    if (configured != null) throw configured;
    files.remove(filename);
  }
}
