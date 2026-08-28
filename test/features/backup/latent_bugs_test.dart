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

// TASK-34 — Group M: latent-bug regression tests (I-1 … I-5)
// sp-20260524 — Group N: BUG-01 + BUG-R1 regression tests (N-1 … N-4)
// sp-20260524 — Group O: BUG-RT01 BackupNotifier count propagation (O-1 … O-3)
//
// I-1  Restore flow step order: BackupPickerSheet → MetraConfirmDialog → PassphraseDialog.
// I-2  Dispatcher no-crash on all 5 BackupState subtypes.
// I-3a Zero Color(0x…) hex literals in lib/features/backup/ and lib/core/widgets/settings/.
// I-3b Zero fontFamily: string literals in the same dirs.
// I-3c Zero MetraColors.light / MetraColors.dark direct access in the same dirs.
// I-3d lib/core/widgets/settings/ covered by I-3a / I-3b (same dirs in single grep).
// I-4  Cross-reference: keepAlive covered in backup_picker_sheet_integration_test.dart I-F.
// I-5  Cross-reference: Colors.red covered in passphrase_dialog_token_test.dart.
//
// N-1  BUG-01: BackupConnected.passphraseSet false when no passphrase in storage.
// N-2  BUG-01: BackupConnected.passphraseSet true + autoBackupActive true when passphrase present.
// N-3  BUG-01: autoBackupActive false when backupSuspended=true even if passphrase present.
// N-4  BUG-R1: restore() Ok-branch invalidates currentCycleDayProvider + cycleDayForDateProvider.
//
// O-1  BUG-RT01: restore() returns the int count from the Ok branch.
// O-2  BUG-RT01: restore() returns null on the Err branch + sets BackupErrorState.
// O-3  BUG-RT01: restoreWithPassphrase() propagates the count from restore().
//
// Platform matrix: all (Linux CI — no device required).

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/errors/metra_exception.dart';
import 'package:metra/core/theme/metra_theme.dart';
import 'package:metra/core/util/nullable.dart';
import 'package:metra/data/services/backup/backup_file_entry.dart';
import 'package:metra/domain/entities/app_settings_data.dart';
import 'package:metra/domain/use_cases/backup_data.dart';
import 'package:metra/domain/use_cases/restore_data.dart';
import 'package:metra/features/backup/backup_screen.dart';
import 'package:metra/features/backup/state/backup_notifier.dart';
import 'package:metra/domain/entities/sync_log_entity.dart';
import 'package:metra/features/backup/state/backup_state.dart';
import 'package:metra/features/backup/widgets/backup_picker_sheet.dart';
import 'package:metra/features/backup/widgets/metra_confirm_dialog.dart';
import 'package:metra/features/backup/widgets/passphrase_dialog.dart';
import 'package:metra/l10n/app_localizations.dart';
import 'package:metra/providers/backup_providers.dart';
import 'package:metra/providers/encryption_provider.dart';
import 'package:metra/providers/repository_providers.dart';
import 'package:metra/providers/use_case_providers.dart';

import '../../helpers/fake_app_settings_repository.dart';
import '../../helpers/fake_backup_runner.dart';
import '../../helpers/fake_dropbox_provider.dart';
import '../../helpers/fake_sync_log_repository.dart';
import '../../helpers/in_memory_secure_storage.dart';

// ---------------------------------------------------------------------------
// N: helper runner — always succeeds (BUG-R1 + BUG-01 tests)
// ---------------------------------------------------------------------------

/// A [BackupRunner] that immediately succeeds on both backup and restore.
class _OkRunner implements BackupRunner {
  @override
  Future<void> backup() async {}

  @override
  Future<int> restore({String? filename}) async => 0;
}

/// A [BackupRunner] whose [backup] does not resolve until [_completer]
/// completes — lets Group K (TASK-09) stage a state mutation while
/// `_runBackup()`'s underlying orchestrator call is still pending, then
/// release it to resolve `Ok()`.
class _CompleterGatedRunner implements BackupRunner {
  _CompleterGatedRunner(this._completer);

  final Completer<void> _completer;

  @override
  Future<void> backup() async {
    await _completer.future;
  }

  @override
  Future<int> restore({String? filename}) async => 0;
}

// ---------------------------------------------------------------------------
// Stub notifier (mirrors _StubBackupNotifier from backup_screen_test.dart)
// ---------------------------------------------------------------------------

class _StubBackupNotifier extends BackupNotifier {
  _StubBackupNotifier(this._initial);

  final BackupState _initial;

  String? capturedRestorePassphrase;
  String? capturedRestoreFilename;

  @override
  Future<BackupState> build() async => _initial;

  @override
  Future<int?> restoreWithPassphrase(
    String passphrase, {
    String? filename,
  }) async {
    capturedRestorePassphrase = passphrase;
    capturedRestoreFilename = filename;
    return null;
  }

  @override
  Future<void> backupWithPassphrase(String passphrase) async {}

  @override
  Future<void> backupSilent() async {}

  @override
  Future<void> backupNow() async {}
}

