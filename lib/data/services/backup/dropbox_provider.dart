// Copyright (C) 2026 Paolo Santucci
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
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;

import '../../../core/errors/metra_exception.dart';

abstract class CloudBackupProvider {
  Future<void> upload(Uint8List blob, String filename);
  Future<Uint8List> download(String filename);
  Future<List<String>> listFiles();
  Future<void> deleteFile(String filename);
}

class DropboxProvider implements CloudBackupProvider {
  DropboxProvider({
    required String appKey,
    FlutterSecureStorage? storage,
    http.Client? client,
    Future<String> Function(String url, {required String callbackUrlScheme})?
        webAuth,
    Random? random,
  })  : _appKey = appKey,
        _storage = storage ?? const FlutterSecureStorage(),
        _client = client ?? http.Client(),
        _webAuth = webAuth ?? _defaultWebAuth,
        _random = random ?? Random.secure();

  static const _accessTokenKey = 'metra_dropbox_access_token_v1';
  static const _refreshTokenKey = 'metra_dropbox_refresh_token_v1';
  // App-folder access: the Dropbox app console is set to "App folder" type,
  // so all paths are relative to /Apps/<AppName>/ — root is '' and files are
  // '/<filename>'. This also eliminates the Latin-1 encoding concern that
  // required the former ASCII-only absolute path.
  static const _filePrefix = 'metra_backup_';
  static const _fileSuffix = '.enc';
  static const _redirectUri = 'metra://oauth-callback';

  final String _appKey;
  final FlutterSecureStorage _storage;
  final http.Client _client;
  final Future<String> Function(String url, {required String callbackUrlScheme})
      _webAuth;
  final Random _random;

  // Holds the CSRF state token generated at the start of each authorize() call.
  // Compared against the value returned in the OAuth callback to detect CSRF.
  String? _oauthState;

  static Future<String> _defaultWebAuth(
    String url, {
    required String callbackUrlScheme,
  }) =>
      FlutterWebAuth2.authenticate(
        url: url,
        callbackUrlScheme: callbackUrlScheme,
      );

  Future<bool> get isConnected async =>
      (await _storage.read(key: _accessTokenKey)) != null;

