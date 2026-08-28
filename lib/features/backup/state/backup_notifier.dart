// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/metra_exception.dart';
import '../../../core/utils/result.dart';
import '../../../data/services/backup/backup_filename.dart';
import '../../../data/services/backup/cloud_backup_provider.dart';
import '../../../domain/entities/app_settings_data.dart';
import '../../../domain/entities/sync_log_entity.dart';
import '../../../domain/repositories/app_settings_repository.dart';
import '../../../providers/backup_providers.dart';
import '../../../providers/encryption_provider.dart';
import '../../../providers/repository_providers.dart';
import '../../../providers/use_case_providers.dart';
import 'backup_state.dart';

class BackupNotifier extends AsyncNotifier<BackupState> {
  /// Secure-storage key for the cached backup passphrase.
  ///
  /// Delegates to [AppConstants.kBackupPassphraseKey] so there is exactly one
  /// definition of the key string in the codebase (FR-23).  Exposed as a
  /// public constant so [BackupScreen] can read the cached value without
  /// hardcoding the literal string in the UI layer.
  static const kPassphraseKey = AppConstants.kBackupPassphraseKey;

  // Keep the private alias to avoid changing every internal call-site.
  static const _passphraseKey = kPassphraseKey;

  /// The [BackupOperation] currently mid-flight, or `null` when idle
  /// (TASK-06, FR-08/FR-09).
  ///
  /// Unifies the re-entrancy/overlay guard across [firstConnect],
  /// [disconnect], and [switchProvider] — previously only [switchProvider]
  /// tracked this (as a `bool`), which meant (a) [build] always reported a
  /// hardcoded [BackupOperation.switching] regardless of which operation was
  /// actually running, and (b) [firstConnect]/[disconnect] had no
  /// re-entrancy guard at all.
  ///
  /// The Drift writes each of these three flows performs re-emit
  /// [appSettingsStreamProvider] and re-trigger [build] before the flow
  /// itself has finished (e.g. before the terminal passphrase-key wipe or
  /// `ref.invalidateSelf()`); deriving state from those half-written
  /// settings would flash the wrong state over the running overlay. While
  /// set, [build] returns `BackupRunning(_inFlightOperation!)` instead — the
  /// ACTUAL operation, not a hardcoded value.
  ///
  /// Set in a `try` and cleared to `null` in `finally` on every exit path of
  /// all three methods (FR-09) — never left non-null after a method returns,
  /// so the UI can never wedge in [BackupRunning] indefinitely (D4).
  BackupOperation? _inFlightOperation;

  /// Memoization key/value pair for the iCloud container probe (FR-15).
  ///
  /// `_iCloudProbeKey` records the `activeProvider` the memo was computed
  /// for; `_iCloudProbeMemo` holds the last probe result. A `false`
  /// (signed-out/unavailable) result is deliberately NEVER memoized — only
  /// `true` is ever stored — so a user who re-signs into iCloud mid-session
  /// is picked up on the very next call rather than waiting for an explicit
  /// connect/disconnect/switch (EC-07).
  ///
  /// Invalidated (both set to `null`) at first-connect / disconnect / switch
  /// (FR-16, [_invalidateICloudProbeMemo]) and on backup/restore failure
  /// (FR-23) — see the `Err` branches of [_runBackup] and [restore]. A
  /// successful backup/restore does NOT invalidate the memo (FR-23 negative
  /// case): only failure signals the container may have become unreachable.
  SyncProvider? _iCloudProbeKey;
  bool? _iCloudProbeMemo;

  /// Clears the iCloud probe memo (FR-16/FR-23) so the next [_isConnected]
  /// call re-probes the container instead of returning a stale cached value.
  void _invalidateICloudProbeMemo() {
    _iCloudProbeKey = null;
    _iCloudProbeMemo = null;
  }

