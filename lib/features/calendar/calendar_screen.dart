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
import '../../domain/entities/cycle_prediction.dart';
import '../../domain/entities/daily_log_entity.dart';
import '../../domain/entities/flow_intensity.dart';
import '../../domain/entities/flow_type.dart';
import '../../domain/entities/pain_symptom_data.dart';
import '../../domain/entities/pain_symptom_type.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/repository_providers.dart';
import 'state/calendar_month_controller.dart';
import 'state/prediction_controller.dart';
import 'widgets/calendar_day.dart';
import 'widgets/calendar_legend.dart';
import 'widgets/month_navigator.dart';

/// The main calendar screen (tab 1).
///
/// Shows a monthly grid of [CalendarDay] widgets, a month navigation header,
/// and a day-detail card that is always visible (defaults to today).
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime.utc(now.year, now.month, now.day);
  }

  /// Builds locale-aware single-character day-of-week headers, Monday first.
  ///
  /// 2024-01-01 is a Monday, so iterating i=0..6 over that week gives Mon→Sun.
  List<String> _buildDayHeaders(String locale) {
    final fmt = intl.DateFormat.E(locale);
    return List.generate(7, (i) {
      final d = DateTime(2024, 1, i + 1);
      return fmt.format(d).substring(0, 1).toUpperCase();
    });
  }

  @override
  Widget build(BuildContext context) {
    // safe: delegates registered in MetraApp
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDark ? MetraColors.dark.bgPrimary : MetraColors.light.bgPrimary;
    final textColor = isDark
        ? MetraColors.dark.textSecondary
        : MetraColors.light.textSecondary;

    final calendarAsync = ref.watch(calendarMonthProvider);
    final prediction = ref.watch(cyclePredictionProvider).valueOrNull;
    final symptomsAsync = ref.watch(painSymptomsProvider(_selectedDate));
    final symptoms = symptomsAsync.valueOrNull ?? [];

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
            final monthName = intl.DateFormat.MMMM(locale).format(
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
                  labels: _buildDayHeaders(locale),
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
                    locale: locale,
                    prediction: prediction,
                    selectedDate: _selectedDate,
                    onDaySelected: (date) =>
                        setState(() => _selectedDate = date),
                  ),
                ),
                const CalendarLegend(),
                _DayDetailCard(
                  selectedDate: _selectedDate,
                  log: monthState.logs[_selectedDate],
                  symptoms: symptoms,
                  l10n: l10n,
                  locale: locale,
                  isDark: isDark,
                ),
              ],
            );
          },
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
    required this.locale,
    required this.onDaySelected,
    this.prediction,
    this.selectedDate,
  });

  final int year;
  final int month;
  final Map<DateTime, DailyLogEntity> logs;
  final DateTime today;
  final AppLocalizations l10n;
  final String locale;
  final CyclePrediction? prediction;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onDaySelected;

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
    bool hasPrediction,
    AppLocalizations l10n,
  ) {
    final dateStr = intl.DateFormat.yMMMMd(locale).format(date);
    if (isToday) return l10n.a11y_calendar_day_today(dateStr);
    if (hasPrediction && log == null) {
      return l10n.a11y_calendar_day_prediction(dateStr);
    }
    if (log == null) return l10n.a11y_calendar_day_no_flow(dateStr);
    if (log.spotting) return l10n.a11y_calendar_day_spotting(dateStr);
    if (log.flowType == FlowType.mestruazioni) {
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
        final isFlow = log?.flowType == FlowType.mestruazioni;
        final isSpotting = log?.spotting ?? false;
        final hasNote = log?.notes != null && log!.notes!.isNotEmpty;
        final hasPrediction = prediction?.containsDate(date) ?? false;

        return CalendarDay(
          date: date,
          semanticsLabel:
              _buildSemantics(date, log, isToday, hasPrediction, l10n),
          isFlow: isFlow,
          isSpotting: isSpotting,
          hasPrediction: hasPrediction,
          hasNote: hasNote,
          isToday: isToday,
          isSelected: selectedDate == date,
          onTap: () => onDaySelected(date),
        );
      },
    );
  }
}

class _DayDetailCard extends StatelessWidget {
  const _DayDetailCard({
    required this.selectedDate,
    required this.symptoms,
    required this.l10n,
    required this.locale,
    required this.isDark,
    this.log,
  });

  final DateTime selectedDate;
  final DailyLogEntity? log;
  final List<PainSymptomData> symptoms;
  final AppLocalizations l10n;
  final String locale;
  final bool isDark;

