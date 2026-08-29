// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/metra_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/browser_settings_provider.dart';
import '../state/backup_notifier.dart';
import '../state/backup_state.dart';

/// Error-state view for the Backup screen.
///
/// Shown by the dispatcher when [BackupState] is [BackupErrorState].
/// Owns its Scaffold + AppBar so the dispatcher can mount it directly without
/// wrapping it in a second Scaffold (spec §5.1 dispatcher contract).
///
/// The body is byte-equivalent to the former inline [_ErrorBody]:
/// - [Semantics(liveRegion: true)] on the error message so assistive
///   technology announces the error string when the view first appears.
/// - A retry [ElevatedButton] that invalidates [backupNotifierProvider],
///   triggering the notifier to rebuild from scratch.
///
/// When [kind] is [BackupErrorKind.noBrowser], an additional "Enable browser"
/// button is shown: it opens the browser app's info screen in system Settings
/// via the `metra/browser_settings` platform channel so the user can enable a
/// disabled browser (e.g. Chrome in DISABLED_UNTIL_USED on Samsung), then
/// return and retry. The localised [AppLocalizations.backupErrorNoBrowserMessage]
/// replaces the raw [message] in that case.
class BackupErrorView extends ConsumerWidget {
  const BackupErrorView({
    required this.message,
    this.kind = BackupErrorKind.generic,
    super.key,
  });

  final String message;
  final BackupErrorKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = MetraColors.of(context);
    final bg = colors.bgPrimary;
    final textPrimary = colors.textPrimary;
    final isNoBrowser = kind == BackupErrorKind.noBrowser;
    final displayedMessage =
        isNoBrowser ? l10n.backupErrorNoBrowserMessage : message;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: Text(
          l10n.backup_screen_title,
          style: TextStyle(color: textPrimary),
        ),
        iconTheme: IconThemeData(color: textPrimary),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              liveRegion: true,
              child: Text(displayedMessage),
            ),
            const SizedBox(height: 24),
            if (isNoBrowser)
              ElevatedButton(
                onPressed: () => _openBrowserSettings(ref),
                child: Text(l10n.backupErrorEnableBrowser),
              ),
            ElevatedButton(
              onPressed: () => ref.invalidate(backupNotifierProvider),
              child: Text(l10n.common_error_generic),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openBrowserSettings(WidgetRef ref) async {
    final service = ref.read(browserSettingsServiceProvider);
    var ok = await service.openAppDetails(chromePackage);
    if (!ok) {
      ok = await service.openAppsSettings();
    }
  }
}
