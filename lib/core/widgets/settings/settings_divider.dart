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

import '../../theme/metra_colors.dart';

/// A 1 dp horizontal rule that separates rows inside a SettingsCard.
///
/// Colour: [MetraPalette.borderSubtle] — ink-at-7% in light, avorio-at-7% in dark.
/// No horizontal indent; spans the full card width.
///
/// Byte-equivalent (in render contract) to the private `_SettingsDivider` in
/// `lib/features/settings/settings_screen.dart` (TASK-07). The private
/// definition stays until TASK-12 migrates all callsites.
class SettingsDivider extends StatelessWidget {
  const SettingsDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: MetraColors.of(context).borderSubtle);
  }
}