// ---------------------------------------------------------------------------
// _wrap helper
// ---------------------------------------------------------------------------

Widget _wrap(
  BackupState state, {
  _StubBackupNotifier? stub,
  FakeDropboxProvider? fakeProvider,
}) {
  return ProviderScope(
    overrides: [
      backupNotifierProvider.overrideWith(
        () => stub ?? _StubBackupNotifier(state),
      ),
      secureStorageProvider.overrideWithValue(InMemorySecureStorage()),
      cloudBackupProvider.overrideWithValue(
        fakeProvider ??
            FakeDropboxProvider(
              seedEntries: [
                BackupFileEntry(
                  name: 'default.enc',
                  timestampUtc: DateTime.utc(2026, 5, 17, 12),
                  sizeBytes: 1024,
                ),
              ],
            ),
      ),
    ],
    child: MaterialApp(
      theme: MetraTheme.light(),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const BackupScreen(),
    ),
  );
}

// ---------------------------------------------------------------------------
// Static grep helper (mirrors _grepDartFiles from token_discipline_test.dart)
// ---------------------------------------------------------------------------

List<String> _grepDartFiles(List<String> dirs, RegExp pattern) {
  final hits = <String>[];
  for (final dirPath in dirs) {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) continue;
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (pattern.hasMatch(lines[i])) {
          hits.add('${entity.path}:${i + 1}: ${lines[i]}');
        }
      }
    }
  }
  return hits;
}

