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

/// The outcome of an OS-level notification-permission request.
///
/// Callers should switch on this sealed class to handle each case explicitly
/// without a default branch — Dart's exhaustiveness checker guarantees no
/// branch is silently forgotten.
///
/// See [NotificationService.requestPermission] for the detection rules on
/// each platform.
sealed class PermissionRequestOutcome {
  const PermissionRequestOutcome();
}

/// The user granted notification permission, or permission was already granted.
final class PermissionGranted extends PermissionRequestOutcome {
  const PermissionGranted();
}

/// The user was shown the system dialog and explicitly denied permission.
///
/// The app may request again in a future session (OS policy permitting), but
/// must not show a settings-redirect prompt yet.
final class PermissionDenied extends PermissionRequestOutcome {
  const PermissionDenied();
}

/// The OS suppressed the system dialog because the user previously selected
/// "don't ask again" (Android) or because the app is permanently denied (iOS).
///
/// The only recovery path is navigating the user to the system settings panel.
/// See [NotificationService.openNotificationSettings].
final class PermissionBlocked extends PermissionRequestOutcome {
  const PermissionBlocked();
}

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
  /// Returns a [PermissionRequestOutcome] that callers must switch on
  /// exhaustively:
  /// - [PermissionGranted]: permission was granted or was already active.
  /// - [PermissionDenied]: the user dismissed or denied the system dialog.
  /// - [PermissionBlocked]: the OS suppressed the dialog because the user
  ///   previously selected "don't ask again" (Android) or the app is
  ///   permanently denied (iOS). Show a settings-redirect prompt; call
  ///   [openNotificationSettings] to take the user directly there.
  ///
  /// On Android 13+ (API 33+): captures `areNotificationsEnabled` before and
  /// after the plugin call to distinguish [PermissionDenied] from
  /// [PermissionBlocked].
  /// On Android < 13: no runtime permission required — always returns
  /// [PermissionGranted].
  /// On iOS: if already enabled (`checkPermissions().isEnabled == true`),
  /// returns [PermissionGranted] without showing a dialog again. Otherwise
  /// calls the notifications plugin `requestPermissions` and maps the result.
  /// On any unresolvable plugin state: returns [PermissionDenied] as a safe
  /// lower bound (never [PermissionBlocked] without confirming OS suppression).
  ///
  /// Only call this method when the user explicitly enables notifications
  /// (e.g. the settings-toggle-on flow). For cold-start re-checks use
  /// [hasNotificationPermission] — it never shows a system dialog.
  Future<PermissionRequestOutcome> requestPermission();

  /// Opens the OS notification-settings panel for this app.
  ///
  /// On Android: dispatches the system settings intent for in-app notification
  /// settings via a platform method channel handler in the Kotlin layer.
  /// On iOS: opens the iOS settings URL via the notifications plugin or via
  /// a sibling method channel handler in the Swift layer.
  ///
  /// Any platform-channel error is caught, logged via `debugPrint` prefixed
  /// with `[NotificationService.openNotificationSettings]`, and swallowed —
  /// this method never throws. The swallow policy mirrors
  /// [openBatteryOptimizationSettings].
  ///
  /// Only call this after receiving [PermissionBlocked] from
  /// [requestPermission], so the user is redirected with intent.
  Future<void> openNotificationSettings();

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
