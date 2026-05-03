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
import '../../core/widgets/button_ghost.dart';
import '../../core/widgets/list_row_metra.dart';
import '../../domain/entities/app_settings_data.dart';
import '../../domain/services/csv_codec.dart';
import '../../domain/use_cases/import_daily_logs.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/use_case_providers.dart';
import 'state/settings_notifier.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgPrimary =
        isDark ? MetraColors.dark.bgPrimary : MetraColors.light.bgPrimary;
    final textPrimary =
        isDark ? MetraColors.dark.textPrimary : MetraColors.light.textPrimary;
    final textSecondary = isDark
        ? MetraColors.dark.textSecondary
        : MetraColors.light.textSecondary;
    final stateError =
        isDark ? MetraColors.dark.stateError : MetraColors.light.stateError;
    final settings = ref.watch(settingsNotifierProvider).valueOrNull ??
        const AppSettingsData.defaults();

    return Scaffold(
      backgroundColor: bgPrimary,
      body: SafeArea(
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MetraSpacing.s4,
                MetraSpacing.s6,
                MetraSpacing.s4,
                MetraSpacing.s2,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  l10n.settings_screen_title,
                  style: MetraTypography.titleLg.copyWith(
                    color: textPrimary,
                  ),
                ),
              ),
            ),

            // ── Preferenze ──────────────────────────────────────────────────
            _SectionHeader(l10n.settings_section_preferences),
            _GroupCard(
              children: [
                ListRowMetra(
                  title: l10n.settings_language_label,
                  semanticsLabel:
                      '${l10n.settings_language_label}: ${_languageName(l10n, settings.languageCode)}',
                  trailing: _ChevronTrailing(
                    _languageName(l10n, settings.languageCode),
                  ),
                  onTap: () =>
                      _showLanguagePicker(context, ref, settings, l10n),
                ),
                ListRowMetra(
                  title: l10n.settings_theme_label,
                  semanticsLabel:
                      '${l10n.settings_theme_label}: ${_themeName(l10n, settings.darkMode)}',
                  trailing: _ChevronTrailing(
                    _themeName(l10n, settings.darkMode),
                  ),
                  onTap: () => _showThemePicker(context, ref, settings, l10n),
                ),
              ],
            ),

            // ── Registro ────────────────────────────────────────────────────
            _SectionHeader(l10n.settings_section_log),
            _GroupCard(
              children: [
                SwitchListTile.adaptive(
                  value: settings.painEnabled,
                  onChanged: (v) =>
                      _save(ref, settings.copyWith(painEnabled: v)),
                  title: Text(
                    l10n.settings_pain_label,
                    style: MetraTypography.body.copyWith(
                      color: textPrimary,
                    ),
                  ),
                ),
                SwitchListTile.adaptive(
                  value: settings.notesEnabled,
                  onChanged: (v) =>
                      _save(ref, settings.copyWith(notesEnabled: v)),
                  title: Text(
                    l10n.settings_notes_label,
                    style: MetraTypography.body.copyWith(
                      color: textPrimary,
                    ),
                  ),
                ),
              ],
            ),

            // ── Notifiche ───────────────────────────────────────────────────
            _SectionHeader(l10n.settings_section_notifications),
            _GroupCard(
              children: [
                SwitchListTile.adaptive(
                  value: settings.notificationsEnabled,
                  onChanged: (v) => _save(
                    ref,
                    settings.copyWith(notificationsEnabled: v),
                  ),
                  title: Text(
                    l10n.settings_notifications_label,
                    style: MetraTypography.body.copyWith(
                      color: textPrimary,
                    ),
                  ),
                ),
                ListRowMetra(
                  title: l10n.settings_advance_label,
                  semanticsLabel:
                      '${l10n.settings_advance_label}: ${l10n.settings_advance_value(settings.notificationDaysBefore)}',
                  trailing: _ChevronTrailing(
                    l10n.settings_advance_value(
                      settings.notificationDaysBefore,
                    ),
                  ),
                  onTap: () => _showAdvancePicker(context, ref, settings, l10n),
                ),
              ],
            ),

            // ── Privacy e dati ───────────────────────────────────────────────
            _SectionHeader(l10n.settings_section_privacy),
            _GroupCard(
              children: [
                ListRowMetra(
                  title: l10n.settings_backup_label,
                  semanticsLabel:
                      '${l10n.settings_backup_label}: ${l10n.settings_backup_not_configured}',
                  trailing: _ChevronTrailing(
                    l10n.settings_backup_not_configured,
                  ),
                  onTap: () => context.push('/backup'),
                ),
              ],
            ),

            // ── CSV export / import ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: MetraSpacing.s4,
                vertical: MetraSpacing.s3,
              ),
              child: ButtonGhost(
                label: l10n.settings_export_csv,
                semanticsLabel: l10n.settings_export_csv,
                onPressed: () => _handleExport(context, ref, l10n),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: MetraSpacing.s4,
                vertical: MetraSpacing.s3,
              ),
              child: ButtonGhost(
                label: l10n.settings_import_csv,
                semanticsLabel: l10n.settings_import_csv,
                onPressed: () => _handleImport(context, ref, l10n),
              ),
            ),

            // ── Zona pericolosa ──────────────────────────────────────────────
            _SectionHeader(l10n.settings_section_danger),
            _GroupCard(
              children: [
                ListRowMetra(
                  title: l10n.settings_delete_all,
                  semanticsLabel:
                      '${l10n.settings_delete_all} — ${l10n.settings_delete_all_confirm_body}',
                  leading: Icon(
                    Icons.delete_outline,
                    color: stateError,
                    size: 20,
                  ),
                  trailing: null,
                  onTap: () => _showDeleteConfirmation(context, ref, l10n),
                ),
              ],
            ),

            // ── Informazioni ─────────────────────────────────────────────────
            _SectionHeader(l10n.settings_section_about),
            _GroupCard(
              children: [
                ListRowMetra(
                  title: l10n.settings_privacy_policy,
                  semanticsLabel: l10n.settings_privacy_policy,
                  trailing: const Icon(Icons.open_in_new, size: 16),
                  onTap: () => launchUrl(
                    Uri.parse(
                      'https://paolosantucci.github.io/metra/privacy',
                    ),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ],
            ),

            // ── Footer ───────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: MetraSpacing.s6,
              ),
              child: Column(
                children: [
                  Text(
                    '${MetraTypography.wordmark} ${AppConstants.kAppVersion}',
                    style: MetraTypography.caption.copyWith(
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(height: MetraSpacing.s2),
                  Text(
                    'GPL-3.0',
                    style: MetraTypography.caption.copyWith(
                      color: textSecondary,
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
      code == 'it' ? l10n.settings_language_it : l10n.settings_language_en;

  static String _themeName(AppLocalizations l10n, bool? darkMode) =>
      switch (darkMode) {
        null => l10n.settings_theme_system,
        false => l10n.settings_theme_light,
        true => l10n.settings_theme_dark,
      };

  static void _showLanguagePicker(
    BuildContext context,
    WidgetRef ref,
    AppSettingsData settings,
    AppLocalizations l10n,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(l10n.settings_language_it),
              trailing: settings.languageCode == 'it'
                  ? const Icon(Icons.check)
                  : null,
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _save(ref, settings.copyWith(languageCode: 'it'));
              },
            ),
            ListTile(
              title: Text(l10n.settings_language_en),
              trailing: settings.languageCode == 'en'
                  ? const Icon(Icons.check)
                  : null,
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _save(ref, settings.copyWith(languageCode: 'en'));
              },
            ),
          ],
        ),
      ),
    );
  }

  static void _showThemePicker(
    BuildContext context,
    WidgetRef ref,
    AppSettingsData settings,
    AppLocalizations l10n,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(l10n.settings_theme_system),
              trailing:
                  settings.darkMode == null ? const Icon(Icons.check) : null,
              onTap: () {
                Navigator.of(sheetCtx).pop();
                // Full constructor needed: copyWith cannot set darkMode to null.
                _save(
                  ref,
                  AppSettingsData(
                    languageCode: settings.languageCode,
                    darkMode: null,
                    painEnabled: settings.painEnabled,
                    notesEnabled: settings.notesEnabled,
                    notificationDaysBefore: settings.notificationDaysBefore,
                    notificationsEnabled: settings.notificationsEnabled,
                    onboardingCompleted: settings.onboardingCompleted,
                  ),
                );
              },
            ),
            ListTile(
              title: Text(l10n.settings_theme_light),
              trailing:
                  settings.darkMode == false ? const Icon(Icons.check) : null,
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _save(ref, settings.copyWith(darkMode: false));
              },
            ),
            ListTile(
              title: Text(l10n.settings_theme_dark),
              trailing:
                  settings.darkMode == true ? const Icon(Icons.check) : null,
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _save(ref, settings.copyWith(darkMode: true));
              },
            ),
          ],
        ),
      ),
    );
  }

  static void _showAdvancePicker(
    BuildContext context,
    WidgetRef ref,
    AppSettingsData settings,
    AppLocalizations l10n,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: 7,
          itemBuilder: (_, i) {
            final days = i + 1;
            return ListTile(
              title: Text(l10n.settings_advance_value(days)),
              trailing: settings.notificationDaysBefore == days
                  ? const Icon(Icons.check)
                  : null,
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _save(
                  ref,
                  settings.copyWith(notificationDaysBefore: days),
                );
              },
            );
          },
        ),
      ),
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
      );
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.common_error_generic)),
      );
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = isDark
        ? MetraColors.dark.textSecondary
        : MetraColors.light.textSecondary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        MetraSpacing.s4,
        MetraSpacing.s5,
        MetraSpacing.s4,
        MetraSpacing.s2,
      ),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: MetraTypography.caption.copyWith(
            color: textSecondary,
          ),
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgSurface =
        isDark ? MetraColors.dark.bgSurface : MetraColors.light.bgSurface;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: MetraSpacing.s4),
      decoration: BoxDecoration(
        color: bgSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _ChevronTrailing extends StatelessWidget {
  const _ChevronTrailing(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = isDark
        ? MetraColors.dark.textSecondary
        : MetraColors.light.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: MetraTypography.body.copyWith(
            color: textSecondary,
          ),
        ),
        const SizedBox(width: MetraSpacing.s2),
        Icon(
          Icons.chevron_right,
          size: 16,
          color: textSecondary,
        ),
      ],
    );
  }
}
