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
import 'package:metra/core/theme/metra_colors.dart';
import 'package:metra/core/theme/metra_typography.dart';
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
/// Compliant with bible §19.2–§19.7 (TASK-07):
/// - Title: DM Serif Display 20 inchiostro (§19.2 element #1)
/// - Body: Inter 14 rgba(43,37,33,0.68) (§19.2 element #2)
/// - List: maxHeight 160 dp (§19.2 element #3)
/// - Badge: "più recente" pill on index-0 row only (§19.3)
/// - Action row: [Usa più recente] | [Annulla] [Ripristina] (§19.2)
/// - Empty state: cloud icon + italic text + single Chiudi (§19.5)
/// - semanticLabel: l10n.restorePickerSemanticLabel (§19.7)
/// - elevation: 0, shape: BorderRadius.circular(12) (§19.4)
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
    final palette = MetraColors.of(context);
    final locale = Localizations.localeOf(context).toString();

    return AlertDialog(
      // §19.4 — no shadow; elevation through surface-color contrast.
      elevation: 0,
      // §19.4 — 12 dp border-radius.
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      // §19.7 — semantic label for screen readers.
      semanticLabel: l10n.restorePickerSemanticLabel,
      // §19.2 element #1 — DM Serif Display 20 inchiostro.
      title: Text(
        l10n.restorePickerTitle,
        style: MetraTypography.dayDetailTitle.copyWith(
          color: palette.ink,
        ),
      ),
      // §19.2 element #2 — body line (only shown when list is present).
      content: hasEntries
          ? _buildListContent(l10n, locale, palette)
          : _buildEmptyState(l10n, palette),
      // §19.2 action row layout — three items with spaceBetween:
      // [Usa più recente] ... [Annulla] ... [Ripristina]
      // When entries are absent, a single right-aligned [Chiudi] is used.
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actionsOverflowAlignment: OverflowBarAlignment.end,
      actionsOverflowButtonSpacing: 0,
      actions: hasEntries
          ? _buildActions(context, l10n, colorScheme)
          : _buildEmptyActions(context, l10n),
    );
  }

  // ---------------------------------------------------------------------------
  // Content builders
  // ---------------------------------------------------------------------------

  Widget _buildListContent(
    AppLocalizations l10n,
    String locale,
    MetraPalette palette,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // §19.2 element #2 — body line.
        Text(
          l10n.restorePickerBody,
          style: MetraTypography.caption.copyWith(
            color: palette.ink.withAlpha(0xAD), // rgba(43,37,33,0.68) ≈ 0xAD
          ),
        ),
        const SizedBox(height: 8),
        // §19.2 element #3 — scrollable list capped at 160 dp.
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 160),
          child: SingleChildScrollView(
            child: RadioGroup<String>(
              groupValue: _selected,
              onChanged: (v) {
                if (v != null) setState(() => _selected = v);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(widget.entries.length, (index) {
                  final entry = widget.entries[index];
                  final dateStr = intl.DateFormat.yMMMd(locale)
                      .add_Hm()
                      .format(entry.timestampUtc.toLocal());
                  final sizeStr = _formatSize(entry.sizeBytes);
                  return RadioListTile<String>(
                    value: entry.name,
                    title: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      children: [
                        Text(
                          l10n.restorePickerRowTemplate(dateStr, sizeStr),
                        ),
                        // §19.3 — "più recente" badge on index-0 row only.
                        if (index == 0) _buildBadge(l10n, palette),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// §19.3 — Pill badge: bg terracotta18, border terracotta44, text tc_scura.
  Widget _buildBadge(AppLocalizations l10n, MetraPalette palette) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        // §19.3: bg = terracotta @ 9% (≈ 0x18 alpha)
        color: palette.terracotta.withAlpha(0x18),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          // §19.3: border = terracotta @ 27% (≈ 0x44 alpha)
          color: palette.terracotta.withAlpha(0x44),
        ),
      ),
      child: Text(
        l10n.restorePickerBadgeNewest,
        style: MetraTypography.pillSm.copyWith(
          // §19.3: text color = tc_scura (terracottaDeep in light, tc_chiara in dark)
          color: palette.terracottaDeep,
        ),
      ),
    );
  }

  /// §19.5 — Empty state: cloud icon + italic text wrapped in liveRegion.
  Widget _buildEmptyState(AppLocalizations l10n, MetraPalette palette) {
    final mutedColor =
        palette.ink.withAlpha(0x61); // rgba(43,37,33,0.38) ≈ 0x61
    return Semantics(
      liveRegion: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // §19.5 — cloud icon 28 dp, muted color.
          Icon(
            Icons.cloud_outlined,
            size: 28,
            color: mutedColor,
          ),
          const SizedBox(height: 8),
          // §19.5 — Inter 14 italic, muted color.
          Text(
            l10n.restorePickerEmpty,
            style: MetraTypography.caption.copyWith(
              color: mutedColor,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Action builders
  // ---------------------------------------------------------------------------

  /// §19.2 action row when entries are present.
  ///
  /// Three [TextButton]s with [MainAxisAlignment.spaceBetween]:
  /// - [restorePickerUseNewest] (left / start)
  /// - [restorePickerAnnulla] (center)
  /// - [restorePickerRestoreThisVersion] (right / end, error color)
  ///
  /// Flutter's [AlertDialog] renders the list through an [OverflowBar], which
  /// falls back to a column layout when the available width is too narrow —
  /// preserving accessibility at all font scales and test viewport sizes.
  List<Widget> _buildActions(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    return [
      // §19.2 element #4 — "Usa più recente" shortcut.
      TextButton(
        onPressed: () => Navigator.of(context).pop(const RestorePickNewest()),
        child: Text(l10n.restorePickerUseNewest),
      ),
      // §19.2 — Annulla (cancel).
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(l10n.restorePickerAnnulla),
      ),
      // §19.2 element #5 — destructive CTA, error color.
      TextButton(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.error,
        ),
        onPressed: () =>
            Navigator.of(context).pop(RestorePickFilename(_selected)),
        child: Text(l10n.restorePickerRestoreThisVersion),
      ),
    ];
  }

  /// §19.5 — Empty-state action row: single right-aligned Chiudi.
  List<Widget> _buildEmptyActions(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(l10n.restorePickerClose),
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // Utilities
  // ---------------------------------------------------------------------------

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
