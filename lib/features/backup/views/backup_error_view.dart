// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/metra_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../state/backup_notifier.dart';

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
class BackupErrorView extends ConsumerWidget {
  const BackupErrorView({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = MetraColors.of(context);
    final bg = colors.bgPrimary;
    final textPrimary = colors.textPrimary;

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
              child: Text(message),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => ref.invalidate(backupNotifierProvider),
              child: Text(l10n.common_error_generic),
            ),
          ],
        ),
      ),
    );
  }
}
