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

/// Styled text input field.
///
/// Serves both single-line and multi-line (notes) usage.
/// [maxLines] = 1 → single line input. [maxLines] = null → expands vertically.
/// [hint] is a usage example, not a label — the caller must provide an
/// accessible label via a wrapping [Semantics] or [TextField.decoration.labelText]
/// if the context requires one.
///
/// Font size is 16pt to prevent iOS auto-zoom on focus.
class TextFieldMetra extends StatelessWidget {
  const TextFieldMetra({
    super.key,
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final int? maxLines;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final fillColor =
        isDark ? MetraColors.dark.bgSurface : MetraColors.light.bgSurface;
    final textColor =
        isDark ? MetraColors.dark.textPrimary : MetraColors.light.textPrimary;
    final hintColor = isDark
        ? MetraColors.dark.textSecondary
        : MetraColors.light.textSecondary;
    final borderSubtle =
        isDark ? MetraColors.dark.borderSubtle : MetraColors.light.borderSubtle;
    final focusRing =
        isDark ? MetraColors.dark.focusRing : MetraColors.light.focusRing;

    // Multi-line (textarea) uses larger radius and more padding per spec §7.
    final bool isMultiline = maxLines == null || maxLines! > 1;
    final double radius = isMultiline ? MetraRadius.md : MetraRadius.sm;
    final EdgeInsets contentPadding = isMultiline
        ? const EdgeInsets.all(MetraSpacing.s4)
        : const EdgeInsets.symmetric(
            horizontal: MetraSpacing.s4,
            vertical: MetraSpacing.s3,
          );

    return TextField(
      controller: controller,
      maxLines: maxLines,
      onChanged: onChanged,
      style: MetraTypography.body.copyWith(color: textColor),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: MetraTypography.body.copyWith(color: hintColor),
        filled: true,
        fillColor: fillColor,
        contentPadding: contentPadding,
        // Minimum tap target: 44pt height on single-line
        constraints: BoxConstraints(
          minHeight: isMultiline ? 96 : 44,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: focusRing, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(
            color: isDark
                ? MetraColors.dark.stateError
                : MetraColors.light.stateError,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(
            color: isDark
                ? MetraColors.dark.stateError
                : MetraColors.light.stateError,
            width: 2,
          ),
        ),
      ),
    );
  }
}
