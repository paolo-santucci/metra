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
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:metra/core/errors/metra_exception.dart';
import 'package:metra/data/services/backup/backup_file_entry.dart';
import 'package:metra/data/services/backup/cloud_backup_provider.dart';
import 'package:metra/data/services/backup/google_drive_provider.dart';
import 'package:metra/domain/entities/sync_log_entity.dart';

import '../../../helpers/in_memory_secure_storage.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds the minimal folder-list response for a resolved Metra folder.
Map<String, dynamic> folderListResponse(String folderId) => {
      'files': [
        {'id': folderId, 'name': 'Metra'},
      ],
    };

/// Builds the folder-list response for an absent Metra folder.
Map<String, dynamic> emptyFolderListResponse() => {'files': <dynamic>[]};

/// Builds a minimal file-create response (folder or file).
Map<String, dynamic> createResponse(String id, String name) => {
      'id': id,
      'name': name,
    };

/// Builds a Drive files.list response with the provided file entries.
/// Each entry is `{id, name, modifiedTime, size}`.
String filesListJson(List<Map<String, dynamic>> files) =>
    jsonEncode({'files': files});

/// Encodes a minimal JWT with the given email in the payload (no signature).
/// The implementation is expected to base64url-decode the middle segment.
String fakeIdToken(String email) {
  final header = base64Url.encode(utf8.encode(jsonEncode({'alg': 'none'})));
  final payload = base64Url.encode(
    utf8.encode(jsonEncode({'email': email, 'sub': '12345'})),
  );
  return '$header.$payload.fakesignature';
}

// ---------------------------------------------------------------------------
// Shared key constants
// ---------------------------------------------------------------------------

const accessTokenKey = 'metra_google_drive_access_token_v1';
const refreshTokenKey = 'metra_google_drive_refresh_token_v1';
const dropboxAccessKey = 'metra_dropbox_access_token_v1';
const dropboxRefreshKey = 'metra_dropbox_refresh_token_v1';
const passphraseKey = 'metra_backup_passphrase_v1';

const folderId = 'folder-123';
const folderIdNew = 'folder-new';

/// Extracts and returns the OAuth state from a URL string.
String extractState(String url) =>
    Uri.parse(url).queryParameters['state'] ?? '';

