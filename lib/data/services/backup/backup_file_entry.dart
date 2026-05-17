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

import 'package:flutter/foundation.dart';

/// A single backup file entry returned by [CloudBackupProvider.listFiles].
///
/// Carries the metadata needed by the restore picker (FR-14b): file name,
/// UTC timestamp, and size in bytes.  Equality is value-based on all three
/// fields so instances can be compared and placed in sets.
@immutable
class BackupFileEntry {
  const BackupFileEntry({
    required this.name,
    required this.timestampUtc,
    required this.sizeBytes,
  });

  final String name;
  final DateTime timestampUtc;
  final int sizeBytes;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BackupFileEntry &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          timestampUtc == other.timestampUtc &&
          sizeBytes == other.sizeBytes;

  @override
  int get hashCode => Object.hash(name, timestampUtc, sizeBytes);

  @override
  String toString() =>
      'BackupFileEntry(name: $name, timestampUtc: $timestampUtc, sizeBytes: $sizeBytes)';
}
