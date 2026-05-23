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

import 'dart:io' as io show File;
import 'dart:ui' show Tristate;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/theme/metra_theme.dart';
import 'package:metra/core/widgets/settings/metra_toggle.dart';

// Wraps the widget under test in a minimal MaterialApp with the Métra theme.
Widget _wrap(
  Widget child, {
  ThemeMode themeMode = ThemeMode.light,
  bool disableAnimations = false,
}) =>
    MaterialApp(
      theme: MetraTheme.light(),
      darkTheme: MetraTheme.dark(),
      themeMode: themeMode,
      home: MediaQuery(
        data: MediaQueryData(
          disableAnimations: disableAnimations,
        ),
        child: Scaffold(body: Center(child: child)),
      ),
    );

void main() {
  // ── Dimensions ────────────────────────────────────────────────────────────

  testWidgets('MetraToggle: 48×28 dimensions, terracotta active when true', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(MetraToggle(value: true, onChanged: (_) {})),
    );
    await tester.pump();

    // The AnimatedContainer is the root of the toggle track.
    final container = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer),
    );
    final decoration = container.decoration as BoxDecoration;

    expect(container.constraints?.maxWidth, 48.0);
    expect(container.constraints?.minWidth, 48.0);
    expect(container.constraints?.maxHeight, 28.0);
    expect(container.constraints?.minHeight, 28.0);

    // When value is true the track background should be the terracotta accent.
    // We verify it is non-transparent (the accentFlow colour).
    expect(decoration.color, isNotNull);
    // Alpha component: .a is 0.0–1.0, fully opaque = 1.0.
    expect(decoration.color!.a, greaterThan(0.0));
  });

  // ── Tap interaction ───────────────────────────────────────────────────────

  testWidgets('MetraToggle: tap fires onChanged with toggled value', (
    tester,
  ) async {
    bool? received;
    await tester.pumpWidget(
      _wrap(
        MetraToggle(
          value: false,
          onChanged: (v) => received = v,
        ),
      ),
    );

    await tester.tap(find.byType(MetraToggle));
    await tester.pump();

    expect(received, isTrue); // false → toggled → true
  });

  testWidgets('MetraToggle: tap on true fires onChanged with false', (
    tester,
  ) async {
    bool? received;
    await tester.pumpWidget(
      _wrap(
        MetraToggle(
          value: true,
          onChanged: (v) => received = v,
        ),
      ),
    );

    await tester.tap(find.byType(MetraToggle));
    await tester.pump();

    expect(received, isFalse); // true → toggled → false
  });

  // ── iOS platform override ─────────────────────────────────────────────────
  // The widget must render without throwing under an iOS platform override,
  // and must NOT use Platform.isIOS / dart:io for the check.

  testWidgets(
    'MetraToggle: iOS platform override — widget renders without error',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await tester.pumpWidget(
          _wrap(MetraToggle(value: false, onChanged: (_) {})),
        );
        await tester.pump();
        expect(find.byType(MetraToggle), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  // ── Reduced motion ────────────────────────────────────────────────────────
  // When MediaQuery.disableAnimations is true the widget must use a duration
  // derived from MetraMotion.instant (0 ms), not the normal fast duration.

  testWidgets(
    'MetraToggle: reduced motion — AnimatedContainer uses instant duration',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          MetraToggle(value: true, onChanged: (_) {}),
          disableAnimations: true,
        ),
      );
      await tester.pump();

      final container = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      // MetraMotion.instant == 0 ms
      expect(container.duration, const Duration(milliseconds: 0));
    },
  );

  testWidgets(
    'MetraToggle: normal motion — AnimatedContainer uses fast duration',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          MetraToggle(value: true, onChanged: (_) {}),
          disableAnimations: false,
        ),
      );
      await tester.pump();

      final container = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      // MetraMotion.fast == 150 ms
      expect(container.duration, const Duration(milliseconds: 150));
    },
  );

  // ── Static analysis guard ─────────────────────────────────────────────────
  // Ensures no import of dart:io snuck into the implementation file.

  test('metra_toggle.dart contains no import of dart:io', () {
    final src = io.File('lib/core/widgets/settings/metra_toggle.dart')
        .readAsStringSync();
    // Neither unconditional nor conditional dart:io imports are allowed.
    expect(src.contains("import 'dart:io'"), isFalse);
    expect(src.contains('import "dart:io"'), isFalse);
  });

  test('metra_toggle.dart contains no Platform.isIOS reference', () {
    final src = io.File('lib/core/widgets/settings/metra_toggle.dart')
        .readAsStringSync();
    expect(src.contains('Platform.isIOS'), isFalse);
    expect(src.contains('Platform.isAndroid'), isFalse);
  });

  // ── Semantics ─────────────────────────────────────────────────────────────

  testWidgets('MetraToggle: Semantics toggled reflects value', (tester) async {
    await tester.pumpWidget(
      _wrap(MetraToggle(value: true, onChanged: (_) {})),
    );
    await tester.pump();

    final semantics = tester.getSemantics(find.byType(MetraToggle));
    expect(semantics.flagsCollection.isToggled, Tristate.isTrue);
  });

  testWidgets(
    'MetraToggle: Semantics toggled is false when value is false',
    (tester) async {
      await tester.pumpWidget(
        _wrap(MetraToggle(value: false, onChanged: (_) {})),
      );
      await tester.pump();

      final semantics = tester.getSemantics(find.byType(MetraToggle));
      expect(semantics.flagsCollection.isToggled, isNot(Tristate.isTrue));
    },
  );
}
