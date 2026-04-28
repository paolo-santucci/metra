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

class CycleEntryEntity {
  const CycleEntryEntity({
    required this.id,
    required this.startDate,
    this.endDate,
    this.cycleLength,
    this.periodLength,
  });

  final int id;
  final DateTime startDate;
  final DateTime? endDate;
  final int? cycleLength;
  final int? periodLength;

  CycleEntryEntity copyWith({
    int? id,
    DateTime? startDate,
    DateTime? endDate,
    int? cycleLength,
    int? periodLength,
  }) {
    return CycleEntryEntity(
      id: id ?? this.id,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      cycleLength: cycleLength ?? this.cycleLength,
      periodLength: periodLength ?? this.periodLength,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CycleEntryEntity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          startDate == other.startDate &&
          endDate == other.endDate &&
          cycleLength == other.cycleLength &&
          periodLength == other.periodLength;

  @override
  int get hashCode =>
      id.hashCode ^
      startDate.hashCode ^
      endDate.hashCode ^
      cycleLength.hashCode ^
      periodLength.hashCode;
}
