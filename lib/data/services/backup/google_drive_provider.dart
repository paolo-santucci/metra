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

// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;

import '../../../core/errors/metra_exception.dart';
import '../../../domain/entities/sync_log_entity.dart';
import 'backup_file_entry.dart';
import 'cloud_backup_provider.dart';

class GoogleDriveProvider implements CloudBackupProvider {
  GoogleDriveProvider({
    required String clientId,
    FlutterSecureStorage? storage,
    http.Client? client,
    Future<String> Function(String url, {required String callbackUrlScheme})?
        webAuth,
    Random? random,
  })  : _clientId = clientId,
        _storage = storage ?? const FlutterSecureStorage(),
        _client = client ?? http.Client(),
        _webAuth = webAuth ?? _defaultWebAuth,
        _random = random ?? Random.secure();

  static const _accessTokenKey = 'metra_google_drive_access_token_v1';
  static const _refreshTokenKey = 'metra_google_drive_refresh_token_v1';
  static const _filePrefix = 'metra_backup_';
  static const _fileSuffix = '.enc';
  // Reverse-domain scheme required by Google's OAuth 2.0 policy (generic
  // schemes like metra:// are rejected with 400 invalid_request).
  static const _redirectUri = 'com.paolosantucci.metraapp:/oauth-callback-google';

  final String _clientId;
  final FlutterSecureStorage _storage;
  final http.Client _client;
  final Future<String> Function(String url, {required String callbackUrlScheme})
      _webAuth;
  final Random _random;

  // Memoized folder id — resolved once on first upload/list/delete.
  String? _folderId;

  // Email decoded from id_token during authorize (cached in memory).
  String? _cachedEmail;

  // Holds the CSRF state token generated at the start of each authorize() call.
  String? _oauthState;

  static Future<String> _defaultWebAuth(
    String url, {
    required String callbackUrlScheme,
  }) =>
      FlutterWebAuth2.authenticate(
        url: url,
        callbackUrlScheme: callbackUrlScheme,
      );

  @override
  SyncProvider get id => SyncProvider.googleDrive;

