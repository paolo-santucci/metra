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

/// A platform-aware 48×28 dp toggle atom.
///
/// Active colour: [MetraColors.accentFlow] (terracotta).
/// Inactive colour: [MetraColors.bgSunken] (dark) / ink-at-8% (light).
///
/// Reduced-motion-aware: honours [MediaQuery.disableAnimations].
/// Platform detection uses [defaultTargetPlatform] — never dart:io Platform checks.
///
/// Render contract is byte-equivalent to the private `_MetraToggle` in
/// `settings_screen.dart`. Do NOT remove that class until TASK-12.
class MetraToggle extends StatelessWidget {
  const MetraToggle({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = MetraColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onColor = colors.accentFlow;
    // Off track: ink@8% in light, bgSunken in dark.
    // Asymmetric tokens — kept as ternary because the alpha value differs per mode.
    final offColor = isDark ? colors.bgSunken : colors.ink.withAlpha(0x14);
    final dotColor = colors.bgSurface;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final dur = Duration(
      milliseconds: reduceMotion ? MetraMotion.instant : MetraMotion.fast,
    );

    return Semantics(
      toggled: value,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: dur,
          width: 48,
          height: 28,
          decoration: BoxDecoration(
            color: value ? onColor : offColor,
            borderRadius: BorderRadius.circular(MetraRadius.mmd), // 14
          ),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: dur,
                top: 3,
                left: value ? 23.0 : 3.0,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: dotColor,
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
