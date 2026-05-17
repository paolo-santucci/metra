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

/// The result of attempting to schedule a prediction notification.
///
/// Callers should switch on this sealed class to handle each case explicitly.
/// M1: [SchedulePredictionNotification.execute] binds but does not consume the
/// result — full wiring happens in M4.
sealed class NotificationScheduleResult {
  const NotificationScheduleResult();
}

/// The notification was scheduled successfully.
final class NotificationScheduleSuccess extends NotificationScheduleResult {
  const NotificationScheduleSuccess();
}

/// The scheduling attempt failed; [error] carries the original exception.
///
/// [error] is typed [Object] (not [PlatformException]) to keep the domain
/// layer free of Flutter platform imports — callers in the data layer
/// may safely cast to [PlatformException] when they know the origin.
final class NotificationScheduleFailure extends NotificationScheduleResult {
  const NotificationScheduleFailure(this.error);

  final Object error;
}

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
  ///
  /// Returns [NotificationScheduleSuccess] on success or
  /// [NotificationScheduleFailure] wrapping the original exception on failure.
  Future<NotificationScheduleResult> schedulePredictionNotification(
    DateTime notifyAt,
    String title,
    String body,
  );

  /// Cancels the prediction-reminder notification if one is scheduled.
  Future<void> cancelPredictionNotifications();

  /// Requests the OS-level notification permission.
  ///
  /// **Fail-closed policy**: a [null] response from the OS plugin is treated
  /// as [false] — an explicit request with an indeterminate response is not
  /// silently granted.
  ///
  /// On Android 13+ (API 33+): calls the plugin's
  /// `requestNotificationsPermission()`. Subsequent calls after denial return
  /// [false] immediately without showing a dialog again; the user must go to
  /// Android Settings to re-enable.
  /// On Android < 13: returns [true] (no runtime permission required).
  /// On iOS: calls `requestPermissions(sound: true, alert: true, badge: true)`
  /// on the plugin's [IOSFlutterLocalNotificationsPlugin] resolved via
  /// `resolvePlatformSpecificImplementation`. A [null] result is fail-closed:
  /// returns [false].
  ///
  /// Only call this method when the user explicitly enables notifications
  /// (e.g. the settings-toggle-on flow). For cold-start re-checks, use
  /// [hasNotificationPermission] instead — it never shows a system dialog.
  Future<bool> requestPermission();

  /// Read-only check: returns [true] if Métra currently has the OS-level
  /// notification permission, without re-prompting the user.
  ///
  /// **Fail-open policy**: any [null] response or platform query failure is
  /// treated as [true] — do not block scheduling over a query failure.
  ///
  /// On Android < 13: returns [true] (no runtime permission required).
  /// On Android 13+: queries the system permission state without showing
  /// a dialog (uses the plugin's `areNotificationsEnabled()`).
  /// On iOS: calls `checkPermissions()` on the plugin's
  /// [IOSFlutterLocalNotificationsPlugin] resolved via
  /// `resolvePlatformSpecificImplementation`; returns
  /// `NotificationsEnabledOptions.isEnabled`, or [true] on a [null] result
  /// (fail-open).
  /// On any platform error: returns [true] (fail-open).
  ///
  /// Use this method for cold-start re-checks (FR-07). Use [requestPermission]
  /// only when the user explicitly enables notifications.
  Future<bool> hasNotificationPermission();

  /// Returns true if Métra is on the OS battery-optimisation whitelist.
  ///
  /// On iOS: returns [true] (no concept exists on that platform).
  /// On Android < 23 (M, no Doze mode): returns [true].
  /// On any platform error: returns [false] without throwing.
  Future<bool> isIgnoringBatteryOptimizations();

  /// Opens the OS battery-optimisation settings panel for Métra so the
  /// user can toggle the whitelist exemption.
  ///
  /// On iOS: no-op (returns immediately; no equivalent concept exists).
  /// On Android < 23: no-op.
  /// On intent-rejection (OEM custom builds): emits a [debugPrint] line
  /// prefixed with `[NotificationService.openBatteryOpt]` and returns
  /// without throwing.
  Future<void> openBatteryOptimizationSettings();
}
