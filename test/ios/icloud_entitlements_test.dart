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
import 'package:flutter_test/flutter_test.dart';

/// Group G: iOS iCloud entitlements wiring verification (FR-08, FR-09)
/// Tests that Runner.entitlements exists with the four required keys
/// and that CODE_SIGN_ENTITLEMENTS is wired correctly in project.pbxproj.
void main() {
  group('iOS iCloud entitlements (FR-08, FR-09)', () {
    late File entitlementsFile;
    late File pbxprojFile;
    late String entitlementsContent;
    late String pbxprojContent;

    setUpAll(() {
      entitlementsFile = File('ios/Runner/Runner.entitlements');
      pbxprojFile = File('ios/Runner.xcodeproj/project.pbxproj');
    });

    setUp(() {
      if (entitlementsFile.existsSync()) {
        entitlementsContent = entitlementsFile.readAsStringSync();
      } else {
        entitlementsContent = '';
      }
      if (pbxprojFile.existsSync()) {
        pbxprojContent = pbxprojFile.readAsStringSync();
      } else {
        pbxprojContent = '';
      }
    });

    test('Runner.entitlements exists', () {
      // FR-08: ios/Runner/Runner.entitlements file must exist
      expect(entitlementsFile.existsSync(), isTrue);
    });

    test(
      'Runner.entitlements contains icloud-container-identifiers key',
      () {
        // FR-08: Must declare icloud-container-identifiers with the iOS container id
        expect(
          entitlementsContent,
          contains('com.apple.developer.icloud-container-identifiers'),
        );
        // Must use iOS bundle id (com.paolosantucci.metra), not Android metraapp
        expect(
          entitlementsContent,
          contains('iCloud.com.paolosantucci.metra'),
        );
      },
    );

    test(
      'Runner.entitlements contains ubiquity-container-identifiers key',
      () {
        // FR-08: Must declare ubiquity-container-identifiers with the iOS container id
        expect(
          entitlementsContent,
          contains('com.apple.developer.ubiquity-container-identifiers'),
        );
        expect(
          entitlementsContent,
          contains('iCloud.com.paolosantucci.metra'),
        );
      },
    );

    test(
      'Runner.entitlements contains icloud-services key',
      () {
        // FR-08: Must declare icloud-services as [CloudDocuments]
        expect(
          entitlementsContent,
          contains('com.apple.developer.icloud-services'),
        );
        expect(
          entitlementsContent,
          contains('CloudDocuments'),
        );
      },
    );

    test(
      'Runner.entitlements contains icloud-container-environment key',
      () {
        // FR-08: Must declare icloud-container-environment as Production
        expect(
          entitlementsContent,
          contains('com.apple.developer.icloud-container-environment'),
        );
        expect(
          entitlementsContent,
          contains('Production'),
        );
      },
    );

    test(
      'Runner.entitlements has exactly 4 keys and no Android metraapp suffix',
      () {
        // FR-08/FR-08-neg: Must have exactly 4 keys and no Android suffix
        final keyMatches =
            RegExp(r'<key>').allMatches(entitlementsContent).length;
        expect(keyMatches, equals(4));
        expect(
          entitlementsContent.contains('metraapp'),
          isFalse,
        );
      },
    );

    test(
      'project.pbxproj has CODE_SIGN_ENTITLEMENTS in Debug config (97C147061)',
      () {
        // FR-09: Debug config must have CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;
        // Extract the Debug config block (97C147061) and verify CODE_SIGN_ENTITLEMENTS
        final debugMatch = RegExp(
          r'97C147061CF9000F007C117D\s*/\*\s*Debug\s*\*/\s*=\s*\{[^}]*buildSettings\s*=\s*\{[^}]*?CODE_SIGN_ENTITLEMENTS\s*=\s*Runner/Runner\.entitlements;',
          dotAll: true,
        ).firstMatch(pbxprojContent);
        expect(debugMatch, isNotNull);
      },
    );

    test(
      'project.pbxproj has CODE_SIGN_ENTITLEMENTS in Release config (97C147071)',
      () {
        // FR-09: Release config must have CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;
        final releaseMatch = RegExp(
          r'97C147071CF9000F007C117D\s*/\*\s*Release\s*\*/\s*=\s*\{[^}]*buildSettings\s*=\s*\{[^}]*?CODE_SIGN_ENTITLEMENTS\s*=\s*Runner/Runner\.entitlements;',
          dotAll: true,
        ).firstMatch(pbxprojContent);
        expect(releaseMatch, isNotNull);
      },
    );

    test(
      'project.pbxproj has CODE_SIGN_ENTITLEMENTS in Profile config (249021D4)',
      () {
        // FR-09: Profile config must have CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;
        final profileMatch = RegExp(
          r'249021D4217E4FDB00AE95B9\s*/\*\s*Profile\s*\*/\s*=\s*\{[^}]*buildSettings\s*=\s*\{[^}]*?CODE_SIGN_ENTITLEMENTS\s*=\s*Runner/Runner\.entitlements;',
          dotAll: true,
        ).firstMatch(pbxprojContent);
        expect(profileMatch, isNotNull);
      },
    );

    test(
      'project.pbxproj does NOT have CODE_SIGN_ENTITLEMENTS in RunnerTests Debug (331C8088)',
      () {
        // FR-09-neg: RunnerTests configs must NOT have CODE_SIGN_ENTITLEMENTS
        // Extract the 331C8088 (RunnerTests Debug) block and verify no CODE_SIGN_ENTITLEMENTS
        final match = RegExp(
          r'331C8088294A63A400263BE5\s*/\*\s*Debug\s*\*/\s*=\s*\{([^}]*name\s*=\s*Debug;)?',
          dotAll: true,
        );
        final block = match.firstMatch(pbxprojContent)?.group(0) ?? '';
        expect(
          block.contains('CODE_SIGN_ENTITLEMENTS'),
          isFalse,
        );
      },
    );

    test(
      'project.pbxproj does NOT have CODE_SIGN_ENTITLEMENTS in RunnerTests Release (331C8089)',
      () {
        // FR-09-neg: RunnerTests Release must NOT have CODE_SIGN_ENTITLEMENTS
        final match = RegExp(
          r'331C8089294A63A400263BE5\s*/\*\s*Release\s*\*/\s*=\s*\{([^}]*name\s*=\s*Release;)?',
          dotAll: true,
        );
        final block = match.firstMatch(pbxprojContent)?.group(0) ?? '';
        expect(
          block.contains('CODE_SIGN_ENTITLEMENTS'),
          isFalse,
        );
      },
    );

    test(
      'project.pbxproj does NOT have CODE_SIGN_ENTITLEMENTS in RunnerTests Profile (331C808A)',
      () {
        // FR-09-neg: RunnerTests Profile must NOT have CODE_SIGN_ENTITLEMENTS
        final match = RegExp(
          r'331C808A294A63A400263BE5\s*/\*\s*Profile\s*\*/\s*=\s*\{([^}]*name\s*=\s*Profile;)?',
          dotAll: true,
        );
        final block = match.firstMatch(pbxprojContent)?.group(0) ?? '';
        expect(
          block.contains('CODE_SIGN_ENTITLEMENTS'),
          isFalse,
        );
      },
    );
  });
}
