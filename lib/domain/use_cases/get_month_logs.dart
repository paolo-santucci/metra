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
import '../repositories/daily_log_repository.dart';

class GetMonthLogs {
  const GetMonthLogs(this._repo);

  final DailyLogRepository _repo;

  Stream<List<DailyLogEntity>> call(int year, int month) =>
      _repo.watchMonth(year, month);
}
