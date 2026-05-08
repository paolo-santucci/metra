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

/// Abstract interface for scheduling and cancelling local notifications.
///
/// Lives in the domain layer — no Flutter or platform imports.
/// The concrete implementation is [FlutterNotificationService] in data/.
abstract class NotificationService {
  /// Initialises the notification plugin and platform channels.
  ///
  /// Must be called once before any other method, typically from [main].
  Future<void> initialize();

  /// Schedules a single prediction-reminder notification.
  ///
  /// The notification fires at the local time encoded in [notifyAt].
  /// Any previously scheduled prediction notification is replaced
  /// (same stable ID is reused).
  Future<void> schedulePredictionNotification(
    DateTime notifyAt,
    String title,
    String body,
  );

  /// Cancels the prediction-reminder notification if one is scheduled.
  Future<void> cancelPredictionNotifications();

  /// Requests the OS-level notification permission (Android 13+ / API 33+).
  ///
  /// Returns [true] if permission is granted (or pre-granted for the current
  /// OS version / platform).  On iOS, permissions are handled automatically
  /// during [initialize] — this method returns [true] on that platform.
  /// Subsequent calls after denial return [false] immediately without showing
  /// a dialog again; the user must go to Android Settings to re-enable.
  Future<bool> requestPermission();
}
