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
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/theme/metra_theme.dart';
import 'package:metra/features/onboarding/onboarding_screen.dart';
import 'package:metra/l10n/app_localizations.dart';

// ── Helpers ──────────────────────────────────────────────────────────────────

Widget _wrapWithTheme(ThemeData theme) => ProviderScope(
      child: MaterialApp(
        theme: theme,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const OnboardingScreen(),
      ),
    );

/// Navigate to the data page (page 2) by tapping "Get started".
Future<void> _navigateToDataPage(WidgetTester tester) async {
  await tester.tap(find.text('Get started'));
  await tester.pumpAndSettle();
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // Give each test enough vertical space to render the onboarding pages.
  setUp(() {});

  group('Onboarding CTA — dark theme (FR-05/FR-07)', () {
    testWidgets('_WelcomePage dark — ButtonStyle ghost spec', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_wrapWithTheme(MetraTheme.dark()));
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Get started'),
      );
      final style = button.style!;
      final emptyStates = <WidgetState>{};

      final bg = style.backgroundColor?.resolve(emptyStates);
      final fg = style.foregroundColor?.resolve(emptyStates);
      final side = style.side?.resolve(emptyStates);

      // Dark ghost: bg = avorio #EDE4D3 @ 0x1A
      expect(
        bg,
        equals(const Color(0xFFEDE4D3).withAlpha(0x1A)),
        reason: 'dark CTA background must be avorio at 10% alpha (0x1A)',
      );
      // Foreground = avorio full opacity
      expect(
        fg,
        equals(const Color(0xFFEDE4D3)),
        reason: 'dark CTA foreground must be avorio at full opacity',
      );
      // Border = avorio @ 0x2E
      expect(
        side,
        equals(
          BorderSide(
            color: const Color(0xFFEDE4D3).withAlpha(0x2E),
            width: 1.0,
          ),
        ),
        reason: 'dark CTA border must be avorio at 18% alpha (0x2E)',
      );
    });

    testWidgets('_DataPage dark — same ghost spec', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_wrapWithTheme(MetraTheme.dark()));
      await tester.pumpAndSettle();
      await _navigateToDataPage(tester);

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'All set →'),
      );
      final style = button.style!;
      final emptyStates = <WidgetState>{};

      final bg = style.backgroundColor?.resolve(emptyStates);
      final fg = style.foregroundColor?.resolve(emptyStates);
      final side = style.side?.resolve(emptyStates);

      expect(
        bg,
        equals(const Color(0xFFEDE4D3).withAlpha(0x1A)),
        reason: 'dark data-page CTA background must be avorio at 10% alpha',
      );
      expect(
        fg,
        equals(const Color(0xFFEDE4D3)),
        reason: 'dark data-page CTA foreground must be avorio',
      );
      expect(
        side,
        equals(
          BorderSide(
            color: const Color(0xFFEDE4D3).withAlpha(0x2E),
            width: 1.0,
          ),
        ),
        reason: 'dark data-page CTA border must be avorio at 18% alpha',
      );
    });
  });

  group('Onboarding CTA — light theme regression (FR-06)', () {
    testWidgets('_WelcomePage light — solid ink', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_wrapWithTheme(MetraTheme.light()));
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Get started'),
      );
      final style = button.style!;
      final emptyStates = <WidgetState>{};

      final bg = style.backgroundColor?.resolve(emptyStates);
      final fg = style.foregroundColor?.resolve(emptyStates);
      final side = style.side?.resolve(emptyStates);

      // Light solid: bg = ink #2B2521, fg = sand #F4EDE2, no border
      expect(
        bg,
        equals(const Color(0xFF2B2521)),
        reason: 'light CTA background must be ink (#2B2521)',
      );
      expect(
        fg,
        equals(const Color(0xFFF4EDE2)),
        reason: 'light CTA foreground must be sand (#F4EDE2)',
      );
      final isNoBorder = side == null || side == BorderSide.none;
      expect(isNoBorder, isTrue, reason: 'light CTA must have no border');
    });

    testWidgets('_DataPage light — solid ink', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_wrapWithTheme(MetraTheme.light()));
      await tester.pumpAndSettle();
      await _navigateToDataPage(tester);

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'All set →'),
      );
      final style = button.style!;
      final emptyStates = <WidgetState>{};

      final bg = style.backgroundColor?.resolve(emptyStates);
      final fg = style.foregroundColor?.resolve(emptyStates);
      final side = style.side?.resolve(emptyStates);

      expect(
        bg,
        equals(const Color(0xFF2B2521)),
        reason: 'light data-page CTA background must be ink (#2B2521)',
      );
      expect(
        fg,
        equals(const Color(0xFFF4EDE2)),
        reason: 'light data-page CTA foreground must be sand (#F4EDE2)',
      );
      final isNoBorder = side == null || side == BorderSide.none;
      expect(
        isNoBorder,
        isTrue,
        reason: 'light data-page CTA must have no border',
      );
    });
  });

  group('Onboarding CTA — behavioural invariants (FR-11/NFR-03)', () {
    testWidgets('tap target ≥ 48×48 dp — welcome page light', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_wrapWithTheme(MetraTheme.light()));
      await tester.pumpAndSettle();

      final size =
          tester.getSize(find.widgetWithText(FilledButton, 'Get started'));
      expect(size.height, greaterThanOrEqualTo(48));
      expect(size.width, greaterThanOrEqualTo(48));
    });

    testWidgets('tap target ≥ 48×48 dp — welcome page dark', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_wrapWithTheme(MetraTheme.dark()));
      await tester.pumpAndSettle();

      final size =
          tester.getSize(find.widgetWithText(FilledButton, 'Get started'));
      expect(size.height, greaterThanOrEqualTo(48));
      expect(size.width, greaterThanOrEqualTo(48));
    });

    testWidgets('onPressed is non-null on welcome page', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_wrapWithTheme(MetraTheme.dark()));
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Get started'),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('pressed-state smoke — dark welcome page, no exception (EC-06)',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_wrapWithTheme(MetraTheme.dark()));
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(
        tester.getCenter(find.widgetWithText(FilledButton, 'Get started')),
      );
      await tester.pump();
      // No exception; button still in tree.
      expect(find.widgetWithText(FilledButton, 'Get started'), findsOneWidget);
      await gesture.up();
    });
  });
}