  /// Single derivation point for the "is a backup provider connected?"
  /// predicate (FR-15).
  ///
  /// Exhaustive switch over [AppSettingsData.activeProvider] (TASK-07, M3):
  ///   - dropbox / googleDrive → email-sentinel (`dropboxEmail != null`),
  ///     preserving the pre-M3 behaviour exactly (zero regression).
  ///   - iCloud → idempotent container probe via [CloudBackupProvider.authorize];
  ///     a [SyncException] means signed-out/unavailable (NFR-06); the catch is
  ///     LOCAL — no exception may escape [build()] (EC-07).
  ///
  /// Not `activeProvider != null` — that defaults to dropbox and is never null.
  Future<bool> _isConnected(AppSettingsData settings) async {
    switch (settings.activeProvider) {
      case SyncProvider.dropbox:
      case SyncProvider.googleDrive:
        return settings.dropboxEmail != null; // unchanged sentinel (FR-19)
      case SyncProvider.iCloud:
        // FR-15: return the memoized result when it was computed for the
        // SAME activeProvider — repeated settings emissions that leave
        // activeProvider unchanged (e.g. a daily-log save bumping
        // lastLogOrSymptomWriteAt) must not re-run the probe (NFR-07).
        if (_iCloudProbeKey == settings.activeProvider &&
            _iCloudProbeMemo != null) {
          return _iCloudProbeMemo!;
        }
        try {
          await ref.read(cloudBackupProvider).authorize(); // container probe
          _iCloudProbeKey = settings.activeProvider;
          _iCloudProbeMemo = true;
          return true;
        } on SyncException {
          // EC-07: a probe failure is NEVER memoized as connected — leave
          // the memo cleared so the very next call re-probes.
          _iCloudProbeKey = null;
          _iCloudProbeMemo = null;
          return false; // signed-out → not connected (NFR-06)
        }
    }
  }

  @override
  Future<BackupState> build() async {
    // BUG-B01: watch the reactive Drift stream so build() re-triggers on every
    // stream emission (e.g. after backupSuspended is written by DeleteAllData).
    // Awaiting .future ensures build() blocks until the first emission — this
    // preserves compatibility with fake StreamProviders backed by Stream.value().
    // We deliberately ignore the emitted value and re-read fresh data via
    // getOrCreate(), which always returns the current DB/in-memory state and
    // is not subject to stream-lag between the emission and the read.
    await ref.watch(appSettingsStreamProvider.future);
    // Mid-operation rebuilds must not read the half-written settings any of
    // firstConnect/disconnect/switchProvider's Drift writes produce — hold
    // the running overlay, reporting the ACTUAL in-flight operation (FR-08),
    // until the flow finishes (its finally clears the flag before the final
    // invalidateSelf / return).
    if (_inFlightOperation != null) {
      return BackupRunning(_inFlightOperation!);
    }
    final settingsRepo = await ref.read(appSettingsRepositoryProvider.future);
    final settings = await settingsRepo.getOrCreate();
    if (!await _isConnected(settings)) {
      return const BackupNotConnected();
    }
    final passphrase = await ref
        .read(secureStorageProvider)
        .read(key: _passphraseKey);
    final passphraseSet = passphrase != null && passphrase.isNotEmpty;
    final autoBackupActive = !settings.backupSuspended && passphraseSet;
    return BackupConnected(
      // TASK-04 (FR-15, OQ-06): populate provider from settings so the
      // connected view can render the active provider's display name without
      // re-reading settings (single source of truth, no stale-read hazard).
      provider: settings.activeProvider,
      email: settings.dropboxEmail, // nullable — no `!` (FR-16)
      lastBackupAt: settings.lastBackupAt,
      autoBackupActive: autoBackupActive,
      passphraseSet: passphraseSet,
    );
  }

