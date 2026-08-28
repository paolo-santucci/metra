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

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:icloud_storage/icloud_storage.dart'; // rule-8: no existing lib covers iCloud-container access
import 'package:path_provider/path_provider.dart';

import 'icloud_gateway.dart';

/// Production implementation of [IcloudGateway] backed by the
/// [ICloudStorage] static plugin API against the container
/// [_containerId] (`iCloud.com.paolosantucci.metra`).
///
/// The [IcloudGateway] seam is byte-oriented; this class bridges the
/// path-oriented [ICloudStorage] API by staging bytes through a temporary
/// file for uploads and downloads, then cleaning up immediately
/// (spec §4.3 Decision 1). All plugin types ([ICloudFile]) are confined to
/// this class and never cross the [IcloudGateway] boundary (NFR-07).
///
/// **No native call is made until a method is invoked** (FR-14). The
/// constructor stores nothing and performs no I/O; merely resolving the
/// provider on Android or the Linux CI runner is side-effect-free.
///
/// This is the ONLY file in the project that imports
/// [package:icloud_storage] (TASK-06 scope rule, NFR-07).
class ProductionIcloudGateway implements IcloudGateway {
  /// The iCloud container identifier, matching `ios/Runner/Runner.entitlements`.
  static const _containerId = 'iCloud.com.paolosantucci.metra';

  /// Container availability / sign-in probe.
  ///
  /// Calls [ICloudStorage.gather] as the lightest non-interactive probe: it
  /// returns normally when the container is accessible and the user is signed
  /// in to iCloud, and throws [PlatformException] with code `'E_CTR'` when
  /// signed-out or the container is unavailable.
  @override
  Future<void> ensureAvailable() async {
    await ICloudStorage.gather(containerId: _containerId);
  }

  /// Writes [blob] to [relativePath] in the iCloud container.
  ///
  /// Bridges [Uint8List] → temp file → [ICloudStorage.upload] → delete temp.
  /// [ICloudStorage.upload] is eventually consistent: the entry is NOT
  /// guaranteed visible to [gather] on return (the [IcloudProvider] poll
  /// handles this).
  @override
  Future<void> upload(Uint8List blob, String relativePath) async {
    final dir = await getTemporaryDirectory();
    final tempFile = File('${dir.path}/$relativePath');
    try {
      await tempFile.writeAsBytes(blob, flush: true);
      await ICloudStorage.upload(
        containerId: _containerId,
        filePath: tempFile.path,
        destinationRelativePath: relativePath,
      );
    } finally {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }

  /// Lists the container's current entries.
  ///
  /// Maps [ICloudFile] → [IcloudEntry] so that [ICloudFile] never crosses
  /// the seam boundary (NFR-07). [ICloudFile.sizeInBytes] is always provided
  /// by the plugin (sourced from NSMetadataItemFSSizeKey); it may be 0 for
  /// files not yet downloaded — [IcloudProvider] applies the `?? 0` fallback.
  @override
  Future<List<IcloudEntry>> gather() async {
    final files = await ICloudStorage.gather(containerId: _containerId);
    return files
        .map(
          (f) => IcloudEntry(
            relativePath: f.relativePath,
            sizeBytes: f.sizeInBytes,
          ),
        )
        .toList();
  }

  /// Returns the bytes at [relativePath].
  ///
  /// Bridges [ICloudStorage.download] → temp file → [Uint8List] → delete temp.
  ///
  /// **icloud_storage 2.2.0 eventual-consistency contract:**
  /// The `ICloudStorage.download()` future completes immediately — it returns
  /// `result(nil)` from the native side before the file exists at
  /// `destinationFilePath`. The native plugin starts an `NSMetadataQuery`
  /// asynchronously; only when the downloading status becomes `.current` does
  /// it copy bytes to `destinationFilePath` via `moveCloudFile`, after which it
  /// emits `FlutterEndOfEventStream` to close the Dart `onProgress` stream.
  ///
  /// Awaiting the `download()` future alone is therefore NOT sufficient —
  /// `readAsBytes()` would run before the file exists, producing a
  /// `PathNotFoundException`. The `onProgress` stream close (`onDone`) is the
  /// only reliable completion signal. This method attaches a [Completer] to the
  /// stream's `onDone` / `onError` callbacks and awaits it (with a bounded
  /// [Duration] timeout that throws rather than reading a missing file) before
  /// calling `readAsBytes()`. This mirrors the upload eventual-consistency
  /// handling in [IcloudProvider.upload] — the difference is that upload polls
  /// [IcloudGateway.gather], whereas download uses the plugin's native stream.
  @override
  Future<Uint8List> download(String relativePath) async {
    final dir = await getTemporaryDirectory();
    final tempPath = '${dir.path}/$relativePath';
    final tempFile = File(tempPath);

    // Declared before the download call so the onProgress closure captures it.
    // The native side invokes onProgress(stream) synchronously before
    // result(nil), ensuring the listener is attached before any events fire.
    final completer = Completer<void>();

    try {
      await ICloudStorage.download(
        containerId: _containerId,
        relativePath: relativePath,
        destinationFilePath: tempPath,
        onProgress: (Stream<double> stream) {
          stream.listen(
            null, // progress percentages not needed
            onDone: () {
              if (!completer.isCompleted) completer.complete();
            },
            onError: (Object error) {
              if (!completer.isCompleted) completer.completeError(error);
            },
            cancelOnError: true,
          );
        },
      );

      // The download() future returns before the file is materialised. Wait for
      // the onProgress stream to close — the native side emits
      // FlutterEndOfEventStream after copying bytes to destinationFilePath.
      // A bounded timeout throws (TimeoutException) rather than reading a
      // missing file, surfacing a stuck download as a clear error.
      await completer.future.timeout(const Duration(seconds: 60));

      return await tempFile.readAsBytes();
    } finally {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }

  /// Deletes [relativePath] from the container.
  @override
  Future<void> delete(String relativePath) async {
    await ICloudStorage.delete(
      containerId: _containerId,
      relativePath: relativePath,
    );
  }
}
