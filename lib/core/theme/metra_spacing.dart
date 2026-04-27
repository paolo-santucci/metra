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

// Spacing, radius, and motion tokens sourced from mockup/tokens.json.
abstract final class MetraSpacing {
  static const double s0  = 0;
  static const double s1  = 4;
  static const double s2  = 8;
  static const double s3  = 12;
  static const double s4  = 16;
  static const double s5  = 20;
  static const double s6  = 24;
  static const double s8  = 32;
  static const double s10 = 40;
  static const double s12 = 48;
  static const double s16 = 64;
}

abstract final class MetraRadius {
  static const double sm   = 8;
  static const double md   = 12;
  static const double lg   = 16;
  static const double pill = 999;
}

abstract final class MetraMotion {
  // Durations (milliseconds) — use as Duration(milliseconds: MetraMotion.base)
  static const int instant    = 0;
  static const int fast       = 150;
  static const int base       = 240;
  static const int slow       = 400;
  static const int risingFill = 600;
  static const int painPulse  = 780;

  // Reduced-motion fallbacks (check MediaQuery.of(context).disableAnimations)
  static const int slowReduced       = 80;
  static const int risingFillReduced = 80;
}
