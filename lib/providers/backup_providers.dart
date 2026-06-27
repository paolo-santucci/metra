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

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/backup/backup_file_entry.dart';
import '../data/services/backup/backup_service.dart';
import '../data/services/backup/cloud_backup_provider.dart';
import '../data/services/backup/dropbox_provider.dart';
import '../data/services/backup/google_drive_provider.dart';
import '../data/services/backup/icloud_provider.dart';
import '../data/services/backup/production_icloud_gateway.dart';
import '../data/services/backup/sync_orchestrator.dart';
import '../domain/entities/sync_log_entity.dart';
import '../domain/use_cases/backup_data.dart';
import '../domain/use_cases/restore_data.dart';
import 'encryption_provider.dart';
import 'repository_providers.dart';
import 'use_case_providers.dart';

const _dropboxAppKey = String.fromEnvironment('DROPBOX_APP_KEY');
const _googleOauthClientId = String.fromEnvironment('GOOGLE_OAUTH_CLIENT_ID');

final dropboxProviderProvider = Provider<DropboxProvider>((ref) {
  return DropboxProvider(
    appKey: _dropboxAppKey,
    storage: ref.watch(secureStorageProvider),
  );
});

final googleDriveProviderProvider = Provider<GoogleDriveProvider>(
  (ref) => GoogleDriveProvider(
    clientId: _googleOauthClientId,
    storage: ref.watch(secureStorageProvider),
  ),
);

/// Resolves the iCloud backup provider backed by [ProductionIcloudGateway].
///
/// iOS/iPadOS only — no OAuth, no token keys. Mirroring the M2
/// [googleDriveProviderProvider] factory shape (FR-12). Lazy: neither
/// [IcloudProvider] nor [ProductionIcloudGateway] makes a native call until
/// a method is invoked (FR-14).
final iCloudProviderProvider = Provider<IcloudProvider>(
  (ref) => IcloudProvider(gateway: ProductionIcloudGateway()),
);

/// Returns the list of backup providers available on [platform].
///
/// Single source of both the Android-only-Google-Drive rule and the
/// iOS-only-iCloud rule (FR-02, CC-3.1).
/// Pure and synchronous — callers pass [defaultTargetPlatform]; the rules
/// live here exactly once, consumed by the picker UI.
///
/// Per-platform matrix:
/// - Android: `[dropbox, googleDrive]`
/// - iOS:     `[dropbox, iCloud]` (iCloud last; Google Drive is Android-only)
/// - Other (linux, windows — non-shipping, defensive): `[dropbox]`
///
/// Note: [resolveBackupProvider]'s `googleDrive` arm is intentionally
/// unguarded (asymmetric with the iCloud arm by design — user decision
/// 2026-06-27). This function is the only picker-availability guard for
/// Google Drive; [resolveBackupProvider] is not.
List<SyncProvider> availableProviders(TargetPlatform platform) {
  return [
    SyncProvider.dropbox,
    if (platform == TargetPlatform.android) SyncProvider.googleDrive,
    if (platform == TargetPlatform.iOS) SyncProvider.iCloud,
  ];
}

/// Synchronous arbitrary-provider resolver (CC-3.2 / FR-03 / NFR-03).
///
/// Resolves ANY chosen [SyncProvider] — including a not-yet-active one —
/// sharing the single iCloud platform guard. Must NOT be converted to a
/// [FutureProvider] (13+ `overrideWithValue` sites; cascade of `await`
/// through [BackupNotifier]).
///
/// Resolution rules:
/// - dropbox      → [dropboxProviderProvider]
/// - googleDrive  → [googleDriveProviderProvider]
/// - iCloud       → [iCloudProviderProvider] iff `defaultTargetPlatform == iOS`,
///                  else [dropboxProviderProvider] (off-iOS fallback, never
///                  throws — EC-09). Defense-in-depth only: [availableProviders]
///                  excludes iCloud on non-iOS, so the picker never returns it.
final resolveBackupProvider =
    Provider.family<CloudBackupProvider, SyncProvider>((ref, id) {
  switch (id) {
    case SyncProvider.dropbox:
      return ref.watch(dropboxProviderProvider);
    case SyncProvider.googleDrive:
      return ref.watch(googleDriveProviderProvider);
    case SyncProvider.iCloud:
      // Platform-guarded: iCloud is iOS/iPadOS only. Off-iOS (Android, Linux
      // CI runner) falls back to Dropbox without throwing (EC-09, FR-13).
      // Guard uses [defaultTargetPlatform] (never dart:io Platform, which is
      // always false on the Linux CI runner).
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        return ref.watch(iCloudProviderProvider);
      }
      return ref.watch(dropboxProviderProvider);
  }
});

/// Resolves the active backup provider implementation from the persisted
/// [AppSettingsData.activeProvider] setting.
///
/// Stays a synchronous [Provider] — converting to [FutureProvider] would break
/// 13+ [overrideWithValue] test sites and cascade [await] through
/// [backupFileListProvider] and [BackupNotifier] (NFR-03).
///
/// Redefined (M4) to delegate to [resolveBackupProvider] so the iCloud guard
/// lives in exactly one place. Behaviour for existing callers is identical.
///
/// Resolution rules:
/// - Reads [appSettingsStreamProvider].valueOrNull?.activeProvider synchronously.
/// - Defaults to [SyncProvider.dropbox] during the settings-loading frame
///   (when the stream has not yet emitted — EC-01).
final cloudBackupProvider = Provider<CloudBackupProvider>((ref) {
  // Read activeProvider synchronously; default to dropbox during the
  // settings-loading frame (stream has not yet emitted — EC-01).
  final activeProvider =
      ref.watch(appSettingsStreamProvider).valueOrNull?.activeProvider ??
          SyncProvider.dropbox;
  return ref.watch(resolveBackupProvider(activeProvider));
});

final backupServiceProvider = FutureProvider<BackupService>((ref) async {
  final logRepo = await ref.watch(dailyLogRepositoryProvider.future);
  return BackupService(logRepo);
});

final syncOrchestratorProvider = FutureProvider<SyncOrchestrator>((ref) async {
  final backupSvc = await ref.watch(backupServiceProvider.future);
  final settingsRepo = await ref.watch(appSettingsRepositoryProvider.future);
  final logRepo = await ref.watch(dailyLogRepositoryProvider.future);
  final syncLogRepo = await ref.watch(syncLogRepositoryProvider.future);
  final recomputeUseCase =
      await ref.watch(recomputeCycleEntriesProvider.future);
  return SyncOrchestrator(
    backupService: backupSvc,
    encryptionService: ref.watch(encryptionServiceProvider),
    provider: ref.watch(cloudBackupProvider),
    settingsRepo: settingsRepo,
    syncLogRepo: syncLogRepo,
    logRepo: logRepo,
    // RecomputeCycleEntries is a callable class; the tear-off satisfies
    // RecomputeFn = Future<dynamic> Function() because Result<...> <: dynamic.
    recompute: recomputeUseCase.call,
    secureStorage: ref.watch(secureStorageProvider),
  );
});

final backupDataProvider = FutureProvider<BackupData>((ref) async {
  final orch = await ref.watch(syncOrchestratorProvider.future);
  return BackupData(orch);
});

final restoreDataProvider = FutureProvider<RestoreData>((ref) async {
  final orch = await ref.watch(syncOrchestratorProvider.future);
  return RestoreData(orch);
});

final backupFileListProvider =
    FutureProvider.autoDispose<List<BackupFileEntry>>((ref) async {
  return ref.watch(cloudBackupProvider).listFiles();
});
