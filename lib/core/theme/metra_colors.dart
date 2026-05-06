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

// MetraPalette is the single interface for brightness-aware color access.
// Use MetraColors.of(context) in widgets — never MetraColors.light/dark directly.
// MetraTheme uses the concrete types (_LightPalette / _DarkPalette) to access
// fields that are not in the interface (e.g. nightLavender, surfaceRaised).
abstract interface class MetraPalette {
  // ── Primitive aliases ────────────────────────────────────────────────────────
  // Direct access to canonical paint values needed by widgets that apply inline
  // alpha tints (e.g. ink.withValues(alpha: 0.10)). Prefer semantic aliases.
  Color get ink; // primary text/outline primitive
  Color get sand; // primary background primitive
  Color get terracotta; // primary accent primitive
  Color get terracottaDeep; // deep accent (tc_scura / tc_chiara)
  Color get dustyOchre; // warm accent primitive
  Color get malva; // pain accent primitive

  // ── Semantic aliases ─────────────────────────────────────────────────────────
  Color get bgPrimary;
  Color get bgSurface;
  Color get bgSunken;
  Color get textPrimary;
  Color get textSecondary;
  Color get textOnSand;
  Color get textOnAccent;
  Color get accentFlow;
  Color get accentFlowStrong;
  Color get accentFlowText;
  Color get accentPrediction;
  Color get accentWarmth;
  Color get accentWarmthStrong;
  Color get accentPain;
  Color get accentConfirmation;
  Color get accentConfirmationStrong;
  Color get borderSubtle;
  Color get borderStrong;
  Color get stateError;
  Color get stateSuccess;
  Color get stateWarning;
  Color get focusRing;
  Color get bgOverlay;
  Color get textDisabledColor;
  // Semantic token for the selected calendar day cell fill.
  // Light: ink (#2B2521), Dark: mutedTerracotta (#B86848).
  // Kept distinct from accentFlow so future palette changes to accentFlow
  // cannot silently shift the calendar selection colour (OQ-01).
  Color get selectedDayFill;
}

// Design tokens sourced from design/DESIGN-BIBLE.md § 1.1, cross-checked against
// wiki/design/Métra Screens Light.html (super-canon). Field names use English
// aliases (sand/ink/moss…); the bible uses Italian (sabbia/inchiostro/muschio…).
// Never add a color here that is not in the DESIGN-BIBLE canonical palette.
@immutable
final class _LightPalette implements MetraPalette {
  const _LightPalette();

  // ── 10 canonical primitives per DESIGN-BIBLE § 1.1 ──────────────────────────
  // Fields satisfy MetraPalette getters via implicit field-getters.
  @override
  final Color sand = const Color(0xFFF4EDE2); // sabbia
  final Color surfaceRaised = const Color(0xFFFAF5EE); // surface (#FAF5EE)
  final Color bianco = const Color(0xFFFDFAF6); // bianco
  @override
  final Color ink = const Color(0xFF2B2521); // inchiostro
  @override
  final Color terracotta = const Color(0xFFC87456); // terracotta
  @override
  final Color terracottaDeep = const Color(0xFF9A4D32); // tc_scura (#9A4D32)
  @override
  final Color dustyOchre = const Color(0xFFD4A26A); // ocra
  final Color nightLavender = const Color(0xFF5B4E7A); // lavanda
  @override
  final Color malva = const Color(0xFF9E7488); // malva
  final Color moss = const Color(0xFF7A8471); // muschio

  // ── Off-catalog primitives — pending deletion after consumer sweep ───────────
  // Do not add new references. Replace usages with bible alpha-tints:
  //   inkSoft       → ink.withAlpha(0x66) [secondary text, inchiostro @ 0.40]
  //                    ink.withAlpha(0x24) [strong border, inchiostro @ 0.14]
  //   surfaceSunken → ink.withAlpha(0x0A) [sunken bg, inchiostro @ 0.04]
  //   divider       → ink.withAlpha(0x12) [card/section edge, inchiostro @ 0.07]
  //   textDisabled  → ink.withAlpha(0xAD) [disabled label, inchiostro @ 0.68]
  //   dustyOchreDeep → dustyOchre (ocra)
  //   mossDeep      → moss (muschio)
  final Color inkSoft = const Color(0xFF5A4F47);
  final Color surfaceSunken = const Color(0xFFECE4D6);
  final Color divider = const Color(0xFFDCD2C0);
  final Color textDisabled = const Color(0xFF8C8378);
  final Color dustyOchreDeep = const Color(0xFF8A6332);
  final Color mossDeep = const Color(0xFF4F5A47);

  // rgba(43,37,33,0.32) → alpha=round(0.32*255)=82=0x52, RGB=0x2B2521
  final Color overlayScrim = const Color(0x522B2521);

