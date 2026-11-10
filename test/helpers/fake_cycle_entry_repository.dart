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

import 'dart:async';

import 'package:metra/domain/entities/cycle_entry_entity.dart';
import 'package:metra/domain/repositories/cycle_entry_repository.dart';

class FakeCycleEntryRepository implements CycleEntryRepository {
  final List<CycleEntryEntity> entries = [];
  int _nextId = 1;

  StreamController<List<CycleEntryEntity>>? _watchController;

  /// Switches [watchAll] to controllable mode and returns the backing
  /// controller.
  ///
  /// Tests that need several emissions call this once and then push each
  /// emission with [emitCycles]. Callers that never call it keep the default
  /// single-emission [Stream.value] behaviour untouched.
  StreamController<List<CycleEntryEntity>> enableControllableWatchAll() {
    final controller = StreamController<List<CycleEntryEntity>>();
    _watchController = controller;
    return controller;
  }

  /// Pushes one [watchAll] emission containing [cycles].
  void emitCycles(List<CycleEntryEntity> cycles) {
    final controller = _watchController;
    if (controller == null) {
      throw StateError('Call enableControllableWatchAll() first.');
    }
    controller.add(List<CycleEntryEntity>.of(cycles));
  }

  /// Closes the controllable [watchAll] controller when one is active.
  Future<void> close() async {
    final controller = _watchController;
    _watchController = null;
    await controller?.close();
  }

  @override
  Stream<List<CycleEntryEntity>> watchAll() {
    final controller = _watchController;
    if (controller != null) return controller.stream;
    return Stream.value(List.from(entries));
  }

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

  @override
  Future<CycleEntryEntity?> getByStartDate(DateTime startDate) async =>
      entries.where((e) => e.startDate == startDate).firstOrNull;

  final List<String> callLog = [];
  bool deleteAllCalled = false;

  /// When non-null, [deleteAll] throws this error instead of clearing entries.
  Object? throwOnDeleteAll;

  @override
  Future<void> deleteAll() async {
    if (throwOnDeleteAll != null) {
      throw throwOnDeleteAll!; // safe: null-checked above
    }
    deleteAllCalled = true;
    callLog.add('deleteAll');
    entries.clear();
  }
}
