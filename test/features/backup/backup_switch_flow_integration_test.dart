// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
// SPDX-License-Identifier: GPL-3.0-or-later

// TASK-09 — Cross-cutting switch-flow integration tests (§7.2 Groups C/D).
//
// Spec refs: FR-09..FR-13, NFR-07/08/09, CC-1, CC-3.1, EC-04/05/08.
//
// Tests the FULL chain: provider seams → BackupNotifier.switchProvider →
// canonical-order invariants (spy sequence) + error paths + edge cases.
// One widget test validates the mounted-guard for the view handler.
//
// No NativeDatabase.memory() — M4 has no DB migration (schema 11 unchanged).
// All state via FakeAppSettingsRepository + InMemorySecureStorage.
// iOS arm via debugDefaultTargetPlatformOverride + tearDown reset.
//
// Platform matrix: Linux CI, headless; iOS arm via platform override.
//
// To run locally:
//   mkdir -p /tmp/sqlitelib && \
//   ln -sf /usr/lib/x86_64-linux-gnu/libsqlite3.so.0 /tmp/sqlitelib/libsqlite3.so
//   LD_LIBRARY_PATH=/tmp/sqlitelib flutter test \
//     test/features/backup/backup_switch_flow_integration_test.dart

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/errors/metra_exception.dart';
import 'package:metra/core/theme/metra_theme.dart';
import 'package:metra/data/services/backup/backup_file_entry.dart';
import 'package:metra/data/services/backup/cloud_backup_provider.dart';
import 'package:metra/domain/entities/app_settings_data.dart';
import 'package:metra/domain/entities/sync_log_entity.dart';
import 'package:metra/domain/use_cases/backup_data.dart';
import 'package:metra/domain/use_cases/restore_data.dart';
import 'package:metra/features/backup/state/backup_notifier.dart';
import 'package:metra/features/backup/state/backup_state.dart';
import 'package:metra/features/backup/views/backup_empty_view.dart';
import 'package:metra/l10n/app_localizations.dart';
import 'package:metra/providers/backup_providers.dart';
import 'package:metra/providers/encryption_provider.dart';
import 'package:metra/providers/repository_providers.dart';

import '../../helpers/fake_app_settings_repository.dart';
import '../../helpers/fake_dropbox_provider.dart';
import '../../helpers/fake_icloud_provider.dart';
import '../../helpers/fake_sync_log_repository.dart';
import '../../helpers/in_memory_secure_storage.dart';

// ---------------------------------------------------------------------------
// File-private fakes
// ---------------------------------------------------------------------------

/// Spy-enabled Google Drive fake.  Mirrors the private
/// `_FakeGoogleDriveProvider` from backup_notifier_test.dart so this file
/// is self-contained without coupling to that file's private types.
class _FakeGoogleDriveProvider implements CloudBackupProvider {
  int disconnectCalls = 0;
  int authorizeCalls = 0;
  bool authorizeThrows = false;
  String? currentEmailResult = 'user@google.com';
  final List<String> deleteCalls = [];

  @override
  SyncProvider get id => SyncProvider.googleDrive;

  @override
  Future<void> authorize() async {
    authorizeCalls++;
    if (authorizeThrows) {
      throw const SyncException('Google Drive auth failed');
    }
  }

  @override
  Future<String?> currentEmail() async => currentEmailResult;

  @override
  Future<void> disconnect() async {
    disconnectCalls++;
  }

  @override
  Future<void> upload(Uint8List blob, String filename) async {}

  @override
  Future<Uint8List> download(String filename) async => Uint8List(0);

  @override
  Future<List<BackupFileEntry>> listFiles() async => [];

  @override
  Future<void> deleteFile(String filename) async {
    deleteCalls.add(filename);
  }
}

/// Google Drive fake whose [authorize] blocks until [release] is completed.
/// Used for the re-entrancy test (EC-06).
class _BlockingAuthGoogleDriveProvider implements CloudBackupProvider {
  _BlockingAuthGoogleDriveProvider(this.release);

  final Completer<void> release;
  int authorizeCalls = 0;

