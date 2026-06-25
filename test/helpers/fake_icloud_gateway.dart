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
import 'package:metra/data/services/backup/icloud_gateway.dart';

/// In-memory [IcloudGateway] for tests.
///
/// Supports three tunable behaviours:
///
/// **Visibility model** (`invisibleForGatherCalls`): a blob written by
/// [upload] does not appear in [gather] results for the first
/// [invisibleForGatherCalls] calls after the upload. On the
/// `(invisibleForGatherCalls + 1)`-th call it becomes visible. The default
/// (`0`) makes every upload immediately visible on the next [gather].
///
/// **Signed-out simulation** (`signedIn`): when `false`, [ensureAvailable]
/// throws a [PlatformException] to simulate the user not being signed into
/// iCloud.
///
/// **Quota simulation** (`throwQuotaOnNextUpload`): set to `true` before
/// calling [upload] to make that call throw a [PlatformException] whose
/// `code` equals [IcloudGateway.kQuotaExceededCode].
class FakeIcloudGateway implements IcloudGateway {
  FakeIcloudGateway({
    int invisibleForGatherCalls = 0,
    this.signedIn = true,
  }) : _invisibleForGatherCalls = invisibleForGatherCalls;

  /// Blobs stored by [upload], keyed by relative path.
  final Map<String, Uint8List> store = {};

  /// Number of [gather] calls during which a just-uploaded blob stays hidden.
  final int _invisibleForGatherCalls;

  /// When `false`, [ensureAvailable] throws [PlatformException].
  bool signedIn;

  /// Set to `true` before calling [upload] to make the next upload throw
  /// [PlatformException] with code [IcloudGateway.kQuotaExceededCode].
  bool throwQuotaOnNextUpload = false;

  // Tracks remaining invisible-gather-calls per path after upload.
  final Map<String, int> _pendingVisibility = {};

  @override
  Future<void> ensureAvailable() async {
    if (!signedIn) {
      throw PlatformException(
        code: 'USER_NOT_SIGNED_IN',
        message: 'Simulated: user is not signed in to iCloud',
      );
    }
  }

  @override
  Future<void> upload(Uint8List blob, String relativePath) async {
    if (throwQuotaOnNextUpload) {
      throwQuotaOnNextUpload = false;
      throw PlatformException(
        code: IcloudGateway.kQuotaExceededCode,
        message: 'Simulated: iCloud storage quota exceeded',
      );
    }
    store[relativePath] = blob;
    _pendingVisibility[relativePath] = _invisibleForGatherCalls;
  }

  @override
  Future<List<IcloudEntry>> gather() async {
    final result = <IcloudEntry>[];
    for (final path in store.keys) {
      final remaining = _pendingVisibility[path] ?? 0;
      if (remaining > 0) {
        // Still invisible: decrement the counter and skip this entry.
        _pendingVisibility[path] = remaining - 1;
      } else {
        // Visible: include in results.
        result.add(
          IcloudEntry(relativePath: path, sizeBytes: store[path]!.length),
        );
      }
    }
    return result;
  }

  @override
  Future<Uint8List> download(String relativePath) async {
    final blob = store[relativePath];
    if (blob == null) {
      throw PlatformException(
        code: 'FILE_NOT_FOUND',
        message: 'Simulated: file not found at $relativePath',
      );
    }
    return blob;
  }

  @override
  Future<void> delete(String relativePath) async {
    store.remove(relativePath);
    _pendingVisibility.remove(relativePath);
  }
}
