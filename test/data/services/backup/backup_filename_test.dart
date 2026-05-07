// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:metra/data/services/backup/backup_filename.dart';

void main() {
  group('BackupFilename', () {
    test('parseTimestamp: valid canonical name', () {
      final result = BackupFilename.parseTimestamp(
        'metra_backup_20260429T100000Z.enc',
      );
      expect(result, DateTime.utc(2026, 4, 29, 10, 0, 0));
    });

    test('parseTimestamp: invalid prefix', () {
      final result = BackupFilename.parseTimestamp('invalid_name.txt');
      expect(result, isNull);
    });

    test('parseTimestamp: empty string', () {
      final result = BackupFilename.parseTimestamp('');
      expect(result, isNull);
    });

    test('filenameFor: produces canonical name', () {
      final result = BackupFilename.filenameFor(
        DateTime.utc(2026, 4, 29, 10, 0, 0),
      );
      expect(result, 'metra_backup_20260429T100000Z.enc');
    });

    test('round-trip identity', () {
      final dt = DateTime.utc(2026, 12, 31, 23, 59, 59);
      final result =
          BackupFilename.parseTimestamp(BackupFilename.filenameFor(dt));
      expect(result, dt);
    });
  });
}
