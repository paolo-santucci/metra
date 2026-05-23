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

// TASK-21 — BackupScreen dispatcher
//
// Exhaustive state dispatcher over AsyncValue<BackupState>.  Each view owns
// its own Scaffold + AppBar; this widget never wraps the result in a second
// Scaffold (spec §5.1 dispatcher contract).
//
// State mapping:
//   AsyncLoading                               → thin loading Scaffold
//   AsyncError(:final error)                   → BackupErrorView(message)
//   AsyncData(BackupNotConnected)              → BackupEmptyView
//   AsyncData(BackupConnected)                 → BackupConnectedView(state)
//   AsyncData(BackupRunning(restoring))        → RestoreProgressScreen
//   AsyncData(BackupRunning(any other))        → thin Scaffold + _RunningBody
//   AsyncData(BackupErrorState(:final message))→ BackupErrorView(message)
//
// No default: branch.  A new BackupState subtype fails the Dart analyzer until
// explicitly mapped here (FR-20 neg).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/metra_colors.dart';
import '../../l10n/app_localizations.dart';
import 'restore_progress_screen.dart';
import 'state/backup_notifier.dart';
import 'state/backup_state.dart';
import 'views/backup_connected_view.dart';
import 'views/backup_empty_view.dart';
import 'views/backup_error_view.dart';

class BackupScreen extends ConsumerWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(backupNotifierProvider);

    return asyncState.when(
      loading: () => _loadingScaffold(context),
      error: (error, _) => BackupErrorView(message: error.toString()),
      data: (state) => switch (state) {
        BackupNotConnected() => const BackupEmptyView(),
        BackupConnected() => BackupConnectedView(state: state),
        BackupRunning(operation: BackupOperation.restoring) =>
          const RestoreProgressScreen(),
        BackupRunning(:final operation) => _runningScaffold(
            context,
            operation,
          ),
        BackupErrorState(:final message) => BackupErrorView(message: message),
      },
    );
  }
}

// ---------------------------------------------------------------------------
// _loadingScaffold — shown during AsyncLoading
// ---------------------------------------------------------------------------

Widget _loadingScaffold(BuildContext context) {
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
    body: const Center(child: CircularProgressIndicator()),
  );
}

// ---------------------------------------------------------------------------
// _runningScaffold — shown for BackupRunning (non-restoring operations)
// ---------------------------------------------------------------------------

Widget _runningScaffold(BuildContext context, BackupOperation operation) {
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
    body: _RunningBody(operation: operation),
  );
}

// ---------------------------------------------------------------------------
// _RunningBody — preserved per §1 / §5.1 dispatcher contract
// ---------------------------------------------------------------------------

class _RunningBody extends StatelessWidget {
  const _RunningBody({required this.operation});

  final BackupOperation operation;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final label = switch (operation) {
      BackupOperation.restoring => l10n.backup_restore_in_progress,
      BackupOperation.backingUp => l10n.backup_in_progress,
      BackupOperation.connecting => l10n.backup_in_progress,
      BackupOperation.disconnecting => l10n.backup_in_progress,
    };
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(label),
        ],
      ),
    );
  }
}
