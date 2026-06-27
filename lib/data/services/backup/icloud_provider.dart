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

import '../../../core/errors/metra_exception.dart';
import '../../../domain/entities/sync_log_entity.dart';
import 'backup_file_entry.dart';
import 'backup_filename.dart';
import 'cloud_backup_provider.dart';
import 'icloud_gateway.dart';

/// iCloud Drive backup provider implementing [CloudBackupProvider].
///
/// Responsibilities:
///  - Idempotent, non-interactive [authorize] via [IcloudGateway.ensureAvailable].
///  - Bounded read-after-write poll in [upload] so [SyncOrchestrator] can
///    assume synchronous list-after-write semantics (FR-03/04).
///  - Newest-first [listFiles] filtered to `metra_backup_*.enc` (FR-05/06).
///  - Quota [PlatformException] → [InsufficientStorageException] mapping (FR-07).
///
/// No crypto, no OAuth, no token storage — the orchestrator supplies opaque
/// AES-256-GCM blobs; this provider stores and retrieves them unchanged
/// (NFR-01). The [IcloudGateway] seam keeps all plugin types below this class
/// boundary (NFR-07).
class IcloudProvider implements CloudBackupProvider {
  IcloudProvider({
    required IcloudGateway gateway,
    // ignore: use_setters_to_change_properties — stored once in initialiser list
    Future<void> Function(Duration)? delay,
  })  : _gateway = gateway,
        _delay = delay ?? Future.delayed;

  static const _filePrefix = 'metra_backup_';
  static const _fileSuffix = '.enc';

  /// Maximum number of [IcloudGateway.gather] calls during the
  /// read-after-write poll inside [upload].
  ///
  /// Concrete value is an architect decision (spec §4.3 Decision 2, OQ-02);
  /// validated/tuned on-device at M6.
  static const kIcloudPollMaxAttempts = 10;

  /// Wait between consecutive [IcloudGateway.gather] attempts.
  static const kIcloudPollInterval = Duration(milliseconds: 500);

  final IcloudGateway _gateway;
  final Future<void> Function(Duration) _delay;

  // ---------------------------------------------------------------------------
  // CloudBackupProvider — identity
  // ---------------------------------------------------------------------------

  @override
  SyncProvider get id => SyncProvider.iCloud;

  /// Returns `null` — iCloud has no OAuth flow and no email identifier (FR-01).
  @override
  Future<String?> currentEmail() async => null;

  /// No-op: iCloud holds no token keys.
  ///
  /// Connected-sentinel reset (activeProvider/passphrase) is the notifier's
  /// responsibility, not the provider's (FR-01).
  @override
  Future<void> disconnect() async {}

  // ---------------------------------------------------------------------------
  // CloudBackupProvider — authorize
  // ---------------------------------------------------------------------------

  /// Probes the iCloud container for availability.
  ///
  /// Idempotent and non-interactive — no system prompt. Doubles as the
  /// connection probe for [BackupNotifier._isConnected] (§4.3 Decision 4).
  /// Maps [PlatformException] → [SyncException] (NFR-06).
  @override
  Future<void> authorize() async {
    try {
      await _gateway.ensureAvailable();
    } on PlatformException catch (e) {
      throw SyncException('iCloud unavailable: ${e.code}');
    }
  }

  // ---------------------------------------------------------------------------
  // CloudBackupProvider — upload (bounded read-after-write poll, FR-03/04)
  // ---------------------------------------------------------------------------

  /// Writes [blob] to [filename], then runs a best-effort bounded poll via
  /// [IcloudGateway.gather] to give the orchestrator a chance to see the file.
  ///
  /// **Success criterion for iCloud (eventually consistent):** a successful
  /// gateway write is sufficient. The read-after-write poll is courtesy-only;
  /// exhaustion without visibility is NOT an error — the OS owns sync timing
  /// (§3.1 semantic contract).
  ///
  /// Error mapping:
  ///  - quota [PlatformException] (`code == kQuotaExceededCode`)
  ///        → throws [InsufficientStorageException] (FR-07)
  ///  - any other [PlatformException] on the write
  ///        → throws [SyncException] (FR-07-neg)
  ///  - poll exhausted without visibility
  ///        → returns normally (iCloud eventual consistency — §3.1)
  @override
  Future<void> upload(Uint8List blob, String filename) async {
    try {
      await _gateway.upload(blob, filename);
    } on PlatformException catch (e) {
      if (e.code == IcloudGateway.kQuotaExceededCode) {
        throw const InsufficientStorageException();
      }
      throw SyncException('upload failed: ${e.code}');
    }

    // Bounded poll: up to kIcloudPollMaxAttempts gather() calls.
    // Delay is injected so fake_async can drive the loop deterministically.
    // Off-by-one guard: no trailing delay after the final attempt (EC-04).
    for (var attempt = 0; attempt < kIcloudPollMaxAttempts; attempt++) {
      final entries = await _gateway.gather();
      final visible = entries.any((e) => e.relativePath == filename);
      if (visible) return;
      if (attempt < kIcloudPollMaxAttempts - 1) {
        await _delay(kIcloudPollInterval);
      }
    }

    // Poll exhausted without visibility — normal for iCloud's eventual
    // consistency (§3.1 semantic contract). A successful gateway write is the
    // success criterion; non-visibility within the poll window is not an error.
    // The method returns implicitly (Future<void>).
  }

  // ---------------------------------------------------------------------------
  // CloudBackupProvider — listFiles (FR-05/06)
  // ---------------------------------------------------------------------------

  /// Returns all `metra_backup_*.enc` entries from the container, sorted
  /// newest-first by filename (lexicographic descending on the embedded UTC
  /// timestamp).
  ///
  /// Mapping:
  ///  - [IcloudEntry.sizeBytes] `== null` → `sizeBytes = 0` (FR-06)
  ///  - Empty container or no matching entries → `const []` (never throws, FR-05)
  @override
  Future<List<BackupFileEntry>> listFiles() async {
    final entries = await _gateway.gather();
    if (entries.isEmpty) return const [];

    final result = <BackupFileEntry>[];
    for (final entry in entries) {
      final name = entry.relativePath;
      // Quick pre-filter on prefix/suffix; parseTimestamp validates the full
      // datetime segment.
      if (!name.startsWith(_filePrefix) || !name.endsWith(_fileSuffix)) {
        continue;
      }
      final timestamp = BackupFilename.parseTimestamp(name);
      if (timestamp == null) continue;
      result.add(
        BackupFileEntry(
          name: name,
          timestampUtc: timestamp,
          sizeBytes: entry.sizeBytes ?? 0,
        ),
      );
    }

    if (result.isEmpty) return const [];
    // Newest-first: sort by name descending (timestamp is embedded in name,
    // so lexicographic order == chronological order — same convention as
    // DropboxProvider and GoogleDriveProvider).
    result.sort((a, b) => b.name.compareTo(a.name));
    return result;
  }

  // ---------------------------------------------------------------------------
  // CloudBackupProvider — download / deleteFile
  // ---------------------------------------------------------------------------

  @override
  Future<Uint8List> download(String filename) async {
    try {
      return await _gateway.download(filename);
    } on PlatformException catch (e) {
      throw SyncException('download failed: ${e.code}');
    }
  }

  @override
  Future<void> deleteFile(String filename) async {
    try {
      await _gateway.delete(filename);
    } on PlatformException catch (e) {
      throw SyncException('delete failed: ${e.code}');
    }
  }
}
