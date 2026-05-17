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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/metra_theme.dart';
import 'domain/entities/app_settings_data.dart';
import 'domain/entities/cycle_prediction.dart';
import 'domain/services/notification_service.dart';
import 'features/backup/state/backup_notifier.dart';
import 'features/calendar/state/prediction_controller.dart';
import 'features/settings/state/settings_notifier.dart';
import 'l10n/app_localizations.dart';
import 'providers/encryption_provider.dart';
import 'providers/notification_error_reporter_provider.dart';
import 'providers/use_case_providers.dart';
import 'router/app_router.dart';

/// Top-level [GlobalKey] for the [ScaffoldMessenger] mounted by [MetraApp].
///
/// Exposed at file scope so async [ref.listen] callbacks in [_MetraInnerState]
/// can surface snackbars without a [BuildContext] (FR-07, BUG-M2). The key is
/// passed to [MaterialApp.router] via [scaffoldMessengerKey:] and consumed by
/// [notificationErrorReporterProvider] in TASK-06.
///
/// **GlobalKey justification**: a single app-wide [ScaffoldMessengerState] is
/// needed so that error reporters wired in Wave-2 listeners can call
/// [ScaffoldMessengerState.showSnackBar] safely after async gaps — i.e. when
/// the original [BuildContext] may no longer be valid. One key instance for
/// the lifetime of the app; no rebuild cost.
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Root widget — owns [ProviderScope] and accepts overrides for tests.
class MetraApp extends StatelessWidget {
  const MetraApp({
    super.key,
    this.overrides = const [],
  });

  final List<Override> overrides;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: overrides,
      child: const _MetraInner(),
    );
  }
}

class _MetraInner extends ConsumerStatefulWidget {
  const _MetraInner();

  @override
  ConsumerState<_MetraInner> createState() => _MetraInnerState();
}

class _MetraInnerState extends ConsumerState<_MetraInner> {
  @override
  void initState() {
    super.initState();
    // Best-effort: initialize notification channels. Failures are non-fatal
    // (e.g. test environments without a platform channel).
    // FR-07 / BUG-B03: chain the cold-start POST_NOTIFICATIONS re-check
    // immediately after initialize() completes so we verify OS permission
    // reality before the first scheduling call fires.
    ref
        .read(notificationServiceProvider)
        .initialize()
        .then((_) => _verifyNotificationPermissionOnColdStart())
        .catchError((Object _) {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoSyncIfConfigured();
    });
  }

  // FR-07 / BUG-B03 / Fix #2: verify OS POST_NOTIFICATIONS permission at cold-start.
  //
  // When the user's persisted notificationsEnabled is true but the OS permission
  // has been revoked since the last grant (e.g. the user manually revoked it in
  // Settings), we must flip the persisted flag to false so the UI and scheduling
  // logic reflect reality. Without this check a cold-start with a revoked
  // permission silently fires scheduler.execute() and schedules a notification
  // that the OS will silently drop, and the user never sees the discrepancy.
  //
  // Fix #2: uses hasNotificationPermission() (read-only check via
  // areNotificationsEnabled()) instead of requestPermission(), which would
  // re-show the system dialog on grant-then-revoke after every cold-start —
  // violating Métra's "no nag" voice and FR-07's explicit "no re-prompt"
  // requirement.
  Future<void> _verifyNotificationPermissionOnColdStart() async {
    final settings = await ref.read(settingsNotifierProvider.future);
    if (!settings.notificationsEnabled) return;
    // FR-07 / Fix #2: read-only check via checkSelfPermission-equivalent;
    // never re-prompt the user at cold-start (Métra "no nag" voice).
    final granted =
        await ref.read(notificationServiceProvider).hasNotificationPermission();
    if (!granted) {
      // OS permission revoked since last grant — revert persisted flag so
      // displayed state matches reality (no notification will fire while denied).
      await ref
          .read(settingsNotifierProvider.notifier)
          .save(settings.copyWith(notificationsEnabled: false));
    }
  }