  @override
  Future<void> authorize() async {
    final verifier = _generateCodeVerifier();
    final challenge = _codeChallenge(verifier);
    _oauthState = _generateOauthState();

    final authUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
      'client_id': _clientId,
      'response_type': 'code',
      'redirect_uri': _redirectUri,
      'scope': 'https://www.googleapis.com/auth/drive.file',
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
      'access_type': 'offline',
      'prompt': 'consent',
      'state': _oauthState!,
    });

    final result = await _webAuth(
      authUrl.toString(),
      callbackUrlScheme: 'com.paolosantucci.metraapp',
    ).timeout(
      const Duration(minutes: 5),
      onTimeout: () =>
          throw const SyncException('OAuth timed out — please try again'),
    );

    final callbackParams = Uri.parse(result).queryParameters;
    final returnedState = callbackParams['state'];
    if (returnedState != _oauthState) {
      throw const SyncException(
        'OAuth state mismatch — possible CSRF attack',
      );
    }

    final code = callbackParams['code'];
    if (code == null) {
      throw const SyncException('OAuth callback missing code');
    }

    final tokenRes = await _client.post(
      Uri.https('oauth2.googleapis.com', '/token'),
      body: {
        'code': code,
        'grant_type': 'authorization_code',
        'client_id': _clientId,
        'code_verifier': verifier,
        'redirect_uri': _redirectUri,
      },
    );

    if (tokenRes.statusCode != 200) {
      throw SyncException('Token exchange failed: ${tokenRes.statusCode}');
    }

    final tokens = jsonDecode(tokenRes.body) as Map<String, dynamic>;
    await _storage.write(
      key: _accessTokenKey,
      value: tokens['access_token'] as String,
    );
    await _storage.write(
      key: _refreshTokenKey,
      value: tokens['refresh_token'] as String,
    );

    // Cache email from id_token if present.
    final idToken = tokens['id_token'] as String?;
    if (idToken != null) {
      _cachedEmail = _decodeEmailFromIdToken(idToken);
    }
  }

  @override
  Future<String?> currentEmail() async {
    final token = await _storage.read(key: _accessTokenKey);
    if (token == null) return null;
    if (_cachedEmail != null) return _cachedEmail;
    return 'Google Drive';
  }

  @override
  Future<void> disconnect() async {
    final token = await _storage.read(key: _accessTokenKey);
    if (token != null) {
      try {
        await _client.post(
          Uri.https('oauth2.googleapis.com', '/revoke', {'token': token}),
        );
        // ignore: empty_catches — revoke is best-effort; tokens are wiped below
      } catch (_) {}
    }
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }

  @override
  Future<void> upload(Uint8List blob, String filename) async {
    final folderId = await _ensureFolderId();

    final boundary = _generateBoundary();
    final metadataJson = jsonEncode({
      'name': filename,
      'parents': [folderId],
    });

    final bodyBytes = _buildMultipartBody(boundary, metadataJson, blob);
    final headers = {
      'Content-Type': 'multipart/related; boundary=$boundary',
    };

    final res = await _authenticatedRequest(
      () async {
        final token = await _storage.read(key: _accessTokenKey);
        if (token == null) throw const SyncException('Not connected');
        return _client.post(
          Uri.https(
            'www.googleapis.com',
            '/upload/drive/v3/files',
            {'uploadType': 'multipart'},
          ),
          headers: {
            'Authorization': 'Bearer $token',
            ...headers,
          },
          body: bodyBytes,
        );
      },
    );

    if (res.statusCode == 403) {
      if (_isStorageQuotaExceeded(res.body)) {
        throw const InsufficientStorageException();
      }
      throw SyncException('Upload failed: ${res.statusCode}');
    }
    if (res.statusCode != 200) {
      throw SyncException('Upload failed: ${res.statusCode}');
    }
  }

  @override
  Future<Uint8List> download(String filename) async {
    final folderId = await _ensureFolderIdForRead();
    final fileId = await _resolveFileId(folderId, filename);

    final res = await _authenticatedRequest(
      () async {
        final token = await _storage.read(key: _accessTokenKey);
        if (token == null) throw const SyncException('Not connected');
        return _client.get(
          Uri.https(
            'www.googleapis.com',
            '/drive/v3/files/$fileId',
            {'alt': 'media'},
          ),
          headers: {'Authorization': 'Bearer $token'},
        );
      },
    );

    if (res.statusCode != 200) {
      throw SyncException('Download failed: ${res.statusCode}');
    }
    return res.bodyBytes;
  }

  @override
  Future<List<BackupFileEntry>> listFiles() async {
    // Check connection first — throws SyncException if not connected.
    final token = await _storage.read(key: _accessTokenKey);
    if (token == null) throw const SyncException('Not connected');

    // Resolve folder; if folder absent, return empty (FR-11 parity).
    final folderId = await _resolveFolderIdOrNull();
    if (folderId == null) return <BackupFileEntry>[];

    final res = await _authenticatedRequest(
      () async {
        final tok = await _storage.read(key: _accessTokenKey);
        if (tok == null) throw const SyncException('Not connected');
        return _client.get(
          Uri.https('www.googleapis.com', '/drive/v3/files', {
            'q': "'$folderId' in parents and trashed=false",
            'fields': 'files(id,name,modifiedTime,size)',
          }),
          headers: {'Authorization': 'Bearer $tok'},
        );
      },
    );

    if (res.statusCode == 404) return <BackupFileEntry>[];
    if (res.statusCode != 200) {
      throw SyncException('listFiles failed: ${res.statusCode}');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final rawFiles = body['files'] as List<dynamic>;
    final entries = <BackupFileEntry>[];

    for (final f in rawFiles) {
      final map = f as Map<String, dynamic>;
      final name = map['name'] as String;
      if (!name.startsWith(_filePrefix) || !name.endsWith(_fileSuffix)) {
        continue;
      }
      final modifiedTime = map['modifiedTime'] as String;
      final timestamp = DateTime.parse(modifiedTime).toUtc();
      // size may come as String from Drive API.
      final sizeRaw = map['size'];
      final size =
          sizeRaw is int ? sizeRaw : int.parse(sizeRaw as String? ?? '0');
      entries.add(
        BackupFileEntry(name: name, timestampUtc: timestamp, sizeBytes: size),
      );
    }

    // Sort by name descending (matches DropboxProvider convention: newest first).
    entries.sort((a, b) => b.name.compareTo(a.name));
    return entries;
  }

  @override
  Future<void> deleteFile(String filename) async {
    final folderId = await _ensureFolderIdForRead();
    final fileId = await _resolveFileId(folderId, filename);

    final res = await _authenticatedRequest(
      () async {
        final token = await _storage.read(key: _accessTokenKey);
        if (token == null) throw const SyncException('Not connected');
        return _client.delete(
          Uri.https('www.googleapis.com', '/drive/v3/files/$fileId'),
          headers: {'Authorization': 'Bearer $token'},
        );
      },
    );

    if (res.statusCode != 204 && res.statusCode != 200) {
      throw SyncException('Delete failed: ${res.statusCode}');
    }
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  /// Builds the folder-resolution URI with an unencoded `q` parameter so the
  /// literal MIME-type string is preserved in `req.url.toString()` for tests.
  Uri _folderListUri() => Uri(
        scheme: 'https',
        host: 'www.googleapis.com',
        path: '/drive/v3/files',
        query:
            "q=mimeType='application/vnd.google-apps.folder' and name='Metra' and trashed=false"
            '&spaces=drive&fields=files(id,name)',
      );

  /// Resolves and memoizes the Metra folder id, creating it if absent.
  /// Used by upload (must create folder if absent).
  Future<String> _ensureFolderId() async {
    if (_folderId != null) return _folderId!;

    final token = await _storage.read(key: _accessTokenKey);
    if (token == null) throw const SyncException('Not connected');

    final res = await _client.get(
      _folderListUri(),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final files = body['files'] as List<dynamic>;
      if (files.isNotEmpty) {
        _folderId = (files.first as Map<String, dynamic>)['id'] as String;
        return _folderId!;
      }
    }

    // Folder absent — create it.
    final createRes = await _client.post(
      Uri.https('www.googleapis.com', '/drive/v3/files'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': 'Metra',
        'mimeType': 'application/vnd.google-apps.folder',
      }),
    );

    if (createRes.statusCode != 200) {
      throw SyncException('Folder create failed: ${createRes.statusCode}');
    }

    final created = jsonDecode(createRes.body) as Map<String, dynamic>;
    _folderId = created['id'] as String;
    return _folderId!;
  }

  /// Resolves the Metra folder id for read operations; returns `null` if absent.
  /// Does NOT create the folder. Does NOT memoize a null result.
  Future<String?> _resolveFolderIdOrNull() async {
    if (_folderId != null) return _folderId;

    final token = await _storage.read(key: _accessTokenKey);
    if (token == null) return null;

    final res = await _client.get(
      _folderListUri(),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) return null;

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final files = body['files'] as List<dynamic>;
    if (files.isEmpty) return null;

    _folderId = (files.first as Map<String, dynamic>)['id'] as String;
    return _folderId;
  }

  /// Resolves the folder id for read-only operations (download, delete).
  /// Throws SyncException('Not connected') if no access token.
  Future<String> _ensureFolderIdForRead() async {
    if (_folderId != null) return _folderId!;

    final token = await _storage.read(key: _accessTokenKey);
    if (token == null) throw const SyncException('Not connected');

    final resolved = await _resolveFolderIdOrNull();
    if (resolved == null) {
      throw const SyncException('Metra folder not found');
    }
    return resolved;
  }

  /// Resolves a file's Drive id by its name within the given folder.
  Future<String> _resolveFileId(String folderId, String filename) async {
    final token = await _storage.read(key: _accessTokenKey);
    if (token == null) throw const SyncException('Not connected');

    final res = await _client.get(
      Uri.https('www.googleapis.com', '/drive/v3/files', {
        'q': "'$folderId' in parents and name='$filename' and trashed=false",
        'fields': 'files(id,name)',
      }),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      throw SyncException('File resolve failed: ${res.statusCode}');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final files = body['files'] as List<dynamic>;
    if (files.isEmpty) {
      throw SyncException('File not found: $filename');
    }
    return (files.first as Map<String, dynamic>)['id'] as String;
  }

  /// Central 401-refresh-retry wrapper.
  /// Calls [makeRequest]; on a 401 refreshes the access token and retries once.
  Future<http.Response> _authenticatedRequest(
    Future<http.Response> Function() makeRequest,
  ) async {
    var res = await makeRequest();
    if (res.statusCode == 401) {
      await _refreshAccessToken();
      res = await makeRequest();
    }
    return res;
  }

  Future<void> _refreshAccessToken() async {
    final refresh = await _storage.read(key: _refreshTokenKey);
    if (refresh == null) throw const SyncException('No refresh token');

    final res = await _client.post(
      Uri.https('oauth2.googleapis.com', '/token'),
      body: {
        'grant_type': 'refresh_token',
        'refresh_token': refresh,
        'client_id': _clientId,
      },
    );

    if (res.statusCode != 200) {
      throw const SyncException('Refresh failed');
    }

    final tokens = jsonDecode(res.body) as Map<String, dynamic>;
    final access = tokens['access_token'] as String;
    await _storage.write(key: _accessTokenKey, value: access);
  }

  bool _isStorageQuotaExceeded(String responseBody) {
    try {
      final body = jsonDecode(responseBody) as Map<String, dynamic>;
      final error = body['error'] as Map<String, dynamic>?;
      if (error == null) return false;
      final errors = error['errors'] as List<dynamic>?;
      if (errors == null) return false;
      for (final e in errors) {
        final map = e as Map<String, dynamic>;
        if (map['reason'] == 'storageQuotaExceeded') return true;
      }
    } catch (_) {}
    return false;
  }

  String? _decodeEmailFromIdToken(String idToken) {
    try {
      final parts = idToken.split('.');
      if (parts.length < 2) return null;
      // Base64url-decode the payload (pad as needed).
      var payload = parts[1];
      final mod = payload.length % 4;
      if (mod == 2) {
        payload += '==';
      } else if (mod == 3) {
        payload += '=';
      }
      final decoded = utf8.decode(base64Url.decode(payload));
      final claims = jsonDecode(decoded) as Map<String, dynamic>;
      return claims['email'] as String?;
    } catch (_) {
      return null;
    }
  }

  Uint8List _buildMultipartBody(
    String boundary,
    String metadataJson,
    Uint8List blob,
  ) {
    final metadataPart = '--$boundary\r\n'
        'Content-Type: application/json; charset=UTF-8\r\n'
        '\r\n'
        '$metadataJson\r\n';
    final blobPartHeader = '--$boundary\r\n'
        'Content-Type: application/octet-stream\r\n'
        '\r\n';
    final closing = '\r\n--$boundary--\r\n';

    final metadataBytes = utf8.encode(metadataPart);
    final blobHeaderBytes = utf8.encode(blobPartHeader);
    final closingBytes = utf8.encode(closing);

    final total = metadataBytes.length +
        blobHeaderBytes.length +
        blob.length +
        closingBytes.length;
    final result = Uint8List(total);
    var offset = 0;
    result.setAll(offset, metadataBytes);
    offset += metadataBytes.length;
    result.setAll(offset, blobHeaderBytes);
    offset += blobHeaderBytes.length;
    result.setAll(offset, blob);
    offset += blob.length;
    result.setAll(offset, closingBytes);
    return result;
  }

  String _generateBoundary() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(24, (_) => chars[_random.nextInt(chars.length)])
        .join();
  }

  String _generateOauthState() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  String _generateCodeVerifier() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    return List.generate(64, (_) => chars[_random.nextInt(chars.length)])
        .join();
  }

  String _codeChallenge(String verifier) {
    final digest = sha256.convert(utf8.encode(verifier)).bytes;
    return base64Url
        .encode(digest)
        .replaceAll('=', '')
        .replaceAll('+', '-')
        .replaceAll('/', '_');
  }
}
