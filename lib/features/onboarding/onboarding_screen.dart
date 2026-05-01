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
import '../../core/widgets/metra_wordmark.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/use_case_providers.dart';
import 'state/onboarding_notifier.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goToDataPage() {
    _controller.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _controller,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _WelcomePage(onGetStarted: _goToDataPage),
          const _DataPage(),
        ],
      ),
    );
  }
}

// ── Page 1: Welcome ──────────────────────────────────────────────────────────

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({required this.onGetStarted});

  final VoidCallback onGetStarted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentFlow =
        isDark ? MetraColors.dark.accentFlow : MetraColors.light.accentFlow;
    final textPrimary =
        isDark ? MetraColors.dark.textPrimary : MetraColors.light.textPrimary;
    final textSecondary = isDark
        ? MetraColors.dark.textSecondary
        : MetraColors.light.textSecondary;
    final bgPrimary =
        isDark ? MetraColors.dark.bgPrimary : MetraColors.light.bgPrimary;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hero zone: wordmark + terracotta radial halos (spec § 12.1).
          // Fixed at 340dp per DESIGN-BIBLE § 12.1 flex 0 0 340.
          SizedBox(
            height: 340,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Outer elliptical glow: rgba(200,116,86,0.05) → transparent 80%
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.4),
                      radius: 0.85,
                      colors: [
                        accentFlow.withValues(alpha: 0.05),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.80],
                    ),
                  ),
                ),
                // Centered halo 220×220: rgba(200,116,86,0.12) → transparent 70%
                Center(
                  child: SizedBox(
                    width: 220,
                    height: 220,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            accentFlow.withValues(alpha: 0.12),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.70],
                        ),
                      ),
                    ),
                  ),
                ),
                // Wordmark
                Center(
                  child: Semantics(
                    header: true,
                    child: MetraWordmark(color: textPrimary),
                  ),
                ),
              ],
            ),
          ),
          // Content zone: text scrolls; CTA is pinned at bottom.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(36, 0, 36, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Manifesto headline: DM Serif Display 34 / lh 1.2 per § 12.1.
                        Text(
                          l10n.onboarding_tagline,
                          style: MetraTypography.headlineLg
                              .copyWith(color: textPrimary),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          l10n.onboarding_privacy_line,
                          style: MetraTypography.body.copyWith(
                            color: textSecondary,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 40),
                        Center(child: _MacronDots(color: accentFlow)),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(36, 0, 36, 28),
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: textPrimary,
                      foregroundColor: bgPrimary,
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: onGetStarted,
                    child: Text(l10n.onboarding_get_started),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MacronDots extends StatelessWidget {
  const _MacronDots({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(48, 22),
      painter: _MacronDotsPainter(color: color),
    );
  }
}

class _MacronDotsPainter extends CustomPainter {
  const _MacronDotsPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(6, 4), const Offset(42, 4), linePaint);
    canvas.drawCircle(
      const Offset(12, 16),
      3,
      Paint()..color = color.withValues(alpha: 0.4),
    );
    canvas.drawCircle(
      const Offset(24, 16),
      3,
      Paint()..color = color.withValues(alpha: 0.65),
    );
    canvas.drawCircle(
      const Offset(36, 16),
      3,
      Paint()..color = color.withValues(alpha: 0.4),
    );
  }

  @override
  bool shouldRepaint(_MacronDotsPainter old) => old.color != color;
}

// ── Page 2: Data entry ────────────────────────────────────────────────────────

class _DataPage extends ConsumerWidget {
  const _DataPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? MetraColors.dark.textPrimary : MetraColors.light.textPrimary;
    final textSecondary = isDark
        ? MetraColors.dark.textSecondary
        : MetraColors.light.textSecondary;
    final accentFlow =
        isDark ? MetraColors.dark.accentFlow : MetraColors.light.accentFlow;
    final bgPrimary =
        isDark ? MetraColors.dark.bgPrimary : MetraColors.light.bgPrimary;
    final state = ref.watch(onboardingNotifierProvider);
    final notifier = ref.read(onboardingNotifierProvider.notifier);
    final locale = Localizations.localeOf(context).toString();

