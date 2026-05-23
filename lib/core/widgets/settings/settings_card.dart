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

/// Promoted public equivalent of the private `_GroupCard` in
/// `settings_screen.dart` (FR-04).
///
/// Renders a rounded card with:
/// - `MetraColors.of(context).bgSurface` background
/// - 1 px `MetraColors.of(context).borderSubtle` border (ink-at-7%)
/// - `MetraRadius.lg` (16 dp) corner radius
/// - 24 dp horizontal margin (`MetraSpacing.s6`)
/// - `clipBehavior: Clip.antiAlias`
///
/// The private `_GroupCard` in `settings_screen.dart` is left untouched until
/// TASK-12 migrates callsites.
class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = MetraColors.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: MetraSpacing.s6),
      decoration: BoxDecoration(
        color: colors.bgSurface,
        borderRadius: BorderRadius.circular(MetraRadius.lg),
        border: Border.all(color: colors.borderSubtle, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}
