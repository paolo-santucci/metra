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
    final repo = await ref.watch(appSettingsRepositoryProvider.future);
    return repo.getOrCreate();
  }

  Future<void> save(AppSettingsData settings) async {
    final repo = await ref.read(appSettingsRepositoryProvider.future);
    await repo.updateSettings(settings);
    state = AsyncData(settings);
  }
}
