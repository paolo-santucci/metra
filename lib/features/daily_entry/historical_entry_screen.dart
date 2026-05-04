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
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/metra_colors.dart';
import '../../core/theme/metra_spacing.dart';
import '../../core/theme/metra_typography.dart';
import '../../core/widgets/choice_chip_metra.dart';
import '../../domain/entities/daily_log_entity.dart';
import '../../domain/entities/flow_intensity.dart';
import '../../domain/entities/flow_type.dart';
import '../../domain/entities/pain_symptom_data.dart';
import '../../domain/entities/pain_symptom_type.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/repository_providers.dart';
import '../settings/state/settings_notifier.dart';
import 'state/daily_entry_controller.dart';
import 'widgets/circle_pain_picker.dart';
import 'widgets/flow_intensity_dots.dart';
import 'widgets/flow_type_chips.dart';
// symptom_chips_row omitted; chips rendered inline via ChoiceChipMetra;

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
  FlowType? _flowType;
  FlowIntensity? _flowIntensity;
  FlowIntensity? _lastMensIntensity;
  bool _otherDischarge = false;
  // null = not logged; 0 = Nessuno (explicit zero); 1-3 = pain levels.
  int? _painIntensity;
  Set<PainSymptomType> _selectedSymptoms = {};
  List<String> _customSymptomLabels = [];
  bool _addingSymptom = false;

  late final TextEditingController _notesController;
  final TextEditingController _customSymptomController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();
    ref.listenManual<AsyncValue<DailyLogEntity?>>(
      dailyEntryProvider(widget.date),
      (_, next) => next.whenData(_initFromLog),
      fireImmediately: true,
    );
    ref.listenManual<AsyncValue<List<PainSymptomData>>>(
      painSymptomsProvider(widget.date),
      (_, next) => next.whenData(_initSymptoms),
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    _customSymptomController.dispose();
    super.dispose();
  }

  /// Seeds form from the first data that arrives. Ignores subsequent updates
  /// so in-progress edits are not overwritten by stream refreshes.
  void _initFromLog(DailyLogEntity? log) {
    if (_formInitialized) return;
    _formInitialized = true;
    _hasExistingLog = log != null;
    if (log == null) return;

    _flowType = log.flowType;
    _flowIntensity = log.flowIntensity;
    _otherDischarge = log.otherDischarge;
    _painIntensity = log.painEnabled ? log.painIntensity : null;
    if (log.notes != null) {
      _notesController.text = log.notes!;
    }
  }

  /// Seeds [_selectedSymptoms] and [_customSymptomLabels] from the one-shot
  /// [painSymptomsProvider] load.
  void _initSymptoms(List<PainSymptomData> symptoms) {
    if (_symptomsInitialized) return;
    _symptomsInitialized = true;
    _selectedSymptoms = symptoms
        .where((s) => s.symptomType != PainSymptomType.custom)
        .map((s) => s.symptomType)
        .toSet();
    _customSymptomLabels = symptoms
        .where(
          (s) =>
              s.symptomType == PainSymptomType.custom &&
              s.customLabel != null &&
              s.customLabel!.isNotEmpty,
        )
        .map((s) => s.customLabel!)
        .toList();
  }

  DailyLogEntity _buildEntity() {
    final notesText = _notesController.text.trim();
    return DailyLogEntity(
      date: widget.date,
      flowType: _flowType,
      flowIntensity: _flowType == FlowType.mestruazioni ? _flowIntensity : null,
      otherDischarge: _otherDischarge,
      painEnabled: _painIntensity != null,
      painIntensity: _painIntensity,
      notesEnabled: notesText.isNotEmpty,
      notes: notesText.isNotEmpty ? notesText : null,
    );
  }

  Future<void> _save() async {
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

    if (_symptomsInitialized) {
      try {
        final repo = await ref.read(dailyLogRepositoryProvider.future);
        await repo.replacePainSymptoms(
          widget.date,
          <PainSymptomData>[
            ..._selectedSymptoms.map((t) => PainSymptomData(symptomType: t)),
            ..._customSymptomLabels.map(
              (label) => PainSymptomData(
                symptomType: PainSymptomType.custom,
                customLabel: label,
              ),
            ),
          ],
        );
        ref.invalidate(painSymptomsProvider(widget.date));
      } catch (e) {
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
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
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
    final l10n = AppLocalizations.of(context)!;
    final bgColor = MetraColors.of(context).bgPrimary;

    final logAsync = ref.watch(dailyEntryProvider(widget.date));
    ref.watch(painSymptomsProvider(widget.date));

    final settings = ref.watch(settingsNotifierProvider).valueOrNull;
    final painEnabled = settings?.painEnabled ?? true;
    final notesEnabled = settings?.notesEnabled ?? true;

    return Scaffold(
      backgroundColor: bgColor,
      body: logAsync.when(
        loading: () => SafeArea(
          child: Center(
            child: Semantics(
              label: l10n.common_loading,
              child: const CircularProgressIndicator(),
            ),
          ),
        ),
        error: (_, __) => SafeArea(
          child: Center(
            child: Semantics(
              liveRegion: true,
              child: Text(l10n.common_error_generic),
            ),
          ),
        ),
        data: (_) => _buildForm(context, l10n, painEnabled, notesEnabled),
      ),
    );
  }

  Widget _buildForm(
    BuildContext context,
    AppLocalizations l10n,
    bool painEnabled,
    bool notesEnabled,
  ) {
    final colors = MetraColors.of(context);
    final textPrimary = colors.textPrimary;
    final textSecondary = colors.textSecondary;
    final accentFlow = colors.accentFlow;
    final bgSunken = colors.bgSunken;
    final borderStrong = colors.borderStrong;
    final surfaceRaised = colors.bgSurface;
    final borderColor = colors.ink.withAlpha(0x12);

    final locale = Localizations.localeOf(context).languageCode;
    final rawDate = DateFormat('EEEE d MMMM', locale).format(widget.date);
    final dateStr =
        rawDate.substring(0, 1).toUpperCase() + rawDate.substring(1);

    final sectionLabelStyle = MetraTypography.caption.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: 0.06 * 12,
      color: textPrimary.withValues(alpha: 0.40),
    );

    final sectionBorder = Border(
      top: BorderSide(color: borderColor, width: 1),
      bottom: BorderSide(color: borderColor, width: 1),
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: MetraSpacing.sp100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Bare header — no Material AppBar.
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.pop(),
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.arrow_back_ios_rounded,
                            size: 18,
                            color: textSecondary,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (_hasExistingLog)
                        GestureDetector(
                          onTap: _delete,
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateStr,
                    style:
                        MetraTypography.caption.copyWith(color: textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.today_how_are_you,
                    style: MetraTypography.screenTitle
                        .copyWith(color: textPrimary),
                  ),
                ],
              ),
            ),

            // ── Flusso section frame ──────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: surfaceRaised,
                border: sectionBorder,
              ),
              padding: const EdgeInsets.symmetric(
                vertical: MetraSpacing.sp18,
                horizontal: MetraSpacing.s6,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.daily_entry_flow_label.toUpperCase(),
                    style: sectionLabelStyle,
                  ),
                  const SizedBox(height: MetraSpacing.s4),
                  FlowTypeChips(
                    selected: _flowType,
                    onChanged: (newType) {
                      setState(() {
                        if (_flowType == FlowType.mestruazioni &&
                            newType != FlowType.mestruazioni) {
                          _lastMensIntensity = _flowIntensity;
                        }
                        _flowType = newType;
                        if (newType == FlowType.mestruazioni) {
                          _flowIntensity =
                              _lastMensIntensity ?? FlowIntensity.medium;
                        } else {
                          _flowIntensity = null;
                        }
                      });
                    },
                  ),
                  if (_flowType == FlowType.mestruazioni) ...[
                    const SizedBox(height: MetraSpacing.s4),
                    FlowIntensityDots(
                      selected: _flowIntensity,
                      onChanged: (v) => setState(() => _flowIntensity = v),
                    ),
                  ],
                  if (_flowType == FlowType.spotting) ...[
                    const SizedBox(height: MetraSpacing.sp14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: MetraSpacing.sp14,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: accentFlow.withValues(alpha: 0.051),
                        border: Border.all(
                          color: accentFlow.withValues(alpha: 0.157),
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(MetraRadius.smm),
                      ),
                      child: Text(
                        l10n.daily_entry_spotting_note,
                        style: MetraTypography.tiny.copyWith(
                          color: textPrimary.withValues(alpha: 0.65),
                          fontWeight: FontWeight.w400,
                          height: 1.55,
                        ),
                      ),
                    ),
                  ],
                  if (_flowType == FlowType.assente) ...[
                    const SizedBox(height: MetraSpacing.sp14),
                    Row(
                      children: [
                        Icon(
                          Icons.check,
                          color: textPrimary.withValues(alpha: 0.35),
                          size: 16,
                        ),
                        const SizedBox(width: MetraSpacing.s2),
                        Text(
                          l10n.daily_entry_assente_confirmation,
                          style: MetraTypography.tiny.copyWith(
                            color: textPrimary.withValues(alpha: 0.45),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            if (painEnabled) ...[
              const SizedBox(height: 1),

              // ── Dolore section frame ────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: surfaceRaised,
                  border: sectionBorder,
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: MetraSpacing.sp18,
                  horizontal: MetraSpacing.s6,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.today_pain_intensity_label.toUpperCase(),
                      style: sectionLabelStyle,
                    ),
                    const SizedBox(height: MetraSpacing.s4),
                    CirclePainPicker(
                      selected: _painIntensity,
                      onChanged: (v) => setState(() => _painIntensity = v),
                    ),
                  ],
                ),
              ),
            ],

            if (painEnabled) ...[
              const SizedBox(height: 1),

              // ── Sintomi section frame ───────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: surfaceRaised,
                  border: sectionBorder,
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: MetraSpacing.sp18,
                  horizontal: MetraSpacing.s6,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.daily_entry_symptoms_label.toUpperCase(),
                      style: sectionLabelStyle,
                    ),
                    const SizedBox(height: MetraSpacing.s4),
                    Wrap(
                      spacing: MetraSpacing.s2,
                      runSpacing: MetraSpacing.s2,
                      children: [
                        ..._buildSymptomChips(l10n, textPrimary, textSecondary),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            if (notesEnabled) ...[
              const SizedBox(height: 1),

              // ── Nota libera section frame ───────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: surfaceRaised,
                  border: sectionBorder,
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: MetraSpacing.sp18,
                  horizontal: MetraSpacing.s6,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.today_notes_label.toUpperCase(),
                      style: sectionLabelStyle,
                    ),
                    const SizedBox(height: MetraSpacing.s4),
                    TextField(
                      controller: _notesController,
                      minLines: 3,
                      maxLines: 6,
                      style: MetraTypography.body.copyWith(color: textPrimary),
                      decoration: InputDecoration(
                        hintText: l10n.today_notes_hint,
                        hintStyle: MetraTypography.body.copyWith(
                          fontSize: 15,
                          color: textPrimary.withValues(alpha: 0.35),
                        ),
                        filled: true,
                        fillColor: bgSunken,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: MetraSpacing.sp14,
                          vertical: MetraSpacing.s3,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(MetraRadius.md),
                          borderSide:
                              BorderSide(color: borderStrong, width: 1.5),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(MetraRadius.md),
                          borderSide:
                              BorderSide(color: borderStrong, width: 1.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(MetraRadius.md),
                          borderSide: BorderSide(color: accentFlow, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── Save CTA ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MetraSpacing.s6,
                MetraSpacing.s6,
                MetraSpacing.s6,
                0,
              ),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  backgroundColor: accentFlow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(MetraRadius.lg),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                ),
                onPressed: _save,
                icon: const Icon(Icons.check, size: 18),
                label: Text(l10n.daily_entry_save_action),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const List<PainSymptomType> _symptomTypes = [
    PainSymptomType.headache,
    PainSymptomType.fatigue,
    PainSymptomType.backPain,
    PainSymptomType.nausea,
    PainSymptomType.bloating,
    PainSymptomType.breastTenderness,
  ];

  String _symptomLabel(PainSymptomType type, AppLocalizations l10n) =>
      switch (type) {
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

  List<Widget> _buildSymptomChips(
    AppLocalizations l10n,
    Color textPrimary,
    Color textSecondary,
  ) {
    final fixedChips = _symptomTypes.map((type) {
      final label = _symptomLabel(type, l10n);
      return ChoiceChipMetra(
        label: label,
        selected: _selectedSymptoms.contains(type),
        semanticsLabel: label,
        onSelected: (isSelected) {
          setState(() {
            final updated = Set<PainSymptomType>.from(_selectedSymptoms);
            if (isSelected) {
              updated.add(type);
            } else {
              updated.remove(type);
            }
            _selectedSymptoms = updated;
          });
        },
      );
    });

    final customChips = _customSymptomLabels.map((label) {
      return ChoiceChipMetra(
        label: label,
        selected: true,
        semanticsLabel: label,
        onSelected: (_) {
          setState(() {
            _customSymptomLabels =
                _customSymptomLabels.where((l) => l != label).toList();
          });
        },
      );
    });

    final Widget addWidget = _addingSymptom
        ? Container(
            constraints: const BoxConstraints(minHeight: 44),
            child: _InlineSymptomInput(
              controller: _customSymptomController,
              textSecondary: textSecondary,
              onConfirm: () {
                final text = _customSymptomController.text.trim();
                if (text.isEmpty) {
                  setState(() => _addingSymptom = false);
                  return;
                }
                final fixedLabels = _symptomTypes
                    .map((t) => _symptomLabel(t, l10n).toLowerCase())
                    .toSet();
                final alreadyExists = _customSymptomLabels.any(
                      (l) => l.toLowerCase() == text.toLowerCase(),
                    ) ||
                    fixedLabels.contains(text.toLowerCase());
                setState(() {
                  if (!alreadyExists) {
                    _customSymptomLabels = [..._customSymptomLabels, text];
                  }
                  _addingSymptom = false;
                  _customSymptomController.clear();
                });
              },
              onCancel: () => setState(() {
                _addingSymptom = false;
                _customSymptomController.clear();
              }),
            ),
          )
        : GestureDetector(
            onTap: () => setState(() => _addingSymptom = true),
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              child: _AddSymptomChip(
                label: l10n.today_add_symptom,
                textSecondary: textSecondary,
              ),
            ),
          );

    return [...fixedChips, ...customChips, addWidget];
  }
}

// ── Inline symptom input ──────────────────────────────────────────────────────

class _InlineSymptomInput extends StatelessWidget {
  const _InlineSymptomInput({
    required this.controller,
    required this.textSecondary,
    required this.onConfirm,
    required this.onCancel,
  });

  final TextEditingController controller;
  final Color textSecondary;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 100, maxWidth: 160),
          child: TextField(
            controller: controller,
            autofocus: true,
            onSubmitted: (_) => onConfirm(),
            inputFormatters: [LengthLimitingTextInputFormatter(40)],
            style: MetraTypography.caption.copyWith(color: textSecondary),
            decoration: InputDecoration(
              hintText: 'es. Vertigini',
              hintStyle: MetraTypography.caption.copyWith(
                color: textSecondary.withValues(alpha: 0.5),
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: MetraSpacing.s4,
                vertical: MetraSpacing.s2,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(MetraRadius.md),
                borderSide:
                    BorderSide(color: textSecondary.withValues(alpha: 0.25)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(MetraRadius.md),
                borderSide:
                    BorderSide(color: textSecondary.withValues(alpha: 0.25)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(MetraRadius.md),
                borderSide:
                    BorderSide(color: textSecondary.withValues(alpha: 0.5)),
              ),
            ),
          ),
        ),
        TextButton(
          onPressed: onConfirm,
          style: TextButton.styleFrom(
            minimumSize: const Size(44, 44),
            padding: EdgeInsets.zero,
          ),
          child: Text(
            'OK',
            style: MetraTypography.caption.copyWith(
              color: textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Dashed "add" chip ─────────────────────────────────────────────────────────

/// Dashed-border chip for the "Aggiungi" action.
/// The '+' icon and label text are styled separately to match the mockup:
/// '+' at 18px / 0.35 alpha, label at 13px / 0.40 alpha, with 5px gap.
class _AddSymptomChip extends StatelessWidget {
  const _AddSymptomChip({required this.label, required this.textSecondary});

  final String label;
  final Color textSecondary;

  @override
  Widget build(BuildContext context) {
    final plusColor = textSecondary.withValues(alpha: 0.35);
    final labelColor = textSecondary.withValues(alpha: 0.40);
    return CustomPaint(
      painter:
          _DashedBorderPainter(color: textSecondary.withValues(alpha: 0.25)),
      child: SizedBox(
        height: 36,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '+',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18,
                  color: plusColor,
                  height: 1,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: labelColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const dashWidth = 4.0;
    const dashSpace = 3.0;
    const radius = 20.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          const Radius.circular(radius),
        ),
      );

    final pathMetrics = path.computeMetrics();
    for (final metric in pathMetrics) {
      double distance = 0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(
            distance,
            (distance + dashWidth).clamp(0, metric.length),
          ),
          paint,
        );
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.color != color;
}
