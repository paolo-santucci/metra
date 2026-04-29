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

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/cycle_prediction.dart';
import '../../../providers/use_case_providers.dart';

/// Non-autoDispose provider: the prediction is app-lifetime state consumed by
/// the calendar and the app-level notification listener.
final cyclePredictionProvider =
    AsyncNotifierProvider<CyclePredictionNotifier, CyclePrediction?>(
  CyclePredictionNotifier.new,
);

class CyclePredictionNotifier extends AsyncNotifier<CyclePrediction?> {
  @override
  Future<CyclePrediction?> build() async {
    final uc = await ref.read(watchCyclePredictionProvider.future);
    final completer = Completer<CyclePrediction?>();
    final sub = uc().listen((CyclePrediction? prediction) {
      if (!completer.isCompleted) {
        completer.complete(prediction);
      } else {
        state = AsyncData(prediction);
      }
    });
    ref.onDispose(sub.cancel);
    return completer.future;
  }
}
