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

import 'package:flutter/material.dart';

import '../../theme/metra_colors.dart';
import '../../theme/metra_spacing.dart';
import '../../theme/metra_typography.dart';

/// A section-header label for grouped-list settings screens.
///
/// Renders [text] in uppercase using [MetraTypography.sectionLabel]
/// (Inter 12 / w600 / 0.06em) coloured [MetraColors.textSecondary].
///
/// Use [first] = true for the first group on a screen to apply a reduced
/// top inset (8 dp instead of 24 dp).
///
/// Byte-equivalent render contract to the private `_SectionHeader` in
/// `settings_screen.dart`. That class will be removed in TASK-12 once
/// all call-sites migrate to this public widget.
class SettingsLabel extends StatelessWidget {
  const SettingsLabel(this.text, {this.first = false, super.key});

  final String text;

  /// When true the top padding is 8 dp; otherwise 24 dp (MetraSpacing.s6).
  final bool first;

  @override
  Widget build(BuildContext context) {
    final color = MetraColors.of(context).textSecondary;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        MetraSpacing.s6,
        first ? 8.0 : MetraSpacing.s6,
        MetraSpacing.s6,
        12.0,
      ),
      child: Semantics(
        header: true,
        child: Text(
          text.toUpperCase(),
          style: MetraTypography.sectionLabel.copyWith(color: color),
        ),
      ),
    );
  }
}
