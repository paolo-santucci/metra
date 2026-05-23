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

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/metra_colors.dart';
import '../../core/theme/metra_spacing.dart';
import '../../core/theme/metra_typography.dart';
import '../../core/util/nullable.dart';
import '../../domain/entities/app_settings_data.dart';
import '../../domain/entities/first_day_of_week_setting.dart';
import '../../domain/services/csv_codec.dart';
import '../../domain/use_cases/import_daily_logs.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/app_info_provider.dart';
import '../../providers/use_case_providers.dart';
import '../../core/widgets/settings/cupertino_picker_scaffold.dart';
import '../../core/widgets/settings/metra_toggle.dart';
import '../../core/widgets/settings/settings_card.dart';
import '../../core/widgets/settings/settings_divider.dart';
import '../../core/widgets/settings/settings_label.dart';
import '../../core/widgets/settings/settings_row.dart';
import '../backup/state/backup_notifier.dart';
import '../backup/state/backup_state.dart';
import 'state/settings_notifier.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = MetraColors.of(context);
    final bgPrimary = colors.bgPrimary;
    final textPrimary = colors.textPrimary;
    final textSecondary = colors.textSecondary;
    final settings = ref.watch(settingsNotifierProvider).valueOrNull ??
        AppSettingsData.defaults();
    // Backup-row value is state-aware (Design Bible § 18.6): only
    // BackupConnected resolves to "Configurato"; every other state
    // (loading, NotConnected, Running, ErrorState) falls back to
    // "Non configurato" — full backup state lives on the Backup screen.
    final backupValueText =
        ref.watch(backupNotifierProvider).valueOrNull is BackupConnected
            ? l10n.settings_backup_configured
            : l10n.settings_backup_not_configured;

    return Scaffold(
      backgroundColor: bgPrimary,
      body: SafeArea(
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MetraSpacing.s6,
                MetraSpacing.s6,
                MetraSpacing.s6,
                MetraSpacing.s2,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  l10n.settings_screen_title,
                  style:
                      MetraTypography.screenTitle.copyWith(color: textPrimary),
                ),
              ),
            ),

            // ── Preferenze ────────────────────────────────────────────
            SettingsLabel(l10n.settings_section_preferences, first: true),
            SettingsCard(
              children: [
                SettingsRow.nav(
                  label: l10n.settings_language_label,
                  semanticsLabel:
                      '${l10n.settings_language_label}: ${_languageName(l10n, settings.languageCode)}',
                  valueText: _languageName(l10n, settings.languageCode),
                  onTap: () =>
                      _showLanguagePicker(context, ref, settings, l10n),
                ),
                const SettingsDivider(),
                SettingsRow.nav(
                  label: l10n.settings_theme_label,
                  semanticsLabel:
                      '${l10n.settings_theme_label}: ${_themeName(l10n, settings.darkMode)}',
                  valueText: _themeName(l10n, settings.darkMode),
                  onTap: () => _showThemePicker(context, ref, settings, l10n),
                ),
                const SettingsDivider(),
                SettingsRow.nav(
                  label: l10n.settings_first_day_of_week_label,
                  semanticsLabel:
                      '${l10n.settings_first_day_of_week_label}: ${_firstDayName(l10n, settings.firstDayOfWeek)}',
                  valueText: _firstDayName(l10n, settings.firstDayOfWeek),
                  onTap: () =>
                      _showFirstDayOfWeekPicker(context, ref, settings, l10n),
                ),
              ],
            ),

            // ── Notifiche ─────────────────────────────────────────────
            SettingsLabel(l10n.settings_section_notifications),
            SettingsCard(
              children: [
                SettingsRow.toggle(
                  label: l10n.settings_notifications_label,
                  semanticsLabel:
                      '${l10n.settings_notifications_label}: ${settings.notificationsEnabled ? l10n.settings_notifications_on : l10n.settings_notifications_off}',
                  toggle: MetraToggle(
                    value: settings.notificationsEnabled,
                    onChanged: (v) =>
                        _save(ref, settings.copyWith(notificationsEnabled: v)),
                  ),
                ),
                const SettingsDivider(),
                Opacity(
                  opacity: settings.notificationsEnabled ? 1.0 : 0.38,
                  child: IgnorePointer(
                    ignoring: !settings.notificationsEnabled,
                    child: SettingsRow.nav(
                      label: l10n.settings_advance_label,
                      semanticsLabel:
                          '${l10n.settings_advance_label}: ${l10n.settings_advance_value(settings.notificationDaysBefore)}',
                      valueText: l10n.settings_advance_value(
                        settings.notificationDaysBefore,
                      ),
                      onTap: () => _showCupertinoDaysPicker(
                        context,
                        ref,
                        settings,
                        l10n,
                      ),
                    ),
                  ),
                ),
                const SettingsDivider(),
                Builder(
                  builder: (rowCtx) {
                    final timeValue =
                        MaterialLocalizations.of(rowCtx).formatTimeOfDay(
                      TimeOfDay(
                        hour: settings.notificationTimeMinutes ~/ 60,
                        minute: settings.notificationTimeMinutes % 60,
                      ),
                    );
                    final label = l10n.settings_notification_time_label;
                    return Opacity(
                      opacity: settings.notificationsEnabled ? 1.0 : 0.38,
                      child: IgnorePointer(
                        ignoring: !settings.notificationsEnabled,
                        child: SettingsRow.nav(
                          label: label,
                          semanticsLabel: '$label: $timeValue',
                          valueText: timeValue,
                          onTap: () =>
                              _showCupertinoTimePicker(rowCtx, ref, settings),
                        ),
                      ),
                    );
                  },
                ),
                // "Pianificazione in background" (battery-opt row) was removed.
                // The underlying NotificationService methods are kept for potential
                // re-addition. Users on OEM devices that suppress inexact alarms
                // (Samsung / Xiaomi / OnePlus) must whitelist Métra manually:
                // Settings → Apps → Métra → Battery → Unrestricted.
              ],
            ),

            // ── Registro ──────────────────────────────────────────────
            SettingsLabel(l10n.settings_section_log),
            SettingsCard(
              children: [
                SettingsRow.toggle(
                  label: l10n.settings_pain_label,
                  toggle: MetraToggle(
                    value: settings.painEnabled,
                    onChanged: (v) =>
                        _save(ref, settings.copyWith(painEnabled: v)),
                  ),
                ),
                const SettingsDivider(),
                SettingsRow.toggle(
                  label: l10n.settings_notes_label,
                  toggle: MetraToggle(
                    value: settings.notesEnabled,
                    onChanged: (v) =>
                        _save(ref, settings.copyWith(notesEnabled: v)),
                  ),
                ),
              ],
            ),

            // ── Dati ──────────────────────────────────────────────────
            SettingsLabel(l10n.settings_section_privacy),
            SettingsCard(
              children: [
                SettingsRow.nav(
                  label: l10n.settings_backup_label,
                  semanticsLabel:
                      '${l10n.settings_backup_label}: $backupValueText',
                  valueText: backupValueText,
                  onTap: () => context.push('/backup'),
                ),
                const SettingsDivider(),
                SettingsRow.action(
                  label: l10n.settings_export_csv,
                  onTap: () => _handleExport(context, ref, l10n),
                ),
                const SettingsDivider(),
                SettingsRow.action(
                  label: l10n.settings_import_csv,
                  onTap: () => _handleImport(context, ref, l10n),
                ),
              ],
            ),

            // ── Informazioni ──────────────────────────────────────────
            SettingsLabel(l10n.settings_section_about),
            SettingsCard(
              children: [
                SettingsRow.nav(
                  label: l10n.settings_help_label,
                  onTap: () => launchUrl(
                    Uri.parse(AppConstants.kUrlHelp),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
                const SettingsDivider(),
                SettingsRow.nav(
                  label: l10n.settings_github_label,
                  semanticsLabel: '${l10n.settings_github_label} — GPL-3.0',
                  onTap: () => launchUrl(
                    Uri.parse(AppConstants.kUrlGitHub),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
                const SettingsDivider(),
                SettingsRow.nav(
                  label: l10n.settings_privacy_policy,
                  onTap: () => launchUrl(
                    Uri.parse(AppConstants.kUrlPrivacy),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ],
            ),

            // ── Azioni irreversibili ──────────────────────────────────
            SettingsLabel(l10n.settings_section_danger),
            SettingsCard(
              children: [
                SettingsRow.destructive(
                  label: l10n.settings_delete_all,
                  semanticsLabel:
                      '${l10n.settings_delete_all} — ${l10n.settings_delete_all_confirm_body}',
                  onTap: () => _showDeleteConfirmation(context, ref, l10n),
                ),
              ],
            ),

            // ── Footer ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MetraSpacing.s6,
                MetraSpacing.s6,
                MetraSpacing.s6,
                MetraSpacing.s6,
              ),
              child: Column(
                children: [
                  Text(
                    MetraTypography.wordmark,
                    style: MetraTypography.dayDetailTitle
                        .copyWith(color: textPrimary),
                  ),
                  const SizedBox(height: MetraSpacing.s2),
                  Text(
                    // Read version from the native bundle at runtime so the
                    // displayed string is always in sync with pubspec.yaml
                    // without any manual update on every release.
                    ref.watch(appVersionProvider).valueOrNull ?? '',
                    style: MetraTypography.sectionLabel.copyWith(
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(height: MetraSpacing.s6),
                  _KoFiPill(
                    label: l10n.settings_kofi_label,
                    onTap: () => launchUrl(
                      Uri.parse(AppConstants.kUrlKoFi),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static void _save(WidgetRef ref, AppSettingsData settings) {
    ref.read(settingsNotifierProvider.notifier).save(settings);
  }

  static String _languageName(AppLocalizations l10n, String code) =>
      switch (code) {
        'it' => l10n.settings_language_it,
        'en' => l10n.settings_language_en,
        _ => l10n.settings_language_system,
      };

  static String _themeName(AppLocalizations l10n, bool? darkMode) =>
      switch (darkMode) {
        null => l10n.settings_theme_system,
        false => l10n.settings_theme_light,
        true => l10n.settings_theme_dark,
      };

  static int _roundTo5(int minutes) =>
      ((minutes / 5).round() * 5).clamp(0, 1435);

  static void _showLanguagePicker(
    BuildContext context,
    WidgetRef ref,
    AppSettingsData settings,
    AppLocalizations l10n,
  ) {
    // Why: SettingsScreen lives inside a ShellRoute Scaffold whose
    // bottomNavigationBar already covers the gesture-nav region; turning on
    // useSafeArea here leaves a visible dim-overlay band at the sheet bottom
    // on real Android devices (issue #4 round 2).
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(l10n.settings_language_system),
            trailing:
                settings.languageCode == '' ? const Icon(Icons.check) : null,
            onTap: () {
              Navigator.of(sheetCtx).pop();
              _save(ref, settings.copyWith(languageCode: ''));
            },
          ),
          ListTile(
            title: Text(l10n.settings_language_it),
            trailing:
                settings.languageCode == 'it' ? const Icon(Icons.check) : null,
            onTap: () {
              Navigator.of(sheetCtx).pop();
              _save(ref, settings.copyWith(languageCode: 'it'));
            },
          ),
          ListTile(
            title: Text(l10n.settings_language_en),
            trailing:
                settings.languageCode == 'en' ? const Icon(Icons.check) : null,
            onTap: () {
              Navigator.of(sheetCtx).pop();
              _save(ref, settings.copyWith(languageCode: 'en'));
            },
          ),
        ],
      ),
    );
  }

  static void _showThemePicker(
    BuildContext context,
    WidgetRef ref,
    AppSettingsData settings,
    AppLocalizations l10n,
  ) {
    // Why: see _showLanguagePicker — useSafeArea omitted to avoid
    // dim-overlay gap below sheet under ShellRoute scaffold.
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(l10n.settings_theme_system),
            trailing:
                settings.darkMode == null ? const Icon(Icons.check) : null,
            onTap: () {
              Navigator.of(sheetCtx).pop();
              // M1 Nullable<T> makes this a one-line fix: copyWith(darkMode:
              // Nullable(null)) sets darkMode to null while preserving all
              // other fields. The bare AppSettingsData constructor was removed
              // because it silently reset notificationTimeMinutes and
              // firstDayOfWeek to defaults (issue #13).
              _save(ref, settings.copyWith(darkMode: const Nullable(null)));
            },
          ),
          ListTile(
            title: Text(l10n.settings_theme_light),
            trailing:
                settings.darkMode == false ? const Icon(Icons.check) : null,
            onTap: () {
              Navigator.of(sheetCtx).pop();
              _save(ref, settings.copyWith(darkMode: const Nullable(false)));
            },
          ),
          ListTile(
            title: Text(l10n.settings_theme_dark),
            trailing:
                settings.darkMode == true ? const Icon(Icons.check) : null,
            onTap: () {
              Navigator.of(sheetCtx).pop();
              _save(ref, settings.copyWith(darkMode: const Nullable(true)));
            },
          ),
        ],
      ),
    );
  }

  static String _firstDayName(
    AppLocalizations l10n,
    FirstDayOfWeekSetting setting,
  ) =>
      switch (setting) {
        FirstDayOfWeekSetting.system => l10n.settings_first_day_of_week_system,
        FirstDayOfWeekSetting.sunday => l10n.settings_first_day_of_week_sunday,
        FirstDayOfWeekSetting.monday => l10n.settings_first_day_of_week_monday,
      };

  static void _showFirstDayOfWeekPicker(
    BuildContext context,
    WidgetRef ref,
    AppSettingsData settings,
    AppLocalizations l10n,
  ) {
    // Same pattern as _showLanguagePicker / _showThemePicker:
    // useSafeArea omitted to avoid dim-overlay gap under ShellRoute scaffold.
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(l10n.settings_first_day_of_week_system),
            trailing: settings.firstDayOfWeek == FirstDayOfWeekSetting.system
                ? const Icon(Icons.check)
                : null,
            onTap: () {
              Navigator.of(sheetCtx).pop();
              _save(
                ref,
                settings.copyWith(
                  firstDayOfWeek: FirstDayOfWeekSetting.system,
                ),
              );
            },
          ),
          ListTile(
            title: Text(l10n.settings_first_day_of_week_sunday),
            trailing: settings.firstDayOfWeek == FirstDayOfWeekSetting.sunday
                ? const Icon(Icons.check)
                : null,
            onTap: () {
              Navigator.of(sheetCtx).pop();
              _save(
                ref,
                settings.copyWith(
                  firstDayOfWeek: FirstDayOfWeekSetting.sunday,
                ),
              );
            },
          ),
          ListTile(
            title: Text(l10n.settings_first_day_of_week_monday),
            trailing: settings.firstDayOfWeek == FirstDayOfWeekSetting.monday
                ? const Icon(Icons.check)
                : null,
            onTap: () {
              Navigator.of(sheetCtx).pop();
              _save(
                ref,
                settings.copyWith(
                  firstDayOfWeek: FirstDayOfWeekSetting.monday,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Shows a Cupertino time-picker wheel seeded with [settings.notificationTimeMinutes].
  ///
  /// Used on both Android and iOS — the Cupertino wheel is the canonical
  /// picker for this app on all platforms (Material Time Picker removed in
  /// favour of visual consistency). The stored value is used directly as the
  /// seed without rounding — rounding was causing issue #21 (stored value was
  /// overwritten with a rounded derivative even when the wheel was not moved).
  /// Auto-save fires 250 ms after the last wheel movement; Ripristina resets
  /// to the seed; OK flushes any pending debounce and closes.
  static Future<void> _showCupertinoTimePicker(
    BuildContext context,
    WidgetRef ref,
    AppSettingsData settings,
  ) async {
    // FR-02: use stored value directly as seed — no rounding.
    // The stored value is the authoritative source; rounding is a visual
    // concern of the wheel (minuteInterval:5) and must not affect storage.
    final storedMinutes = settings.notificationTimeMinutes;
    // The CupertinoDatePicker requires initialDateTime to be on a tick mark
    // when minuteInterval > 1. Round to nearest 5 for display only — the
    // stored value is what gets written back.
    final seedMinutes = _roundTo5(storedMinutes);
    final initial = DateTime(2000, 1, 1, seedMinutes ~/ 60, seedMinutes % 60);

    int currentMinutes = storedMinutes; // starts at stored (not rounded) value

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => WheelPickerScaffold(
        wheelBuilder: (resetKey, scheduleAutoSave) => CupertinoDatePicker(
          key: resetKey,
          mode: CupertinoDatePickerMode.time,
          minuteInterval: 5,
          initialDateTime: initial,
          use24hFormat: MediaQuery.alwaysUse24HourFormatOf(ctx),
          onDateTimeChanged: (dt) {
            currentMinutes = dt.hour * 60 + dt.minute;
            scheduleAutoSave();
          },
        ),
        onAutoSave: () => _save(
          ref,
          settings.copyWith(notificationTimeMinutes: currentMinutes),
        ),
        onRestore: () {
          // Ripristina: restore the value that was stored when the picker opened.
          currentMinutes = storedMinutes;
          _save(
            ref,
            settings.copyWith(notificationTimeMinutes: storedMinutes),
          );
        },
      ),
    );
  }

  /// Shows a Cupertino days-picker wheel seeded with
  /// [settings.notificationDaysBefore].
  ///
  /// Used on both Android and iOS — the Cupertino wheel is the canonical
  /// picker for this app on all platforms (SimpleDialog removed in favour of
  /// visual consistency with the time picker). Auto-save fires 250 ms after
  /// the last wheel movement; Ripristina resets to the seed; OK flushes any
  /// pending debounce and closes.
  static Future<void> _showCupertinoDaysPicker(
    BuildContext context,
    WidgetRef ref,
    AppSettingsData settings,
    AppLocalizations l10n,
  ) async {
    final seededIndex = (settings.notificationDaysBefore - 1)
        .clamp(0, AppConstants.kMaxAdvanceDays - 1);

    int selectedIndex = seededIndex;

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) {
        final colors = MetraColors.of(ctx);
        return WheelPickerScaffold(
          wheelBuilder: (resetKey, scheduleAutoSave) => CupertinoTheme(
            data: CupertinoThemeData(
              brightness: Theme.of(ctx).brightness,
              primaryColor: colors.accentFlow,
              textTheme: CupertinoTextThemeData(
                pickerTextStyle: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 21,
                ),
              ),
            ),
            child: CupertinoPicker(
              key: resetKey,
              scrollController: FixedExtentScrollController(
                initialItem: selectedIndex,
              ),
              itemExtent: 44,
              onSelectedItemChanged: (i) {
                selectedIndex = i;
                scheduleAutoSave();
              },
              children: [
                for (int i = 1; i <= AppConstants.kMaxAdvanceDays; i++)
                  Center(
                    child: Text(
                      l10n.settings_advance_value(i),
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 21,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          onAutoSave: () => _save(
            ref,
            settings.copyWith(notificationDaysBefore: selectedIndex + 1),
          ),
          onRestore: () {
            selectedIndex = seededIndex;
            _save(
              ref,
              settings.copyWith(notificationDaysBefore: seededIndex + 1),
            );
          },
        );
      },
    );
  }

  static void _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    // Capture ScaffoldMessenger before async gap.
    final messenger = ScaffoldMessenger.of(context);
    showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(l10n.settings_delete_all_confirm_title),
        content: Text(l10n.settings_delete_all_confirm_body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(l10n.common_cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogCtx).colorScheme.error,
            ),
            onPressed: () {
              Navigator.of(dialogCtx).pop(true);
              ref
                  .read(deleteAllDataProvider.future)
                  .then(
                    (uc) => uc.execute().then(
                          (_) => messenger.showSnackBar(
                            SnackBar(
                              content: Text(l10n.settings_delete_all_done),
                            ),
                          ),
                        ),
                  )
                  .catchError(
                    (_) => messenger.showSnackBar(
                      SnackBar(
                        content: Text(l10n.common_error_generic),
                      ),
                    ),
                  );
            },
            child: Text(l10n.common_delete),
          ),
        ],
      ),
    );
  }

  static Future<void> _handleExport(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final messenger = ScaffoldMessenger.of(context);

    if (!context.mounted) return;
    final screenSize = MediaQuery.of(context).size;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MetraSpacing.s4,
                MetraSpacing.s5,
                MetraSpacing.s4,
                MetraSpacing.s3,
              ),
              child: Text(l10n.csv_export_privacy_warning),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(sheetCtx).pop(false),
                  child: Text(l10n.common_cancel),
                ),
                TextButton(
                  onPressed: () => Navigator.of(sheetCtx).pop(true),
                  child: Text(l10n.csv_export_privacy_confirm),
                ),
                const SizedBox(width: MetraSpacing.s2),
              ],
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    // Capture the render position BEFORE any await — the RenderBox is stable here.
    // sharePositionOrigin is required on iOS 16+ when UIActivityViewController
    // returns a non-null popoverPresentationController (always true on iOS 26+).
    final box = context.findRenderObject() as RenderBox?;
    final shareRect = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : Rect.fromCenter(
            center: Offset(
              screenSize.width / 2,
              screenSize.height / 2,
            ),
            width: 1,
            height: 1,
          );

    try {
      final exportUc = await ref.read(exportDailyLogsProvider.future);
      final csvString = await exportUc.execute();

      final tempDir = await getTemporaryDirectory();
      final now = DateTime.now();
      final filename = 'metra_export_${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}.csv';
      final file = File('${tempDir.path}/$filename');
      await file.writeAsString(csvString, encoding: utf8);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        sharePositionOrigin: shareRect,
      );
    } catch (e, st) {
      debugPrint('CSV export error: $e\n$st');
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.common_error_generic)),
        );
      }
    }
  }

  static Future<void> _handleImport(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final messenger = ScaffoldMessenger.of(context);

    FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: false,
      );
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.common_error_generic)),
      );
      return;
    }
    if (picked == null || picked.files.isEmpty) return;

    String csvString;
    try {
      final path = picked.files.first.path;
      final bytes = picked.files.first.bytes;
      if (path != null) {
        csvString = await File(path).readAsString(encoding: utf8);
      } else if (bytes != null) {
        csvString = utf8.decode(bytes);
      } else {
        throw const FormatException(
          'File content unavailable: unable to read path or bytes',
        );
      }
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.common_error_generic)),
      );
      return;
    }

    final decodeResult = const CsvCodec().decode(csvString);

    final List<DailyLogRow> rowsToImport = decodeResult.rows;
    if (decodeResult.errors.isNotEmpty) {
      if (!context.mounted) return;
      final choice = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          content: Text(
            l10n.csv_import_errors_dialog(decodeResult.errors.length),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: Text(l10n.csv_import_abort),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: Text(l10n.csv_import_skip_continue),
            ),
          ],
        ),
      );
      if (choice != true) return;
    }

    if (rowsToImport.isEmpty) return;

    if (!context.mounted) return;
    final mode = await showDialog<ImportMode>(
      context: context,
      builder: (dialogCtx) => SimpleDialog(
        title: Text(l10n.csv_import_mode_title),
        children: [
          SimpleDialogOption(
            onPressed: () =>
                Navigator.of(dialogCtx).pop(ImportMode.deleteAndImport),
            child: Text(l10n.csv_import_mode_delete),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(dialogCtx).pop(ImportMode.overwrite),
            child: Text(l10n.csv_import_mode_overwrite),
          ),
          SimpleDialogOption(
            onPressed: () =>
                Navigator.of(dialogCtx).pop(ImportMode.keepExisting),
            child: Text(l10n.csv_import_mode_keep),
          ),
        ],
      ),
    );
    if (mode == null) return;

    // FR-03: gate the destructive deleteAndImport mode behind a confirmation
    // dialog. Pattern from _showDeleteConfirmation (canonical destructive style:
    // foregroundColor = colorScheme.error on the confirm button).
    if (mode == ImportMode.deleteAndImport) {
      if (!context.mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: Text(l10n.csvImportConfirmDeleteTitle),
          content: Text(l10n.csvImportConfirmDeleteBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: Text(l10n.common_cancel),
            ),
            Semantics(
              label: l10n.csvImportConfirmDeleteAction,
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(dialogCtx).colorScheme.error,
                ),
                onPressed: () => Navigator.of(dialogCtx).pop(true),
                child: Text(l10n.csvImportConfirmDeleteAction),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    try {
      final importUc = await ref.read(importDailyLogsProvider.future);
      final result = await importUc.execute(rows: rowsToImport, mode: mode);
      if (messenger.mounted) {
        final msg = result.skipped > 0
            ? l10n.csv_import_success_skipped(result.imported, result.skipped)
            : l10n.csv_import_success(result.imported);
        messenger.showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (_) {
      if (messenger.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.common_error_generic)),
        );
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Private sub-widgets
// ---------------------------------------------------------------------------

class _KoFiPill extends StatelessWidget {
  const _KoFiPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = MetraColors.of(context);
    final accentFlow = colors.accentFlow;
    final pillBg = accentFlow.withAlpha(0x14);
    final dotBg = accentFlow.withAlpha(0x28);
    final textColor = colors.accentFlowStrong;

    return Semantics(
      label: label,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: MetraSpacing.s2,
          ),
          decoration: BoxDecoration(
            color: pillBg,
            borderRadius: BorderRadius.circular(MetraSpacing.s5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: dotBg,
                  borderRadius: BorderRadius.circular(MetraSpacing.s2),
                ),
              ),
              const SizedBox(width: MetraSpacing.s2),
              Text(
                label,
                style: MetraTypography.listDate.copyWith(
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
