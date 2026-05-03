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

// Spacing, radius, and motion tokens sourced from design/DESIGN-BIBLE.md §§ 1.3–1.4,
// cross-checked against design/Métra Screens Light.html (super-canon).

// Legacy spacing aliases — kept for backward compatibility during migration.
// New code should use sp{value} constants below which map directly to the
// DESIGN-BIBLE § 1.3 canonical scale: 0·2·3·4·5·6·7·8·10·12·14·16·18·20·24·28·32·36·44·48·56·72·84·90·100
abstract final class MetraSpacing {
  // Legacy aliases (sN = step N, value ≠ N)
  static const double s0 = 0;
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 20;
  static const double s6 = 24;
  static const double s8 = 32;
  static const double s12 = 48;

  // Canonical scale per DESIGN-BIBLE § 1.3 (spN = N logical pixels)
  static const double sp2 = 2;
  static const double sp3 = 3;
  static const double sp5 = 5;
  static const double sp6 = 6;
  static const double sp7 = 7;
  static const double sp10 = 10;
  static const double sp14 = 14;
  static const double sp18 = 18;
  static const double sp28 = 28;
  static const double sp36 = 36;
  static const double sp44 = 44;
  static const double sp56 = 56;
  static const double sp72 = 72;
  static const double sp84 = 84;
  static const double sp90 = 90;
  static const double sp100 = 100;
}

// Border-radius catalog per DESIGN-BIBLE § 1.4.
// Allowed values: 6, 8, 10, 12, 14, 16, 18, 20, 44.
// Chip-pill rule: radius = ½ × height — never use a fixed large value.
abstract final class MetraRadius {
  static const double xs = 6; // sharp inner elements
  static const double sm = 8;
  static const double smm = 10; // segmented track, stepper micro-buttons
  static const double md = 12;
  static const double mmd = 14; // timeline card, flow pill
  static const double lg = 16;
  static const double lgg = 18;
  static const double xl = 20; // year-label pill (calendar)
  static const double phone = 44; // phone-corner large elements
}

abstract final class MetraMotion {
  // Durations (milliseconds) — use as Duration(milliseconds: MetraMotion.base)
  static const int instant = 0;
  static const int fast = 150;
  static const int base = 240;
  static const int slow = 400;
  static const int risingFill = 600;
  static const int painPulse = 780;

  // Reduced-motion fallbacks (check MediaQuery.of(context).disableAnimations)
  static const int slowReduced = 80;
  static const int risingFillReduced = 80;
}