    final microLabelStyle = MetraTypography.caption.copyWith(
      color: textPrimary.withValues(alpha: 0.40),
      fontWeight: FontWeight.w600,
      letterSpacing: 0.06 * 12,
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            _StepProgressBar(
              current: 2,
              total: 2,
              label: l10n.onboarding_step_label(2, 2),
              accentColor: accentFlow,
              textColor: textSecondary,
            ),
            const SizedBox(height: 24),
            // "Il tuo primo ciclo" headline: DM Serif Display 28 / lh 1.25 per § 12.1.
            Text(
              l10n.onboarding_headline,
              style: MetraTypography.headlineSm.copyWith(color: textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.onboarding_subhead,
              style: MetraTypography.caption.copyWith(
                color: textPrimary.withValues(alpha: 0.68),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),

            // Field 1 — last period date
            Text(
              l10n.onboarding_last_period_question.toUpperCase(),
              style: microLabelStyle,
            ),
            const SizedBox(height: 10),
            _DatePickerField(
              selectedDate: state.lastPeriodDate,
              onDateSelected: notifier.setDate,
              locale: locale,
              l10n: l10n,
            ),
            const SizedBox(height: 24),

            // Field 2 — cycle length
            Text(
              l10n.onboarding_cycle_length_label.toUpperCase(),
              style: microLabelStyle,
            ),
            const SizedBox(height: 10),
            _CycleLengthStepper(
              value: state.cycleLength,
              l10n: l10n,
              onIncrement: notifier.incrementCycleLength,
              onDecrement: notifier.decrementCycleLength,
              accentFlow: accentFlow,
              textPrimary: textPrimary,
            ),
            const SizedBox(height: 24),

            // Field 3 — period duration
            Text(
              l10n.onboarding_period_duration_label.toUpperCase(),
              style: microLabelStyle,
            ),
            const SizedBox(height: 10),
            _PeriodDurationPicker(
              selected: state.periodLength,
              onChanged: notifier.setPeriodLength,
            ),
            const Spacer(),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: textPrimary,
                foregroundColor: bgPrimary,
                disabledBackgroundColor: textPrimary.withValues(alpha: 0.35),
                disabledForegroundColor: bgPrimary.withValues(alpha: 0.60),
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed:
                  state.canSubmit ? () => _onSubmit(context, ref, state) : null,
              child: Text(l10n.onboarding_all_set),
            ),
            const SizedBox(height: MetraSpacing.s8),
          ],
        ),
      ),
    );
  }

  Future<void> _onSubmit(
    BuildContext context,
    WidgetRef ref,
    OnboardingState state,
  ) async {
    final uc = await ref.read(completeOnboardingProvider.future);
    await uc.execute(
      lastPeriodDate: state.lastPeriodDate!,
      cycleLength: state.cycleLength,
      periodLength: state.periodLength,
    );
    if (context.mounted) {
      context.go('/calendar');
    }
  }
}

// ── Date picker field ─────────────────────────────────────────────────────────

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.selectedDate,
    required this.onDateSelected,
    required this.locale,
    required this.l10n,
  });

  final DateTime? selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final String locale;
  final AppLocalizations l10n;

  String _formatDate(DateTime date) {
    return intl.DateFormat('d MMMM yyyy', locale).format(date);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? MetraColors.dark.textPrimary : MetraColors.light.textPrimary;
    final bgSurface =
        isDark ? MetraColors.dark.bgSurface : MetraColors.light.bgSurface;

    final displayText = selectedDate != null
        ? _formatDate(selectedDate!)
        : l10n.onboarding_date_placeholder;
    final hasDate = selectedDate != null;

    return Semantics(
      label: 'Primo giorno ultima mestruazione, ${hasDate ? displayText : 'non selezionato'}',
      button: true,
      child: GestureDetector(
        onTap: () => _pickDate(context),
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: bgSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: textPrimary.withValues(alpha: 0.14),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  displayText,
                  style: MetraTypography.body.copyWith(
                    color: hasDate
                        ? textPrimary
                        : textPrimary.withValues(alpha: 0.40),
                  ),
                ),
              ),
              Icon(
                Icons.calendar_today_outlined,
                size: 18,
                color: textPrimary.withValues(alpha: 0.40),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: now,
      initialDate: selectedDate ?? now.subtract(const Duration(days: 28)),
    );
    if (picked != null) {
      onDateSelected(DateTime.utc(picked.year, picked.month, picked.day));
    }
  }
}

// ── Period duration picker ────────────────────────────────────────────────────

