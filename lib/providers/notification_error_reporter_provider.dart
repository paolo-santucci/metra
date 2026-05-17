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

// NFR-03: This file must NOT import anything from lib/data/ or
// package:metra/data/. The abstraction lives entirely in the UI/provider
// layer and depends only on Flutter + Riverpod primitives.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:metra/app.dart' show scaffoldMessengerKey;

/// Abstraction over snackbar dispatch used by async [ref.listen] callbacks.
///
/// Decouples the listener logic from [BuildContext] so that TASK-08
/// integration tests can override this provider with a [FakeNotificationErrorReporter]
/// on Linux CI without a live [ScaffoldMessengerState].
///
/// Production implementation: [_ScaffoldMessengerReporter].
/// Test double: `FakeNotificationErrorReporter` in `test/helpers/`.
abstract class NotificationErrorReporter {
  /// Surfaces [message] to the user as a transient snackbar.
  ///
  /// Implementations must be a no-op when the underlying surface is
  /// unavailable (EC-12: null currentState race on cold start).
  void report(String message);
}

/// Production [NotificationErrorReporter] that dispatches via the global
/// [scaffoldMessengerKey].
///
/// The `?.` null-safe call on [GlobalKey.currentState] defends against the
/// EC-12 cold-start race: if the listener fires before the [MaterialApp] has
/// completed its first build, [currentState] is null and [report] is a no-op.
class _ScaffoldMessengerReporter implements NotificationErrorReporter {
  const _ScaffoldMessengerReporter(this._key);

  final GlobalKey<ScaffoldMessengerState> _key;

  @override
  void report(String message) {
    _key.currentState?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

/// Riverpod provider exposing the [NotificationErrorReporter] singleton.
///
/// Override with [FakeNotificationErrorReporter] in tests (TASK-08, FR-14)
/// to assert on exactly how many snackbars were dispatched without mounting
/// a live [ScaffoldMessenger].
///
/// NFR-03: no import from lib/data/ in this file.
final notificationErrorReporterProvider = Provider<NotificationErrorReporter>(
  (ref) => _ScaffoldMessengerReporter(scaffoldMessengerKey),
);
