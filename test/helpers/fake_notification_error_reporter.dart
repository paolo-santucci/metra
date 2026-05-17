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

import 'package:metra/providers/notification_error_reporter_provider.dart';

/// Test double for [NotificationErrorReporter].
///
/// Records every [report] call in [messages] so tests can assert on the
/// exact sequence of error strings dispatched by the listener logic
/// (e.g. TASK-08 FR-14: "exactly one snackbar dispatched on schedule failure").
class FakeNotificationErrorReporter implements NotificationErrorReporter {
  final List<String> messages = [];

  @override
  void report(String message) => messages.add(message);
}
