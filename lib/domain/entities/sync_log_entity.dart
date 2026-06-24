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

// Shipped members: dropbox, googleDrive, iCloud (FR-03, FR-04).
enum SyncProvider { dropbox, googleDrive, iCloud }

enum SyncOperation { backup, restore, backupSkipped }

class SyncLogEntity {
  const SyncLogEntity({
    this.id,
    required this.timestamp,
    required this.provider,
    required this.operation,
    required this.success,
    this.errorMessage,
  });

  final int? id;
  final DateTime timestamp;
  final SyncProvider provider;
  final SyncOperation operation;
  final bool success;
  final String? errorMessage;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncLogEntity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          timestamp == other.timestamp &&
          provider == other.provider &&
          operation == other.operation &&
          success == other.success &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode =>
      Object.hash(id, timestamp, provider, operation, success, errorMessage);

  SyncLogEntity copyWith({
    int? id,
    DateTime? timestamp,
    SyncProvider? provider,
    SyncOperation? operation,
    bool? success,
    String? errorMessage,
  }) =>
      SyncLogEntity(
        id: id ?? this.id,
        timestamp: timestamp ?? this.timestamp,
        provider: provider ?? this.provider,
        operation: operation ?? this.operation,
        success: success ?? this.success,
        errorMessage: errorMessage ?? this.errorMessage,
      );
}
