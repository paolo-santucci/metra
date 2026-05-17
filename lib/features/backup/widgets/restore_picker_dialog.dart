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
import 'package:intl/intl.dart' as intl;
import 'package:metra/data/services/backup/backup_file_entry.dart';
import 'package:metra/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Sealed outcome type
// ---------------------------------------------------------------------------

/// Returned by [RestorePickerDialog.show].
///
/// Either the user chose a specific backup file ([RestorePickFilename]) or
/// clicked the "Use newest" shortcut ([RestorePickNewest]).  A `null` return
/// means the dialog was dismissed (barrier tap / back gesture).
sealed class RestorePickerOutcome {
  const RestorePickerOutcome();
}

/// The user explicitly selected a backup file and confirmed.
final class RestorePickFilename extends RestorePickerOutcome {
  const RestorePickFilename(this.filename);

  /// The opaque file identifier from [BackupFileEntry.name].
  final String filename;
}

/// The user tapped the "Use newest" shortcut.
final class RestorePickNewest extends RestorePickerOutcome {
  const RestorePickNewest();
}

// ---------------------------------------------------------------------------
// Dialog widget
// ---------------------------------------------------------------------------

/// An [AlertDialog] that lists backup files as [RadioListTile] rows and
/// returns a [RestorePickerOutcome].
///
/// HC-5 compliance: this widget is intentionally ignorant of any filename
/// format.  It treats [BackupFileEntry.name] as an opaque identifier and uses
/// [BackupFileEntry.timestampUtc] / [BackupFileEntry.sizeBytes] for display
/// only.  No filename-parsing logic exists here.
class RestorePickerDialog extends StatefulWidget {
  const RestorePickerDialog._({required this.entries});

  final List<BackupFileEntry> entries;

  /// Shows the picker and returns the user's choice.
  ///
  /// Returns `null` if the dialog is dismissed without a selection.
  static Future<RestorePickerOutcome?> show(
    BuildContext context, {
    required List<BackupFileEntry> entries,
  }) {
    return showDialog<RestorePickerOutcome>(
      context: context,
      builder: (_) => RestorePickerDialog._(entries: entries),
    );
  }

  @override
  State<RestorePickerDialog> createState() => _RestorePickerDialogState();
}

class _RestorePickerDialogState extends State<RestorePickerDialog> {
  late String _selected;

  @override
  void initState() {
    super.initState();
    // Pre-select the first entry (newest); fall back to empty string when list
    // is empty so the empty-state branch renders safely.
    _selected = widget.entries.isNotEmpty ? widget.entries.first.name : '';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final hasEntries = widget.entries.isNotEmpty;
    final locale = Localizations.localeOf(context).toString();

    return AlertDialog(
      // No Material shadow — elevation through surface-color contrast per §19.4.
      elevation: 0,
      semanticLabel: l10n.restorePickerTitle,
      title: Text(l10n.restorePickerTitle),
      content: _buildContent(l10n, locale),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        // Left side — "Use newest" shortcut (HC-5: no filename display).
        TextButton(
          onPressed: hasEntries
              ? () => Navigator.of(context).pop(const RestorePickNewest())
              : null,
          child: Text(l10n.restorePickerUseNewest),
        ),
        // Right side — destructive "Restore this version" CTA.
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: colorScheme.error,
          ),
          onPressed: hasEntries
              ? () => Navigator.of(context).pop(RestorePickFilename(_selected))
              : null,
          child: Text(l10n.restorePickerRestoreThisVersion),
        ),
      ],
    );
  }

  Widget _buildContent(AppLocalizations l10n, String locale) {
    if (widget.entries.isEmpty) {
      return _buildEmptyState(l10n);
    }
    return _buildList(l10n, locale);
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Semantics(
      liveRegion: true,
      child: Text(l10n.restorePickerEmpty),
    );
  }

  Widget _buildList(AppLocalizations l10n, String locale) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.restorePickerBody),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 240),
          child: SingleChildScrollView(
            child: RadioGroup<String>(
              groupValue: _selected,
              onChanged: (v) {
                if (v != null) setState(() => _selected = v);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: widget.entries.map((entry) {
                  final dateStr = intl.DateFormat.yMMMd(locale)
                      .add_Hm()
                      .format(entry.timestampUtc.toLocal());
                  final sizeStr = _formatSize(entry.sizeBytes);
                  return RadioListTile<String>(
                    value: entry.name,
                    title: Text(
                      l10n.restorePickerRowTemplate(dateStr, sizeStr),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