  @override
  SyncProvider get id => SyncProvider.googleDrive;

  @override
  Future<void> authorize() async {
    authorizeCalls++;
    await release.future;
  }

  @override
  Future<String?> currentEmail() async => 'user@google.com';

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> upload(Uint8List blob, String filename) async {}

  @override
  Future<Uint8List> download(String filename) async => Uint8List(0);

  @override
  Future<List<BackupFileEntry>> listFiles() async => [];

  @override
  Future<void> deleteFile(String filename) async {}
}

/// Minimal [BackupRunner] stub.  [switchProvider] does not call backup or
/// restore, but the container must have [backupDataProvider] and
/// [restoreDataProvider] overrides to avoid resolving real DB infrastructure.
class _FakeRunner implements BackupRunner {
  @override
  Future<void> backup() async {}

  @override
  Future<int> restore({String? filename}) async => 0;
}

/// [BackupNotifier] whose [switchProvider] blocks until [release] is
/// completed.  Used by the mounted-guard widget test (I-07) so the test can
/// unmount the widget while [handleConnectViaPicker] is mid-await.
class _BlockingSwitchNotifier extends BackupNotifier {
  _BlockingSwitchNotifier(this._release);

  final Completer<void> _release;

  @override
  Future<BackupState> build() async => const BackupNotConnected();

  @override
  Future<void> switchProvider(SyncProvider target) async {
    await _release.future;
  }
}

/// File-private StreamController-backed fake that re-emits [watchSettings]
/// after each mutating write.
///
/// The shared [FakeAppSettingsRepository.watchSettings] returns
/// [Stream.value(storedSettings)] — a cold single-shot stream that never
/// re-emits on mutations.  This makes BUG-01 structurally invisible to all
/// existing tests (I-01..I-07), because [BackupNotifier.build()] never sees a
/// re-emission while [switchProvider] is in flight.
///
/// This subclass adds a broadcast [StreamController] and overrides the three
/// mutating methods called by [switchProvider] to re-emit after each write.
/// Combined with the [appSettingsRepositoryProvider] override in
/// [makeReemittingSwitchContainer], this makes [appSettingsStreamProvider]
/// re-emit automatically — which marks [BackupNotifier] dirty, triggering the
/// Riverpod assertion at line 246 (`ref.read(resolveBackupProvider(target))`).
///
/// File-private (C-05): the shared helper in test/helpers/ is NOT modified.
class _ReemittingFakeAppSettingsRepository extends FakeAppSettingsRepository {
  final _controller = StreamController<AppSettingsData?>.broadcast();

  @override
  Stream<AppSettingsData?> watchSettings() async* {
    yield storedSettings; // first emission — lets build()'s .future complete
    yield* _controller.stream; // subsequent re-emissions on each mutation
  }

  @override
  Future<void> setActiveProvider(SyncProvider provider) async {
    await super.setActiveProvider(provider);
    _controller.add(storedSettings);
  }

  @override
  Future<void> updateBackupState({
    required String? dropboxEmail,
    required DateTime? lastBackupAt,
  }) async {
    await super.updateBackupState(
      dropboxEmail: dropboxEmail,
      lastBackupAt: lastBackupAt,
    );
    _controller.add(storedSettings);
  }

  @override
  Future<void> clearBackupSuspended() async {
    await super.clearBackupSuspended();
    _controller.add(storedSettings);
  }

