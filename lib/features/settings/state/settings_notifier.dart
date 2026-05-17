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

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/app_settings_data.dart';
import '../../../providers/repository_providers.dart';

final settingsNotifierProvider =
    AsyncNotifierProvider<SettingsNotifier, AppSettingsData>(
  SettingsNotifier.new,
);

class SettingsNotifier extends AsyncNotifier<AppSettingsData> {
  @override
  Future<AppSettingsData> build() async {
    // BUG-003 fix: watch the reactive settings stream so this notifier
    // rebuilds whenever DB writes (e.g. saveDeclaredCycleLength) land,
    // keeping in-memory state in sync with all DB writes within 500 ms
    // (NFR-02). The _toCompanion exclusion invariant in
    // DriftAppSettingsRepository is not affected.
    final asyncSettings = ref.watch(appSettingsStreamProvider);
    if (asyncSettings.hasValue) {
      // Stream has emitted at least once — use the live value.
      return asyncSettings.requireValue ?? AppSettingsData.defaults();
    }
    // Still loading or errored — fall back to one-shot read so the
    // existing tests that override appSettingsRepositoryProvider (not
    // appSettingsStreamProvider) continue to resolve correctly.
    final repo = await ref.read(appSettingsRepositoryProvider.future);
    return repo.getOrCreate();
  }

  Future<void> save(AppSettingsData settings) async {
    final repo = await ref.read(appSettingsRepositoryProvider.future);
    await repo.updateSettings(settings);
    state = AsyncData(settings);
  }
}