  /// Shared handshake for both [firstConnect] and [switchProvider]'s
  /// post-flip step (FR-01): authorize → currentEmail → best-effort
  /// `listFiles` → `updateBackupState` → `clearBackupSuspended`.
  ///
  /// Takes an already-resolved [provider] and [settingsRepo] rather than
  /// resolving [target] / reading the repository itself. BOTH callers
  /// resolve exclusively via [resolveBackupProvider] (CC-2) — NEVER
  /// [cloudBackupProvider], which is keyed off the (possibly stale)
  /// persisted `activeProvider` and would race the Drift stream mid-switch —
  /// so CC-2 holds end-to-end even though the resolution call itself lives
  /// at the call site, not in this method.
  ///
  /// This split is deliberate (BUG-01 ref-hoist): [switchProvider] must
  /// resolve the new provider AND the settings repository BEFORE its steps
  /// 6–7 Drift writes, exactly like the pre-refactor code did — calling
  /// `ref.read` for EITHER one AFTER those writes throws a Riverpod "ref
  /// used after dependency changed but before rebuild" assertion once
  /// `appSettingsStreamProvider` re-emits (regression-guarded by
  /// `backup_switch_flow_integration_test.dart` I-08/I-09). Folding either
  /// read into this shared method would silently reintroduce that crash for
  /// the switchProvider caller, so both callers hoist both reads themselves
  /// and pass the resolved instances in.
  ///
  /// Never reads, writes, or deletes [kPassphraseKey] — the G-02/G-04
  /// source-grep guards enforce that invariant and also require this method
  /// to be defined outside the [switchProvider]→[backupWithPassphrase]
  /// marker span.
  ///
  /// Failure contract: [CloudBackupProvider.authorize] throwing, or the
  /// null-email guard throwing, propagates to the caller with NO Drift
  /// write performed — the caller ([firstConnect] / [switchProvider])
  /// converts the exception to [BackupErrorState]. A `listFiles()` failure
  /// is best-effort only: it is swallowed and does not block
  /// `updateBackupState` / `clearBackupSuspended` (EC-04).
  Future<void> _completeProviderHandshake(
    SyncProvider target,
    CloudBackupProvider provider,
    AppSettingsRepository settingsRepo,
  ) async {
    await provider.authorize();
    final email = await provider.currentEmail();
    // iCloud has no email; only fail on null for OAuth-based providers (FR-16).
    if (email == null && target != SyncProvider.iCloud) {
      throw const SyncException('Could not fetch account');
    }
    DateTime? discoveredLastBackupAt;
    try {
      final files = await provider.listFiles(); // sorted desc, newest first
      if (files.isNotEmpty) {
        discoveredLastBackupAt = BackupFilename.parseTimestamp(
          files.first.name,
        );
      }
    } catch (e) {
      debugPrint(
        '[BackupNotifier._completeProviderHandshake] listFiles() error '
        '(best-effort): $e',
      );
      // best-effort: listing failure does not abort the handshake
    }
    await settingsRepo.updateBackupState(
      dropboxEmail: email,
      lastBackupAt: discoveredLastBackupAt,
    );
    // BUG-B04: clear the post-wipe suspended sentinel before invalidating.
    // Without this, a delete-all → reconnect sequence leaves backupSuspended=true,
    // which would make the Stato label show "non attivo" after reconnect even
    // when the user enters a passphrase.
    await settingsRepo.clearBackupSuspended();
  }

  /// Dedicated first-connect entry point (BUG-B06 restoration, FR-02/FR-03).
  ///
  /// Invoked ONLY by the empty-view CTA — never by [switchProvider], which
  /// must stay passphrase-free (FR-13/CC-1). Runs [_completeProviderHandshake]
  /// then performs the BUG-B06 stale-passphrase wipe as its terminal
  /// secure-storage op, strictly AFTER `clearBackupSuspended` (HC-2
  /// ordering), then invalidates self so [build] re-derives the connected
  /// state. Defined outside the [switchProvider]→[backupWithPassphrase]
  /// marker span (G-02/G-04).
  Future<void> firstConnect(SyncProvider target) async {
    // TASK-06 re-entrancy guard (FR-09): reject if ANY operation
    // (connect/disconnect/switch) is already in flight.
    if (_inFlightOperation != null) return;
    // FR-16: unconditionally clear the iCloud probe memo — a first-connect
    // attempt must never be answered from a stale cached probe result, even
    // when target already equals the current activeProvider.
    _invalidateICloudProbeMemo();
    _inFlightOperation = BackupOperation.connecting;
    state = const AsyncData(BackupRunning(BackupOperation.connecting));
    try {
      // BUG-01/02: hoist the SecureStorage handle, the resolved provider,
      // AND the settings repository via ref.read BEFORE the handshake's
      // first Drift write, so ref.read cannot fire after the notifier is
      // marked dirty by a stream re-emission (same structural hazard as
      // BUG-01 in switchProvider).
      final storage = ref.read(secureStorageProvider);
      final provider = ref.read(resolveBackupProvider(target));
      final settingsRepo = await ref.read(appSettingsRepositoryProvider.future);
      await _completeProviderHandshake(target, provider, settingsRepo);
      // BUG-B06: wipe any passphrase left in iOS Keychain / Android EncryptedSharedPrefs
      // from a prior install. KeychainAccessibility.first_unlock items survive app
      // uninstall on iOS; EncryptedSharedPreferences survive on Android API 23+.
      // Without this delete, build() reads the stale key and computes
      // passphraseSet=true → autoBackupActive=true before the user has set a passphrase.
      // Safe: disconnect() already deletes this key, so this is idempotent on a
      // fresh-install first-connect. backupSilent() guards on pass==null and will
      // not fire until the user enters a passphrase via backupWithPassphrase().
      await storage.delete(key: _passphraseKey);
      ref.invalidateSelf();
    } catch (e) {
      debugPrint('[BackupNotifier.firstConnect] ${e.runtimeType}: $e');
      state = AsyncData(
        BackupErrorState(
          e is MetraException
              ? e.message
              : 'Something went wrong. Please try again.',
        ),
      );
    } finally {
      _inFlightOperation = null;
    }
  }

