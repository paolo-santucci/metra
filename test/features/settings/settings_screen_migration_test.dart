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

// Group C — Settings migration cleanliness tests (TASK-25, FR-10)
//
// Spec §7.1 Group C bullets:
//   C-1: settings_screen.dart private-class removal (grep/string-search)
//   C-2: flutter analyze reports zero orphan-import / dead-code warnings
//   C-3: SettingsRow backwards-compatibility smoke (all actual call-site variants)
//
// NOTE: Spec bullet C-3 mentions "Calendario toggle" and "Account staticInfo"
// rows that do NOT exist in the codebase:
//   – Calendario (F-10 device calendar) was deferred 2026-04-29 and never
//     added to SettingsScreen.
//   – Account/staticInfo is a BackupConnectedView concept, not a SettingsScreen
//     row.
// This test instead verifies the *actual* call-site variants present in
// settings_screen.dart: nav (Lingua, Preavviso, Orario notifica),
// toggle (Notifiche, Dolore, Note giornaliere), action (Esporta CSV),
// destructive (Elimina tutti i dati).
//
// Target platforms: Android, iOS, web (all — no platform-specific rendering).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/theme/metra_theme.dart';
import 'package:metra/core/widgets/settings/metra_toggle.dart';
import 'package:metra/core/widgets/settings/settings_row.dart';
import 'package:metra/domain/entities/app_settings_data.dart';
import 'package:metra/features/backup/state/backup_notifier.dart';
import 'package:metra/features/backup/state/backup_state.dart';
import 'package:metra/features/settings/settings_screen.dart';
import 'package:metra/features/settings/state/settings_notifier.dart';
import 'package:metra/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Shared stubs (mirrors structure in settings_screen_test.dart to keep the
// two files independent — no cross-file test helpers to avoid coupling).
// ---------------------------------------------------------------------------

class _StubSettingsNotifier extends SettingsNotifier {
  _StubSettingsNotifier(this._initial);

  final AppSettingsData _initial;

  @override
  Future<AppSettingsData> build() async => _initial;

  @override
  Future<void> save(AppSettingsData settings) async {
    state = AsyncData(settings);
  }
}

class _StubBackupNotifier extends BackupNotifier {
  _StubBackupNotifier(this._initial);

  final BackupState _initial;

  @override
  Future<BackupState> build() async => _initial;
}

