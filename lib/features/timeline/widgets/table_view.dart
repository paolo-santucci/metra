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
import '../../../domain/entities/cycle_summary.dart';
import '../../../domain/entities/flow_intensity.dart';
import '../../../l10n/app_localizations.dart';

class TableView extends StatelessWidget {
  const TableView({super.key, required this.summaries});

  final List<CycleSummary> summaries;

  @override
  Widget build(BuildContext context) {
    if (summaries.isEmpty) return const _TableEmptyState();
    final l10n = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 90),
      child: Column(
        children: [
          _HeaderRow(l10n: l10n),
          ...summaries.map((s) => _DataRow(summary: s)),
        ],
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final ink = MetraColors.light.ink;
    final labelStyle = GoogleFonts.inter(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      // rgba(43,37,33,0.68) — inchiostro at 68% opacity per §10.4
      color: ink.withValues(alpha: 0.68),
      letterSpacing: 0.44, // 0.04em × 11px
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: ink.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: _CellRow(
        mese: Text(
          l10n.table_col_month,
          style: labelStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        ciclo: Text(
          l10n.table_col_cycle,
          style: labelStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        dur: Text(
          l10n.table_col_duration,
          style: labelStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        flusso: Text(
          l10n.table_col_flow,
          style: labelStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow({required this.summary});

  final CycleSummary summary;

  @override
  Widget build(BuildContext context) {
    final ink = MetraColors.light.ink;
    final tcScura = MetraColors.light.terracottaDeep;

    final raw = intl.DateFormat.yMMM('it').format(summary.cycle.startDate);
    final month = raw[0].toUpperCase() + raw.substring(1);

    final meseStyle = GoogleFonts.inter(fontSize: 14, color: ink);
    final secondaryStyle = GoogleFonts.inter(
      fontSize: 14,
      color: ink.withValues(alpha: 0.60),
    );
    final flussoStyle = GoogleFonts.inter(fontSize: 13, color: tcScura);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: MetraColors.light.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ink.withValues(alpha: 0.06)),
      ),
      child: _CellRow(
        mese: Text(
          month,
          style: meseStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        ciclo: Text(
          '${summary.cycle.cycleLength ?? '—'}g',
          style: secondaryStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        dur: Text(
          '${summary.cycle.periodLength ?? '—'}g',
          style: secondaryStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        flusso: Text(
          _flowLabel(summary.dominantFlow),
          style: flussoStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  String _flowLabel(FlowIntensity? flow) {
    switch (flow) {
      case null:
        return '—';
      case FlowIntensity.light:
        return 'Leggero';
      case FlowIntensity.medium:
        return 'Moderato';
      case FlowIntensity.heavy:
      // veryHeavy is a v3 back-compat value — treated as Abbondante
      case FlowIntensity.veryHeavy:
        return 'Abbondante';
    }
  }
}

/// Four-column row layout matching §10.4 grid "1fr 60px 50px 80px" with gap 8.
class _CellRow extends StatelessWidget {
  const _CellRow({
    required this.mese,
    required this.ciclo,
    required this.dur,
    required this.flusso,
  });

  final Widget mese;
  final Widget ciclo;
  final Widget dur;
  final Widget flusso;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: mese),
        const SizedBox(width: 8),
        SizedBox(width: 60, child: ciclo),
        const SizedBox(width: 8),
        SizedBox(width: 50, child: dur),
        const SizedBox(width: 8),
        SizedBox(width: 80, child: flusso),
      ],
    );
  }
}

class _TableEmptyState extends StatelessWidget {
  const _TableEmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(64),
        child: Text(
          l10n.timeline_empty_hint,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 15,
            color: MetraColors.light.textSecondary,
          ),
        ),
      ),
    );
  }
}
