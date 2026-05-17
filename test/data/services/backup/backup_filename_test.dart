// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:metra/data/services/backup/backup_filename.dart';

void main() {
  group('BackupFilename', () {
    // --- Legacy parse tests (FR-15a) ---

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

    // --- Generation tests (FR-15) ---

    test('filenameFor: produces suffixed canonical name', () {
      // After TASK-12 every generated filename carries a 6-char [a-z0-9] suffix.
      final result = BackupFilename.filenameFor(
        DateTime.utc(2026, 4, 29, 10, 0, 0),
      );
      expect(
        result,
        matches(r'^metra_backup_20260429T100000Z_[a-z0-9]{6}\.enc$'),
      );
    });

    test('round-trip identity', () {
      final dt = DateTime.utc(2026, 12, 31, 23, 59, 59);
      // parseTimestamp strips the suffix and returns the timestamp component.
      final result =
          BackupFilename.parseTimestamp(BackupFilename.filenameFor(dt));
      expect(result, dt);
    });

    test('filenameFor accepts optional randomSuffix param', () {
      // Compile-time check: method must be callable with the named arg.
      // Deterministic injection behaviour verified in HC-7 test below.
      final t = DateTime.utc(2026, 5, 17, 12, 0, 0);
      final fn = BackupFilename.filenameFor(t, randomSuffix: 'aaaaaa');
      expect(fn, isA<String>());
    });

    // --- FR-15 / HC-7 / NFR-11 / FR-15a tests (TASK-12) ---

    test('FR-15 — same-UTC-second filenames differ', () {
      final t = DateTime.utc(2026, 5, 17, 12, 0, 0);
      final a = BackupFilename.filenameFor(t);
      final b = BackupFilename.filenameFor(t);
      expect(a, isNot(equals(b)));
      expect(a, matches(r'^metra_backup_20260517T120000Z_[a-z0-9]{6}\.enc$'));
      expect(b, matches(r'^metra_backup_20260517T120000Z_[a-z0-9]{6}\.enc$'));
    });

    test('HC-7 — deterministic injection: randomSuffix = "aaaaaa"', () {
      final fn = BackupFilename.filenameFor(
        DateTime.utc(2026, 5, 17, 12, 0, 0),
        randomSuffix: 'aaaaaa',
      );
      expect(fn, equals('metra_backup_20260517T120000Z_aaaaaa.enc'));
    });

    test('NFR-11 entropy proxy — N=100 distinct length-6 [a-z0-9] suffixes',
        () {
      final suffixes = <String>{};
      for (var i = 0; i < 100; i++) {
        final fn = BackupFilename.filenameFor(
          DateTime.utc(2026, 5, 17, 12, 0, i % 60),
        );
        final m = RegExp(r'_([a-z0-9]{6})\.enc$').firstMatch(fn);
        expect(m, isNotNull);
        suffixes.add(m!.group(1)!);
      }
      expect(suffixes.length, equals(100));
    });

    test('FR-15a — legacy form parses', () {
      expect(
        BackupFilename.parseTimestamp('metra_backup_20260517T120000Z.enc'),
        equals(DateTime.utc(2026, 5, 17, 12, 0, 0)),
      );
    });

    test('FR-15a — suffixed form parses', () {
      expect(
        BackupFilename.parseTimestamp(
          'metra_backup_20260517T120000Z_abc123.enc',
        ),
        equals(DateTime.utc(2026, 5, 17, 12, 0, 0)),
      );
    });

    test('FR-15a — invalid forms return null without throwing', () {
      expect(BackupFilename.parseTimestamp('not_a_backup.txt'), isNull);
      expect(BackupFilename.parseTimestamp(''), isNull);
      // Uppercase suffix must be rejected (alphabet is [a-z0-9] only).
      expect(
        BackupFilename.parseTimestamp(
          'metra_backup_20260517T120000Z_ABC123.enc',
        ),
        isNull,
      );
    });
  });
}
