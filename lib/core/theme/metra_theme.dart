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
import 'metra_colors.dart';
import 'metra_typography.dart';

// MetraTheme provides ThemeData for light and dark modes.
// Dark mode is DESIGNED (not an inversion) per CLAUDE.md §8.1 and §9.
abstract final class MetraTheme {
  static ThemeData light() {
    const colors = MetraColors.light;
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: colors.sand,
      colorScheme: ColorScheme(
        brightness: Brightness.light,
        primary: colors.terracottaDeep,
        onPrimary: colors.sand,
        primaryContainer: colors.terracotta,
        onPrimaryContainer: colors.sand,
        secondary: colors.nightLavender,
        onSecondary: colors.sand,
        tertiary: colors.dustyOchre,
        onTertiary: colors.sand,
        surface: colors.surfaceRaised,
        onSurface: colors.ink,
        onSurfaceVariant: colors.textSecondary, // ink @ 0x66 — § 1.1
        outline: colors.borderSubtle, // ink @ 0x12 — § 1.5
        outlineVariant: colors.borderStrong, // ink @ 0x24 — § 1.5
        error: colors.terracottaDeep,
        onError: colors.sand,
        shadow: const Color(0x1F2B2521), // rgba(43,37,33,0.12) — § 1.6
        scrim: colors.overlayScrim,
      ),
      textTheme: MetraTypography.toTextTheme(colors.ink),
      cardTheme: CardThemeData(
        color: colors.surfaceRaised,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.borderSubtle), // ink @ 0x12 — § 1.5
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.bgSunken, // ink @ 0x0A — § 1.1
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      dividerColor: colors.borderSubtle, // ink @ 0x12 — § 1.5
      navigationBarTheme: NavigationBarThemeData(
        // Wave 0.2 will replace NavigationBar with a custom BackdropFilter tab bar.
        // These styles are transitional until that rebuild lands.
        indicatorColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: colors.terracotta, size: 24);
          }
          return IconThemeData(
            color: colors.ink.withValues(alpha: 0.30),
            size: 24,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colors.terracotta,
            );
          }
          return GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w400,
            color: colors.ink.withValues(alpha: 0.55),
          );
        }),
      ),
      useMaterial3: true,
    );
  }

  static ThemeData dark() {
    const colors = MetraColors.dark;
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: colors.deepNight,
      colorScheme: ColorScheme(
        brightness: Brightness.dark,
        primary: colors.mutedTerracottaSoft,
        onPrimary: colors.deepNight,
        primaryContainer: colors.mutedTerracotta,
        onPrimaryContainer: colors.deepNight,
        secondary: colors.lightLavender,
        onSecondary: colors.deepNight,
        tertiary: colors.warmOchreDark,
        onTertiary: colors.deepNight,
        surface: colors.deepNightRaised,
        onSurface: colors.ivory,
        onSurfaceVariant: colors.ivorySoft,
        outline: colors.dividerDark,
        outlineVariant: colors.ivorySoft,
        error: colors.mutedTerracottaSoft,
        onError: colors.deepNight,
        shadow: const Color(0x661A1410),
        scrim: colors.overlayScrim,
      ),
      textTheme: MetraTypography.toTextTheme(colors.ivory),
      cardTheme: CardThemeData(
        color: colors.deepNightRaised,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.dividerDark),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.deepNightSunken,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      dividerColor: colors.dividerDark,
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: colors.mutedTerracotta, size: 24);
          }
          return IconThemeData(
            color: colors.ivory.withValues(alpha: 0.30),
            size: 24,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colors.mutedTerracotta,
            );
          }
          return GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w400,
            color: colors.ivory.withValues(alpha: 0.55),
          );
        }),
      ),
      useMaterial3: true,
    );
  }
}
