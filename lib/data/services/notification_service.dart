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

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:metra/domain/services/notification_service.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Concrete [NotificationService] backed by [flutter_local_notifications].
///
/// Notification channel: "metra_cycle" (high importance).
///
/// Android exact-alarm note: the manifest declares SCHEDULE_EXACT_ALARM,
/// which is correct for minSdk 24 (flutter.minSdkVersion default).
/// On Android 13+ (API 33+) a user-visible permission prompt is shown once;
/// on earlier versions the permission is pre-granted.
/// If minSdk is ever raised to 33+, consider switching to USE_EXACT_ALARM
/// (pre-granted, no prompt on Android 13+) and updating the manifest.
class FlutterNotificationService implements NotificationService {
  /// Stable ID for the single prediction-reminder notification.
  ///
  /// Must never change: changing it would orphan any already-scheduled
  /// notification on devices that have not yet been updated.
  static const int kPredictionNotificationId = 1001;

  static const String _kChannelId = 'metra_cycle';
  static const String _kChannelName = 'Mētra — Ciclo';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  @override
  Future<void> initialize() async {
    tz.initializeTimeZones();
    try {
      final timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } on Exception {
      // Fall back to UTC if timezone detection fails (unsupported platform,
      // unknown IANA name, or method channel not registered in tests).
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

  @override
  Future<void> schedulePredictionNotification(
    DateTime notifyAt,
    String title,
    String body,
  ) async {
    // Fire at 09:00 local time on the notification date.
    final scheduledDate = tz.TZDateTime(
      tz.local,
      notifyAt.year,
      notifyAt.month,
      notifyAt.day,
      9, // 09:00
    );

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

    await _plugin.zonedSchedule(
      kPredictionNotificationId,
      title,
      body,
      scheduledDate,
      details,
      // exactAllowWhileIdle keeps the alarm firing even in Doze mode.
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      // Absolute time — do not reinterpret as wall-clock time.
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: null,
    );
  }

  @override
  Future<void> cancelPredictionNotifications() async {
    await _plugin.cancel(kPredictionNotificationId);
  }
}
