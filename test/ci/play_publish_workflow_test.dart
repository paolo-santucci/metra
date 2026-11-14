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

// Guards for .github/workflows/android-play.yml — the Play Store publishing
// workflow. Three properties are load-bearing and easy to lose in a later edit:
//
//   * it is manual-only, so no push or tag can put a build on Play by accident
//     (a v* tag means "upload iOS to TestFlight", see ios.yml);
//   * it refuses to run without the Play credential *and* the release keystore,
//     because the Gradle fallback silently produces a debug-signed bundle that
//     Play rejects;
//   * the third-party publish action is pinned to an exact version.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('android-play.yml publishing guards', () {
    late String content;

    setUpAll(() {
      content = File(
        '.github/workflows/android-play.yml',
      ).readAsStringSync();
    });

    test('is manual-only: no push and no tag trigger', () {
      expect(
        content,
        contains('workflow_dispatch:'),
        reason: 'the publish workflow must be manually dispatchable',
      );
      expect(
        content,
        isNot(contains('push:')),
        reason: 'a push trigger would publish on every merge to main',
      );
      expect(
        content,
        isNot(contains('tags:')),
        reason: 'a v* tag already means "iOS TestFlight"; Android must '
            'never piggyback on it',
      );
      expect(content, isNot(contains('schedule:')));
    });

    test('defaults to the internal testing track', () {
      expect(
        content,
        contains("default: 'internal'"),
        reason: 'the default track must be the test environment, not '
            'production — publishing to production is always an explicit '
            'choice',
      );
      for (final track in ['internal', 'alpha', 'beta', 'production']) {
        expect(
          content,
          contains('          - $track'),
          reason: 'track choice $track must be offered',
        );
      }
    });

    test('fails fast when the Play credential or keystore is missing', () {
      expect(content, contains('secrets.PLAY_SERVICE_ACCOUNT_JSON'));
      expect(content, contains('secrets.KEYSTORE_BASE64'));

      final preflight = content.substring(
        content.indexOf('Preflight'),
        content.indexOf('Setup Java'),
      );
      expect(
        preflight,
        contains('exit "\$missing"'),
        reason: 'the preflight must exit non-zero, not just warn',
      );
    });

    test('publishes the signed AAB for the Métra application id', () {
      expect(content, contains('com.paolosantucci.metraapp'));
      expect(
        content,
        contains(
          'releaseFiles: build/app/outputs/bundle/release/'
          'com.paolosantucci.metraapp-release.aab',
        ),
      );
      expect(
        content,
        contains('build appbundle --release'),
        reason: 'Play takes an AAB, never an APK',
      );
      expect(
        content,
        contains('flutter pub get --enforce-lockfile'),
        reason: 'a published build must match the committed lockfile',
      );
    });

    test('verifies the AAB is signed before uploading', () {
      expect(
        content,
        contains('jarsigner -verify'),
        reason: 'an unsigned or debug-signed AAB is rejected by Play only '
            'after a slow upload',
      );
      expect(
        content.indexOf('jarsigner -verify'),
        lessThan(content.indexOf('upload-google-play')),
        reason: 'signature verification must run before the publish step',
      );
    });

    test('third-party publish action is pinned to an exact version', () {
      final pinned = RegExp(
        r'r0adkll/upload-google-play@v\d+\.\d+\.\d+',
      );
      expect(
        pinned.hasMatch(content),
        isTrue,
        reason: 'pin the publish action to a release tag, never a floating '
            'major (supply chain: it receives the Play service account key)',
      );
    });

    test('runs inside the play-test environment', () {
      expect(content, contains('environment: play-test'));
    });

    test('flutter version stays in lockstep with quality.yml', () {
      final quality = File('.github/workflows/quality.yml').readAsStringSync();
      final pin = RegExp(
        r"flutter-version: '([^']+)'",
      ).firstMatch(quality);
      expect(pin, isNotNull, reason: 'quality.yml must pin a flutter-version');
      expect(
        content,
        contains("flutter-version: '${pin!.group(1)}'"),
        reason: 'AGENTS.md requires every workflow to pin the same Flutter '
            'version',
      );
    });
  });
}
