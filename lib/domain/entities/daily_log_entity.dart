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

import 'flow_intensity.dart';

class DailyLogEntity {
  const DailyLogEntity({
    required this.date,
    this.flowIntensity,
    this.spotting = false,
    this.painEnabled = false,
    this.painIntensity,
    this.notesEnabled = false,
    this.notes,
  });

  final DateTime date;
  final FlowIntensity? flowIntensity;
  final bool spotting;
  final bool painEnabled;
  final int? painIntensity;
  final bool notesEnabled;
  final String? notes;

  DailyLogEntity copyWith({
    DateTime? date,
    FlowIntensity? flowIntensity,
    bool? spotting,
    bool? painEnabled,
    int? painIntensity,
    bool? notesEnabled,
    String? notes,
  }) {
    return DailyLogEntity(
      date: date ?? this.date,
      flowIntensity: flowIntensity ?? this.flowIntensity,
      spotting: spotting ?? this.spotting,
      painEnabled: painEnabled ?? this.painEnabled,
      painIntensity: painIntensity ?? this.painIntensity,
      notesEnabled: notesEnabled ?? this.notesEnabled,
      notes: notes ?? this.notes,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyLogEntity &&
          runtimeType == other.runtimeType &&
          date == other.date &&
          flowIntensity == other.flowIntensity &&
          spotting == other.spotting &&
          painEnabled == other.painEnabled &&
          painIntensity == other.painIntensity &&
          notesEnabled == other.notesEnabled &&
          notes == other.notes;

  @override
  int get hashCode =>
      date.hashCode ^
      flowIntensity.hashCode ^
      spotting.hashCode ^
      painEnabled.hashCode ^
      painIntensity.hashCode ^
      notesEnabled.hashCode ^
      notes.hashCode;
}
