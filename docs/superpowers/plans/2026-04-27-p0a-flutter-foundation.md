# P-0a Flutter Foundation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Install Flutter + Android SDK on Fedora 43, scaffold the Métra project, import design tokens as Dart constants, and ship a running 4-tab navigation shell.

**Architecture:** Layered Flutter app (`UI → Domain → Data`); 4-tab bottom navigation via `go_router` shell route; `MaterialApp` wired to `MetraTheme` (light + dark); all design tokens as `const` Dart values sourced from `mockup/tokens.json`.

**Tech Stack:** Flutter stable (≥3.19), Dart null-safe, `go_router ^14.2.7`, `google_fonts ^6.2.1`, `flutter_riverpod ^2.5.1`, `riverpod_annotation ^2.3.5`, `build_runner ^2.4.11`, `flutter_lints ^4.0.0`.

**Scope note:** This is sub-plan P-0a of a four-part Phase 0. P-0b covers the encrypted DB + EncryptionService; P-0c covers security documentation; P-0d covers CI/CD pipelines. The DoD for the full Phase 0 gate requires all four complete. This plan's DoD is: `flutter run` shows 4 empty tabs on the Android emulator, `flutter test` and `flutter analyze` both pass clean.

---

## File structure

**Created by this plan:**

```
pubspec.yaml                              # all §3 deps
analysis_options.yaml                     # lints: avoid_print, prefer_const, etc.
lib/
  main.dart                               # entry point
  app.dart                                # MaterialApp + MetraTheme + go_router
  core/
    constants/
      app_constants.dart                  # tap target sizes, layout constants
    theme/
      metra_colors.dart                   # MetraColors (light + dark palettes)
      metra_typography.dart               # MetraTypography (DM Serif Display + Inter)
      metra_spacing.dart                  # MetraSpacing + MetraRadius + MetraMotion
      metra_theme.dart                    # MetraTheme.light() / MetraTheme.dark()
  router/
    app_router.dart                       # go_router ShellRoute, 4 tabs
  features/
    calendar/
      calendar_screen.dart               # empty scaffold
    timeline/
      timeline_screen.dart               # empty scaffold
    stats/
      stats_screen.dart                  # empty scaffold
    settings/
      settings_screen.dart               # empty scaffold
test/
  core/
    theme/
      metra_colors_test.dart             # palette contract tests
      metra_theme_test.dart              # theme renders without error
  features/
    navigation/
      navigation_test.dart              # 4 tabs visible, navigation works
```

**Not in this plan (future P-0b / P-0c / P-0d):**
- `lib/data/` (Drift schema, EncryptionService) → P-0b
- Security docs in `docs/security/` → P-0c
- `.github/workflows/` → P-0d

---

## Task 1: Install Flutter SDK

**Files:** none (environment setup only)

**Context:** Flutter is not installed on this Fedora 43 x86_64 machine. The official approach is `git clone` from the stable branch.

- [ ] **Step 1: Clone Flutter stable**

```bash
mkdir -p ~/development
git clone https://github.com/flutter/flutter.git -b stable ~/development/flutter
```

Expected: clones ~1 GB (takes 2–5 minutes on a normal connection), no errors.

- [ ] **Step 2: Add Flutter to PATH permanently**

Add to `~/.bashrc` (or `~/.zshrc` if using zsh):

```bash
echo 'export PATH="$HOME/development/flutter/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

- [ ] **Step 3: Run flutter doctor**

```bash
flutter doctor
```

Expected output includes (some ✗ are OK at this stage — Android toolchain will be set up in Task 2):

```
[✓] Flutter (Channel stable, 3.x.x, ...)
[✗] Android toolchain - develop for Android devices (Android SDK is missing)
[!] Linux toolchain - develop for Linux desktop
[✓] VS Code (optional)
[✗] Connected device (none available)
```

If `Flutter` row is ✗, diagnose before continuing. Common fix on Fedora:
```bash
sudo dnf install -y git curl unzip xz zip clang cmake ninja-build pkg-config libgtk-3-dev
```

---

## Task 2: Install Android SDK + create AVD

**Files:** none (environment setup only)

**Context:** No Android SDK or AVD on this machine. Using Android cmdline-tools (no Android Studio required).

- [ ] **Step 1: Download Android cmdline-tools**

Go to https://developer.android.com/studio#downloads, scroll to "Command line tools only", download the Linux zip. As of 2026-04, the file is named `commandlinetools-linux-<number>_latest.zip`. Save to `~/Downloads/`.

```bash
mkdir -p ~/Android/Sdk/cmdline-tools
cd ~/Android/Sdk/cmdline-tools
# Replace <number> with the actual build number from the downloaded file:
unzip ~/Downloads/commandlinetools-linux-<number>_latest.zip
# The zip extracts a folder named "cmdline-tools". Rename it to "latest":
mv cmdline-tools latest
```

- [ ] **Step 2: Set ANDROID_HOME + add tools to PATH**

```bash
cat >> ~/.bashrc << 'EOF'
export ANDROID_HOME="$HOME/Android/Sdk"
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"
EOF
source ~/.bashrc
```

- [ ] **Step 3: Accept licenses + install SDK components**

```bash
sdkmanager --licenses    # accept all (type 'y' repeatedly)
sdkmanager "platform-tools" "emulator" \
           "platforms;android-35" \
           "build-tools;35.0.0" \
           "system-images;android-35;google_apis;x86_64"
