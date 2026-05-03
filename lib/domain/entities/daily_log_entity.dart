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
import 'flow_type.dart';

class DailyLogEntity {
  const DailyLogEntity({
    required this.date,
    this.flowType,
    this.flowIntensity,
    this.otherDischarge = false,
    this.painEnabled = false,
    this.painIntensity,
    this.notesEnabled = false,
    this.notes,
  });

  final DateTime date;

  /// Categorical type of flow for the day. `null` = not logged.
  /// `FlowType.mestruazioni` is the only value for which `flowIntensity`
  /// is meaningful; for `assente`/`spotting` the intensity must be `null`.
  final FlowType? flowType;

  /// Ordinal menstrual flow intensity. Only meaningful when
  /// `flowType == FlowType.mestruazioni`.
  final FlowIntensity? flowIntensity;

  final bool otherDischarge;
  final bool painEnabled;
  final int? painIntensity;
  final bool notesEnabled;
  final String? notes;

  /// True iff the day is logged as spotting. Derived from `flowType`
  /// for backward compatibility with code that previously read `.spotting`
  /// from a separate boolean field.
  bool get spotting => flowType == FlowType.spotting;

  DailyLogEntity copyWith({
    DateTime? date,
    FlowType? flowType,
    bool clearFlowType = false,
    FlowIntensity? flowIntensity,
    bool clearFlowIntensity = false,
    bool? otherDischarge,
    bool? painEnabled,
    int? painIntensity,
    bool clearPainIntensity = false,
    bool? notesEnabled,
    String? notes,
    bool clearNotes = false,
  }) {
    return DailyLogEntity(
      date: date ?? this.date,
      flowType: clearFlowType ? null : (flowType ?? this.flowType),
      flowIntensity:
          clearFlowIntensity ? null : (flowIntensity ?? this.flowIntensity),
      otherDischarge: otherDischarge ?? this.otherDischarge,
      painEnabled: painEnabled ?? this.painEnabled,
      painIntensity:
          clearPainIntensity ? null : (painIntensity ?? this.painIntensity),
      notesEnabled: notesEnabled ?? this.notesEnabled,
      notes: clearNotes ? null : (notes ?? this.notes),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyLogEntity &&
          runtimeType == other.runtimeType &&
          date == other.date &&
          flowType == other.flowType &&
          flowIntensity == other.flowIntensity &&
          otherDischarge == other.otherDischarge &&
          painEnabled == other.painEnabled &&
          painIntensity == other.painIntensity &&
          notesEnabled == other.notesEnabled &&
          notes == other.notes;

  @override
  int get hashCode =>
      date.hashCode ^
      flowType.hashCode ^
      flowIntensity.hashCode ^
      otherDischarge.hashCode ^
      painEnabled.hashCode ^
      painIntensity.hashCode ^
      notesEnabled.hashCode ^
      notes.hashCode;
}
