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
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/theme/metra_colors.dart';

void main() {
  group('MetraColors light palette', () {
    test('terracotta matches tokens.json', () {
      expect(MetraColors.light.terracotta, const Color(0xFFC87456));
    });

    test('terracottaDeep matches tokens.json', () {
      expect(MetraColors.light.terracottaDeep, const Color(0xFF9B4E32));
    });

    test('sand matches tokens.json', () {
      expect(MetraColors.light.sand, const Color(0xFFF4EDE2));
    });

    test('ink matches tokens.json', () {
      expect(MetraColors.light.ink, const Color(0xFF2B2521));
    });

    test('nightLavender matches tokens.json', () {
      expect(MetraColors.light.nightLavender, const Color(0xFF5B4E7A));
    });
  });

  group('MetraColors dark palette', () {
    test('deepNight matches tokens.json', () {
      expect(MetraColors.dark.deepNight, const Color(0xFF1A1410));
    });

    test('ivory matches tokens.json', () {
      expect(MetraColors.dark.ivory, const Color(0xFFEDE4D3));
    });

    test('mutedTerracotta matches tokens.json', () {
      expect(MetraColors.dark.mutedTerracotta, const Color(0xFFB86848));
    });

    test('lightLavender matches tokens.json', () {
      expect(MetraColors.dark.lightLavender, const Color(0xFF9B8FBF));
    });
  });

  group('MetraColors semantic contract', () {
    test('dustyOchre is decorative-only (never used as text color)', () {
      expect(MetraColors.light.dustyOchre, const Color(0xFFD4A26A));
    });

    test('terracotta on sand is large-text-only (3.0:1)', () {
      expect(
        MetraColors.light.terracotta,
        isNot(equals(MetraColors.light.terracottaDeep)),
      );
    });

    test('light bgOverlay maps to overlayScrim', () {
      expect(MetraColors.light.bgOverlay, MetraColors.light.overlayScrim);
    });

    test('dark bgOverlay maps to overlayScrim', () {
      expect(MetraColors.dark.bgOverlay, MetraColors.dark.overlayScrim);
    });

    test('light textDisabledColor maps to textDisabled primitive', () {
      expect(MetraColors.light.textDisabledColor, const Color(0xFF8C8378));
    });

    test('dark textDisabledColor maps to textDisabled primitive', () {
      expect(MetraColors.dark.textDisabledColor, const Color(0xFF6B6358));
    });
  });
}
