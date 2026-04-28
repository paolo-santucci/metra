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

import '../../core/theme/metra_colors.dart';
import '../../core/theme/metra_spacing.dart';
import '../../core/widgets/segmented_control_metra.dart';
import '../../l10n/app_localizations.dart';
import 'state/timeline_controller.dart';
import 'widgets/table_view.dart';
import 'widgets/timeline_view.dart';

enum _ViewMode { timeline, table }

class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  _ViewMode _mode = _ViewMode.timeline;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final summariesAsync = ref.watch(timelineProvider);

    return Scaffold(
      backgroundColor:
          isDark ? MetraColors.dark.bgPrimary : MetraColors.light.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MetraSpacing.s4,
                MetraSpacing.s4,
                MetraSpacing.s4,
                MetraSpacing.s2,
              ),
              child: SegmentedControlMetra(
                segments: [l10n.timeline_view_toggle, l10n.table_view_toggle],
                selectedIndex: _mode.index,
                onChanged: (i) => setState(() => _mode = _ViewMode.values[i]),
              ),
            ),
            Expanded(
              child: summariesAsync.when(
                loading: () => Center(
                  child: Semantics(
                    label: l10n.common_loading,
                    child: const CircularProgressIndicator(),
                  ),
                ),
                error: (_, __) => Center(
                  child: Text(
                    l10n.common_error_generic,
                    style: TextStyle(
                      color: isDark
                          ? MetraColors.dark.textSecondary
                          : MetraColors.light.textSecondary,
                    ),
                  ),
                ),
                data: (summaries) => _mode == _ViewMode.timeline
                    ? TimelineView(summaries: summaries)
                    : TableView(summaries: summaries),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
