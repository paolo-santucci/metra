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
// Pure byte-size formatter for backup picker rows.

/// Human-readable size suffix for a backup picker row.
///
/// Returns:
/// - `''`       when [bytes] is 0 (unknown / not-yet-downloaded — caller omits
///              the suffix so the row shows only date+time).
/// - `"N B"`    when [bytes] < 1 024.
/// - `"N KB"`   when [bytes] < 1 048 576 (integer, no decimal).
/// - `"N.D MB"` otherwise (one decimal place).
///
/// KB / MB are unit symbols, not localised strings — no ARB key needed.
String formatBackupSize(int bytes) {
  if (bytes <= 0) return '';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
