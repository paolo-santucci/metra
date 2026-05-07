// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/data/services/backup/dropbox_provider.dart';
import 'package:metra/providers/backup_providers.dart';

import '../helpers/fake_dropbox_provider.dart';

void main() {
  group('cloudBackupProvider', () {
    test(
      'resolves to a CloudBackupProvider and can be overridden with FakeDropboxProvider',
      () {
        final fake = FakeDropboxProvider();
        final container = ProviderContainer(
          overrides: [cloudBackupProvider.overrideWithValue(fake)],
        );
        addTearDown(container.dispose);

        final result = container.read(cloudBackupProvider);

        expect(result, isA<CloudBackupProvider>());
        expect(result, same(fake));
      },
    );
  });
}
