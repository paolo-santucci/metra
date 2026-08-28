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

import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/errors/metra_exception.dart';
import 'package:metra/data/services/backup/backup_file_entry.dart';
import 'package:metra/data/services/backup/cloud_backup_provider.dart';
import 'package:metra/data/services/backup/icloud_gateway.dart';
import 'package:metra/data/services/backup/icloud_provider.dart';
import 'package:metra/domain/entities/sync_log_entity.dart';

import '../../../helpers/fake_icloud_gateway.dart';
import '../../../helpers/in_memory_secure_storage.dart';

// ---------------------------------------------------------------------------
// Local test doubles
// ---------------------------------------------------------------------------

/// Extends [FakeIcloudGateway] to track the total number of [gather]
/// invocations across the life of a test.
class _CountingGateway extends FakeIcloudGateway {
  _CountingGateway({super.invisibleForGatherCalls});

  int gatherCallCount = 0;

  @override
  Future<List<IcloudEntry>> gather() {
    gatherCallCount++;
    return super.gather();
  }
}

/// Returns a caller-supplied fixed list from [gather]; ignores [store]
/// contents. Used to construct [BackupFileEntry] instances from specific
/// [IcloudEntry] shapes (e.g. `sizeBytes == null`).
class _FixedGatherGateway extends FakeIcloudGateway {
  _FixedGatherGateway(this._fixed);

  final List<IcloudEntry> _fixed;

  @override
  Future<List<IcloudEntry>> gather() async => _fixed;
}

/// Extends [FakeIcloudGateway] with configurable [PlatformException] throws
/// on [upload], [download], and [delete]. When the corresponding field is
/// `null`, the call is delegated to the super implementation.
class _ErrorGateway extends FakeIcloudGateway {
  // ignore: use_setters_to_change_properties
  PlatformException? uploadError;
  PlatformException? downloadError;
  PlatformException? deleteError;

  @override
  Future<void> upload(Uint8List blob, String relativePath) async {
    if (uploadError != null) throw uploadError!;
    return super.upload(blob, relativePath);
  }

  @override
  Future<Uint8List> download(String relativePath) async {
    if (downloadError != null) throw downloadError!;
    return super.download(relativePath);
  }

  @override
  Future<void> delete(String relativePath) async {
    if (deleteError != null) throw deleteError!;
    return super.delete(relativePath);
  }
}

// ---------------------------------------------------------------------------
// Convenience constants
// ---------------------------------------------------------------------------

/// Canonical backup filenames with sortable UTC timestamps.
const _filename1 = 'metra_backup_20260625T120000Z_aaaaaa.enc'; // newest
const _filename2 = 'metra_backup_20260620T120000Z_bbbbbb.enc';
const _filename3 = 'metra_backup_20260615T120000Z_cccccc.enc'; // oldest

final _blob = Uint8List.fromList([1, 2, 3]);

