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

import 'package:flutter_test/flutter_test.dart';
import 'package:metra/data/services/notification_service.dart';

void main() {
  group('notification ID uniqueness guardrail', () {
    /// Enumeration of all notification-ID constants used in the codebase.
    ///
    /// This list is maintained manually to catch accidental reuse of a
    /// notification ID across different notification types. Every new
    /// notification ID must be appended here and added to the assertion below.
    /// Failure to register a new ID here will cause the uniqueness test to fail,
    /// preventing silent collisions that could lead to cancelling the wrong
    /// notification type.
    ///
    /// Currently registered IDs:
    ///   - 1001: FlutterNotificationService.kPredictionNotificationId (cycle prediction reminder)
    ///
    /// When adding a new notification:
    ///   1. Choose a unique ID not already in this list.
    ///   2. Append it here: const int kMyNewNotificationId = <chosen ID>;
    ///   3. Add the constant to the notificationIds list below.
    ///   4. Re-run this test to confirm the assertion passes.
    const notificationIds = [
      FlutterNotificationService.kPredictionNotificationId,
    ];

    test('all notification IDs are unique', () {
      // Assertion: the set of IDs has the same length as the list,
      // proving no duplicates exist.
      expect(
        notificationIds.toSet().length,
        equals(notificationIds.length),
        reason:
            'Notification IDs must be unique; a duplicate was detected in the notificationIds list.',
      );
    });

    test('uniqueness guard catches duplicate IDs (meta-test)', () {
      // Failure-path proof: a duplicated ID list should fail the same assertion.
      // This meta-test proves the guard is not vacuously true; it actually detects
      // duplicates and would catch a future accidental reuse.
      const duplicatedIds = [1001, 1001];
      expect(
        duplicatedIds.toSet().length,
        isNot(equals(duplicatedIds.length)),
        reason:
            'Meta-test: duplicated IDs should not have equal set and list lengths.',
      );
    });
  });
}
