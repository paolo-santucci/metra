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

// Design tokens sourced from mockup/tokens.json §colors.
// Field names mirror JSON keys. Never add a color here that is not in tokens.json.
@immutable
final class _LightPalette {
  const _LightPalette();

  // Primitive palette
  final Color sand = const Color(0xFFF4EDE2);
  final Color terracotta = const Color(0xFFC87456);
  final Color terracottaDeep = const Color(0xFF9B4E32);
  final Color dustyOchre = const Color(0xFFD4A26A);
  final Color dustyOchreDeep = const Color(0xFF8A6332);
  final Color nightLavender = const Color(0xFF5B4E7A);
  final Color moss = const Color(0xFF7A8471);
  final Color mossDeep = const Color(0xFF4F5A47);
  final Color ink = const Color(0xFF2B2521);
  final Color inkSoft = const Color(0xFF5A4F47);
  final Color surfaceRaised = const Color(0xFFFBF6EC);
  final Color surfaceSunken = const Color(0xFFECE4D6);
  final Color divider = const Color(0xFFDCD2C0);
  // rgba(43,37,33,0.32) → alpha=round(0.32*255)=82=0x52, RGB=0x2B2521
  final Color overlayScrim = const Color(0x522B2521);
  final Color textDisabled = const Color(0xFF8C8378);

  // Semantic aliases — use these in widgets, not the primitives above.
  Color get bgPrimary => sand;
  Color get bgSurface => surfaceRaised;
  Color get bgSunken => surfaceSunken;
  Color get textPrimary => ink;
  Color get textSecondary => inkSoft;
  Color get textOnSand => terracottaDeep;
  Color get textOnAccent => sand;
  Color get accentFlow => terracotta;
  Color get accentFlowStrong => terracottaDeep;
  Color get accentPrediction => nightLavender;
  Color get accentWarmth => dustyOchre;
  Color get accentWarmthStrong => dustyOchreDeep;
  Color get accentConfirmation => moss;
  Color get accentConfirmationStrong => mossDeep;
  Color get borderSubtle => divider;
  Color get borderStrong => inkSoft;
  Color get stateError => terracottaDeep;
  Color get stateSuccess => mossDeep;
  Color get stateWarning => dustyOchreDeep;
  Color get focusRing => nightLavender;
  Color get bgOverlay => overlayScrim;
  Color get textDisabledColor => textDisabled;
}

@immutable
final class _DarkPalette {
  const _DarkPalette();

  // Primitive palette
  final Color deepNight = const Color(0xFF1A1410);
  final Color deepNightRaised = const Color(0xFF241D17);
  final Color deepNightSunken = const Color(0xFF15100C);
  final Color mutedTerracotta = const Color(0xFFB86848);
  final Color mutedTerracottaSoft = const Color(0xFFD88B6E);
  final Color lightLavender = const Color(0xFF9B8FBF);
  final Color warmOchreDark = const Color(0xFFC09060);
  final Color mossDark = const Color(0xFF8A9580);
  final Color ivory = const Color(0xFFEDE4D3);
  final Color ivorySoft = const Color(0xFFC8BFAE);
  final Color dividerDark = const Color(0xFF382E26);
  // rgba(0,0,0,0.56) → alpha=round(0.56*255)=143=0x8F
  final Color overlayScrim = const Color(0x8F000000);
  final Color textDisabled = const Color(0xFF6B6358);

  // Semantic aliases
  Color get bgPrimary => deepNight;
  Color get bgSurface => deepNightRaised;
  Color get bgSunken => deepNightSunken;
  Color get textPrimary => ivory;
  Color get textSecondary => ivorySoft;
  Color get textOnSand => mutedTerracottaSoft;
  Color get textOnAccent => deepNight;
  Color get accentFlow => mutedTerracotta;
  Color get accentFlowStrong => mutedTerracottaSoft;
  Color get accentPrediction => lightLavender;
  Color get accentWarmth => warmOchreDark;
  Color get accentWarmthStrong => warmOchreDark;
  Color get accentConfirmation => mossDark;
  Color get accentConfirmationStrong => mossDark;
  Color get borderSubtle => dividerDark;
  Color get borderStrong => ivorySoft;
  Color get stateError => mutedTerracottaSoft;
  Color get stateSuccess => mossDark;
  Color get stateWarning => warmOchreDark;
  Color get focusRing => lightLavender;
  Color get bgOverlay => overlayScrim;
  Color get textDisabledColor => textDisabled;
}

abstract final class MetraColors {
  // ignore: library_private_types_in_public_api
  static const _LightPalette light = _LightPalette();
  // ignore: library_private_types_in_public_api
  static const _DarkPalette dark = _DarkPalette();
}
