// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
//
// Métra is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Métra is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Métra. If not, see <https://www.gnu.org/licenses/>.

import '../entities/app_settings_data.dart';
import '../entities/cycle_prediction.dart';
import '../services/notification_service.dart';

class SchedulePredictionNotification {
  const SchedulePredictionNotification(this._notifService);

  final NotificationService _notifService;

  Future<void> execute({
    required CyclePrediction? prediction,
    required AppSettingsData settings,
    required String title,
    required String body,
    bool skipIfPast = false,
    DateTime Function()? clock,
  }) async {
    await _notifService.cancelPredictionNotifications();
    if (prediction == null || !settings.notificationsEnabled) return;

    final base = prediction.windowStart
        .subtract(Duration(days: settings.notificationDaysBefore));
    final notifyAt = DateTime(
      base.year,
      base.month,
      base.day,
      settings.notificationTimeMinutes ~/ 60,
      settings.notificationTimeMinutes % 60,
    );

    final now = clock != null ? clock() : DateTime.now();
    // Settings-change guard: when the user adjusts advance days or notification
    // time in Settings, the computed notifyAt may already be in the past
    // (including same-day-past). Without this guard the service's
    // shouldShowImmediately path fires and the notification pops up immediately.
    // The prediction-data-change listener passes skipIfPast: false (default),
    // preserving the BUG-005 cold-start immediate-show behavior.
    if (skipIfPast && notifyAt.isBefore(now)) return;
    final today = DateTime(now.year, now.month, now.day);
    if (notifyAt.toLocal().isBefore(today)) return;

    // ignore: unused_local_variable
    final result = await _notifService.schedulePredictionNotification(
        notifyAt, title, body);
    // M1: result is intentionally unused — M4 wires the revert-and-notify path here.
  }
}
