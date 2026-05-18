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

import 'package:metra/providers/permission_blocked_dialog_provider.dart';

/// Test double for [PermissionBlockedDialog].
///
/// Records how many times [show] was called via [showCount]. Use [reset]
/// to zero the counter between steps in a multi-step test scenario.
///
/// Set [showCount] assertions to 0 on the [PermissionDenied] path and 1
/// on the [PermissionBlocked] path to distinguish the two outcomes.
class FakePermissionBlockedDialog implements PermissionBlockedDialog {
  /// Number of times [show] has been called.
  int showCount = 0;

  @override
  Future<void> show() async {
    showCount++;
  }

  /// Resets [showCount] to zero.
  ///
  /// Call between successive steps in a multi-step test (e.g. FR-25 dual
  /// toggle-on scenario) so each assertion is independent.
  void reset() {
    showCount = 0;
  }
}
