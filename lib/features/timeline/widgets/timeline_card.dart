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
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl;

import '../../../core/theme/metra_colors.dart';
import '../../../core/theme/metra_typography.dart';
import '../../../core/widgets/metra_icon.dart';
import '../../../domain/entities/cycle_summary.dart';
import '../../../domain/entities/flow_intensity.dart';
import '../../../domain/entities/pain_symptom_type.dart';
import '../../../l10n/app_localizations.dart';

class TimelineCard extends StatelessWidget {
  const TimelineCard({super.key, required this.summary, required this.isLast});

  final CycleSummary summary;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TimelineRail(isLast: isLast),
          const SizedBox(width: 16),
          Expanded(child: _CardBody(summary: summary)),
        ],
      ),
    );
  }
}

class _TimelineRail extends StatelessWidget {
  const _TimelineRail({required this.isLast});

  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 18),
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: MetraColors.light.terracotta,
            ),
          ),
          if (!isLast)
            Expanded(
              child: Container(
                width: 2,
                margin: const EdgeInsets.only(top: 2),
                color: MetraColors.light.ink.withValues(alpha: 0.10),
              ),
            ),
        ],
      ),
    );
  }
}

class _CardBody extends StatelessWidget {
  const _CardBody({required this.summary});

  final CycleSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: MetraColors.light.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: MetraColors.light.ink.withValues(alpha: 0.07),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(summary: summary),
          const SizedBox(height: 6),
          _ChipRow(summary: summary),
          _Footer(summary: summary),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.summary});

  final CycleSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final rawMonth = intl.DateFormat.yMMM('it').format(summary.cycle.startDate);
    final monthLabel = rawMonth.isEmpty
        ? rawMonth
        : rawMonth[0].toUpperCase() + rawMonth.substring(1);
    final n = summary.cycle.periodLength;
    final durationLabel =
        n != null ? l10n.archive_card_duration_days(n) : 'Durata —g';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          monthLabel,
          style: MetraTypography.archiveMonth.copyWith(
            color: MetraColors.light.ink,
          ),
        ),
        Text(
          durationLabel,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: MetraColors.light.ink.withValues(alpha: 0.40),
          ),
        ),
      ],
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.summary});

  final CycleSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final chips = <Widget>[
      _FlowPill(flow: summary.dominantFlow),
      if (summary.dominantPainIntensity != null &&
          summary.dominantPainIntensity! > 0)
        _PainPill(intensity: summary.dominantPainIntensity!, l10n: l10n),
      ...summary.symptoms
          .where((t) => t != PainSymptomType.custom)
          .take(2)
          .map((t) => _SymptomPill(type: t, l10n: l10n)),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips,
    );
  }
}

class _FlowPill extends StatelessWidget {
  const _FlowPill({required this.flow});

  final FlowIntensity? flow;

  @override
  Widget build(BuildContext context) {
    final label = flow != null ? _flowLabel(flow!) : '—';
    return _MiniChip(
      svgBody: MetraIcons.dropFilled,
      iconColor: MetraColors.light.terracottaDeep,
      label: label,
      labelColor: MetraColors.light.terracottaDeep,
      bg: MetraColors.light.terracotta.withValues(alpha: 0x15 / 255),
    );
  }

  static String _flowLabel(FlowIntensity intensity) => switch (intensity) {
        FlowIntensity.light => 'Leggero',
        FlowIntensity.medium => 'Moderato',
        FlowIntensity.heavy => 'Abbondante',
        FlowIntensity.veryHeavy => 'Molto abbondante',
      };
}

class _PainPill extends StatelessWidget {
  const _PainPill({required this.intensity, required this.l10n});

  final int intensity;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final label = switch (intensity) {
      1 => l10n.daily_entry_pain_mild,
      2 => l10n.daily_entry_pain_moderate,
      _ => l10n.daily_entry_pain_severe,
    };
    return _MiniChip(
      svgBody: MetraIcons.zapFilled,
      iconColor: MetraColors.light.malva,
      label: label,
      labelColor: MetraColors.light.malva,
      bg: const Color.fromARGB(0x1F, 158, 116, 136),
    );
  }
}

class _SymptomPill extends StatelessWidget {
  const _SymptomPill({required this.type, required this.l10n});

  final PainSymptomType type;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return _MiniChip(
      svgBody: MetraIcons.starSmallFilled,
      iconColor: MetraColors.light.dustyOchre,
      label: _symptomLabel(l10n, type),
      labelColor: MetraColors.light.ink.withValues(alpha: 0.60),
      bg: MetraColors.light.dustyOchre.withValues(alpha: 0x18 / 255),
    );
  }

  static String _symptomLabel(AppLocalizations l10n, PainSymptomType type) =>
      switch (type) {
        PainSymptomType.cramps => l10n.daily_entry_symptom_cramps,
        PainSymptomType.backPain => l10n.daily_entry_symptom_backPain,
        PainSymptomType.headache => l10n.daily_entry_symptom_headache,
        PainSymptomType.migraine => l10n.daily_entry_symptom_migraine,
        PainSymptomType.bloating => l10n.daily_entry_symptom_bloating,
        PainSymptomType.fatigue => l10n.daily_entry_symptom_fatigue,
        PainSymptomType.nausea => l10n.daily_entry_symptom_nausea,
        PainSymptomType.breastTenderness =>
          l10n.daily_entry_symptom_breastTenderness,
        PainSymptomType.custom => '',
      };
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({
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

class _Footer extends StatelessWidget {
  const _Footer({required this.summary});

  final CycleSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final len = summary.cycle.cycleLength;
    final dayStr =
        intl.DateFormat('d MMM', 'it').format(summary.cycle.startDate);

    final text = len != null
        ? l10n.archive_card_footer(len, dayStr)
        : 'Ciclo —g · dal $dayStr';

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 12,
          color: MetraColors.light.ink.withValues(alpha: 0.40),
        ),
      ),
    );
  }
}
