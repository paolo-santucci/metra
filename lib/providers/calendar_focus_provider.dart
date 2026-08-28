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

/// One-shot Timeline → Calendar focus request (#3, FR-01/FR-02).
///
/// Lives in the neutral `lib/providers/` layer (not `features/calendar/`)
/// so `TimelineScreen` can produce a request without a timeline→calendar
/// cross-feature import.
///
/// Non-autoDispose: the value must survive the navigation gap between
/// `TimelineScreen` recording it and `CalendarScreen` consuming it. Do not
/// change this to `NotifierProvider.autoDispose` — a listener drop between
/// the two screens would discard the pending request before it is read.
final calendarFocusRequestProvider =
    NotifierProvider<CalendarFocusRequest, DateTime?>(CalendarFocusRequest.new);

/// Notifier backing [calendarFocusRequestProvider].
class CalendarFocusRequest extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  /// Records a request to focus [date] on the Calendar. Normalised to
  /// UTC midnight to match `CalendarMonthState` / `CalendarDay` date keys.
  ///
  /// A second call before consumption overwrites the prior value — only
  /// the last tap matters (§5.3).
  void request(DateTime date) =>
      state = DateTime.utc(date.year, date.month, date.day);

  /// Clears the request once the Calendar has consumed it. Idempotent:
  /// calling this when the state is already `null` is a no-op (EC-04).
  void clear() => state = null;
}
