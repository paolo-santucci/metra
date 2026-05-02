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

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  late final DateTime _today;

  bool _formInitialized = false;
  bool _symptomsInitialized = false;
  bool _userHasModifiedSymptoms = false;

  DailyLogEntity? _existingLog;
  FlowType? _flowType;
  FlowIntensity? _flowIntensity;
  FlowIntensity? _lastMensIntensity;
  int? _painIntensity;
  Set<PainSymptomType> _selectedSymptoms = {};
  List<String> _customSymptomLabels = [];
  late final TextEditingController _notesController;
  bool _addingSymptom = false;
  final TextEditingController _customSymptomController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _today = DateTime.utc(now.year, now.month, now.day);
    _notesController = TextEditingController();
    ref.listenManual<AsyncValue<DailyLogEntity?>>(
      dailyEntryProvider(_today),
      (_, next) => next.whenData(_initFromLog),
      fireImmediately: true,
    );
    ref.listenManual<AsyncValue<List<PainSymptomData>>>(
      painSymptomsProvider(_today),
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

  void _initFromLog(DailyLogEntity? log) {
    if (_formInitialized) return;
    _formInitialized = true;
    _existingLog = log;
    if (log == null) return;
    setState(() {
      _flowType = log.flowType;
      _flowIntensity = log.flowIntensity;
      _painIntensity = log.painEnabled ? log.painIntensity : null;
      if (log.notes != null) _notesController.text = log.notes!;
    });
  }

  void _initSymptoms(List<PainSymptomData> symptoms) {
    if (_symptomsInitialized) return;
    _symptomsInitialized = true;
    if (!_userHasModifiedSymptoms) {
      setState(() {
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
      });
    }
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final notifier = ref.read(dailyEntryProvider(_today).notifier);
    final notesText = _notesController.text.trim();

    final log = (_existingLog ?? DailyLogEntity(date: _today)).copyWith(
      flowType: _flowType,
      clearFlowType: _flowType == null,
      flowIntensity: _flowType == FlowType.mestruazioni ? _flowIntensity : null,
      clearFlowIntensity: _flowType != FlowType.mestruazioni,
      painEnabled: _painIntensity != null,
      painIntensity: _painIntensity,
      clearPainIntensity: _painIntensity == null,
      notesEnabled: notesText.isNotEmpty,
      notes: notesText.isNotEmpty ? notesText : null,
      clearNotes: notesText.isEmpty,
    );
    await notifier.save(log);

    if (!mounted) return;
    if (ref.read(dailyEntryProvider(_today)) is AsyncError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.common_error_generic)),
      );
      return;
    }

    try {
      final repo = await ref.read(dailyLogRepositoryProvider.future);
      await repo.replacePainSymptoms(
        _today,
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
    } catch (e) {
      debugPrint('replacePainSymptoms failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.common_error_generic)),
      );
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.daily_entry_save_action)),
    );
  }

  static const List<PainSymptomType> _symptomTypes = [
    PainSymptomType.cramps,
    PainSymptomType.headache,
    PainSymptomType.fatigue,
    PainSymptomType.backPain,
    PainSymptomType.nausea,
    PainSymptomType.bloating,
    PainSymptomType.breastTenderness,
  ];

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
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? MetraColors.dark.textPrimary : MetraColors.light.textPrimary;
    final textSecondary = isDark
        ? MetraColors.dark.textSecondary
        : MetraColors.light.textSecondary;
    final bgPrimary =
        isDark ? MetraColors.dark.bgPrimary : MetraColors.light.bgPrimary;
    final surfaceRaised =
        isDark ? MetraColors.dark.bgSurface : MetraColors.light.surfaceRaised;
    final accentFlow =
        isDark ? MetraColors.dark.accentFlow : MetraColors.light.accentFlow;
    final bgSunken =
        isDark ? MetraColors.dark.bgSunken : MetraColors.light.bgSunken;
    final borderStrong =
        isDark ? MetraColors.dark.borderStrong : MetraColors.light.borderStrong;
    final borderColor = isDark
        ? MetraColors.dark.textPrimary.withAlpha(0x12)
        : MetraColors.light.ink.withAlpha(0x12);

    final settings = ref.watch(settingsNotifierProvider).valueOrNull;
    final painEnabled = settings?.painEnabled ?? true;
    final notesEnabled = settings?.notesEnabled ?? true;

    final locale = Localizations.localeOf(context).languageCode;
    final rawDate = DateFormat('EEEE d MMMM', locale).format(DateTime.now());
    final dateStr =
        rawDate.substring(0, 1).toUpperCase() + rawDate.substring(1);

    final sectionLabelStyle = MetraTypography.caption.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: 0.72,
      color: textPrimary.withValues(alpha: 0.40),
    );

    final sectionBorder = Border(
      top: BorderSide(color: borderColor, width: 1),
      bottom: BorderSide(color: borderColor, width: 1),
    );

    return Scaffold(
      backgroundColor: bgPrimary,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: MetraSpacing.sp100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ───────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateStr,
                      style: MetraTypography.caption.copyWith(
                        color: textSecondary,
                      ),
                    ),
                    const SizedBox(height: MetraSpacing.s1),
                    Text(
                      l10n.today_how_are_you,
                      style: MetraTypography.screenTitle.copyWith(
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Flow section frame ────────────────────────────────────────
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

                // ── Pain section frame ──────────────────────────────────────
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

                // ── Symptoms section frame ────────────────────────────────
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
                          ..._symptomTypes.map((type) {
                            final label = _symptomLabel(type, l10n);
                            final selected = _selectedSymptoms.contains(type);
                            return ChoiceChipMetra(
                              label: label,
                              selected: selected,
                              semanticsLabel: label,
                              onSelected: (isSelected) {
                                setState(() {
                                  _userHasModifiedSymptoms = true;
                                  final updated = Set<PainSymptomType>.from(
                                    _selectedSymptoms,
                                  );
                                  if (isSelected) {
                                    updated.add(type);
                                  } else {
                                    updated.remove(type);
                                  }
                                  _selectedSymptoms = updated;
                                });
                              },
                            );
                          }),
                          ..._customSymptomLabels.map((label) {
                            return ChoiceChipMetra(
                              label: label,
                              selected: true,
                              semanticsLabel: label,
                              onSelected: (_) {
                                setState(() {
                                  _userHasModifiedSymptoms = true;
                                  _customSymptomLabels = _customSymptomLabels
                                      .where((l) => l != label)
                                      .toList();
                                });
                              },
                            );
                          }),
                          if (!_addingSymptom)
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _addingSymptom = true),
                              child: Container(
                                constraints:
                                    const BoxConstraints(minHeight: 44),
                                child: _AddSymptomChip(
                                  label: l10n.today_add_symptom,
                                  textSecondary: textSecondary,
                                ),
                              ),
                            )
                          else
                            Container(
                              constraints: const BoxConstraints(minHeight: 44),
                              child: _InlineSymptomInput(
                                controller: _customSymptomController,
                                textSecondary: textSecondary,
                                onConfirm: () {
                                  final text =
                                      _customSymptomController.text.trim();
                                  if (text.isEmpty) {
                                    setState(() => _addingSymptom = false);
                                    return;
                                  }
                                  final fixedLabels = _symptomTypes
                                      .map(
                                        (t) => _symptomLabel(t, l10n)
                                            .toLowerCase(),
                                      )
                                      .toSet();
                                  final alreadyExists = _customSymptomLabels
                                          .any(
                                        (l) =>
                                            l.toLowerCase() ==
                                            text.toLowerCase(),
                                      ) ||
                                      fixedLabels.contains(text.toLowerCase());
                                  setState(() {
                                    _userHasModifiedSymptoms = true;
                                    if (!alreadyExists) {
                                      _customSymptomLabels = [
                                        ..._customSymptomLabels,
                                        text,
                                      ];
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
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              if (notesEnabled) ...[
                const SizedBox(height: 1),

                // ── Notes section frame ─────────────────────────────────────
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
                        style:
                            MetraTypography.body.copyWith(color: textPrimary),
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
                            borderSide: BorderSide(
                              color: accentFlow,
                              width: 1.5,
                            ),
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
      ),
    );
  }
}

/// Inline text field that replaces the "+ Aggiungi" chip while editing.
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

/// Dashed-border chip for the "Aggiungi" action.
/// The '+' icon and label text are styled separately to match the mockup:
/// '+' at 18px / 0.35 alpha, label at 13px / 0.40 alpha, with 5px gap.
class _AddSymptomChip extends StatelessWidget {
  const _AddSymptomChip({
    required this.label,
    required this.textSecondary,
  });

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
