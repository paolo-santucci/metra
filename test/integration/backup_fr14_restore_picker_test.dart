// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
// SPDX-License-Identifier: GPL-3.0-or-later

// Widget integration test for FR-14: restore-picker rendering, newest
// pre-selected, second-row selection, and captured-filename forwarding.
//
// Spec ref: FR-14, FR-19l, NFR-08, §7.2 E2E flow 2.
// Renders BackupScreen with all fake overrides (real BackupNotifier, fake
// runner at the RestoreData level).  Locale set to IT (NFR-07 primary locale).
// Runs on Linux CI (NFR-08).
//
// Steps:
//   (a) Seed FakeDropboxProvider with 3 BackupFileEntry objects.
//   (b) Render BackupScreen (BackupConnected state via FakeAppSettingsRepository).
//   (c) Tap "Restore from backup"; confirm destructive dialog.
//   (d) Assert RestorePickerDialog appears with 3 rows, newest pre-selected.
//   (e) Tap the second row.
//   (f) Tap "Restore this version".
//   (g) Assert passphrase dialog appears.
//   (h) Enter 'test-pass' and confirm.
//   (i) Assert FakeBackupRunner.restore was called with filename == entries[1].name
//       and the passphrase was forwarded via InMemorySecureStorage.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/theme/metra_theme.dart';
import 'package:metra/data/services/backup/backup_file_entry.dart';
import 'package:metra/domain/entities/app_settings_data.dart';
import 'package:metra/domain/use_cases/backup_data.dart';
import 'package:metra/domain/use_cases/restore_data.dart';
import 'package:metra/features/backup/backup_screen.dart';
import 'package:metra/features/backup/state/backup_notifier.dart';
import 'package:metra/l10n/app_localizations.dart';
import 'package:metra/providers/backup_providers.dart';
import 'package:metra/providers/encryption_provider.dart';
import 'package:metra/providers/repository_providers.dart';

import '../helpers/fake_app_settings_repository.dart';
import '../helpers/fake_backup_runner.dart';
import '../helpers/fake_dropbox_provider.dart';
import '../helpers/fake_sync_log_repository.dart';
import '../helpers/in_memory_secure_storage.dart';

