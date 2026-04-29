// Copyright (C) 2024 Paolo Santucci
//
// This file is part of Métra.
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:convert';

import '../../core/errors/metra_exception.dart';
import 'daily_log_entity.dart';
import 'daily_log_with_symptoms.dart';
import 'flow_intensity.dart';
import 'pain_symptom_data.dart';
import 'pain_symptom_type.dart';

class BackupSnapshot {
  const BackupSnapshot({
    required this.version,
    required this.exportedAt,
    required this.logsWithSymptoms,
  });

  static const int currentVersion = 1;

  final int version;
  final DateTime exportedAt;
  final List<DailyLogWithSymptoms> logsWithSymptoms;

  Map<String, dynamic> toJson() => {
        'version': version,
        'exported_at': exportedAt.toUtc().toIso8601String(),
        'daily_logs': logsWithSymptoms.map((lws) {
          return {
            'date': lws.log.date.toUtc().toIso8601String(),
            'flow_intensity': lws.log.flowIntensity?.index,
            'spotting': lws.log.spotting,
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
    if (version != currentVersion) {
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
    final logs = logsRaw.map(_parseLog).toList();
    return BackupSnapshot(
      version: version,
      exportedAt: exportedAt,
      logsWithSymptoms: logs,
    );
  }

  static DailyLogWithSymptoms _parseLog(dynamic e) {
    if (e is! Map<String, dynamic>) {
      throw const BackupFormatException('Each log must be an object');
    }
    final date = DateTime.tryParse(e['date'] as String? ?? '');
    if (date == null) {
      throw const BackupFormatException('log.date missing or invalid');
    }
    final flowIdx = e['flow_intensity'] as int?;
    final flow = flowIdx == null
        ? null
        : (flowIdx >= 0 && flowIdx < FlowIntensity.values.length
            ? FlowIntensity.values[flowIdx]
            : throw const BackupFormatException(
                'Invalid flow_intensity index',
              ));
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
    final log = DailyLogEntity(
      date: date,
      flowIntensity: flow,
      spotting: e['spotting'] as bool? ?? false,
      otherDischarge: e['other_discharge'] as bool? ?? false,
      painEnabled: e['pain_enabled'] as bool? ?? false,
      painIntensity: e['pain_intensity'] as int?,
      notesEnabled: e['notes_enabled'] as bool? ?? false,
      notes: e['notes'] as String?,
    );
    return DailyLogWithSymptoms(log: log, symptoms: symptoms);
  }
}
