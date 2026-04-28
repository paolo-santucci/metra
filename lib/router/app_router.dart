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
import 'package:go_router/go_router.dart';
import '../features/calendar/calendar_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/stats/stats_screen.dart';
import '../features/timeline/timeline_screen.dart';

// Tab indices match the NavigationBar destination order:
//   0 = Calendar, 1 = Timeline, 2 = Stats, 3 = Settings.
// Do NOT reorder without updating _destinations and _paths below.
const int _tabCalendar = 0;
const int _tabSettings = 3;

final GoRouter appRouter = GoRouter(
  initialLocation: '/calendar',
  routes: [
    ShellRoute(
      builder: (context, state, child) => _ScaffoldWithNav(child: child),
      routes: [
        GoRoute(
          path: '/calendar',
          builder: (context, state) => const CalendarScreen(),
        ),
        GoRoute(
          path: '/timeline',
          builder: (context, state) => const TimelineScreen(),
        ),
        GoRoute(
          path: '/stats',
          builder: (context, state) => const StatsScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    ),
  ],
);

class _ScaffoldWithNav extends StatelessWidget {
  const _ScaffoldWithNav({required this.child});

  final Widget child;

  // Italian labels: source of truth is the mockup (mockup/scripts/i18n.js).
  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.calendar_today_outlined),
      label: 'Calendario',
    ),
    NavigationDestination(
      icon: Icon(Icons.view_timeline_outlined),
      label: 'Timeline',
    ),
    NavigationDestination(
      icon: Icon(Icons.bar_chart_outlined),
      label: 'Statistiche',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      label: 'Impostazioni',
    ),
  ];

  static const _paths = <String>[
    '/calendar',
    '/timeline',
    '/stats',
    '/settings',
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final index = _paths.indexWhere(location.startsWith);
    return index < 0 ? _tabCalendar : index.clamp(_tabCalendar, _tabSettings);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex(context),
        onDestinationSelected: (index) => context.go(_paths[index]),
        destinations: _destinations,
      ),
    );
  }
}
