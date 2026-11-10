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
/// accessible label via [semanticsLabel] or a wrapping [Semantics] if the
/// context requires one.
///
/// Optional decoration slots: [prefixIcon] renders in the leading slot,
/// [suffixIcon] in the trailing one. The caller supplies and owns both widgets
/// — e.g. a tappable clear affordance in [suffixIcon]. This widget deliberately
/// owns no debouncing, filtering or clearing behaviour: that stays with the
/// caller, so the shared widget stays purely presentational.
///
/// [semanticsLabel] set → the field is wrapped in a [Semantics] node carrying
/// exactly that label. Null (default) → no wrapper node is added, so no orphan
/// semantics node is introduced (FR-17).
///
/// All three optional params default to null: existing call sites and goldens
/// are unaffected.
///
/// Font size is 16pt to prevent iOS auto-zoom on focus.
///
/// <!-- CANON GAP: search-input surface — OQ-03 -->
/// The bible defines no search-input component. This surface is a
/// documented-gap reuse that only composes catalogued tokens (bgSurface fill,
/// borderSubtle border, focusRing, 44 dp minHeight); a bible patch is pending.
class TextFieldMetra extends StatelessWidget {
  const TextFieldMetra({
    super.key,
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.onChanged,
    this.prefixIcon,
    this.suffixIcon,
    this.semanticsLabel,
  });

  final TextEditingController controller;
  final String hint;
  final int? maxLines;
  final ValueChanged<String>? onChanged;

  /// Leading decoration slot (e.g. a search glyph). Null → no prefix.
  final Widget? prefixIcon;

  /// Trailing decoration slot (e.g. a caller-owned clear affordance).
  /// Null → no suffix.
  final Widget? suffixIcon;

  /// Exact accessibility label for the field. Null → no wrapper node.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final colors = MetraColors.of(context);
    final fillColor = colors.bgSurface;
    final textColor = colors.textPrimary;
    final hintColor = colors.textSecondary;
    final borderSubtle = colors.borderSubtle;
    final focusRing = colors.focusRing;

    // Multi-line (textarea) uses larger radius and more padding per spec §7.
    final bool isMultiline = maxLines == null || maxLines! > 1;
    final double radius = isMultiline ? MetraRadius.md : MetraRadius.sm;
    final EdgeInsets contentPadding = isMultiline
        ? const EdgeInsets.all(MetraSpacing.s4)
        : const EdgeInsets.symmetric(
            horizontal: MetraSpacing.s4,
            vertical: MetraSpacing.s3,
          );

    final Widget field = TextField(
      controller: controller,
      maxLines: maxLines,
      onChanged: onChanged,
      style: MetraTypography.body.copyWith(color: textColor),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: MetraTypography.body.copyWith(color: hintColor),
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
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
          borderSide: BorderSide(color: colors.stateError),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: colors.stateError, width: 2),
        ),
      ),
    );

    final label = semanticsLabel;
    if (label == null) {
      return field;
    }

    // `container: true` + `explicitChildNodes: true` keep the label on its own
    // node instead of merging it into the field's semantics: the announced
    // string stays exactly [label] (FR-17) while the field keeps its own
    // editable-text node as a child.
    return Semantics(
      label: label,
      container: true,
      explicitChildNodes: true,
      child: field,
    );
  }
}