  Future<void> disconnect() async {
    // TASK-06 re-entrancy guard (FR-09): reject if ANY operation
    // (connect/disconnect/switch) is already in flight.
    if (_inFlightOperation != null) return;
    // FR-16: clear the iCloud probe memo — otherwise a later reconnect to
    // iCloud (activeProvider flips back to iCloud) could observe a stale
    // memoized value instead of re-probing the container.
    _invalidateICloudProbeMemo();
    _inFlightOperation = BackupOperation.disconnecting;
    state = const AsyncData(BackupRunning(BackupOperation.disconnecting));
    try {
      final dropbox = ref.read(cloudBackupProvider);
      await dropbox.disconnect();
      final settingsRepo = await ref.read(appSettingsRepositoryProvider.future);
      // BUG-02 (defensive): capture secureStorageProvider BEFORE any Drift write
      // so ref.read cannot fire after the notifier is marked dirty by a
      // stream re-emission (same structural hazard as BUG-01 in switchProvider).
      final storage = ref.read(secureStorageProvider);
      await settingsRepo.updateBackupState(
        dropboxEmail: null,
        lastBackupAt: null,
      );
      // BUG-2: reset the active provider to the default (dropbox) so that
      // _isConnected evaluates the email-sentinel branch on the next build().
      // Without this, iCloud stays "connected" because _isConnected probes the
      // still-available container via authorize() — there is no disconnect
      // sentinel for iCloud.  Resetting to dropbox + null dropboxEmail gives
      // the null-email sentinel path, which correctly reports disconnected.
      // This is identical to the idiom used by DeleteAllData (C-07: no new
      // persisted field; harmless for Dropbox/Google Drive which are already
      // governed by the email sentinel).
      await settingsRepo.setActiveProvider(SyncProvider.dropbox);
      await storage.delete(key: _passphraseKey);
      ref.invalidateSelf();
    } catch (e) {
      state = AsyncData(
        BackupErrorState(
          e is MetraException
              ? e.message
              : 'Something went wrong. Please try again.',
        ),
      );
    } finally {
      _inFlightOperation = null;
    }
  }

