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

// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/metra_colors.dart';
import '../../theme/metra_spacing.dart';
import '../settings/settings_divider.dart';
import '../../../l10n/app_localizations.dart';

/// A stateless bottom-sheet scaffold for Cupertino-style picker modals.
///
/// Renders a toolbar row with two text buttons — [resetLabel] on the left
/// (fires [onReset]) and [confirmLabel] on the right (fires [onConfirm]) —
/// a 1 dp divider, and the picker [child] below.
///
/// Background colour: [MetraColors.bgPrimary] (sabbia / sand).
/// Top corners: [MetraRadius.lg] (16 dp) rounded.
/// Button typography: Inter 16 / w500 / [MetraColors.accentFlow] (terracotta).
///
/// [resetLabel] and [confirmLabel] default to the l10n values
/// `common_restore` ("Ripristina") and `common_ok` ("OK") when omitted.
///
/// [useSafeArea]: when `true`, wraps [child] in a [SafeArea] to avoid
/// home-indicator overlap. Pass `false` (default) for Settings call sites
/// inside a ShellRoute where safe-area is already handled by the shell.
///
/// The private `_CupertinoPickerScaffold` in `settings_screen.dart` retains a
/// different stateful API (debounce + resetKey). Do NOT remove it — that is
/// TASK-12's responsibility.
class CupertinoPickerScaffold extends StatelessWidget {
  const CupertinoPickerScaffold({
    required this.child,
    required this.onReset,
    required this.onConfirm,
    this.resetLabel,
    this.confirmLabel,
    this.useSafeArea = false,
    super.key,
  });

  /// The picker content displayed below the toolbar divider.
  final Widget child;

  /// Called when the user taps the reset (left) toolbar button.
  final VoidCallback onReset;

  /// Called when the user taps the confirm (right) toolbar button.
  final VoidCallback onConfirm;

  /// Label for the reset button. Defaults to [AppLocalizations.common_restore].
  final String? resetLabel;

  /// Label for the confirm button. Defaults to [AppLocalizations.common_ok].
  final String? confirmLabel;

  /// When `true`, wraps [child] in a [SafeArea]. Default `false`.
  final bool useSafeArea;

  @override
  Widget build(BuildContext context) {
    final colors = MetraColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final buttonStyle = GoogleFonts.inter(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: colors.accentFlow,
    );

    final pickerChild = useSafeArea ? SafeArea(child: child) : child;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(MetraRadius.lg),
      ),
      child: ColoredBox(
        color: colors.bgPrimary,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Toolbar row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Semantics(
                  button: true,
                  label: resetLabel ?? l10n.common_restore,
                  child: GestureDetector(
                    onTap: onReset,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: MetraSpacing.s4,
                        vertical: MetraSpacing.sp14,
                      ),
                      child: Text(
                        resetLabel ?? l10n.common_restore,
                        style: buttonStyle,
                      ),
                    ),
                  ),
                ),
                Semantics(
                  button: true,
                  label: confirmLabel ?? l10n.common_ok,
                  child: GestureDetector(
                    onTap: onConfirm,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: MetraSpacing.s4,
                        vertical: MetraSpacing.sp14,
                      ),
                      child: Text(
                        confirmLabel ?? l10n.common_ok,
                        style: buttonStyle,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // 1 dp separator
            const SettingsDivider(),
            // Picker content
            pickerChild,
          ],
        ),
      ),
    );
  }
}

const Duration _kPickerAutoSaveDebounce = Duration(milliseconds: 250);

/// A stateful bottom-sheet scaffold for Cupertino wheel-picker modals with
/// debounced auto-save and resetKey re-seeding.
///
/// Promoted public equivalent of the private `_CupertinoPickerScaffold` in
/// `settings_screen.dart` (migrated by TASK-12).
///
/// [wheelBuilder] receives a [Key] (bumped on Ripristina so the wheel
/// re-seeds) and a `scheduleAutoSave` callback (drives the 250 ms debounce).
/// Toolbar: left = Ripristina (cancel pending debounce, call [onRestore],
/// bump key, modal stays open), right = OK (flush pending debounce if active,
/// then close modal).
class WheelPickerScaffold extends StatefulWidget {
  const WheelPickerScaffold({
    required this.wheelBuilder,
    required this.onAutoSave,
    required this.onRestore,
    super.key,
  });

  final Widget Function(Key resetKey, void Function() scheduleAutoSave)
      wheelBuilder;
  final VoidCallback onAutoSave;
  final VoidCallback onRestore;

  @override
  State<WheelPickerScaffold> createState() => _WheelPickerScaffoldState();
}

class _WheelPickerScaffoldState extends State<WheelPickerScaffold> {
  Key _resetKey = UniqueKey();
  Timer? _debounce;

  void _scheduleAutoSave() {
    _debounce?.cancel();
    _debounce = Timer(_kPickerAutoSaveDebounce, () {
      _debounce = null;
      widget.onAutoSave();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = MetraColors.of(context);

    return CupertinoTheme(
      data: CupertinoThemeData(
        brightness: Theme.of(context).brightness,
        primaryColor: colors.accentFlow,
      ),
      child: Container(
        height: 310,
        color: colors.bgSurface,
        child: Column(
          children: [
            SizedBox(
              height: 44,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Semantics(
                    label: l10n.common_restore,
                    button: true,
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      onPressed: () {
                        _debounce?.cancel();
                        _debounce = null;
                        widget.onRestore();
                        setState(() => _resetKey = UniqueKey());
                      },
                      child: Text(
                        l10n.common_restore,
                        style: TextStyle(
                          color: colors.accentFlow,
                          fontWeight: FontWeight.w600,
                          fontSize: 17,
                        ),
                      ),
                    ),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    onPressed: () {
                      if (_debounce?.isActive == true) {
                        _debounce!.cancel();
                        _debounce = null;
                        widget.onAutoSave();
                      }
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      l10n.common_ok,
                      style: TextStyle(
                        color: colors.accentFlow,
                        fontWeight: FontWeight.w600,
                        fontSize: 17,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: widget.wheelBuilder(_resetKey, _scheduleAutoSave),
            ),
          ],
        ),
      ),
    );
  }
}
