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

import '../../../core/theme/metra_colors.dart';
import '../../../core/theme/metra_spacing.dart';
import '../../../core/theme/metra_typography.dart';
import '../../../domain/entities/flow_type.dart';
import '../../../l10n/app_localizations.dart';

/// Three equal-width chips for selecting a [FlowType].
///
/// Tapping the already-selected chip deselects it (calls onChanged with null).
/// Visual states:
/// - null (none selected): all chips show borderSubtle outline.
/// - assente selected: dashed terracotta border, transparent fill.
/// - mestruazioni selected: solid terracotta border + 15% accent fill.
/// - spotting selected: solid 50%-opacity terracotta border + 25% accent fill.
class FlowTypeChips extends StatelessWidget {
  const FlowTypeChips({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final FlowType? selected;
  final ValueChanged<FlowType?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent =
        isDark ? MetraColors.dark.accentFlow : MetraColors.light.accentFlow;
    final borderSubtle =
        isDark ? MetraColors.dark.borderSubtle : MetraColors.light.borderSubtle;
    final textPrimary =
        isDark ? MetraColors.dark.textPrimary : MetraColors.light.textPrimary;
    final textSecondary = isDark
        ? MetraColors.dark.textSecondary
        : MetraColors.light.textSecondary;
    final accentText = isDark
        ? MetraColors.dark.accentFlowText
        : MetraColors.light.accentFlowText;

    return Row(
      children: [
        Expanded(
          child: _FlowChip(
            label: l10n.daily_entry_flow_chip_assente,
            flowType: FlowType.assente,
            selected: selected,
            accent: accent,
            accentText: accentText,
            borderSubtle: borderSubtle,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            onTap: () => onChanged(
              selected == FlowType.assente ? null : FlowType.assente,
            ),
          ),
        ),
        const SizedBox(width: MetraSpacing.s2),
        Expanded(
          child: _FlowChip(
            label: l10n.daily_entry_flow_chip_mestruazioni,
            flowType: FlowType.mestruazioni,
            selected: selected,
            accent: accent,
            accentText: accentText,
            borderSubtle: borderSubtle,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            onTap: () => onChanged(
              selected == FlowType.mestruazioni ? null : FlowType.mestruazioni,
            ),
          ),
        ),
        const SizedBox(width: MetraSpacing.s2),
        Expanded(
          child: _FlowChip(
            label: l10n.daily_entry_flow_chip_spotting,
            flowType: FlowType.spotting,
            selected: selected,
            accent: accent,
            accentText: accentText,
            borderSubtle: borderSubtle,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            onTap: () => onChanged(
              selected == FlowType.spotting ? null : FlowType.spotting,
            ),
          ),
        ),
      ],
    );
  }
}

class _FlowChip extends StatelessWidget {
  const _FlowChip({
    required this.label,
    required this.flowType,
    required this.selected,
    required this.accent,
    required this.accentText,
    required this.borderSubtle,
    required this.textPrimary,
    required this.textSecondary,
    required this.onTap,
  });

  final String label;
  final FlowType flowType;
  final FlowType? selected;
  final Color accent;
  final Color accentText;
  final Color borderSubtle;
  final Color textPrimary;
  final Color textSecondary;
  final VoidCallback onTap;

  bool get _isSelected => selected == flowType;

  @override
  Widget build(BuildContext context) {
    final isAssente = flowType == FlowType.assente;

    Widget chip;
    if (isAssente && _isSelected) {
      // Spec § 7.1: bg rgba(43,37,33,0.08), dashed inchiostro 0.32, width 1.5.
      chip = Container(
        height: 44,
        decoration: BoxDecoration(
          color: textPrimary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(MetraRadius.md),
        ),
        child: CustomPaint(
          painter: _DashedRoundedRectPainter(
            color: textPrimary.withValues(alpha: 0.32),
            radius: MetraRadius.md,
          ),
          child: _ChipContent(
            label: label,
            textColor: textPrimary,
            isSelected: true,
          ),
        ),
      );
    } else {
      // Solid border chip.
      final (bgColor, borderColor, borderWidth) =
          switch ((flowType, _isSelected)) {
        // ${terracotta}22 bg, ${terracotta}BB border, 1.5px
        (FlowType.mestruazioni, true) => (
            accent.withValues(alpha: 0.133),
            accent.withValues(alpha: 0.733),
            1.5,
          ),
        // ${terracotta}14 bg, ${terracotta}66 border, 1.5px
        (FlowType.spotting, true) => (
            accent.withValues(alpha: 0.078),
            accent.withValues(alpha: 0.400),
            1.5,
          ),
        // Idle: rgba(0.04) bg, rgba(0.10) border, 1px
        _ => (textPrimary.withValues(alpha: 0.04), borderSubtle, 1.0),
      };

      chip = Container(
        height: 44,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(MetraRadius.md),
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        child: _ChipContent(
          label: label,
          textColor: _isSelected ? accentText : textSecondary,
          isSelected: _isSelected,
        ),
      );
    }

    return Semantics(
      label: label,
      toggled: _isSelected,
      button: true,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: chip,
      ),
    );
  }
}

class _ChipContent extends StatelessWidget {
  const _ChipContent({
    required this.label,
    required this.textColor,
    required this.isSelected,
  });

  final String label;
  final Color textColor;

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Center(
        child: Text(
          label,
          style: MetraTypography.caption.copyWith(
            color: textColor,
            fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

/// Draws a dashed rounded-rect border with the given [color] and corner [radius].
class _DashedRoundedRectPainter extends CustomPainter {
  const _DashedRoundedRectPainter({
    required this.color,
    required this.radius,
  });

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    const dashWidth = 4.0;
    const dashSpace = 3.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Radius.circular(radius),
        ),
      );

    final pathMetrics = path.computeMetrics();
    for (final metric in pathMetrics) {
      double distance = 0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(
            distance,
            (distance + dashWidth).clamp(0, metric.length),
          ),
          paint,
        );
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRoundedRectPainter old) =>
      old.color != color || old.radius != radius;
}
