// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
//
// Métra is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Métra is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Métra. If not, see <https://www.gnu.org/licenses/>.

// These tests exercise SQLCipher on a real file-based database. They require a
// physical Android or iOS device and are therefore skipped on the Linux CI
// host (enforced by the @TestOn annotation below).
@TestOn('android || ios')
library;

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SQLCipher integration (device only)', () {
    test('same key reopens successfully', () {
      // TODO: open file DB with key A, insert row, close, reopen with key A → reads row
      // Skipped on Linux CI — must run on physical Android device.
    });

    test('wrong key fails to open', () {
      // TODO: open file DB with key A, close, reopen with key B → exception
    });

    test('no key fails to open', () {
      // TODO: open file DB with key A, close, reopen without key → exception
    });
  });
}