  /// Switches the active backup provider from the current one to [target].
  ///
  /// Ordered contract (spec §5.1):
  ///   1. Re-entrancy guard: return immediately if any operation
  ///      (connect/disconnect/switch) is already in flight (TASK-06,
  ///      FR-09) — i.e. [_inFlightOperation] is non-null.
  ///   2. Platform guard: assert [target] is in [availableProviders].
  ///   3. Set state → [BackupRunning(BackupOperation.switching)].
  ///   4. Read the settings repository, old AND new provider (via
  ///      [resolveBackupProvider]) — all BEFORE any Drift mutation (BUG-01
  ///      ref-hoist — see step 8 note).
  ///   5. **Abort gate**: [old.disconnect()]; on throw → [BackupErrorState], return;
  ///      activeProvider unchanged, target never authorized (FR-11).
  ///   6. [setActiveProvider(target)] — the flip.
  ///   7. Clear identity: [updateBackupState(null, null)].
  ///   8. New provider and settings repository already resolved at step 4 —
  ///      MUST NOT be re-resolved/re-read here. [cloudBackupProvider] must
  ///      never be used (CC-2 stale-read — it still points to the old
  ///      provider until the Drift stream re-emits) — but re-reading even
  ///      [resolveBackupProvider] or [appSettingsRepositoryProvider] at this
  ///      point throws a Riverpod ref-after-dependency-changed assertion once
  ///      the steps 6–7 writes have re-emitted `appSettingsStreamProvider`
  ///      (BUG-01). Hoisting at step 4 sidesteps both hazards.
  ///   9–10. Authorize + currentEmail + best-effort listFiles + updateBackupState
  ///      + clearBackupSuspended — delegated to [_completeProviderHandshake]
  ///      (FR-01), the same helper [firstConnect] uses.
  ///  11. On post-flip failure ([_completeProviderHandshake] throws) → [BackupErrorState], return.
  ///      No rollback — activeProvider stays [target] (OQ-01, architect decision).
  ///      The next [build()] observes target with no email → [BackupNotConnected],
  ///      giving the user a clean retry surface.
  ///  12. [ref.invalidateSelf()].
  ///
  /// Security invariants (FR-13, CC-1):
  ///   - Never reads, writes, or deletes [kPassphraseKey].
  ///   - Never calls the notifier's own [firstConnect] / [disconnect] — both
  ///     delete the passphrase key.
  ///   - Never calls [old.deleteFile] — old .enc files are left intact.
  Future<void> switchProvider(SyncProvider target) async {
    // Step 1: re-entrancy guard (TASK-06, FR-09) — reject if ANY operation
    // (connect/disconnect/switch) is already in flight, not just a same-type
    // switch.
    if (_inFlightOperation != null) return;

    // FR-16: clear the iCloud probe memo — otherwise a later switch back to
    // iCloud (activeProvider flips back to iCloud) could observe a stale
    // memoized value instead of re-probing the container.
    _invalidateICloudProbeMemo();

    // Step 2: platform guard — iCloud is iOS-only (availableProviders enforces it).
    assert(availableProviders(defaultTargetPlatform).contains(target));

    // Step 3: signal switch in progress.
    state = const AsyncData(BackupRunning(BackupOperation.switching));

    // Steps 4–11 run under the mid-switch guard: the Drift writes at steps
    // 6–7 re-emit appSettingsStreamProvider and re-run build() while the
    // switch is still in flight; without the guard that rebuild derives
    // BackupNotConnected from the half-written settings and the connect view
    // flashes over the switching overlay.  Error paths return from inside the
    // try, so the finally clears the flag on every exit.
    _inFlightOperation = BackupOperation.switching;
    try {
      // Step 4: read BOTH the old and new providers BEFORE any Drift mutation.
      // BUG-01: resolving resolveBackupProvider(target) AFTER the steps 6–7
      // Drift writes throws a Riverpod assertion once appSettingsStreamProvider
      // re-emits and marks BackupNotifier dirty (regression-guarded by
      // backup_switch_flow_integration_test.dart I-08/I-09). Hoisting both
      // reads here is safe: resolveBackupProvider resolves by its 'id'
      // argument (not by reactive settings), so capturing newProvider before
      // the flip returns the same instance a post-flip read would have
      // returned — the CC-2 invariant is preserved.
      final settingsRepo = await ref.read(appSettingsRepositoryProvider.future);
      final settings = await settingsRepo.getOrCreate();
      final old = ref.read(resolveBackupProvider(settings.activeProvider));
      final newProvider = ref.read(resolveBackupProvider(target));

      // Step 5: abort gate — if disconnect throws, leave activeProvider unchanged.
      try {
        await old.disconnect();
      } catch (e) {
        debugPrint(
          '[BackupNotifier.switchProvider] abort gate — old.disconnect() '
          'failed: $e; aborting switch, activeProvider unchanged',
        );
        state = AsyncData(
          BackupErrorState(
            e is MetraException
                ? e.message
                : 'Something went wrong. Please try again.',
          ),
        );
        return;
      }

      // Step 6: flip — this is the point of no return (OQ-01).
      await settingsRepo.setActiveProvider(target);

      // Step 7: clear old identity fields.
      await settingsRepo.updateBackupState(
        dropboxEmail: null,
        lastBackupAt: null,
      );

      // Steps 8–11: post-flip connect sequence delegates to the same handshake
      // firstConnect uses (FR-01), fed with the provider hoisted at step 4
      // (BUG-01) — never touches the passphrase key (FR-13/G-02/G-04). Any
      // exception here does NOT roll back activeProvider (OQ-01 architect
      // decision) — the next build() will observe target with no email and
      // yield BackupNotConnected, giving the user a clean retry surface.
      try {
        await _completeProviderHandshake(target, newProvider, settingsRepo);
      } catch (e) {
        debugPrint(
          '[BackupNotifier.switchProvider] post-flip failure — $e; '
          'activeProvider stays ${target.name} (OQ-01, no rollback)',
        );
        state = AsyncData(
          BackupErrorState(
            e is MetraException
                ? e.message
                : 'Something went wrong. Please try again.',
          ),
        );
        return;
      }
    } finally {
      _inFlightOperation = null;
    }

    // Step 12: trigger build() with the new settings (the guard is already
    // cleared, so this rebuild derives the real post-switch state).
    ref.invalidateSelf();
  }

