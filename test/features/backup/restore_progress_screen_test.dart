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

// TASK-20 — RestoreProgressScreen smoke tests
//
// Covers:
//   - AppBar with no leading widget (FR-18)
//   - Terracotta CircularProgressIndicator (accentFlow)
//   - DM Serif Display 22 heading (titleMd)
//   - PopScope.canPop == false (EC-09)
//   - Semantics(liveRegion: true) on heading (FR-32)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/theme/metra_colors.dart';
import 'package:metra/core/theme/metra_theme.dart';
import 'package:metra/features/backup/restore_progress_screen.dart';
import 'package:metra/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Test harness
// ---------------------------------------------------------------------------

Widget _wrap(Widget child) => ProviderScope(
      child: MaterialApp(
        theme: MetraTheme.light(),
        darkTheme: MetraTheme.dark(),
        themeMode: ThemeMode.light,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  testWidgets(
    'RestoreProgressScreen anatomy: AppBar(no leading), terracotta spinner, DM Serif 22 heading',
    (tester) async {
      await tester.pumpWidget(_wrap(const RestoreProgressScreen()));
      await tester.pump();

      // AppBar present.
      expect(find.byType(AppBar), findsOneWidget);

      // No leading widget in the AppBar.
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(
        appBar.leading,
        isNull,
        reason: 'AppBar must have leading: null (FR-18)',
      );
      expect(
        appBar.automaticallyImplyLeading,
        isFalse,
        reason: 'AppBar must not imply a back button (FR-18)',
      );

      // Terracotta spinner present.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final spinner = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      final animation = spinner.valueColor;
      expect(animation, isNotNull, reason: 'Spinner must have valueColor set');
      final resolvedColor =
          (animation! as AlwaysStoppedAnimation<Color>).value;
      expect(
        resolvedColor,
        MetraColors.light.accentFlow,
        reason: 'Spinner color must be accentFlow (terracotta)',
      );

      // Heading text widget present with DM Serif Display 22px style.
      final headingFinder = find.byWidgetPredicate(
        (w) =>
            w is Text &&
            w.style != null &&
            (w.style!.fontSize ?? 0) == 22.0,
      );
      expect(
        headingFinder,
        findsOneWidget,
        reason: 'Heading must use fontSize 22 (titleMd / DM Serif Display)',
      );
    },
  );

  testWidgets(
    'RestoreProgressScreen PopScope.canPop == false',
    (tester) async {
      await tester.pumpWidget(_wrap(const RestoreProgressScreen()));
      await tester.pump();

      final popScopeWidgets = tester
          .widgetList<PopScope<dynamic>>(find.byType(PopScope))
          .toList();
      expect(
        popScopeWidgets,
        isNotEmpty,
        reason: 'Screen must contain a PopScope widget (EC-09)',
      );
      expect(
        popScopeWidgets.first.canPop,
        isFalse,
        reason: 'PopScope.canPop must be false to block back navigation (EC-09)',
      );
    },
  );

  testWidgets(
    'RestoreProgressScreen heading has Semantics(liveRegion: true)',
    (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(_wrap(const RestoreProgressScreen()));
      await tester.pump();

      final liveRegionNodes = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where((s) => s.properties.liveRegion == true)
          .toList();
      expect(
        liveRegionNodes,
        isNotEmpty,
        reason: 'Heading must be wrapped in Semantics(liveRegion: true) (FR-32)',
      );

      handle.dispose();
    },
  );
}
