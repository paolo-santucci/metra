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
import 'package:google_fonts/google_fonts.dart';

// Typography sourced from mockup/tokens.json §typography.
// Wordmark: 'Mētra' — literal ē (U+0113), never a Unicode escape.
abstract final class MetraTypography {
  // Scale entries map 1:1 to tokens.json §typography.scale.
  static TextStyle get displayXl => GoogleFonts.dmSerifDisplay(
        fontSize: 48,
        height: 1.2,
        letterSpacing: -0.01 * 48,
      );

  static TextStyle get displayLg => GoogleFonts.dmSerifDisplay(
        fontSize: 40,
        height: 1.2,
        letterSpacing: -0.01 * 40,
      );

  static TextStyle get displayMd => GoogleFonts.dmSerifDisplay(
        fontSize: 32,
        height: 1.2,
        letterSpacing: -0.01 * 32,
      );

  static TextStyle get titleLg => GoogleFonts.dmSerifDisplay(
        fontSize: 26,
        height: 1.3,
      );

  static TextStyle get titleMd => GoogleFonts.dmSerifDisplay(
        fontSize: 22,
        height: 1.3,
      );

  static TextStyle get titleSm => GoogleFonts.inter(
        fontSize: 20,
        height: 1.3,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get bodyLg => GoogleFonts.inter(
        fontSize: 18,
        height: 1.5,
      );

  static TextStyle get body => GoogleFonts.inter(
        fontSize: 16,
        height: 1.5,
      );

  static TextStyle get caption => GoogleFonts.inter(
        fontSize: 13,
        height: 1.4,
        letterSpacing: 0.01 * 13,
      );

  static TextStyle get tiny => GoogleFonts.inter(
        fontSize: 12,
        height: 1.4,
        letterSpacing: 0.01 * 12,
        fontWeight: FontWeight.w500,
      );

  // Wordmark: always use this constant; never reconstruct it inline.
  // ē = U+0113 — a literal character per CLAUDE.md §8.3.
  static const String wordmark = 'Mētra';

  static TextTheme toTextTheme(Color textColor) => TextTheme(
        displayLarge: displayXl.copyWith(color: textColor),
        displayMedium: displayLg.copyWith(color: textColor),
        displaySmall: displayMd.copyWith(color: textColor),
        headlineLarge: titleLg.copyWith(color: textColor),
        headlineMedium: titleMd.copyWith(color: textColor),
        headlineSmall: titleSm.copyWith(color: textColor),
        bodyLarge: bodyLg.copyWith(color: textColor),
        bodyMedium: body.copyWith(color: textColor),
        bodySmall: caption.copyWith(color: textColor),
        labelSmall: tiny.copyWith(color: textColor),
      );
}
