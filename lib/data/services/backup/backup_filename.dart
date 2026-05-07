// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
// SPDX-License-Identifier: GPL-3.0-or-later

/// Utility class for converting between backup filenames and UTC timestamps.
///
/// Canonical format: `metra_backup_YYYYMMDDTHHMMSSz.enc`
class BackupFilename {
  BackupFilename._();

  static const _prefix = 'metra_backup_';
  static const _suffix = '.enc';

  static final _pattern = RegExp(
    r'^metra_backup_(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})Z\.enc$',
  );

  /// Returns the canonical filename for a backup taken at [t].
  ///
  /// The datetime is always converted to UTC before formatting.
  static String filenameFor(DateTime t) {
    final dt = t.toUtc();
    final y = dt.year.toString().padLeft(4, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$_prefix$y$mo${d}T$h$mi${s}Z$_suffix';
  }

  /// Parses the UTC timestamp encoded in [filename].
  ///
  /// Returns `null` for any input that does not match the canonical pattern.
  /// Never throws.
  static DateTime? parseTimestamp(String filename) {
    final match = _pattern.firstMatch(filename);
    if (match == null) return null;
    return DateTime.utc(
      int.parse(match.group(1)!), // year
      int.parse(match.group(2)!), // month
      int.parse(match.group(3)!), // day
      int.parse(match.group(4)!), // hour
      int.parse(match.group(5)!), // minute
      int.parse(match.group(6)!), // second
    );
  }
}