```

Expected: each package downloads and installs without error.

- [ ] **Step 4: Create an AVD**

```bash
avdmanager create avd \
  --name Pixel_7_API35 \
  --package "system-images;android-35;google_apis;x86_64" \
  --device "pixel_7"
```

Expected: `AVD 'Pixel_7_API35' created with config...`

- [ ] **Step 5: Run flutter doctor again — Android toolchain must be ✓**

```bash
flutter doctor
```

Expected:

```
[✓] Flutter (Channel stable, ...)
[✓] Android toolchain - develop for Android devices (Android SDK version 35.0.0)
[✓] Connected device (Emulator: Pixel 7 API 35)
```

If `[!] Android toolchain` appears instead of `[✓]`, run:
```bash
flutter doctor --android-licenses
```

Do not proceed to Task 3 until this row is `[✓]`.

---

## Task 3: Create Flutter project in the worktree

**Files:** `pubspec.yaml` (initial), `lib/main.dart`, `analysis_options.yaml` (flutter default)

**Context:** The worktree at the repo root already contains `CLAUDE.md`, `LICENSE`, `mockup/`. We create the Flutter project in place — not in a subdirectory.

- [ ] **Step 1: Initialise Flutter project**

```bash
cd /home/paolo/Sviluppo/metra/.claude/worktrees/tender-kilby-912687
flutter create . \
  --project-name metra \
  --org com.paolosantucci \
  --platforms android,ios \
  --empty
```

`--empty` creates a minimal `main.dart` with just a `MaterialApp`. Expected: Flutter creates `lib/main.dart`, `android/`, `ios/`, `test/`, `pubspec.yaml`.

- [ ] **Step 2: Verify it builds**

Start the emulator in the background:
```bash
emulator -avd Pixel_7_API35 -no-audio &
# Wait ~30 seconds for the emulator to boot
```

Then:
```bash
flutter run --no-pub
```

Expected: app launches on the emulator with a blank Material screen. Press `q` to quit.

- [ ] **Step 3: Remove default counter example test**

```bash
rm test/widget_test.dart
```

- [ ] **Step 4: Commit initial scaffold**

```bash
git add pubspec.yaml pubspec.lock lib/ android/ ios/ test/ analysis_options.yaml .gitignore
git commit -m "chore: flutter create scaffold (Métra, com.paolosantucci)"
```

---

## Task 4: Replace pubspec.yaml with full dependency set

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Replace pubspec.yaml**

```yaml
name: metra
description: "Métra — privacy-first menstrual cycle tracker."
publish_to: none
version: 0.1.0+1

environment:
  sdk: ">=3.3.0 <4.0.0"

dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter

  # State management
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5

  # Routing
  go_router: ^14.2.7

  # Fonts
  google_fonts: ^6.2.1

  # Local DB (added in P-0b)
  # drift: ^2.18.0
  # drift_flutter: ^0.2.0

  # DB encryption (added in P-0b)
  # sqlcipher_flutter_libs: ^0.5.4

  # Cryptography (added in P-0b)
  # cryptography: ^2.7.0

  # Keychain (added in P-0b)
  # flutter_secure_storage: ^9.2.2

  # Charts (added in P-2)
  # fl_chart: ^0.68.0

  # Notifications (added in P-3)
  # flutter_local_notifications: ^17.2.2
  # flutter_timezone: ^3.0.0

  # Device calendar (added in P-5)
  # device_calendar: ^4.3.1

  # Cloud sync auth (added in P-6)
  # google_sign_in: ^6.2.1
  # googleapis: ^13.2.0
  # http: ^1.2.2

  # Export/share (added in P-5)
  # file_picker: ^8.1.2
  # share_plus: ^10.0.2
  # csv: ^6.0.0

  # i18n
  intl: ^0.19.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
  riverpod_generator: ^2.4.3
  build_runner: ^2.4.11

flutter:
  uses-material-design: true
  generate: true   # enables gen_l10n
```

- [ ] **Step 2: Fetch dependencies**

```bash
flutter pub get
```

Expected: resolves without version conflicts. If there are conflicts, run `flutter pub outdated` and bump the conflicting constraint.

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add P-0a dependencies (riverpod, go_router, google_fonts, intl)"
```

---

## Task 5: Harden analysis_options.yaml

**Files:**
- Modify: `analysis_options.yaml`

- [ ] **Step 1: Replace analysis_options.yaml**

```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true
  errors:
    missing_required_param: error
    missing_return: error
    todo: warning

linter:
  rules:
    # Style
    prefer_const_constructors: true
    prefer_const_declarations: true
    prefer_const_literals_to_create_immutables: true
    require_trailing_commas: true
    # Safety
    avoid_print: true
    avoid_dynamic_calls: true
    avoid_type_to_string: true
    cancel_subscriptions: true
    close_sinks: true
    # Dart idioms
    use_super_parameters: true
    use_string_buffers: true
    unnecessary_lambdas: true
    prefer_final_locals: true
    prefer_final_in_for_each: true
```

- [ ] **Step 2: Run analyzer — must be clean**

```bash
flutter analyze
```

Expected: `No issues found!`

If `avoid_print` fires on the default `main.dart`, replace the `print` call with a comment placeholder — we'll wire a real logger in P-0b.

- [ ] **Step 3: Commit**

```bash
git add analysis_options.yaml lib/main.dart
git commit -m "chore: harden analysis_options.yaml (strict mode, avoid_print, prefer_const)"
```

---

## Task 6: GPL-3.0 header script

