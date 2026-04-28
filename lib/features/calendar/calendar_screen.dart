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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' as intl;

import '../../core/theme/metra_colors.dart';
import '../../core/theme/metra_spacing.dart';
import '../../core/theme/metra_typography.dart';
import '../../domain/entities/daily_log_entity.dart';
import '../../domain/entities/flow_intensity.dart';
import '../../l10n/app_localizations.dart';
import 'state/calendar_month_controller.dart';
import 'widgets/calendar_day.dart';
import 'widgets/month_navigator.dart';

/// The main calendar screen (tab 1).
///
/// Shows a monthly grid of [CalendarDay] widgets, a month navigation header,
/// and a FAB to jump to today's quick entry.
///
/// The FAB scales in from 0 → 1 with an elastic curve on first mount
/// (plain easeOut when reduce-motion is active). Duration is capped at
/// 240ms per project animation spec.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  // Italian short day-of-week header: Monday first.
  static const List<String> _dayHeaders = [
    'L',
    'M',
    'M',
    'G',
    'V',
    'S',
    'D',
  ];

  @override
  Widget build(BuildContext context) {
    // safe: delegates registered in MetraApp
    final l10n = AppLocalizations.of(context)!;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDark ? MetraColors.dark.bgPrimary : MetraColors.light.bgPrimary;
    final textColor = isDark
        ? MetraColors.dark.textSecondary
        : MetraColors.light.textSecondary;

    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final fabDuration = reduceMotion
        ? const Duration(milliseconds: 80)
        : const Duration(milliseconds: 240);
    final fabCurve = reduceMotion ? Curves.easeOut : Curves.elasticOut;

    final calendarAsync = ref.watch(calendarMonthProvider);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: calendarAsync.when(
          loading: () => Center(
            child: Semantics(
              label: l10n.common_loading,
              child: const CircularProgressIndicator(),
            ),
          ),
          error: (_, __) => Center(
            child: Text(
              l10n.common_error_generic,
              style: TextStyle(color: textColor),
            ),
          ),
          data: (monthState) {
            final now = DateTime.now();
            final isCurrentMonth =
                monthState.year == now.year && monthState.month == now.month;

            // intl.DateFormat.MMMM uses locale-aware month name.
            final monthName = intl.DateFormat.MMMM('it').format(
              DateTime(monthState.year, monthState.month),
            );
            final title = l10n.calendar_month_title(
              monthName,
              monthState.year.toString(),
            );

            return Column(
              children: [
                MonthNavigator(
                  title: title,
                  prevLabel: l10n.calendar_prev_month,
                  nextLabel: l10n.calendar_next_month,
                  onPrev: () =>
                      ref.read(calendarMonthProvider.notifier).goToPrevMonth(),
                  onNext: () =>
                      ref.read(calendarMonthProvider.notifier).goToNextMonth(),
                  canGoNext: !isCurrentMonth,
                ),
                // Day-of-week header row.
                _DayOfWeekHeader(
                  labels: _dayHeaders,
                  isDark: isDark,
                  textColor: textColor,
                ),
                Expanded(
                  child: _CalendarGrid(
                    year: monthState.year,
                    month: monthState.month,
                    logs: monthState.logs,
                    today: now,
                    l10n: l10n,
                  ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        duration: fabDuration,
        curve: fabCurve,
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: FloatingActionButton(
          onPressed: () => context.push('/daily-entry/today'),
          tooltip: l10n.calendar_fab_label,
          child: Semantics(
            label: l10n.calendar_fab_label,
            child: const Icon(Icons.add),
          ),
        ),
      ),
    );
  }
}

class _DayOfWeekHeader extends StatelessWidget {
  const _DayOfWeekHeader({
    required this.labels,
    required this.isDark,
    required this.textColor,
  });

  final List<String> labels;
  final bool isDark;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MetraSpacing.s2),
      child: Row(
        children: labels.map((label) {
          return Expanded(
            child: Center(
              child: Text(
                label,
                style: MetraTypography.caption.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.year,
    required this.month,
    required this.logs,
    required this.today,
    required this.l10n,
  });

  final int year;
  final int month;
  final Map<DateTime, DailyLogEntity> logs;
  final DateTime today;
  final AppLocalizations l10n;

  /// Number of blank leading cells before day 1.
  /// Dart's DateTime.weekday: 1=Monday…7=Sunday. We want Monday first → offset = weekday - 1.
  int get _leadingBlanks {
    final firstDayWeekday = DateTime(year, month, 1).weekday;
    return firstDayWeekday - 1; // 0 for Monday, 6 for Sunday
  }

  int get _daysInMonth => DateUtils.getDaysInMonth(year, month);

  String _buildSemantics(
    DateTime date,
    DailyLogEntity? log,
    bool isToday,
    AppLocalizations l10n,
  ) {
    final dateStr = intl.DateFormat.yMMMMd('it').format(date);
    if (isToday) return l10n.a11y_calendar_day_today(dateStr);
    if (log == null) return l10n.a11y_calendar_day_no_flow(dateStr);
    if (log.spotting) return l10n.a11y_calendar_day_spotting(dateStr);
    if (log.flowIntensity != null && log.flowIntensity != FlowIntensity.none) {
      final flowLabel = _flowLabel(log.flowIntensity!, l10n);
      return l10n.a11y_calendar_day_flow(flowLabel, dateStr);
    }
    if (log.notes != null && log.notes!.isNotEmpty) {
      return l10n.a11y_calendar_day_has_note(dateStr);
    }
    return l10n.a11y_calendar_day_no_flow(dateStr);
  }

  String _flowLabel(FlowIntensity intensity, AppLocalizations l10n) {
    switch (intensity) {
      case FlowIntensity.none:
        return l10n.daily_entry_flow_none;
      case FlowIntensity.light:
        return l10n.daily_entry_flow_light;
      case FlowIntensity.medium:
        return l10n.daily_entry_flow_medium;
      case FlowIntensity.heavy:
        return l10n.daily_entry_flow_heavy;
      case FlowIntensity.veryHeavy:
        return l10n.daily_entry_flow_veryHeavy;
    }
  }

  @override
  Widget build(BuildContext context) {
    final blanks = _leadingBlanks;
    final days = _daysInMonth;
    final totalCells = blanks + days;

    return GridView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: MetraSpacing.s2,
        vertical: MetraSpacing.s1,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1,
      ),
      itemCount: totalCells,
      itemBuilder: (context, index) {
        if (index < blanks) {
          // Empty leading cell — non-interactive, not announced by screen reader.
          return const ExcludeSemantics(child: SizedBox.shrink());
        }

        final dayNumber = index - blanks + 1;
        // Use UTC midnight so map keys match DailyLogEntity.date (UTC midnight).
        final date = DateTime.utc(year, month, dayNumber);
        final log = logs[date];

        final isToday = today.year == year &&
            today.month == month &&
            today.day == dayNumber;
        final isFlow = log?.flowIntensity != null &&
            log!.flowIntensity != FlowIntensity.none;
        final isSpotting = log?.spotting ?? false;
        final hasNote = log?.notes != null && log!.notes!.isNotEmpty;

        return CalendarDay(
          date: date,
          semanticsLabel: _buildSemantics(date, log, isToday, l10n),
          isFlow: isFlow,
          isSpotting: isSpotting,
          hasNote: hasNote,
          isToday: isToday,
          onTap: () => context.push(
            '/daily-entry/${date.toIso8601String().substring(0, 10)}',
          ),
        );
      },
    );
  }
}
