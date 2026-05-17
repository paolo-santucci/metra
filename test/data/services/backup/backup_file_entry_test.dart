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

import 'package:flutter_test/flutter_test.dart';
import 'package:metra/data/services/backup/backup_file_entry.dart';

import '../../../helpers/fake_dropbox_provider.dart';

void main() {
  group('BackupFileEntry', () {
    test('equality is value-based on all three fields', () {
      final t = DateTime.utc(2026, 5, 17, 12);
      final a = BackupFileEntry(
        name: 'metra_backup_20260517T120000Z_abc123.enc',
        timestampUtc: t,
        sizeBytes: 4096,
      );
      final b = BackupFileEntry(
        name: 'metra_backup_20260517T120000Z_abc123.enc',
        timestampUtc: t,
        sizeBytes: 4096,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect({a, b}.length, equals(1));
    });

    test('inequality on sizeBytes', () {
      final t = DateTime.utc(2026, 5, 17, 12);
      final a =
          BackupFileEntry(name: 'x.enc', timestampUtc: t, sizeBytes: 4096);
      final b =
          BackupFileEntry(name: 'x.enc', timestampUtc: t, sizeBytes: 8192);
      expect(a, isNot(equals(b)));
    });

    test('inequality on name', () {
      final t = DateTime.utc(2026, 5, 17, 12);
      final a =
          BackupFileEntry(name: 'a.enc', timestampUtc: t, sizeBytes: 1024);
      final b =
          BackupFileEntry(name: 'b.enc', timestampUtc: t, sizeBytes: 1024);
      expect(a, isNot(equals(b)));
    });

    test('inequality on timestampUtc', () {
      final a = BackupFileEntry(
        name: 'x.enc',
        timestampUtc: DateTime.utc(2026, 5, 17, 12),
        sizeBytes: 1024,
      );
      final b = BackupFileEntry(
        name: 'x.enc',
        timestampUtc: DateTime.utc(2026, 5, 17, 13),
        sizeBytes: 1024,
      );
      expect(a, isNot(equals(b)));
    });
  });

  group('FakeDropboxProvider.listFiles', () {
    test('returns List<BackupFileEntry>', () async {
      final fake = FakeDropboxProvider(
        seedEntries: [
          BackupFileEntry(
            name: 'x.enc',
            timestampUtc: DateTime.utc(2026),
            sizeBytes: 1,
          ),
        ],
      );
      final result = await fake.listFiles();
      expect(result, isA<List<BackupFileEntry>>());
      expect(result.length, equals(1));
    });

    test('returns empty list when no seed entries provided', () async {
      final fake = FakeDropboxProvider();
      final result = await fake.listFiles();
      expect(result, isA<List<BackupFileEntry>>());
      expect(result, isEmpty);
    });

    test('listFiles returns seed entries in insertion order', () async {
      final t1 = DateTime.utc(2026, 5, 17, 10);
      final t2 = DateTime.utc(2026, 5, 17, 11);
      final e1 =
          BackupFileEntry(name: 'a.enc', timestampUtc: t1, sizeBytes: 100);
      final e2 =
          BackupFileEntry(name: 'b.enc', timestampUtc: t2, sizeBytes: 200);
      final fake = FakeDropboxProvider(seedEntries: [e1, e2]);
      final result = await fake.listFiles();
      expect(result, equals([e1, e2]));
    });
  });
}