**Files:**
- Create: `tools/add_license_header.sh`

**Context:** Every Dart source file must carry the GPL-3.0 header (CLAUDE.md §3). This script stamps it on any file that is missing it.

- [ ] **Step 1: Create the script**

```bash
#!/usr/bin/env bash
# Stamps GPL-3.0 header on Dart files missing it.
HEADER="// Copyright (C) $(date +%Y)  Paolo Santucci
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
"

find lib test -name "*.dart" | while read -r file; do
  if ! head -1 "$file" | grep -q "Copyright"; then
    echo "Stamping $file"
    printf '%s\n' "$HEADER" | cat - "$file" > /tmp/metra_hdr && mv /tmp/metra_hdr "$file"
  fi
done
```

Save as `tools/add_license_header.sh`.

- [ ] **Step 2: Make executable and run**

```bash
mkdir -p tools
chmod +x tools/add_license_header.sh
./tools/add_license_header.sh
```

Expected: prints `Stamping lib/main.dart` (and any other existing files). No errors.

- [ ] **Step 3: Verify header in main.dart**

```bash
head -3 lib/main.dart
```

Expected:
```
// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
```

- [ ] **Step 4: Analyze + commit**

```bash
flutter analyze
git add tools/ lib/
git commit -m "chore: GPL-3.0 header script + stamp existing Dart files"
```

---

## Task 7: Scaffold lib/ directory structure

**Files:**
- Create: all placeholder files listed in the File Structure section

**Context:** We create the directory tree now so that later tasks can import across modules without finding missing files.

- [ ] **Step 1: Create placeholder files**

Run these one by one (they are short enough to write inline):

```bash
mkdir -p lib/core/constants lib/core/theme lib/core/errors lib/core/utils lib/router
mkdir -p lib/features/calendar lib/features/timeline lib/features/stats lib/features/settings
mkdir -p lib/features/daily_entry lib/features/backup
mkdir -p lib/l10n
mkdir -p lib/data/database/daos lib/data/services/backup lib/data/repositories
mkdir -p lib/domain/entities lib/domain/use_cases
mkdir -p test/core/theme test/features/navigation
```

For each file, write the minimal content (just the copyright header + a placeholder class/file comment):

`lib/core/constants/app_constants.dart`:
```dart
// Copyright (C) 2026  Paolo Santucci
// [GPL header - add via tools/add_license_header.sh]

// Tap target sizes, layout constants (§10, §layout tokens).
// Values sourced from mockup/tokens.json §layout.
class AppConstants {
  AppConstants._();

  static const double tapTargetMin = 44.0;
  static const double tapTargetMd = 48.0;
  static const double contentPad = 24.0;
  static const double maxWidth = 420.0;
}
```

`lib/core/errors/metra_exception.dart`:
```dart
// Copyright (C) 2026  Paolo Santucci
// [GPL header - add via tools/add_license_header.sh]

sealed class MetraException implements Exception {
  const MetraException(this.message);
  final String message;
}

final class StorageException extends MetraException {
  const StorageException(super.message);
}

final class EncryptionException extends MetraException {
  const EncryptionException(super.message);
}

final class SyncException extends MetraException {
  const SyncException(super.message);
}
```

Feature screen stubs — create one per feature with this template (replace `Calendar` with each feature name):

`lib/features/calendar/calendar_screen.dart`:
```dart
// Copyright (C) 2026  Paolo Santucci
// [GPL header - add via tools/add_license_header.sh]

import 'package:flutter/material.dart';

// → CalendarScreen: full implementation in P-1.
class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Calendar')),
    );
  }
}
```

Create identical stubs for:
- `lib/features/timeline/timeline_screen.dart` (`TimelineScreen`, `'Timeline'`)
- `lib/features/stats/stats_screen.dart` (`StatsScreen`, `'Stats'`)
- `lib/features/settings/settings_screen.dart` (`SettingsScreen`, `'Settings'`)

- [ ] **Step 2: Stamp GPL headers**

```bash
./tools/add_license_header.sh
```

- [ ] **Step 3: Analyze**

```bash
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/ test/
git commit -m "chore: scaffold lib/ directory structure with empty feature stubs"
```

---

## Task 8: Import design tokens — MetraColors

**Files:**
- Create: `lib/core/theme/metra_colors.dart`
- Create: `test/core/theme/metra_colors_test.dart`

**Context:** Values are sourced directly from `mockup/tokens.json`. The `MetraColors` class mirrors the JSON 1:1 so the mockup and Flutter app share the same palette contract. Wordmark string uses `'Mētra'` with a literal ē (Unicode U+0113) — never a Unicode escape, never a CSS pseudo-element (see memory note).

- [ ] **Step 1: Write the failing test first**

