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
import 'package:metra/providers/calendar_focus_provider.dart';

void main() {
  group('calendarFocusRequestProvider (Group A, #3)', () {
    test('build() returns null on first read', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(calendarFocusRequestProvider), isNull);
    });

    test('request() normalises a local DateTime to UTC midnight', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final localWithTime = DateTime(2026, 3, 14, 15, 30, 45);
      container
          .read(calendarFocusRequestProvider.notifier)
          .request(localWithTime);

      expect(
        container.read(calendarFocusRequestProvider),
        DateTime.utc(2026, 3, 14),
      );
    });

    test(
        'request() normalises a UTC DateTime with a time-of-day to UTC midnight',
        () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final utcWithTime = DateTime.utc(2026, 3, 14, 23, 59, 59);
      container
          .read(calendarFocusRequestProvider.notifier)
          .request(utcWithTime);

      expect(
        container.read(calendarFocusRequestProvider),
        DateTime.utc(2026, 3, 14),
      );
    });

    test(
        'a second request() before consumption overwrites the first '
        '(only the last tap matters)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(calendarFocusRequestProvider.notifier);
      notifier.request(DateTime(2026, 1, 1));
      notifier.request(DateTime(2026, 6, 15));

      expect(
        container.read(calendarFocusRequestProvider),
        DateTime.utc(2026, 6, 15),
      );
    });

    test('clear() resets a pending request back to null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(calendarFocusRequestProvider.notifier);
      notifier.request(DateTime(2026, 4, 2));
      notifier.clear();

      expect(container.read(calendarFocusRequestProvider), isNull);
    });

    test('clear() is idempotent when the state is already null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(calendarFocusRequestProvider.notifier);
      expect(container.read(calendarFocusRequestProvider), isNull);

      // Calling clear() on an already-null state must not throw and must
      // leave the state unchanged (EC-04).
      notifier.clear();

      expect(container.read(calendarFocusRequestProvider), isNull);
    });

    test(
        'non-autoDispose proof: a set value survives after the last '
        'listener is dropped', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Attach and then drop the only listener — if the provider were
      // accidentally declared `autoDispose`, this tears down its state on
      // the next event-loop turn and a fresh read would fall back to the
      // build() null default instead of the value set below.
      final subscription = container.listen(
        calendarFocusRequestProvider,
        (previous, next) {},
      );

      container
          .read(calendarFocusRequestProvider.notifier)
          .request(DateTime(2026, 9, 10));

      subscription.close();

      // Let any pending disposal microtasks/timers (as used by
      // `autoDispose`) run before re-reading.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(calendarFocusRequestProvider),
        DateTime.utc(2026, 9, 10),
        reason: 'calendarFocusRequestProvider must be non-autoDispose: the '
            'value must survive the navigation gap between TimelineScreen '
            'and CalendarScreen even with no active listener.',
      );
    });
  });
}
