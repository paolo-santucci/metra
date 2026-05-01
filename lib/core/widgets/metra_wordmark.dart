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

import '../theme/metra_typography.dart';

// MetraWordmark renders the Mētra brand wordmark as DM Serif Display text.
// The product name uses macron-e (ē, U+0113) per DESIGN-BIBLE § 0.3.
class MetraWordmark extends StatelessWidget {
  const MetraWordmark({super.key, required this.color, this.fontSize = 56.0});

  final Color color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      MetraTypography.wordmark,
      style: GoogleFonts.dmSerifDisplay(
        fontSize: fontSize,
        fontWeight: FontWeight.w400,
        height: 1.0,
        letterSpacing: fontSize * -0.02,
        color: color,
      ),
    );
  }
}
