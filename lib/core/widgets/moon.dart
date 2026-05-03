import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Renders a moon in one of five phases using bible-defined SVG geometry.
///
/// Phases:
///   0 = new moon    — outer circle only, no fill
///   1 = waxing crescent
///   2 = first quarter
///   3 = waxing gibbous
///   4 = full moon
class MetraMoon extends StatelessWidget {
  const MetraMoon({
    super.key,
    required this.phase,
    this.size = 24.0,
    this.color,
  });

  final int phase;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? IconTheme.of(context).color ?? Colors.black;
    final hex = _colorToHex(effectiveColor);
    final clampedPhase = phase.clamp(0, 4);

    final fillFragment = _fills[clampedPhase];
    final svgString =
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
        '<circle cx="12" cy="12" r="9" stroke="$hex" stroke-width="1.3" fill="none"/>'
        '${fillFragment.replaceAll('{fill}', hex)}'
        '</svg>';

    return SvgPicture.string(svgString, width: size, height: size);
  }

  static String _colorToHex(Color color) {
    final r = (color.r * 255).round().toStringRadixPadded(2);
    final g = (color.g * 255).round().toStringRadixPadded(2);
    final b = (color.b * 255).round().toStringRadixPadded(2);
    return '#$r$g$b';
  }

  // Inner fill fragments per phase; {fill} is replaced with the resolved hex color.
  // Phase 0: no fill — empty string.
  static const List<String> _fills = [
    '',
    '<path d="M12 3a9 9 0 0 0 0 18 6 6 0 0 1 0-18z" fill="{fill}" fill-opacity="0.8"/>',
    '<path d="M12 3v18a9 9 0 0 0 0-18z" fill="{fill}" fill-opacity="0.8"/>',
    '<path d="M12 3a9 9 0 0 1 0 18 4 4 0 0 0 0-18z" fill="{fill}" fill-opacity="0.8"/>',
    '<circle cx="12" cy="12" r="9" fill="{fill}" fill-opacity="0.8"/>',
  ];
}

extension on int {
  String toStringRadixPadded(int radix) => toRadixString(radix).padLeft(2, '0');
}
