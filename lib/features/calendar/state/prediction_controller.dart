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

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/cycle_prediction.dart';
import '../../../providers/repository_providers.dart';
import '../../../providers/use_case_providers.dart';

/// Non-autoDispose provider: the prediction is app-lifetime state consumed by
/// the calendar and the app-level notification listener.
///
/// BUG-001 fix: converted from an async* generator body (which captured
/// declaredCycleLength once via .future and never re-ran) to a synchronous
/// StreamProvider body. Riverpod's dependency tracking now rebuilds this
/// provider body on every emission from appSettingsStreamProvider or
/// watchCyclePredictionProvider, including within-session DB writes such as
/// saveDeclaredCycleLength(). The prediction for <3-cycle users correctly
/// reflects the latest declared cycle length without an app restart.
final cyclePredictionProvider = StreamProvider<CyclePrediction?>((ref) {
  // Synchronous body: ref.watch installs reactive dependencies.
  // Every new emission from appSettingsStreamProvider rebuilds this provider,
  // restarting the inner stream with the updated declaredCycleLength.
  final ucAsync = ref.watch(watchCyclePredictionProvider);
  final settingsAsync = ref.watch(appSettingsStreamProvider);

  // Return empty stream while either dependency is loading or errored,
  // so no data emission reaches the notification listener until both
  // dependencies have resolved (EC-02, EC-03).
  final uc = ucAsync.valueOrNull;
  if (uc == null) return const Stream.empty();
  if (settingsAsync is AsyncLoading || settingsAsync is AsyncError) {
    return const Stream.empty();
  }

  final declaredCycleLength = settingsAsync.valueOrNull?.declaredCycleLength;
  return uc(declaredCycleLength: declaredCycleLength);
});
