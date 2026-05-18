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

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:metra/core/errors/metra_exception.dart';
import 'package:metra/data/services/backup/dropbox_provider.dart';

import '../../../helpers/in_memory_secure_storage.dart';

void main() {
  late InMemorySecureStorage storage;

  setUp(() {
    storage = InMemorySecureStorage();
  });

  // ---------------------------------------------------------------------------
  // Group A — InsufficientStorageException type contract
  // ---------------------------------------------------------------------------

  group('InsufficientStorageException', () {
    test('constructor sets statusCode == 507 and message == ARB key', () {
      const e = InsufficientStorageException();
      expect(e.statusCode, 507);
      expect(e.message, 'backup_error_storage_full');
    });

    test('is SyncException == true; is MetraException == true', () {
      const e = InsufficientStorageException();
      // Use isA<> matcher to check type hierarchy without triggering the
      // unnecessary_type_check lint (which fires on `e is T` when T is a
      // supertype guaranteed by the class hierarchy at compile time).
      expect(e, isA<SyncException>());
      expect(e, isA<MetraException>());
    });
  });

  // ---------------------------------------------------------------------------
  // Group B — DropboxProvider.upload 507 discrimination
  // ---------------------------------------------------------------------------

  group('DropboxProvider.upload 507 discrimination', () {
    late Uint8List blob;

    setUp(() {
      storage.values['metra_dropbox_access_token_v1'] = 'tok';
      blob = Uint8List.fromList([1, 2, 3]);
    });

    test(
        'status 507 → throws InsufficientStorageException, not generic SyncException',
        () async {
      final client = MockClient((_) async => http.Response('', 507));
      final provider =
          DropboxProvider(appKey: 'key', storage: storage, client: client);
      await expectLater(
        () => provider.upload(blob, 'metra-backup-2026.enc'),
        throwsA(isA<InsufficientStorageException>()),
      );
    });

    test(
        'status 503 → throws SyncException but NOT InsufficientStorageException',
        () async {
      final client = MockClient((_) async => http.Response('', 503));
      final provider =
          DropboxProvider(appKey: 'key', storage: storage, client: client);
      await expectLater(
        () => provider.upload(blob, 'metra-backup-2026.enc'),
        throwsA(
          allOf(
            isA<SyncException>(),
            isNot(isA<InsufficientStorageException>()),
          ),
        ),
      );
    });

    test('status 200 → completes without throwing', () async {
      final client = MockClient((_) async => http.Response('{}', 200));
      final provider =
          DropboxProvider(appKey: 'key', storage: storage, client: client);
      await provider.upload(blob, 'metra-backup-2026.enc');
    });
  });

  test('upload sends bearer token and correct Dropbox-API-Arg', () async {
    storage.values['metra_dropbox_access_token_v1'] = 'tok';
    final calls = <http.Request>[];
    final client = MockClient((req) async {
      calls.add(req);
      return http.Response('{}', 200);
    });
    final p = DropboxProvider(appKey: 'key', storage: storage, client: client);
    await p.upload(Uint8List.fromList([1, 2, 3]), 'metra_backup_x.enc');
    expect(calls, hasLength(1));
    expect(calls.single.headers['Authorization'], 'Bearer tok');
    final arg = jsonDecode(calls.single.headers['Dropbox-API-Arg']!)
        as Map<String, dynamic>;
    expect(arg['path'], '/metra_backup_x.enc');
    expect(calls.single.bodyBytes, [1, 2, 3]);
  });

  // FR-14b — listFiles returns metadata-bearing entries (TASK-13)
  test('FR-14b — listFiles returns metadata-bearing entries', () async {
    storage.values['metra_dropbox_access_token_v1'] = 'tok';
    const fixture = '{"entries":['
        '{"name":"metra_backup_20260517T120000Z_abc123.enc",'
        '"server_modified":"2026-05-17T12:00:01Z","size":4096},'
        '{"name":"metra_backup_20260516T120000Z_def456.enc",'
        '"server_modified":"2026-05-16T12:00:01Z","size":2048},'
        '{"name":"metra_backup_20260515T120000Z.enc",'
        '"server_modified":"2026-05-15T12:00:01Z","size":1024},'
        '{"name":"unrelated.txt","server_modified":"2026-05-14T12:00:01Z","size":512}'
        ']}';
    final client = MockClient(
      (req) async => http.Response(fixture, 200),
    );
    final p = DropboxProvider(appKey: 'key', storage: storage, client: client);
    final entries = await p.listFiles();

    expect(entries, hasLength(3));
    // Sorted descending by name — newest first.
    expect(entries[0].name, 'metra_backup_20260517T120000Z_abc123.enc');
    expect(
      entries[0].timestampUtc,
      DateTime.utc(2026, 5, 17, 12, 0, 1),
    );
    expect(entries[0].sizeBytes, 4096);

    expect(entries[1].name, 'metra_backup_20260516T120000Z_def456.enc');
    expect(
      entries[1].timestampUtc,
      DateTime.utc(2026, 5, 16, 12, 0, 1),
    );
    expect(entries[1].sizeBytes, 2048);

    expect(entries[2].name, 'metra_backup_20260515T120000Z.enc');
    expect(
      entries[2].timestampUtc,
      DateTime.utc(2026, 5, 15, 12, 0, 1),
    );
    expect(entries[2].sizeBytes, 1024);
  });

  // EC-05 / §5.1.5 — HTTP 401 throws SyncException without partial construction
  test('listFiles HTTP 401 throws SyncException without partial construction',
      () async {
    // No refresh token — _refreshAccessToken throws SyncException immediately.
    storage.values['metra_dropbox_access_token_v1'] = 'expired';
    var entryConstructed = false;
    final client = MockClient((req) async {
      if (req.url.path.contains('/oauth2/token')) {
        return http.Response('', 500); // refresh fails → SyncException
      }
      if (!entryConstructed) {
        entryConstructed = true;
      }
      return http.Response('Unauthorized', 401);
    });
    final p = DropboxProvider(appKey: 'key', storage: storage, client: client);
    expect(p.listFiles(), throwsA(isA<SyncException>()));
    expect(entryConstructed, isFalse);
  });

  test('listFiles returns [] on 409 path/not_found', () async {
    storage.values['metra_dropbox_access_token_v1'] = 'tok';
    final client = MockClient((req) async => http.Response('{}', 409));
    final p = DropboxProvider(appKey: 'key', storage: storage, client: client);
    expect(await p.listFiles(), isEmpty);
  });

  test('401 triggers token refresh and retries once', () async {
    storage.values['metra_dropbox_access_token_v1'] = 'expired';
    storage.values['metra_dropbox_refresh_token_v1'] = 'r';
    var callCount = 0;
    final client = MockClient((req) async {
      callCount++;
      if (req.url.path == '/oauth2/token') {
        return http.Response(jsonEncode({'access_token': 'new'}), 200);
      }
      if (callCount == 1) return http.Response('Unauthorized', 401);
      return http.Response('{}', 200);
    });
    final p = DropboxProvider(appKey: 'key', storage: storage, client: client);
    await p.upload(Uint8List.fromList([1]), 'metra_backup_x.enc');
    expect(storage.values['metra_dropbox_access_token_v1'], 'new');
  });

  test('isConnected reflects token presence', () async {
    final p = DropboxProvider(appKey: 'key', storage: storage);
    expect(await p.isConnected, isFalse);
    storage.values['metra_dropbox_access_token_v1'] = 't';
    expect(await p.isConnected, isTrue);
  });

  test('disconnect clears both tokens from storage', () async {
    storage.values['metra_dropbox_access_token_v1'] = 't';
    storage.values['metra_dropbox_refresh_token_v1'] = 'r';
    final client = MockClient((_) async => http.Response('{}', 200));
    final p = DropboxProvider(appKey: 'key', storage: storage, client: client);
    await p.disconnect();
    expect(
      storage.values.containsKey('metra_dropbox_access_token_v1'),
      isFalse,
    );
    expect(
      storage.values.containsKey('metra_dropbox_refresh_token_v1'),
      isFalse,
    );
  });

  test('throws SyncException when not connected', () async {
    final p = DropboxProvider(appKey: 'key', storage: storage);
    expect(
      () => p.upload(Uint8List.fromList([1]), 'x.enc'),
      throwsA(isA<SyncException>()),
    );
  });

  // BUG-C03 / FR-10 / NFR-05 / EC-12
  group('OAuth timeout (BUG-C03)', () {
    test(
      'authorize() throws SyncException after 5 minutes when _webAuth never resolves',
      () {
        fakeAsync((fake) {
          final p = DropboxProvider(
            appKey: 'key',
            storage: storage,
            webAuth: (url, {required callbackUrlScheme}) =>
                Completer<String>().future, // never completes
          );

          SyncException? caught;
          p.authorize().then((_) {}).catchError((Object e) {
            caught = e as SyncException;
          });

          // Advance the fake clock past the 5-minute threshold.
          fake.elapse(const Duration(minutes: 5));

          expect(caught, isNotNull);
          expect(caught, isA<SyncException>());
          expect(
            caught!.message,
            'OAuth timed out — please try again',
          );
        });
      },
    );

    test(
      'authorize() succeeds when _webAuth resolves within 5 minutes',
      () async {
        // The token-exchange HTTP mock must also handle the POST.
        final client = MockClient((req) async {
          if (req.url.path == '/oauth2/token') {
            return http.Response(
              jsonEncode({
                'access_token': 'access-tok',
                'refresh_token': 'refresh-tok',
              }),
              200,
            );
          }
          return http.Response('{}', 200);
        });

        final p = DropboxProvider(
          appKey: 'key',
          storage: storage,
          client: client,
          // Capture the state from the auth URL so CSRF check passes.
          webAuth: (url, {required callbackUrlScheme}) async {
            final state = Uri.parse(url).queryParameters['state']!;
            return 'metra://oauth-callback?code=abc&state=$state';
          },
        );

        // Must not throw — no timeout, no SyncException.
        await expectLater(p.authorize(), completes);

        // Happy-path: tokens written to storage.
        expect(
          storage.values['metra_dropbox_access_token_v1'],
          'access-tok',
        );
        expect(
          storage.values['metra_dropbox_refresh_token_v1'],
          'refresh-tok',
        );
      },
    );
  });
}
