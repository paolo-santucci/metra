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
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl;

import '../../core/theme/metra_colors.dart';
import '../../core/theme/metra_spacing.dart';
import '../../core/theme/metra_typography.dart';
import '../../core/widgets/metra_icon.dart';
import '../../domain/entities/cycle_prediction.dart';
import '../../domain/entities/daily_log_entity.dart';
import '../../domain/entities/flow_intensity.dart';
import '../../domain/entities/flow_type.dart';
import '../../domain/entities/pain_symptom_data.dart';
import '../../domain/entities/pain_symptom_type.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/repository_providers.dart';
import '../../providers/use_case_providers.dart';
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

  // Italian day-of-week initials, Monday first (Bible § 8.2).
  static const List<String> _dayHeaders = ['L', 'M', 'M', 'G', 'V', 'S', 'D'];

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
    final selectedCycleDay =
        ref.watch(cycleDayForDateProvider(_selectedDate)).valueOrNull;
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
            final maxMonth = now.month == 12 ? 1 : now.month + 1;
            final maxYear = now.month == 12 ? now.year + 1 : now.year;
            final isAtMaxFuture =
                monthState.year == maxYear && monthState.month == maxMonth;
            final canGoNext = !isAtMaxFuture;

            // Bible § 8.1: "Month Year" — e.g. "Aprile 2025".
            final rawMonth = intl.DateFormat.MMMM(locale).format(
              DateTime(monthState.year, monthState.month),
            );
            final title =
                '${rawMonth.substring(0, 1).toUpperCase()}${rawMonth.substring(1)} ${monthState.year}';

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: MonthNavigator(
                    title: title,
                    prevLabel: l10n.calendar_prev_month,
                    nextLabel: l10n.calendar_next_month,
                    onPrev: () => ref
                        .read(calendarMonthProvider.notifier)
                        .goToPrevMonth(),
                    onNext: () => ref
                        .read(calendarMonthProvider.notifier)
                        .goToNextMonth(),
                    onToday: () {
                      ref
                          .read(calendarMonthProvider.notifier)
                          .goToToday();
                      final today = DateTime.now();
                      setState(
                        () => _selectedDate = DateTime.utc(
                          today.year,
                          today.month,
                          today.day,
                        ),
                      );
                    },
                    todayLabel: l10n.calendar_today,
                    canGoNext: canGoNext,
                  ),
                ),
                SliverToBoxAdapter(
                  child: _DayOfWeekHeader(
                    labels: _dayHeaders,
                    isDark: isDark,
                  ),
                ),
                SliverToBoxAdapter(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragEnd: (details) {
                      final velocity = details.primaryVelocity ?? 0;
                      if (velocity.abs() < 200.0) return;
                      final notifier = ref.read(calendarMonthProvider.notifier);
                      if (velocity > 0) {
                        // Right swipe → previous month (always allowed).
                        notifier.goToPrevMonth();
                      } else if (canGoNext) {
                        // Left swipe → next month (guarded by canGoNext).
                        notifier.goToNextMonth();
                      }
                    },
                    child: _CalendarGrid(
                      year: monthState.year,
                      month: monthState.month,
                      logs: monthState.logs,
                      daysWithSymptoms: monthState.daysWithSymptoms,
                      today: now,
                      l10n: l10n,
                      locale: locale,
                      prediction: prediction,
                      selectedDate: _selectedDate,
                      onDaySelected: (date) =>
                          setState(() => _selectedDate = date),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: CalendarLegend()),
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _DayDetailCard(
                    selectedDate: _selectedDate,
                    log: monthState.logs[_selectedDate],
                    symptoms: symptoms,
                    cycleDay: selectedCycleDay,
                    l10n: l10n,
                    locale: locale,
                    isDark: isDark,
                  ),
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
  });

  final List<String> labels;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    // Bible § 8.2: ink @ 35% alpha (0x59 = round(0.35 × 255)).
    final labelColor =
        (isDark ? MetraColors.dark.textPrimary : MetraColors.light.textPrimary)
            .withAlpha(0x59);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 4),
      child: Row(
        children: labels.map((label) {
          return Expanded(
            child: Center(
              child: Text(
                label,
                style: MetraTypography.dayHeader.copyWith(color: labelColor),
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
    required this.daysWithSymptoms,
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
  final Set<DateTime> daysWithSymptoms;
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
      padding: const EdgeInsets.symmetric(horizontal: MetraSpacing.s3),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1,
        mainAxisSpacing: 2,
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

        final todayUtc = DateTime.utc(today.year, today.month, today.day);
        final isToday = today.year == year &&
            today.month == month &&
            today.day == dayNumber;
        final isFuture = date.isAfter(todayUtc);
        final isFlow = log?.flowType == FlowType.mestruazioni;
        final isSpotting = log?.spotting ?? false;
        final hasNote = log?.notes != null && log!.notes!.isNotEmpty;
        final hasPrediction = !date.isBefore(todayUtc) &&
            (prediction?.containsDate(date) ?? false);
        final hasPain = log?.painEnabled ?? false;
        final hasSymptom = daysWithSymptoms.contains(date);

        return CalendarDay(
          date: date,
          semanticsLabel:
              _buildSemantics(date, log, isToday, hasPrediction, l10n),
          isFlow: isFlow,
          isSpotting: isSpotting,
          hasPrediction: hasPrediction,
          hasNote: hasNote,
          hasPain: hasPain,
          hasSymptom: hasSymptom,
          isToday: isToday,
          isSelected: selectedDate == date,
          isFuture: isFuture,
          onTap: isFuture ? null : () => onDaySelected(date),
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
    this.cycleDay,
  });

  final DateTime selectedDate;
  final DailyLogEntity? log;
  final List<PainSymptomData> symptoms;
  final int? cycleDay;
  final AppLocalizations l10n;
  final String locale;
  final bool isDark;

  String _symptomLabel(PainSymptomData symptom, AppLocalizations l10n) =>
      switch (symptom.symptomType) {
        PainSymptomType.cramps => l10n.daily_entry_symptom_cramps,
        PainSymptomType.headache => l10n.daily_entry_symptom_headache,
        PainSymptomType.bloating => l10n.daily_entry_symptom_bloating,
        PainSymptomType.backPain => l10n.daily_entry_symptom_backPain,
        PainSymptomType.migraine => l10n.daily_entry_symptom_migraine,
        PainSymptomType.custom =>
          symptom.customLabel ?? l10n.daily_entry_symptom_custom,
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
    final malva =
        isDark ? MetraColors.dark.accentPain : MetraColors.light.accentPain;
    final dustyOchre =
        isDark ? MetraColors.dark.accentWarmth : MetraColors.light.accentWarmth;
    final hasData = log != null;

    // Flow label — same logic as the removed _FlowBadge.
    String? flowLabel;
    if (log != null) {
      if (log!.flowType == FlowType.mestruazioni &&
          log!.flowIntensity != null) {
        flowLabel = switch (log!.flowIntensity!) {
          FlowIntensity.light => l10n.daily_entry_flow_intensity_light,
          FlowIntensity.medium => l10n.daily_entry_flow_intensity_medium,
          FlowIntensity.heavy ||
          FlowIntensity.veryHeavy =>
            l10n.daily_entry_flow_intensity_heavy,
        };
      } else if (log!.flowType == FlowType.spotting) {
        flowLabel = l10n.daily_entry_flow_chip_spotting;
      } else if (log!.flowType == FlowType.assente) {
        flowLabel = l10n.daily_entry_flow_chip_assente;
      }
    }

    // Pain label — same l10n keys used by timeline_card.dart.
    String? painLabel;
    if (log?.painIntensity != null && log!.painIntensity! > 0) {
      painLabel = switch (log!.painIntensity!) {
        1 => l10n.daily_entry_pain_mild,
        2 => l10n.daily_entry_pain_moderate,
        _ => l10n.daily_entry_pain_severe,
      };
    }

    // Note text — only when notes are enabled and non-empty.
    final noteText = (log?.notesEnabled == true &&
            log?.notes != null &&
            log!.notes!.isNotEmpty)
        ? log!.notes
        : null;

    final weekday = intl.DateFormat.EEEE(locale).format(selectedDate);
    final dayMonth = intl.DateFormat('d MMMM', locale).format(selectedDate);
    final dateLabel =
        '${weekday.substring(0, 1).toUpperCase()}${weekday.substring(1)} $dayMonth';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: bgSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Header (left-aligned, no right badge).
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                dateLabel,
                style: MetraTypography.titleMd.copyWith(color: textPrimary),
              ),
              if (!hasData) ...[
                const SizedBox(height: 2),
                Text(
                  l10n.calendar_day_detail_no_data,
                  style: MetraTypography.caption.copyWith(
                    color: textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ] else if (cycleDay != null) ...[
                const SizedBox(height: 2),
                Text(
                  l10n.calendar_day_detail_cycle_day(cycleDay!),
                  style: MetraTypography.caption.copyWith(
                    color: textSecondary,
                  ),
                ),
              ],
            ],
          ),
          // 2. Pills row (flow + pain + symptoms).
          if (flowLabel != null ||
              painLabel != null ||
              symptoms.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (flowLabel != null)
                  _DataPill(
                    svgBody: MetraIcons.dropFilled,
                    iconColor: accentFlow,
                    label: flowLabel,
                    labelColor: textPrimary,
                    bg: accentFlow.withValues(alpha: 0.08),
                  ),
                if (painLabel != null)
                  _DataPill(
                    svgBody: MetraIcons.zapFilled,
                    iconColor: malva,
                    label: painLabel,
                    labelColor: malva,
                    bg: malva.withValues(alpha: 0.12),
                  ),
                ...symptoms.map(
                  (s) => _DataPill(
                    svgBody: MetraIcons.starSmallFilled,
                    iconColor: dustyOchre,
                    label: _symptomLabel(s, l10n),
                    labelColor: textPrimary,
                    bg: dustyOchre.withValues(alpha: 0.10),
                  ),
                ),
              ],
            ),
          ],
          // 3. Note text.
          if (noteText != null) ...[
            const SizedBox(height: 8),
            Text(
              noteText,
              style: MetraTypography.body.copyWith(
                fontSize: 13,
                color: textSecondary,
                height: 1.5,
              ),
            ),
          ],
          // 4. CTA button.
          if (!selectedDate.isAfter(
            DateTime.utc(
              DateTime.now().year,
              DateTime.now().month,
              DateTime.now().day,
            ),
          )) ...[
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
                    MetraIcon(
                      svgBody: MetraIcons.note,
                      size: 16,
                      color: accentFlow,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      hasData
                          ? l10n.calendar_day_detail_edit
                          : l10n.calendar_day_detail_add,
                      style: MetraTypography.body.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? MetraColors.dark.accentFlowStrong
                            : MetraColors.light.terracottaDeep,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DataPill extends StatelessWidget {
  const _DataPill({
    required this.svgBody,
    required this.iconColor,
    required this.label,
    required this.labelColor,
    required this.bg,
  });

  final String svgBody;
  final Color iconColor;
  final String label;
  final Color labelColor;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MetraIcon(svgBody: svgBody, size: 11, color: iconColor, filled: true),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 11, color: labelColor),
          ),
        ],
      ),
    );
  }
}
