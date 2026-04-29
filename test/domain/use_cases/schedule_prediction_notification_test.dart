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

import 'package:flutter_test/flutter_test.dart';
import 'package:metra/domain/entities/app_settings_data.dart';
import 'package:metra/domain/entities/cycle_prediction.dart';
import 'package:metra/domain/use_cases/schedule_prediction_notification.dart';

import '../../helpers/fake_notification_service.dart';

void main() {
  late FakeNotificationService fakeService;
  late SchedulePredictionNotification useCase;

  CyclePrediction makePrediction(DateTime expectedStart) {
    return CyclePrediction(
      windowStart: expectedStart.subtract(const Duration(days: 2)),
      windowEnd: expectedStart.add(const Duration(days: 2)),
      expectedStart: expectedStart,
      cyclesUsed: 3,
    );
  }

  setUp(() {
    fakeService = FakeNotificationService();
    useCase = SchedulePredictionNotification(fakeService);
  });

  group('SchedulePredictionNotification.execute', () {
    // Test 1: null prediction → cancel called, no schedule
    test('null prediction → cancel called, no schedule', () async {
      const settings = AppSettingsData(
        languageCode: 'it',
        painEnabled: true,
        notesEnabled: true,
        notificationDaysBefore: 2,
        notificationsEnabled: true,
      );

      await useCase.execute(
        prediction: null,
        settings: settings,
        title: 'Test title',
        body: 'Test body',
      );

      expect(fakeService.cancelCount, equals(1));
      expect(fakeService.scheduled, isEmpty);
    });

    // Test 2: notifications disabled → cancel called, no schedule
    test('notifications disabled → cancel called, no schedule', () async {
      final prediction = makePrediction(
        DateTime.now().add(const Duration(days: 10)),
      );
      const settings = AppSettingsData(
        languageCode: 'it',
        painEnabled: true,
        notesEnabled: true,
        notificationDaysBefore: 2,
        notificationsEnabled: false,
      );

      await useCase.execute(
        prediction: prediction,
        settings: settings,
        title: 'Test title',
        body: 'Test body',
      );

      expect(fakeService.cancelCount, equals(1));
      expect(fakeService.scheduled, isEmpty);
    });

    // Test 3: notify date in the past → cancel called, no schedule
    test('notify date in the past → cancel called, no schedule', () async {
      // windowStart = yesterday → notifyAt = yesterday (0 days before) → past
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final prediction = makePrediction(
        yesterday.add(const Duration(days: 2)),
      ); // expectedStart = yesterday+2d, windowStart = yesterday
      const settings = AppSettingsData(
        languageCode: 'it',
        painEnabled: true,
        notesEnabled: true,
        notificationDaysBefore: 0,
        notificationsEnabled: true,
      );

      await useCase.execute(
        prediction: prediction,
        settings: settings,
        title: 'Test title',
        body: 'Test body',
      );

      expect(fakeService.cancelCount, equals(1));
      expect(fakeService.scheduled, isEmpty);
    });

    // Test 4: valid future prediction → cancel then schedule
    test('valid future prediction → cancel then schedule', () async {
      final futureStart = DateTime.now().add(const Duration(days: 10));
      final prediction = makePrediction(
        futureStart.add(const Duration(days: 2)),
      ); // windowStart = futureStart
      const settings = AppSettingsData(
        languageCode: 'it',
        painEnabled: true,
        notesEnabled: true,
        notificationDaysBefore: 2,
        notificationsEnabled: true,
      );

      await useCase.execute(
        prediction: prediction,
        settings: settings,
        title: 'Test title',
        body: 'Test body',
      );

      expect(fakeService.cancelCount, equals(1));
      expect(fakeService.scheduled, hasLength(1));

      final entry = fakeService.scheduled.first;
      expect(
        entry.notifyAt,
        equals(
          prediction.windowStart.subtract(const Duration(days: 2)),
        ),
      );
      expect(entry.title, equals('Test title'));
      expect(entry.body, equals('Test body'));
    });

    test(
        'notificationDaysBefore=0 is clamped to 1 — notification still scheduled',
        () async {
      final notifService = FakeNotificationService();
      final uc = SchedulePredictionNotification(notifService);
      final prediction = CyclePrediction(
        expectedStart: DateTime.utc(2026, 6, 1),
        windowStart: DateTime.utc(2026, 5, 30),
        windowEnd: DateTime.utc(2026, 6, 3),
        cyclesUsed: 3,
      );
      const settings = AppSettingsData(
        languageCode: 'it',
        painEnabled: true,
        notesEnabled: true,
        notificationsEnabled: true,
        notificationDaysBefore: 0, // invalid: below 1
      );

      await uc.execute(
        prediction: prediction,
        settings: settings,
        title: 't',
        body: 'b',
      );

      // Clamped to 1: notifyAt = windowStart - 1 day = 2026-05-29
      expect(
        notifService.scheduled.first.notifyAt,
        equals(DateTime.utc(2026, 5, 29)),
      );
    });
  });
}
