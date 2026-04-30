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
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/features/onboarding/state/onboarding_notifier.dart';

void main() {
  ProviderContainer makeContainer() => ProviderContainer();

  test('initial cycleLength is 28', () {
    final container = makeContainer();
    addTearDown(container.dispose);
    final state = container.read(onboardingNotifierProvider);
    expect(state.cycleLength, 28);
  });

  test('initial lastPeriodDate is null', () {
    final container = makeContainer();
    addTearDown(container.dispose);
    final state = container.read(onboardingNotifierProvider);
    expect(state.lastPeriodDate, isNull);
  });

  test('setDate updates lastPeriodDate', () {
    final container = makeContainer();
    addTearDown(container.dispose);
    final date = DateTime.utc(2026, 3, 15);
    container.read(onboardingNotifierProvider.notifier).setDate(date);
    final state = container.read(onboardingNotifierProvider);
    expect(state.lastPeriodDate, date);
  });

  test('incrementCycleLength increments by 1', () {
    final container = makeContainer();
    addTearDown(container.dispose);
    container.read(onboardingNotifierProvider.notifier).incrementCycleLength();
    final state = container.read(onboardingNotifierProvider);
    expect(state.cycleLength, 29);
  });

  test('decrementCycleLength decrements by 1', () {
    final container = makeContainer();
    addTearDown(container.dispose);
    container.read(onboardingNotifierProvider.notifier).decrementCycleLength();
    final state = container.read(onboardingNotifierProvider);
    expect(state.cycleLength, 27);
  });

  test('incrementCycleLength clamps at 45', () {
    final container = makeContainer();
    addTearDown(container.dispose);
    for (var i = 0; i < 40; i++) {
      container
          .read(onboardingNotifierProvider.notifier)
          .incrementCycleLength();
    }
    final state = container.read(onboardingNotifierProvider);
    expect(state.cycleLength, 45);
  });

  test('decrementCycleLength clamps at 21', () {
    final container = makeContainer();
    addTearDown(container.dispose);
    for (var i = 0; i < 30; i++) {
      container
          .read(onboardingNotifierProvider.notifier)
          .decrementCycleLength();
    }
    final state = container.read(onboardingNotifierProvider);
    expect(state.cycleLength, 21);
  });

  test('initial periodLength is 3', () {
    final container = makeContainer();
    addTearDown(container.dispose);
    final state = container.read(onboardingNotifierProvider);
    expect(state.periodLength, 3);
  });

  test('setPeriodLength updates periodLength', () {
    final container = makeContainer();
    addTearDown(container.dispose);
    container.read(onboardingNotifierProvider.notifier).setPeriodLength(5);
    final state = container.read(onboardingNotifierProvider);
    expect(state.periodLength, 5);
  });

  test('setPeriodLength clamps at 1', () {
    final container = makeContainer();
    addTearDown(container.dispose);
    container.read(onboardingNotifierProvider.notifier).setPeriodLength(0);
    final state = container.read(onboardingNotifierProvider);
    expect(state.periodLength, 1);
  });

  test('setPeriodLength clamps at 8', () {
    final container = makeContainer();
    addTearDown(container.dispose);
    container.read(onboardingNotifierProvider.notifier).setPeriodLength(9);
    final state = container.read(onboardingNotifierProvider);
    expect(state.periodLength, 8);
  });

  test('canSubmit is false when lastPeriodDate is null', () {
    final container = makeContainer();
    addTearDown(container.dispose);
    final state = container.read(onboardingNotifierProvider);
    expect(state.canSubmit, isFalse);
  });

  test('canSubmit is true when lastPeriodDate is set', () {
    final container = makeContainer();
    addTearDown(container.dispose);
    final date = DateTime.utc(2026, 3, 15);
    container.read(onboardingNotifierProvider.notifier).setDate(date);
    final state = container.read(onboardingNotifierProvider);
    expect(state.canSubmit, isTrue);
  });
}
