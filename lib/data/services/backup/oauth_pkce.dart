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

/// PKCE (Proof Key for Code Exchange) helpers shared by the OAuth-based
/// cloud backup providers (Google Drive, Dropbox).
///
/// Extracted verbatim from the providers' previously-duplicated private
/// methods. Callers are responsible for supplying a cryptographically
/// secure [Random] (e.g. `Random.secure()`) — there is no default so the
/// choice stays explicit at the call site.
library;

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Generates a random CSRF-protection `state` value: 16 random bytes
/// rendered as a 32-character lowercase hex string.
String generateOauthState(Random random) {
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// Generates a PKCE `code_verifier`: 64 characters drawn from the
/// unreserved character set allowed by RFC 7636 (`A-Z`, `a-z`, `0-9`, `-`,
/// `.`, `_`, `~`).
String generateCodeVerifier(Random random) {
  const chars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
  return List.generate(64, (_) => chars[random.nextInt(chars.length)]).join();
}

/// Derives the PKCE `code_challenge` (S256 method) from a `code_verifier`:
/// the SHA-256 digest, base64url-encoded with padding stripped.
///
/// `base64Url.encode` already emits the URL-safe alphabet (`-`/`_` instead
/// of `+`/`/`), so no further character substitution is required.
String codeChallenge(String verifier) {
  final digest = sha256.convert(utf8.encode(verifier)).bytes;
  return base64Url.encode(digest).replaceAll('=', '');
}
