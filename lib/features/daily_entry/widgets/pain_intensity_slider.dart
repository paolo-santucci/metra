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
import '../../../l10n/app_localizations.dart';

/// Discrete slider for pain intensity (0–3).
///
/// Hidden when [enabled] is false. When shown, the slider reveals itself with
/// a 240ms vertical slide + fade (80ms when reduce-motion is active).
/// Labels: 0=none, 1=mild, 2=moderate, 3=severe.
class PainIntensitySlider extends StatelessWidget {
  const PainIntensitySlider({
    super.key,
    required this.enabled,
    required this.value,
    required this.onChanged,
  });

  final bool enabled;

  /// Current value 0–3; null is treated as 0.
  final int? value;

  final ValueChanged<int> onChanged;

  static const int _min = 0;
  static const int _max = 3;

  String _label(int v, AppLocalizations l10n) {
    switch (v) {
      case 0:
        return l10n.daily_entry_pain_none;
      case 1:
        return l10n.daily_entry_pain_mild;
      case 2:
        return l10n.daily_entry_pain_moderate;
      case 3:
        return l10n.daily_entry_pain_severe;
      default:
        return l10n.daily_entry_pain_none;
    }
  }

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.of(context).disableAnimations
        ? const Duration(milliseconds: 80)
        : const Duration(milliseconds: 240);

    // Theme reads are unconditional so they are available for the slider
    // content regardless of whether enabled is checked inside the switcher.
    // safe: delegates registered in MetraApp
    final l10n = AppLocalizations.of(context)!;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark
        ? MetraColors.dark.textSecondary
        : MetraColors.light.textSecondary;
    final activeColor =
        isDark ? MetraColors.dark.accentFlow : MetraColors.light.accentFlow;
    final inactiveColor =
        isDark ? MetraColors.dark.borderSubtle : MetraColors.light.borderSubtle;

    final current = (value ?? 0).clamp(_min, _max);

    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeOut,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SizeTransition(
          sizeFactor: animation,
          axisAlignment: -1,
          child: child,
        ),
      ),
      child: enabled
          ? _SliderContent(
              key: const ValueKey<bool>(true),
              current: current,
              label: _label(current, l10n),
              labelColor: labelColor,
              activeColor: activeColor,
              inactiveColor: inactiveColor,
              onChanged: onChanged,
            )
          : const SizedBox.shrink(key: ValueKey<bool>(false)),
    );
  }
}

/// Extracted slider body so [AnimatedSwitcher] can key on it cleanly.
class _SliderContent extends StatelessWidget {
  const _SliderContent({
    super.key,
    required this.current,
    required this.label,
    required this.labelColor,
    required this.activeColor,
    required this.inactiveColor,
    required this.onChanged,
  });

  final int current;
  final String label;
  final Color labelColor;
  final Color activeColor;
  final Color inactiveColor;
  final ValueChanged<int> onChanged;

  static const int _min = 0;
  static const int _max = 3;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: label,
          slider: true,
          value: label,
          child: SliderTheme(
            data: SliderThemeData(
              activeTrackColor: activeColor,
              inactiveTrackColor: inactiveColor,
              thumbColor: activeColor,
              overlayColor: activeColor.withValues(alpha: 0.2),
              trackHeight: 4,
            ),
            child: Slider(
              value: current.toDouble(),
              min: _min.toDouble(),
              max: _max.toDouble(),
              divisions: _max - _min,
              onChanged: (v) => onChanged(v.round()),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(
            left: MetraSpacing.s4,
            bottom: MetraSpacing.s2,
          ),
          child: Text(
            label,
            style: MetraTypography.caption.copyWith(color: labelColor),
          ),
        ),
      ],
    );
  }
}
