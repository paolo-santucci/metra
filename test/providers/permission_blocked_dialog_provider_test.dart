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

// Tests for NavigatorKeyDialog — the production PermissionBlockedDialog
// implementation that dispatches an AlertDialog via the global navigatorKey.
//
// Covers:
//   - dialog_closes_when_openNotificationSettings_throws (T-02 / BUG-02):
//     the finally block must close the dialog even when openNotificationSettings
//     throws (e.g. MissingPluginException from a missing iOS channel).
//   - dialog_closes_when_openNotificationSettings_completes_normally:
//     regression guard — the finally must not skip Navigator.pop on the happy path.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/domain/services/notification_service.dart';
import 'package:metra/l10n/app_localizations.dart';
import 'package:metra/providers/permission_blocked_dialog_provider.dart';

// ---------------------------------------------------------------------------
// Test-local fake notification service that throws on openNotificationSettings.
// Defined here rather than in the shared fake because the throwing behaviour
// is specific to this test (the shared FakeNotificationService only counters).
// Must NOT modify test/helpers/fake_notification_service.dart (outside Owns).
// ---------------------------------------------------------------------------
class _ThrowingNotificationService implements NotificationService {
  final Object _error;

  const _ThrowingNotificationService(this._error);

  @override
  Future<void> openNotificationSettings() async => throw _error;

  // ── Stub implementations (unused in these tests) ─────────────────────────

  @override
  Future<void> initialize() async {}

  @override
  Future<NotificationScheduleResult> schedulePredictionNotification(
    DateTime notifyAt,
    String title,
    String body,
  ) async =>
      const NotificationScheduleSuccess();

  @override
  Future<void> cancelPredictionNotifications() async {}

  @override
  Future<PermissionRequestOutcome> requestPermission() async =>
      const PermissionDenied();

  @override
  Future<bool> hasNotificationPermission() async => true;

  @override
  Future<bool> isIgnoringBatteryOptimizations() async => true;

  @override
  Future<void> openBatteryOptimizationSettings() async {}
}

class _NormalNotificationService implements NotificationService {
  @override
  Future<void> openNotificationSettings() async {
    // Completes normally — no throw.
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<NotificationScheduleResult> schedulePredictionNotification(
    DateTime notifyAt,
    String title,
    String body,
  ) async =>
      const NotificationScheduleSuccess();

  @override
  Future<void> cancelPredictionNotifications() async {}

  @override
  Future<PermissionRequestOutcome> requestPermission() async =>
      const PermissionDenied();

  @override
  Future<bool> hasNotificationPermission() async => true;

  @override
  Future<bool> isIgnoringBatteryOptimizations() async => true;

  @override
  Future<void> openBatteryOptimizationSettings() async {}
}

void main() {
  // -------------------------------------------------------------------------
  // T-02 (BUG-02): NavigatorKeyDialog — "Open system settings" button closes
  // the dialog via a finally block, even when openNotificationSettings throws.
  // -------------------------------------------------------------------------

  group('NavigatorKeyDialog — "Open system settings" button', () {
    testWidgets(
      'dialog_closes_when_openNotificationSettings_throws',
      (tester) async {
        // Arrange: build a MaterialApp with the global navigator key and
        // localization delegates so AppLocalizations.of(ctx) succeeds.
        final globalKey = GlobalKey<NavigatorState>();
        final throwingService = _ThrowingNotificationService(
          MissingPluginException(
            'No implementation found for method open on channel metra/notification_settings',
          ),
        );
        final dialog = NavigatorKeyDialog(globalKey, throwingService);

        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: globalKey,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: SizedBox.shrink()),
          ),
        );
        await tester.pumpAndSettle();

        // Act: trigger the dialog (fire-and-forget — show() awaits dismissal).
        unawaited(dialog.show()); // intentionally not awaited
        await tester.pumpAndSettle();

        // Confirm the dialog is visible before tapping.
        expect(find.byType(AlertDialog), findsOneWidget);

        // Tap "Open system settings" — openNotificationSettings throws;
        // the finally block must still call Navigator.pop(dialogCtx).
        await tester
            .tap(find.widgetWithText(TextButton, 'Open system settings'));
        await tester.pumpAndSettle();

        // Assert: dialog is dismissed regardless of the exception.
        expect(find.byType(AlertDialog), findsNothing);
      },
    );

    testWidgets(
      'dialog_closes_when_openNotificationSettings_completes_normally',
      (tester) async {
        // Arrange: same setup but normal (non-throwing) service.
        final globalKey = GlobalKey<NavigatorState>();
        final normalService = _NormalNotificationService();
        final dialog = NavigatorKeyDialog(globalKey, normalService);

        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: globalKey,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: SizedBox.shrink()),
          ),
        );
        await tester.pumpAndSettle();

        unawaited(dialog.show()); // fire-and-forget
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsOneWidget);

        await tester
            .tap(find.widgetWithText(TextButton, 'Open system settings'));
        await tester.pumpAndSettle();

        // Assert: dialog is dismissed on the happy path.
        expect(find.byType(AlertDialog), findsNothing);
      },
    );
  });
}