`test/core/theme/metra_colors_test.dart`:
```dart
// Copyright (C) 2026  Paolo Santucci
// [GPL header - add via tools/add_license_header.sh]

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/theme/metra_colors.dart';

void main() {
  group('MetraColors light palette', () {
    test('terracotta matches tokens.json', () {
      expect(MetraColors.light.terracotta, const Color(0xFFC87456));
    });

    test('terracottaDeep matches tokens.json', () {
      expect(MetraColors.light.terracottaDeep, const Color(0xFF9B4E32));
    });

    test('sand matches tokens.json', () {
      expect(MetraColors.light.sand, const Color(0xFFF4EDE2));
    });

    test('ink matches tokens.json', () {
      expect(MetraColors.light.ink, const Color(0xFF2B2521));
    });

    test('nightLavender matches tokens.json', () {
      expect(MetraColors.light.nightLavender, const Color(0xFF5B4E7A));
    });
  });

  group('MetraColors dark palette', () {
    test('deepNight matches tokens.json', () {
      expect(MetraColors.dark.deepNight, const Color(0xFF1A1410));
    });

    test('ivory matches tokens.json', () {
      expect(MetraColors.dark.ivory, const Color(0xFFEDE4D3));
    });

    test('mutedTerracotta matches tokens.json', () {
      expect(MetraColors.dark.mutedTerracotta, const Color(0xFFB86848));
    });

    test('lightLavender matches tokens.json', () {
      expect(MetraColors.dark.lightLavender, const Color(0xFF9B8FBF));
    });
  });

  group('MetraColors semantic contract', () {
    test('dustyOchre is decorative-only (never used as text color)', () {
      // Contrast ratio dustyOchre on sand = 2.0:1 → FAIL for text.
      // This test documents the constraint: dustyOchre must never appear
      // as a text foreground in any widget.
      expect(MetraColors.light.dustyOchre, const Color(0xFFD4A26A));
    });

    test('terracotta on sand is large-text-only (3.0:1)', () {
      // Small body text must use terracottaDeep (5.6:1 AA).
      expect(MetraColors.light.terracotta, isNot(equals(MetraColors.light.terracottaDeep)));
    });
  });
}
```

- [ ] **Step 2: Run test — expect FAIL (file does not exist yet)**

```bash
flutter test test/core/theme/metra_colors_test.dart
```

Expected: `Error: Cannot find 'package:metra/core/theme/metra_colors.dart'`

- [ ] **Step 3: Implement MetraColors**

`lib/core/theme/metra_colors.dart`:
```dart
// Copyright (C) 2026  Paolo Santucci
// [GPL header - add via tools/add_license_header.sh]

import 'package:flutter/material.dart';

// Design tokens sourced from mockup/tokens.json §colors.
// Field names mirror JSON keys. Never add a color here that is not in tokens.json.
@immutable
final class _LightPalette {
  const _LightPalette();

  // Primitive palette
  final Color sand             = const Color(0xFFF4EDE2);
  final Color terracotta       = const Color(0xFFC87456);
  final Color terracottaDeep   = const Color(0xFF9B4E32);
  final Color dustyOchre       = const Color(0xFFD4A26A);
  final Color dustyOchreDeep   = const Color(0xFF8A6332);
  final Color nightLavender    = const Color(0xFF5B4E7A);
  final Color moss             = const Color(0xFF7A8471);
  final Color mossDeep         = const Color(0xFF4F5A47);
  final Color ink              = const Color(0xFF2B2521);
  final Color inkSoft          = const Color(0xFF5A4F47);
  final Color surfaceRaised    = const Color(0xFFFBF6EC);
  final Color surfaceSunken    = const Color(0xFFECE4D6);
  final Color divider          = const Color(0xFFDCD2C0);
  final Color overlayScrim     = const Color(0x52002B2521); // rgba(43,37,33,0.32)
  final Color textDisabled     = const Color(0xFF8C8378);

  // Semantic aliases — use these in widgets, not the primitives above.
  // Contrast ratios from tokens.json §contrastChecks.
  Color get bgPrimary          => sand;
  Color get bgSurface          => surfaceRaised;
  Color get bgSunken           => surfaceSunken;
  Color get textPrimary        => ink;           // 12.4:1 AAA on sand
  Color get textSecondary      => inkSoft;       // 6.9:1 AA on sand
  // textOnSand: use terracottaDeep (5.6:1 AA), NEVER terracotta (3.0:1 large-only)
  Color get textOnSand         => terracottaDeep;
  Color get textOnAccent       => sand;
  Color get accentFlow         => terracotta;    // large UI / decorative only
  Color get accentFlowStrong   => terracottaDeep; // text + icons
  Color get accentPrediction   => nightLavender; // 6.8:1 AA
  Color get accentWarmth       => dustyOchre;    // decorative only (2.0:1 FAIL for text)
  Color get accentWarmthStrong => dustyOchreDeep; // 4.7:1 AA
  Color get accentConfirmation => moss;
  Color get accentConfirmationStrong => mossDeep; // 7.1:1 AA
  Color get borderSubtle       => divider;
  Color get borderStrong       => inkSoft;
  Color get stateError         => terracottaDeep;
  Color get stateSuccess       => mossDeep;
  Color get stateWarning       => dustyOchreDeep;
  Color get focusRing          => nightLavender;
}

@immutable
final class _DarkPalette {
  const _DarkPalette();

  // Primitive palette
  final Color deepNight            = const Color(0xFF1A1410);
  final Color deepNightRaised      = const Color(0xFF241D17);
  final Color deepNightSunken      = const Color(0xFF15100C);
  final Color mutedTerracotta      = const Color(0xFFB86848);
  final Color mutedTerracottaSoft  = const Color(0xFFD88B6E);
  final Color lightLavender        = const Color(0xFF9B8FBF);
  final Color warmOchreDark        = const Color(0xFFC09060);
  final Color mossDark             = const Color(0xFF8A9580);
  final Color ivory                = const Color(0xFFEDE4D3);
  final Color ivorySoft            = const Color(0xFFC8BFAE);
  final Color dividerDark          = const Color(0xFF382E26);
  final Color overlayScrim         = const Color(0x8F000000); // rgba(0,0,0,0.56)
  final Color textDisabled         = const Color(0xFF6B6358);

  // Semantic aliases
  Color get bgPrimary          => deepNight;
  Color get bgSurface          => deepNightRaised;
  Color get bgSunken           => deepNightSunken;
  Color get textPrimary        => ivory;           // 13.2:1 AAA
  Color get textSecondary      => ivorySoft;       // 9.4:1 AA
  Color get textOnSand         => mutedTerracottaSoft; // 6.0:1 AA
  Color get textOnAccent       => deepNight;
  Color get accentFlow         => mutedTerracotta; // 3.9:1 large/decorative
  Color get accentFlowStrong   => mutedTerracottaSoft; // 6.0:1 AA
  Color get accentPrediction   => lightLavender;   // 5.5:1 AA
  Color get accentWarmth       => warmOchreDark;   // 5.6:1 AA
  Color get accentWarmthStrong => warmOchreDark;
  Color get accentConfirmation => mossDark;        // 5.0:1 AA
  Color get accentConfirmationStrong => mossDark;
  Color get borderSubtle       => dividerDark;
  Color get borderStrong       => ivorySoft;
  Color get stateError         => mutedTerracottaSoft;
  Color get stateSuccess       => mossDark;
  Color get stateWarning       => warmOchreDark;
  Color get focusRing          => lightLavender;
}

abstract final class MetraColors {
  static const _LightPalette light = _LightPalette();
  static const _DarkPalette dark   = _DarkPalette();
}
```

