// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
//
// Métra is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Métra is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Métra. If not, see <https://www.gnu.org/licenses/>.

import 'package:metra/domain/entities/cycle_prediction.dart';
import 'package:metra/domain/repositories/cycle_entry_repository.dart';
import 'package:metra/domain/services/cycle_prediction_service.dart';

/// Watches all cycle entries and maps each emission to a [CyclePrediction].
///
/// Emits null when fewer than 3 complete cycles are available.
class WatchCyclePrediction {
  const WatchCyclePrediction(this._cycleRepo, this._service);

  final CycleEntryRepository _cycleRepo;
  final CyclePredictionService _service;

  Stream<CyclePrediction?> call() =>
      _cycleRepo.watchAll().map(_service.predict);
}
