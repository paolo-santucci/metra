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

class OnboardingState {
  const OnboardingState({
    this.lastPeriodDate,
    this.cycleLength = 28,
    this.periodLength = 3,
  });

  final DateTime? lastPeriodDate;
  final int cycleLength;
  final int periodLength;

  bool get canSubmit => lastPeriodDate != null;

  OnboardingState copyWith({
    DateTime? lastPeriodDate,
    int? cycleLength,
    int? periodLength,
  }) =>
      OnboardingState(
        lastPeriodDate: lastPeriodDate ?? this.lastPeriodDate,
        cycleLength: cycleLength ?? this.cycleLength,
        periodLength: periodLength ?? this.periodLength,
      );
}

class OnboardingNotifier extends Notifier<OnboardingState> {
  @override
  OnboardingState build() => const OnboardingState();

  void setDate(DateTime date) => state = state.copyWith(lastPeriodDate: date);

  void incrementCycleLength() => state = state.copyWith(
        cycleLength: (state.cycleLength + 1).clamp(21, 45),
      );

  void decrementCycleLength() => state = state.copyWith(
        cycleLength: (state.cycleLength - 1).clamp(21, 45),
      );

  void setPeriodLength(int value) => state = state.copyWith(
        periodLength: value.clamp(1, 8),
      );
}

final onboardingNotifierProvider =
    NotifierProvider<OnboardingNotifier, OnboardingState>(
  OnboardingNotifier.new,
);