  String _symptomLabel(PainSymptomType type, AppLocalizations l10n) =>
      switch (type) {
        PainSymptomType.cramps => l10n.daily_entry_symptom_cramps,
        PainSymptomType.headache => l10n.daily_entry_symptom_headache,
        PainSymptomType.bloating => l10n.daily_entry_symptom_bloating,
        PainSymptomType.backPain => l10n.daily_entry_symptom_backPain,
        PainSymptomType.migraine => l10n.daily_entry_symptom_migraine,
        PainSymptomType.custom => l10n.daily_entry_symptom_custom,
        PainSymptomType.fatigue => l10n.daily_entry_symptom_fatigue,
        PainSymptomType.nausea => l10n.daily_entry_symptom_nausea,
        PainSymptomType.breastTenderness =>
          l10n.daily_entry_symptom_breastTenderness,
      };

  @override
  Widget build(BuildContext context) {
    final bgSurface =
        isDark ? MetraColors.dark.bgSurface : MetraColors.light.bgSurface;
    final textPrimary =
        isDark ? MetraColors.dark.textPrimary : MetraColors.light.textPrimary;
    final textSecondary = isDark
        ? MetraColors.dark.textSecondary
        : MetraColors.light.textSecondary;
    final accentFlow =
        isDark ? MetraColors.dark.accentFlow : MetraColors.light.accentFlow;
    final borderColor = isDark ? Colors.white12 : Colors.black12;

    final hasData = log != null;
    final weekday = intl.DateFormat.EEEE(locale).format(selectedDate);
    final dayMonth = intl.DateFormat('d MMMM', locale).format(selectedDate);
    final dateLabel =
        '${weekday.substring(0, 1).toUpperCase()}${weekday.substring(1)} $dayMonth';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dateLabel,
                style: MetraTypography.titleMd.copyWith(color: textPrimary),
              ),
              if (!hasData)
                Text(
                  l10n.calendar_day_detail_no_data,
                  style: MetraTypography.caption.copyWith(
                    color: textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                )
              else
                _FlowBadge(log: log!, isDark: isDark),
            ],
          ),
          if (symptoms.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                ...symptoms.take(2).map(
                      (s) => _SymptomPill(
                        label: _symptomLabel(s.symptomType, l10n),
                        isDark: isDark,
                      ),
                    ),
                if (symptoms.length > 2)
                  Text(
                    '+${symptoms.length - 2}',
                    style: MetraTypography.tiny.copyWith(
                      color: textSecondary,
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => context.push(
              '/daily-entry/${selectedDate.toIso8601String().substring(0, 10)}',
            ),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: accentFlow.withValues(alpha: 0.06),
                border: Border.all(color: accentFlow.withValues(alpha: 0.13)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.edit_outlined, size: 16, color: accentFlow),
                  const SizedBox(width: 6),
                  Text(
                    l10n.calendar_day_detail_edit,
                    style: MetraTypography.body.copyWith(
                      color: textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowBadge extends StatelessWidget {
  const _FlowBadge({required this.log, required this.isDark});

  final DailyLogEntity log;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final accentFlow =
        isDark ? MetraColors.dark.accentFlow : MetraColors.light.accentFlow;

    String? label;
    if (log.flowType == FlowType.mestruazioni && log.flowIntensity != null) {
      label = switch (log.flowIntensity!) {
        FlowIntensity.light => l10n.daily_entry_flow_light,
        FlowIntensity.medium => l10n.daily_entry_flow_medium,
        FlowIntensity.heavy => l10n.daily_entry_flow_heavy,
        FlowIntensity.veryHeavy => l10n.daily_entry_flow_veryHeavy,
      };
    } else if (log.flowType == FlowType.spotting) {
      label = l10n.daily_entry_flow_chip_spotting;
    } else if (log.flowType == FlowType.assente) {
      label = l10n.daily_entry_flow_chip_assente;
    }

    if (label == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: accentFlow.withValues(alpha: 0.09),
        border: Border.all(color: accentFlow.withValues(alpha: 0.27)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: MetraTypography.caption.copyWith(
          fontWeight: FontWeight.w500,
          color: accentFlow,
        ),
      ),
    );
  }
}

class _SymptomPill extends StatelessWidget {
  const _SymptomPill({required this.label, required this.isDark});

  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final accentFlow =
        isDark ? MetraColors.dark.accentFlow : MetraColors.light.accentFlow;
    final bgPrimary =
        isDark ? MetraColors.dark.bgPrimary : MetraColors.light.bgPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: accentFlow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: MetraTypography.tiny.copyWith(
          color: bgPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