void main() {
  late InMemorySecureStorage storage;

  setUp(() {
    storage = InMemorySecureStorage();
  });

  // =========================================================================
  // Group A — id getter / interface contract / imports (FR-01, FR-02, NFR-04)
  // =========================================================================

  group('Group A — id getter and interface contract', () {
    test('id getter returns SyncProvider.googleDrive', () {
      final provider = GoogleDriveProvider(
        clientId: 'cid',
        storage: storage,
        client: MockClient((_) async => http.Response('{}', 200)),
      );
      expect(provider.id, SyncProvider.googleDrive);
    });

    test('id getter does not depend on clientId value', () {
      final provider = GoogleDriveProvider(
        clientId: '',
        storage: storage,
        client: MockClient((_) async => http.Response('{}', 200)),
      );
      // id is a compile-time-constant-style getter, never touches clientId
      expect(provider.id, SyncProvider.googleDrive);
    });

    test(
      'GoogleDriveProvider satisfies the 8-member CloudBackupProvider interface',
      () {
        // Compilation itself is the assertion; CloudBackupProvider assignment
        // fails at compile time if any member is missing.
        final CloudBackupProvider impl = GoogleDriveProvider(
          clientId: '',
          storage: storage,
          client: MockClient((_) async => http.Response('{}', 200)),
        );
        expect(impl, isA<CloudBackupProvider>());
      },
    );

    test(
      'google_drive_provider.dart imports no google_sign_in, googleapis, or '
      'Play Services packages (FR-02, NFR-04)',
      () {
        final src = File('lib/data/services/backup/google_drive_provider.dart')
            .readAsStringSync();
        expect(
          src,
          isNot(contains("import 'package:google_sign_in/")),
          reason: 'google_drive_provider.dart must not import google_sign_in',
        );
        expect(
          src,
          isNot(contains("import 'package:googleapis/")),
          reason: 'google_drive_provider.dart must not import googleapis',
        );
        expect(
          src,
          isNot(contains("import 'package:google_api_availability/")),
          reason: 'google_drive_provider.dart must not import '
              'google_api_availability',
        );
        // No com.google.android.gms or gms reference.
        expect(
          src,
          isNot(contains('gms')),
          reason: 'google_drive_provider.dart must not reference Play Services',
        );
      },
    );

    test(
      'google_drive_provider.dart imports no package:flutter/ or '
      'flutter_riverpod (NFR-04)',
      () {
        final src = File('lib/data/services/backup/google_drive_provider.dart')
            .readAsStringSync();
        expect(
          src,
          isNot(contains("import 'package:flutter/")),
          reason: 'google_drive_provider.dart must not import package:flutter/',
        );
        expect(
          src,
          isNot(contains("import 'package:flutter_riverpod/")),
          reason: 'google_drive_provider.dart must not import flutter_riverpod',
        );
      },
    );
  });

  // =========================================================================
  // Group B — constructor + lazy client-id (FR-14, EC-07)
  // =========================================================================

  group('Group B — constructor and lazy client-id', () {
    test(
      'GoogleDriveProvider constructs without throwing on empty clientId',
      () {
        expect(
          () => GoogleDriveProvider(
            clientId: '',
            storage: storage,
          ),
          returnsNormally,
        );
      },
    );

    test(
      'id returns SyncProvider.googleDrive after construction with empty '
      'clientId',
      () {
        final provider = GoogleDriveProvider(clientId: '', storage: storage);
        expect(provider.id, SyncProvider.googleDrive);
      },
    );

    test(
      'listFiles with empty clientId and stubbed token does not throw '
      'an assertion about the empty string (FR-14, EC-07)',
      () async {
        // Seed access token so not-connected guard does not fire.
        storage.values[accessTokenKey] = 'tok';
        // Client returns empty folder (no Metra folder).
        final client = MockClient((_) async {
          return http.Response(
            jsonEncode(emptyFolderListResponse()),
            200,
          );
        });
        final provider = GoogleDriveProvider(
          clientId: '',
          storage: storage,
          client: client,
        );
        // Must not throw an assertion about empty clientId.
        final result = await provider.listFiles();
        expect(result, isEmpty);
      },
    );
  });

  // =========================================================================
  // Group C — OAuth / PKCE / CSRF (FR-02, FR-03, EC-05, EC-06, NFR-02)
  // =========================================================================

  group('Group C — OAuth authorize PKCE and CSRF', () {
    test(
      'authorize URL carries non-empty code_challenge and '
      'code_challenge_method=S256',
      () async {
        String? capturedUrl;
        final client = MockClient((req) async {
          if (req.url.host == 'oauth2.googleapis.com') {
            return http.Response(
              jsonEncode({
                'access_token': 'at',
                'refresh_token': 'rt',
              }),
              200,
            );
          }
          return http.Response('{}', 200);
        });
        final provider = GoogleDriveProvider(
          clientId: 'cid',
          storage: storage,
          client: client,
          webAuth: (String url, {required String callbackUrlScheme}) async {
            capturedUrl = url;
            final state = extractState(url);
            return 'com.paolosantucci.metraapp:/oauth-callback-google?code=abc&state=$state';
          },
        );
        await provider.authorize();

        final uri = Uri.parse(capturedUrl!);
        final challenge = uri.queryParameters['code_challenge'];
        final method = uri.queryParameters['code_challenge_method'];

        expect(challenge, isNotEmpty);
        expect(method, 'S256');
      },
    );

    test(
      'code_verifier hashes (SHA-256, base64url-no-pad) to the code_challenge',
      () async {
        String? capturedUrl;
        String? capturedVerifier;
        final client = MockClient((req) async {
          if (req.url.host == 'oauth2.googleapis.com' && req.method == 'POST') {
            // Capture verifier from the token exchange body.
            final body = Uri.splitQueryString(req.body);
            capturedVerifier = body['code_verifier'];
            return http.Response(
              jsonEncode({
                'access_token': 'at',
                'refresh_token': 'rt',
              }),
              200,
            );
          }
          return http.Response('{}', 200);
        });
        final provider = GoogleDriveProvider(
          clientId: 'cid',
          storage: storage,
          client: client,
          webAuth: (String url, {required String callbackUrlScheme}) async {
            capturedUrl = url;
            final state = extractState(url);
            return 'com.paolosantucci.metraapp:/oauth-callback-google?code=abc&state=$state';
          },
        );
        await provider.authorize();

        final uri = Uri.parse(capturedUrl!);
        final challenge = uri.queryParameters['code_challenge']!;

        // SHA-256 of verifier, base64url-no-pad.
        final digest = sha256.convert(utf8.encode(capturedVerifier!));
        final expectedChallenge =
            base64Url.encode(digest.bytes).replaceAll('=', '');

        expect(challenge, expectedChallenge);
      },
    );

    test(
      'authorize URL scope equals exactly '
      'https://www.googleapis.com/auth/drive.file',
      () async {
        String? capturedUrl;
        final client = MockClient((req) async {
          if (req.url.host == 'oauth2.googleapis.com') {
            return http.Response(
              jsonEncode({'access_token': 'at', 'refresh_token': 'rt'}),
              200,
            );
          }
          return http.Response('{}', 200);
        });
        final provider = GoogleDriveProvider(
          clientId: 'cid',
          storage: storage,
          client: client,
          webAuth: (String url, {required String callbackUrlScheme}) async {
            capturedUrl = url;
            final state = extractState(url);
            return 'com.paolosantucci.metraapp:/oauth-callback-google?code=abc&state=$state';
          },
        );
        await provider.authorize();

        final uri = Uri.parse(capturedUrl!);
        final scope = uri.queryParameters['scope'];
        expect(
          scope,
          'https://www.googleapis.com/auth/drive.file',
          reason: 'scope must be exactly drive.file — no broader Drive scope',
        );
        // Must not contain any broader scope substring.
        expect(scope, isNot(contains('drive.readonly')));
        expect(scope, isNot(contains('openid')));
        expect(scope, isNot(contains('email')));
      },
    );

    test(
      'authorize URL contains access_type=offline and prompt=consent',
      () async {
        String? capturedUrl;
        final client = MockClient((req) async {
          if (req.url.host == 'oauth2.googleapis.com') {
            return http.Response(
              jsonEncode({'access_token': 'at', 'refresh_token': 'rt'}),
              200,
            );
          }
          return http.Response('{}', 200);
        });
        final provider = GoogleDriveProvider(
          clientId: 'cid',
          storage: storage,
          client: client,
          webAuth: (String url, {required String callbackUrlScheme}) async {
            capturedUrl = url;
            final state = extractState(url);
            return 'com.paolosantucci.metraapp:/oauth-callback-google?code=abc&state=$state';
          },
        );
        await provider.authorize();

        final uri = Uri.parse(capturedUrl!);
        expect(uri.queryParameters['access_type'], 'offline');
        expect(uri.queryParameters['prompt'], 'consent');
      },
    );

    test(
      'authorize with matched state completes; '
      'mismatched state throws SyncException with CSRF message',
      () async {
        final client = MockClient((req) async {
          if (req.url.host == 'oauth2.googleapis.com') {
            return http.Response(
              jsonEncode({'access_token': 'at', 'refresh_token': 'rt'}),
              200,
            );
          }
          return http.Response('{}', 200);
        });

        // Matched state — should complete.
        final providerOk = GoogleDriveProvider(
          clientId: 'cid',
          storage: storage,
          client: client,
          webAuth: (String url, {required String callbackUrlScheme}) async {
            final state = extractState(url);
            return 'com.paolosantucci.metraapp:/oauth-callback-google?code=abc&state=$state';
          },
        );
        await expectLater(providerOk.authorize(), completes);

        // Mismatched state — should throw SyncException with CSRF message.
        final storage2 = InMemorySecureStorage();
        final providerBad = GoogleDriveProvider(
          clientId: 'cid',
          storage: storage2,
          client: client,
          webAuth: (String url, {required String callbackUrlScheme}) async =>
              'com.paolosantucci.metraapp:/oauth-callback-google?code=abc&state=WRONG_STATE',
        );
        await expectLater(
          providerBad.authorize(),
          throwsA(
            isA<SyncException>().having(
              (e) => e.message,
              'message',
              contains('CSRF attack'),
            ),
          ),
        );
        // No tokens written on CSRF mismatch.
        expect(storage2.values.containsKey(accessTokenKey), isFalse);
        expect(storage2.values.containsKey(refreshTokenKey), isFalse);
      },
    );

    test(
      'authorize with missing code in callback throws SyncException and '
      'writes no tokens',
      () async {
        final client = MockClient((_) async => http.Response('{}', 200));
        final provider = GoogleDriveProvider(
          clientId: 'cid',
          storage: storage,
          client: client,
          webAuth: (String url, {required String callbackUrlScheme}) async {
            final state = extractState(url);
            // Callback has state but no code.
            return 'com.paolosantucci.metraapp:/oauth-callback-google?state=$state';
          },
        );
        await expectLater(
          provider.authorize(),
          throwsA(
            isA<SyncException>().having(
              (e) => e.message,
              'message',
              contains('OAuth callback missing code'),
            ),
          ),
        );
        expect(storage.values.containsKey(accessTokenKey), isFalse);
        expect(storage.values.containsKey(refreshTokenKey), isFalse);
      },
    );

    test(
      'authorize times out after 5 minutes via fakeAsync and writes no tokens '
      '(EC-05)',
      () {
        fakeAsync((fake) {
          final provider = GoogleDriveProvider(
            clientId: 'cid',
            storage: storage,
            webAuth: (String url, {required String callbackUrlScheme}) =>
                Completer<String>().future, // never completes
          );

          SyncException? caught;
          provider.authorize().then((_) {}).catchError((Object e) {
            caught = e as SyncException;
          });

          fake.elapse(const Duration(minutes: 5));

          expect(caught, isNotNull);
          expect(caught, isA<SyncException>());
          expect(
            caught!.message,
            'OAuth timed out — please try again',
          );
          expect(storage.values.containsKey(accessTokenKey), isFalse);
          expect(storage.values.containsKey(refreshTokenKey), isFalse);
        });
      },
    );

    test(
      'authorize happy path writes both metra_google_drive_*_v1 keys '
      'and does NOT write Dropbox or passphrase keys (FR-05, NFR-02)',
      () async {
        final client = MockClient((req) async {
          if (req.url.host == 'oauth2.googleapis.com') {
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
        final provider = GoogleDriveProvider(
          clientId: 'cid',
          storage: storage,
          client: client,
          webAuth: (String url, {required String callbackUrlScheme}) async {
            final state = extractState(url);
            return 'com.paolosantucci.metraapp:/oauth-callback-google?code=auth-code&state=$state';
          },
        );
        await provider.authorize();

        expect(storage.values[accessTokenKey], 'access-tok');
        expect(storage.values[refreshTokenKey], 'refresh-tok');
        // Dropbox and passphrase keys must NOT be written.
        expect(storage.values.containsKey(dropboxAccessKey), isFalse);
        expect(storage.values.containsKey(dropboxRefreshKey), isFalse);
        expect(storage.values.containsKey(passphraseKey), isFalse);
      },
    );
  });

  // =========================================================================
  // Group D — folder scoping + _ensureFolderId (FR-04, EC-01)
  // =========================================================================

  group('Group D — folder scoping and _ensureFolderId', () {
    setUp(() {
      storage.values[accessTokenKey] = 'tok';
    });

    test(
      'upload folder id resolution: folder-query returns folder-123 → '
      'files.create includes parents:[folder-123] (FR-04)',
      () async {
        http.Request? uploadRequest;
        final client = MockClient((req) async {
          if (req.method == 'GET' && req.url.queryParameters.containsKey('q')) {
            // Folder-resolution query.
            return http.Response(
              jsonEncode(folderListResponse(folderId)),
              200,
            );
          }
          if (req.method == 'POST') {
            uploadRequest = req;
            return http.Response(
              jsonEncode(createResponse('file-1', 'metra_backup_x.enc')),
              200,
            );
          }
          return http.Response('{}', 200);
        });
        final provider = GoogleDriveProvider(
          clientId: 'cid',
          storage: storage,
          client: client,
        );
        await provider.upload(
          Uint8List.fromList([1, 2, 3]),
          'metra_backup_x.enc',
        );

        expect(uploadRequest, isNotNull);
        // The multipart request body should contain the folder id.
        final body = utf8.decode(uploadRequest!.bodyBytes);
        expect(body, contains(folderId));
      },
    );

    test(
      'folder-query URL contains mimeType, name=Metra, and trashed=false '
      '(FR-04)',
      () async {
        String? folderQueryUrl;
        final client = MockClient((req) async {
          if (req.method == 'GET' && req.url.queryParameters.containsKey('q')) {
            folderQueryUrl = req.url.toString();
            return http.Response(
              jsonEncode(folderListResponse(folderId)),
              200,
            );
          }
          if (req.method == 'POST') {
            return http.Response(
              jsonEncode(createResponse('file-1', 'metra_backup_x.enc')),
              200,
            );
          }
          return http.Response('{}', 200);
        });
        final provider = GoogleDriveProvider(
          clientId: 'cid',
          storage: storage,
          client: client,
        );
        await provider.upload(
          Uint8List.fromList([1, 2, 3]),
          'metra_backup_x.enc',
        );

        expect(folderQueryUrl, isNotNull);
        expect(
          folderQueryUrl,
          contains('application/vnd.google-apps.folder'),
        );
        expect(folderQueryUrl, contains('Metra'));
        expect(folderQueryUrl, contains('trashed=false'));
      },
    );

    test(
      'folder id memoization: 2 consecutive uploads issue folder-query exactly '
      'once (FR-04)',
      () async {
        var folderQueryCount = 0;
        final client = MockClient((req) async {
          if (req.method == 'GET' && req.url.queryParameters.containsKey('q')) {
            final q = req.url.queryParameters['q'] ?? '';
            if (q.contains('folder') || q.contains('vnd.google')) {
              folderQueryCount++;
            }
            return http.Response(
              jsonEncode(folderListResponse(folderId)),
              200,
            );
          }
          if (req.method == 'POST') {
            return http.Response(
              jsonEncode(createResponse('file-x', 'metra_backup_x.enc')),
              200,
            );
          }
          return http.Response('{}', 200);
        });
        final provider = GoogleDriveProvider(
          clientId: 'cid',
          storage: storage,
          client: client,
        );
        await provider.upload(Uint8List.fromList([1]), 'metra_backup_1.enc');
        await provider.upload(Uint8List.fromList([2]), 'metra_backup_2.enc');

        expect(folderQueryCount, 1);
      },
    );

    test(
      'upload folder-create branch: empty folder-query → issues files.create '
      'folder before upload; upload parents reference new id (FR-04, EC-01)',
      () async {
        var folderCreateIssued = false;
        http.Request? uploadReq;
        final client = MockClient((req) async {
          if (req.method == 'GET' && req.url.queryParameters.containsKey('q')) {
            // No Metra folder yet.
            return http.Response(
              jsonEncode(emptyFolderListResponse()),
              200,
            );
          }
          if (req.method == 'POST') {
            final body = utf8.decode(req.bodyBytes);
            if (body.contains('application/vnd.google-apps.folder') &&
                !req.url.path.contains('upload')) {
              // Folder create.
              folderCreateIssued = true;
              return http.Response(
                jsonEncode(createResponse(folderIdNew, 'Metra')),
                200,
              );
            }
            // File upload.
            uploadReq = req;
            return http.Response(
              jsonEncode(createResponse('file-new', 'metra_backup_x.enc')),
              200,
            );
          }
          return http.Response('{}', 200);
        });
        final provider = GoogleDriveProvider(
          clientId: 'cid',
          storage: storage,
          client: client,
        );
        await provider.upload(
          Uint8List.fromList([1, 2, 3]),
          'metra_backup_x.enc',
        );

        expect(folderCreateIssued, isTrue);
        expect(uploadReq, isNotNull);
        final body = utf8.decode(uploadReq!.bodyBytes);
        expect(body, contains(folderIdNew));
      },
    );
  });

  // =========================================================================
  // Group E — quota discrimination (FR-07, EC-02, EC-03)
  // =========================================================================

  group('Group E — upload quota discrimination', () {
    setUp(() {
      storage.values[accessTokenKey] = 'tok';
    });

    String quotaBody(String reason) => jsonEncode({
          'error': {
            'code': 403,
            'errors': [
              {'reason': reason, 'domain': 'global', 'message': 'error'},
            ],
            'message': 'error',
          },
        });

    MockClient clientWith403(String reason) => MockClient((req) async {
          if (req.method == 'GET') {
            return http.Response(jsonEncode(folderListResponse(folderId)), 200);
          }
          return http.Response(quotaBody(reason), 403);
        });

    test(
      '403 storageQuotaExceeded → throwsA(isA<InsufficientStorageException>()) '
      '(EC-02, FR-07)',
      () async {
        final provider = GoogleDriveProvider(
          clientId: 'cid',
          storage: storage,
          client: clientWith403('storageQuotaExceeded'),
        );
        await expectLater(
          () => provider.upload(
            Uint8List.fromList([1]),
            'metra_backup_x.enc',
          ),
          throwsA(isA<InsufficientStorageException>()),
        );
      },
    );

    test(
      '403 rateLimitExceeded → SyncException but NOT InsufficientStorageException '
      '(EC-03, FR-07 second clause)',
      () async {
        final provider = GoogleDriveProvider(
          clientId: 'cid',
          storage: storage,
          client: clientWith403('rateLimitExceeded'),
        );
        await expectLater(
          () => provider.upload(
            Uint8List.fromList([1]),
            'metra_backup_x.enc',
          ),
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
      '403 insufficientFilePermissions → SyncException NOT '
      'InsufficientStorageException (EC-03)',
      () async {
        final provider = GoogleDriveProvider(
          clientId: 'cid',
          storage: storage,
          client: clientWith403('insufficientFilePermissions'),
        );
        await expectLater(
          () => provider.upload(
            Uint8List.fromList([1]),
            'metra_backup_x.enc',
          ),
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
      '503 → SyncException NOT InsufficientStorageException (EC-03)',
      () async {
        final client = MockClient((req) async {
          if (req.method == 'GET') {
            return http.Response(jsonEncode(folderListResponse(folderId)), 200);
          }
          return http.Response('Service Unavailable', 503);
        });
        final provider = GoogleDriveProvider(
          clientId: 'cid',
          storage: storage,
          client: client,
        );
        await expectLater(
          () => provider.upload(
            Uint8List.fromList([1]),
            'metra_backup_x.enc',
          ),
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
      '200 → upload completes without throwing',
      () async {
        final client = MockClient((req) async {
          if (req.method == 'GET') {
            return http.Response(jsonEncode(folderListResponse(folderId)), 200);
          }
          return http.Response(
            jsonEncode(createResponse('file-1', 'metra_backup_x.enc')),
            200,
          );
        });
        final provider = GoogleDriveProvider(
          clientId: 'cid',
          storage: storage,
          client: client,
        );
        await expectLater(
          provider.upload(Uint8List.fromList([1]), 'metra_backup_x.enc'),
          completes,
        );
      },
    );
  });

  // =========================================================================
  // Group F — upload bearer token + parents (FR-04, FR-05, NFR-02)
  // =========================================================================

  group('Group F — upload bearer token and multipart metadata', () {
    setUp(() {
      storage.values[accessTokenKey] = 'tok';
    });

    test(
      'upload sends Authorization: Bearer <token> header on Drive request',
      () async {
        http.Request? uploadReq;
        final client = MockClient((req) async {
          if (req.method == 'GET') {
            return http.Response(jsonEncode(folderListResponse(folderId)), 200);
          }
          if (req.method == 'POST') {
            uploadReq = req;
            return http.Response(
              jsonEncode(createResponse('file-1', 'metra_backup_x.enc')),
              200,
            );
          }
          return http.Response('{}', 200);
        });
        final provider = GoogleDriveProvider(
          clientId: 'cid',
          storage: storage,
          client: client,
        );
        await provider.upload(
          Uint8List.fromList([1, 2, 3]),
          'metra_backup_x.enc',
        );

        expect(uploadReq, isNotNull);
        expect(uploadReq!.headers['Authorization'], 'Bearer tok');
      },
    );

    test(
      'multipart upload metadata contains name and parents; '
      'binary part contains exact blob bytes',
      () async {
        final blob = Uint8List.fromList([10, 20, 30, 40]);
        http.Request? uploadReq;
        final client = MockClient((req) async {
          if (req.method == 'GET') {
            return http.Response(jsonEncode(folderListResponse(folderId)), 200);
          }
          if (req.method == 'POST') {
            uploadReq = req;
            return http.Response(
              jsonEncode(createResponse('file-1', 'metra_backup_f.enc')),
              200,
            );
          }
          return http.Response('{}', 200);
        });
        final provider = GoogleDriveProvider(
          clientId: 'cid',
          storage: storage,
          client: client,
        );
        await provider.upload(blob, 'metra_backup_f.enc');

        expect(uploadReq, isNotNull);
        final body = utf8.decode(uploadReq!.bodyBytes, allowMalformed: true);
        // Metadata part must contain name and parents.
        expect(body, contains('"name"'));
        expect(body, contains('metra_backup_f.enc'));
        expect(body, contains('"parents"'));
        expect(body, contains(folderId));
        // Binary part: blob bytes must appear in the raw body bytes.
        expect(uploadReq!.bodyBytes, containsAll(blob));
      },
    );
  });

  // =========================================================================
  // Group G — listFiles sort + filter + parse (FR-10, FR-11, EC-01)
  // =========================================================================

  group('Group G — listFiles sort filter and parse', () {
    setUp(() {
      storage.values[accessTokenKey] = 'tok';
    });

    test(
      'listFiles: 3 matching + 1 non-matching → 3 entries sorted by name '
      'descending; .first is newest, .last is oldest; unrelated absent (FR-10)',
      () async {
        final files = [
          {
            'id': 'id3',
            'name': 'metra_backup_20260517T120000Z_abc.enc',
            'modifiedTime': '2026-05-17T12:00:00Z',
            'size': '4096',
          },
          {
            'id': 'id1',
            'name': 'metra_backup_20260515T120000Z_xyz.enc',
            'modifiedTime': '2026-05-15T12:00:00Z',
            'size': '1024',
          },
          {
            'id': 'id2',
            'name': 'metra_backup_20260516T120000Z_def.enc',
            'modifiedTime': '2026-05-16T12:00:00Z',
            'size': '2048',
          },
          {
            'id': 'id0',
            'name': 'unrelated.txt',
            'modifiedTime': '2026-05-14T12:00:00Z',
            'size': '512',
          },
        ];
        var callIndex = 0;
        final client = MockClient((req) async {
          if (req.method == 'GET') {
            callIndex++;
            if (callIndex == 1) {
              // First GET: folder resolution.
              return http.Response(
                jsonEncode(folderListResponse(folderId)),
                200,
              );
            }
            // Second GET: scoped files list.
            return http.Response(filesListJson(files), 200);
          }
          return http.Response('{}', 200);
        });
        final provider = GoogleDriveProvider(
          clientId: 'cid',
          storage: storage,
          client: client,
        );
        final entries = await provider.listFiles();

        expect(entries, hasLength(3));
        // Sort by name descending.
        expect(
          entries[0].name,
          'metra_backup_20260517T120000Z_abc.enc',
        );
        expect(
          entries[1].name,
          'metra_backup_20260516T120000Z_def.enc',
        );
        expect(
          entries[2].name,
          'metra_backup_20260515T120000Z_xyz.enc',
        );
        // Confirm .first is newer than .last.
        expect(
          entries.first.name.compareTo(entries.last.name),
          greaterThan(0),
          reason: '.first name must be lexicographically greater than .last',
        );
        // unrelated.txt must not appear.
        expect(
          entries.any((BackupFileEntry entry) => entry.name == 'unrelated.txt'),
          isFalse,
        );
      },
    );

    test(
      'listFiles: each entry has non-null name, timestampUtc, and sizeBytes; '
      'timestampUtc is parsed from modifiedTime (FR-10)',
      () async {
        final files = [
          {
            'id': 'id1',
            'name': 'metra_backup_20260517T120000Z_abc.enc',
            'modifiedTime': '2026-05-17T12:00:00Z',
            'size': '4096',
          },
        ];
        var callIndex = 0;
        final client = MockClient((req) async {
          if (req.method == 'GET') {
            callIndex++;
            if (callIndex == 1) {
              return http.Response(
                jsonEncode(folderListResponse(folderId)),
                200,
              );
            }
            return http.Response(filesListJson(files), 200);
          }
          return http.Response('{}', 200);
        });
        final provider = GoogleDriveProvider(
          clientId: 'cid',
          storage: storage,
          client: client,
        );
        final entries = await provider.listFiles();

        expect(entries, hasLength(1));
        final e = entries.first;
        expect(e.name, isNotEmpty);
        expect(e.timestampUtc, isNotNull);
        expect(e.sizeBytes, isNotNull);
        // timestampUtc parsed from modifiedTime '2026-05-17T12:00:00Z'.
        expect(e.timestampUtc, DateTime.utc(2026, 5, 17, 12, 0, 0));
        expect(e.sizeBytes, 4096);
      },
    );

    test(
      'listFiles returns [] when folder-resolution query yields {files:[]} '
      '(FR-11, EC-01)',
      () async {
        final client = MockClient((_) async {
          return http.Response(
            jsonEncode(emptyFolderListResponse()),
            200,
          );
        });
        final provider = GoogleDriveProvider(
          clientId: 'cid',
          storage: storage,
          client: client,
        );
        final entries = await provider.listFiles();
        expect(entries, isEmpty);
      },
    );

    test(
      'listFiles returns [] when folder-resolution query returns 404 '
      '(FR-11, EC-01)',
      () async {
        final client = MockClient((_) async => http.Response('{}', 404));
        final provider = GoogleDriveProvider(
          clientId: 'cid',
          storage: storage,
          client: client,
        );
        final entries = await provider.listFiles();
        expect(entries, isEmpty);
      },
    );

    test(
      'listFiles returns [] when folder resolved but scoped files.list returns '
      '404 (EC-01 error-state variant)',
      () async {
        var callIndex = 0;
        final client = MockClient((req) async {
          callIndex++;
          if (callIndex == 1) {
            // First GET: folder resolution succeeds.
            return http.Response(
              jsonEncode(folderListResponse(folderId)),
              200,
            );
          }
          // Second GET: scoped files list returns 404.
          return http.Response('{}', 404);
        });
        final provider = GoogleDriveProvider(
          clientId: 'cid',
          storage: storage,
          client: client,
        );
        final entries = await provider.listFiles();
        expect(entries, isEmpty);
      },
    );
  });

  // =========================================================================
  // Group H — 401 refresh + retry (FR-06, EC-04, EC-09)
  // =========================================================================

  group('Group H — 401 refresh and retry', () {
    setUp(() {
      storage.values[accessTokenKey] = 'expired';
      storage.values[refreshTokenKey] = 'refresh-tok';
    });

    test(
      '401 on upload → refresh returns new token → retry succeeds; '
      'storage updated; upload calls == 2 (FR-06, EC-04)',
      () async {
        var uploadCallCount = 0;
        final client = MockClient((req) async {
          // Folder resolution: always succeed.
          if (req.method == 'GET' && req.url.queryParameters.containsKey('q')) {
            return http.Response(
              jsonEncode(folderListResponse(folderId)),
              200,
            );
          }
          // Token refresh endpoint.
          if (req.url.host == 'oauth2.googleapis.com') {
            return http.Response(
              jsonEncode({'access_token': 'new-tok', 'expires_in': 3600}),
              200,
            );
          }
          // Upload endpoint (multipart POST).
          if (req.method == 'POST') {
            uploadCallCount++;
            if (uploadCallCount == 1) {
              return http.Response('Unauthorized', 401);
            }
            return http.Response(
              jsonEncode(createResponse('file-1', 'metra_backup_x.enc')),
              200,
            );
          }
          return http.Response('{}', 200);
        });
        final provider = GoogleDriveProvider(
          clientId: 'cid',
          storage: storage,
          client: client,
        );
        await provider.upload(Uint8List.fromList([1]), 'metra_backup_x.enc');

        expect(storage.values[accessTokenKey], 'new-tok');
        expect(uploadCallCount, 2);
      },
    );

    test(
      '401 on retry is NOT retried again; upload calls == 2; throws SyncException '
      '(FR-06 second clause)',
      () async {
        var uploadCallCount = 0;
        final client = MockClient((req) async {
          if (req.method == 'GET' && req.url.queryParameters.containsKey('q')) {
            return http.Response(
              jsonEncode(folderListResponse(folderId)),
              200,
            );
          }
          if (req.url.host == 'oauth2.googleapis.com') {
            return http.Response(
              jsonEncode({'access_token': 'new-tok', 'expires_in': 3600}),
              200,
            );
          }
          if (req.method == 'POST') {
            uploadCallCount++;
            // Both calls return 401.
            return http.Response('Unauthorized', 401);
          }
          return http.Response('{}', 200);
        });
        final provider = GoogleDriveProvider(
          clientId: 'cid',
          storage: storage,
          client: client,
        );
        await expectLater(
          () => provider.upload(Uint8List.fromList([1]), 'metra_backup_x.enc'),
          throwsA(isA<SyncException>()),
        );
        expect(uploadCallCount, 2);
      },
    );

    test(
      'missing refresh token → SyncException("No refresh token"); '
      'no token-endpoint call (EC-09)',
      () async {
        // Remove the refresh token.
        storage.values.remove(refreshTokenKey);

        var tokenEndpointCalled = false;
        final client = MockClient((req) async {
          if (req.method == 'GET' && req.url.queryParameters.containsKey('q')) {
            return http.Response(
              jsonEncode(folderListResponse(folderId)),
              200,
            );
          }
          if (req.url.host == 'oauth2.googleapis.com') {
            tokenEndpointCalled = true;
            return http.Response('{}', 200);
          }
          if (req.method == 'POST') {
            return http.Response('Unauthorized', 401);
          }
          return http.Response('{}', 200);
        });
        final provider = GoogleDriveProvider(
          clientId: 'cid',
          storage: storage,
          client: client,
        );
        await expectLater(
          () => provider.upload(Uint8List.fromList([1]), 'metra_backup_x.enc'),
          throwsA(
            isA<SyncException>().having(
              (e) => e.message,
              'message',
              contains('No refresh token'),
            ),
          ),
        );
        expect(tokenEndpointCalled, isFalse);
      },
    );

    test(
      'refresh endpoint returns 500 → SyncException("Refresh failed"); '
      'no retry of original request (FR-06, EC-09)',
      () async {
        var uploadCallCount = 0;
        final client = MockClient((req) async {
          if (req.method == 'GET' && req.url.queryParameters.containsKey('q')) {
            return http.Response(
              jsonEncode(folderListResponse(folderId)),
              200,
            );
          }
          if (req.url.host == 'oauth2.googleapis.com') {
            return http.Response('Internal Server Error', 500);
          }
          if (req.method == 'POST') {
            uploadCallCount++;
            return http.Response('Unauthorized', 401);
          }
          return http.Response('{}', 200);
        });
        final provider = GoogleDriveProvider(
          clientId: 'cid',
          storage: storage,
          client: client,
        );
        await expectLater(
          () => provider.upload(Uint8List.fromList([1]), 'metra_backup_x.enc'),
          throwsA(
            isA<SyncException>().having(
              (e) => e.message,
              'message',
              contains('Refresh failed'),
            ),
          ),
        );
        // No retry after a failed refresh.
        expect(uploadCallCount, 1);
      },
    );
  });

  // =========================================================================
  // Group I — disconnect + key isolation (FR-08, EC-10, NFR-02, EC-12)
  // =========================================================================

  group('Group I — disconnect and key isolation', () {
    test(
      'disconnect deletes both Google keys unconditionally; '
      'Dropbox and passphrase keys untouched (FR-08, NFR-02)',
      () async {
        storage.values[accessTokenKey] = 'tok';
        storage.values[refreshTokenKey] = 'r';
        storage.values[dropboxAccessKey] = 'dropbox-tok';
        storage.values[dropboxRefreshKey] = 'dropbox-r';
        storage.values[passphraseKey] = 'pw';

        final client = MockClient((_) async => http.Response('{}', 200));
        final provider = GoogleDriveProvider(
          clientId: 'cid',
          storage: storage,
          client: client,
        );
        await provider.disconnect();

        expect(storage.values.containsKey(accessTokenKey), isFalse);
        expect(storage.values.containsKey(refreshTokenKey), isFalse);
        // Dropbox and passphrase untouched.
        expect(storage.values[dropboxAccessKey], 'dropbox-tok');
        expect(storage.values[dropboxRefreshKey], 'dropbox-r');
        expect(storage.values[passphraseKey], 'pw');
      },
    );

    test(
      'disconnect: revoke endpoint returns 500 → disconnect still completes; '
      'both Google keys deleted (EC-10, FR-08)',
      () async {
        storage.values[accessTokenKey] = 'tok';
        storage.values[refreshTokenKey] = 'r';

        final client = MockClient(
          (_) async => http.Response('Internal Server Error', 500),
        );
        final provider = GoogleDriveProvider(
          clientId: 'cid',
          storage: storage,
          client: client,
        );
        // Must NOT throw.
        await expectLater(provider.disconnect(), completes);

        expect(storage.values.containsKey(accessTokenKey), isFalse);
        expect(storage.values.containsKey(refreshTokenKey), isFalse);
      },
    );

    test(
      'disconnect does NOT delete metra_backup_passphrase_v1 '
      '(NFR-02 key isolation)',
      () async {
        storage.values[accessTokenKey] = 'tok';
        storage.values[refreshTokenKey] = 'r';
        storage.values[passphraseKey] = 'my-passphrase';

        final client = MockClient((_) async => http.Response('{}', 200));
        final provider = GoogleDriveProvider(
          clientId: 'cid',
          storage: storage,
          client: client,
        );
        await provider.disconnect();

        expect(storage.values[passphraseKey], 'my-passphrase');
      },
    );

    test(
      'not-connected: CRUD methods throw SyncException; '
      'currentEmail() returns null (EC-12)',
      () async {
        // No access token in storage.
        final client = MockClient((_) async => http.Response('{}', 200));
        final provider = GoogleDriveProvider(
          clientId: 'cid',
          storage: storage,
          client: client,
        );

        await expectLater(
          () => provider.upload(
            Uint8List.fromList([1]),
            'metra_backup_x.enc',
          ),
          throwsA(
            isA<SyncException>().having(
              (e) => e.message,
              'message',
              contains('Not connected'),
            ),
          ),
        );
        await expectLater(
          () => provider.download('metra_backup_x.enc'),
          throwsA(isA<SyncException>()),
        );
        await expectLater(
          provider.listFiles,
          throwsA(isA<SyncException>()),
        );
        await expectLater(
          () => provider.deleteFile('metra_backup_x.enc'),
          throwsA(isA<SyncException>()),
        );

        // currentEmail() returns null, not throws.
        final email = await provider.currentEmail();
        expect(email, isNull);
      },
    );
  });

  // =========================================================================
  // Group J — currentEmail (FR-09, EC-11, EC-12)
  // =========================================================================

  group('Group J — currentEmail', () {
    test(
      'currentEmail returns decoded email from id_token (FR-09)',
      () async {
        final idToken = fakeIdToken('user@gmail.com');
        final client = MockClient((req) async {
          if (req.url.host == 'oauth2.googleapis.com') {
            return http.Response(
              jsonEncode({
                'access_token': 'at',
                'refresh_token': 'rt',
                'id_token': idToken,
              }),
              200,
            );
          }
          return http.Response('{}', 200);
        });
        final provider = GoogleDriveProvider(
          clientId: 'cid',
          storage: storage,
          client: client,
          webAuth: (String url, {required String callbackUrlScheme}) async {
            final state = extractState(url);
            return 'com.paolosantucci.metraapp:/oauth-callback-google?code=abc&state=$state';
          },
        );
        await provider.authorize();

        final email = await provider.currentEmail();
        expect(email, 'user@gmail.com');
      },
    );

    test(
      'currentEmail returns non-null label when no id_token in token response '
      '(EC-11, FR-09)',
      () async {
        final client = MockClient((req) async {
          if (req.url.host == 'oauth2.googleapis.com') {
            return http.Response(
              jsonEncode({
                'access_token': 'at',
                'refresh_token': 'rt',
                // No id_token field.
              }),
              200,
            );
          }
          return http.Response('{}', 200);
        });
        final provider = GoogleDriveProvider(
          clientId: 'cid',
          storage: storage,
          client: client,
          webAuth: (String url, {required String callbackUrlScheme}) async {
            final state = extractState(url);
            return 'com.paolosantucci.metraapp:/oauth-callback-google?code=abc&state=$state';
          },
        );
        await provider.authorize();

        final email = await provider.currentEmail();
        // Must be non-null and not throw.
        expect(email, isNotNull);
        expect(email, isA<String>());
      },
    );

    test(
      'currentEmail returns null when not connected (no access token) (EC-12)',
      () async {
        // No access token in storage.
        final provider = GoogleDriveProvider(clientId: 'cid', storage: storage);
        final email = await provider.currentEmail();
        expect(email, isNull);
      },
    );
  });

  // =========================================================================
  // Group — deleteFile (FR-04)
  // =========================================================================

  group('deleteFile — folder-scoped by name', () {
    setUp(() {
      storage.values[accessTokenKey] = 'tok';
    });

    test(
      'deleteFile resolves file id within Metra folder then issues DELETE; '
      '204 → no throw (FR-04)',
      () async {
        String? deleteUrl;
        var callIndex = 0;
        final client = MockClient((req) async {
          if (req.method == 'GET') {
            callIndex++;
            if (callIndex == 1) {
              // Folder resolution.
              return http.Response(
                jsonEncode(folderListResponse(folderId)),
                200,
              );
            }
            // File id resolution within folder.
            return http.Response(
              jsonEncode({
                'files': [
                  {'id': 'file-abc', 'name': 'metra_backup_x.enc'},
                ],
              }),
              200,
            );
          }
          // DELETE.
          if (req.method == 'DELETE') {
            deleteUrl = req.url.toString();
            return http.Response('', 204);
          }
          return http.Response('{}', 200);
        });
        final provider = GoogleDriveProvider(
          clientId: 'cid',
          storage: storage,
          client: client,
        );
        await expectLater(
          provider.deleteFile('metra_backup_x.enc'),
          completes,
        );
        expect(deleteUrl, isNotNull);
        expect(deleteUrl, contains('file-abc'));
      },
    );

    test(
      'deleteFile file-list query contains the folder id (folder scoping)',
      () async {
        String? listQueryUrl;
        var callIndex = 0;
        final client = MockClient((req) async {
          if (req.method == 'GET') {
            callIndex++;
            if (callIndex == 1) {
              return http.Response(
                jsonEncode(folderListResponse(folderId)),
                200,
              );
            }
            listQueryUrl = req.url.toString();
            return http.Response(
              jsonEncode({
                'files': [
                  {'id': 'file-abc', 'name': 'metra_backup_x.enc'},
                ],
              }),
              200,
            );
          }
          if (req.method == 'DELETE') {
            return http.Response('', 204);
          }
          return http.Response('{}', 200);
        });
        final provider = GoogleDriveProvider(
          clientId: 'cid',
          storage: storage,
          client: client,
        );
        await provider.deleteFile('metra_backup_x.enc');

        expect(listQueryUrl, isNotNull);
        expect(listQueryUrl, contains(folderId));
      },
    );
  });

  // =========================================================================
  // Group M — EC-08 concurrency invariant + callbackUrlScheme (EC-08, FR-15)
  // =========================================================================

  group('Group M — OAuth callback scheme invariant', () {
    test(
      'google_drive_provider.dart uses callbackUrlScheme: '
      'com.paolosantucci.metraapp (reverse-domain, Google policy) (EC-08, FR-15)',
      () {
        final src = File('lib/data/services/backup/google_drive_provider.dart')
            .readAsStringSync();
        expect(
          src,
          contains("callbackUrlScheme: 'com.paolosantucci.metraapp'"),
          reason:
              'Provider must use the reverse-domain scheme required by '
              "Google's OAuth 2.0 policy",
        );
      },
    );

    test(
      'google_drive_provider.dart redirect URI uses host oauth-callback-google '
      '(EC-08, FR-15)',
      () {
        final src = File('lib/data/services/backup/google_drive_provider.dart')
            .readAsStringSync();
        expect(
          src,
          contains('oauth-callback-google'),
          reason: 'Redirect URI must use host oauth-callback-google',
        );
      },
    );
  });

  // =========================================================================
  // Group L — CI workflow + AndroidManifest contract (FR-12, FR-15)
  // =========================================================================

  group('Group L — CI workflow dart-define and manifest assertions', () {
    test(
      'android.yml: all three build commands contain '
      '--dart-define=GOOGLE_OAUTH_CLIENT_ID (FR-12)',
      () {
        final src = File('.github/workflows/android.yml').readAsStringSync();
        // The dart-define must appear at least 3 times (debug, release,
        // appbundle).
        final matches = RegExp(
          r'--dart-define=GOOGLE_OAUTH_CLIENT_ID=\$\{\{[^}]+\}\}',
        ).allMatches(src);
        expect(
          matches.length,
          greaterThanOrEqualTo(3),
          reason: 'android.yml must have GOOGLE_OAUTH_CLIENT_ID dart-define in '
              'all 3 build commands (debug-APK, release-APK, appbundle)',
        );
      },
    );

    test(
      'ios.yml: both build commands contain '
      '--dart-define=GOOGLE_OAUTH_CLIENT_ID (FR-12)',
      () {
        final src = File('.github/workflows/ios.yml').readAsStringSync();
        final matches = RegExp(
          r'--dart-define=GOOGLE_OAUTH_CLIENT_ID=\$\{\{[^}]+\}\}',
        ).allMatches(src);
        expect(
          matches.length,
          greaterThanOrEqualTo(2),
          reason: 'ios.yml must have GOOGLE_OAUTH_CLIENT_ID dart-define in '
              'both build commands (no-codesign, release-archive)',
        );
      },
    );

    test(
      'quality.yml does NOT contain GOOGLE_OAUTH_CLIENT_ID (FR-12)',
      () {
        final src = File('.github/workflows/quality.yml').readAsStringSync();
        expect(
          src,
          isNot(contains('GOOGLE_OAUTH_CLIENT_ID')),
          reason:
              'quality.yml must not carry the GOOGLE_OAUTH_CLIENT_ID define',
        );
      },
    );

    test(
      'AndroidManifest.xml has a second intent-filter with '
      'host=oauth-callback-google (FR-15)',
      () {
        final src = File(
          'android/app/src/main/AndroidManifest.xml',
        ).readAsStringSync();
        expect(
          src,
          contains('oauth-callback-google'),
          reason: 'Manifest must have a second intent-filter with '
              'host=oauth-callback-google',
        );
      },
    );

    test(
      'AndroidManifest.xml uses exactly the expected two schemes across '
      'OAuth intent-filters: metra (Dropbox) + com.paolosantucci.metraapp '
      '(Google Drive, reverse-domain per Google policy) — EC-08 invariant',
      () {
        final src = File(
          'android/app/src/main/AndroidManifest.xml',
        ).readAsStringSync();
        // Scope to <intent-filter> blocks only: the standard Flutter
        // <queries> block declares http/https schemes that are unrelated
        // to OAuth routing and must not count toward the EC-08 invariant.
        final intentFilters = RegExp(
          r'<intent-filter[\s\S]*?</intent-filter>',
        ).allMatches(src).map((m) => m.group(0)!).join('\n');
        final schemes = RegExp(r'android:scheme="([^"]+)"')
            .allMatches(intentFilters)
            .map((m) => m.group(1))
            .toSet();
        expect(
          schemes,
          equals({'metra', 'com.paolosantucci.metraapp'}),
          reason: 'OAuth intent-filters must use exactly two schemes: '
              '"metra" (Dropbox) and "com.paolosantucci.metraapp" '
              '(Google Drive reverse-domain); no others allowed (EC-08)',
        );
      },
    );

    test(
      'Info.plist does NOT contain a Google reversed-client-id '
      'CFBundleURLSchemes entry (FR-15, §1.3 scope boundary)',
      () {
        final src = File('ios/Runner/Info.plist').readAsStringSync();
        // Must NOT contain a com.googleusercontent.apps reversed-client-id
        // scheme.
        expect(
          src,
          isNot(contains('com.googleusercontent.apps')),
          reason:
              'Info.plist must not have a Google reversed-client-id URL scheme',
        );
      },
    );

    test(
      'redirect host oauth-callback-google is consistent between '
      'google_drive_provider.dart and AndroidManifest.xml (FR-15)',
      () {
        final dartSrc =
            File('lib/data/services/backup/google_drive_provider.dart')
                .readAsStringSync();
        final manifestSrc = File(
          'android/app/src/main/AndroidManifest.xml',
        ).readAsStringSync();

        expect(
          dartSrc,
          contains('oauth-callback-google'),
          reason: 'Dart source must contain the redirect host',
        );
        expect(
          manifestSrc,
          contains('oauth-callback-google'),
          reason: 'AndroidManifest must contain the matching redirect host',
        );
      },
    );
  });
}
