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

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/constants/app_constants.dart';
import '../../../providers/encryption_provider.dart';

class OnboardingState {
  const OnboardingState({
    this.lastPeriodDate,
    this.cycleLength = 28,
    this.periodLength = 3,
    this.isSubmitting = false,
    this.isHydrated = false,
  });

  final DateTime? lastPeriodDate;
  final int cycleLength;
  final int periodLength;

  /// True from the first `await` in the submit sequence until completion or
  /// error. Drives the CTA `onPressed = null` to prevent double-submission.
  final bool isSubmitting;

  /// True once [OnboardingNotifier]'s secure-storage hydration has
  /// completed, regardless of whether a restorable draft was found.
  ///
  /// `false` on the synchronous [OnboardingNotifier.build] result; flips to
  /// `true` in a later event-loop turn once the async read settles. Drives
  /// the page-2 auto-advance via `ref.listen` — never `initState`, which
  /// would race the hydration read (spec §4.3, OQ-06).
  final bool isHydrated;

  bool get canSubmit => lastPeriodDate != null;

  OnboardingState copyWith({
    DateTime? lastPeriodDate,
    int? cycleLength,
    int? periodLength,
    bool? isSubmitting,
    bool? isHydrated,
  }) =>
      OnboardingState(
        lastPeriodDate: lastPeriodDate ?? this.lastPeriodDate,
        cycleLength: cycleLength ?? this.cycleLength,
        periodLength: periodLength ?? this.periodLength,
        isSubmitting: isSubmitting ?? this.isSubmitting,
        isHydrated: isHydrated ?? this.isHydrated,
      );
}

class OnboardingNotifier extends Notifier<OnboardingState> {
  /// Serializes draft writes so overlapping mutations (e.g. rapid stepper
  /// taps) complete in call order — the terminal keystore value always
  /// equals the last mutation (last-write-wins). Deliberately NOT
  /// debounced: a debounce would reopen the app-kill data-loss window this
  /// feature exists to close (spec §4.3).
  Future<void> _writeChain = Future<void>.value();

  static const List<String> _draftKeys = [
    AppConstants.kOnboardingDraftDateKey,
    AppConstants.kOnboardingDraftCycleLengthKey,
    AppConstants.kOnboardingDraftPeriodLengthKey,
  ];

  @override
  OnboardingState build() {
    // Fire-and-forget: secure storage is a platform channel, so hydration
    // always resolves in a later event-loop turn — after this build() call
    // (and the caller's `ref.listen` registration) land. Stays a sync
    // `Notifier`, not `AsyncNotifier` (spec §4.3 "async-hydration idiom",
    // OQ-06 — migrating would ripple into ~37 pre-existing assertions for
    // no benefit).
    unawaited(_hydrate());
    return const OnboardingState();
  }

  /// Restores a page-2 draft from secure storage, if one exists.
  ///
  /// A restorable draft requires the date key (the anchor — onboarding
  /// cannot be submitted without a date, OQ-01). A missing key, a
  /// secure-storage read failure, or a malformed stored value are all
  /// treated the same way — "no draft": `isHydrated` still flips to `true`,
  /// but the rest of the state stays at its current (default) values.
  /// Never throws (EC-12).
  Future<void> _hydrate() async {
    final storage = ref.read(secureStorageProvider);
    try {
      final dateString =
          await storage.read(key: AppConstants.kOnboardingDraftDateKey);
      if (dateString == null) {
        state = state.copyWith(isHydrated: true);
        return;
      }

      final cycleString = await storage.read(
        key: AppConstants.kOnboardingDraftCycleLengthKey,
      );
      final periodString = await storage.read(
        key: AppConstants.kOnboardingDraftPeriodLengthKey,
      );

      state = OnboardingState(
        lastPeriodDate: _parseDraftDate(dateString),
        cycleLength:
            cycleString == null ? state.cycleLength : int.parse(cycleString),
        periodLength:
            periodString == null ? state.periodLength : int.parse(periodString),
        isHydrated: true,
      );
    } catch (e) {
      // PlatformException (read failure) or FormatException (malformed
      // value) — both are "no draft" (EC-12). The exception's own message
      // never carries the stored value (see _parseDraftDate), so this is
      // safe to log (NFR-07: no draft value ever reaches a log line).
      debugPrint('[OnboardingNotifier._hydrate] ${e.runtimeType}: $e');
      state = state.copyWith(isHydrated: true);
    }
  }

