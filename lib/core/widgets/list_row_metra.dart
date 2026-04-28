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
import '../theme/metra_spacing.dart';

/// List tile with optional leading icon slot, title, and optional trailing widget.
///
/// When [onTap] is null, rendered as static informational row (no ink, no button semantics).
/// When interactive, minimum tap target is 48dp (Android-first for lists).
class ListRowMetra extends StatelessWidget {
  const ListRowMetra({
    super.key,
    required this.title,
    required this.semanticsLabel,
    this.leading,
    this.trailing,
    this.onTap,
  });

  final String title;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDark ? MetraColors.dark.bgSurface : MetraColors.light.bgSurface;
    final borderColor =
        isDark ? MetraColors.dark.borderSubtle : MetraColors.light.borderSubtle;
    final textColor =
        isDark ? MetraColors.dark.textPrimary : MetraColors.light.textPrimary;

    final rowContent = Container(
      constraints: const BoxConstraints(minHeight: 48),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          bottom: BorderSide(color: borderColor),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: MetraSpacing.s4,
        vertical: MetraSpacing.s3,
      ),
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: MetraSpacing.s3),
          ],
          Expanded(
            child: Text(
              title,
              style: MetraTypography.body.copyWith(color: textColor),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: MetraSpacing.s3),
            trailing!,
          ],
        ],
      ),
    );

    if (onTap == null) {
      return Semantics(
        label: semanticsLabel,
        container: true,
        child: rowContent,
      );
    }

    return Semantics(
      label: semanticsLabel,
      button: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: rowContent,
      ),
    );
  }
}
