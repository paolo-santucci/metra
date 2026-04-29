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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/metra_theme.dart';
import 'domain/entities/cycle_prediction.dart';
import 'features/calendar/state/prediction_controller.dart';
import 'l10n/app_localizations.dart';
import 'providers/use_case_providers.dart';
import 'router/app_router.dart';

/// Root widget — owns [ProviderScope] and accepts overrides for tests.
class MetraApp extends StatelessWidget {
  const MetraApp({
    super.key,
    this.overrides = const [],
  });

  final List<Override> overrides;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: overrides,
      child: const _MetraInner(),
    );
  }
}

class _MetraInner extends ConsumerStatefulWidget {
  const _MetraInner();

  @override
  ConsumerState<_MetraInner> createState() => _MetraInnerState();
}

class _MetraInnerState extends ConsumerState<_MetraInner> {
  @override
  void initState() {
    super.initState();
    // Best-effort: initialize notification channels. Failures are non-fatal
    // (e.g. test environments without a platform channel).
    ref
        .read(notificationServiceProvider)
        .initialize()
        .catchError((Object _) {});
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<CyclePrediction?>>(
      cyclePredictionProvider,
      (_, next) async {
        final prediction = next.valueOrNull;
        final settings = ref.read(getOrCreateSettingsProvider).valueOrNull;
        if (settings == null) return;
        final l10n =
            await AppLocalizations.delegate.load(Locale(settings.languageCode));
        final scheduler =
            await ref.read(schedulePredictionNotificationProvider.future);
        await scheduler.execute(
          prediction: prediction,
          settings: settings,
          title: l10n.notification_prediction_title,
          body: prediction != null
              ? l10n.notification_prediction_body(
                  settings.notificationDaysBefore,
                )
              : '',
        );
      },
    );

    return MaterialApp.router(
      title: 'Mētra',
      theme: MetraTheme.light(),
      darkTheme: MetraTheme.dark(),
      themeMode: ThemeMode.system,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
