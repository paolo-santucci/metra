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
import '../../core/widgets/text_field_metra.dart';
import '../../domain/entities/daily_log_entity.dart';
import '../../domain/entities/flow_intensity.dart';
import '../../domain/entities/pain_symptom_data.dart';
import '../../domain/entities/pain_symptom_type.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/repository_providers.dart';
import 'state/daily_entry_controller.dart';
import 'widgets/flow_intensity_picker.dart';
import 'widgets/pain_intensity_slider.dart';
import 'widgets/symptom_chips_row.dart';

/// Full-screen entry for logging or editing data for an arbitrary past date.
///
/// [date] must be a UTC-midnight DateTime; the router parses and normalizes it.
class HistoricalEntryScreen extends ConsumerStatefulWidget {
  const HistoricalEntryScreen({super.key, required this.date});

  final DateTime date;

  @override
  ConsumerState<HistoricalEntryScreen> createState() =>
      _HistoricalEntryScreenState();
}

class _HistoricalEntryScreenState extends ConsumerState<HistoricalEntryScreen> {
  // Tracks whether we have seeded form state from the loaded log.
  bool _formInitialized = false;

  // Tracks whether _selectedSymptoms has been seeded from the DB.
  // When false, _save() skips replacePainSymptoms to avoid erasing data that
  // has not yet been loaded.
  bool _symptomsInitialized = false;

  // Whether an existing log was loaded (used to show delete action).
  bool _hasExistingLog = false;

  // Form fields mirroring DailyLogEntity.
  FlowIntensity? _selectedFlow;
  bool _isSpotting = false;
  bool _painEnabled = false;
  int _painIntensity = 0;
  bool _notesEnabled = false;
  Set<PainSymptomType> _selectedSymptoms = {};

  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  /// Seeds form from the first data that arrives. Ignores subsequent updates
  /// so in-progress edits are not overwritten by stream refreshes.
  void _initFromLog(DailyLogEntity? log) {
    if (_formInitialized) return;
    _formInitialized = true;
    _hasExistingLog = log != null;
    if (log == null) return;

    // Do not log entity contents — security requirement.
    _selectedFlow = log.flowIntensity;
    _isSpotting = log.spotting;
    _painEnabled = log.painEnabled;
    _painIntensity = log.painIntensity ?? 0;
    _notesEnabled = log.notesEnabled;
    if (log.notes != null) {
      _notesController.text = log.notes!; // safe: notes is non-null checked
    }
  }

  /// Seeds [_selectedSymptoms] from the one-shot [painSymptomsProvider] load.
  /// Only runs once; subsequent calls are no-ops.
  void _initSymptoms(List<PainSymptomData> symptoms) {
    if (_symptomsInitialized) return;
    _symptomsInitialized = true;
    _selectedSymptoms = symptoms.map((s) => s.symptomType).toSet();
  }

  DailyLogEntity _buildEntity() => DailyLogEntity(
    date: widget.date,
    flowIntensity: _selectedFlow,
    spotting: _isSpotting,
    painEnabled: _painEnabled,
    painIntensity: _painEnabled ? _painIntensity : null,
    notesEnabled: _notesEnabled,
    notes:
        _notesEnabled && _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
  );

