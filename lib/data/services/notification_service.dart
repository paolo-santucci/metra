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

import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:metra/domain/services/notification_service.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Concrete [NotificationService] backed by [flutter_local_notifications].
///
/// Notification channel: "metra_cycle" (high importance).
///
/// Android scheduling mode: uses [AndroidScheduleMode.inexactAllowWhileIdle].
/// Cycle reminders fire within Doze's ~15 min window — acceptable for a
/// daily reminder and avoids the SCHEDULE_EXACT_ALARM permission, which is
/// not auto-granted on Android 14+ and is policy-gated for non-alarm-clock
/// apps. The manifest no longer declares SCHEDULE_EXACT_ALARM.
///
/// Battery-optimisation channel: "metra/battery_optimization".
/// Routes two methods to the MainActivity Kotlin handler:
///   - `isIgnoring` → PowerManager.isIgnoringBatteryOptimizations
///   - `openSettings` → Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
class FlutterNotificationService implements NotificationService {
  static const _kBatteryOptChannel =
      MethodChannel('metra/battery_optimization');

  /// Stable ID for the single prediction-reminder notification.
  ///
  /// Must never change: changing it would orphan any already-scheduled
  /// notification on devices that have not yet been updated.
  static const int kPredictionNotificationId = 1001;

  static const String _kChannelId = 'metra_cycle';
  static const String _kChannelName = 'Mētra — Ciclo';

  FlutterNotificationService({
    @visibleForTesting FlutterLocalNotificationsPlugin? pluginOverride,
  }) : _plugin = pluginOverride ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  @override
  Future<void> initialize() async {
    tz.initializeTimeZones();
    try {
      final timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } on Exception {
      // Fall back to UTC if timezone detection fails (unsupported platform,
      // unknown IANA name, or method channel not registered in tests).
      debugPrint(
        'FlutterNotificationService: timezone detection failed; '
        'falling back to UTC.',
      );
      tz.setLocalLocation(tz.UTC);
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _plugin.initialize(settings);

    // Create the Android notification channel once; a no-op on re-creates.
    const channel = AndroidNotificationChannel(
      _kChannelId,
      _kChannelName,
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Computes the exact local TZDateTime for the alarm on the calendar
  /// day of [notifyAt] in the device's local timezone, at the hour and
  /// minute encoded in [notifyAt].
  ///
  /// BUG-004 fix: [notifyAt] may be a UTC datetime. We convert to local first
  /// so that users at negative-UTC-offset get the correct local calendar day
  /// (not one day late). For example, UTC midnight 2026-06-08 in UTC-5 (New
  /// York) becomes 2026-06-07 19:00 local, so the notification fires at the
  /// requested time on June 7 — the correct intended calendar day.
  @visibleForTesting
  tz.TZDateTime computeScheduledTz(DateTime notifyAt) {
    // Convert UTC instant to local timezone before extracting calendar
    // components. For positive-UTC-offset zones (e.g. Europe/Rome, UTC+2),
    // UTC midnight shifts forward to 02:00 on the same calendar day — no
    // regression. For negative-UTC-offset zones (e.g. America/New_York,
    // UTC-5), UTC midnight shifts back to 19:00 on the preceding local
    // calendar day, which is the correct intended day for the notification.
    // Use tz.TZDateTime.from() to respect the timezone package's tz.local
    // setting — this allows unit tests to call tz.setLocalLocation() and
    // have the conversion use the configured test timezone rather than the
    // OS timezone (which Dart's built-in toLocal() uses and cannot be
    // overridden in pure-Dart tests).
    //
    // Hour and minute are taken directly from notifyAt (the caller is
    // responsible for supplying the user-configured time-of-day), NOT from
    // the local conversion. This avoids the off-by-one that arose when the
    // time was hardcoded to 9.
    final local = tz.TZDateTime.from(notifyAt, tz.local);
    return tz.TZDateTime(
      tz.local,
      local.year,
      local.month,
      local.day,
      notifyAt.hour,
      notifyAt.minute,
    );
  }

  /// Returns true when [scheduledDate] is on the same calendar day as [now]
  /// AND [now] is at or after [scheduledDate] — meaning the configured alarm
  /// time has already passed today so the notification must be shown immediately.
  ///
  /// Pure predicate; no side-effects. @visibleForTesting to allow unit tests
  /// to exercise the branch logic without a platform channel.
  @visibleForTesting
  bool shouldShowImmediately(tz.TZDateTime scheduledDate, tz.TZDateTime now) {
    final sameDay = scheduledDate.year == now.year &&
        scheduledDate.month == now.month &&
        scheduledDate.day == now.day;
    return sameDay && !scheduledDate.isAfter(now);
  }

  @override
  Future<void> schedulePredictionNotification(
    DateTime notifyAt,
    String title,
    String body,
  ) async {
    // Fire at the time encoded in notifyAt on the correct local calendar day.
    final scheduledDate = computeScheduledTz(notifyAt);
    final now = tz.TZDateTime.now(tz.local);

    if (scheduledDate.isBefore(now)) {
      if (shouldShowImmediately(scheduledDate, now)) {
        // BUG-005 fix: cold-start on notification day after the scheduled time —
        // the scheduled alarm was cancelled by the listener before we got here.
        // Show immediately so the notification is not silently lost.
        await _plugin.show(
          kPredictionNotificationId,
          title,
          body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              _kChannelId,
              _kChannelName,
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
        );
      }
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      _kChannelId,
      _kChannelName,
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _plugin.zonedSchedule(
        kPredictionNotificationId,
        title,
        body,
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        // Absolute time — do not reinterpret as wall-clock time.
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: null,
      );
    } on PlatformException catch (e) {
      debugPrint(
        'FlutterNotificationService: zonedSchedule failed (${e.code}): ${e.message}',
      );
    }
  }

  @override
  Future<void> cancelPredictionNotifications() async {
    await _plugin.cancel(kPredictionNotificationId);
  }

  @override
  Future<bool> requestPermission() async {
    // On Android 13+ (API 33+), POST_NOTIFICATIONS is a runtime permission.
    // requestNotificationsPermission() shows the system dialog the first time;
    // subsequent calls return the persisted result without a dialog.
    // On iOS, permission is requested via DarwinInitializationSettings in
    // initialize() — resolvePlatformSpecificImplementation returns null there,
    // so we return true (already handled).
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return true;
    return await androidPlugin.requestNotificationsPermission() ?? true;
  }

  @override
  Future<bool> hasNotificationPermission() async {
    // areNotificationsEnabled() is read-only: returns the persisted permission
    // state without showing the system dialog. Available on Android 13+ via
    // POST_NOTIFICATIONS; on Android < 13 returns true (no runtime permission
    // required). On iOS, resolvePlatformSpecificImplementation returns null
    // (iOS permission is handled during initialize()), so we return true.
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return true;
    return await androidPlugin.areNotificationsEnabled() ?? true;
  }

  @override
  Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      final result = await _kBatteryOptChannel.invokeMethod<bool>('isIgnoring');
      // Kotlin handler returns Boolean; null means Android < 23 (no Doze),
      // which is treated as whitelisted (true).
      return result ?? true;
    } on PlatformException {
      // OEM error or unsupported path — treat as not-whitelisted so the
      // Settings row remains actionable.
      return false;
    }
  }

  @override
  Future<void> openBatteryOptimizationSettings() async {
    try {
      await _kBatteryOptChannel.invokeMethod<void>('openSettings');
    } on PlatformException catch (e) {
      debugPrint('[NotificationService.openBatteryOpt] $e');
    }
  }
}