const _backupAndSettings = [
  'lib/features/backup',
  'lib/core/widgets/settings',
];

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  // I-1 — Restore flow step order
  // =========================================================================

  group('I-1 — restore flow step order (picker → confirm → passphrase)', () {
    testWidgets(
      'should_show_BackupPickerSheet_then_MetraConfirmDialog_then_PassphraseDialog_'
      'when_restore_tapped_given_one_seed_entry',
      (tester) async {
        tester.view.physicalSize = const Size(2400, 6000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final seedEntry = BackupFileEntry(
          name: 'task34_test.enc',
          timestampUtc: DateTime.utc(2026, 5, 21, 8),
          sizeBytes: 512,
        );
        final stub = _StubBackupNotifier(
          const BackupConnected(
            provider: SyncProvider.dropbox,
            email: 'test@metra.app',
            autoBackupActive: true,
            passphraseSet: true,
          ),
        );

        await tester.pumpWidget(
          _wrap(
            const BackupConnected(
              provider: SyncProvider.dropbox,
              email: 'test@metra.app',
              autoBackupActive: true,
              passphraseSet: true,
            ),
            stub: stub,
            fakeProvider: FakeDropboxProvider(seedEntries: [seedEntry]),
          ),
        );
        await tester.pumpAndSettle();

        // ── Step 1: tap the Restore action row ─────────────────────────────
        await tester.tap(find.byKey(const Key('backup_restore_action_row')));
        // Allow the async fetch + sheet open to settle.
        await tester.pumpAndSettle();

        expect(
          find.byType(BackupPickerSheet),
          findsOneWidget,
          reason:
              'BackupPickerSheet must be visible after tapping the restore row',
        );
        expect(
          find.byType(MetraConfirmDialog),
          findsNothing,
          reason: 'MetraConfirmDialog must NOT appear before picker confirm',
        );

        // ── Step 2: confirm selection in the picker ─────────────────────────
        // The picker confirm button label is "Restore" (backupPickerConfirm in
        // app_en.arb). There is also "Restore" inside MetraConfirmDialog later,
        // but the dialog is not visible yet — so find.text('Restore') is unique.
        await tester.tap(find.text('Restore'));
        await tester.pumpAndSettle();

        expect(
          find.byType(MetraConfirmDialog),
          findsOneWidget,
          reason: 'MetraConfirmDialog must be visible after picker confirm',
        );
        expect(
          find.byType(PassphraseDialog),
          findsNothing,
          reason: 'PassphraseDialog must NOT appear before confirm dialog',
        );

        // ── Step 3: confirm the destructive dialog ──────────────────────────
        // MetraConfirmDialog uses backupRestoreConfirmRestore → "Restore" in EN.
        // Tap it; two "Restore" texts were visible during picker so we need the
        // dialog confirm button which has key not set — use the constrained-box
        // key to scope, or just find the last "Restore" visible.
        await tester.tap(find.text('Restore').last);
        await tester.pumpAndSettle();

        expect(
          find.byType(PassphraseDialog),
          findsOneWidget,
          reason: 'PassphraseDialog must be visible after confirm dialog',
        );

        // ── Step 4: enter passphrase and submit ─────────────────────────────
        // PassphraseDialog in unlock mode has one obscure TextField.
        await tester.enterText(
          find.byType(TextField).first,
          'test-passphrase-1',
        );
        await tester.pumpAndSettle();
        // "Unlock and restore" is the EN label for backup_passphrase_unlock_button.
        await tester.tap(find.text('Unlock and restore'));
        await tester.pumpAndSettle();

        expect(
          stub.capturedRestorePassphrase,
          equals('test-passphrase-1'),
          reason:
              'restoreWithPassphrase must be called with the entered passphrase',
        );
        expect(
          stub.capturedRestoreFilename,
          equals('task34_test.enc'),
          reason:
              'restoreWithPassphrase must receive the filename from the seed entry',
        );
      },
    );
  });

  // =========================================================================
  // I-2 — Dispatcher no-crash on all BackupState subtypes
  // =========================================================================

  group('I-2 — dispatcher no-crash on every BackupState subtype', () {
    // Helper: mount BackupScreen with the given state and assert no exception.
    Future<void> assertNoCrash(
      WidgetTester tester,
      BackupState state, {
      bool settle = false,
    }) async {
      await tester.pumpWidget(_wrap(state));
      if (settle) {
        await tester.pumpAndSettle();
      } else {
        await tester.pump();
      }
      expect(
        tester.takeException(),
        isNull,
        reason: 'BackupScreen must not throw for state: $state',
      );
    }

    testWidgets(
      'should_not_crash_when_state_is_BackupNotConnected',
      (tester) async {
        tester.view.physicalSize = const Size(800, 4000);
        addTearDown(() => tester.view.resetPhysicalSize());

        await assertNoCrash(tester, const BackupNotConnected(), settle: true);
      },
    );

    testWidgets(
      'should_not_crash_when_state_is_BackupConnected',
      (tester) async {
        tester.view.physicalSize = const Size(2400, 6000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await assertNoCrash(
          tester,
          const BackupConnected(
            provider: SyncProvider.dropbox,
            email: 'i2@metra.app',
            autoBackupActive: false,
            passphraseSet: true,
            lastBackupAt: null,
          ),
          settle: true,
        );
      },
    );

    testWidgets(
      'should_not_crash_when_state_is_BackupRunning_restoring',
      (tester) async {
        await assertNoCrash(
          tester,
          const BackupRunning(BackupOperation.restoring),
        );
      },
    );

    testWidgets(
      'should_not_crash_when_state_is_BackupRunning_backingUp',
      (tester) async {
        await assertNoCrash(
          tester,
          const BackupRunning(BackupOperation.backingUp),
        );
      },
    );

    testWidgets(
      'should_not_crash_when_state_is_BackupErrorState',
      (tester) async {
        tester.view.physicalSize = const Size(800, 4000);
        addTearDown(() => tester.view.resetPhysicalSize());

        await assertNoCrash(
          tester,
          const BackupErrorState('i2 error message'),
          settle: true,
        );
      },
    );
  });

  // =========================================================================
  // I-3 — Anti-pattern grep: no raw Color hex, no fontFamily literals,
  //        no MetraColors.light / MetraColors.dark in backup + settings dirs
  // =========================================================================

  group(
      'I-3 — token-discipline regression guard (lib/features/backup/ + lib/core/widgets/settings/)',
      () {
    // I-3a
    test(
      'I-3a zero Color(0x…) hex literals in backup and settings source',
      () {
        final hits = _grepDartFiles(
          _backupAndSettings,
          RegExp(r'Color\(0x'),
        );
        expect(
          hits,
          isEmpty,
          reason: 'Hardcoded Color(0x…) literals found. '
              'Use MetraColors.of(context).<token> or withAlpha(0xNN) on a token '
              'getter instead.\nHits:\n${hits.join('\n')}',
        );
      },
    );

    // I-3b
    test(
      'I-3b zero fontFamily: string literals in backup and settings source',
      () {
        final hits = _grepDartFiles(
          _backupAndSettings,
          RegExp(r"""fontFamily:\s*['"]"""),
        );
        expect(
          hits,
          isEmpty,
          reason: 'fontFamily: string literals found. '
              'Use MetraTypography.<style> or GoogleFonts.inter(…) instead.\n'
              'Hits:\n${hits.join('\n')}',
        );
      },
    );

    // I-3c  — MetraColors.light / MetraColors.dark direct access
    // MetraColors.of(context) is the correct pattern (uses lowercase 'of').
    // MetraColors.light and MetraColors.dark are private-palette direct access,
    // which bypasses theme switching (documented anti-pattern in metra_colors.dart).
    test(
      'I-3c zero MetraColors.light / MetraColors.dark direct access '
      'in backup and settings source',
      () {
        final hits = _grepDartFiles(
          _backupAndSettings,
          RegExp(r'MetraColors\.(light|dark)\b'),
        );
        expect(
          hits,
          isEmpty,
          reason: 'MetraColors.light or MetraColors.dark used directly. '
              'Use MetraColors.of(context) to respect theme switching.\n'
              'Hits:\n${hits.join('\n')}',
        );
      },
    );
  });

  // =========================================================================
  // I-4 — Cross-reference: keepAlive covered in TASK-35
  // =========================================================================

  test(
    'I-4 keepAlive cross-reference to TASK-35 I-F',
    () {
      // keepAlive behavior of backupFileListProvider during the restore flow is
      // covered by listenManual in backup_connected_view_handlers.dart (EC-06).
      // The integration-level proof (sheet stays alive during sheet-covered state)
      // is in test/integration/backup_picker_sheet_integration_test.dart Scenario I-F.
    },
    skip: 'cross-reference only — covered in TASK-35 I-F',
  );

  // =========================================================================
  // I-5 — Cross-reference: Colors.red covered in TASK-23 Group K
  // =========================================================================

  test(
    'I-5 Colors.red absent — covered in passphrase_dialog_token_test.dart',
    () {
      // Colors.red in passphrase_dialog.dart is covered by FR-29 in
      // test/static/token_discipline_test.dart (TASK-23 Group K).
    },
    skip:
        'cross-reference only — covered in test/static/token_discipline_test.dart',
  );

  // =========================================================================
  // N — sp-20260524: BUG-01 state derivation + BUG-R1 restore invalidation
  // =========================================================================

  // ── N-1 … N-3: BUG-01 state derivation ────────────────────────────────────

  group(
    'N-1..3 — BUG-01: BackupConnected.passphraseSet derivation',
    () {
      late FakeAppSettingsRepository settingsRepo;
      late InMemorySecureStorage storage;
      late FakeSyncLogRepository syncLogRepo;

      setUp(() {
        settingsRepo = FakeAppSettingsRepository();
        storage = InMemorySecureStorage();
        syncLogRepo = FakeSyncLogRepository();
      });

      ProviderContainer makeContainer() => ProviderContainer(
            overrides: [
              appSettingsRepositoryProvider.overrideWith(
                (_) async => settingsRepo,
              ),
              secureStorageProvider.overrideWithValue(storage),
              // restoreDataProvider / backupDataProvider not exercised by build()
              restoreDataProvider.overrideWith(
                (_) async => RestoreData(_OkRunner()),
              ),
              backupDataProvider.overrideWith(
                (_) async => BackupData(_OkRunner()),
              ),
              cloudBackupProvider.overrideWithValue(FakeDropboxProvider()),
              syncLogRepositoryProvider.overrideWith((_) async => syncLogRepo),
            ],
          );

      // N-1: no passphrase key in storage → passphraseSet: false, autoBackupActive: false
      test(
        'backup_connected_state_reports_passphraseSet_false_until_first_backup',
        () async {
          // Seed settings with a connected email; backupSuspended defaults to false.
          settingsRepo.storedSettings = AppSettingsData.defaults().copyWith(
            dropboxEmail: const Nullable('a@b.test'),
          );
          // Storage intentionally empty — no passphrase key present.

          final container = makeContainer();
          addTearDown(container.dispose);

          final state = await container.read(backupNotifierProvider.future);
          expect(state, isA<BackupConnected>());
          final connected = state as BackupConnected;
          expect(
            connected.passphraseSet,
            isFalse,
            reason: 'passphraseSet must be false when no passphrase in storage',
          );
          expect(
            connected.autoBackupActive,
            isFalse,
            reason: 'autoBackupActive must be false when passphrase absent '
                '(conjunctive condition: !backupSuspended && passphraseSet)',
          );
        },
      );

      // N-2: passphrase key present in storage → passphraseSet: true, autoBackupActive: true
      test(
        'backup_connected_state_reports_passphraseSet_true_when_storage_has_value',
        () async {
          settingsRepo.storedSettings = AppSettingsData.defaults().copyWith(
            dropboxEmail: const Nullable('a@b.test'),
          );
          storage.values[BackupNotifier.kPassphraseKey] = 'pw';

          final container = makeContainer();
          addTearDown(container.dispose);

          final state = await container.read(backupNotifierProvider.future);
          expect(state, isA<BackupConnected>());
          final connected = state as BackupConnected;
          expect(
            connected.passphraseSet,
            isTrue,
            reason: 'passphraseSet must be true when storage contains value',
          );
          expect(
            connected.autoBackupActive,
            isTrue,
            reason: 'autoBackupActive must be true when passphrase set and '
                'backupSuspended = false',
          );
        },
      );

      // N-3: backupSuspended=true + passphrase set → autoBackupActive: false
      test(
        'backup_connected_state_autoBackupActive_false_when_suspended_even_if_passphrase_set',
        () async {
          settingsRepo.storedSettings = AppSettingsData.defaults().copyWith(
            dropboxEmail: const Nullable('a@b.test'),
          );
          // Force backupSuspended = true via the dedicated writer.
          await settingsRepo.updateBackupSuspended(true);
          storage.values[BackupNotifier.kPassphraseKey] = 'pw';

          final container = makeContainer();
          addTearDown(container.dispose);

          final state = await container.read(backupNotifierProvider.future);
          expect(state, isA<BackupConnected>());
          final connected = state as BackupConnected;
          expect(
            connected.passphraseSet,
            isTrue,
            reason: 'passphraseSet must still reflect storage truthfully',
          );
          expect(
            connected.autoBackupActive,
            isFalse,
            reason:
                'autoBackupActive must be false when backupSuspended = true, '
                'even though passphrase is set',
          );
        },
      );
    },
  );

  // =========================================================================
  // O — sp-20260524: BUG-RT01 BackupNotifier count propagation
  // =========================================================================

  group(
    'O-1..3 — BUG-RT01: BackupNotifier.restore/restoreWithPassphrase count propagation',
    () {
      FakeAppSettingsRepository settingsRepo() => FakeAppSettingsRepository()
        ..storedSettings = AppSettingsData.defaults().copyWith(
          dropboxEmail: const Nullable('a@b.test'),
        );

      ProviderContainer makeContainer({
        required FakeBackupRunner fakeRunner,
        InMemorySecureStorage? storage,
      }) =>
          ProviderContainer(
            overrides: [
              appSettingsRepositoryProvider.overrideWith(
                (_) async => settingsRepo(),
              ),
              secureStorageProvider.overrideWithValue(
                storage ??
                    (InMemorySecureStorage()
                      ..values[BackupNotifier.kPassphraseKey] = 'pw'),
              ),
              restoreDataProvider.overrideWith(
                (_) async => RestoreData(fakeRunner),
              ),
              backupDataProvider.overrideWith(
                (_) async => BackupData(fakeRunner),
              ),
              cloudBackupProvider.overrideWithValue(FakeDropboxProvider()),
              syncLogRepositoryProvider.overrideWith(
                (_) async => FakeSyncLogRepository(),
              ),
            ],
          );

      // O-1: restore() returns the int count from the Ok branch.
      test(
        'backupNotifier_restore_returns_count_from_okBranch',
        () async {
          final fakeRunner = FakeBackupRunner()..restoreReturnValue = 5;
          final container = makeContainer(fakeRunner: fakeRunner);
          addTearDown(container.dispose);

          await container.read(backupNotifierProvider.future);

          final count = await container
              .read(backupNotifierProvider.notifier)
              .restore(filename: 'metra_backup_test.enc');

          expect(count, equals(5));
        },
      );

      // O-2: restore() returns null on the Err branch + sets BackupErrorState.
      test(
        'backupNotifier_restore_returns_null_on_errBranch',
        () async {
          final fakeRunner = FakeBackupRunner()
            ..restoreError = const SyncException('boom');
          final container = makeContainer(fakeRunner: fakeRunner);
          addTearDown(container.dispose);

          await container.read(backupNotifierProvider.future);
          final notifier = container.read(backupNotifierProvider.notifier);

          final count = await notifier.restore();

          expect(count, isNull);
          expect(
            container.read(backupNotifierProvider).valueOrNull,
            isA<BackupErrorState>(),
          );
        },
      );

      // O-3: restoreWithPassphrase() propagates the count from restore().
      test(
        'backupNotifier_restoreWithPassphrase_returns_count_from_okBranch',
        () async {
          final fakeRunner = FakeBackupRunner()..restoreReturnValue = 12;
          final storage = InMemorySecureStorage()
            ..values[BackupNotifier.kPassphraseKey] = 'old-pw';
          final container = makeContainer(
            fakeRunner: fakeRunner,
            storage: storage,
          );
          addTearDown(container.dispose);

          await container.read(backupNotifierProvider.future);

          final count = await container
              .read(backupNotifierProvider.notifier)
              .restoreWithPassphrase('pw', filename: 'f.enc');

          expect(count, equals(12));
        },
      );
    },
  );

  // ── N-4: BUG-R1 post-restore invalidation ──────────────────────────────────

  group(
    'N-4 — BUG-R1: restore() Ok-branch invalidates currentCycleDayProvider + cycleDayForDateProvider',
    () {
      test(
        'restore_ok_invalidates_currentCycleDay_and_cycleDayForDate',
        () async {
          // Counters track how many times each provider's create fn is called.
          var cycleDayCount = 0;
          var cycleDayForDateCount = 0;
          final testDate = DateTime.utc(2026, 5, 24);

          final settingsRepo = FakeAppSettingsRepository()
            ..storedSettings = AppSettingsData.defaults().copyWith(
              dropboxEmail: const Nullable('a@b.test'),
            );
          final storage = InMemorySecureStorage()
            ..values[BackupNotifier.kPassphraseKey] = 'pw';

          final container = ProviderContainer(
            overrides: [
              appSettingsRepositoryProvider.overrideWith(
                (_) async => settingsRepo,
              ),
              secureStorageProvider.overrideWithValue(storage),
              restoreDataProvider.overrideWith(
                (_) async => RestoreData(_OkRunner()),
              ),
              backupDataProvider.overrideWith(
                (_) async => BackupData(_OkRunner()),
              ),
              cloudBackupProvider.overrideWithValue(FakeDropboxProvider()),
              syncLogRepositoryProvider.overrideWith(
                (_) async => FakeSyncLogRepository(),
              ),
              // Counter providers — increment on every create() call.
              currentCycleDayProvider.overrideWith((_) async {
                cycleDayCount++;
                return null;
              }),
              cycleDayForDateProvider.overrideWith((ref, date) async {
                cycleDayForDateCount++;
                return null;
              }),
            ],
          );
          addTearDown(container.dispose);

          // Prime both providers once (count goes to 1).
          await container.read(currentCycleDayProvider.future);
          await container.read(cycleDayForDateProvider(testDate).future);
          expect(cycleDayCount, 1, reason: 'primed once before restore');
          expect(cycleDayForDateCount, 1, reason: 'primed once before restore');

          // Ensure notifier is built before calling restore.
          await container.read(backupNotifierProvider.future);

          // Act: trigger restore — should land in Ok() branch.
          await container
              .read(backupNotifierProvider.notifier)
              .restore(filename: 'test.enc');

          // Re-read to trigger recreation (invalidate + read = count++).
          await container.read(currentCycleDayProvider.future);
          await container.read(cycleDayForDateProvider(testDate).future);

          expect(
            cycleDayCount,
            2,
            reason:
                'currentCycleDayProvider must be invalidated by restore Ok branch',
          );
          expect(
            cycleDayForDateCount,
            2,
            reason:
                'cycleDayForDateProvider must be invalidated by restore Ok branch',
          );
        },
      );
    },
  );

  // =========================================================================
  // K — TASK-09 / L1 (FEAT-BUG-003): passphrase-rollback TOCTOU fix (FR-20)
  // =========================================================================
  //
  // `_runBackup()` changes `Future<void>` → `Future<bool>` (true on Ok(),
  // false on Err()). `backupWithPassphrase` must key the rollback decision
  // off that returned bool, not a post-hoc `state.valueOrNull is
  // BackupErrorState` inspection — the latter is racy: anything that mutates
  // `state` between the orchestrator call resolving and the inspection (e.g.
  // a concurrent settings-stream rebuild) can make a genuinely successful
  // backup look like a failure (or vice versa) at inspection time.
  //
  // G1 stages exactly that race with a completer-gated orchestrator: while
  // `_runBackup()`'s `uc()` call is still pending, `state` is mutated to
  // `BackupErrorState` (standing in for "whatever a concurrent rebuild left
  // behind") — then the orchestrator resolves `Ok()`. A state-inspection
  // implementation would misread the leftover `BackupErrorState` and roll
  // back the passphrase despite the real success; the fix must not.
  //
  // G2 is the non-race control: a genuine `Err()` still rolls back.
  // G3 is a source-grep guard: `_runBackup()` stays a private implementation
  // detail with zero call sites outside `backup_notifier.dart`.

  group(
    'K — TASK-09 / L1 (FEAT-BUG-003): passphrase-rollback TOCTOU fix (FR-20)',
    () {
      FakeAppSettingsRepository settingsRepo() => FakeAppSettingsRepository()
        ..storedSettings = AppSettingsData.defaults().copyWith(
          dropboxEmail: const Nullable('a@b.test'),
        );

      ProviderContainer makeContainer({
        required BackupRunner runner,
        required InMemorySecureStorage storage,
      }) =>
          ProviderContainer(
            overrides: [
              appSettingsRepositoryProvider.overrideWith(
                (_) async => settingsRepo(),
              ),
              secureStorageProvider.overrideWithValue(storage),
              backupDataProvider.overrideWith(
                (_) async => BackupData(runner),
              ),
              restoreDataProvider.overrideWith(
                (_) async => RestoreData(runner),
              ),
              cloudBackupProvider.overrideWithValue(FakeDropboxProvider()),
              syncLogRepositoryProvider.overrideWith(
                (_) async => FakeSyncLogRepository(),
              ),
            ],
          );

      // G1: TOCTOU race closed — Ok() completes AFTER a concurrent state
      // mutation (standing in for a concurrent stream rebuild) has already
      // set state to BackupErrorState. The rollback decision must use the
      // bool _runBackup() returns, not the racy state snapshot.
      test(
        'G1_backupWithPassphrase_does_not_roll_back_when_a_concurrent_state_'
        'mutation_leaves_BackupErrorState_but_runBackup_actually_succeeds',
        () async {
          final completer = Completer<void>();
          final runner = _CompleterGatedRunner(completer);
          final storage = InMemorySecureStorage()
            ..values[BackupNotifier.kPassphraseKey] = 'old-pass';
          final container = makeContainer(runner: runner, storage: storage);
          addTearDown(container.dispose);
          addTearDown(() {
            if (!completer.isCompleted) completer.complete();
          });

          await container.read(backupNotifierProvider.future);
          final notifier = container.read(backupNotifierProvider.notifier);

          // Act (part 1): start the manual backup — it will block inside
          // _runBackup() awaiting the gated orchestrator call.
          unawaited(notifier.backupWithPassphrase('new-pass'));
          await Future<void>.delayed(Duration.zero);

          expect(
            container.read(backupNotifierProvider).valueOrNull,
            isA<BackupRunning>(),
            reason: 'orchestrator call must be pending before the race is '
                'staged',
          );

          // Stage the race: something concurrent (e.g. a settings-stream
          // rebuild) leaves BackupErrorState in `state` WHILE the real
          // orchestrator call is still in flight and has not yet resolved.
          notifier.state = const AsyncData(
            BackupErrorState('concurrent-rebuild-noise'),
          );

          // Act (part 2): the orchestrator now genuinely succeeds.
          completer.complete();
          await Future<void>.delayed(Duration.zero);
          await Future<void>.delayed(Duration.zero);

          expect(
            storage.values[BackupNotifier.kPassphraseKey],
            equals('new-pass'),
            reason: '_runBackup() returned true (Ok()) — the rollback '
                'decision must key off that, not the racy BackupErrorState '
                'left in state by the concurrent mutation. A '
                'state-inspection implementation wrongly rolls back here.',
          );
        },
      );

      // G2: regression — a genuine Err() (no race) still rolls back, exactly
      // as the existing groups at test/features/backup/state/backup_notifier_test.dart
      // already assert; kept here too since it is the direct control case for G1.
      test(
        'G2_backupWithPassphrase_rolls_back_when_runBackup_genuinely_fails',
        () async {
          final runner = FakeBackupRunner()
            ..backupError = const SyncException('network error');
          final storage = InMemorySecureStorage()
            ..values[BackupNotifier.kPassphraseKey] = 'old-pass';
          final container = makeContainer(runner: runner, storage: storage);
          addTearDown(container.dispose);

          await container.read(backupNotifierProvider.future);
          await container
              .read(backupNotifierProvider.notifier)
              .backupWithPassphrase('new-pass');

          expect(
            storage.values[BackupNotifier.kPassphraseKey],
            equals('old-pass'),
            reason: 'a genuine Err() (no race) must still roll back the '
                'passphrase — unchanged regression behaviour',
          );
          expect(
            container.read(backupNotifierProvider).valueOrNull,
            isA<BackupErrorState>(),
          );
        },
      );

      // G3: _runBackup stays a private implementation detail — zero call
      // sites outside backup_notifier.dart. Scoped to lib/: Dart's leading-
      // underscore privacy already forbids any other *library* from calling
      // it (a cross-file call site would not compile), so this is a
      // source-grep sanity guard against the method ever being renamed away
      // from that privacy or duplicated/re-exported elsewhere in lib/.
      // Comments/prose mentioning "_runBackup(" (in this very file, or in
      // other test files' doc comments) are not call sites and are excluded
      // by scoping the scan to lib/ only.
      test(
        'G3_runBackup_has_zero_call_sites_outside_backup_notifier_dart',
        () {
          final hits = _grepDartFiles(
            ['lib'],
            RegExp(r'_runBackup\('),
          )
              .where(
                (hit) => !hit.startsWith(
                  'lib/features/backup/state/backup_notifier.dart:',
                ),
              )
              .toList();
          expect(
            hits,
            isEmpty,
            reason: '_runBackup( must have zero call sites outside '
                'backup_notifier.dart (it stays private).\nHits:\n'
                '${hits.join('\n')}',
          );
        },
      );
    },
  );

  // =========================================================================
  // L — TASK-11 / L2 (FEAT-BUG-004): cold-start guard ordering (FR-21) +
  //     truthful skip-log attribution (FR-06)
  // =========================================================================
  //
  // Pre-fix, `backupSilent()`/`backupNow()` evaluate their `BackupRunning` /
  // `BackupNotConnected` guards against `state.valueOrNull` WITHOUT first
  // awaiting `future` (the AsyncNotifier's `build()` completion). During a
  // true cold start `state.valueOrNull` is `null` (`AsyncLoading`) — neither
  // guard matches `null`, so both guards are vacuous and execution falls
  // through into the write-recency check / `_runBackup()`, bypassing whatever
  // `build()` would have derived (including `BackupNotConnected`).
  //
  // L1 stages exactly that race with a Completer-gated
  // `appSettingsRepositoryProvider` future: the notifier is read (kicking off
  // `build()`, which suspends at its first `await`) and `backupSilent()` is
  // invoked immediately, before the gate opens. The persisted settings
  // represent the post-iCloud-disconnect dropbox sentinel
  // (`activeProvider==dropbox`, `dropboxEmail==null`, FR-06) with a
  // write-recency shape that WOULD trip the skip-log write site if the guard
  // were vacuous. The fix must resolve `future` first, observe
  // `BackupNotConnected`, and return before either write site is reachable.
  //
  // L2 is the same shape for `backupNow()`.
  // L3 is the non-race control: a genuinely-connected Dropbox account still
  // gets a truthfully-attributed `backupSkipped` entry when the recency guard
  // trips (FR-06 regression).

  group(
    'L — TASK-11 / L2 (FEAT-BUG-004): cold-start guard ordering (FR-21) + '
    'truthful attribution (FR-06)',
    () {
      ProviderContainer makeGatedContainer({
        required Completer<FakeAppSettingsRepository> gate,
        required InMemorySecureStorage storage,
        required FakeBackupRunner runner,
        required FakeSyncLogRepository syncLogRepo,
      }) =>
          ProviderContainer(
            overrides: [
              appSettingsRepositoryProvider.overrideWith((_) => gate.future),
              secureStorageProvider.overrideWithValue(storage),
              backupDataProvider.overrideWith((_) async => BackupData(runner)),
              restoreDataProvider
                  .overrideWith((_) async => RestoreData(runner)),
              cloudBackupProvider.overrideWithValue(FakeDropboxProvider()),
              syncLogRepositoryProvider.overrideWith((_) async => syncLogRepo),
            ],
          );

      // L1: backupSilent() — cold-start + disconnected sentinel.
      test(
        'L1_backupSilent_awaits_build_before_evaluating_guards_'
        'disconnected_sentinel_writes_zero_entries',
        () async {
          final repo = FakeAppSettingsRepository();
          // Recency-trip shape: a pre-fix vacuous guard would fall through
          // into the write-recency check and misattribute a skip entry to
          // the dropbox sentinel (FR-06). dropboxEmail stays null.
          await repo.updateBackupState(
            dropboxEmail: null,
            lastBackupAt: DateTime.utc(2026, 1, 1),
          );
          await repo.updateLastDataWriteAt(DateTime.utc(2026, 1, 1));

          final gate = Completer<FakeAppSettingsRepository>();
          final storage = InMemorySecureStorage();
          final runner = FakeBackupRunner();
          final syncLogRepo = FakeSyncLogRepository();

          final container = makeGatedContainer(
            gate: gate,
            storage: storage,
            runner: runner,
            syncLogRepo: syncLogRepo,
          );
          addTearDown(container.dispose);
          addTearDown(() {
            if (!gate.isCompleted) gate.complete(repo);
          });

          final notifier = container.read(backupNotifierProvider.notifier);

          // Precondition: build() has not resolved — true cold start.
          expect(
            container.read(backupNotifierProvider).valueOrNull,
            isNull,
            reason: 'build() must still be AsyncLoading at call time — the '
                'gated appSettingsRepositoryProvider future has not resolved',
          );

          final call = notifier.backupSilent();
          gate.complete(repo);
          await call;

          expect(
            runner.backupCallCount,
            0,
            reason: 'E2: backupSilent() must fire ZERO orchestrator calls '
                'once it observes BackupNotConnected',
          );
          expect(
            syncLogRepo.appended,
            isEmpty,
            reason: 'FR-06: the disconnected dropbox sentinel must not '
                'produce a misattributed backupSkipped entry',
          );
        },
      );

      // L2: backupNow() — same cold-start ordering fix.
      test(
        'L2_backupNow_awaits_build_before_evaluating_guards_'
        'disconnected_sentinel_fires_zero_orchestrator_calls',
        () async {
          final repo = FakeAppSettingsRepository();
          final gate = Completer<FakeAppSettingsRepository>();
          final storage = InMemorySecureStorage()
            ..values[BackupNotifier.kPassphraseKey] = 'pw';
          final runner = FakeBackupRunner();
          final syncLogRepo = FakeSyncLogRepository();

          final container = makeGatedContainer(
            gate: gate,
            storage: storage,
            runner: runner,
            syncLogRepo: syncLogRepo,
          );
          addTearDown(container.dispose);
          addTearDown(() {
            if (!gate.isCompleted) gate.complete(repo);
          });

          final notifier = container.read(backupNotifierProvider.notifier);

          expect(
            container.read(backupNotifierProvider).valueOrNull,
            isNull,
            reason: 'build() must still be AsyncLoading at call time',
          );

          final call = notifier.backupNow();
          gate.complete(repo);
          await call;

          expect(
            runner.backupCallCount,
            0,
            reason: 'FR-21: backupNow() must observe BackupNotConnected once '
                'build() resolves and never call the orchestrator',
          );
        },
      );

      // L3: FR-06 regression — a genuine connection still attributes
      // truthfully when the recency guard trips.
      test(
        'L3_genuine_dropbox_connection_still_attributes_backupSkipped_'
        'to_dropbox',
        () async {
          final repo = FakeAppSettingsRepository();
          await repo.updateBackupState(
            dropboxEmail: 'a@b.test',
            lastBackupAt: DateTime.utc(2026, 1, 1),
          );
          await repo.updateLastDataWriteAt(DateTime.utc(2026, 1, 1));

          final storage = InMemorySecureStorage()
            ..values[BackupNotifier.kPassphraseKey] = 'pw';
          final runner = FakeBackupRunner();
          final syncLogRepo = FakeSyncLogRepository();

          final container = ProviderContainer(
            overrides: [
              appSettingsRepositoryProvider.overrideWith(
                (_) async => repo,
              ),
              secureStorageProvider.overrideWithValue(storage),
              backupDataProvider.overrideWith((_) async => BackupData(runner)),
              restoreDataProvider
                  .overrideWith((_) async => RestoreData(runner)),
              cloudBackupProvider.overrideWithValue(FakeDropboxProvider()),
              syncLogRepositoryProvider.overrideWith((_) async => syncLogRepo),
            ],
          );
          addTearDown(container.dispose);

          await container.read(backupNotifierProvider.future);
          await container.read(backupNotifierProvider.notifier).backupSilent();

          expect(syncLogRepo.appended, hasLength(1));
          expect(syncLogRepo.appended.single.provider, SyncProvider.dropbox);
          expect(
            syncLogRepo.appended.single.operation,
            SyncOperation.backupSkipped,
          );
        },
      );
    },
  );
}