  // FR-15 / BUG-D04: route auto-sync through BackupNotifier.backupSilent()
  // so ref.invalidateSelf() fires inside _runBackup and any open BackupScreen
  // re-renders the updated lastBackupAt without navigation.
  //
  // FR-18 / BUG-D06: catch(e) now emits a structured debugPrint so
  // real-device regressions are diagnosable from device logs.
  Future<void> _autoSyncIfConfigured() async {
    try {
      final storage = ref.read(secureStorageProvider);
      final pass = await storage.read(key: 'metra_backup_passphrase_v1');
      if (pass == null) return; // first backup not done yet; no-op
      await ref.read(backupNotifierProvider.notifier).backupSilent();
    } catch (e) {
      debugPrint('[autoSync] ${e.runtimeType}: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsNotifierProvider).valueOrNull;

    final themeMode = switch (settings?.darkMode) {
      null => ThemeMode.system,
      false => ThemeMode.light,
      true => ThemeMode.dark,
    };

    final locale = (settings == null || settings.languageCode.isEmpty)
        ? null
        : Locale(settings.languageCode);

    // Reschedule notification whenever the predicted next cycle date changes.
    //
    // FR-05 / BUG-B02: guard scheduler.execute() with prev is AsyncData so
    // the cold-start AsyncLoading → AsyncData transition does NOT invoke
    // scheduling. Only legitimate data-update (AsyncData → AsyncData)
    // transitions trigger rescheduling, preventing alarm-quota exhaustion.
    ref.listen<AsyncValue<CyclePrediction?>>(
      cyclePredictionProvider,
      (prev, next) async {
        if (prev is! AsyncData<CyclePrediction?>) return;
        if (next is! AsyncData<CyclePrediction?>) return;
        final prediction = next.valueOrNull;
        final currentSettings = ref.read(settingsNotifierProvider).valueOrNull;
        if (currentSettings == null) return;
        final l10n = await AppLocalizations.delegate
            .load(Locale(_effectiveLangCode(currentSettings.languageCode)));
        final scheduler =
            await ref.read(schedulePredictionNotificationProvider.future);
        try {
          // FR-09: switch on the structured result. Failure path is a silent
          // drop — no toggle revert, no snackbar. cancelPredictionNotifications()
          // inside execute() may still throw PlatformException; the outer
          // on PlatformException handles that path (FR-10).
          final result = await scheduler.execute(
            prediction: prediction,
            settings: currentSettings,
            title: l10n.notification_prediction_title,
            body: prediction != null
                ? l10n.notification_prediction_body(
                    currentSettings.notificationDaysBefore,
                  )
                : '',
          );
          switch (result) {
            case NotificationScheduleSuccess():
              // No side effect — prediction successfully scheduled.
              break;
            case NotificationScheduleFailure(:final error):
              // FR-09: silent drop — no revert, no snackbar.
              debugPrint(
                '[predictionListener] schedule failure (silent drop): $error',
              );
          }
        } on PlatformException catch (e) {
          // FR-10: cancelPredictionNotifications() inside execute() may throw
          // PlatformException (SCHEDULE_EXACT_ALARM revoked or cancel error).
          // The prediction listener never shows UI errors for this path.
          debugPrint('[predictionListener] PlatformException (cancel path): $e');
        }
      },
    );

    // Reschedule notification immediately when the user changes settings
    // (toggle notificationsEnabled or adjust notificationDaysBefore).
    //
    // FR-06 / BUG-B02: guard scheduler.execute() with prev is AsyncData so
    // the cold-start AsyncLoading → AsyncData transition does NOT invoke
    // scheduling. Only legitimate user-driven (AsyncData → AsyncData)
    // transitions trigger rescheduling.
    ref.listen<AsyncValue<AppSettingsData>>(
      settingsNotifierProvider,
      (prev, next) async {
        final currentSettings = next.valueOrNull;
        if (currentSettings == null) return;

        // Deduplicate: SettingsNotifier.save() updates state = AsyncData(s)
        // immediately, then the Drift stream rebuild fires the notifier again
        // with the identical value — causing a second call to execute() per
        // save. AppSettingsData.== is structural (all fields compared), so
        // this guard collapses the double-fire into a single scheduling call.
        if (prev is AsyncData<AppSettingsData> &&
            prev.requireValue == currentSettings) {
          return;
        }

        // BUG-002 fix: only request OS permission when the user explicitly
        // enables notifications (AsyncData → AsyncData transition). The
        // AsyncLoading → AsyncData cold-start transition must NOT trigger
        // requestPermission(); the previous state is not a user action.
        // Without this guard, a cold start with notificationsEnabled: true
        // and OS permission revoked would silently write notificationsEnabled:
        // false to the DB, destroying the user's persisted preference (FR-04,
        // FR-05, EC-05).
        if (prev is AsyncData<AppSettingsData>) {
          final wasEnabled = prev.value.notificationsEnabled;
          if (currentSettings.notificationsEnabled && !wasEnabled) {
            final granted =
                await ref.read(notificationServiceProvider).requestPermission();
            if (!granted) {
              // User denied the OS dialog — revert the toggle so the displayed
              // state matches reality (no notification will fire while denied).
              await ref.read(settingsNotifierProvider.notifier).save(
                    currentSettings.copyWith(notificationsEnabled: false),
                  );
              return;
            }
          }
        }

        // FR-06 / BUG-B02: skip scheduling on cold-start transition.
        // The _verifyNotificationPermissionOnColdStart() method handles
        // the initial permission check independently of this listener.
        if (prev is! AsyncData<AppSettingsData>) return;

        final prediction = ref.read(cyclePredictionProvider).valueOrNull;
        final l10n = await AppLocalizations.delegate
            .load(Locale(_effectiveLangCode(currentSettings.languageCode)));
        // FR-08: capture the localised failure message before await so the
        // locale is pinned to the user's current settings at scheduling time.
        final failureMessage = l10n.notificationScheduleFailedMessage;
        final scheduler =
            await ref.read(schedulePredictionNotificationProvider.future);
        try {
          // FR-08: switch on the structured result. On failure, revert the
          // toggle and surface a localised snackbar. cancelPredictionNotifications()
          // inside execute() may still throw PlatformException; the outer
          // on PlatformException handles that path (FR-10).
          final result = await scheduler.execute(
            prediction: prediction,
            settings: currentSettings,
            title: l10n.notification_prediction_title,
            body: prediction != null
                ? l10n.notification_prediction_body(
                    currentSettings.notificationDaysBefore,
                  )
                : '',
            // skipIfPast: true — settings change only: if the computed
            // notification time is already in the past (including same-day-past)
            // skip silently. This prevents the service's shouldShowImmediately
            // path from firing a spurious notification when the user adjusts
            // advance days or notification time in Settings.
            skipIfPast: true,
          );
          switch (result) {
            case NotificationScheduleSuccess():
              // No side effect — notification successfully scheduled.
              break;
            case NotificationScheduleFailure():
              // FR-08(a): revert the toggle so displayed state matches reality.
              await ref.read(settingsNotifierProvider.notifier).save(
                    currentSettings.copyWith(notificationsEnabled: false),
                  );
              // FR-08(b): surface a localised error snackbar via the global key.
              ref
                  .read(notificationErrorReporterProvider)
                  .report(failureMessage);
          }
        } on PlatformException catch (e) {
          // FR-10: cancelPredictionNotifications() inside execute() may throw
          // PlatformException (SCHEDULE_EXACT_ALARM revoked or cancel error).
          // The schedule path no longer throws after FR-05; this catch is live
          // only for the cancel-throw path.
          debugPrint('[settingsListener] PlatformException (cancel path): $e');
        }
      },
    );

    return MaterialApp.router(
      title: 'Mētra',
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: MetraTheme.light(),
      darkTheme: MetraTheme.dark(),
      themeMode: themeMode,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: ref.watch(appRouterProvider),
      debugShowCheckedModeBanner: false,
    );
  }

  /// Resolves an empty [stored] code (= "follow system") to an actual
  /// language code supported by the app.
  static String _effectiveLangCode(String stored) {
    if (stored.isNotEmpty) return stored;
    final sys = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return AppLocalizations.supportedLocales.any((l) => l.languageCode == sys)
        ? sys
        : 'it';
  }
}
