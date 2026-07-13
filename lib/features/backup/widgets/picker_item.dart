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
// TASK-03 (code-review fixes) — shared CupertinoPicker wheel item.
//
// Moved verbatim from backup_picker_sheet_internals.dart (formerly also
// duplicated as the private _ProviderPickerItem in
// backup_provider_picker_sheet.dart). Both BackupPickerSheet (restore
// version picker) and BackupProviderPickerSheet (M4 multi-provider picker)
// consume this single widget so the distance-based typography ladder is
// defined exactly once (FR-19).
//
// Import allow-list (NFR-05): package:flutter/* + package:google_fonts only
// — no data-layer imports, so the G-05 flat scan of widgets/ (non-recursive)
// covers this file automatically.
//
// <!-- CANON GAP: the distance-based opacity/weight ladder below (16sp/w500
// @ opacity 1.0 for the selected row; 15sp/w400 @ opacity 0.35 for adjacent
// rows; 15sp/w400 @ opacity 0.18 beyond) is not enumerated as a named token
// in ui-design-bible.md §19.3 (which covers the RadioListTile restore-dialog
// radio-row tokens, a different pattern) or §18.10.2 (toolbar button parity
// only). This move is verbatim/behaviour-preserving — no new value is
// introduced — so render parity with the pre-existing (uncanonised)
// implementation is preserved as-is. -->

import 'package:flutter/widgets.dart';
import 'package:google_fonts/google_fonts.dart';

/// A single row inside a [CupertinoPicker] wheel, styled by its distance
/// from the currently-selected item.
///
/// Shared between [BackupPickerSheet] (restore version picker) and
/// `BackupProviderPickerSheet` (multi-provider picker) — see FR-19.
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
