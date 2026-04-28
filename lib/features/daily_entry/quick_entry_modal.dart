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

import '../../core/theme/metra_colors.dart';
import '../../core/theme/metra_spacing.dart';
import '../../core/widgets/button_ghost.dart';
import '../../core/widgets/button_primary.dart';
import '../../core/widgets/section_title_metra.dart';
import '../../domain/entities/daily_log_entity.dart';
import '../../domain/entities/flow_intensity.dart';
import '../../l10n/app_localizations.dart';
import 'state/daily_entry_controller.dart';
import 'widgets/flow_intensity_picker.dart';

/// Today's quick daily entry: ≤3 taps to log flow.
///
/// Date is always today, normalized to UTC midnight.
/// Controlled via [dailyEntryProvider(today)].
///
/// The form body reveals with a 240ms slide-up + fade when data loads
/// (80ms when reduce-motion is active).
class QuickEntryModal extends ConsumerStatefulWidget {
  const QuickEntryModal({super.key});

  @override
  ConsumerState<QuickEntryModal> createState() => _QuickEntryModalState();
}

class _QuickEntryModalState extends ConsumerState<QuickEntryModal> {
  late final DateTime _today;
  FlowIntensity? _selectedFlow;
  bool _isSpotting = false;
  bool _initialized = false;

  /// Retains the full loaded entity so _save() can preserve pain/notes fields.
  DailyLogEntity? _existingLog;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // Normalize to UTC midnight so the provider family key matches the DB.
    _today = DateTime.utc(now.year, now.month, now.day);
  }

  void _initFromLog(DailyLogEntity? log) {
    if (_initialized) return;
    _initialized = true;
    _existingLog = log;
    if (log == null) return;
    _selectedFlow = log.flowIntensity;
    _isSpotting = log.spotting;
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!; // safe: delegates registered in MetraApp
    final notifier = ref.read(dailyEntryProvider(_today).notifier);

    // Merge flow/spotting changes onto the existing entity so pain, notes, and
    // other fields set via HistoricalEntryScreen are not silently destroyed.
    final log =
        _existingLog?.copyWith(
          flowIntensity: _selectedFlow,
          spotting: _isSpotting,
        ) ??
        DailyLogEntity(
          date: _today,
          flowIntensity: _selectedFlow,
          spotting: _isSpotting,
        );

    await notifier.save(log);

    if (!mounted) return;
    final currentState = ref.read(dailyEntryProvider(_today));
    if (currentState is AsyncError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.common_error_generic)),
      );
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // safe: delegates registered in MetraApp
    final l10n = AppLocalizations.of(context)!;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDark ? MetraColors.dark.bgPrimary : MetraColors.light.bgPrimary;

    final duration = MediaQuery.of(context).disableAnimations
        ? const Duration(milliseconds: 80)
        : const Duration(milliseconds: 240);

    final logAsync = ref.watch(dailyEntryProvider(_today));
    logAsync.whenData(_initFromLog);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Text(l10n.daily_entry_title),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
          tooltip: l10n.daily_entry_cancel,
        ),
      ),
      body: AnimatedSwitcher(
        duration: duration,
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeOut,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: logAsync.when(
          loading: () => Center(
            key: const ValueKey<String>('loading'),
            child: Semantics(
              label: l10n.common_loading,
              child: const CircularProgressIndicator(),
            ),
          ),
          error: (_, __) => Center(
            key: const ValueKey<String>('error'),
            child: Text(l10n.common_error_generic),
          ),
          data: (_) => _buildForm(
            context,
            l10n,
            key: const ValueKey<String>('form'),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(
    BuildContext context,
    AppLocalizations l10n, {
    Key? key,
  }) {
    return SafeArea(
      key: key,
      child: Padding(
        padding: const EdgeInsets.all(MetraSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitleMetra(title: l10n.daily_entry_flow_label),
            const SizedBox(height: MetraSpacing.s3),
            FlowIntensityPicker(
              selectedFlow: _selectedFlow,
              isSpotting: _isSpotting,
              onFlowChanged: (flow) => setState(() {
                _selectedFlow = flow;
                if (flow != null) _isSpotting = false;
              }),
              onSpottingChanged: (spotting) => setState(() {
                _isSpotting = spotting;
                if (spotting) _selectedFlow = null;
              }),
            ),
            const SizedBox(height: MetraSpacing.s6),
            Row(
              children: [
                Expanded(
                  child: ButtonPrimary(
                    label: l10n.daily_entry_save,
                    semanticsLabel: l10n.daily_entry_save,
                    onPressed: _save,
                  ),
                ),
                const SizedBox(width: MetraSpacing.s3),
                ButtonGhost(
                  label: l10n.daily_entry_cancel,
                  semanticsLabel: l10n.daily_entry_cancel,
                  onPressed: () => context.pop(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
