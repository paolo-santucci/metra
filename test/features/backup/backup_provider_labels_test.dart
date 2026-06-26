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

// TASK-03 (M4) — backupProviderDisplayName helper unit tests.
//
// Verifies that backupProviderDisplayName correctly maps every SyncProvider
// member to its corresponding l10n getter (backupProviderName*) with a
// non-empty result, using an exhaustive switch (no default fallthrough).
//
// Uses AppLocalizationsIt directly (no widget pump needed) for isolation.
// All three SyncProvider members are tested to ensure exhaustiveness.

import 'package:flutter_test/flutter_test.dart';
import 'package:metra/domain/entities/sync_log_entity.dart';
import 'package:metra/features/backup/widgets/backup_provider_labels.dart';
import 'package:metra/l10n/app_localizations_it.dart';

void main() {
  late AppLocalizationsIt l10n;

  setUp(() {
    l10n = AppLocalizationsIt();
  });

  group('backupProviderDisplayName', () {
    test(
        'dropbox returns l10n.backupProviderNameDropbox and result is non-empty',
        () {
      final result = backupProviderDisplayName(l10n, SyncProvider.dropbox);
      expect(result, equals(l10n.backupProviderNameDropbox));
      expect(result, isNotEmpty);
    });

    test(
        'googleDrive returns l10n.backupProviderNameGoogleDrive and result is non-empty',
        () {
      final result = backupProviderDisplayName(l10n, SyncProvider.googleDrive);
      expect(result, equals(l10n.backupProviderNameGoogleDrive));
      expect(result, isNotEmpty);
    });

    test('iCloud returns l10n.backupProviderNameICloud and result is non-empty',
        () {
      final result = backupProviderDisplayName(l10n, SyncProvider.iCloud);
      expect(result, equals(l10n.backupProviderNameICloud));
      expect(result, isNotEmpty);
    });

    test(
        'exhaustiveness: all SyncProvider.values yield non-empty strings '
        '(no default/throw fallthrough)', () {
      for (final provider in SyncProvider.values) {
        final result = backupProviderDisplayName(l10n, provider);
        expect(
          result,
          isNotEmpty,
          reason: 'SyncProvider.$provider returned an empty string — '
              'exhaustive switch may be missing a case',
        );
      }
    });
  });
}
