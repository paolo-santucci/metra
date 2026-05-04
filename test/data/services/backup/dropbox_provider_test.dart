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

import 'dart:convert';
import 'dart:typed_data';

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

  test('listFiles returns sorted backup filenames newest first', () async {
    storage.values['metra_dropbox_access_token_v1'] = 'tok';
    final client = MockClient((req) async {
      return http.Response(
        jsonEncode({
          'entries': [
            {'.tag': 'file', 'name': 'metra_backup_20260428T100000Z.enc'},
            {'.tag': 'file', 'name': 'metra_backup_20260429T100000Z.enc'},
            {'.tag': 'file', 'name': 'unrelated.txt'},
          ],
        }),
        200,
      );
    });
    final p = DropboxProvider(appKey: 'key', storage: storage, client: client);
    final files = await p.listFiles();
    expect(files, [
      'metra_backup_20260429T100000Z.enc',
      'metra_backup_20260428T100000Z.enc',
    ]);
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
}