/// Wraps [SettingsScreen] with the minimum overrides required to mount it
/// in a test without touching the real database.
Widget _wrap(List<Override> overrides) {
  return ProviderScope(
    overrides: [
      backupNotifierProvider.overrideWith(
        () => _StubBackupNotifier(const BackupNotConnected()),
      ),
      ...overrides,
    ],
    child: MaterialApp(
      theme: MetraTheme.light(),
      locale: const Locale('it'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const SettingsScreen(),
    ),
  );
}

// ---------------------------------------------------------------------------
// Default AppSettingsData used across Group C smoke tests.
// ---------------------------------------------------------------------------
final _defaults = AppSettingsData(
  languageCode: 'it',
  darkMode: null,
  painEnabled: true,
  notesEnabled: true,
  notificationDaysBefore: 2,
  notificationsEnabled: true, // enable so Preavviso/Orario rows are tappable
  onboardingCompleted: false,
);

void main() {
  // ──────────────────────────────────────────────────────────────────────────
  // C-1: Private-class removal — grep test
  // ──────────────────────────────────────────────────────────────────────────
  group('Group C-1: settings_screen.dart private-class removal', () {
    // We read the source file from disk (relative to repo root).  The working
    // directory for `flutter test` is always the package root, so
    // lib/features/... resolves correctly.
    const srcPath = 'lib/features/settings/settings_screen.dart';

    late String src;

    setUpAll(() {
      src = File(srcPath).readAsStringSync();
    });

    test(
      'should_have_no_private_SectionHeader_class',
      () => expect(src, isNot(contains('class _SectionHeader'))),
    );

    test(
      'should_have_no_private_GroupCard_class',
      () => expect(src, isNot(contains('class _GroupCard'))),
    );

    test(
      'should_have_no_private_SettingsDivider_class',
      () => expect(src, isNot(contains('class _SettingsDivider'))),
    );

    test(
      'should_have_no_private_SettingsRow_class',
      () => expect(src, isNot(contains('class _SettingsRow'))),
    );

    test(
      'should_have_no_private_MetraToggle_class',
      () => expect(src, isNot(contains('class _MetraToggle'))),
    );

    test(
      'should_have_no_private_CupertinoPickerScaffold_class',
      () => expect(src, isNot(contains('class _CupertinoPickerScaffold'))),
    );

    test(
      'should_import_public_SettingsRow_from_core_widgets',
      () => expect(
        src,
        contains(
          "import '../../core/widgets/settings/settings_row.dart'",
        ),
      ),
    );

    test(
      'should_import_public_MetraToggle_from_core_widgets',
      () => expect(
        src,
        contains(
          "import '../../core/widgets/settings/metra_toggle.dart'",
        ),
      ),
    );
  });

  // ──────────────────────────────────────────────────────────────────────────
  // C-2: Analyzer cleanliness — no orphan-import or dead-code warnings
  // ──────────────────────────────────────────────────────────────────────────
  group('Group C-2: flutter analyze reports zero migration-related warnings',
      () {
    test(
      'should_report_zero_unused_import_or_dead_code_warnings_for_settings_screen',
      () {
        // Locate the flutter binary.  In CI it is on PATH; locally it may live
        // in the Flutter SDK bin directory.  We try several candidates and skip
        // the test if none are found.
        final candidates = [
          'flutter',
          Platform.environment['FLUTTER_ROOT'] != null
              ? '${Platform.environment['FLUTTER_ROOT']}/bin/flutter'
              : null,
        ].whereType<String>().toList();

        ProcessResult? result;
        for (final candidate in candidates) {
          try {
            result = Process.runSync(
              candidate,
              ['analyze', 'lib/features/settings/settings_screen.dart'],
              workingDirectory: Directory.current.path,
              runInShell: true,
            );
            break; // success
          } catch (_) {
            // binary not found or not executable — try next candidate
          }
        }

        if (result == null) {
          markTestSkipped(
            'flutter binary not found on PATH — skipping C-2 analyzer check. '
            'Run manually: flutter analyze lib/features/settings/settings_screen.dart',
          );
          return;
        }

        final stdout = result.stdout as String;
        final stderr = result.stderr as String;
        final combined = '$stdout\n$stderr';

        // Filter to lines that reference settings_screen.dart specifically and
        // are about unused imports or dead code — the warnings TASK-12 was
        // meant to eliminate.
        final relevantWarnings = combined
            .split('\n')
            .where(
              (line) =>
                  line.contains('settings_screen.dart') &&
                  (line.contains('unused_import') ||
                      line.contains('dead_code') ||
                      line.contains("Unused import") ||
                      line.contains('is not used')),
            )
            .toList();

        expect(
          relevantWarnings,
          isEmpty,
          reason: 'flutter analyze found migration-related warnings in '
              'settings_screen.dart:\n${relevantWarnings.join('\n')}',
        );
      },
    );
  });

  // ──────────────────────────────────────────────────────────────────────────
  // C-3: SettingsRow backwards-compatibility smoke
  // ──────────────────────────────────────────────────────────────────────────
  //
  // Verifies that all five SettingsRow variants render correctly after the
  // TASK-12 promotion.  We check variant *identity* (structural widget type +
  // distinguishing widget descendant) rather than duplicating the label-text
  // assertions already covered by settings_screen_test.dart.
  //
  // Spec says "Calendario" and "Account staticInfo" — those rows do not exist
  // in the codebase (F-10 deferred; Account is a BackupConnectedView concept).
  // Deviation documented above.
  group('Group C-3: SettingsRow backwards-compatibility smoke', () {
    late _StubSettingsNotifier stub;

    setUp(() {
      stub = _StubSettingsNotifier(_defaults);
    });

    // Helper: pump with a very tall viewport so all rows are in the widget tree
    // without scrolling (uses same pattern as settings_screen_test.dart).
    Future<void> pumpFull(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _wrap([settingsNotifierProvider.overrideWith(() => stub)]),
      );
      await tester.pumpAndSettle();
    }

    // ── Nav rows ───────────────────────────────────────────────────────────

    testWidgets(
      'should_render_Lingua_as_nav_row_with_chevron_given_default_settings',
      (tester) async {
        await pumpFull(tester);

        // The row must exist by label
        expect(find.text('Lingua'), findsOneWidget);

        // It must carry a chevron icon — the structural marker for .nav
        // We narrow to the ancestor SettingsRow that contains the 'Lingua' text.
        final linguaRowFinder = find.ancestor(
          of: find.text('Lingua'),
          matching: find.byType(SettingsRow),
        );
        expect(linguaRowFinder, findsOneWidget);

        // Nav rows include a chevron icon in their trailing area.
        final chevronInLinguaRow = find.descendant(
          of: linguaRowFinder,
          matching: find.byIcon(Icons.chevron_right),
        );
        expect(
          chevronInLinguaRow,
          findsOneWidget,
          reason: 'Lingua SettingsRow must be a .nav variant (chevron present)',
        );
      },
    );

    testWidgets(
      'should_render_Preavviso_as_nav_row_with_chevron_given_notifications_enabled',
      (tester) async {
        await pumpFull(tester);

        expect(find.text('Preavviso'), findsOneWidget);

        final preavvisoRowFinder = find.ancestor(
          of: find.text('Preavviso'),
          matching: find.byType(SettingsRow),
        );
        expect(preavvisoRowFinder, findsOneWidget);

        final chevronInPreavvisoRow = find.descendant(
          of: preavvisoRowFinder,
          matching: find.byIcon(Icons.chevron_right),
        );
        expect(
          chevronInPreavvisoRow,
          findsOneWidget,
          reason:
              'Preavviso SettingsRow must be a .nav variant (chevron present)',
        );
      },
    );

    testWidgets(
      'should_render_OrarioNotifica_as_nav_row_with_chevron_given_notifications_enabled',
      (tester) async {
        await pumpFull(tester);

        expect(find.text('Orario notifica'), findsOneWidget);

        final orarioRowFinder = find.ancestor(
          of: find.text('Orario notifica'),
          matching: find.byType(SettingsRow),
        );
        expect(orarioRowFinder, findsOneWidget);

        final chevronInOrarioRow = find.descendant(
          of: orarioRowFinder,
          matching: find.byIcon(Icons.chevron_right),
        );
        expect(
          chevronInOrarioRow,
          findsOneWidget,
          reason:
              'Orario notifica SettingsRow must be a .nav variant (chevron present)',
        );
      },
    );

    // ── Toggle rows ────────────────────────────────────────────────────────

    testWidgets(
      'should_render_PromemorioCliCo_as_toggle_row_containing_MetraToggle_given_default_settings',
      (tester) async {
        await pumpFull(tester);

        // The notifications-enable row is labelled "Promemoria ciclo" in Italian
        // (ARB key: settings_notifications_label — NOT "Notifiche").
        expect(find.text('Promemoria ciclo'), findsOneWidget);

        final notificheRowFinder = find.ancestor(
          of: find.text('Promemoria ciclo'),
          matching: find.byType(SettingsRow),
        );
        expect(notificheRowFinder, findsOneWidget);

        // Toggle rows embed a MetraToggle as their trailing widget.
        final toggleInNotificheRow = find.descendant(
          of: notificheRowFinder,
          matching: find.byType(MetraToggle),
        );
        expect(
          toggleInNotificheRow,
          findsOneWidget,
          reason:
              'Promemoria ciclo SettingsRow must be a .toggle variant (MetraToggle present)',
        );
      },
    );

    testWidgets(
      'should_render_Dolore_as_toggle_row_containing_MetraToggle_given_default_settings',
      (tester) async {
        await pumpFull(tester);

        expect(find.text('Dolore'), findsOneWidget);

        final doloreRowFinder = find.ancestor(
          of: find.text('Dolore'),
          matching: find.byType(SettingsRow),
        );
        expect(doloreRowFinder, findsOneWidget);

        final toggleInDoloreRow = find.descendant(
          of: doloreRowFinder,
          matching: find.byType(MetraToggle),
        );
        expect(
          toggleInDoloreRow,
          findsOneWidget,
          reason:
              'Dolore SettingsRow must be a .toggle variant (MetraToggle present)',
        );
      },
    );

    testWidgets(
      'should_render_NoteGiornaliere_as_toggle_row_containing_MetraToggle_given_default_settings',
      (tester) async {
        await pumpFull(tester);

        expect(find.text('Note giornaliere'), findsOneWidget);

        final noteRowFinder = find.ancestor(
          of: find.text('Note giornaliere'),
          matching: find.byType(SettingsRow),
        );
        expect(noteRowFinder, findsOneWidget);

        final toggleInNoteRow = find.descendant(
          of: noteRowFinder,
          matching: find.byType(MetraToggle),
        );
        expect(
          toggleInNoteRow,
          findsOneWidget,
          reason:
              'Note giornaliere SettingsRow must be a .toggle variant (MetraToggle present)',
        );
      },
    );

    // ── Action rows ────────────────────────────────────────────────────────

    testWidgets(
      'should_render_EsportaCSV_as_action_row_without_chevron_or_toggle',
      (tester) async {
        await pumpFull(tester);

        expect(find.text('Esporta CSV'), findsOneWidget);

        final esportaRowFinder = find.ancestor(
          of: find.text('Esporta CSV'),
          matching: find.byType(SettingsRow),
        );
        expect(esportaRowFinder, findsOneWidget);

        // Action rows have no chevron and no MetraToggle — that is the
        // negative-space contract: this is an "action" row, not nav or toggle.
        final chevronInEsportaRow = find.descendant(
          of: esportaRowFinder,
          matching: find.byIcon(Icons.chevron_right),
        );
        expect(
          chevronInEsportaRow,
          findsNothing,
          reason:
              'Esporta CSV SettingsRow must be a .action variant (no chevron)',
        );

        final toggleInEsportaRow = find.descendant(
          of: esportaRowFinder,
          matching: find.byType(MetraToggle),
        );
        expect(
          toggleInEsportaRow,
          findsNothing,
          reason:
              'Esporta CSV SettingsRow must be a .action variant (no MetraToggle)',
        );
      },
    );

    // ── Destructive rows ───────────────────────────────────────────────────

    testWidgets(
      'should_render_EliminaTuttiIDati_as_destructive_row_without_chevron_or_toggle',
      (tester) async {
        await pumpFull(tester);

        expect(find.text('Elimina tutti i dati'), findsOneWidget);

        final deleteRowFinder = find.ancestor(
          of: find.text('Elimina tutti i dati'),
          matching: find.byType(SettingsRow),
        );
        expect(deleteRowFinder, findsOneWidget);

        // Destructive rows have no chevron and no MetraToggle.
        final chevronInDeleteRow = find.descendant(
          of: deleteRowFinder,
          matching: find.byIcon(Icons.chevron_right),
        );
        expect(
          chevronInDeleteRow,
          findsNothing,
          reason:
              'Elimina tutti i dati SettingsRow must be a .destructive variant (no chevron)',
        );

        final toggleInDeleteRow = find.descendant(
          of: deleteRowFinder,
          matching: find.byType(MetraToggle),
        );
        expect(
          toggleInDeleteRow,
          findsNothing,
          reason:
              'Elimina tutti i dati SettingsRow must be a .destructive variant (no MetraToggle)',
        );
      },
    );

    // ── Spec-deviation guard ───────────────────────────────────────────────
    // The spec §7.1 Group C mentions "Calendario toggle" and "Account staticInfo"
    // which do not exist.  These tests confirm their absence so that if those
    // rows are ever added back, the spec can be updated and these guards removed.

    testWidgets(
      'should_NOT_render_Calendario_toggle_given_F10_is_deferred',
      (tester) async {
        await pumpFull(tester);
        // F-10 was deferred 2026-04-29; no Calendario row must be present.
        expect(find.text('Calendario'), findsNothing);
      },
    );
  });
}
