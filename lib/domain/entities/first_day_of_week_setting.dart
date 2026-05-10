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

/// User preference for the first day of the week shown in the calendar grid.
///
/// Stored in the database as the enum [index] integer (0, 1, 2).
enum FirstDayOfWeekSetting {
  /// Use the locale's first day of week as reported by
  /// [MaterialLocalizations.firstDayOfWeekIndex] (0 = Sunday, 1 = Monday).
  system, // index 0

  /// Always start the week on Sunday ([DateTime.sunday] = 7).
  sunday, // index 1

  /// Always start the week on Monday ([DateTime.monday] = 1).
  monday, // index 2
}
