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

import 'package:flutter_test/flutter_test.dart';
import 'package:metra/domain/entities/first_day_of_week_setting.dart';

void main() {
  group('FirstDayOfWeekSetting enum index contract', () {
    test('system has index 0', () {
      expect(FirstDayOfWeekSetting.system.index, 0);
    });

    test('sunday has index 1', () {
      expect(FirstDayOfWeekSetting.sunday.index, 1);
    });

    test('monday has index 2', () {
      expect(FirstDayOfWeekSetting.monday.index, 2);
    });

    test('values list has exactly 3 entries', () {
      expect(FirstDayOfWeekSetting.values.length, 3);
    });

    test('values[0] == system', () {
      expect(FirstDayOfWeekSetting.values[0], FirstDayOfWeekSetting.system);
    });

    test('values[1] == sunday', () {
      expect(FirstDayOfWeekSetting.values[1], FirstDayOfWeekSetting.sunday);
    });

    test('values[2] == monday', () {
      expect(FirstDayOfWeekSetting.values[2], FirstDayOfWeekSetting.monday);
    });
  });
}