- [ ] **Step 4: Run test — expect PASS**

```bash
flutter test test/core/theme/metra_colors_test.dart
```

Expected:
```
00:00 +9: All tests passed!
```

- [ ] **Step 5: Stamp GPL headers + commit**

```bash
./tools/add_license_header.sh
flutter analyze
git add lib/core/theme/metra_colors.dart test/core/theme/metra_colors_test.dart
git commit -m "feat: MetraColors design tokens (sourced from tokens.json)"
```

---

## Task 9: Import design tokens — MetraTypography + MetraSpacing

**Files:**
- Create: `lib/core/theme/metra_typography.dart`
- Create: `lib/core/theme/metra_spacing.dart`

No unit tests for pure `const` values; they are validated by widget tests in Task 11.

- [ ] **Step 1: Create MetraTypography**

`lib/core/theme/metra_typography.dart`:
```dart
// Copyright (C) 2026  Paolo Santucci
// [GPL header - add via tools/add_license_header.sh]

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Typography sourced from mockup/tokens.json §typography.
// Wordmark: 'Mētra' — literal ē (U+0113), never a Unicode escape.
abstract final class MetraTypography {
  // Scale entries map 1:1 to tokens.json §typography.scale.
  static TextStyle get displayXl => GoogleFonts.dmSerifDisplay(
        fontSize: 48,
        height: 1.2,
        letterSpacing: -0.01 * 48,
      );

  static TextStyle get displayLg => GoogleFonts.dmSerifDisplay(
        fontSize: 40,
        height: 1.2,
        letterSpacing: -0.01 * 40,
      );

  static TextStyle get displayMd => GoogleFonts.dmSerifDisplay(
        fontSize: 32,
        height: 1.2,
        letterSpacing: -0.01 * 32,
      );

  static TextStyle get titleLg => GoogleFonts.dmSerifDisplay(
        fontSize: 26,
        height: 1.3,
      );

  static TextStyle get titleMd => GoogleFonts.dmSerifDisplay(
        fontSize: 22,
        height: 1.3,
      );

  static TextStyle get titleSm => GoogleFonts.inter(
        fontSize: 20,
        height: 1.3,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get bodyLg => GoogleFonts.inter(
        fontSize: 18,
        height: 1.5,
      );

  static TextStyle get body => GoogleFonts.inter(
        fontSize: 16,
        height: 1.5,
      );

  static TextStyle get caption => GoogleFonts.inter(
        fontSize: 13,
        height: 1.4,
        letterSpacing: 0.01 * 13,
      );

  static TextStyle get tiny => GoogleFonts.inter(
        fontSize: 12,
        height: 1.4,
        letterSpacing: 0.01 * 12,
        fontWeight: FontWeight.w500,
      );

  // Wordmark: always use this constant; never reconstruct it inline.
  // ē = U+0113 — a literal character, matching CLAUDE.md §18 memory note.
  static const String wordmark = 'Mētra';

  static TextTheme toTextTheme(Color textColor) => TextTheme(
        displayLarge:  displayXl.copyWith(color: textColor),
        displayMedium: displayLg.copyWith(color: textColor),
        displaySmall:  displayMd.copyWith(color: textColor),
        headlineLarge: titleLg.copyWith(color: textColor),
        headlineMedium: titleMd.copyWith(color: textColor),
        headlineSmall: titleSm.copyWith(color: textColor),
        bodyLarge:     bodyLg.copyWith(color: textColor),
        bodyMedium:    body.copyWith(color: textColor),
        bodySmall:     caption.copyWith(color: textColor),
        labelSmall:    tiny.copyWith(color: textColor),
      );
}
```

- [ ] **Step 2: Create MetraSpacing**

