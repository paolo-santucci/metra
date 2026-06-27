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

import 'dart:ui' show Locale;

/// Resolves the effective app [Locale] from the stored Settings language choice
/// and the device's FULL ordered preferred-locale list.
///
/// This is the **single source of truth** for the follow-system fallback rule
/// (FR-28 / FR-29 / FR-30, LP risk R-10). It is consumed by BOTH locale
/// resolution sites so they can never drift:
///   1. the notification-string path (`_effectiveLangCode` in `app.dart`), and
///   2. the UI path (`MaterialApp.router.localeResolutionCallback` in `app.dart`).
///
/// Resolution rules:
///   * `stored == 'it'` -> `Locale('it')`            (explicit choice, FR-29)
///   * `stored == 'en'` -> `Locale('en')`            (explicit choice, FR-29)
///   * `stored == ''`   -> `Locale('it')` iff ANY entry in [systemLocales] has
///                          `languageCode == 'it'` (region-stripped, so `it-CH`
///                          counts), else `Locale('en')`   (follow-system, FR-28)
///   * any other code   -> `Locale('en')`            (unsupported clamp, BUG-003)
///
/// [systemLocales] MUST be the full preferred list
/// (`WidgetsBinding.instance.platformDispatcher.locales`) and NOT the single
/// primary `.locale`, so the notification path and the widget tree resolve
/// identically on multilingual devices (BUG-002 — the divergence the bug-hunter
/// confirmed). Pure / widget-free so it is unit-testable without a widget tree.
Locale resolveAppLocale({
  required String stored,
  required List<Locale> systemLocales,
}) {
  if (stored == 'it') return const Locale('it');
  if (stored == 'en') return const Locale('en');
  final prefersItalian =
      stored.isEmpty && systemLocales.any((l) => l.languageCode == 'it');
  return prefersItalian ? const Locale('it') : const Locale('en');
}
