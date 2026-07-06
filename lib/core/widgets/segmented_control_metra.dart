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

// Lets widget tests uniquely target the decorated track Container — plain
// find.byType(Container) also matches AnimatedContainer's own internal
// Container implementation (one per segment), which is not the track.
@visibleForTesting
const Key segmentedControlTrackKey = ValueKey('segmentedControlTrack');

/// 2–3 segment toggle control.
///
/// Implements WAI-ARIA tablist pattern via Semantics: the container has
/// `label` for context, each option announces its selection state via
/// [Semantics.selected].
///
/// FR-12 tap-target note: Flutter's hit-testing gates on every ancestor
/// RenderBox's own declared `size` (`RenderBox.hitTest` checks
/// `size.contains(position)` before recursing into children), so a tap
/// region larger than the painted 34/36 dp pill cannot be nested inside the
/// track's own `Row` without also growing that Row (and the visible track
/// background) to match. Instead, the invisible 44×44 dp hit-region lives in
/// a parallel overlay `Row`, stacked over the unmodified visual track — see
/// [build] — so the painted pill and track stay pixel-identical while the
/// hit-testable area grows to meet the NFR-04 floor.
class SegmentedControlMetra extends StatelessWidget {
  const SegmentedControlMetra({
    super.key,
    required this.segments,
    required this.selectedIndex,
    required this.onChanged,
    this.semanticsLabel,
  }) : assert(segments.length >= 2 && segments.length <= 3);

  final List<String> segments;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  /// FR-07: optional override for the container Semantics label. `null`
  /// preserves the original hard-coded 'Vista' label used by the Archivio
  /// toggle — additive/non-breaking for that existing call site.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = MetraColors.of(context);
    final activeTextStyle = MetraTypography.caption.copyWith(
      color: colors.textPrimary,
      fontWeight: FontWeight.w500,
    );
    // § 5.4 FR-12 (2026-07-05): idle-label alpha raised from 0.50 (both
    // themes) to 0.68 light / 0.65 dark so the composited contrast over the
    // tinted track clears the NFR-04 ≥4.5:1 floor (was ≈2.9:1 light /
    // ≈4.0:1 dark). Both replacements are existing catalogued alpha stops,
    // not invented values.
    final inactiveTextStyle = MetraTypography.caption.copyWith(
      color: colors.textPrimary.withValues(alpha: isDark ? 0.65 : 0.68),
      fontWeight: FontWeight.w400,
    );

    final List<Widget> pills = [];
    final List<Widget> hitRegions = [];
    for (var i = 0; i < segments.length; i++) {
      if (i > 0) {
        pills.add(const SizedBox(width: 2));
        hitRegions.add(const SizedBox(width: 2));
      }
      final isActive = i == selectedIndex;
      final style = isActive ? activeTextStyle : inactiveTextStyle;
      pills.add(
        _Pill(
          label: segments[i],
          isActive: isActive,
          isDark: isDark,
          style: style,
          colors: colors,
        ),
      );
      hitRegions.add(
        _HitRegion(
          label: segments[i],
          isActive: isActive,
          style: style,
          onTap: () => onChanged(i),
        ),
      );
    }

    return Semantics(
      label: semanticsLabel ?? 'Vista',
      explicitChildNodes: true,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            key: segmentedControlTrackKey,
            decoration: BoxDecoration(
              color: colors.bgSunken,
              borderRadius: BorderRadius.circular(MetraRadius.smm),
            ),
            padding: const EdgeInsets.all(3),
            child: Row(mainAxisSize: MainAxisSize.min, children: pills),
          ),
          Row(mainAxisSize: MainAxisSize.min, children: hitRegions),
        ],
      ),
    );
  }
}

/// The visible, decorated segment pill. Paint-only — no gesture/semantics
/// (those live on [_HitRegion]); its size/appearance are unchanged by FR-12.
class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.isActive,
    required this.isDark,
    required this.style,
    required this.colors,
  });

  final String label;
  final bool isActive;
  final bool isDark;
  final TextStyle style;
  final MetraPalette colors;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      constraints: const BoxConstraints(minHeight: 36, minWidth: 44),
      padding: const EdgeInsets.symmetric(
        horizontal: MetraSpacing.s4,
        vertical: MetraSpacing.s2,
      ),
      decoration: BoxDecoration(
        color: isActive ? colors.bgSurface : Colors.transparent,
        borderRadius: BorderRadius.circular(MetraRadius.sm),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: isDark
                      ? const Color(0x1F000000)
                      : const Color(0x1F2B2521),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: Text(label, style: style),
    );
  }
}

/// FR-12 invisible 44×44 dp hit-region, centered on the [_Pill] above it via
/// the parent Stack's `Alignment.center`. Mirrors the pill's horizontal
/// padding + text style so its natural width matches the pill's painted
/// width exactly (both clamp to the same `minWidth: 44` floor), keeping the
/// enlarged tap area aligned over pills of any label length.
class _HitRegion extends StatelessWidget {
  const _HitRegion({
    required this.label,
    required this.isActive,
    required this.style,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final TextStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      selected: isActive,
      button: true,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: MetraSpacing.s4),
            // A raw RichText (not Text) reproduces the pill's width formula
            // (max(intrinsic text width, minWidth)) for width-matching only.
            // Using RichText directly — rather than Text — keeps this
            // invisible measurement helper out of find.text() results
            // (which ignore standalone RichText by default), so it can
            // never be confused with real, user-facing label text.
            child: RichText(
              textScaler: MediaQuery.textScalerOf(context),
              text: TextSpan(
                text: label,
                style: DefaultTextStyle.of(context)
                    .style
                    .merge(style)
                    .copyWith(color: Colors.transparent),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