  // ── Semantic aliases — use these in widgets, not the primitives above ────────
  @override
  Color get bgPrimary => sand;
  @override
  Color get bgSurface => surfaceRaised;
  @override
  Color get bgSunken => ink.withAlpha(0x0A); // inchiostro @ 0.04 — § 1.1
  @override
  Color get textPrimary => ink;
  @override
  Color get textSecondary => ink.withAlpha(0x66); // inchiostro @ 0.40 — § 1.1
  @override
  Color get textOnSand => terracottaDeep;
  @override
  Color get textOnAccent => sand;
  @override
  Color get accentFlow => terracotta;
  @override
  Color get accentFlowStrong => terracottaDeep;
  // AA-compliant terracotta for normal-size text on sand background (4.68:1).
  @override
  Color get accentFlowText => terracottaDeep;
  @override
  Color get accentPrediction => nightLavender;
  @override
  Color get accentWarmth => dustyOchre;
  @override
  Color get accentWarmthStrong => dustyOchre;
  @override
  Color get accentPain => malva;
  @override
  Color get accentConfirmation => moss;
  @override
  Color get accentConfirmationStrong => moss;
  @override
  Color get borderSubtle => ink.withAlpha(0x12); // inchiostro @ 0.07 — § 1.5
  @override
  Color get borderStrong => ink.withAlpha(0x24); // inchiostro @ 0.14 — § 1.5
  @override
  Color get stateError => terracottaDeep;
  @override
  Color get stateSuccess => moss;
  @override
  Color get stateWarning => dustyOchre;
  @override
  Color get focusRing => nightLavender;
  @override
  Color get bgOverlay => overlayScrim;
  @override
  Color get textDisabledColor =>
      ink.withAlpha(0xAD); // inchiostro @ 0.68 — § 1.1
  @override
  Color get selectedDayFill => ink; // inchiostro (#2B2521) — FR-02, OQ-01
}

// Dark palette — values sourced from design/Métra Screens Dark.html const C
// (super-canon). All borders and alpha-tinted text use the avorio base
// rgba(237,228,211, α) per DESIGN-BIBLE § 1.1.1.
@immutable
final class _DarkPalette implements MetraPalette {
  const _DarkPalette();

  // ── Canonical dark primitives — from HTML const C ───────────────────────────
  final Color deepNight = const Color(0xFF1A1410); // sabbia dark (notte)
  final Color deepNightRaised =
      const Color(0xFF251D18); // surface dark (surface_d)
  final Color ivory = const Color(0xFFEDE4D3); // inchiostro dark (avorio)
  final Color mutedTerracotta =
      const Color(0xFFB86848); // terracotta dark (tc_spenta)
  final Color mutedTerracottaSoft =
      const Color(0xFFD4906A); // tc_scura dark (tc_chiara)
  final Color lightLavender =
      const Color(0xFF9B8FBF); // lavanda dark (lav_chiara)
  final Color malvaLight = const Color(0xFFC4A0B4); // malva dark (malva_chiara)
  final Color warmOchreDark = const Color(0xFFC4924A); // ocra dark
  final Color mossDark = const Color(0xFF9FA896); // muschio dark

  // ── MetraPalette — primitive aliases ─────────────────────────────────────────
  @override
  Color get ink => ivory;
  @override
  Color get sand => deepNight;
  @override
  Color get terracotta => mutedTerracotta;
  @override
  Color get terracottaDeep => mutedTerracottaSoft;
  @override
  Color get dustyOchre => warmOchreDark;
  @override
  Color get malva => malvaLight;

  // ── Semantic aliases — avorio alpha stops per DESIGN-BIBLE § 1.1.1 ──────────
  @override
  Color get bgPrimary => deepNight;
  @override
  Color get bgSurface => deepNightRaised;
  // Note textarea bg: rgba(237,228,211,0.05) per dark HTML line 820.
  @override
  Color get bgSunken => ivory.withAlpha(0x0D); // avorio @ 0.05
  @override
  Color get textPrimary => ivory;
  @override
  Color get textSecondary =>
      ivory.withAlpha(0xA6); // avorio @ 0.65 — sub text dark
  @override
  Color get textOnSand => mutedTerracottaSoft;
  @override
  Color get textOnAccent => deepNight;
  @override
  Color get accentFlow => mutedTerracotta;
  @override
  Color get accentFlowStrong => mutedTerracottaSoft;
  // AA-compliant on deepNight background (6.81:1).
  @override
  Color get accentFlowText => mutedTerracottaSoft;
  @override
  Color get accentPrediction => lightLavender;
  @override
  Color get accentWarmth => warmOchreDark;
  @override
  Color get accentWarmthStrong => warmOchreDark;
  @override
  Color get accentPain => malvaLight;
  @override
  Color get accentConfirmation => mossDark;
  @override
  Color get accentConfirmationStrong => mossDark;
  // avorio @ 0.07 = card border dark per § 1.1.1
  @override
  Color get borderSubtle => ivory.withAlpha(0x12);
  // avorio @ 0.14 = border2 dark per § 1.1.1
  @override
  Color get borderStrong => ivory.withAlpha(0x24);
  @override
  Color get stateError => mutedTerracottaSoft;
  @override
  Color get stateSuccess => mossDark;
  @override
  Color get stateWarning => warmOchreDark;
  @override
  Color get focusRing => lightLavender;
  // rgba(0,0,0,0.56) for dark overlays
  @override
  Color get bgOverlay => const Color(0x8F000000);
  // avorio @ 0.68 = readable disabled text dark
  @override
  Color get textDisabledColor => ivory.withAlpha(0xAD);
  @override
  // tc_spenta (#B86848) — muted terracotta dark-mode selected fill — FR-01, OQ-01
  Color get selectedDayFill => mutedTerracotta;
}

abstract final class MetraColors {
  // ignore: library_private_types_in_public_api
  static const _LightPalette light = _LightPalette();
  // ignore: library_private_types_in_public_api
  static const _DarkPalette dark = _DarkPalette();

  // Use this in all widgets. Returns the correct palette for the current
  // brightness without leaking a concrete palette type.
  static MetraPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}
