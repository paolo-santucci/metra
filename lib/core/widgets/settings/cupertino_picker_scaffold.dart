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
/// an optional non-tappable [title] in the center slot, a 1 dp divider,
/// and the picker [child] below.
///
/// Background colour: [MetraColors.bgPrimary] (sabbia / sand).
/// Top corners: [MetraRadius.lg] (16 dp) rounded.
/// Button typography: Inter 17 / w600 / [MetraColors.accentFlow] (terracotta).
///
/// [resetLabel] and [confirmLabel] default to the l10n values
/// `common_restore` ("Ripristina") and `common_ok` ("OK") when omitted.
///
/// [title]: optional center label (Inter 17 / w600 / textPrimary per §18.10.2).
/// When `null` (default) the center slot is empty — existing callers are
/// visually unchanged.
///
/// [confirmKey]: optional widget key applied to the confirm [Semantics] node.
/// Used by `BackupProviderPickerSheet` to assert `find.byKey(confirm)` in
/// tests (FR-17). Defaults to `null`.
///
/// [useSafeArea]: when `true`, wraps [child] in a [SafeArea] to avoid
/// home-indicator overlap. Pass `false` (default) for Settings call sites
/// inside a ShellRoute where safe-area is already handled by the shell.
///
/// [WheelPickerScaffold] adds debounced settings saves and reset support.
class CupertinoPickerScaffold extends StatelessWidget {
  const CupertinoPickerScaffold({
    required this.child,
    required this.onReset,
    required this.onConfirm,
    this.resetLabel,
    this.confirmLabel,
    this.title,
    this.confirmKey,
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

  /// Optional non-tappable center title rendered between the two toolbar
  /// buttons. Style: Inter 17 / w600 / textPrimary (§18.10.2 CG-2).
  /// Pass `null` (default) to leave the center slot empty — existing callers
  /// are visually unchanged.
  final String? title;

  /// Optional widget key applied to the confirm [Semantics] node.
  /// Used by pickers that need `find.byKey(...)` access to the confirm button
  /// in widget tests (FR-17). Defaults to `null`.
  final Key? confirmKey;

  /// When `true`, wraps [child] in a [SafeArea]. Default `false`.
  final bool useSafeArea;

  @override
  Widget build(BuildContext context) {
    final colors = MetraColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final buttonStyle = GoogleFonts.inter(
      fontSize: 17,
      fontWeight: FontWeight.w600,
      color: colors.accentFlow,
    ).copyWith(inherit: false, decoration: TextDecoration.none);

    final pickerStyle = GoogleFonts.inter(
      fontSize: 21,
      fontWeight: FontWeight.w400,
      color: colors.textPrimary,
    );
    final themedChild = CupertinoTheme(
      data: CupertinoThemeData(
        brightness: Theme.of(context).brightness,
        primaryColor: colors.accentFlow,
        textTheme: CupertinoTextThemeData(
          pickerTextStyle: pickerStyle,
          dateTimePickerTextStyle: pickerStyle,
        ),
      ),
      child: child,
    );
    final pickerChild =
        useSafeArea ? SafeArea(top: false, child: themedChild) : themedChild;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(MetraRadius.lg),
      ),
      child: ColoredBox(
        color: colors.bgPrimary,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height -
                MediaQuery.paddingOf(context).top,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, constraints) => SizedBox(
                  height: MediaQuery.textScalerOf(context).scale(24) +
                      MetraSpacing.sp14 * 2,
                  child: NavigationToolbar(
                    centerMiddle: true,
                    leading: ConstrainedBox(
                      constraints:
                          BoxConstraints(maxWidth: constraints.maxWidth / 2),
                      child: _toolbarAction(
                        resetLabel ?? l10n.common_restore,
                        onReset,
                        buttonStyle,
                      ),
                    ),
                    middle: title == null
                        ? null
                        : Text(
                            title!,
                            style:
                                buttonStyle.copyWith(color: colors.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                    trailing: ConstrainedBox(
                      constraints:
                          BoxConstraints(maxWidth: constraints.maxWidth / 2),
                      child: _toolbarAction(
                        confirmLabel ?? l10n.common_ok,
                        onConfirm,
                        buttonStyle,
                        key: confirmKey,
                      ),
                    ),
                  ),
                ),
              ),
              // 1 dp separator
              const SettingsDivider(),
              // Picker content
              Flexible(child: pickerChild),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolbarAction(
    String label,
    VoidCallback onTap,
    TextStyle style, {
    Key? key,
  }) {
    return Semantics(
      key: key,
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MetraSpacing.s4,
            vertical: MetraSpacing.sp14,
          ),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Text(
              label,
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
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
    return CupertinoPickerScaffold(
      resetLabel: l10n.common_restore,
      confirmLabel: l10n.common_ok,
      useSafeArea: true,
      onReset: _restore,
      onConfirm: _confirm,
      child: widget.wheelBuilder(_resetKey, _scheduleAutoSave),
    );
  }

  void _restore() {
    _debounce?.cancel();
    _debounce = null;
    widget.onRestore();
    setState(() => _resetKey = UniqueKey());
  }

  void _confirm() {
    if (_debounce?.isActive == true) {
      _debounce!.cancel();
      _debounce = null;
      widget.onAutoSave();
    }
    Navigator.of(context).pop();
  }
}
