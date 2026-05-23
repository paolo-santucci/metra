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
import 'package:google_fonts/google_fonts.dart';
import 'package:metra/core/theme/metra_colors.dart';

/// Builds the trailing element of a [SettingsRow].
///
/// Receives only resolved flags — no [_RowVariant] dependency — so this
/// function lives in a separate library file without leaking private types.
///
/// - [showChevron] true → render the 16dp chevron at ink-at-40%.
/// - [valueText] non-null → render secondary value text (Inter 14 / w400).
/// - [toggle] non-null → render the pre-built toggle widget directly.
/// - All three null → returns null (no trailing element).
Widget? buildSettingsRowTrailing({
  required MetraPalette colors,
  bool showChevron = false,
  String? valueText,
  Widget? toggle,
}) {
  if (toggle != null) return toggle;

  if (showChevron) {
    // Value text + chevron: both may be present simultaneously (.nav variant).
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (valueText != null)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Text(
              valueText,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: colors.textSecondary,
              ),
            ),
          ),
        Icon(
          Icons.chevron_right,
          size: 16,
          color: colors.ink.withAlpha(0x66), // 40% opacity per spec
        ),
      ],
    );
  }

  if (valueText != null) {
    // Static-info trailing: value text only, no chevron.
    return Text(
      valueText,
      style: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: colors.textSecondary,
      ),
    );
  }

  return null;
}
