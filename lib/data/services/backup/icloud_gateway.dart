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

import 'dart:typed_data';

import 'package:flutter/foundation.dart' show immutable;

/// A single iCloud-container entry as seen by the seam. Plugin types
/// (ICloudFile) never cross this boundary (NFR-07).
@immutable
class IcloudEntry {
  const IcloudEntry({required this.relativePath, this.sizeBytes});

  final String relativePath;

  /// `null` when the plugin reports no reliable size.
  final int? sizeBytes;
}

/// Injectable seam over the four static `icloud_storage` operations.
///
/// All members are byte-oriented so the fake implementation is a pure
/// in-memory [Map] with no file I/O (spec §4.3 Decision 1). No member
/// imports or exposes any `package:icloud_storage` type (NFR-07).
abstract interface class IcloudGateway {
  /// Container availability / sign-in probe. Returns normally when the iCloud
  /// container is reachable; throws [PlatformException] when signed-out or the
  /// container is unavailable. Non-interactive (no system prompt).
  Future<void> ensureAvailable();

  /// Writes [blob] to [relativePath] in the container. Eventually consistent:
  /// the entry is NOT guaranteed visible to [gather] on return.
  ///
  /// Throws [PlatformException]; `code == kQuotaExceededCode` signals
  /// storage-full.
  Future<void> upload(Uint8List blob, String relativePath);

  /// Lists the container's current entries (possibly stale — see [upload]).
  ///
  /// Empty container ⇒ `const []`. Throws [PlatformException] on container
  /// error.
  Future<List<IcloudEntry>> gather();

  /// Returns the bytes at [relativePath]. Throws [PlatformException] if absent.
  Future<Uint8List> download(String relativePath);

  /// Deletes [relativePath]. Throws [PlatformException] on failure.
  Future<void> delete(String relativePath);

  /// The [PlatformException.code] the plugin raises on quota/storage-full.
  ///
  /// Pinned as ONE named constant because the exact code cannot be confirmed
  /// off-device; MUST be verified on a physical device at M6 (OQ-01, §6.1
  /// EC-08). If the plugin surfaces no explicit quota signal, the 507 loop
  /// cannot engage and retention=3 still prunes on every successful upload
  /// (parent OQ-04) — that fallback is documented in IcloudProvider.
  // TODO(M6): confirm against the real icloud_storage PlatformException code
  static const String kQuotaExceededCode = 'E_QUOTA_EXCEEDED';
}
