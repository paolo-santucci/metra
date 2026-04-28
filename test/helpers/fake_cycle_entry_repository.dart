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

import 'package:metra/domain/entities/cycle_entry_entity.dart';
import 'package:metra/domain/repositories/cycle_entry_repository.dart';

class FakeCycleEntryRepository implements CycleEntryRepository {
  final List<CycleEntryEntity> entries = [];
  int _nextId = 1;

  @override
  Stream<List<CycleEntryEntity>> watchAll() => Stream.value(List.from(entries));

  @override
  Future<List<CycleEntryEntity>> getRecent(int n) async =>
      entries.reversed.take(n).toList();

  @override
  Future<CycleEntryEntity> insert(CycleEntryEntity entry) async {
    final withId = CycleEntryEntity(
      id: _nextId++,
      startDate: entry.startDate,
      endDate: entry.endDate,
      cycleLength: entry.cycleLength,
      periodLength: entry.periodLength,
    );
    entries.add(withId);
    return withId;
  }

  @override
  Future<void> update(CycleEntryEntity entry) async {
    final idx = entries.indexWhere((e) => e.id == entry.id);
    if (idx >= 0) entries[idx] = entry;
  }

  @override
  Future<void> delete(int id) async {
    entries.removeWhere((e) => e.id == id);
  }

  @override
  Future<void> replaceAll(List<CycleEntryEntity> newEntries) async {
    entries.clear();
    for (final e in newEntries) {
      entries.add(
        CycleEntryEntity(
          id: _nextId++,
          startDate: e.startDate,
          endDate: e.endDate,
          cycleLength: e.cycleLength,
          periodLength: e.periodLength,
        ),
      );
    }
  }
}
