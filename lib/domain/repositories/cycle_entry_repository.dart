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

import '../entities/cycle_entry_entity.dart';

abstract class CycleEntryRepository {
  Stream<List<CycleEntryEntity>> watchAll();

  Future<List<CycleEntryEntity>> getRecent(int n);

  Future<CycleEntryEntity> insert(CycleEntryEntity entry);

  Future<void> update(CycleEntryEntity entry);

  Future<void> delete(int id);

  /// Replaces the entire cycle entry table with [entries] in a single
  /// transaction.  Used by [RecomputeCycleEntries].
  Future<void> replaceAll(List<CycleEntryEntity> entries);
}
