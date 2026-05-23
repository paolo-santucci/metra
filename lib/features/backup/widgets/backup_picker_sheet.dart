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

// SPDX-License-Identifier: GPL-3.0-or-later
//
// TASK-15 — BackupPickerSheet
//
// A modal bottom sheet hosting a CupertinoPicker for selecting a backup file.
// Private layout helpers live in backup_picker_sheet_internals.dart (≤150 LoC
// split per NFR-08).
//
// Public API:
//   BackupPickerSheet({required entries, initialIndex=0})
//   BackupPickerSheet.show(context, {required entries, initialIndex=0})
//     → Future<int?>   (int on Ripristina, null on Annulla / barrier dismiss)
//
// Contracts:
//   • FR-15: top-only 16 dp radius, sabbia bg, CupertinoPicker w/ sp44 itemExtent
//   • FR-16: returns selected index or null
//   • FR-17: empty-list → disabled Ripristina, liveRegion empty label, Annulla active
//   • EC-01: throws ArgumentError on out-of-range initialIndex (non-empty list)
//   • OQ-12: useSafeArea NOT passed false (/backup is outside ShellRoute)

import 'package:flutter/material.dart';

import '../../../core/theme/metra_colors.dart';
import '../../../data/services/backup/backup_file_entry.dart';
import '../../../l10n/app_localizations.dart';
import 'backup_picker_sheet_internals.dart';

/// Modal bottom sheet for selecting a [BackupFileEntry] from [entries].
class BackupPickerSheet extends StatefulWidget {
  BackupPickerSheet({
    required this.entries,
    this.initialIndex = 0,
    super.key,
  }) {
    if (entries.isNotEmpty && initialIndex >= entries.length) {
      throw ArgumentError.value(
        initialIndex,
        'initialIndex',
        'must be < entries.length (${entries.length}) when entries is non-empty',
      );
    }
  }

  final List<BackupFileEntry> entries;
  final int initialIndex;

  /// Presents this sheet and returns the selected index, or null on cancel /
  /// barrier dismiss.  Throws [ArgumentError] when [initialIndex] is out of
  /// range for a non-empty [entries] list (EC-01).
  static Future<int?> show(
    BuildContext context, {
    required List<BackupFileEntry> entries,
    int initialIndex = 0,
  }) {
    if (entries.isNotEmpty && initialIndex >= entries.length) {
      throw ArgumentError.value(
        initialIndex,
        'initialIndex',
        'must be < entries.length (${entries.length}) when entries is non-empty',
      );
    }
    final colors = MetraColors.of(context);
    return showModalBottomSheet<int?>(
      context: context,
      isScrollControlled: true,
      // Transparent so CupertinoPickerScaffold's ClipRRect is the visual boundary
      // (avoids double-rounding artefact if backgroundColor != transparent).
      backgroundColor: Colors.transparent,
      barrierColor: colors.textPrimary.withAlpha(0x40), // ink-at-25%
      builder: (_) =>
          BackupPickerSheet(entries: entries, initialIndex: initialIndex),
    );
  }

  @override
  State<BackupPickerSheet> createState() => _BackupPickerSheetState();
}

class _BackupPickerSheetState extends State<BackupPickerSheet> {
  late int _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialIndex;
  }

  void _cancel() => Navigator.of(context).pop(null);
  void _confirm() => Navigator.of(context).pop(_selected);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (widget.entries.isEmpty) {
      return EmptySheet(onCancel: _cancel, l10n: l10n);
    }
    return PickerSheet(
      entries: widget.entries,
      selected: _selected,
      onSelectedChanged: (i) => setState(() => _selected = i),
      onCancel: _cancel,
      onConfirm: _confirm,
      l10n: l10n,
    );
  }
}
