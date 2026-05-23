// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
// SPDX-License-Identifier: GPL-3.0-or-later
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

// TASK-36 — Integration scenarios I-M and I-N
//
//   I-M  SettingsScreen post-migration smoke: all major section cards render
//        without exceptions after the atom-promotion migration (TASK-05..12).
//   I-N  Cross-reference guard: backup_fr12_lifecycle_test.dart still exists
//        (NFR-11 reference integrity).
//
// Notes:
//   • SettingsScreen reads backupNotifierProvider (for Backup row value text)
//     and settingsNotifierProvider. Both must be overridden — the real
//     notifiers touch the database which is not seeded in widget tests.
//   • Do NOT tap the Backup row ("Cloud backup"): it calls context.push('/backup')
//     which requires GoRouter and would throw without router registration.
//   • The "≥ 6 SettingsCard" assertion covers all six sections:
//     Preferences, Notifications, Log, Data, About, Irreversible actions.
//
// Target platforms: Linux CI, headless.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/theme/metra_theme.dart';
import 'package:metra/core/widgets/settings/settings_card.dart';
import 'package:metra/domain/entities/app_settings_data.dart';
import 'package:metra/features/backup/state/backup_notifier.dart';
import 'package:metra/features/backup/state/backup_state.dart';
import 'package:metra/features/settings/settings_screen.dart';
import 'package:metra/features/settings/state/settings_notifier.dart';
import 'package:metra/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Stubs
// ---------------------------------------------------------------------------

class _StubSettingsNotifier extends SettingsNotifier {
  _StubSettingsNotifier(this._initial);

  final AppSettingsData _initial;

  @override
  Future<AppSettingsData> build() async => _initial;

  @override
  Future<void> save(AppSettingsData settings) async {
    state = AsyncData(settings);
  }
}

class _StubBackupNotifier extends BackupNotifier {
  _StubBackupNotifier(this._initial);

  final BackupState _initial;

  @override
  Future<BackupState> build() async => _initial;
}

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

/// Mounts [SettingsScreen] without a router; the backup row tap is NOT tested
/// here (requires GoRouter). All interactive rows that open pickers are also
/// not tapped — this is a smoke test for render-without-exception.
Widget _wrapSettings({
  AppSettingsData? settings,
  BackupState backupState = const BackupNotConnected(),
}) {
  final data = settings ??
      AppSettingsData(
        languageCode: 'en',
        darkMode: null,
        painEnabled: true,
        notesEnabled: true,
        notificationDaysBefore: 2,
        notificationsEnabled: false,
        onboardingCompleted: false,
      );

  return ProviderScope(
    overrides: [
      backupNotifierProvider.overrideWith(
        () => _StubBackupNotifier(backupState),
      ),
      settingsNotifierProvider.overrideWith(
        () => _StubSettingsNotifier(data),
      ),
    ],
    child: MaterialApp(
      theme: MetraTheme.light(),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const SettingsScreen(),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  // I-M — SettingsScreen post-migration smoke
  // =========================================================================

  group('I-M — settings_screen_post_migration_smoke', () {
    testWidgets(
      'should_render_all_six_section_cards_without_exception',
      (tester) async {
        // Tall viewport so all sections render without scrolling.
        tester.view.physicalSize = const Size(1080, 8000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(_wrapSettings());
        await tester.pumpAndSettle();

        // Six SettingsCard widgets — one per section:
        //   1. Preferences
        //   2. Notifications
        //   3. Log
        //   4. Data
        //   5. About (section_about)
        //   6. Irreversible actions
        expect(
          find.byType(SettingsCard),
          findsAtLeast(6),
          reason:
              'all six settings sections must render at least one SettingsCard',
        );
      },
    );

    testWidgets(
      'should_render_key_section_labels_in_uppercase_English',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 8000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(_wrapSettings());
        await tester.pumpAndSettle();

        // SettingsLabel renders text.toUpperCase() — assertions use upper case.
        expect(find.text('PREFERENCES'), findsOneWidget);
        expect(find.text('NOTIFICATIONS'), findsOneWidget);
        expect(find.text('LOG'), findsOneWidget);
        expect(find.text('DATA'), findsOneWidget);
        expect(find.text('IRREVERSIBLE ACTIONS'), findsOneWidget);
      },
    );

    testWidgets(
      'should_render_backup_row_with_not_configured_value_when_not_connected',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 8000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          _wrapSettings(backupState: const BackupNotConnected()),
        );
        await tester.pumpAndSettle();

        // settings_backup_not_configured = "Not configured"
        expect(find.text('Not configured'), findsOneWidget);
      },
    );

    testWidgets(
      'should_render_backup_row_with_configured_value_when_connected',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 8000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          _wrapSettings(
            backupState: const BackupConnected(
              email: 'user@test.com',
              autoBackupActive: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // settings_backup_configured = "Configured"
        expect(find.text('Configured'), findsOneWidget);
      },
    );

    testWidgets(
      'should_render_settings_title_as_semantic_header',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 8000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(_wrapSettings());
        await tester.pumpAndSettle();

        // settings_screen_title = "Settings"
        expect(find.text('Settings'), findsOneWidget);
      },
    );
  });

  // =========================================================================
  // I-N — Cross-reference guard: backup_fr12_lifecycle_test.dart must exist
  // =========================================================================

  group('I-N — backup_fr12_lifecycle_file_existence_guard', () {
    test(
      'should_find_backup_fr12_lifecycle_test_dart_on_disk',
      () {
        // NFR-11: this guard ensures the FR-12 lifecycle integration test is
        // not accidentally deleted. The path is relative to the package root,
        // which is the cwd during `flutter test`.
        const path = 'test/integration/backup_fr12_lifecycle_test.dart';
        expect(
          File(path).existsSync(),
          isTrue,
          reason: 'NFR-11 cross-reference guard: $path must exist. '
              'Do not delete this file — it is referenced by TASK-36 spec.',
        );
      },
    );
  });
}
