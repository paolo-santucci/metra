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
// Unit tests for formatBackupSize — pure Dart, no Flutter needed.

import 'package:flutter_test/flutter_test.dart';
import 'package:metra/features/backup/widgets/backup_size_format.dart';

void main() {
  group('formatBackupSize', () {
    test('returns empty string for 0 (unknown / not-yet-downloaded)', () {
      expect(formatBackupSize(0), '');
    });

    test('returns bytes with B suffix for values under 1 KB', () {
      expect(formatBackupSize(512), '512 B');
    });

    test('returns integer KB for exactly 1 KB', () {
      expect(formatBackupSize(1024), '1 KB');
    });

    test('returns integer KB for 2 KB', () {
      expect(formatBackupSize(2048), '2 KB');
    });

    test('returns integer KB for 3 KB', () {
      expect(formatBackupSize(3072), '3 KB');
    });

    test('returns one-decimal MB for exactly 1 MB', () {
      expect(formatBackupSize(1024 * 1024), '1.0 MB');
    });

    test('returns one-decimal MB for 1.5 MB', () {
      expect(formatBackupSize(1536 * 1024), '1.5 MB');
    });
  });
}
