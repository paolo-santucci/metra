// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/theme/metra_theme.dart';
import 'package:metra/features/backup/state/backup_notifier.dart';
import 'package:metra/features/backup/state/backup_state.dart';
import 'package:metra/features/backup/views/backup_error_view.dart';
import 'package:metra/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Stub notifier — controllable Completer so we can observe a loading state
// ---------------------------------------------------------------------------

class _StubNotifier extends BackupNotifier {
  _StubNotifier(this._initial);
  final BackupState _initial;
  int buildCount = 0;

  @override
  Future<BackupState> build() async {
    buildCount++;
    return _initial;
  }
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

Widget _wrap({
  required String message,
  _StubNotifier? stub,
}) {
  return ProviderScope(
    overrides: [
      backupNotifierProvider.overrideWith(
        () => stub ?? _StubNotifier(BackupErrorState(message)),
      ),
    ],
    child: MaterialApp(
      theme: MetraTheme.light(),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BackupErrorView(message: message),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('BackupErrorView', () {
    testWidgets(
      'renders liveRegion error message + retry CTA',
      (tester) async {
        const errorMessage = 'Something went wrong in backup';

        await tester.pumpWidget(_wrap(message: errorMessage));
        await tester.pumpAndSettle();

        // Error message text is rendered.
        expect(find.text(errorMessage), findsOneWidget);

        // ElevatedButton (retry CTA) is present.
        expect(find.byType(ElevatedButton), findsOneWidget);

        // Semantics(liveRegion: true) wraps the error message.
        final liveRegionWidgets = tester
            .widgetList<Semantics>(find.byType(Semantics))
            .where((s) => s.properties.liveRegion == true)
            .toList();
        expect(
          liveRegionWidgets,
          isNotEmpty,
          reason:
              'Expected at least one Semantics widget with liveRegion: true',
        );
      },
    );

    testWidgets(
      'retry CTA label is common_error_generic localised string',
      (tester) async {
        await tester.pumpWidget(_wrap(message: 'error'));
        await tester.pumpAndSettle();

        // EN locale value of common_error_generic.
        expect(
          find.widgetWithText(
            ElevatedButton,
            'Something went wrong. Please try again.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'retry CTA tap invalidates backupNotifierProvider — rebuild triggered',
      (tester) async {
        const errorMessage = 'Network error';
        final stub = _StubNotifier(const BackupErrorState(errorMessage));

        // Use a wrapper that also watches the provider so it initialises.
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              backupNotifierProvider.overrideWith(() => stub),
            ],
            child: MaterialApp(
              theme: MetraTheme.light(),
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Column(
                children: [
                  // This watcher ensures the provider is initialised so
                  // buildCount can be observed after invalidation.
                  Consumer(
                    builder: (context, ref, _) {
                      ref.watch(backupNotifierProvider);
                      return const SizedBox.shrink();
                    },
                  ),
                  const Expanded(
                    child: BackupErrorView(message: errorMessage),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final buildCountAfterSettle = stub.buildCount;
        expect(
          buildCountAfterSettle,
          greaterThan(0),
          reason: 'Provider should have built at least once',
        );

        // Tap the retry button — triggers ref.invalidate.
        await tester.tap(find.byType(ElevatedButton));
        await tester.pumpAndSettle();

        // build() must have been called at least once more after invalidation.
        expect(
          stub.buildCount,
          greaterThan(buildCountAfterSettle),
          reason: 'Tapping retry should invalidate backupNotifierProvider, '
              'causing build() to be called again',
        );
      },
    );

    testWidgets(
      'has own Scaffold with backup_screen_title AppBar',
      (tester) async {
        await tester.pumpWidget(_wrap(message: 'error'));
        await tester.pumpAndSettle();

        // Own Scaffold.
        expect(find.byType(Scaffold), findsWidgets);

        // AppBar with backup title (EN locale).
        expect(find.text('Backup'), findsOneWidget);
      },
    );
  });
}