  /// Closes the broadcast controller.  Call from [addTearDown] in I-08.
  void dispose() => _controller.close();
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _wrapEmpty({required _BlockingSwitchNotifier spy}) {
  return ProviderScope(
    overrides: [
      backupNotifierProvider.overrideWith(() => spy),
    ],
    child: MaterialApp(
      theme: MetraTheme.light(),
      locale: const Locale('it'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const BackupEmptyView(),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late FakeAppSettingsRepository settingsRepo;
  late InMemorySecureStorage storage;
  late FakeDropboxProvider fakeDropbox;
  late FakeICloudProvider fakeICloud;
  late _FakeGoogleDriveProvider fakeGoogleDrive;
  late FakeSyncLogRepository fakeSyncLogRepo;
  late _FakeRunner runner;

  setUp(() {
    settingsRepo = FakeAppSettingsRepository();
    storage = InMemorySecureStorage();
    fakeDropbox = FakeDropboxProvider();
    fakeICloud = FakeICloudProvider();
    fakeGoogleDrive = _FakeGoogleDriveProvider();
    fakeSyncLogRepo = FakeSyncLogRepository();
    runner = _FakeRunner();
  });

  /// Standard ProviderContainer for switch-flow integration tests.
  ///
  /// Overrides [resolveBackupProvider] so spy fakes are returned for each
  /// [SyncProvider].  [cloudBackupProvider] resolves through the family
  /// (not pinned) — correct for all scenarios except explicit stale-read checks.
  ProviderContainer makeSwitchContainer() {
    return ProviderContainer(
      overrides: [
        appSettingsRepositoryProvider.overrideWith(
          (_) async => settingsRepo,
        ),
        secureStorageProvider.overrideWithValue(storage),
        backupDataProvider.overrideWith((_) async => BackupData(runner)),
        restoreDataProvider.overrideWith((_) async => RestoreData(runner)),
        resolveBackupProvider.overrideWith((ref, id) {
          switch (id) {
            case SyncProvider.dropbox:
              return fakeDropbox;
            case SyncProvider.googleDrive:
              return fakeGoogleDrive;
            case SyncProvider.iCloud:
              return fakeICloud;
          }
        }),
        syncLogRepositoryProvider.overrideWith((_) async => fakeSyncLogRepo),
      ],
    );
  }

  /// ProviderContainer for the BUG-01 re-emit regression test (I-08).
  ///
  /// Mirrors [makeSwitchContainer] but replaces [appSettingsRepositoryProvider]
  /// with [reemitFake].  Since [appSettingsStreamProvider] is:
  ///   `yield* (await ref.watch(appSettingsRepositoryProvider.future)).watchSettings()`
  /// overriding the repository is sufficient — no separate
  /// [appSettingsStreamProvider] override is needed.
  ProviderContainer makeReemittingSwitchContainer(
    _ReemittingFakeAppSettingsRepository reemitFake,
  ) {
    return ProviderContainer(
      overrides: [
        appSettingsRepositoryProvider.overrideWith(
          (_) async => reemitFake,
        ),
        secureStorageProvider.overrideWithValue(storage),
        backupDataProvider.overrideWith((_) async => BackupData(runner)),
        restoreDataProvider.overrideWith((_) async => RestoreData(runner)),
        resolveBackupProvider.overrideWith((ref, id) {
          switch (id) {
            case SyncProvider.dropbox:
              return fakeDropbox;
            case SyncProvider.googleDrive:
              return fakeGoogleDrive;
            case SyncProvider.iCloud:
              return fakeICloud;
          }
        }),
        syncLogRepositoryProvider.overrideWith((_) async => fakeSyncLogRepo),
      ],
    );
  }

  // ── I-01: Full switch Dropbox→Google Drive — canonical-order spy ─────────

  test(
    'I-01 full switch D→GDrive: canonical spy order '
    '(disconnect→setActiveProvider→authorize) + passphrase unchanged '
    '→ BackupConnected(provider:googleDrive)',
    () async {
      await settingsRepo.updateBackupState(
        dropboxEmail: 'user@dropbox.com',
        lastBackupAt: null,
      );
      storage.values[BackupNotifier.kPassphraseKey] = 'my-passphrase';

      // Ordering invariant: at the exact moment disconnect() fires, the
      // callLog must NOT yet contain 'setActiveProvider' (FR-10/FR-11).
      fakeDropbox.onDisconnectCalled = () {
        expect(
          settingsRepo.callLog.contains('setActiveProvider'),
          isFalse,
          reason:
              'setActiveProvider must NOT be called before old.disconnect() '
              'completes (FR-10 canonical order)',
        );
      };

      final container = makeSwitchContainer();
      addTearDown(container.dispose);
      await container.read(backupNotifierProvider.future);

      await container
          .read(backupNotifierProvider.notifier)
          .switchProvider(SyncProvider.googleDrive);

      // ── Spy counts ──────────────────────────────────────────────────────
      expect(
        fakeDropbox.disconnectCalls,
        1,
        reason:
            'old provider (dropbox) disconnect() must be called once (FR-10)',
      );
      expect(
        fakeGoogleDrive.disconnectCalls,
        0,
        reason: 'new provider disconnect() must NOT be called (FR-10)',
      );
      expect(
        fakeGoogleDrive.authorizeCalls,
        1,
        reason: 'new provider authorize() must be called once (FR-12)',
      );
      expect(
        fakeDropbox.deleteCalls,
        isEmpty,
        reason: 'deleteFile must NOT be called on old provider (FR-13)',
      );

      // ── activeProvider flipped ──────────────────────────────────────────
      final settings = await settingsRepo.getOrCreate();
      expect(
        settings.activeProvider,
        SyncProvider.googleDrive,
        reason: 'activeProvider must be persisted as googleDrive after flip',
      );
      expect(
        settingsRepo.callLog,
        contains('setActiveProvider'),
        reason: 'setActiveProvider must appear in callLog',
      );

      // ── Passphrase unchanged (FR-13) ────────────────────────────────────
      expect(
        storage.values[BackupNotifier.kPassphraseKey],
        'my-passphrase',
        reason: 'kBackupPassphraseKey must be unchanged throughout (FR-13)',
      );

      // ── Final state ─────────────────────────────────────────────────────
      final finalState = await container.read(backupNotifierProvider.future);
      expect(
        finalState,
        isA<BackupConnected>(),
        reason: 'final state must be BackupConnected after successful switch',
      );
      expect(
        (finalState as BackupConnected).provider,
        SyncProvider.googleDrive,
        reason:
            'BackupConnected.provider must reflect the new active provider (FR-15)',
      );
    },
  );

  // ── I-02: Abort-before-connect (EC-04 / FR-11) ───────────────────────────

  test(
    'I-02 abort-before-connect (EC-04): disconnect throws → '
    'activeProvider stays dropbox, authorizeCalls==0, '
    'setActiveProvider NOT called, state is BackupErrorState',
    () async {
      await settingsRepo.updateBackupState(
        dropboxEmail: 'user@dropbox.com',
        lastBackupAt: null,
      );
      // Arm the abort gate.
      fakeDropbox.disconnectThrows = true;

      final container = makeSwitchContainer();
      addTearDown(container.dispose);
      await container.read(backupNotifierProvider.future);

      await container
          .read(backupNotifierProvider.notifier)
          .switchProvider(SyncProvider.googleDrive);

      // activeProvider unchanged.
      final settings = await settingsRepo.getOrCreate();
      expect(
        settings.activeProvider,
        SyncProvider.dropbox,
        reason: 'abort gate: activeProvider must remain dropbox (EC-04/FR-11)',
      );

      // New provider was never authorized.
      expect(
        fakeGoogleDrive.authorizeCalls,
        0,
        reason: 'abort gate: new provider must NOT be authorized (EC-04/FR-11)',
      );

      // setActiveProvider was never called.
      expect(
        settingsRepo.callLog,
        isNot(contains('setActiveProvider')),
        reason:
            'abort gate: setActiveProvider must NOT be called (EC-04/FR-11)',
      );

      // State is BackupErrorState.
      final state = container.read(backupNotifierProvider).valueOrNull;
      expect(
        state,
        isA<BackupErrorState>(),
        reason:
            'abort gate: state must be BackupErrorState after disconnect throw',
      );
    },
  );

  // ── I-03: Post-flip connect failure stays flipped (EC-05 / OQ-01) ─────────

  test(
    'I-03 post-flip failure (EC-05/OQ-01): authorize throws after flip → '
    'activeProvider==googleDrive (no rollback), dropboxEmail==null, '
    'BackupErrorState; next build()→BackupNotConnected(googleDrive)',
    () async {
      await settingsRepo.updateBackupState(
        dropboxEmail: 'user@dropbox.com',
        lastBackupAt: null,
      );
      // Arm authorize failure on the NEW provider (post-flip failure).
      fakeGoogleDrive.authorizeThrows = true;

      final container = makeSwitchContainer();
      addTearDown(container.dispose);
      await container.read(backupNotifierProvider.future);

      await container
          .read(backupNotifierProvider.notifier)
          .switchProvider(SyncProvider.googleDrive);

      // activeProvider stays on the target (no rollback — OQ-01 decision).
      final settings = await settingsRepo.getOrCreate();
      expect(
        settings.activeProvider,
        SyncProvider.googleDrive,
        reason: 'OQ-01: activeProvider must stay googleDrive (no rollback)',
      );

      // Old identity was cleared.
      expect(
        settings.dropboxEmail,
        isNull,
        reason: 'old identity (dropboxEmail) must be null after flip',
      );

      // Immediate state is BackupErrorState.
      final errorState = container.read(backupNotifierProvider).valueOrNull;
      expect(
        errorState,
        isA<BackupErrorState>(),
        reason: 'post-flip failure must surface BackupErrorState',
      );

      // Next build() re-run (via invalidate) → BackupNotConnected for googleDrive
      // because activeProvider==googleDrive with no email → not connected.
      container.invalidate(backupNotifierProvider);
      final nextState = await container.read(backupNotifierProvider.future);
      expect(
        nextState,
        isA<BackupNotConnected>(),
        reason: 'OQ-01: next build() must emit BackupNotConnected for the new '
            'provider so the user can retry from a clean state',
      );
    },
  );

  // ── I-04: iCloud null email tolerated (EC-08 / FR-12) ────────────────────

  test(
    'I-04 iCloud null email (EC-08): iOS override; '
    'currentEmail()==null tolerated → BackupConnected(provider:iCloud)',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      await settingsRepo.updateBackupState(
        dropboxEmail: 'user@dropbox.com',
        lastBackupAt: null,
      );
      // fakeICloud.currentEmail() returns null by default (EC-08).

      final container = makeSwitchContainer();
      addTearDown(container.dispose);
      await container.read(backupNotifierProvider.future);

      // Must NOT throw — null email is tolerated for iCloud.
      await container
          .read(backupNotifierProvider.notifier)
          .switchProvider(SyncProvider.iCloud);

      final settings = await settingsRepo.getOrCreate();
      expect(
        settings.activeProvider,
        SyncProvider.iCloud,
        reason: 'activeProvider must be flipped to iCloud',
      );
      expect(
        settings.dropboxEmail,
        isNull,
        reason: 'iCloud stores null email (EC-08)',
      );

      // build() re-run: iCloud arm probes authorize() which is a no-op on fake.
      // FakeICloudProvider.authorize() increments authorizeCalls and doesn't throw.
      final finalState = await container.read(backupNotifierProvider.future);
      expect(
        finalState,
        isA<BackupConnected>(),
        reason: 'final state must be BackupConnected for iCloud',
      );
      expect(
        (finalState as BackupConnected).provider,
        SyncProvider.iCloud,
        reason: 'BackupConnected.provider must be iCloud (FR-15)',
      );
    },
  );

  // ── I-05: Re-entrancy guard (EC-06) ──────────────────────────────────────

  test(
    'I-05 re-entrancy (EC-06): BackupRunning(switching) blocks first call; '
    'second call returns immediately; authorizeCalls <= 1',
    () async {
      await settingsRepo.updateBackupState(
        dropboxEmail: 'user@dropbox.com',
        lastBackupAt: null,
      );

      final releaser = Completer<void>();
      final blockingGoogleDrive = _BlockingAuthGoogleDriveProvider(releaser);

      final container = ProviderContainer(
        overrides: [
          appSettingsRepositoryProvider.overrideWith(
            (_) async => settingsRepo,
          ),
          secureStorageProvider.overrideWithValue(storage),
          backupDataProvider.overrideWith((_) async => BackupData(runner)),
          restoreDataProvider.overrideWith((_) async => RestoreData(runner)),
          resolveBackupProvider.overrideWith((ref, id) {
            switch (id) {
              case SyncProvider.dropbox:
                return fakeDropbox;
              case SyncProvider.googleDrive:
                return blockingGoogleDrive;
              case SyncProvider.iCloud:
                return fakeICloud;
            }
          }),
          syncLogRepositoryProvider.overrideWith((_) async => fakeSyncLogRepo),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(() {
        if (!releaser.isCompleted) releaser.complete();
      });

      await container.read(backupNotifierProvider.future);

      // First call blocks inside blockingGoogleDrive.authorize().
      unawaited(
        container
            .read(backupNotifierProvider.notifier)
            .switchProvider(SyncProvider.googleDrive),
      );
      // Allow microtasks to advance state to BackupRunning(switching).
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(backupNotifierProvider).valueOrNull,
        isA<BackupRunning>(),
        reason: 'precondition: first call must have entered BackupRunning',
      );

      // Second call must return immediately (re-entrancy guard).
      await container
          .read(backupNotifierProvider.notifier)
          .switchProvider(SyncProvider.googleDrive)
          .timeout(
            const Duration(seconds: 3),
            onTimeout: () => throw StateError(
              'switchProvider did not return within 3 s — '
              're-entrancy guard is missing (EC-06)',
            ),
          );

      expect(
        blockingGoogleDrive.authorizeCalls,
        lessThanOrEqualTo(1),
        reason: 'EC-06: re-entrant call must not invoke authorize() again',
      );

      // Unblock the first call to clean up.
      releaser.complete();
    },
    timeout: const Timeout(Duration(seconds: 10)),
  );

  // ── I-06: First-connect via picker — idempotent forget (EC-02) ───────────

  test(
    'I-06 first-connect via picker (EC-02): clean state (no token); '
    'old.disconnect() is a no-op; authorize called once; '
    'activeProvider flips to googleDrive; passphrase untouched',
    () async {
      // Clean state: BackupNotConnected, activeProvider==dropbox (default),
      // no Dropbox token in secure storage.  InMemorySecureStorage starts empty
      // so kPassphraseKey is already absent (read() returns null for missing keys).

      final container = makeSwitchContainer();
      addTearDown(container.dispose);
      await container.read(backupNotifierProvider.future);

      // FakeDropboxProvider.disconnect() is always a no-op (no real token to delete).
      await container
          .read(backupNotifierProvider.notifier)
          .switchProvider(SyncProvider.googleDrive);

      // disconnect() was called (idempotent no-op on clean state).
      expect(
        fakeDropbox.disconnectCalls,
        1,
        reason:
            'EC-02: disconnect() is always called (idempotent no-op on clean state)',
      );

      // authorize() was called on the new provider.
      expect(
        fakeGoogleDrive.authorizeCalls,
        1,
        reason:
            'EC-02: new provider must be authorized after idempotent forget',
      );

      // activeProvider flipped.
      final settings = await settingsRepo.getOrCreate();
      expect(
        settings.activeProvider,
        SyncProvider.googleDrive,
        reason: 'EC-02: activeProvider must flip to googleDrive',
      );

      // Passphrase (if any) untouched.  On a clean state it was null, and it
      // must remain null (not set by switchProvider which never writes the key).
      expect(
        storage.values[BackupNotifier.kPassphraseKey],
        isNull,
        reason: 'EC-02: passphrase key must not be written by switchProvider',
      );
    },
  );

  // ── I-07: Mounted-guard — view disposed mid-await (OQ-QA-02) ─────────────

  testWidgets(
    'I-07 mounted-guard (OQ-QA-02): BackupEmptyView disposed while '
    'switchProvider is mid-await → no post-unmount crash or exception',
    (tester) async {
      // Use a large physicalSize + DPR=1.0 so the CupertinoPickerScaffold
      // toolbar does not overflow (default DPR=3.0 would give 266.7 px, too
      // narrow for the scaffold layout).
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final releaser = Completer<void>();
      final spy = _BlockingSwitchNotifier(releaser);

      await tester.pumpWidget(_wrapEmpty(spy: spy));
      await tester.pumpAndSettle();

      // Tap the connect CTA to open the provider picker.
      await tester.tap(find.byKey(const Key('backup_empty_cta')));
      await tester.pumpAndSettle();

      // Confirm with the default selection.  This triggers
      // handleConnectViaPicker → BackupProviderPickerSheet returns a provider
      // → switchProvider is called (which blocks on the Completer).
      await tester.tap(find.byKey(const Key('confirm')));
      // Single pump: advance to the await boundary without settling.
      await tester.pump();

      // Unmount the widget while switchProvider is blocked.
      await tester.pumpWidget(const SizedBox.shrink());

      // Release the block — the handler would try to run the
      // mounted-guard after this await completes.
      releaser.complete();
      await tester.pump();

      // No exception must be thrown (mounted-guard prevents post-unmount access).
      expect(tester.takeException(), isNull);
    },
  );

  // ── I-08: Re-emit regression (BUG-01) ────────────────────────────────────

  test(
    'I-08 re-emit regression (BUG-01): watchSettings re-emits on setActiveProvider '
    'mid-switchProvider → switchProvider completes without Riverpod '
    'ref-after-Drift-mutation crash',
    () async {
      // Setup: use the re-emitting fake so stream emissions fire mid-switchProvider.
      final reemitFake = _ReemittingFakeAppSettingsRepository();
      // Pre-seed connected state: Dropbox active, email present so build()
      // resolves BackupConnected rather than BackupNotConnected.
      await reemitFake.updateBackupState(
        dropboxEmail: 'user@dropbox.com',
        lastBackupAt: null,
      );
      storage.values[BackupNotifier.kPassphraseKey] = 'my-passphrase';
      // LIFO teardown: container.dispose runs first (registered second),
      // then reemitFake.dispose closes the broadcast controller.
      addTearDown(reemitFake.dispose);

      final container = makeReemittingSwitchContainer(reemitFake);
      addTearDown(container.dispose);

      // Wait for initial build to complete so the notifier is fully resolved
      // before we exercise switchProvider.
      await container.read(backupNotifierProvider.future);

      // Act: attempt the provider switch; catch any Riverpod assertion.
      //
      // BUG-01 mechanism: setActiveProvider (step 6) → _controller.add() →
      // appSettingsStreamProvider re-emits → BackupNotifier marked dirty.
      // ref.read(resolveBackupProvider(target)) at step 8 then fires the
      // Riverpod assertion because the notifier's ref is in a dirty state.
      Object? caught;
      try {
        await container
            .read(backupNotifierProvider.notifier)
            .switchProvider(SyncProvider.googleDrive);
      } catch (e) {
        caught = e;
      }

      // PRIMARY RED assertion: BUG-01 guard.
      // Before the fix: caught != null (Riverpod StateError/assertion).
      // After the fix:  caught == null (ref.read hoisted before the mutation).
      expect(
        caught,
        isNull,
        reason:
            'BUG-01: ref.read(resolveBackupProvider(target)) after the Drift '
            're-emission must not throw a Riverpod assertion',
      );

      // Progress guards — a fix that merely swallows the error cannot pass
      // these: they confirm the switch actually completed the happy path.
      final s = await reemitFake.getOrCreate();
      expect(
        s.activeProvider,
        SyncProvider.googleDrive,
        reason: 'activeProvider must be persisted as googleDrive after switch',
      );
      expect(
        fakeGoogleDrive.authorizeCalls,
        1,
        reason: 'new provider authorize() must be called exactly once',
      );
      final finalState = await container.read(backupNotifierProvider.future);
      expect(
        finalState,
        isA<BackupConnected>(),
        reason: 'final state must be BackupConnected after successful switch',
      );
      expect(
        (finalState as BackupConnected).provider,
        SyncProvider.googleDrive,
        reason: 'BackupConnected.provider must reflect the new active provider',
      );
    },
  );
}
