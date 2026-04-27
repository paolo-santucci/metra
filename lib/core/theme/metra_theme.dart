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
        tertiary: colors.dustyOchreDeep,
        onTertiary: colors.sand,
        surface: colors.surfaceRaised,
        onSurface: colors.ink,
        onSurfaceVariant: colors.inkSoft,
        outline: colors.divider,
        outlineVariant: colors.inkSoft,
        error: colors.terracottaDeep,
        onError: colors.sand,
        shadow: const Color(0x142B2521),
        scrim: colors.overlayScrim,
      ),
      textTheme: MetraTypography.toTextTheme(colors.ink),
      cardTheme: CardThemeData(
        color: colors.surfaceRaised,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.divider),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceSunken,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      dividerColor: colors.divider,
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
      useMaterial3: true,
    );
  }
}
