// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
// SPDX-License-Identifier: GPL-3.0-or-later
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
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/metra_colors.dart';
import '../../../core/theme/metra_spacing.dart';
import '../../../core/theme/metra_typography.dart';

/// Métra-styled confirmation dialog.
///
/// Plain [Dialog] with [MetraRadius.xxl] (24 dp) border radius, capped at
/// 310 dp wide (EC-13). Returns `true` / `false` / `null` via [show].
class MetraConfirmDialog extends StatelessWidget {
  const MetraConfirmDialog({
    super.key,
    required this.title,
    this.body,
    this.cancelLabel = 'Annulla',
    this.confirmLabel = 'Conferma',
  });

  final String title;
  final String? body;
  final String cancelLabel;
  final String confirmLabel;

  /// Shows the dialog; returns `true` (confirm), `false` (cancel), or
  /// `null` (barrier dismiss).
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    String? body,
    String? cancelLabel,
    String? confirmLabel,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => MetraConfirmDialog(
        title: title,
        body: body,
        cancelLabel: cancelLabel ?? 'Annulla',
        confirmLabel: confirmLabel ?? 'Conferma',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = MetraColors.of(context);
    return Dialog(
      backgroundColor: palette.bgSurface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MetraRadius.xxl),
      ),
      child: ConstrainedBox(
        key: const Key('metra_confirm_dialog_constrained'),
        constraints: const BoxConstraints(maxWidth: 310),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: MetraTypography.dayDetailTitle.copyWith(
                  color: palette.textPrimary,
                ),
              ),
              if (body != null) ...[
                const SizedBox(height: 12),
                Text(
                  body!,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    height: 1.4,
                    color: palette.textPrimary.withAlpha(0xAD),
                  ),
                ),
              ],
              const SizedBox(height: 28),
              // Wrap reflows gracefully on very narrow screens; in production
              // two short labels always fit on one line.
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 28,
                children: [
                  _DialogAction(
                    label: cancelLabel,
                    color: palette.accentFlow,
                    onTap: () => Navigator.of(context).pop(false),
                  ),
                  _DialogAction(
                    label: confirmLabel,
                    color: palette.accentFlowStrong,
                    onTap: () => Navigator.of(context).pop(true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

/// Action button used inside [MetraConfirmDialog].
///
/// [GestureDetector] with [HitTestBehavior.opaque] wrapping a [Padding] so
/// the full padded area forms the hit target (≥ 44 dp tall).
class _DialogAction extends StatelessWidget {
  const _DialogAction({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          // (44 - fontSize 16) / 2 = 14 dp vertical → effective hit height = 44 dp.
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              height: 1.0,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}