`lib/core/theme/metra_spacing.dart`:
```dart
// Copyright (C) 2026  Paolo Santucci
// [GPL header - add via tools/add_license_header.sh]

// Spacing, radius, and motion tokens sourced from mockup/tokens.json.
abstract final class MetraSpacing {
  static const double s0  = 0;
  static const double s1  = 4;
  static const double s2  = 8;
  static const double s3  = 12;
  static const double s4  = 16;
  static const double s5  = 20;
  static const double s6  = 24;
  static const double s8  = 32;
  static const double s10 = 40;
  static const double s12 = 48;
  static const double s16 = 64;
}

abstract final class MetraRadius {
  static const double sm     = 8;
  static const double md     = 12;
  static const double lg     = 16;
  static const double pill   = 999;
}

abstract final class MetraMotion {
  // Durations (milliseconds) — use in Duration(milliseconds: MetraMotion.base)
  static const int instant    = 0;
  static const int fast       = 150;
  static const int base       = 240;
  static const int slow       = 400;
  static const int risingFill = 600;
  static const int painPulse  = 780;

  // Reduced-motion fallbacks (check MediaQuery.of(context).disableAnimations)
  static const int slowReduced       = 80;
  static const int risingFillReduced = 80;
}
```

- [ ] **Step 3: Analyze + commit**

```bash
./tools/add_license_header.sh
flutter analyze
git add lib/core/theme/metra_typography.dart lib/core/theme/metra_spacing.dart
git commit -m "feat: MetraTypography + MetraSpacing design tokens (from tokens.json)"
```

---

## Task 10: MetraTheme light + dark

**Files:**
- Create: `lib/core/theme/metra_theme.dart`
- Create: `test/core/theme/metra_theme_test.dart`

- [ ] **Step 1: Write the failing test**

`test/core/theme/metra_theme_test.dart`:
```dart
// Copyright (C) 2026  Paolo Santucci
// [GPL header - add via tools/add_license_header.sh]

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/theme/metra_theme.dart';
import 'package:metra/core/theme/metra_colors.dart';

void main() {
  group('MetraTheme.light', () {
    final theme = MetraTheme.light();

    test('brightness is light', () {
      expect(theme.brightness, Brightness.light);
    });

    test('scaffold background is sand', () {
      expect(theme.scaffoldBackgroundColor, MetraColors.light.sand);
    });

    test('primary color is terracottaDeep (AA-compliant for text)', () {
      expect(theme.colorScheme.primary, MetraColors.light.terracottaDeep);
    });
  });

  group('MetraTheme.dark', () {
    final theme = MetraTheme.dark();

    test('brightness is dark', () {
      expect(theme.brightness, Brightness.dark);
    });

    test('scaffold background is deepNight', () {
      expect(theme.scaffoldBackgroundColor, MetraColors.dark.deepNight);
    });

    test('primary color is mutedTerracottaSoft (AA-compliant for text)', () {
      expect(theme.colorScheme.primary, MetraColors.dark.mutedTerracottaSoft);
    });
  });

  group('MetraTheme design contract', () {
    test('light and dark themes have different scaffold backgrounds', () {
      expect(
        MetraTheme.light().scaffoldBackgroundColor,
        isNot(equals(MetraTheme.dark().scaffoldBackgroundColor)),
      );
    });

    test('no pure black in dark theme scaffold (warm brown-black)', () {
      // deepNight = 0xFF1A1410, not 0xFF000000
      expect(
        MetraTheme.dark().scaffoldBackgroundColor,
        isNot(equals(Colors.black)),
      );
    });
  });
}
```

- [ ] **Step 2: Run test — expect FAIL**

```bash
flutter test test/core/theme/metra_theme_test.dart
```

Expected: `Error: Cannot find 'package:metra/core/theme/metra_theme.dart'`

- [ ] **Step 3: Implement MetraTheme**

`lib/core/theme/metra_theme.dart`:
```dart
// Copyright (C) 2026  Paolo Santucci
// [GPL header - add via tools/add_license_header.sh]

import 'package:flutter/material.dart';
import 'metra_colors.dart';
import 'metra_typography.dart';

// MetraTheme provides ThemeData for light and dark modes.
// Dark mode is DESIGNED (not an inversion) per CLAUDE.md §8.1 and §9.
abstract final class MetraTheme {
  static ThemeData light() {
    final colors = MetraColors.light;
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: colors.sand,
      colorScheme: ColorScheme(
        brightness: Brightness.light,
        primary: colors.terracottaDeep,      // AA text color
        onPrimary: colors.sand,
        primaryContainer: colors.terracotta, // decorative fill
        onPrimaryContainer: colors.sand,
        secondary: colors.nightLavender,     // predictions
        onSecondary: colors.sand,
        tertiary: colors.dustyOchreDeep,     // warmth / notes
        onTertiary: colors.sand,
        surface: colors.surfaceRaised,
        onSurface: colors.ink,
        onSurfaceVariant: colors.inkSoft,
        outline: colors.divider,
        outlineVariant: colors.inkSoft,
        error: colors.terracottaDeep,
        onError: colors.sand,
        shadow: const Color(0x142B2521),
        scrim: colors.overlayScrim,
      ),
      textTheme: MetraTypography.toTextTheme(colors.ink),
      cardTheme: CardTheme(
        color: colors.surfaceRaised,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.divider),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceSunken,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      dividerColor: colors.divider,
      useMaterial3: true,
    );
  }

  static ThemeData dark() {
    final colors = MetraColors.dark;
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: colors.deepNight,
      colorScheme: ColorScheme(
        brightness: Brightness.dark,
        primary: colors.mutedTerracottaSoft,   // AA text 6.0:1
        onPrimary: colors.deepNight,
        primaryContainer: colors.mutedTerracotta,
        onPrimaryContainer: colors.deepNight,
        secondary: colors.lightLavender,       // predictions, 5.5:1 AA
        onSecondary: colors.deepNight,
        tertiary: colors.warmOchreDark,        // warmth, 5.6:1 AA
        onTertiary: colors.deepNight,
        surface: colors.deepNightRaised,
        onSurface: colors.ivory,               // 13.2:1 AAA
        onSurfaceVariant: colors.ivorySoft,    // 9.4:1 AA
        outline: colors.dividerDark,
        outlineVariant: colors.ivorySoft,
        error: colors.mutedTerracottaSoft,
        onError: colors.deepNight,
        shadow: const Color(0x661A1410),
        scrim: colors.overlayScrim,
      ),
      textTheme: MetraTypography.toTextTheme(colors.ivory),
      cardTheme: CardTheme(
        color: colors.deepNightRaised,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.dividerDark),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.deepNightSunken,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      dividerColor: colors.dividerDark,
      useMaterial3: true,
    );
  }
}
```

