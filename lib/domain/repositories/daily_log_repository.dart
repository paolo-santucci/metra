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

import '../entities/daily_log_entity.dart';
import '../entities/pain_symptom_data.dart';

abstract class DailyLogRepository {
  Stream<DailyLogEntity?> watchDay(DateTime date);

  Stream<List<DailyLogEntity>> watchMonth(int year, int month);

  Future<List<DailyLogEntity>> getAllOrderedByDate();

  Future<void> saveDailyLog(DailyLogEntity log);

  Future<void> deleteDailyLog(DateTime date);

  Future<List<PainSymptomData>> getPainSymptoms(DateTime date);

  Future<void> replacePainSymptoms(
    DateTime date,
    List<PainSymptomData> symptoms,
  );
}