void main() {
  group('FR-14 — restore picker E2E widget integration', () {
    late FakeAppSettingsRepository settingsRepo;
    late FakeDropboxProvider fakeDropbox;
    late FakeBackupRunner backupRunner;
    late InMemorySecureStorage storage;

    // Three entries: newest first (the list is already newest-first per spec).
    late List<BackupFileEntry> entries;

    setUp(() {
      settingsRepo = FakeAppSettingsRepository();
      // Seed settings: Dropbox connected so BackupNotifier.build() returns
      // BackupConnected, and lastBackupAt / backupSuspended are defaults.
      settingsRepo.storedSettings = AppSettingsData(
        languageCode: 'it',
        darkMode: false,
        painEnabled: true,
        notesEnabled: true,
        notificationDaysBefore: 2,
        notificationsEnabled: false,
        dropboxEmail: 'user@example.com',
        lastBackupAt: null,
        onboardingCompleted: true,
      );

      entries = [
        BackupFileEntry(
          name: 'newest-fr14.enc',
          timestampUtc: DateTime.utc(2026, 5, 17, 12, 0, 0),
          sizeBytes: 2048,
        ),
        BackupFileEntry(
          name: 'middle-fr14.enc',
          timestampUtc: DateTime.utc(2026, 5, 16, 10, 0, 0),
          sizeBytes: 1024,
        ),
        BackupFileEntry(
          name: 'oldest-fr14.enc',
          timestampUtc: DateTime.utc(2026, 5, 15, 8, 0, 0),
          sizeBytes: 512,
        ),
      ];

      fakeDropbox = FakeDropboxProvider(seedEntries: entries);
      backupRunner = FakeBackupRunner();
      storage = InMemorySecureStorage();
    });

    Widget buildScreen() {
      return ProviderScope(
        overrides: [
          appSettingsRepositoryProvider.overrideWith(
            (_) async => settingsRepo,
          ),
          syncLogRepositoryProvider.overrideWith(
            (_) async => FakeSyncLogRepository(),
          ),
          cloudBackupProvider.overrideWithValue(fakeDropbox),
          restoreDataProvider.overrideWith(
            (_) async => RestoreData(backupRunner),
          ),
          backupDataProvider.overrideWith(
            (_) async => BackupData(backupRunner),
          ),
          secureStorageProvider.overrideWithValue(storage),
        ],
        child: MaterialApp(
          theme: MetraTheme.light(),
          locale: const Locale('it'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const BackupScreen(),
        ),
      );
    }

    testWidgets(
        'FR-19l — picker appears with 3 rows, second-row selection forwarded to runner',
        (tester) async {
      // Use a phone-like viewport: tall enough to show all elements, small
      // enough that dialog layout is realistic (not an extreme 4000px height).
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // (b) Render BackupScreen.
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      // Verify BackupConnected body is shown.
      expect(find.text('user@example.com'), findsNothing); // not raw email
      expect(find.textContaining('user@example.com'), findsOneWidget);
      expect(find.text('Ripristina dal backup'), findsOneWidget);

      // (c) Tap "Ripristina dal backup".
      await tester.tap(find.text('Ripristina dal backup'));
      await tester.pumpAndSettle();

      // Destructive confirm dialog must appear.
      expect(find.text('Ripristinare il backup?'), findsOneWidget);

      // Tap destructive CTA.
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(TextButton, 'Ripristina'),
        ),
      );
      await tester.pumpAndSettle();

      // (d) RestorePickerDialog appears with 3 rows.
      // IT: restorePickerTitle = "Scegli versione" (not "Scegli la versione")
      expect(find.text('Scegli versione'), findsOneWidget);
      expect(find.byType(RadioListTile<String>), findsNWidgets(3));

      // Newest row must be first in the list (entries are already sorted
      // newest-first by the caller; the picker renders them in order).
      // Verify the first RadioListTile corresponds to the newest entry by
      // checking the value attribute of the first Radio<String> widget.
      // IT locale: DateFormat.yMMMd('it').add_Hm() → '17 mag 2026 14:00'
      final newestRadioFinder = find
          .descendant(
            of: find
                .ancestor(
                  of: find.textContaining('17 mag'),
                  matching: find.byType(RadioListTile<String>),
                )
                .first,
            matching: find.byType(Radio<String>),
          )
          .first;
      final newestRadioWidget = tester.widget<Radio<String>>(newestRadioFinder);
      expect(
        newestRadioWidget.value,
        equals(entries.first.name),
        reason: 'first RadioListTile must correspond to the newest entry',
      );
      // Pre-selection is verified behaviorally: the dialog's initState sets
      // _selected = entries.first.name; any "Ripristina questa versione" tap
      // without a prior row change uses that default.  The dedicated test
      // "pre-selection routes to newest entry" below verifies this path.

      // (e) Tap the second row (middle entry — 16 mag).
      // Tap the text label directly — avoids coordinate issues with the
      // RadioListTile ancestor which can land on the dialog actions bar
      // when the dialog is centered in a large test viewport.
      await tester.tap(find.textContaining('16 mag'));
      await tester.pumpAndSettle();

      // (f) Tap "Ripristina" (IT: restorePickerRestoreThisVersion = "Ripristina").
      //     The confirm dialog's "Ripristina" is already dismissed; only the
      //     picker's "Ripristina" is on screen at this point.
      await tester.tap(find.text('Ripristina'));
      await tester.pumpAndSettle();

      // (g) Passphrase dialog appears.
      expect(find.text('Inserisci la passphrase'), findsOneWidget);
      expect(find.byType(TextField), findsAtLeastNWidgets(1));

      // (h) Enter 'test-pass' and confirm.
      await tester.enterText(
        find.byType(TextField).first,
        'test-pass',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sblocca e ripristina'));
      await tester.pumpAndSettle();

      // (i) Assert: runner called with filename == entries[1].name.
      expect(
        backupRunner.restoreCallCount,
        equals(1),
        reason: 'restore must be called exactly once',
      );
      expect(
        backupRunner.lastFilename,
        equals(entries[1].name),
        reason:
            'runner must receive the second entry name (middle-fr14.enc), not the newest',
      );

      // Assert: passphrase was written to secure storage before the runner call.
      expect(
        storage.values[BackupNotifier.kPassphraseKey],
        equals('test-pass'),
        reason:
            'passphrase must be persisted in secure storage before the restore call',
      );
    });

    testWidgets(
        'FR-14 — pre-selection routes "Restore this version" to newest entry',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      // Tap "Ripristina dal backup" → confirm destructive dialog.
      await tester.tap(find.text('Ripristina dal backup'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(TextButton, 'Ripristina'),
        ),
      );
      await tester.pumpAndSettle();

      // Picker shown — do NOT tap any row; tap "Ripristina" immediately.
      // IT: restorePickerTitle = "Scegli versione", restorePickerRestoreThisVersion = "Ripristina"
      expect(find.text('Scegli versione'), findsOneWidget);
      await tester.tap(find.text('Ripristina'));
      await tester.pumpAndSettle();

      // Passphrase dialog.
      await tester.enterText(find.byType(TextField).first, 'test-pass');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sblocca e ripristina'));
      await tester.pumpAndSettle();

      expect(backupRunner.restoreCallCount, equals(1));
      // Default (no row tapped) → pre-selected = newest entry.
      expect(
        backupRunner.lastFilename,
        equals(entries.first.name),
        reason: 'default pre-selection must forward the newest entry name when '
            '"Restore this version" is tapped without changing the row',
      );
    });

    testWidgets(
        'FR-14 — "Use newest" shortcut forwards null filename to runner',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      // Tap "Ripristina dal backup" → confirm destructive dialog.
      await tester.tap(find.text('Ripristina dal backup'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(TextButton, 'Ripristina'),
        ),
      );
      await tester.pumpAndSettle();

      // Picker shown — tap "Usa più recente" (IT: restorePickerUseNewest = "Usa più recente").
      expect(find.text('Scegli versione'), findsOneWidget);
      await tester.tap(find.text('Usa più recente'));
      await tester.pumpAndSettle();

      // Passphrase dialog.
      await tester.enterText(find.byType(TextField).first, 'test-pass');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sblocca e ripristina'));
      await tester.pumpAndSettle();

      expect(backupRunner.restoreCallCount, equals(1));
      // "Use newest" → filename null (legacy path).
      expect(
        backupRunner.lastFilename,
        isNull,
        reason:
            '"Use newest" shortcut must forward filename: null to the runner',
      );
    });
  });
}