  Future<void> authorize() async {
    final verifier = _generateCodeVerifier();
    final challenge = _codeChallenge(verifier);
    _oauthState = _generateOauthState();
    final authUrl = Uri.https('www.dropbox.com', '/oauth2/authorize', {
      'client_id': _appKey,
      'response_type': 'code',
      'redirect_uri': _redirectUri,
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
      'token_access_type': 'offline',
      'state': _oauthState!,
    });
    final result =
        await _webAuth(authUrl.toString(), callbackUrlScheme: 'metra');
    final callbackParams = Uri.parse(result).queryParameters;
    final returnedState = callbackParams['state'];
    if (returnedState != _oauthState) {
      throw const SyncException('OAuth state mismatch — possible CSRF attack');
    }
    final code = callbackParams['code'];
    if (code == null) {
      throw const SyncException('OAuth callback missing code');
    }
    final tokenRes = await _client.post(
      Uri.https('api.dropbox.com', '/oauth2/token'),
      body: {
        'code': code,
        'grant_type': 'authorization_code',
        'client_id': _appKey,
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
  }

  Future<String?> currentEmail() async {
    final token = await _storage.read(key: _accessTokenKey);
    if (token == null) return null;
    final res = await _authenticatedPost(
      Uri.https('api.dropboxapi.com', '/2/users/get_current_account'),
      body: 'null',
      headers: {'Content-Type': 'application/json'},
    );
    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data['email'] as String?;
  }

  Future<void> disconnect() async {
    final token = await _storage.read(key: _accessTokenKey);
    if (token != null) {
      try {
        await _authenticatedPost(
          Uri.https('api.dropboxapi.com', '/2/auth/token/revoke'),
          body: 'null',
          headers: {'Content-Type': 'application/json'},
        );
        // ignore: empty_catches — revoke is best-effort; token is wiped below
      } catch (_) {}
    }
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }

  @override
  Future<void> upload(Uint8List blob, String filename) async {
    final res = await _authenticatedPost(
      Uri.https('content.dropboxapi.com', '/2/files/upload'),
      bodyBytes: blob,
      headers: {
        'Content-Type': 'application/octet-stream',
        'Dropbox-API-Arg': jsonEncode({
          'path': '/$filename',
          'mode': 'overwrite',
          'mute': true,
        }),
      },
    );
    if (res.statusCode != 200) {
      throw SyncException('Upload failed: ${res.statusCode}');
    }
  }

  @override
  Future<Uint8List> download(String filename) async {
    final res = await _authenticatedPost(
      Uri.https('content.dropboxapi.com', '/2/files/download'),
      body: '',
      headers: {
        'Dropbox-API-Arg': jsonEncode({'path': '/$filename'}),
      },
    );
    if (res.statusCode != 200) {
      throw SyncException('Download failed: ${res.statusCode}');
    }
    return res.bodyBytes;
  }

  @override
  Future<List<String>> listFiles() async {
    final res = await _authenticatedPost(
      Uri.https('api.dropboxapi.com', '/2/files/list_folder'),
      body: jsonEncode({'path': ''}),
      headers: {'Content-Type': 'application/json'},
    );
    if (res.statusCode == 409) {
      // 409 path/not_found means the folder doesn't exist yet — treat as empty.
      return [];
    }
    if (res.statusCode != 200) {
      throw SyncException('List failed: ${res.statusCode}');
    }
    var data = jsonDecode(res.body) as Map<String, dynamic>;
    final entries = (data['entries'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .toList();
    while (data['has_more'] == true) {
      final continueRes = await _authenticatedPost(
        Uri.parse('https://api.dropboxapi.com/2/files/list_folder/continue'),
        body: jsonEncode({'cursor': data['cursor'] as String}),
        headers: {'Content-Type': 'application/json'},
      );
      if (continueRes.statusCode != 200) {
        break; // best-effort; partial list is acceptable
      }
      final nextData = jsonDecode(continueRes.body) as Map<String, dynamic>;
      entries.addAll(
        (nextData['entries'] as List<dynamic>).cast<Map<String, dynamic>>(),
      );
      data = nextData;
    }
    return entries
        .where((e) => e['.tag'] == 'file')
        .map((e) => e['name'] as String)
        .where((n) => n.startsWith(_filePrefix) && n.endsWith(_fileSuffix))
        .toList()
      ..sort((a, b) => b.compareTo(a));
  }

  @override
  Future<void> deleteFile(String filename) async {
    final res = await _authenticatedPost(
      Uri.https('api.dropboxapi.com', '/2/files/delete_v2'),
      body: jsonEncode({'path': '/$filename'}),
      headers: {'Content-Type': 'application/json'},
    );
    if (res.statusCode != 200) {
      throw SyncException('Delete failed: ${res.statusCode}');
    }
  }

  Future<http.Response> _authenticatedPost(
    Uri uri, {
    Object? body,
    Uint8List? bodyBytes,
    Map<String, String>? headers,
  }) async {
    Future<http.Response> doPost(String token) async {
      final h = {'Authorization': 'Bearer $token', ...?headers};
      if (bodyBytes != null) {
        return _client.post(uri, headers: h, body: bodyBytes);
      }
      return _client.post(uri, headers: h, body: body);
    }

    var token = await _storage.read(key: _accessTokenKey);
    if (token == null) throw const SyncException('Not connected');
    var res = await doPost(token);
    if (res.statusCode == 401) {
      token = await _refreshAccessToken();
      res = await doPost(token);
    }
    return res;
  }

  Future<String> _refreshAccessToken() async {
    final refresh = await _storage.read(key: _refreshTokenKey);
    if (refresh == null) throw const SyncException('No refresh token');
    final res = await _client.post(
      Uri.https('api.dropbox.com', '/oauth2/token'),
      body: {
        'grant_type': 'refresh_token',
        'refresh_token': refresh,
        'client_id': _appKey,
      },
    );
    if (res.statusCode != 200) {
      throw const SyncException('Refresh failed');
    }
    final tokens = jsonDecode(res.body) as Map<String, dynamic>;
    final access = tokens['access_token'] as String;
    await _storage.write(key: _accessTokenKey, value: access);
    return access;
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
