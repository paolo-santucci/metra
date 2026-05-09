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

// Tests for TASK-02 (sp-20260509-android-ios-prerelease-bugs):
//   - FR-09 / BUG-C02: release-blocker — INTERNET permission must be declared
//     in the main AndroidManifest.xml (not just in the debug overlay), or
//     every release APK throws SocketException on every Dropbox HTTP call.
//   - FR-08 / BUG-C01: KeepAliveService must be exported (android:exported=
//     "true"), otherwise Chrome's cross-UID bindService during OAuth fails
//     and the OS OOM-killer terminates Métra mid-OAuth on real devices
//     (the emulator masks this behaviour).
//
// Note: REQUEST_IGNORE_BATTERY_OPTIMIZATIONS was removed (qp-20260509) when
// the "Pianificazione in background" Settings row was removed. The permission
// is no longer used. Its test has been removed accordingly.
//
// These assertions read the manifest as text and use `contains` checks.
// No XML parser dependency is required.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AndroidManifest.xml — TASK-02 release-blocker assertions', () {
    late final String manifest;

    setUpAll(() {
      manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
    });

    test(
      'declares INTERNET permission (FR-09 / BUG-C02 — release-blocker)',
      () {
        expect(
          manifest.contains(
            '<uses-permission android:name="android.permission.INTERNET"/>',
          ),
          isTrue,
          reason: 'INTERNET permission missing from main AndroidManifest.xml. '
              'Without it, every release APK throws SocketException on every '
              'Dropbox HTTP call. Currently declared only in the debug overlay '
              '(android/app/src/debug/AndroidManifest.xml), which masks the '
              'defect in debug builds.',
        );
      },
    );

    test(
      'KeepAliveService is exported=true (FR-08 / BUG-C01)',
      () {
        // Locate the KeepAliveService line and assert it is exported=true,
        // not exported=false. Chrome's cross-UID bindService during OAuth
        // requires the service to be exported; otherwise the OS treats Métra
        // as not in-use and the OOM-killer terminates the process mid-OAuth
        // on real devices. The emulator masks this behaviour.
        final keepAliveLines = manifest
            .split('\n')
            .where((line) => line.contains('KeepAliveService'))
            .toList();
        expect(
          keepAliveLines,
          isNotEmpty,
          reason: 'KeepAliveService declaration not found in manifest.',
        );
        for (final line in keepAliveLines) {
          expect(
            line.contains('android:exported="true"'),
            isTrue,
            reason:
                'KeepAliveService must be exported=true so Chrome\'s cross-UID '
                'bindService during OAuth succeeds. Line: $line',
          );
          expect(
            line.contains('android:exported="false"'),
            isFalse,
            reason: 'KeepAliveService must NOT be exported=false. Line: $line',
          );
        }
      },
    );
  });
}
