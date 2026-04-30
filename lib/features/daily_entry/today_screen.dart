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
import 'package:intl/intl.dart';

import '../../core/theme/metra_colors.dart';
import '../../core/theme/metra_spacing.dart';
import '../../core/theme/metra_typography.dart';
import '../../core/widgets/choice_chip_metra.dart';
import '../../domain/entities/daily_log_entity.dart';
import '../../domain/entities/flow_intensity.dart';
import '../../domain/entities/pain_symptom_data.dart';
import '../../domain/entities/pain_symptom_type.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/repository_providers.dart';
import 'state/daily_entry_controller.dart';
import 'widgets/circle_flow_picker.dart';
import 'widgets/circle_pain_picker.dart';

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  late final DateTime _today;

  bool _formInitialized = false;
  bool _symptomsInitialized = false;

  FlowIntensity? _selectedFlow;
  bool _isSpotting = false;
  PainLevel _painLevel = PainLevel.none;
  Set<PainSymptomType> _selectedSymptoms = {};
  late final TextEditingController _notesController;

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
    super.dispose();
  }

  void _initFromLog(DailyLogEntity? log) {
    if (_formInitialized) return;
    _formInitialized = true;
    if (log == null) return;
    setState(() {
      _isSpotting = log.spotting;
      _selectedFlow = log.flowIntensity;
      _painLevel = _toPainLevel(log);
      if (log.notes != null) _notesController.text = log.notes!;
    });
  }

  void _initSymptoms(List<PainSymptomData> symptoms) {
    if (_symptomsInitialized) return;
    _symptomsInitialized = true;
    setState(() {
      _selectedSymptoms = symptoms.map((s) => s.symptomType).toSet();
    });
  }

  PainLevel _toPainLevel(DailyLogEntity entity) {
    if (!entity.painEnabled || entity.painIntensity == null) {
      return PainLevel.none;
    }
    final p = entity.painIntensity!;
    if (p <= 3) return PainLevel.mild;
    if (p <= 6) return PainLevel.moderate;
    return PainLevel.intense;
  }

  int? _painLevelToIntensity(PainLevel level) => switch (level) {
        PainLevel.none => null,
        PainLevel.mild => 3,
        PainLevel.moderate => 6,
        PainLevel.intense => 9,
      };

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final notifier = ref.read(dailyEntryProvider(_today).notifier);
    final intensity = _painLevelToIntensity(_painLevel);
    final notesText = _notesController.text.trim();

    await notifier.save(
      DailyLogEntity(
        date: _today,
        flowIntensity: _selectedFlow,
        spotting: _isSpotting,
        painEnabled: _painLevel != PainLevel.none,
        painIntensity: intensity,
        notesEnabled: notesText.isNotEmpty,
        notes: notesText.isNotEmpty ? notesText : null,
      ),
    );

    if (!mounted) return;
    if (ref.read(dailyEntryProvider(_today)) is AsyncError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.common_error_generic)),
      );
      return;
    }

    if (_symptomsInitialized) {
      try {
        final repo = await ref.read(dailyLogRepositoryProvider.future);
        await repo.replacePainSymptoms(
          _today,
          _selectedSymptoms
              .map((t) => PainSymptomData(symptomType: t))
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.today_save_day)),
    );
  }

  static const List<PainSymptomType> _symptomTypes = [
    PainSymptomType.cramps,
    PainSymptomType.headache,
    PainSymptomType.bloating,
    PainSymptomType.backPain,
    PainSymptomType.migraine,
  ];

  String _symptomLabel(PainSymptomType type, AppLocalizations l10n) =>
      switch (type) {
        PainSymptomType.cramps => l10n.daily_entry_symptom_cramps,
        PainSymptomType.headache => l10n.daily_entry_symptom_headache,
        PainSymptomType.bloating => l10n.daily_entry_symptom_bloating,
        PainSymptomType.backPain => l10n.daily_entry_symptom_backPain,
        PainSymptomType.migraine => l10n.daily_entry_symptom_migraine,
        PainSymptomType.custom => l10n.daily_entry_symptom_custom,
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
    final bgSurface =
        isDark ? MetraColors.dark.bgSurface : MetraColors.light.bgSurface;
    final accentFlow =
        isDark ? MetraColors.dark.accentFlow : MetraColors.light.accentFlow;
    final dividerColor = isDark ? Colors.white12 : Colors.black12;

    final locale = Localizations.localeOf(context).languageCode;
    final rawDate = DateFormat('EEEE d MMMM', locale).format(DateTime.now());
    final dateStr =
        rawDate.substring(0, 1).toUpperCase() + rawDate.substring(1);

    final sectionLabelStyle = MetraTypography.caption.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: 1.2,
      color: textSecondary,
    );

    return Scaffold(
      backgroundColor: bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: MetraSpacing.s6,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: MetraSpacing.s6),
                    Text(
                      dateStr,
                      style: MetraTypography.caption.copyWith(
                        color: textSecondary,
                      ),
                    ),
                    const SizedBox(height: MetraSpacing.s1),
                    Text(
                      l10n.today_how_are_you,
                      style: MetraTypography.displayMd.copyWith(
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: MetraSpacing.s6),

                    // ── Flow ──────────────────────────────────────────────
                    Text(
                      l10n.daily_entry_flow_label.toUpperCase(),
                      style: sectionLabelStyle,
                    ),
                    const SizedBox(height: MetraSpacing.s4),
                    CircleFlowPicker(
                      selectedFlow: _selectedFlow,
                      isSpotting: _isSpotting,
                      onFlowChanged: (f) => setState(() => _selectedFlow = f),
                      onSpottingChanged: (s) => setState(() {
                        _isSpotting = s;
                        if (s) _selectedFlow = null;
                      }),
                    ),
                    const SizedBox(height: MetraSpacing.s6),
                    Divider(color: dividerColor, thickness: 1, height: 1),
                    const SizedBox(height: MetraSpacing.s6),

                    // ── Pain ──────────────────────────────────────────────
                    Text(
                      l10n.today_pain_intensity_label.toUpperCase(),
                      style: sectionLabelStyle,
                    ),
                    const SizedBox(height: MetraSpacing.s4),
                    CirclePainPicker(
                      level: _painLevel,
                      onChanged: (l) => setState(() => _painLevel = l),
                    ),
                    const SizedBox(height: MetraSpacing.s6),
                    Divider(color: dividerColor, thickness: 1, height: 1),
                    const SizedBox(height: MetraSpacing.s6),

                    // ── Symptoms ──────────────────────────────────────────
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
                        _AddSymptomChip(
                          label: l10n.today_add_symptom,
                          textSecondary: textSecondary,
                        ),
                      ],
                    ),
                    const SizedBox(height: MetraSpacing.s6),
                    Divider(color: dividerColor, thickness: 1, height: 1),
                    const SizedBox(height: MetraSpacing.s6),

                    // ── Notes ─────────────────────────────────────────────
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
                          color: textSecondary,
                        ),
                        filled: true,
                        fillColor: bgSurface,
                        contentPadding: const EdgeInsets.all(MetraSpacing.s4),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(MetraRadius.md),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(MetraRadius.md),
                          borderSide: BorderSide.none,
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
                    const SizedBox(height: MetraSpacing.s8),
                  ],
                ),
              ),
            ),

            // ── Save button ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MetraSpacing.s6,
                0,
                MetraSpacing.s6,
                MetraSpacing.s4,
              ),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: accentFlow,
                ),
                onPressed: _save,
                icon: const Icon(Icons.check, size: 20),
                label: Text(l10n.today_save_day),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dashed-border chip for the "+ Aggiungi" action (visual placeholder).
class _AddSymptomChip extends StatelessWidget {
  const _AddSymptomChip({
    required this.label,
    required this.textSecondary,
  });

  final String label;
  final Color textSecondary;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(color: textSecondary),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: MetraSpacing.s4,
          vertical: MetraSpacing.s2,
        ),
        child: Text(
          label,
          style: MetraTypography.body.copyWith(color: textSecondary),
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
