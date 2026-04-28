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

import '../../../core/theme/metra_colors.dart';
import '../../../core/theme/metra_spacing.dart';
import '../../../domain/entities/cycle_summary.dart';
import '../../../l10n/app_localizations.dart';
import 'timeline_card.dart';

class TimelineView extends StatelessWidget {
  const TimelineView({super.key, required this.summaries});

  final List<CycleSummary> summaries;

  @override
  Widget build(BuildContext context) {
    if (summaries.isEmpty) return const _EmptyState();
    return ListView.separated(
      padding: const EdgeInsets.all(MetraSpacing.s4),
      itemCount: summaries.length,
      separatorBuilder: (_, __) => const SizedBox(height: MetraSpacing.s2),
      itemBuilder: (_, i) => TimelineCard(summary: summaries[i]),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MetraSpacing.s8),
        child: Text(
          l10n.timeline_empty_hint,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isDark
                ? MetraColors.dark.textSecondary
                : MetraColors.light.textSecondary,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}
