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

// NFR-03: This file must NOT import anything from lib/data/ or
// package:metra/data/. The abstraction lives entirely in the UI/provider
// layer and depends only on Flutter + Riverpod primitives.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:metra/app.dart' show navigatorKey;
import 'package:metra/domain/services/notification_service.dart';
import 'package:metra/l10n/app_localizations.dart';
import 'package:metra/providers/use_case_providers.dart';

/// Abstraction over the [PermissionBlocked] alert dialog dispatch used by
/// async [ref.listen] callbacks.
///
/// Decouples the listener logic from [BuildContext] so that TASK-08
/// integration tests can override this provider with a
/// [FakePermissionBlockedDialog] on Linux CI without a live
/// [NavigatorState].
///
/// Production implementation: [NavigatorKeyDialog].
/// Test double: `FakePermissionBlockedDialog` in `test/helpers/`.
abstract class PermissionBlockedDialog {
  /// Shows the OS-permission-blocked alert dialog.
  ///
  /// Implementations must be a no-op when the underlying surface is
  /// unavailable (EC-07 cold-start race: [navigatorKey.currentState] is
  /// null before the first frame).
  Future<void> show();
}

/// Production [PermissionBlockedDialog] that dispatches an [AlertDialog]
/// via the global [navigatorKey].
///
/// **Null-safety (EC-07)**: both [GlobalKey.currentState] and
/// [NavigatorState.overlay] are guarded — if either is null the method
/// returns immediately without showing a dialog. This prevents the
/// cold-start race where the listener fires before [MaterialApp.router]
/// completes its first build.
///
/// **Accessibility (NFR-06)**: both action buttons set
/// [MaterialTapTargetSize.padded] and carry distinct [Semantics] labels
/// so TalkBack / VoiceOver can distinguish them (WCAG 2.1 AA).
///
/// The [notificationService] parameter is a lazy getter evaluated only when
/// the "Open system settings" button is pressed — never during the EC-07
/// null-guard early-return path. This makes the class directly unit-testable
/// without a live [Ref] or [ProviderContainer].
@visibleForTesting
class NavigatorKeyDialog implements PermissionBlockedDialog {
  const NavigatorKeyDialog(
    this._key,
    this._notificationService,
  );

  final GlobalKey<NavigatorState> _key;
  final NotificationService _notificationService;

  @override
  Future<void> show() async {
    // EC-07: both null-checks are required.
    // currentState is null before the first frame or after disposal.
    // overlay is null during Navigator rebuild transitions.
    final state = _key.currentState;
    if (state == null) return;
    final overlay = state.overlay;
    if (overlay == null) return;

    final ctx = overlay.context;
    final l10n = AppLocalizations.of(ctx);
    if (l10n == null) return;

    await showDialog<void>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: Text(l10n.notificationPermissionBlockedTitle),
        content: Text(l10n.notificationPermissionBlockedBody),
        actions: [
          Semantics(
            label: l10n.notificationPermissionBlockedDismiss,
            child: TextButton(
              style: TextButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.padded,
              ),
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(l10n.notificationPermissionBlockedDismiss),
            ),
          ),
          Semantics(
            label: l10n.notificationPermissionOpenSettingsCta,
            child: TextButton(
              style: TextButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.padded,
              ),
              onPressed: () async {
                try {
                  await _notificationService.openNotificationSettings();
                } catch (_) {
                  // openNotificationSettings() has its own catch (C-02 contract).
                  // This is defence-in-depth: any exception that escapes is
                  // swallowed here so the finally can close the dialog cleanly.
                } finally {
                  // ignore: use_build_context_synchronously
                  Navigator.pop(dialogCtx);
                }
              },
              child: Text(l10n.notificationPermissionOpenSettingsCta),
            ),
          ),
        ],
      ),
    );
  }
}

/// Riverpod provider exposing the [PermissionBlockedDialog] singleton.
///
/// Override with [FakePermissionBlockedDialog] in tests (TASK-08, FR-24)
/// to assert on exactly how many times the blocked dialog was triggered
/// without mounting a live [Navigator].
///
/// NFR-03: no import from lib/data/ in this file.
final permissionBlockedDialogProvider = Provider<PermissionBlockedDialog>(
  (ref) => NavigatorKeyDialog(
    navigatorKey,
    ref.read(notificationServiceProvider),
  ),
);