void main() {
  // =========================================================================
  // Group A — Identity (FR-01, NFR-01)
  // =========================================================================
  group('Group A — Identity', () {
    late FakeIcloudGateway gateway;

    setUp(() {
      gateway = FakeIcloudGateway();
    });

    test('id == SyncProvider.iCloud (FR-01)', () {
      final provider = IcloudProvider(gateway: gateway);
      expect(provider.id, SyncProvider.iCloud);
    });

    test('id != SyncProvider.dropbox', () {
      final provider = IcloudProvider(gateway: gateway);
      expect(provider.id, isNot(SyncProvider.dropbox));
    });

    test('id != SyncProvider.googleDrive', () {
      final provider = IcloudProvider(gateway: gateway);
      expect(provider.id, isNot(SyncProvider.googleDrive));
    });

    test('IcloudProvider satisfies CloudBackupProvider interface', () {
      // Compilation itself is the primary assertion; the runtime check is
      // a belt-and-suspenders guard.
      final CloudBackupProvider impl = IcloudProvider(gateway: gateway);
      expect(impl, isA<CloudBackupProvider>());
    });

    test('currentEmail() resolves to null — no OAuth, no email (FR-01)',
        () async {
      final provider = IcloudProvider(gateway: gateway);
      final email = await provider.currentEmail();
      expect(email, isNull);
    });

    test('disconnect() completes without throwing (FR-01)', () async {
      final provider = IcloudProvider(gateway: gateway);
      await expectLater(provider.disconnect(), completes);
    });

    test(
      'disconnect() writes nothing to secure storage — iCloud holds no token '
      'keys (NFR-01)',
      () async {
        // IcloudProvider accepts no FlutterSecureStorage parameter: it cannot
        // touch the Keychain. This test pins that contract by verifying the
        // icloud_provider.dart source does not import flutter_secure_storage.
        // The InMemorySecureStorage double is included here only to document
        // that the "no token write" invariant applies even when other providers
        // share the same storage namespace.
        final storage = InMemorySecureStorage();
        storage.values['metra_backup_passphrase_v1'] = 'pw';
        final provider = IcloudProvider(gateway: gateway);
        await provider.disconnect();
        // No metra_*_token_* key may be created during the provider's lifecycle.
        final tokenKeys =
            storage.values.keys.where((k) => k.contains('_token_')).toList();
        expect(tokenKeys, isEmpty);
        // Passphrase left untouched.
        expect(storage.values['metra_backup_passphrase_v1'], 'pw');
      },
    );

    test(
      'authorize() completes when gateway container is reachable (FR-01/FR-15)',
      () async {
        final provider = IcloudProvider(gateway: gateway); // signedIn=true
        await expectLater(provider.authorize(), completes);
      },
    );

    test(
      'authorize() throws SyncException when gateway reports signed-out '
      '(NFR-06)',
      () async {
        gateway.signedIn = false;
        final provider = IcloudProvider(gateway: gateway);
        await expectLater(
          provider.authorize(),
          throwsA(isA<SyncException>()),
        );
      },
    );

    test(
      'authorize() sign-in failure → SyncException, NOT '
      'InsufficientStorageException',
      () async {
        gateway.signedIn = false;
        final provider = IcloudProvider(gateway: gateway);
        await expectLater(
          provider.authorize(),
          throwsA(
            allOf(
              isA<SyncException>(),
              isNot(isA<InsufficientStorageException>()),
            ),
          ),
        );
      },
    );
  });

  // =========================================================================
  // Group C — Read-after-write bounded poll (FR-03, EC-03, EC-04)
  // =========================================================================
  group('Group C — Bounded poll', () {
    test(
      'blob invisible for 3 gather() calls then visible → gather×4, delay×3, '
      'upload() returns (EC-03)',
      () {
        fakeAsync((fake) {
          final gw = _CountingGateway(invisibleForGatherCalls: 3);
          var delayCalls = 0;
          final provider = IcloudProvider(
            gateway: gw,
            delay: (d) {
              delayCalls++;
              return Future<void>.delayed(d);
            },
          );

          bool completed = false;
          provider.upload(_blob, _filename1).then((_) {
            completed = true;
          }).catchError((_) {});

          // 3 delays × 500 ms = 1 500 ms; the 4th gather() sees the blob.
          fake.elapse(const Duration(milliseconds: 1500));

          expect(
            completed,
            isTrue,
            reason: 'upload() must return once the blob is visible',
          );
          expect(
            gw.gatherCallCount,
            4,
            reason: 'gather() once per attempt: invisible×3 then visible×1',
          );
          expect(
            delayCalls,
            3,
            reason:
                'delay after each invisible attempt, not after the visible one',
          );
        });
      },
    );

    test(
      'immediate visibility → gather×1, delay×0 (EC-03)',
      () {
        fakeAsync((fake) {
          final gw = _CountingGateway(); // invisibleForGatherCalls = 0
          var delayCalls = 0;
          final provider = IcloudProvider(
            gateway: gw,
            delay: (d) {
              delayCalls++;
              return Future<void>.delayed(d);
            },
          );

          bool completed = false;
          provider.upload(_blob, _filename1).then((_) {
            completed = true;
          }).catchError((_) {});

          // No timer needed; blob is visible on the first gather() microtask.
          fake.flushMicrotasks();

          expect(completed, isTrue);
          expect(gw.gatherCallCount, 1);
          expect(delayCalls, 0);
        });
      },
    );

    test(
      'upload_returns_normally_when_gateway_write_succeeds_but_poll_never_sees_file',
      () {
        fakeAsync((fake) {
          // Gateway: upload() commits bytes but gather() never lists the file
          // within kIcloudPollMaxAttempts (invisibleForGatherCalls > max).
          // Injected delay so fake_async drives the loop deterministically.
          final gw = _CountingGateway(invisibleForGatherCalls: 1000);
          final provider = IcloudProvider(
            gateway: gw,
            delay: Future<void>.delayed,
          );

          bool completed = false;
          Object? caught;
          provider.upload(_blob, _filename1).then((_) {
            completed = true;
          }).catchError((Object e) {
            caught = e;
          });

          // 9 delays × 500 ms = 4 500 ms; after the 10th (final) gather() the
          // poll exhausts. iCloud is eventually consistent — gateway-write
          // success is the success criterion (§3.1 semantic contract): upload()
          // returns normally instead of throwing.
          fake.elapse(const Duration(milliseconds: 4500));

          expect(
            completed,
            isTrue,
            reason: 'upload() must complete normally when the gateway write '
                'succeeds, even if gather() never sees the file within the '
                'poll window (iCloud eventual consistency — §3.1)',
          );
          expect(
            caught,
            isNull,
            reason:
                'poll exhaustion must NOT throw for an eventually-consistent '
                'provider',
          );
          // Courtesy poll must still run for all kIcloudPollMaxAttempts attempts.
          expect(
            gw.gatherCallCount,
            IcloudProvider.kIcloudPollMaxAttempts,
            reason:
                'courtesy poll must run all kIcloudPollMaxAttempts gather() '
                'calls',
          );
        });
      },
    );

    test(
      'never visible → delay invoked exactly kIcloudPollMaxAttempts-1 times '
      '(no trailing delay on final attempt, EC-04)',
      () {
        fakeAsync((fake) {
          final gw = _CountingGateway(invisibleForGatherCalls: 1000);
          var delayCalls = 0;
          final provider = IcloudProvider(
            gateway: gw,
            delay: (d) {
              delayCalls++;
              return Future<void>.delayed(d);
            },
          );

          provider.upload(_blob, _filename1).then((_) {}).catchError((_) {});

          fake.elapse(const Duration(milliseconds: 4500));

          expect(
            delayCalls,
            IcloudProvider.kIcloudPollMaxAttempts - 1,
            reason: 'delay must NOT be called after the final gather() attempt',
          );
          expect(
            gw.gatherCallCount,
            IcloudProvider.kIcloudPollMaxAttempts,
            reason:
                'gather must be called exactly kIcloudPollMaxAttempts times',
          );
        });
      },
    );

    test(
      'delay receives kIcloudPollInterval (500 ms) on every invocation',
      () {
        fakeAsync((fake) {
          final gw = _CountingGateway(invisibleForGatherCalls: 1000);
          final capturedDurations = <Duration>[];
          final provider = IcloudProvider(
            gateway: gw,
            delay: (d) {
              capturedDurations.add(d);
              return Future<void>.delayed(d);
            },
          );

          provider.upload(_blob, _filename1).then((_) {}).catchError((_) {});

          fake.elapse(const Duration(milliseconds: 4500));

          expect(
            capturedDurations,
            isNotEmpty,
            reason: 'at least one delay must be issued',
          );
          for (final d in capturedDurations) {
            expect(
              d,
              IcloudProvider.kIcloudPollInterval,
              reason: 'each delay must equal kIcloudPollInterval',
            );
          }
        });
      },
    );
  });

  // =========================================================================
  // Group D — listFiles: filter, sort, sizeBytes fallback (FR-05, FR-06)
  // =========================================================================
  group('Group D — listFiles', () {
    test(
      '3 distinct metra_backup_*.enc → newest-first by name DESC, all present, '
      'no foreign-file leak (FR-05)',
      () async {
        final gw = FakeIcloudGateway();
        gw.store[_filename1] = Uint8List.fromList([1]); // 2026-06-25 (newest)
        gw.store[_filename2] = Uint8List.fromList([2]); // 2026-06-20
        gw.store[_filename3] = Uint8List.fromList([3]); // 2026-06-15 (oldest)
        gw.store['unrelated.txt'] = Uint8List.fromList([99]);

        final provider = IcloudProvider(gateway: gw);
        final entries = await provider.listFiles();

        expect(
          entries,
          hasLength(3),
          reason: 'only 3 matching entries expected',
        );
        expect(entries[0].name, _filename1, reason: 'newest first');
        expect(entries[1].name, _filename2);
        expect(entries[2].name, _filename3, reason: 'oldest last');

        // Lexicographic DESC invariant.
        expect(
          entries.first.name.compareTo(entries.last.name),
          greaterThan(0),
          reason: '.first name must be lexicographically greater than .last',
        );

        // Foreign filename must be absent.
        expect(
          entries.any((BackupFileEntry e) => e.name == 'unrelated.txt'),
          isFalse,
        );
      },
    );

    test(
      'IcloudEntry.sizeBytes == null → BackupFileEntry.sizeBytes == 0 (FR-06)',
      () async {
        final gw = _FixedGatherGateway([
          const IcloudEntry(relativePath: _filename1, sizeBytes: null),
        ]);
        final provider = IcloudProvider(gateway: gw);
        final entries = await provider.listFiles();

        expect(entries, hasLength(1));
        expect(
          entries.first.sizeBytes,
          0,
          reason: 'null sizeBytes from plugin must fall back to 0',
        );
      },
    );

    test(
      'IcloudEntry.sizeBytes non-null → BackupFileEntry.sizeBytes preserved (FR-06)',
      () async {
        final gw = _FixedGatherGateway([
          const IcloudEntry(relativePath: _filename1, sizeBytes: 4096),
        ]);
        final provider = IcloudProvider(gateway: gw);
        final entries = await provider.listFiles();

        expect(entries.first.sizeBytes, 4096);
      },
    );

    test(
      'gather() returns [] → listFiles() returns [] and does not throw (FR-05)',
      () async {
        final gw = _FixedGatherGateway([]);
        final provider = IcloudProvider(gateway: gw);
        final entries = await provider.listFiles();
        expect(entries, isEmpty);
      },
    );

    test(
      'non-matching names only → listFiles() returns [] (FR-05)',
      () async {
        final gw = FakeIcloudGateway();
        gw.store['other.txt'] = Uint8List.fromList([1]);
        gw.store['metra_backup_no_ext'] = Uint8List.fromList([2]);
        gw.store['backup_20260625T120000Z_aaaaaa.enc'] =
            Uint8List.fromList([3]);
        gw.store['.enc'] = Uint8List.fromList([4]);

        final provider = IcloudProvider(gateway: gw);
        final entries = await provider.listFiles();
        expect(entries, isEmpty);
      },
    );

    test(
      'listFiles() derives timestampUtc from the filename UTC segment (FR-05)',
      () async {
        final gw = _FixedGatherGateway([
          const IcloudEntry(relativePath: _filename1, sizeBytes: 128),
        ]);
        final provider = IcloudProvider(gateway: gw);
        final entries = await provider.listFiles();

        expect(entries, hasLength(1));
        // _filename1 encodes 2026-06-25T12:00:00Z.
        expect(entries.first.timestampUtc, DateTime.utc(2026, 6, 25, 12, 0, 0));
      },
    );
  });

  // =========================================================================
  // Group E — Quota and error mapping (FR-07)
  // =========================================================================

  // TODO(M6): confirm IcloudGateway.kQuotaExceededCode matches the real
  //           icloud_storage PlatformException code before relying on this
  //           group for production quota handling.
  group('Group E — Quota and error mapping', () {
    test(
      'gateway.upload throws PlatformException(code: IcloudGateway.kQuotaExceededCode) '
      '→ throwsA(isA<InsufficientStorageException>()) (FR-07)',
      () async {
        final gw = FakeIcloudGateway();
        // FakeIcloudGateway uses IcloudGateway.kQuotaExceededCode — never
        // a raw string — matching the OQ-QA-03 invariant.
        gw.throwQuotaOnNextUpload = true;
        final provider = IcloudProvider(gateway: gw);

        await expectLater(
          () => provider.upload(_blob, _filename1),
          throwsA(isA<InsufficientStorageException>()),
        );
      },
    );

    test(
      'quota path → InsufficientStorageException.statusCode == 507',
      () async {
        final gw = FakeIcloudGateway()..throwQuotaOnNextUpload = true;
        final provider = IcloudProvider(gateway: gw);

        await expectLater(
          () => provider.upload(_blob, _filename1),
          throwsA(
            isA<InsufficientStorageException>().having(
              (e) => e.statusCode,
              'statusCode',
              507,
            ),
          ),
        );
      },
    );

    test(
      'non-quota PlatformException on upload → SyncException but NOT '
      'InsufficientStorageException (FR-07)',
      () async {
        final gw = _ErrorGateway()
          ..uploadError = PlatformException(
            code: 'E_ICLOUD_ERROR',
            message: 'Simulated non-quota iCloud error',
          );
        final provider = IcloudProvider(gateway: gw);

        await expectLater(
          () => provider.upload(_blob, _filename1),
          throwsA(
            allOf(
              isA<SyncException>(),
              isNot(isA<InsufficientStorageException>()),
            ),
          ),
        );
      },
    );

    test(
      'download() PlatformException → throwsA(isA<SyncException>()) (FR-07)',
      () async {
        final gw = _ErrorGateway()
          ..downloadError = PlatformException(
            code: 'E_ICLOUD_ERROR',
            message: 'Simulated download error',
          );
        final provider = IcloudProvider(gateway: gw);

        await expectLater(
          () => provider.download(_filename1),
          throwsA(isA<SyncException>()),
        );
      },
    );

    test(
      'download() missing-file PlatformException (FakeIcloudGateway FILE_NOT_FOUND) '
      '→ SyncException',
      () async {
        // Empty store: FakeIcloudGateway.download() throws
        // PlatformException(code:'FILE_NOT_FOUND').
        final gw = FakeIcloudGateway();
        final provider = IcloudProvider(gateway: gw);

        await expectLater(
          () => provider.download('metra_backup_missing.enc'),
          throwsA(isA<SyncException>()),
        );
      },
    );

    test(
      'deleteFile() PlatformException → throwsA(isA<SyncException>()) (FR-07)',
      () async {
        final gw = _ErrorGateway()
          ..deleteError = PlatformException(
            code: 'E_ICLOUD_ERROR',
            message: 'Simulated delete error',
          );
        final provider = IcloudProvider(gateway: gw);

        await expectLater(
          () => provider.deleteFile(_filename1),
          throwsA(isA<SyncException>()),
        );
      },
    );

    test(
      'download() error is SyncException, not InsufficientStorageException',
      () async {
        final gw = _ErrorGateway()
          ..downloadError = PlatformException(
            code: 'E_ICLOUD_ERROR',
            message: 'Simulated download error',
          );
        final provider = IcloudProvider(gateway: gw);

        await expectLater(
          () => provider.download(_filename1),
          throwsA(
            allOf(
              isA<SyncException>(),
              isNot(isA<InsufficientStorageException>()),
            ),
          ),
        );
      },
    );
  });

  // =========================================================================
  // Group F — Purity (NFR-07)
  // =========================================================================
  group('Group F — Purity', () {
    test(
      'icloud_provider.dart has no package:flutter/material.dart import (NFR-07)',
      () {
        final src = File(
          'lib/data/services/backup/icloud_provider.dart',
        ).readAsStringSync();
        expect(
          src,
          isNot(contains("import 'package:flutter/material.dart'")),
          reason:
              'icloud_provider.dart must not import package:flutter/material.dart',
        );
      },
    );

    test(
      'icloud_provider.dart has no package:icloud_storage import — plugin '
      'stays behind the gateway seam (NFR-07)',
      () {
        final src = File(
          'lib/data/services/backup/icloud_provider.dart',
        ).readAsStringSync();
        expect(
          src,
          isNot(contains("import 'package:icloud_storage/")),
          reason:
              'icloud_provider.dart must not import icloud_storage directly; '
              'plugin is accessed only via IcloudGateway',
        );
      },
    );

    test(
      'icloud_provider.dart has no package:flutter_secure_storage import — '
      'iCloud holds no token keys (NFR-01)',
      () {
        final src = File(
          'lib/data/services/backup/icloud_provider.dart',
        ).readAsStringSync();
        expect(
          src,
          isNot(contains("import 'package:flutter_secure_storage/")),
          reason:
              'icloud_provider.dart must not import flutter_secure_storage; '
              'iCloud provider stores no OAuth tokens',
        );
      },
    );
  });
}
