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

import '../../../domain/entities/cycle_stats_data.dart';
import '../../../providers/use_case_providers.dart';

final statsProvider =
    AutoDisposeAsyncNotifierProvider<StatsNotifier, CycleStatsData?>(
  StatsNotifier.new,
);

class StatsNotifier extends AutoDisposeAsyncNotifier<CycleStatsData?> {
  @override
  Future<CycleStatsData?> build() async {
    final uc = await ref.read(computeCycleStatsProvider.future);
    final completer = Completer<CycleStatsData?>();
    final sub = uc().listen((data) {
      if (!completer.isCompleted) {
        completer.complete(data);
      } else {
        state = AsyncData(data);
      }
    });
    ref.onDispose(sub.cancel);
    return completer.future;
  }
}
