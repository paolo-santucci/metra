// Copyright (C) 2024 Paolo Santucci
//
// This file is part of Métra.
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:convert';

import '../../core/errors/metra_exception.dart';
import 'daily_log_entity.dart';
import 'daily_log_with_symptoms.dart';
import 'flow_intensity.dart';
import 'flow_type.dart';
import 'pain_symptom_data.dart';
import 'pain_symptom_type.dart';

/// Snapshot format versions:
///   1 — Original format. `flow_intensity` is the v3 enum (none/light/medium/
///       heavy/veryHeavy, indices 0..4). `spotting` is a separate boolean.
///   2 — Post-P-B format. `flow_type` (FlowType index) is authoritative;
///       `flow_intensity` is the v4 enum (light/medium/heavy/veryHeavy,
///       indices 0..3) and is meaningful only when flow_type ==
///       FlowType.mestruazioni. The `spotting` boolean is omitted.
///
/// Reads accept both v1 and v2; writes always emit v2.
class BackupSnapshot {
  const BackupSnapshot({
    required this.version,
    required this.exportedAt,
    required this.logsWithSymptoms,
  });

  static const int currentVersion = 2;
  static const int _minSupportedVersion = 1;

  final int version;
  final DateTime exportedAt;
  final List<DailyLogWithSymptoms> logsWithSymptoms;

  Map<String, dynamic> toJson() => {
        'version': version,
        'exported_at': exportedAt.toUtc().toIso8601String(),
        'daily_logs': logsWithSymptoms.map((lws) {
          return {
            'date': lws.log.date.toUtc().toIso8601String(),
            'flow_type': lws.log.flowType?.index,
            'flow_intensity': lws.log.flowIntensity?.index,
            'other_discharge': lws.log.otherDischarge,
            'pain_enabled': lws.log.painEnabled,
            'pain_intensity': lws.log.painIntensity,
            'notes_enabled': lws.log.notesEnabled,
            'notes': lws.log.notes,
            'pain_symptoms': lws.symptoms
                .map(
                  (s) => {
                    'symptom_type': s.symptomType.index,
                    'custom_label': s.customLabel,
                  },
                )
                .toList(),
          };
        }).toList(),
      };

  String encode() => jsonEncode(toJson());

  static BackupSnapshot decode(String json) {
    final dynamic raw;
    try {
      raw = jsonDecode(json);
    } catch (e) {
      throw const BackupFormatException('Invalid JSON');
    }
    if (raw is! Map<String, dynamic>) {
      throw const BackupFormatException('Top-level JSON must be an object');
    }
    final version = raw['version'];
    if (version is! int) {
      throw const BackupFormatException('Missing or invalid version');
    }
    if (version < _minSupportedVersion || version > currentVersion) {
      throw BackupFormatException('Unsupported snapshot version $version');
    }
    final exportedAtStr = raw['exported_at'];
    if (exportedAtStr is! String) {
      throw const BackupFormatException('Missing or invalid exported_at');
    }
    final exportedAt = DateTime.tryParse(exportedAtStr);
    if (exportedAt == null) {
      throw const BackupFormatException('exported_at is not ISO-8601');
    }
    final logsRaw = raw['daily_logs'];
    if (logsRaw is! List) {
      throw const BackupFormatException('daily_logs must be a list');
    }
    final logs = logsRaw.map((e) => _parseLog(e, version)).toList();
    return BackupSnapshot(
      version: version,
      exportedAt: exportedAt,
      logsWithSymptoms: logs,
    );
  }

  static DailyLogWithSymptoms _parseLog(dynamic e, int snapshotVersion) {
    if (e is! Map<String, dynamic>) {
      throw const BackupFormatException('Each log must be an object');
    }
    final date = DateTime.tryParse(e['date'] as String? ?? '');
    if (date == null) {
      throw const BackupFormatException('log.date missing or invalid');
    }

    final symptomsRaw = e['pain_symptoms'];
    if (symptomsRaw is! List) {
      throw const BackupFormatException('pain_symptoms must be a list');
    }
    final symptoms = symptomsRaw.map((s) {
      if (s is! Map<String, dynamic>) {
        throw const BackupFormatException('Each symptom must be an object');
      }
      final typeIdx = s['symptom_type'] as int?;
      if (typeIdx == null ||
          typeIdx < 0 ||
          typeIdx >= PainSymptomType.values.length) {
        throw const BackupFormatException('Invalid symptom_type index');
      }
      return PainSymptomData(
        symptomType: PainSymptomType.values[typeIdx],
        customLabel: s['custom_label'] as String?,
      );
    }).toList();

    final flowIdxRaw = e['flow_intensity'] as int?;
    FlowType? flowType;
    FlowIntensity? flow;

    if (snapshotVersion >= 2) {
      // v2: flow_type is authoritative; flow_intensity uses the v4 enum.
      final ftIdx = e['flow_type'] as int?;
      if (ftIdx != null) {
        if (ftIdx < 0 || ftIdx >= FlowType.values.length) {
          throw const BackupFormatException('Invalid flow_type index');
        }
        flowType = FlowType.values[ftIdx];
      }
      if (flowIdxRaw != null) {
        if (flowIdxRaw < 0 || flowIdxRaw >= FlowIntensity.values.length) {
          throw const BackupFormatException('Invalid flow_intensity index');
        }
        flow = FlowIntensity.values[flowIdxRaw];
      }
    } else {
      // v1 → derive new fields from legacy {spotting, flow_intensity v3-enum}.
      final spotting = e['spotting'] as bool? ?? false;
      if (spotting) {
        flowType = FlowType.spotting;
        flow = null;
      } else if (flowIdxRaw != null) {
        // v3 enum: 0=none, 1=light, 2=medium, 3=heavy, 4=veryHeavy
        if (flowIdxRaw < 0 || flowIdxRaw > 4) {
          throw const BackupFormatException(
            'Invalid v1 flow_intensity index',
          );
        }
        if (flowIdxRaw == 0) {
          flowType = FlowType.assente;
          flow = null;
        } else {
          flowType = FlowType.mestruazioni;
          // Shift v3 index → v4 index (drop `none`).
          flow = FlowIntensity.values[flowIdxRaw - 1];
        }
      }
    }

    final log = DailyLogEntity(
      date: date,
      flowType: flowType,
      flowIntensity: flow,
      otherDischarge: e['other_discharge'] as bool? ?? false,
      painEnabled: e['pain_enabled'] as bool? ?? false,
      painIntensity: e['pain_intensity'] as int?,
      notesEnabled: e['notes_enabled'] as bool? ?? false,
      notes: e['notes'] as String?,
    );
    return DailyLogWithSymptoms(log: log, symptoms: symptoms);
  }
}
