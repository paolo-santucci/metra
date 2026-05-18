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
import 'package:go_router/go_router.dart';
import '../app.dart' show navigatorKey;
import '../core/widgets/metra_tab_bar.dart';
import '../features/backup/backup_screen.dart';
import '../features/calendar/calendar_screen.dart';
import '../features/daily_entry/historical_entry_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/stats/stats_screen.dart';
import '../features/timeline/timeline_screen.dart';
import '../providers/repository_providers.dart';

// Tab indices match the NavigationBar destination order:
//   0 = Calendar, 1 = Archivio (Timeline), 2 = Stats, 3 = Settings.
// Do NOT reorder without updating _destinations and _paths below.
const int _tabCalendar = 0;
const int _tabSettings = 3;

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    // FR-24 / TASK-08: navigatorKey is the app-wide GlobalKey<NavigatorState>
    // declared in app.dart. GoRouter registers it as the root navigator so
    // NavigatorKeyDialog can resolve currentState and dispatch the
    // PermissionBlocked AlertDialog without a BuildContext.
    navigatorKey: navigatorKey,
    initialLocation: '/calendar',
    redirect: (context, state) async {
      if (state.uri.path == '/onboarding') return null;
      final settingsRepo = await ref.read(appSettingsRepositoryProvider.future);
      final settings = await settingsRepo.getOrCreate();
      if (!settings.onboardingCompleted) return '/onboarding';
      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      // Daily-entry routes are top-level (outside the ShellRoute) so the
      // bottom navigation bar is hidden when they are active.
      GoRoute(
        path: '/backup',
        builder: (context, state) => const BackupScreen(),
      ),
      GoRoute(
        path: '/daily-entry/:date',
        builder: (context, state) {
          final dateStr =
              state.pathParameters['date']!; // safe: required path param
          // Parse as UTC midnight to match DailyLogEntity.date storage format.
          final parts = dateStr.split('-');
          final date = DateTime.utc(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          );
          return HistoricalEntryScreen(date: date);
        },
      ),
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
});

class _ScaffoldWithNav extends StatelessWidget {
  const _ScaffoldWithNav({required this.child});

  final Widget child;

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
      bottomNavigationBar: MetraTabBar(
        currentIndex: _currentIndex(context),
        onTabSelected: (index) => context.go(_paths[index]),
      ),
    );
  }
}