  Future<void> backupWithPassphrase(String passphrase) async {
    if (state.valueOrNull is BackupRunning) return;
    // HC-2: sentinel read PRECEDES any secure-storage operation.
    // If backupSuspended = true (set by DeleteAllData on wipe), skip silently
    // and log a diagnostic entry — no passphrase is read or written.
    final settingsForSentinel = await ref.read(
      appSettingsRepositoryProvider.future,
    );
    final sentinelSettings = await settingsForSentinel.getOrCreate();
    if (sentinelSettings.backupSuspended) {
      // BUG-B02: manual backup IS the resume path. Clear sentinel BEFORE
      // any secure-storage interaction (HC-2 ordering).
      await settingsForSentinel.clearBackupSuspended();
      // No SyncLog skip entry — the user-driven tap is succeeding, not skipping.
      // backupSilent() retains the skip-log path (different semantics:
      // silent cold-start vs. user-driven tap).
    }
    final storage = ref.read(secureStorageProvider);
    // Read the old passphrase so it can be restored if the upload fails.
    // The invariant: after a failed backup the cloud blob is still encrypted
    // with the old key, so secure storage must keep the old passphrase.
    final oldPassphrase = await storage.read(key: _passphraseKey);

    // Write the new passphrase so the orchestrator picks it up during backup.
    await storage.write(key: _passphraseKey, value: passphrase);

    final succeeded = await _runBackup();

    // FR-20 (L1/FEAT-BUG-003 TOCTOU fix): key the rollback decision off the
    // bool _runBackup() returned, not a post-hoc `state.valueOrNull is
    // BackupErrorState` inspection — the latter races against any concurrent
    // rebuild that mutates `state` between the call above returning and this
    // check running (e.g. a concurrent appSettingsStreamProvider emission).
    if (!succeeded) {
      if (oldPassphrase != null) {
        await storage.write(key: _passphraseKey, value: oldPassphrase);
      } else {
        await storage.delete(key: _passphraseKey);
      }
    }
  }

