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
  }) async {
    await _notifService.cancelPredictionNotifications();
    if (prediction == null || !settings.notificationsEnabled) return;
    final notifyAt = prediction.windowStart
        .subtract(Duration(days: settings.notificationDaysBefore));
    if (notifyAt.isBefore(DateTime.now())) return;
    await _notifService.schedulePredictionNotification(notifyAt, title, body);
  }
}
