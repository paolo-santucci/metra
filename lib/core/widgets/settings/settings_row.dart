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
import 'package:metra/core/theme/metra_colors.dart';
import 'package:metra/core/theme/metra_spacing.dart';
import 'package:metra/core/theme/metra_typography.dart';
import 'package:metra/core/widgets/settings/settings_row_internals.dart'
    show buildSettingsRowTrailing;

/// Variant of a [SettingsRow].
enum _RowVariant { nav, staticInfo, toggle, action, destructive }

/// A single settings row in the Métra settings atom system.
///
/// Five named constructors map to the five visual variants described in
/// ui-design-bible.md §18.5 and spec FR-06 / FR-07.
///
/// Render contract (NFR-05 / EC-10):
/// - minHeight 56 dp (NOT a fixed height — grows with text scale).
/// - 20 dp symmetric horizontal padding.
/// - Label: Inter 15 / w500 / textPrimary (or accentFlowText for destructive).
/// - Value: Inter 14 / w400 / textSecondary (used by .nav and .staticInfo).
/// - Chevron: 16 dp / ink-at-40% (used by .nav).
/// - No Material ripple — taps are handled via GestureDetector.
class SettingsRow extends StatelessWidget {
  /// Navigation row: label + optional value text + chevron, fires [onTap].
  const SettingsRow.nav({
    super.key,
    required this.label,
    this.semanticsLabel,
    this.valueText,
    required VoidCallback this.onTap,
  })  : _variant = _RowVariant.nav,
        toggle = null,
        onChanged = null;

  /// Static-info row: label + optional value text, pointer-events suppressed.
  const SettingsRow.staticInfo({
    super.key,
    required this.label,
    this.semanticsLabel,
    this.valueText,
  })  : _variant = _RowVariant.staticInfo,
        toggle = null,
        onTap = null,
        onChanged = null;

  /// Toggle row: label + a pre-built toggle [Widget].
  ///
  /// The caller is responsible for constructing the toggle widget (e.g.
  /// [MetraToggle] or [Switch]). Row tap does NOT fire the toggle's
  /// [onChanged] — only direct interaction with the toggle widget itself
  /// triggers that callback.
  const SettingsRow.toggle({
    super.key,
    required this.label,
    this.semanticsLabel,
    required this.toggle,
    this.onChanged,
  })  : _variant = _RowVariant.toggle,
        valueText = null,
        onTap = null;

  /// Action row: label only, transparent background, fires [onTap] on tap.
  const SettingsRow.action({
    super.key,
    required this.label,
    this.semanticsLabel,
    required VoidCallback this.onTap,
  })  : _variant = _RowVariant.action,
        valueText = null,
        toggle = null,
        onChanged = null;

  /// Destructive row: terracotta-tinted background + [accentFlowText] label.
  const SettingsRow.destructive({
    super.key,
    required this.label,
    this.semanticsLabel,
    required VoidCallback this.onTap,
  })  : _variant = _RowVariant.destructive,
        valueText = null,
        toggle = null,
        onChanged = null;

  final _RowVariant _variant;
  final String label;
  final String? semanticsLabel;
  // Text value beside chevron (.nav) or trailing text (.staticInfo).
  final String? valueText;
  // Pre-built toggle widget passed to .toggle constructor.
  final Widget? toggle;
  final VoidCallback? onTap;
  // Kept for forward-compatibility; callers that want to react to the toggle
  // should pass onChanged on the toggle widget itself.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = MetraColors.of(context);

    final bool isDestructive = _variant == _RowVariant.destructive;
    final bool isStatic = _variant == _RowVariant.staticInfo;
    final bool isToggle = _variant == _RowVariant.toggle;

    final labelColor =
        isDestructive ? colors.accentFlowText : colors.textPrimary;
    final bgColor =
        isDestructive ? colors.accentFlow.withAlpha(0x0D) : Colors.transparent;

    final Widget? trailing = switch (_variant) {
      _RowVariant.nav => buildSettingsRowTrailing(
          colors: colors,
          showChevron: true,
          valueText: valueText,
        ),
      _RowVariant.staticInfo => buildSettingsRowTrailing(
          colors: colors,
          valueText: valueText,
        ),
      _RowVariant.toggle => toggle,
      _RowVariant.action || _RowVariant.destructive => null,
    };

    // minHeight: 56 dp via ConstrainedBox — NFR-05 / EC-10.
    // Allows the row to grow beyond 56 dp at large text scale.
    final Widget rowContent = Container(
      color: bgColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: MetraSpacing.s5, // 20 dp
          vertical: MetraSpacing.s2, // 8 dp vertical breathing room
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: MetraSpacing.sp56),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: MetraTypography.listTitle.copyWith(color: labelColor),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
        ),
      ),
    );

    if (isStatic) {
      return Semantics(
        label: semanticsLabel ?? label,
        child: IgnorePointer(child: rowContent),
      );
    }

    if (isToggle) {
      // Row tap must NOT fire the toggle's onChanged.
      // Only direct interaction with the toggle widget fires that.
      return Semantics(
        label: semanticsLabel ?? label,
        child: rowContent,
      );
    }

    return Semantics(
      label: semanticsLabel ?? label,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: rowContent,
      ),
    );
  }
}
