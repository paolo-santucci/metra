import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Renders a bible-defined icon from an inner-SVG fragment.
///
/// [svgBody] is the content inside `<svg viewBox="0 0 24 24">`, with
/// `{stroke}` and `{fill}` as color placeholders.
/// For stroke icons: stroke-based paths use `{stroke}` and fill="none".
/// For filled icons: [filled] = true; `{fill}` is used for fill color.
class MetraIcon extends StatelessWidget {
  const MetraIcon({
    super.key,
    required this.svgBody,
    this.size = 24.0,
    this.color,
    this.strokeWidth = 1.5,
    this.filled = false,
  });

  final String svgBody;
  final double size;
  final Color? color;
  final double strokeWidth;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? IconTheme.of(context).color ?? Colors.black;
    final colorHex = _colorToHex(effectiveColor);
    final body = svgBody
        .replaceAll('{stroke}', colorHex)
        .replaceAll('{fill}', colorHex)
        .replaceAll('{sw}', strokeWidth.toStringAsFixed(1));
    const svgString =
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">';
    final svg = SvgPicture.string(
      '$svgString$body</svg>',
      width: size,
      height: size,
    );
    final alpha = effectiveColor.a;
    if (alpha < 0.999) {
      return Opacity(opacity: alpha, child: svg);
    }
    return svg;
  }

  static String _colorToHex(Color color) {
    final r = (color.r * 255).round().toStringRadixPadded(16);
    final g = (color.g * 255).round().toStringRadixPadded(16);
    final b = (color.b * 255).round().toStringRadixPadded(16);
    return '#$r$g$b';
  }
}

extension on int {
  String toStringRadixPadded(int radix) => toRadixString(radix).padLeft(2, '0');
}

// Shared stroke attributes used in every stroke path/rect/circle fragment.
// Paths must contain `stroke="{stroke}" stroke-width="{sw}"` plus round caps.
const _sc =
    'stroke="{stroke}" stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round" fill="none"';

/// Catalog of bible icons, stored as inner-SVG body fragments.
///
/// Stroke icons use `{stroke}` and `{sw}` placeholders.
/// Filled icons use `{fill}` placeholder.
abstract final class MetraIcons {
  // ── Stroke icons (viewBox 24×24, fill:none, round caps+joins) ──────────

  static const String chevronRight = '<path d="M9 6l6 6-6 6" $_sc/>';

  static const String chevronLeft = '<path d="M15 6l-6 6 6 6" $_sc/>';

  static const String chevronDown = '<path d="M6 9l6 6 6-6" $_sc/>';

  static const String x = '<path d="M18 6L6 18M6 6l12 12" $_sc/>';

  static const String lock =
      '<rect x="5" y="11" width="14" height="10" rx="2" $_sc/>'
      '<path d="M8 11V7a4 4 0 0 1 8 0v4" $_sc/>';

  static const String cloud =
      '<path d="M18 10h-1.26A8 8 0 1 0 9 20h9a5 5 0 0 0 0-10z" $_sc/>';

  static const String drop =
      '<path d="M12 3C12 3 5 10 5 15a7 7 0 0 0 14 0c0-5-7-12-7-12z" $_sc/>';

  static const String wave =
      '<path d="M3 12 Q6 9 9 12 Q12 15 15 12 Q18 9 21 12" $_sc/>';

  static const String plus = '<path d="M12 5v14M5 12h14" $_sc/>';

  static const String check = '<path d="M5 12l5 5 9-9" $_sc/>';

  static const String settings = '<circle cx="12" cy="12" r="3" $_sc/>'
      '<path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41'
      'M2 12h2M20 12h2M4.93 19.07l1.41-1.41M17.66 6.34l1.41-1.41" $_sc/>';

  static const String chart = '<path d="M4 20h16" $_sc/>'
      '<rect x="5" y="11" width="3" height="9" rx="1" $_sc/>'
      '<rect x="10.5" y="7" width="3" height="13" rx="1" $_sc/>'
      '<rect x="16" y="4" width="3" height="16" rx="1" $_sc/>';

  static const String calendar =
      '<rect x="3" y="4" width="18" height="18" rx="2" $_sc/>'
      '<path d="M16 2v4M8 2v4M3 10h18" $_sc/>';

  static const String note =
      '<path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7" $_sc/>'
      '<path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4z" $_sc/>';

  static const String wifi = '<path d="M5 12.55a11 11 0 0 1 14.08 0" $_sc/>'
      '<path d="M1.42 9a16 16 0 0 1 21.16 0" $_sc/>'
      '<path d="M8.53 16.11a6 6 0 0 1 6.95 0" $_sc/>'
      '<circle cx="12" cy="20" r="1" fill="{stroke}" stroke="none"/>';

  static const String battery =
      '<rect x="1" y="6" width="18" height="12" rx="2" $_sc/>'
      '<path d="M23 13v-2" $_sc/>'
      '<rect x="3" y="8" width="12" height="8" rx="1"'
      ' fill="{stroke}" fill-opacity="0.55" stroke="none"/>';

  static const String filter = '<path d="M22 3H2l8 9.46V19l4 2v-8.54z" $_sc/>';

  static const String info = '<circle cx="12" cy="12" r="9" $_sc/>'
      '<path d="M12 8v1M12 12v4" $_sc/>';

  static const String leaf =
      '<path d="M5 19C5 12 8 5 19 5c0 11-7 14-14 14z" $_sc/>';

  static const String export_ = '<path d="M12 16V4M8 8l4-4 4 4" $_sc/>'
      '<path d="M20 16v2a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2v-2" $_sc/>';

  static const String moonCrescent =
      '<path d="M12 3a9 9 0 1 0 9 9 6.5 6.5 0 0 1-9-9z" $_sc/>';

  static const String starSmall =
      '<path d="M12 4l1.5 4.5H18l-3.75 2.75 1.5 4.5L12 13l-3.75 2.75 1.5-4.5L6 8.5h4.5z" $_sc/>';

  // ── DataIcons (filled, viewBox 24×24) ────────────────────────────────────

  static const String dropFilled =
      '<path d="M12 3C12 3 5 10 5 15a7 7 0 0 0 14 0c0-5-7-12-7-12z" fill="{fill}"/>';

  static const String dropOutline =
      '<path d="M12 3C12 3 5 10 5 15a7 7 0 0 0 14 0c0-5-7-12-7-12z"'
      ' fill="none" stroke="{fill}" stroke-width="1.5"'
      ' stroke-linecap="round" stroke-linejoin="round"/>';

  static const String moonCrescentFilled =
      '<path d="M12 3a9 9 0 1 0 9 9 6.5 6.5 0 0 1-9-9z" fill="{fill}"/>';

  static const String starSmallFilled =
      '<path d="M12 4l1.5 4.5H18l-3.75 2.75 1.5 4.5L12 13l-3.75 2.75 1.5-4.5L6 8.5h4.5z" fill="{fill}"/>';

  static const String zapFilled =
      '<path d="M13 3L5 14L11 14L9 21L19 11L13 11Z" fill="{fill}"/>';
}
