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

// Tests for TASK-04:
//   Group E — NotificationErrorReporter + Fake (FR-07, EC-12)
//   NFR-03 layer audit: provider must not import data/ layer.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/app.dart' show scaffoldMessengerKey;
import 'package:metra/providers/notification_error_reporter_provider.dart';

import '../helpers/fake_notification_error_reporter.dart';

void main() {
  // ──────────────────────────────────────────────────────────────────────────
  // Group E — NotificationErrorReporter + Fake
  // ──────────────────────────────────────────────────────────────────────────
  group('Group E — NotificationErrorReporter + Fake (FR-07, EC-12)', () {
    test(
      '_ScaffoldMessengerReporter.report with null currentState is a no-op (EC-12)',
      () {
        // An unattached key has currentState == null.
        // We exercise this through the production provider using an unattached
        // key — _ScaffoldMessengerReporter is private, so we test its behaviour
        // through the provider read against an unattached scaffoldMessengerKey.
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final reporter = container.read(notificationErrorReporterProvider);

        // scaffoldMessengerKey has never been attached to a MaterialApp, so
        // currentState is null. report() must be a no-op — no exception thrown.
        expect(
          () => reporter.report('anything'),
          returnsNormally,
          reason: 'EC-12: report() with null currentState must be a no-op',
        );
      },
    );

    test('FakeNotificationErrorReporter records calls', () {
      final fake = FakeNotificationErrorReporter();
      fake.report('msg1');
      fake.report('msg2');
      expect(fake.messages, equals(['msg1', 'msg2']));
    });

    test('FakeNotificationErrorReporter fresh state is empty', () {
      final fake = FakeNotificationErrorReporter();
      expect(fake.messages, isEmpty);
    });

    test('notificationErrorReporterProvider production type', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final reporter = container.read(notificationErrorReporterProvider);

      expect(reporter, isNotNull);
      expect(
        reporter,
        isNot(isA<FakeNotificationErrorReporter>()),
        reason: 'Production container must return the real reporter, not the fake',
      );
    });

    testWidgets(
      'scaffoldMessengerKey wired to MaterialApp — currentState non-null after first frame',
      (tester) async {
        // Build MetraApp with enough overrides to prevent DB / platform-channel
        // calls from blocking. We only need the MaterialApp to mount so the
        // scaffoldMessengerKey attaches its ScaffoldMessengerState.
        //
        // Import the key from the production app module.
        // ignore: avoid_relative_lib_imports — test referencing lib is intentional
        // (the key is the exact same object the provider uses).

        // Pump a minimal MaterialApp that reuses the same scaffoldMessengerKey
        // exported from lib/app.dart. This is the simplest widget harness that
        // proves the key assignment is valid without mounting the full MetraApp
        // (which needs DB + routing).
        await tester.pumpWidget(
          MaterialApp(
            scaffoldMessengerKey: scaffoldMessengerKey,
            home: const Scaffold(body: SizedBox.shrink()),
          ),
        );
        await tester.pump();

        expect(
          scaffoldMessengerKey.currentState,
          isNotNull,
          reason: 'scaffoldMessengerKey.currentState must be non-null once '
              'MaterialApp is built with this key',
        );
      },
    );
  });

  // ──────────────────────────────────────────────────────────────────────────
  // NFR-03 layer audit
  // ──────────────────────────────────────────────────────────────────────────
  group('NFR-03 layer audit — notification_error_reporter_provider.dart', () {
    test('provider file imports nothing from data/ layer', () {
      const providerPath =
          'lib/providers/notification_error_reporter_provider.dart';
      final file = File(providerPath);
      expect(
        file.existsSync(),
        isTrue,
        reason: '$providerPath must exist',
      );

      final content = file.readAsStringSync();
      final lines = content.split('\n');
      final importLines = lines.where((l) => l.trimLeft().startsWith('import'));

      for (final line in importLines) {
        expect(
          line,
          isNot(contains('package:metra/data/')),
          reason: 'NFR-03: provider must not import from package:metra/data/; '
              'found: $line',
        );
        expect(
          line,
          isNot(matches(RegExp(r'''import\s+['"].*[/\\]data[/\\]'''))),
          reason: 'NFR-03: provider must not import via relative data/ path; '
              'found: $line',
        );
      }
    });
  });
}
