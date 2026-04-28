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
import '../theme/metra_colors.dart';
import '../theme/metra_typography.dart';

/// DM Serif Display section header.
///
/// Non-interactive. Semantics marks it as a heading so screen readers
/// can navigate the section structure.
class SectionTitleMetra extends StatelessWidget {
  const SectionTitleMetra({
    super.key,
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? MetraColors.dark.textPrimary : MetraColors.light.textPrimary;

    return Semantics(
      header: true,
      child: Text(
        title,
        style: MetraTypography.titleMd.copyWith(color: textColor),
      ),
    );
  }
}