  /// Persists the current draft (date + cycle + period length) once a date
  /// is set. Merely landing on page 2 with defaults does not produce a
  /// restorable draft (OQ-01) — writing is gated on `lastPeriodDate`.
  ///
  /// Fire-and-forget by design (NFR-05: draft writes never block the UI
  /// isolate) — callers do not await this. The actual write is chained
  /// through [_writeChain] so overlapping mutations serialize instead of
  /// racing (EC-10).
  void _persistDraft() {
    final date = state.lastPeriodDate;
    if (date == null) return;

    final dateString = _formatDraftDate(date);
    final cycleLength = state.cycleLength;
    final periodLength = state.periodLength;
    final storage = ref.read(secureStorageProvider);

    _writeChain = _writeChain.then(
      (_) => _writeDraft(storage, dateString, cycleLength, periodLength),
    );
  }

  Future<void> _writeDraft(
    FlutterSecureStorage storage,
    String dateString,
    int cycleLength,
    int periodLength,
  ) async {
    try {
      await storage.write(
        key: AppConstants.kOnboardingDraftDateKey,
        value: dateString,
      );
      await storage.write(
        key: AppConstants.kOnboardingDraftCycleLengthKey,
        value: cycleLength.toString(),
      );
      await storage.write(
        key: AppConstants.kOnboardingDraftPeriodLengthKey,
        value: periodLength.toString(),
      );
    } catch (e) {
      debugPrint('[OnboardingNotifier._persistDraft] ${e.runtimeType}: $e');
    }
  }

  /// Deletes the three draft keys. Called from `_DataPage._onSubmit` after
  /// `CompleteOnboarding.execute()` succeeds (FR-06).
  ///
  /// Best-effort and idempotent: each key is deleted independently so a
  /// platform-channel failure on one key does not block deletion of the
  /// others; any failure is swallowed and logged, never rethrown into the
  /// caller (EC-13/EC-14).
  Future<void> clearDraft() async {
    final storage = ref.read(secureStorageProvider);
    for (final key in _draftKeys) {
      try {
        await storage.delete(key: key);
      } catch (e) {
        debugPrint('[OnboardingNotifier.clearDraft] ${e.runtimeType}: $e');
      }
    }
  }

  static String _formatDraftDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static DateTime _parseDraftDate(String value) {
    final parts = value.split('-');
    if (parts.length != 3) {
      throw const FormatException('malformed onboarding draft date');
    }
    return DateTime.utc(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  /// Updates [lastPeriodDate]. Ignores any date strictly after [DateTime.now()]
  /// (future dates are invalid anchor dates for the menstrual cycle).
  void setDate(DateTime date) {
    // FR-07: silently ignore future dates — only the UI date picker is a guard,
    // but we also enforce the invariant here for defense in depth.
    if (date.isAfter(DateTime.now())) return;
    state = state.copyWith(lastPeriodDate: date);
    _persistDraft();
  }

  /// Sets the [isSubmitting] flag. Called by the UI before the first await
  /// in the submit sequence, and cleared in a `finally` block.
  void setSubmitting(bool value) => state = state.copyWith(isSubmitting: value);

  void incrementCycleLength() {
    state = state.copyWith(
      cycleLength: (state.cycleLength + 1).clamp(21, 45),
    );
    _persistDraft();
  }

  void decrementCycleLength() {
    state = state.copyWith(
      cycleLength: (state.cycleLength - 1).clamp(21, 45),
    );
    _persistDraft();
  }

  void setPeriodLength(int value) {
    state = state.copyWith(periodLength: value.clamp(1, 8));
    _persistDraft();
  }
}

final onboardingNotifierProvider =
    NotifierProvider<OnboardingNotifier, OnboardingState>(
  OnboardingNotifier.new,
);
