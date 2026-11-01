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
//
// TASK-06 (M4) — BackupProviderPickerSheet
//
// A modal bottom sheet hosting a CupertinoPicker for selecting a backup
// provider. Returns a SyncProvider on confirm or null on cancel / barrier
// dismiss. Distinct from BackupPickerSheet (which returns int? for file index).
//
// Public API:
//   BackupProviderPickerSheet({required providers, initialIndex=0})
//   BackupProviderPickerSheet.show(context, {required providers, initialIndex=0})
//     → Future<SyncProvider?>  (provider on Connetti, null on Annulla / dismiss)
//
// Contracts:
//   • FR-04 / FR-05: CupertinoPicker wheel on both platforms, caller-supplied
//     list — no internal defaultTargetPlatform check.
//   • FR-06 / EC-11: confirm always enabled (list always ≥ 2 per EC-11);
//     no EmptySheet / disabled-confirm branch.
//   • FR-17 / NFR-05: stable Key("sheetRoot"), Key("row_i"), Key("confirm");
//     Semantics(button:true, label) on each row and the confirm button.
//   • §18.8 / §19.1 / §18.10.2 (CG-1 / CG-2): reuses CupertinoPickerScaffold
//     unchanged for radius (16 dp); adds optional center-title slot (CG-2);
//     itemExtent MetraSpacing.sp44; useMagnifier:false; looping:false;
//     selectionOverlay:SizedBox.shrink(); ink-6% band; useSafeArea:true;
//     transparent sheet bg; barrierColor = textPrimary @ 0x40.

import 'package:flutter/material.dart';

import '../../../core/theme/metra_colors.dart';
import '../../../core/widgets/settings/cupertino_picker_scaffold.dart';
import '../../../core/widgets/settings/metra_picker_wheel.dart';
import '../../../domain/entities/sync_log_entity.dart';
import '../../../l10n/app_localizations.dart';
import 'backup_provider_labels.dart';
import 'picker_item.dart';

/// Modal bottom sheet for selecting a [SyncProvider] from [providers].
///
/// The caller is responsible for passing a platform-filtered list (via
/// `availableProviders(defaultTargetPlatform)`) — this widget does NOT call
/// `availableProviders` and contains no `defaultTargetPlatform` check (FR-05).
class BackupProviderPickerSheet extends StatefulWidget {
  BackupProviderPickerSheet({
    required this.providers,
    this.initialIndex = 0,
    super.key,
  }) : assert(providers.isNotEmpty, 'providers must be non-empty');

  /// Platform-filtered provider list supplied by the caller.
  /// Always ≥ 2 on every supported platform (EC-11).
  final List<SyncProvider> providers;

  /// Index of the initially-selected provider. Defaults to 0.
  final int initialIndex;

  /// Presents this sheet and returns the selected [SyncProvider], or `null` on
  /// cancel / barrier dismiss.
  ///
  /// [providers] must be non-empty (assert). Pass the result of
  /// `availableProviders(defaultTargetPlatform)`.
  ///
  /// The sheet root carries [Key("sheetRoot")] for widget-test access (FR-17).
  static Future<SyncProvider?> show(
    BuildContext context, {
    required List<SyncProvider> providers,
    int initialIndex = 0,
  }) {
    assert(providers.isNotEmpty, 'providers must be non-empty');
    final colors = MetraColors.of(context);
    return showModalBottomSheet<SyncProvider?>(
      context: context,
      isScrollControlled: true,
      // Transparent so CupertinoPickerScaffold's ClipRRect is the visual
      // boundary (avoids double-rounding artefact).
      backgroundColor: Colors.transparent,
      barrierColor: colors.textPrimary.withAlpha(0x40), // ink-at-25%
      builder: (_) => BackupProviderPickerSheet(
        providers: providers,
        initialIndex: initialIndex,
        key: const Key('sheetRoot'),
      ),
    );
  }

  @override
  State<BackupProviderPickerSheet> createState() =>
      _BackupProviderPickerSheetState();
}

class _BackupProviderPickerSheetState extends State<BackupProviderPickerSheet> {
  late int _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialIndex;
  }

  void _cancel() => Navigator.of(context).pop(null);

  void _confirm() => Navigator.of(context).pop(widget.providers[_selected]);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return CupertinoPickerScaffold(
      resetLabel: l10n.commonCancel,
      confirmLabel: l10n.backupConnectAction,
      // CG-2: optional center-title slot — shows backupProviderPickerTitle
      // between Annulla (left) and Connetti (right).
      title: l10n.backupProviderPickerTitle,
      onReset: _cancel,
      onConfirm: _confirm,
      // FR-17: stable Key on the confirm button for widget-test access.
      confirmKey: const Key('confirm'),
      useSafeArea: true,
      child: MetraPickerWheel(
        initialItem: widget.initialIndex,
        onSelectedItemChanged: (i) => setState(() => _selected = i),
        children: List.generate(
          widget.providers.length,
          (i) {
            final displayName = backupProviderDisplayName(
              l10n,
              widget.providers[i],
            );
            return Semantics(
              // FR-17: stable Key("row_i") on each provider row.
              // ExcludeSemantics on the visual child prevents Flutter
              // from merging the child Text's content with the explicit
              // label (which would produce "Dropbox\nDropbox").
              key: Key('row_$i'),
              button: true,
              label: displayName,
              child: ExcludeSemantics(
                child: PickerItem(
                  text: displayName,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
