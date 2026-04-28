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

import 'package:metra/domain/entities/daily_log_entity.dart';
import 'package:metra/domain/entities/pain_symptom_data.dart';
import 'package:metra/domain/repositories/daily_log_repository.dart';

class FakeDailyLogRepository implements DailyLogRepository {
  final List<DailyLogEntity> savedLogs = [];
  final Map<DateTime, List<PainSymptomData>> symptoms = {};
  final List<DateTime> deletedDates = [];

  @override
  Stream<DailyLogEntity?> watchDay(DateTime date) {
    final utcDate = DateTime.utc(date.year, date.month, date.day);
    final match = savedLogs.where((l) => l.date == utcDate).toList();
    return Stream.value(match.isEmpty ? null : match.last);
  }

  @override
  Stream<List<DailyLogEntity>> watchMonth(int year, int month) {
    final matches = savedLogs
        .where((l) => l.date.year == year && l.date.month == month)
        .toList();
    return Stream.value(matches);
  }

  @override
  Future<List<DailyLogEntity>> getAllOrderedByDate() async {
    final sorted = List<DailyLogEntity>.from(savedLogs)
      ..sort((a, b) => a.date.compareTo(b.date));
    return sorted;
  }

  @override
  Future<void> saveDailyLog(DailyLogEntity log) async {
    savedLogs.removeWhere((l) => l.date == log.date);
    savedLogs.add(log);
  }

  @override
  Future<void> deleteDailyLog(DateTime date) async {
    final utcDate = DateTime.utc(date.year, date.month, date.day);
    savedLogs.removeWhere((l) => l.date == utcDate);
    deletedDates.add(utcDate);
  }

  @override
  Future<List<PainSymptomData>> getPainSymptoms(DateTime date) async {
    final utcDate = DateTime.utc(date.year, date.month, date.day);
    return symptoms[utcDate] ?? [];
  }

  @override
  Future<void> replacePainSymptoms(
    DateTime date,
    List<PainSymptomData> newSymptoms,
  ) async {
    final utcDate = DateTime.utc(date.year, date.month, date.day);
    symptoms[utcDate] = newSymptoms;
  }
}
