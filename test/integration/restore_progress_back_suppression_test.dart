// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
// SPDX-License-Identifier: GPL-3.0-or-later
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

// TASK-36 — Integration scenario I-P
//
// I-P — RestoreProgressScreen back-button suppressed at navigation-stack level.
//
// This test supplements the widget-level test in
// test/features/backup/restore_progress_screen_test.dart by verifying that
// PopScope.canPop == false and that a programmatic back-press does NOT pop
// RestoreProgressScreen from the Navigator stack.
//
// Spec refs: EC-09 (back suppressed during restore), FR-18 (no back chevron).
// Target platforms: Linux CI, headless.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/theme/metra_theme.dart';
import 'package:metra/features/backup/restore_progress_screen.dart';
import 'package:metra/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group(
    'I-P — RestoreProgressScreen back suppression (navigation-stack level)',
    () {
      // I-P-1: PopScope.canPop is false.
      //
      // NOTE: RestoreProgressScreen contains a CircularProgressIndicator with
      // an infinite animation — use pump() not pumpAndSettle() to avoid timeout.
      testWidgets(
        'should_have_PopScope_with_canPop_false',
        (tester) async {
          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                theme: MetraTheme.light(),
                locale: const Locale('en'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: const RestoreProgressScreen(),
              ),
            ),
          );
          // Advance one frame to let the widget tree build; no pumpAndSettle
          // because CircularProgressIndicator never settles.
          await tester.pump();

          final popScope = tester.widget<PopScope>(find.byType(PopScope));
          expect(
            popScope.canPop,
            isFalse,
            reason: 'EC-09: back must be suppressed during restore',
          );
        },
      );

      // I-P-2: Back press does NOT pop the screen from the Navigator stack.
      //
      // The screen is pushed onto a two-route Navigator so there is a route
      // underneath to pop to. handlePopRoute() is the programmatic equivalent
      // of the device back button.
      //
      // NOTE: RestoreProgressScreen contains a CircularProgressIndicator with
      // an infinite animation — pumpAndSettle() would time out. Use pump()
      // with a bounded duration instead.
      testWidgets(
        'should_remain_on_screen_after_back_press_given_route_underneath',
        (tester) async {
          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                theme: MetraTheme.light(),
                locale: const Locale('en'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                routes: {
                  '/': (_) => const Scaffold(body: Text('Home')),
                  '/restore': (_) => const RestoreProgressScreen(),
                },
                initialRoute: '/',
              ),
            ),
          );
          // Use pump(duration) to advance past route animations without waiting
          // for the infinite CircularProgressIndicator to settle.
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));

          // Push RestoreProgressScreen. Do NOT await — pushNamed returns a
          // Future that resolves when the route is popped, but canPop:false
          // means the route never pops, so awaiting it would hang forever.
          unawaited(
            tester
                .state<NavigatorState>(find.byType(Navigator))
                .pushNamed('/restore'),
          );
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));

          expect(find.byType(RestoreProgressScreen), findsOneWidget);

          // Simulate the system back button.
          final bool handled = await tester.binding.handlePopRoute();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          // PopScope.canPop == false so the pop is rejected; the screen must
          // still be visible.  handlePopRoute() returns true when the route
          // handles the pop (i.e. the pop was consumed/suppressed), meaning
          // the framework did not actually pop the route.
          expect(handled, isTrue);
          expect(
            find.byType(RestoreProgressScreen),
            findsOneWidget,
            reason:
                'EC-09: RestoreProgressScreen must not be popped by back press',
          );
        },
      );
    },
  );
}
