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

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../l10n/app_localizations.dart';
import '../theme/metra_colors.dart';
import 'metra_icon.dart';

// Custom frosted-glass tab bar per DESIGN-BIBLE § 5 (tab bar spec).
// Replaces Material 3 NavigationBar (Wave 0.2).
// Height 84 dp, BackdropFilter blur(16,16), sand @ 0xF5 overlay.
// No animated indicator pill — active tab = terracotta icon + label only.
class MetraTabBar extends StatelessWidget {
  const MetraTabBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  static const _icons = <String>[
    MetraIcons.calendar,
    MetraIcons.wave,
    MetraIcons.chart,
    MetraIcons.settings,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final labels = <String>[
      l10n.nav_calendario,
      l10n.nav_archivio,
      l10n.nav_statistiche,
      l10n.nav_impostazioni,
    ];
    final colors = MetraColors.of(context);
    final activeColor = colors.terracotta;
    final idleColor = colors.ink.withAlpha(0x68);
    final bgColor = colors.sand.withAlpha(0xF5);

    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: SizedBox(
          height: 84 + bottomInset,
          child: ColoredBox(
            color: bgColor,
            child: Column(
              children: [
                SizedBox(
                  height: 84,
                  child: Row(
                    children: [
                      for (int i = 0; i < _icons.length; i++)
                        Expanded(
                          child: GestureDetector(
                            onTap: () => onTabSelected(i),
                            behavior: HitTestBehavior.opaque,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                MetraIcon(
                                  svgBody: _icons[i],
                                  size: 24,
                                  color: i == currentIndex
                                      ? activeColor
                                      : idleColor,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  labels[i],
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: i == currentIndex
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: i == currentIndex
                                        ? activeColor
                                        : idleColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: bottomInset),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