- [ ] **Step 4: Run test — expect PASS**

```bash
flutter test test/core/theme/metra_theme_test.dart
```

Expected: `00:00 +8: All tests passed!`

- [ ] **Step 5: Stamp + commit**

```bash
./tools/add_license_header.sh
flutter analyze
git add lib/core/theme/metra_theme.dart test/core/theme/metra_theme_test.dart
git commit -m "feat: MetraTheme light + dark (designed, not inverted)"
```

---

## Task 11: go_router shell + 4-tab navigation

**Files:**
- Create: `lib/router/app_router.dart`
- Modify: `lib/app.dart`
- Modify: `lib/main.dart`
- Create: `test/features/navigation/navigation_test.dart`

- [ ] **Step 1: Write the failing test**

`test/features/navigation/navigation_test.dart`:
```dart
// Copyright (C) 2026  Paolo Santucci
// [GPL header - add via tools/add_license_header.sh]

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra/app.dart';

void main() {
  group('Bottom navigation shell', () {
    testWidgets('renders 4 navigation destinations', (tester) async {
      await tester.pumpWidget(const MetraApp());
      await tester.pumpAndSettle();

      // NavigationBar has 4 items: Calendar, Timeline, Stats, Settings.
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationDestination), findsNWidgets(4));
    });

    testWidgets('Calendar is the initial route', (tester) async {
      await tester.pumpWidget(const MetraApp());
      await tester.pumpAndSettle();

      expect(find.text('Calendar'), findsOneWidget);
    });

    testWidgets('tapping Timeline tab shows timeline screen', (tester) async {
      await tester.pumpWidget(const MetraApp());
      await tester.pumpAndSettle();

      // Tap the 2nd navigation destination (index 1 = Timeline).
      final destinations = find.byType(NavigationDestination);
      await tester.tap(destinations.at(1));
      await tester.pumpAndSettle();

      expect(find.text('Timeline'), findsOneWidget);
    });

    testWidgets('tapping Stats tab shows stats screen', (tester) async {
      await tester.pumpWidget(const MetraApp());
      await tester.pumpAndSettle();

      final destinations = find.byType(NavigationDestination);
      await tester.tap(destinations.at(2));
      await tester.pumpAndSettle();

      expect(find.text('Stats'), findsOneWidget);
    });

    testWidgets('tapping Settings tab shows settings screen', (tester) async {
      await tester.pumpWidget(const MetraApp());
      await tester.pumpAndSettle();

      final destinations = find.byType(NavigationDestination);
      await tester.tap(destinations.at(3));
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run test — expect FAIL**

```bash
flutter test test/features/navigation/navigation_test.dart
```

Expected: `Error: Cannot find 'package:metra/app.dart'` (or compilation error because `app.dart` is the flutter-create default, not our version).

- [ ] **Step 3: Create app_router.dart**

`lib/router/app_router.dart`:
```dart
// Copyright (C) 2026  Paolo Santucci
// [GPL header - add via tools/add_license_header.sh]

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/calendar/calendar_screen.dart';
import '../features/timeline/timeline_screen.dart';
import '../features/stats/stats_screen.dart';
import '../features/settings/settings_screen.dart';

// Tab indices match the NavigationBar destination order.
// Do NOT reorder without updating _destinations below.
const int _tabCalendar  = 0;
const int _tabTimeline  = 1;
const int _tabStats     = 2;
const int _tabSettings  = 3;

final GoRouter appRouter = GoRouter(
  initialLocation: '/calendar',
  routes: [
    ShellRoute(
      builder: (context, state, child) => _ScaffoldWithNav(child: child),
      routes: [
        GoRoute(
          path: '/calendar',
          builder: (context, state) => const CalendarScreen(),
        ),
        GoRoute(
          path: '/timeline',
          builder: (context, state) => const TimelineScreen(),
        ),
        GoRoute(
          path: '/stats',
          builder: (context, state) => const StatsScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    ),
  ],
);

class _ScaffoldWithNav extends StatelessWidget {
  const _ScaffoldWithNav({required this.child});

  final Widget child;

  static const _destinations = [
    NavigationDestination(icon: Icon(Icons.calendar_today_outlined), label: 'Calendario'),
    NavigationDestination(icon: Icon(Icons.view_timeline_outlined),  label: 'Timeline'),
    NavigationDestination(icon: Icon(Icons.bar_chart_outlined),      label: 'Statistiche'),
    NavigationDestination(icon: Icon(Icons.settings_outlined),       label: 'Impostazioni'),
  ];

  static const _paths = ['/calendar', '/timeline', '/stats', '/settings'];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    return _paths.indexWhere((p) => location.startsWith(p)).clamp(0, 3);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex(context),
        onDestinationSelected: (index) => context.go(_paths[index]),
        destinations: _destinations,
      ),
    );
  }
}
```

- [ ] **Step 4: Create app.dart**

`lib/app.dart`:
```dart
// Copyright (C) 2026  Paolo Santucci
// [GPL header - add via tools/add_license_header.sh]

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/metra_theme.dart';
import 'router/app_router.dart';