class _PeriodDurationPicker extends StatelessWidget {
  const _PeriodDurationPicker({
    required this.selected,
    required this.onChanged,
  });

  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentFlow =
        isDark ? MetraColors.dark.accentFlow : MetraColors.light.accentFlow;
    final textPrimary =
        isDark ? MetraColors.dark.textPrimary : MetraColors.light.textPrimary;
    // Active text: sabbia (sand) per DESIGN-BIBLE § 5.2.
    // Idle background: ink @ 0.07 per DESIGN-BIBLE § 5.2.
    final sand = isDark ? MetraColors.dark.textOnAccent : MetraColors.light.sand;
    final idleBg = textPrimary.withAlpha(0x12);

    return Row(
      children: List.generate(8, (i) {
        final day = i + 1;
        final isSelected = selected == day;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(day),
            child: Container(
              height: 44,
              // Gap between cells: 8px per DESIGN-BIBLE § 5.2.
              margin: EdgeInsets.only(right: i < 7 ? 8 : 0),
              decoration: BoxDecoration(
                color: isSelected ? accentFlow : idleBg,
                borderRadius: BorderRadius.circular(MetraRadius.smm),
              ),
              alignment: Alignment.center,
              child: Text(
                '$day',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? sand : textPrimary,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ── Step progress bar ─────────────────────────────────────────────────────────

class _StepProgressBar extends StatelessWidget {
  const _StepProgressBar({
    required this.current,
    required this.total,
    required this.label,
    required this.accentColor,
    required this.textColor,
  });

  final int current;
  final int total;
  final String label;
  final Color accentColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: List.generate(total, (i) {
            return Expanded(
              child: Container(
                height: 3,
                margin: EdgeInsets.only(right: i < total - 1 ? 4 : 0),
                decoration: BoxDecoration(
                  color: i < current ? accentColor : accentColor.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: MetraTypography.caption.copyWith(color: textColor),
        ),
      ],
    );
  }
}

// ── Cycle length stepper ──────────────────────────────────────────────────────

class _CycleLengthStepper extends StatelessWidget {
  const _CycleLengthStepper({
    required this.value,
    required this.l10n,
    required this.onIncrement,
    required this.onDecrement,
    required this.accentFlow,
    required this.textPrimary,
  });

  final int value;
  final AppLocalizations l10n;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final Color accentFlow;
  final Color textPrimary;

  static const int _min = 21;
  static const int _max = 45;

  @override
  Widget build(BuildContext context) {
    final trackFraction = ((value - _min) / (_max - _min)).clamp(0.0, 1.0);
    final labelStyle11 = GoogleFonts.inter(
      fontSize: 11,
      color: textPrimary.withValues(alpha: 0.35),
    );

    return Column(
      children: [
        // Number + controls row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Decrement button: 40×40 touch area, radius 10, ink @ 0.07 fill.
            Semantics(
              button: true,
              label: 'Diminuisci durata ciclo',
              child: GestureDetector(
                onTap: value > _min ? onDecrement : null,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: textPrimary.withAlpha(
                      value > _min ? 0x12 : 0x08,
                    ),
                    borderRadius: BorderRadius.circular(MetraRadius.smm),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '−',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w300,
                      color: textPrimary.withValues(
                        alpha: value > _min ? 1.0 : 0.35,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: MetraSpacing.s4),
            Semantics(
              label: '$value ${l10n.onboarding_days_unit}',
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value.toString(),
                    style: MetraTypography.stepper.copyWith(color: textPrimary),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l10n.onboarding_days_unit,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: textPrimary.withValues(alpha: 0.68),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: MetraSpacing.s4),
            // Increment button: 40×40 touch area, radius 10, ink @ 0.07 fill.
            Semantics(
              button: true,
              label: 'Aumenta durata ciclo',
              child: GestureDetector(
                onTap: value < _max ? onIncrement : null,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: textPrimary.withAlpha(
                      value < _max ? 0x12 : 0x08,
                    ),
                    borderRadius: BorderRadius.circular(MetraRadius.smm),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '+',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w300,
                      color: textPrimary.withValues(
                        alpha: value < _max ? 1.0 : 0.35,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Range track
        LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              children: [
                Stack(
                  children: [
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: textPrimary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: trackFraction,
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: accentFlow,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('$_min', style: labelStyle11),
                    Text('$_max', style: labelStyle11),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
