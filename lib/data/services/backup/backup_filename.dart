// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:math';

/// Utility class for converting between backup filenames and UTC timestamps.
///
/// Canonical format: `metra_backup_YYYYMMDDTHHMMSSZ_<6char>.enc`
///
/// The 6-character suffix is drawn from `[a-z0-9]` via [Random.secure] to
/// prevent collisions when two backups are issued within the same UTC second
/// (FR-15). Legacy filenames without a suffix are also accepted by
/// [parseTimestamp] (FR-15a).
class BackupFilename {
  BackupFilename._();

  static const _prefix = 'metra_backup_';
  static const _ext = '.enc';
  static const _suffixLength = 6;
  static const _suffixAlphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';

  /// Accepts both legacy form (`…Z.enc`) and new suffixed form (`…Z_<6char>.enc`).
  static final _pattern = RegExp(
    r'^metra_backup_(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})Z(?:_([a-z0-9]{6}))?\.enc$',
  );

  /// Returns the canonical filename for a backup taken at [t].
  ///
  /// The datetime is always converted to UTC before formatting. A 6-character
  /// `[a-z0-9]` suffix is appended to prevent collisions within the same UTC
  /// second (FR-15).
  ///
  /// [randomSuffix] — when provided, the suffix is used verbatim instead of
  /// drawing from [Random.secure]. This exists exclusively for deterministic
  /// test injection (HC-7); production callers must omit this parameter.
  static String filenameFor(DateTime t, {String? randomSuffix}) {
    final dt = t.toUtc();
    final y = dt.year.toString().padLeft(4, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    final suffix = randomSuffix ?? _generateSuffix();
    return '$_prefix$y$mo${d}T$h$mi${s}Z_$suffix$_ext';
  }

  /// Generates a 6-character random suffix from `[a-z0-9]` using
  /// [Random.secure] for cryptographically suitable entropy.
  static String _generateSuffix() {
    final rng = Random.secure();
    final buf = StringBuffer();
    for (var i = 0; i < _suffixLength; i++) {
      buf.writeCharCode(
        _suffixAlphabet.codeUnitAt(rng.nextInt(_suffixAlphabet.length)),
      );
    }
    return buf.toString();
  }

  /// Parses the UTC timestamp encoded in [filename].
  ///
  /// Accepts both the legacy form (`metra_backup_YYYYMMDDTHHMMSSZ.enc`) and
  /// the new suffixed form (`metra_backup_YYYYMMDDTHHMMSSZ_<6char>.enc`).
  ///
  /// Returns `null` for any input that does not match either pattern.
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