class MetraApp extends StatelessWidget {
  const MetraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp.router(
        title: 'Mētra',
        theme: MetraTheme.light(),
        darkTheme: MetraTheme.dark(),
        themeMode: ThemeMode.system,
        routerConfig: appRouter,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
```

- [ ] **Step 5: Update main.dart**

`lib/main.dart`:
```dart
// Copyright (C) 2026  Paolo Santucci
// [GPL header - add via tools/add_license_header.sh]

import 'package:flutter/material.dart';
import 'app.dart';

void main() {
  runApp(const MetraApp());
}
```

- [ ] **Step 6: Run test — expect PASS**

```bash
flutter test test/features/navigation/navigation_test.dart
```

Expected: `00:00 +5: All tests passed!`

- [ ] **Step 7: Run full test suite**

```bash
flutter test
```

Expected: all tests pass (metra_colors, metra_theme, navigation).

- [ ] **Step 8: Stamp + analyze + commit**

```bash
./tools/add_license_header.sh
flutter analyze
git add lib/router/ lib/app.dart lib/main.dart test/features/
git commit -m "feat: go_router 4-tab navigation shell (Calendar/Timeline/Stats/Settings)"
```

---

## Task 12: Verify on Android emulator (DoD gate)

**Files:** none — this is a manual verification step.

**Context:** The DoD for P-0a is `flutter run` shows 4 tabs on the Android emulator. This task must be completed by a human or a CI runner with an attached AVD.

- [ ] **Step 1: Launch emulator (if not already running)**

```bash
emulator -avd Pixel_7_API35 -no-audio &
# Wait for the emulator to finish booting (watch for the lock screen)
```

- [ ] **Step 2: Run the app**

```bash
flutter run
```

Expected: Métra launches on the emulator. Bottom navigation bar shows 4 items. Tapping each item switches the screen.

- [ ] **Step 3: Verify dark mode**

On the emulator, go to System Settings → Display → Dark mode. Switch on. Verify Métra switches to the dark theme automatically (warm brown-black background, no pure white text).

- [ ] **Step 4: Run all tests one final time**

```bash
flutter test
flutter analyze
```

Both must produce zero errors/warnings.

- [ ] **Step 5: Commit verification record**

```bash
mkdir -p docs/p0
# Write a one-line record with the flutter --version output
flutter --version > docs/p0/foundation-verified.txt
echo "Emulator: Pixel_7_API35 (Android 35)" >> docs/p0/foundation-verified.txt
echo "Date: $(date -I)" >> docs/p0/foundation-verified.txt
git add docs/
git commit -m "docs: P-0a foundation verified on Android emulator"
```

---

## Self-review

### Spec coverage

| Requirement | Task |
|---|---|
| Flutter SDK installed on Fedora 43 | T1 |
| Android SDK + AVD ready | T2 |
| Flutter project created, GPL headers | T3, T6 |
| All §3 deps in pubspec.yaml | T4 |
| `analysis_options.yaml` with `avoid_print`, `prefer_const`, `require_trailing_commas` | T5 |
| lib/ directory structure per §4 | T7 |
| `MetraColors` (light + dark, tokens.json 1:1) | T8 |
| `MetraTypography` (DM Serif Display + Inter) | T9 |
| `MetraSpacing`, `MetraRadius`, `MetraMotion` | T9 |
| `MetraTheme.light()` + `MetraTheme.dark()` (designed, not inverted) | T10 |
| 4-tab navigation via go_router ShellRoute | T11 |
| App runs on Android emulator, 4 tabs visible | T12 |

**Not in this plan (by design):**
- Encrypted DB, EncryptionService → P-0b
- Security docs → P-0c
- CI/CD workflows → P-0d
- i18n `.arb` files / localization → P-4 (intl dep is in pubspec; `generate: true` is enabled)

### Placeholder scan

No TBD, TODO, or "implement later" found. Every step shows the full code.

### Type consistency

- `MetraColors.light` and `MetraColors.dark` return `_LightPalette` / `_DarkPalette` instances — accessed as `MetraColors.light.terracotta` throughout T8–T11. Consistent.
- `MetraTheme.light()` / `MetraTheme.dark()` — used in `app.dart` T11 and tested in T10. Consistent.
- `GoRouter appRouter` defined in `app_router.dart`, referenced in `app.dart`. Consistent.
- `MetraApp` class in `app.dart`, imported in `main.dart` and tests. Consistent.

### Notes for P-0b (successor plan)

The Encrypted DB plan will need the key management spec from P-0c (security docs) before it can fix the Argon2id parameters. Sequence: run P-0a (this plan) → P-0c (security docs, no Flutter needed) → P-0b (encrypted DB). P-0d (CI/CD) can run in parallel with P-0c.