  Future<void> _save() async {
    // safe: delegates registered in MetraApp
    final l10n = AppLocalizations.of(context)!;
    final notifier = ref.read(dailyEntryProvider(widget.date).notifier);
    await notifier.save(_buildEntity());

    if (!mounted) return;
    final currentState = ref.read(dailyEntryProvider(widget.date));
    if (currentState is AsyncError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.common_error_generic)),
      );
      return;
    }

    // Persist symptom chips only when we have successfully loaded them first.
    // If symptoms were never fetched (_symptomsInitialized == false), skipping
    // replacePainSymptoms preserves whatever was already in the DB.
    if (_symptomsInitialized) {
      try {
        final repo = await ref.read(dailyLogRepositoryProvider.future);
        await repo.replacePainSymptoms(
          widget.date,
          _selectedSymptoms
              .map((type) => PainSymptomData(symptomType: type))
              .toList(),
        );
      } catch (e) {
        // Symptom persistence failure is non-fatal: surface in debug only.
        assert(() {
          debugPrint('replacePainSymptoms failed: $e');
          return true;
        }());
      }
    }

    if (!mounted) return;
    context.pop();
  }

  Future<void> _delete() async {
    // safe: delegates registered in MetraApp
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(l10n.daily_entry_delete_confirmation_title),
            content: Text(l10n.daily_entry_delete_confirmation_body),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(l10n.daily_entry_cancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(l10n.common_delete),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    final notifier = ref.read(dailyEntryProvider(widget.date).notifier);
    await notifier.delete();

    if (!mounted) return;
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    // safe: delegates registered in MetraApp
    final l10n = AppLocalizations.of(context)!;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDark ? MetraColors.dark.bgPrimary : MetraColors.light.bgPrimary;

    final logAsync = ref.watch(dailyEntryProvider(widget.date));
    // Seed form on first data; no-op after initialization.
    logAsync.whenData(_initFromLog);

    // One-shot symptom load — FutureProvider resolves once, never re-fires.
    // _initSymptoms guards against double-seeding.
    ref
        .watch(painSymptomsProvider(widget.date))
        .whenData(_initSymptoms);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Text(l10n.daily_entry_title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
          tooltip: l10n.daily_entry_cancel,
        ),
        actions: [
          if (_hasExistingLog)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.common_delete,
              onPressed: _delete,
            ),
        ],
      ),
      body: logAsync.when(
        loading: () => Center(
          child: Semantics(
            label: l10n.common_loading,
            child: const CircularProgressIndicator(),
          ),
        ),
        error: (_, __) => Center(child: Text(l10n.common_error_generic)),
        data: (_) => _buildForm(context, l10n),
      ),
    );
  }

  Widget _buildForm(BuildContext context, AppLocalizations l10n) {
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(MetraSpacing.s4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Flow section
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

                  // Pain section — toggle + slider.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SectionTitleMetra(title: l10n.daily_entry_pain_label),
                      Semantics(
                        label: l10n.daily_entry_pain_label,
                        toggled: _painEnabled,
                        child: Switch(
                          value: _painEnabled,
                          onChanged: (v) => setState(() => _painEnabled = v),
                        ),
                      ),
                    ],
                  ),
                  PainIntensitySlider(
                    enabled: _painEnabled,
                    value: _painIntensity,
                    onChanged: (v) => setState(() => _painIntensity = v),
                  ),
                  const SizedBox(height: MetraSpacing.s6),

                  // Symptoms section
                  SectionTitleMetra(title: l10n.daily_entry_symptoms_label),
                  const SizedBox(height: MetraSpacing.s3),
                  SymptomChipsRow(
                    selected: _selectedSymptoms,
                    onChanged: (s) => setState(() => _selectedSymptoms = s),
                  ),
                  const SizedBox(height: MetraSpacing.s6),

                  // Notes section — toggle + text field.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SectionTitleMetra(title: l10n.daily_entry_notes_label),
                      Semantics(
                        label: l10n.daily_entry_notes_label,
                        toggled: _notesEnabled,
                        child: Switch(
                          value: _notesEnabled,
                          onChanged: (v) => setState(() => _notesEnabled = v),
                        ),
                      ),
                    ],
                  ),
                  if (_notesEnabled) ...[
                    const SizedBox(height: MetraSpacing.s3),
                    Semantics(
                      label: l10n.daily_entry_notes_label,
                      textField: true,
                      child: TextFieldMetra(
                        controller: _notesController,
                        hint: l10n.daily_entry_notes_placeholder,
                        maxLines: null,
                      ),
                    ),
                  ],
                  const SizedBox(height: MetraSpacing.s8),
                ],
              ),
            ),
          ),
          // Bottom action bar — always visible.
          _BottomBar(onSave: _save, onCancel: () => context.pop()),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.onSave, required this.onCancel});

  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    // safe: delegates registered in MetraApp
    final l10n = AppLocalizations.of(context)!;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDark ? MetraColors.dark.bgSurface : MetraColors.light.bgSurface;
    final borderColor =
        isDark ? MetraColors.dark.borderSubtle : MetraColors.light.borderSubtle;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: MetraSpacing.s4,
        vertical: MetraSpacing.s3,
      ),
      child: Row(
        children: [
          Expanded(
            child: ButtonPrimary(
              label: l10n.daily_entry_save,
              semanticsLabel: l10n.daily_entry_save,
              onPressed: onSave,
            ),
          ),
          const SizedBox(width: MetraSpacing.s3),
          ButtonGhost(
            label: l10n.daily_entry_cancel,
            semanticsLabel: l10n.daily_entry_cancel,
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}