  Future<void> backupSilent() async {
    // FR-21 (L2/FEAT-BUG-004 cold-start fix): resolve build() BEFORE
    // evaluating the guards below. Without this, a cold-start invocation
    // racing ahead of the first build() (state still AsyncLoading,
    // valueOrNull == null) sees neither guard match — null is not
    // BackupRunning, null is not BackupNotConnected — so both guards are
    // vacuous and execution falls through into the write-recency check
    // using data read directly off the repository, bypassing whatever
    // build() would have derived. Concretely this let backupSilent() run
    // (and, per FR-06, misattribute a backupSkipped entry to the dropbox
    // sentinel) right after an iCloud disconnect, before the very first
    // build() had resolved BackupNotConnected. Awaiting `future` blocks
    // until build() completes, making the guards non-vacuous.
    await future;
    if (state.valueOrNull is BackupRunning) return;
    // Not configured: no account is connected, so there is nowhere to back up.
    // Without this guard, a passphrase left in secure storage after Dropbox
    // disconnect would cause _runBackup to fire and fail silently on every
    // cold-start (BUG-D04 follow-up / FR-14).
    if (state.valueOrNull is BackupNotConnected) return;

    // FR-11/FR-12/FR-13: skip cold-start backup when no new data has been
    // written since the last backup. Manual backup (backupWithPassphrase)
    // bypasses this guard intentionally.
    final settingsRepo = await ref.read(appSettingsRepositoryProvider.future);
    final settings = await settingsRepo.getOrCreate();

    // HC-2 sentinel: guard 3 — inserted between BackupNotConnected (guard 2)
    // and the write-recency check (guard 4). Reuses the settings read above.
    if (settings.backupSuspended) {
      final syncLogRepo = await ref.read(syncLogRepositoryProvider.future);
      await syncLogRepo.append(
        SyncLogEntity(
          timestamp: DateTime.now().toUtc(),
          // FR-18: use the active-provider id from settings, not a hardcoded
          // SyncProvider.dropbox literal — preserves correctness when the
          // active provider changes in future milestones.
          provider: settings.activeProvider,
          operation: SyncOperation.backupSkipped,
          success: true,
          errorMessage: 'skipped: backupSuspended=true',
        ),
      );
      return;
    }

    final lastBackupAt = settings.lastBackupAt;
    final lastWriteAt = settings.lastLogOrSymptomWriteAt;

    // FR-12: first-ever backup always proceeds (no prior backup to compare against).
    if (lastBackupAt != null) {
      // FR-13: no log/symptom ever written → nothing to back up.
      // FR-11: write timestamp not after last backup → nothing new since last upload.
      if (lastWriteAt == null || !lastWriteAt.isAfter(lastBackupAt)) {
        // FR-16: append a diagnostic log entry so the user can inspect why
        // the backup was skipped via the sync log view.
        final syncLogRepo = await ref.read(syncLogRepositoryProvider.future);
        await syncLogRepo.append(
          SyncLogEntity(
            timestamp: DateTime.now().toUtc(),
            // FR-18: use the active-provider id from settings, not a hardcoded
            // SyncProvider.dropbox literal — preserves correctness when the
            // active provider changes in future milestones.
            provider: settings.activeProvider,
            operation: SyncOperation.backupSkipped,
            success: true,
            errorMessage:
                'skipped: lastWriteAt=$lastWriteAt lastBackupAt=$lastBackupAt',
          ),
        );
        return;
      }
    }
    // Cases: (c) first-ever backup, or (d) new data exists → proceed.

    final pass = await ref
        .read(secureStorageProvider)
        .read(key: _passphraseKey);
    if (pass == null) return;
    await _runBackup();
  }

  /// Manual backup triggered from the UI (FR-16/FR-19/FR-20).
  ///
  /// Differences from [backupSilent]:
  /// - Bypasses the write-recency guard — runs even when nothing is new.
  /// - Never writes to secure storage (FR-19 invariant).
  ///
  /// Guard order:
  ///   1. BackupRunning  → no-op (re-entrancy guard)
  ///   2. BackupNotConnected → no-op (no account)
  ///   3. backupSuspended → log skip entry, return
  ///   4. null passphrase → silent return
  ///   5. → _runBackup()
  Future<void> backupNow() async {
    // FR-21 (L2/FEAT-BUG-004 cold-start fix): resolve build() BEFORE
    // evaluating the guards below — same rationale as backupSilent() above.
    await future;

    // Guard 1: already running.
    if (state.valueOrNull is BackupRunning) return;

    // Guard 2: not connected.
    if (state.valueOrNull is BackupNotConnected) return;

    // Guard 3: backup suspended (e.g. post-wipe sentinel).
    // BUG-B02: manual tap IS the resume path — clear the sentinel and proceed.
    // HC-2 ordering: clearBackupSuspended() runs BEFORE any secureStorage read.
    final settingsRepo = await ref.read(appSettingsRepositoryProvider.future);
    final settings = await settingsRepo.getOrCreate();
    if (settings.backupSuspended) {
      await settingsRepo.clearBackupSuspended();
      // No SyncLog skip entry — the user-driven tap is succeeding, not skipping.
      // backupSilent() retains the skip-log path (different semantics:
      // silent cold-start vs. user-driven tap).
    }

    // Guard 4: no passphrase — nothing to encrypt with.
    final pass = await ref
        .read(secureStorageProvider)
        .read(key: _passphraseKey);
    if (pass == null) return;

    // Guard 5 bypassed intentionally: write-recency check is NOT applied here.
    await _runBackup();
  }

