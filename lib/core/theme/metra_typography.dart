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

// Typography sourced from design/DESIGN-BIBLE.md § 1.2, cross-checked against
// design/Métra Screens Light.html (super-canon). Fonts: DM Serif Display + Inter
// (both loaded via google_fonts — never use fontFamily: 'Inter' strings directly).
// Wordmark: 'Mētra' — literal ē (U+0113), never a Unicode escape.
abstract final class MetraTypography {
  // ── DM Serif Display roles ───────────────────────────────────────────────────

  // Hero wordmark: 56px, lh 1.0, ls −0.02em (= −1.12 at 56px)
  static TextStyle get displayHero => GoogleFonts.dmSerifDisplay(
        fontSize: 56,
        fontWeight: FontWeight.w400,
        height: 1.0,
        letterSpacing: -1.12,
      );

  // Onboarding manifesto headline
  static TextStyle get headlineLg => GoogleFonts.dmSerifDisplay(
        fontSize: 34,
        fontWeight: FontWeight.w400,
        height: 1.2,
      );

  // Onboarding secondary headline
  static TextStyle get headlineMd => GoogleFonts.dmSerifDisplay(
        fontSize: 30,
        fontWeight: FontWeight.w400,
        height: 1.2,
      );

  // Onboarding tertiary headline
  static TextStyle get headlineSm => GoogleFonts.dmSerifDisplay(
        fontSize: 28,
        fontWeight: FontWeight.w400,
        height: 1.25,
      );

  // Stepper value / large number display
  static TextStyle get stepper => GoogleFonts.dmSerifDisplay(
        fontSize: 40,
        fontWeight: FontWeight.w400,
        height: 1.0,
      );

  // Stat card primary value
  static TextStyle get statCard => GoogleFonts.dmSerifDisplay(
        fontSize: 32,
        fontWeight: FontWeight.w400,
        height: 1.0,
      );

  // Screen / section title
  static TextStyle get screenTitle => GoogleFonts.dmSerifDisplay(
        fontSize: 26,
        fontWeight: FontWeight.w400,
        height: 1.1,
      );

  // Day-detail card title and similar modal headers
  static TextStyle get dayDetailTitle => GoogleFonts.dmSerifDisplay(
        fontSize: 20,
        fontWeight: FontWeight.w400,
        height: 1.3,
      );

  // Archive month label
  static TextStyle get archiveMonth => GoogleFonts.dmSerifDisplay(
        fontSize: 17,
        fontWeight: FontWeight.w400,
        height: 1.2,
      );

  // ── Inter roles ─────────────────────────────────────────────────────────────

  // Body text (default readable content)
  static TextStyle get body => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.55,
      );

  // List / card primary label
  static TextStyle get listTitle => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        height: 1.55,
      );

  // Date / secondary descriptor
  static TextStyle get listDate => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.4,
      );

  // Section label (uppercase-style tracking)
  static TextStyle get sectionLabel => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 1.4,
        letterSpacing: 0.72, // 0.06em at 12px
      );

  // Calendar day-header row labels (Mon, Tue …)
  static TextStyle get dayHeader => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 1.4,
        letterSpacing: 0.48, // 0.04em at 12px
      );

  // Pill / chip text — large variant (12px)
  static TextStyle get pillMd => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.4,
      );

  // Pill / chip text — small variant (11px)
  static TextStyle get pillSm => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        height: 1.4,
      );

  // Range label (e.g. "Giorni 1–5")
  static TextStyle get rangeLabel => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        height: 1.4,
      );

  // Indicator dot label — idle weight; active/selected callers apply w600
  static TextStyle get dotLabel => GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w400,
        height: 1.4,
      );

  // Tab-bar label — idle weight; active callers apply w600
  static TextStyle get tabLabel => GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w400,
        height: 1.4,
      );

  // ── Legacy abstract scale — kept for backward compatibility ─────────────────
  // New code should use the role-named getters above.
  // These will be removed once all consumers are migrated (Phase 0c sweep).

  static TextStyle get displayXl => GoogleFonts.dmSerifDisplay(
        fontSize: 48,
        height: 1.2,
      );

  static TextStyle get displayLg => GoogleFonts.dmSerifDisplay(
        fontSize: 40,
        height: 1.0,
      );

  static TextStyle get displayMd => GoogleFonts.dmSerifDisplay(
        fontSize: 32,
        height: 1.0,
      );

  static TextStyle get titleLg => GoogleFonts.dmSerifDisplay(
        fontSize: 26,
        height: 1.1,
      );

  static TextStyle get titleMd => GoogleFonts.dmSerifDisplay(
        fontSize: 22,
        height: 1.3,
      );

  // Fixed: was Inter w600 — DESIGN-BIBLE § 1.2 specifies DM Serif Display 400.
  static TextStyle get titleSm => GoogleFonts.dmSerifDisplay(
        fontSize: 20,
        fontWeight: FontWeight.w400,
        height: 1.3,
      );

  static TextStyle get bodyLg => GoogleFonts.inter(
        fontSize: 18,
        height: 1.55,
      );

  static TextStyle get caption => GoogleFonts.inter(
        fontSize: 13,
        height: 1.4,
      );

  static TextStyle get tiny => GoogleFonts.inter(
        fontSize: 12,
        height: 1.4,
        fontWeight: FontWeight.w500,
      );

  // Wordmark: always use this constant; never reconstruct it inline.
  // ē = U+0113 — a literal character per CLAUDE.md §8.3.
  static const String wordmark = 'Mētra';

  static TextTheme toTextTheme(Color textColor) => TextTheme(
        displayLarge: displayHero.copyWith(color: textColor),
        displayMedium: stepper.copyWith(color: textColor),
        displaySmall: statCard.copyWith(color: textColor),
        headlineLarge: screenTitle.copyWith(color: textColor),
        headlineMedium: dayDetailTitle.copyWith(color: textColor),
        headlineSmall: archiveMonth.copyWith(color: textColor),
        bodyLarge: body.copyWith(color: textColor),
        bodyMedium: listDate.copyWith(color: textColor),
        bodySmall: sectionLabel.copyWith(color: textColor),
        labelSmall: dotLabel.copyWith(color: textColor),
      );
}
