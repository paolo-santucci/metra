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
// Private helper widgets for BackupPickerSheet (TASK-15).
// Split from backup_picker_sheet.dart to stay under the 150-line ceiling.

import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/metra_colors.dart';
import '../../../core/theme/metra_spacing.dart';
import '../../../core/widgets/settings/cupertino_picker_scaffold.dart';
import '../../../core/widgets/settings/settings_divider.dart';
import '../../../data/services/backup/backup_file_entry.dart';
import '../../../l10n/app_localizations.dart';

// ── Non-empty sheet ───────────────────────────────────────────────────────────

class PickerSheet extends StatelessWidget {
  const PickerSheet({
    required this.entries,
    required this.selected,
    required this.onSelectedChanged,
    required this.onCancel,
    required this.onConfirm,
    required this.l10n,
    super.key,
  });

  final List<BackupFileEntry> entries;
  final int selected;
  final ValueChanged<int> onSelectedChanged;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = MetraColors.of(context);
    return CupertinoPickerScaffold(
      resetLabel: l10n.commonCancel,
      confirmLabel: l10n.backupPickerConfirm,
      onReset: onCancel,
      onConfirm: onConfirm,
      useSafeArea: true,
      child: SizedBox(
        height: MetraSpacing.sp44 * 5,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: MetraSpacing.s4,
              right: MetraSpacing.s4,
              child: Container(
                height: MetraSpacing.sp44,
                decoration: BoxDecoration(
                  color: colors.textPrimary.withAlpha(0x0F),
                  borderRadius: BorderRadius.circular(MetraRadius.smm),
                ),
              ),
            ),
            CupertinoPicker(
              itemExtent: MetraSpacing.sp44,
              scrollController:
                  FixedExtentScrollController(initialItem: selected),
              useMagnifier: false,
              looping: false,
              selectionOverlay: const SizedBox.shrink(),
              onSelectedItemChanged: onSelectedChanged,
              children: List.generate(
                entries.length,
                (i) => PickerItem(
                  text: DateFormat.yMMMd(l10n.localeName)
                      .add_jm()
                      .format(entries[i].timestampUtc.toLocal()),
                  distanceFromSelected: (i - selected).abs(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty-list sheet ──────────────────────────────────────────────────────────

class EmptySheet extends StatelessWidget {
  const EmptySheet({required this.onCancel, required this.l10n, super.key});

  final VoidCallback onCancel;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = MetraColors.of(context);
    final btnStyle = GoogleFonts.inter(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: colors.accentFlow,
    );
    return ClipRRect(
      borderRadius:
          const BorderRadius.vertical(top: Radius.circular(MetraRadius.lg)),
      child: ColoredBox(
        color: colors.bgPrimary,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Semantics(
                  button: true,
                  label: l10n.commonCancel,
                  child: GestureDetector(
                    onTap: onCancel,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: MetraSpacing.s4,
                        vertical: MetraSpacing.sp14,
                      ),
                      child: Text(l10n.commonCancel, style: btnStyle),
                    ),
                  ),
                ),
                Semantics(
                  button: true,
                  enabled: false,
                  label: l10n.backupPickerConfirm,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: MetraSpacing.s4,
                      vertical: MetraSpacing.sp14,
                    ),
                    child: Text(
                      l10n.backupPickerConfirm,
                      style: btnStyle.copyWith(
                        color: colors.accentFlow.withAlpha(0x80),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SettingsDivider(),
            SizedBox(
              height: MetraSpacing.sp44 * 3,
              child: Center(
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    l10n.backupPickerEmpty,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: colors.textPrimary.withAlpha(0x61),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Picker item with distance-based typography ────────────────────────────────

class PickerItem extends StatelessWidget {
  const PickerItem({
    required this.text,
    required this.distanceFromSelected,
    super.key,
  });

  final String text;
  final int distanceFromSelected;

  @override
  Widget build(BuildContext context) {
    final double fontSize;
    final FontWeight fontWeight;
    final double opacity;

    if (distanceFromSelected == 0) {
      fontSize = 16;
      fontWeight = FontWeight.w500;
      opacity = 1.0;
    } else if (distanceFromSelected == 1) {
      fontSize = 15;
      fontWeight = FontWeight.w400;
      opacity = 0.35;
    } else {
      fontSize = 15;
      fontWeight = FontWeight.w400;
      opacity = 0.18;
    }

    return Center(
      child: Opacity(
        opacity: opacity,
        child: Text(
          text,
          style: GoogleFonts.inter(fontSize: fontSize, fontWeight: fontWeight),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
