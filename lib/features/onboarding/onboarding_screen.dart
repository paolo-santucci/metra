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
import '../../core/theme/metra_typography.dart';
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

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: MetraSpacing.s6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(flex: 3),
            Semantics(
              header: true,
              child: Text(
                MetraTypography.wordmark,
                style: MetraTypography.displayLg.copyWith(color: accentFlow),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: MetraSpacing.s4),
            Text(
              l10n.onboarding_tagline,
              style: MetraTypography.titleMd.copyWith(color: textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: MetraSpacing.s4),
            Text(
              l10n.onboarding_privacy_line,
              style: MetraTypography.body.copyWith(color: textSecondary),
              textAlign: TextAlign.center,
            ),
            const Spacer(flex: 3),
            FilledButton(
              onPressed: onGetStarted,
              child: Text(l10n.onboarding_get_started),
            ),
            const SizedBox(height: MetraSpacing.s8),
          ],
        ),
      ),
    );
  }
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
    final state = ref.watch(onboardingNotifierProvider);
    final notifier = ref.read(onboardingNotifierProvider.notifier);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: MetraSpacing.s6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: MetraSpacing.s12),
            Text(
              l10n.onboarding_last_period_question,
              style: MetraTypography.titleMd.copyWith(color: textPrimary),
            ),
            const SizedBox(height: MetraSpacing.s4),
            _DatePickerField(
              selectedDate: state.lastPeriodDate,
              onDateSelected: notifier.setDate,
            ),
            const SizedBox(height: MetraSpacing.s8),
            Text(
              l10n.onboarding_cycle_length_question,
              style: MetraTypography.titleMd.copyWith(color: textPrimary),
            ),
            const SizedBox(height: MetraSpacing.s4),
            _CycleLengthStepper(
              value: state.cycleLength,
              l10n: l10n,
              onIncrement: notifier.incrementCycleLength,
              onDecrement: notifier.decrementCycleLength,
            ),
            const Spacer(),
            FilledButton(
              onPressed: state.canSubmit
                  ? () => _onSubmit(context, ref, state)
                  : null,
              child: Text(l10n.onboarding_start),
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
  });

  final DateTime? selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final displayText = selectedDate != null
        ? '${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}'
        : 'Select date';

    return Semantics(
      label: 'Last period start date, ${selectedDate != null ? displayText : 'not selected'}',
      button: true,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          alignment: Alignment.centerLeft,
        ),
        icon: const Icon(Icons.calendar_today_outlined, size: 20),
        label: Text(displayText),
        onPressed: () => _pickDate(context),
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 182)),
      lastDate: now,
      initialDate: selectedDate ?? now.subtract(const Duration(days: 28)),
    );
    if (picked != null) {
      onDateSelected(DateTime.utc(picked.year, picked.month, picked.day));
    }
  }
}

// ── Cycle length stepper ──────────────────────────────────────────────────────

class _CycleLengthStepper extends StatelessWidget {
  const _CycleLengthStepper({
    required this.value,
    required this.l10n,
    required this.onIncrement,
    required this.onDecrement,
  });

  final int value;
  final AppLocalizations l10n;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 48,
          height: 48,
          child: IconButton(
            tooltip: 'Decrease cycle length',
            icon: const Icon(Icons.remove),
            onPressed: onDecrement,
          ),
        ),
        const SizedBox(width: MetraSpacing.s4),
        Semantics(
          label: '$value ${l10n.onboarding_days_unit}',
          child: Text(
            value.toString(),
            style: MetraTypography.titleMd,
          ),
        ),
        const SizedBox(width: MetraSpacing.s4),
        SizedBox(
          width: 48,
          height: 48,
          child: IconButton(
            tooltip: 'Increase cycle length',
            icon: const Icon(Icons.add),
            onPressed: onIncrement,
          ),
        ),
      ],
    );
  }
}
