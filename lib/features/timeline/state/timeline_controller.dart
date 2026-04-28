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

import '../../../domain/entities/cycle_summary.dart';
import '../../../providers/use_case_providers.dart';

final timelineProvider =
    AutoDisposeAsyncNotifierProvider<TimelineNotifier, List<CycleSummary>>(
  TimelineNotifier.new,
);

class TimelineNotifier extends AutoDisposeAsyncNotifier<List<CycleSummary>> {
  @override
  Future<List<CycleSummary>> build() async {
    final uc = await ref.read(getCycleSummariesProvider.future);
    final completer = Completer<List<CycleSummary>>();
    final sub = uc().listen((summaries) {
      if (!completer.isCompleted) {
        completer.complete(summaries);
      } else {
        state = AsyncData(summaries);
      }
    });
    ref.onDispose(sub.cancel);
    return completer.future;
  }
}
