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
import 'package:metra/domain/entities/daily_log_entity.dart';
import 'package:metra/domain/entities/flow_intensity.dart';
import 'package:metra/domain/entities/flow_type.dart';

void main() {
  final date = DateTime.utc(2026, 4, 15);

  DailyLogEntity makeLog({
    DateTime? date,
    FlowType? flowType,
    FlowIntensity? flowIntensity,
    bool otherDischarge = false,
    bool painEnabled = false,
    int? painIntensity,
    bool notesEnabled = false,
    String? notes,
  }) => DailyLogEntity(
    date: date ?? DateTime.utc(2026, 4, 15),
    flowType: flowType,
    flowIntensity: flowIntensity,
    otherDischarge: otherDischarge,
    painEnabled: painEnabled,
    painIntensity: painIntensity,
    notesEnabled: notesEnabled,
    notes: notes,
  );

  group('DailyLogEntity construction', () {
    test('stores date and applies default booleans', () {
      final log = DailyLogEntity(date: date);

      expect(log.date, date);
      expect(log.flowType, isNull);
      expect(log.flowIntensity, isNull);
      expect(log.otherDischarge, isFalse);
      expect(log.painEnabled, isFalse);
      expect(log.painIntensity, isNull);
      expect(log.notesEnabled, isFalse);
      expect(log.notes, isNull);
    });

    test('stores all optional fields when provided', () {
      final log = makeLog(
        flowType: FlowType.mestruazioni,
        flowIntensity: FlowIntensity.heavy,
        otherDischarge: true,
        painEnabled: true,
        painIntensity: 3,
        notesEnabled: true,
        notes: 'tired',
      );

      expect(log.flowType, FlowType.mestruazioni);
      expect(log.flowIntensity, FlowIntensity.heavy);
      expect(log.otherDischarge, isTrue);
      expect(log.painEnabled, isTrue);
      expect(log.painIntensity, 3);
      expect(log.notesEnabled, isTrue);
      expect(log.notes, 'tired');
    });
  });

  group('DailyLogEntity.spotting computed getter', () {
    test('is true when flowType is spotting', () {
      final log = makeLog(flowType: FlowType.spotting);

      expect(log.spotting, isTrue);
    });

    test('is false when flowType is mestruazioni', () {
      final log = makeLog(flowType: FlowType.mestruazioni);

      expect(log.spotting, isFalse);
    });

    test('is false when flowType is assente', () {
      final log = makeLog(flowType: FlowType.assente);

      expect(log.spotting, isFalse);
    });

    test('is false when flowType is null', () {
      final log = makeLog();

      expect(log.spotting, isFalse);
    });
  });

  group('DailyLogEntity equality', () {
    test('identical instance equals itself', () {
      final log = makeLog();
      expect(log == log, isTrue);
    });

    test('two instances with same fields are equal', () {
      final a = makeLog(flowType: FlowType.mestruazioni, painIntensity: 2);
      final b = makeLog(flowType: FlowType.mestruazioni, painIntensity: 2);

      expect(a, equals(b));
    });

    test('instances with different date are not equal', () {
      final a = makeLog(date: DateTime.utc(2026, 4, 1));
      final b = makeLog(date: DateTime.utc(2026, 4, 2));

      expect(a, isNot(equals(b)));
    });

    test('instances with different flowType are not equal', () {
      final a = makeLog(flowType: FlowType.mestruazioni);
      final b = makeLog(flowType: FlowType.spotting);

      expect(a, isNot(equals(b)));
    });

    test('instances with different flowIntensity are not equal', () {
      final a = makeLog(flowIntensity: FlowIntensity.light);
      final b = makeLog(flowIntensity: FlowIntensity.heavy);

      expect(a, isNot(equals(b)));
    });

    test('instances with different otherDischarge are not equal', () {
      final a = makeLog(otherDischarge: false);
      final b = makeLog(otherDischarge: true);

      expect(a, isNot(equals(b)));
    });

    test('instances with different painEnabled are not equal', () {
      final a = makeLog(painEnabled: false);
      final b = makeLog(painEnabled: true);

      expect(a, isNot(equals(b)));
    });

    test('instances with different painIntensity are not equal', () {
      final a = makeLog(painIntensity: 1);
      final b = makeLog(painIntensity: 3);

      expect(a, isNot(equals(b)));
    });

    test('instances with different notesEnabled are not equal', () {
      final a = makeLog(notesEnabled: false);
      final b = makeLog(notesEnabled: true);

      expect(a, isNot(equals(b)));
    });

    test('instances with different notes are not equal', () {
      final a = makeLog(notes: 'note A');
      final b = makeLog(notes: 'note B');

      expect(a, isNot(equals(b)));
    });

    test('instance does not equal object of different type', () {
      final log = makeLog();

      // ignore: unrelated_type_equality_checks
      expect(log == 'not a log', isFalse);
    });
  });

  group('DailyLogEntity hashCode', () {
    test('equal objects have the same hashCode', () {
      final a = makeLog(flowType: FlowType.mestruazioni, notes: 'hello');
      final b = makeLog(flowType: FlowType.mestruazioni, notes: 'hello');

      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('DailyLogEntity copyWith', () {
    test('returns equal object when no arguments supplied', () {
      final log = makeLog(flowType: FlowType.mestruazioni, notes: 'x');
      final copy = log.copyWith();

      expect(copy, equals(log));
    });

    test('updates date', () {
      final log = makeLog();
      final newDate = DateTime.utc(2026, 5, 1);
      final copy = log.copyWith(date: newDate);

      expect(copy.date, newDate);
    });

    test('updates flowType', () {
      final log = makeLog(flowType: FlowType.assente);
      final copy = log.copyWith(flowType: FlowType.spotting);

      expect(copy.flowType, FlowType.spotting);
    });

    test('clears flowType with clearFlowType flag', () {
      final log = makeLog(flowType: FlowType.mestruazioni);
      final copy = log.copyWith(clearFlowType: true);

      expect(copy.flowType, isNull);
    });

    test('clearFlowType false with null param preserves original flowType', () {
      final log = makeLog(flowType: FlowType.spotting);
      final copy = log.copyWith(clearFlowType: false);

      expect(copy.flowType, FlowType.spotting);
    });

    test('updates flowIntensity', () {
      final log = makeLog(flowIntensity: FlowIntensity.light);
      final copy = log.copyWith(flowIntensity: FlowIntensity.heavy);

      expect(copy.flowIntensity, FlowIntensity.heavy);
    });

    test('clears flowIntensity with clearFlowIntensity flag', () {
      final log = makeLog(flowIntensity: FlowIntensity.medium);
      final copy = log.copyWith(clearFlowIntensity: true);

      expect(copy.flowIntensity, isNull);
    });

    test('updates otherDischarge', () {
      final log = makeLog(otherDischarge: false);
      final copy = log.copyWith(otherDischarge: true);

      expect(copy.otherDischarge, isTrue);
    });

    test('updates painEnabled', () {
      final log = makeLog(painEnabled: false);
      final copy = log.copyWith(painEnabled: true);

      expect(copy.painEnabled, isTrue);
    });

    test('updates painIntensity', () {
      final log = makeLog(painIntensity: 1);
      final copy = log.copyWith(painIntensity: 3);

      expect(copy.painIntensity, 3);
    });

    test('clears painIntensity with clearPainIntensity flag', () {
      final log = makeLog(painIntensity: 2);
      final copy = log.copyWith(clearPainIntensity: true);

      expect(copy.painIntensity, isNull);
    });

    test('updates notesEnabled', () {
      final log = makeLog(notesEnabled: false);
      final copy = log.copyWith(notesEnabled: true);

      expect(copy.notesEnabled, isTrue);
    });

    test('updates notes', () {
      final log = makeLog(notes: 'old');
      final copy = log.copyWith(notes: 'new');

      expect(copy.notes, 'new');
    });

    test('clears notes with clearNotes flag', () {
      final log = makeLog(notes: 'some note');
      final copy = log.copyWith(clearNotes: true);

      expect(copy.notes, isNull);
    });

    test('clearNotes false with null param preserves original notes', () {
      final log = makeLog(notes: 'preserved');
      final copy = log.copyWith(clearNotes: false);

      expect(copy.notes, 'preserved');
    });
  });
}