  /// Runs the backup orchestrator and returns whether it succeeded.
  ///
  /// Returns `true` on the [Ok] branch, `false` on the [Err] branch (state is
  /// still set to [BackupErrorState] on `Err`, unchanged) or if the
  /// orchestrator throws.
  ///
  /// FR-20 (L1/FEAT-BUG-003 TOCTOU fix): callers that need to know whether
  /// the backup succeeded — [backupWithPassphrase]'s rollback decision — MUST
  /// use this returned bool, never `state.valueOrNull is BackupErrorState`.
  /// Inspecting `state` after the fact is racy: a concurrent rebuild (e.g.
  /// triggered by an unrelated `appSettingsStreamProvider` emission) can
  /// mutate `state` between this method returning and the caller's
  /// inspection, making a genuine success look like a failure (or vice
  /// versa). The returned bool is captured at the one point that is
  /// guaranteed to reflect this specific call's outcome.
  ///
  /// Stays private — [_runBackup] must have zero call sites outside this
  /// file (G3 source-grep guard).
  Future<bool> _runBackup() async {
    state = const AsyncData(BackupRunning(BackupOperation.backingUp));
    try {
      final uc = await ref.read(backupDataProvider.future);
      final result = await uc();
      switch (result) {
        case Ok():
          ref.invalidateSelf();
          return true;
        case Err(:final error):
          state = AsyncData(BackupErrorState(error.message));
          // FR-23: a backup failure is the only remaining signal (once the
          // probe is memoized) that the iCloud container may have become
          // unreachable mid-session — invalidate so the next _isConnected
          // call re-probes instead of keeping a stale `true`.
          _invalidateICloudProbeMemo();
          return false;
      }
    } catch (e) {
      state = AsyncData(
        BackupErrorState(
          e is MetraException
              ? e.message
              : 'Something went wrong. Please try again.',
        ),
      );
      return false;
    }
  }

  /// Returns the number of daily-log rows restored, or null on failure.
  /// On null, the notifier has already set [BackupErrorState] — the caller
  /// uses null as the "do not show success snackbar" signal.
  Future<int?> restore({String? filename}) async {
    state = const AsyncData(BackupRunning(BackupOperation.restoring));
    try {
      final uc = await ref.read(restoreDataProvider.future);
      final result = await uc(filename: filename);
      switch (result) {
        case Ok(:final value):
          ref.invalidateSelf();
          // BUG-R1: invalidate cached cycle-day providers so the UI reflects
          // the restored data. Do NOT invalidate cyclePredictionProvider —
          // the Drift stream propagates that change automatically; manual
          // invalidation would reset the badge to AsyncLoading (C-04).
          ref.invalidate(currentCycleDayProvider);
          ref.invalidate(cycleDayForDateProvider);
          return value; // propagate count to caller
        case Err(:final error):
          state = AsyncData(BackupErrorState(error.message));
          // FR-23: same rationale as _runBackup's Err branch — a restore
          // failure invalidates the iCloud probe memo.
          _invalidateICloudProbeMemo();
          return null;
      }
    } catch (e) {
      state = AsyncData(
        BackupErrorState(
          e is MetraException
              ? e.message
              : 'Something went wrong. Please try again.',
        ),
      );
      return null;
    }
  }

  /// Returns the count from [restore] (null on failure or rollback path).
  Future<int?> restoreWithPassphrase(
    String passphrase, {
    String? filename,
  }) async {
    final storage = ref.read(secureStorageProvider);
    // Read the old passphrase so it can be restored if the download or
    // decryption fails. Invariant: a failed restore must not overwrite
    // a previously-working passphrase in secure storage.
    final oldPassphrase = await storage.read(key: _passphraseKey);

    // Write the new passphrase so the orchestrator picks it up during restore.
    await storage.write(key: _passphraseKey, value: passphrase);

    final count = await restore(filename: filename);

    // If the restore failed, restore() sets an error state but does not throw.
    // Detect failure via state and roll back the secure-storage value.
    final currentState = state.valueOrNull;
    if (currentState is BackupErrorState) {
      if (oldPassphrase != null) {
        await storage.write(key: _passphraseKey, value: oldPassphrase);
      } else {
        await storage.delete(key: _passphraseKey);
      }
    }
    return count;
  }
}

final backupNotifierProvider =
    AsyncNotifierProvider<BackupNotifier, BackupState>(BackupNotifier.new);
