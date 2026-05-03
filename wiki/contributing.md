# Contribute to Métra

Métra is a privacy-first, local-first, GPL-3.0 menstrual cycle tracker built with Flutter. Contributions are welcome — this guide covers everything you need to go from clone to merged PR.

## Table of contents

- [Project principles](#project-principles)
- [Development setup](#development-setup)
  - [Prerequisites](#prerequisites)
  - [First-time setup](#first-time-setup)
  - [Code generation](#code-generation)
- [Architecture overview](#architecture-overview)
- [Code conventions](#code-conventions)
  - [File and class naming](#file-and-class-naming)
  - [Dart style](#dart-style)
  - [State management](#state-management)
  - [Error handling](#error-handling)
  - [UI widgets](#ui-widgets)
  - [License headers](#license-headers)
- [Layering rules](#layering-rules)
- [UI change protocol](#ui-change-protocol)
- [Testing](#testing)
  - [Requirements](#requirements)
  - [Key test scenarios](#key-test-scenarios)
  - [Test structure](#test-structure)
  - [Running tests](#running-tests)
- [Commit conventions](#commit-conventions)
- [CI/CD](#cicd)
- [PR guidelines](#pr-guidelines)
- [E2E verification checklist](#e2e-verification-checklist)
- [Adding a new dependency](#adding-a-new-dependency)

---

## Project principles

Every change must respect these five constraints. A PR that violates them won't be merged regardless of code quality.

1. **Local-first.** Data lives on the user's device. No proprietary server, ever. Cloud is optional and serves only for backup/sync — never as source of truth.
2. **Zero-knowledge cloud.** Cloud providers (Dropbox, Google Drive, OneDrive) see only encrypted blobs. The encryption key never leaves the device. There is no server-side password reset — because there is no server.
3. **No telemetry.** Zero analytics, zero third-party crash reporting, zero tracking. Diagnostic logs are local only and user-clearable.
4. **Accessibility built-in.** WCAG 2.2 AA minimum, AAA where achievable. An inaccessible screen is an incomplete screen.
5. **Respect the user.** No dark patterns, no gamification, no motivational notifications, no endless onboarding.

---

## Development setup

### Prerequisites

- Flutter 3.x + Dart latest stable
- Android SDK + an emulator or a physical device
- Java (for Gradle)
- `adb` in PATH

**iOS note:** local development targets Android. iOS builds run on GitHub Actions macOS runners and are tested via TestFlight on a physical device. There is no iOS simulator available in the local dev environment — don't write code that requires one to verify.

### First-time setup

```bash
git clone https://github.com/paolo-santucci/metra.git
cd metra
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter test
flutter run  # requires a connected Android device or emulator
```

### Code generation

Métra uses `build_runner` for Drift DAO code and Riverpod providers.

```bash
# One-shot (during development)
dart run build_runner build --delete-conflicting-outputs

# Watch mode
dart run build_runner watch --delete-conflicting-outputs
```

Generated files (`*.g.dart`) are committed to the repo. Run `build_runner` whenever you modify a Drift table/DAO or a `@riverpod`-annotated provider. The CI `quality` workflow runs `build_runner` after your tests and fails the build if the output differs from what you committed — so regenerate before pushing.

---

## Architecture overview

Dependencies flow in one direction: `UI → Domain → Data`.

```
lib/
├── core/          # Shared infrastructure: theme tokens, errors, reusable widgets
├── domain/        # Business logic: entities, repository interfaces, use cases
├── data/
│   ├── database/  # Drift schema, DAOs, migrations
│   ├── repositories/  # Drift implementations of domain interfaces
│   └── services/  # External integrations (Dropbox backup, notifications)
├── features/      # UI screens and Riverpod state
├── providers/     # Riverpod provider factories
├── router/        # go_router navigation
└── l10n/          # Localization (Italian primary, English mirror)
```

---

## Code conventions

### File and class naming

| Thing | Convention | Example |
|---|---|---|
| Classes | `UpperCamelCase` | `CyclePredictionService` |
| Files | `lower_snake_case.dart` | `cycle_prediction_service.dart` |
| Riverpod providers | `Provider` suffix | `calendarStateProvider`, `dailyLogRepositoryProvider` |
| Use cases | `VerbNoun` class name | `SaveDailyLog`, `PredictNextCycle` |

No cryptic acronyms. `CycleEntry`, not `CE`.

### Dart style

- Run `dart format` on everything. CI fails if files are unformatted.
- Linter: `flutter_lints` plus custom rules in `analysis_options.yaml` (`prefer_const`, `avoid_print`, `require_trailing_commas`).
- Strict null safety. Never use `!` without a comment explaining why it's safe.
- No `catch(e) {}` without at least a `debugPrint`.

### State management (Riverpod)

- Use `AsyncNotifier` for state with loading/error.
- Never use `FutureProvider` for mutable state.
- Never use `setState` in large widgets — isolate state in a Notifier.
- Drift streams → Riverpod: use `StreamProvider.autoDispose`.
- Prediction stream: `StreamProvider<CyclePrediction?>` — not `AsyncNotifierProvider`. The Completer-based approach had a race condition and was removed.

### Error handling

- Use `Result<T, E>` or sealed classes for expected errors. `throw` is for programming errors only.
- User-facing error messages are in Italian and English. Never expose raw stack traces.

### UI widgets

- Stateless where possible.
- Split any widget over 150 lines.
- Never put business logic in `build()` — use a Notifier.
- `const` constructors everywhere the linter allows.

### License headers

Every new hand-written `.dart` file must begin with this header. Generated files (`*.g.dart`, `app_localizations*.dart`) are exempt.

```dart
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
```

The `quality` CI workflow checks every file in `lib/` and `test/` against this header and fails the build if any are missing. To stamp files automatically:

```bash
bash tools/add_license_header.sh
```

---

## Layering rules

```
features/  →  domain/  →  data/
```

- `domain/` never imports from `data/` or `features/`.
- `features/` never imports directly from `data/database/` or `data/services/` — always through repository interfaces.
- Domain errors must not leak Drift or HTTP types.
- A new dependency between layers must be justified in the PR description.

---

## UI change protocol

The HTML mockup is the canonical source of truth for every visual decision.

1. Open `design/Métra Screens Light.html` in a browser.
2. Make your visual change in the HTML (it's a self-contained React app).
3. Update `design/DESIGN-BIBLE.md` to transcribe the new visual decision.
4. Only then implement in Flutter.

Never change Flutter first. If the HTML mockup and the Design Bible diverge, the HTML wins — patch the Bible to match, never the reverse.

---

## Testing

### Requirements

- Unit tests on every service in `data/services/` and `domain/use_cases/`. The CI coverage gate requires 80% line coverage.
- Widget tests on main screens: calendar, daily entry, stats, settings.
- All tests must pass before you open a PR.
- No half-finished implementations — each commit must leave the test suite green.

### Key test scenarios

**`CyclePredictionService`:** 0, 1, 2, 3, 6, and 10 cycles. Short/long cycles. Missing cycles.

**`EncryptionService`:** encrypt → decrypt round-trip; different IVs produce different ciphertext; a wrong key fails gracefully.

**`SaveDailyLog`:** the DM-02 invariant — `flowIntensity` must be `null` unless `flowType == FlowType.mestruazioni`.

**`RecomputeCycleEntries`:** the mutex — concurrent calls must not clobber each other.

### Test structure

```
test/
├── domain/       # Pure Dart — no Flutter, no Drift mocks
├── data/         # Uses a real in-memory Drift/SQLCipher database
├── features/     # Widget tests with Riverpod ProviderScope overrides
├── core/         # Widget and utility tests (with golden images)
├── helpers/      # FakeDailyLogRepository, FakeCycleEntryRepository, etc.
└── goldens_*/    # Golden image snapshots
```

**Important:** `data/` tests use a real in-memory Drift/SQLCipher database — not mocks. Divergence between mocked and real database behavior has caused regressions before. Keep it real.

### Running tests

```bash
# Full suite
flutter test

# Single file
flutter test test/domain/services/cycle_prediction_service_test.dart

# With coverage
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html

# Regenerate golden images
flutter test --update-goldens
```

---

## Commit conventions

Format: `type(scope): description` — [Conventional Commits](https://www.conventionalcommits.org/).

| Type | Use for |
|---|---|
| `feat` | New feature |
| `fix` | Bug fix |
| `refactor` | Code change that fixes nothing and adds nothing |
| `test` | Adding or correcting tests |
| `docs` | Documentation only |
| `chore` | Build system, tooling, dependencies |

Scope is optional but encouraged — `feat(calendar):`, `fix(prediction):`.

Messages are in English. The git log is public and is part of the project documentation.

---

## CI/CD

Three GitHub Actions workflows run on every push and pull request to `main`.

| Workflow | Trigger | Steps |
|---|---|---|
| `quality.yml` | Push / PR | Format check (`dart format --set-exit-if-changed`) → `flutter analyze` → license header check → tests with coverage → 80% coverage gate → `build_runner` determinism check |
| `android.yml` | Push / PR | `flutter pub get` → build debug APK → build release-unsigned APK |
| `ios.yml` | Push / PR | `flutter pub get` → `flutter build ios --no-codesign` |

The iOS deploy job (TestFlight upload) runs only on tags matching `v*`. TestFlight upload via fastlane is not yet configured — the step currently echoes a TODO. Contact the maintainer if you need to be added as a TestFlight tester.

**Secrets required for iOS signing:** Apple Developer certificate and provisioning profile. These live in GitHub repository secrets; contributors don't need them for local Android development.

---

## PR guidelines

- One logical change per PR. A bug fix PR should not include refactoring.
- Link to the GitHub issue if one exists.
- Describe what changed and why — not just what the diff shows.
- New UI: include a screenshot or screen recording in the PR description.
- New feature: update `lib/l10n/app_it.arb` and `lib/l10n/app_en.arb`, then regenerate `app_localizations*.dart` (run `flutter gen-l10n`).
- Database schema change: add a new migration branch in `AppDatabase.migration.onUpgrade`. Never drop existing columns.

---

## E2E verification checklist

Run through this before tagging a release.

1. **Encrypted DB** — open the DB file in a SQLite browser without the key. It must fail.
2. **Prediction** — enter 3 or more cycles. The predicted date must match a manual weighted-moving-average calculation.
3. **E2E encryption** — back up to Dropbox. Download the `.enc` file. Verify it's unreadable binary. Restore on a second device. Data must be identical.
4. **CSV round-trip** — export. Edit a field in the file. Import. The database must reflect the edit.
5. **Notification** — enable with a 1-day advance. Advance the system date. Verify the notification arrives.
6. **Dynamic Type 200%** — no truncation or broken layout on the calendar or table screens.
7. **TalkBack / VoiceOver** — complete the logging flow without sight.

---

## Adding a new dependency

`pubspec.yaml` is curated. Before adding a package:

1. Confirm that no existing package can do the job.
2. Document the justification in the PR description.

Never add analytics, telemetry, or crash-reporting packages — they violate principle 3.

<!-- author notes
Voice: derived from CLAUDE.md tone and STATUS.md session log prose — direct, imperative, concrete, no filler.

Corrections applied vs. the spec:
- Spec said "wiki/design/Métra Screens Light.html" in the UI change protocol. Actual location is "design/Métra Screens Light.html" (confirmed from DESIGN-BIBLE.md and filesystem). Used the correct path. Maintainer should verify whether a wiki/design/ symlink or copy is intended.
- iOS TestFlight: the spec describes upload as working on tag v*. The actual ios.yml deploy step contains "echo 'TODO: configure fastlane...'" — softened to "not yet configured" to avoid shipping false information.
- CI table expanded: spec listed only format + analyze + coverage. quality.yml also runs license header check (tools/check_license_headers.sh), hard 80% coverage gate, and build_runner determinism check. All three added because contributors will hit them.

Sections cut: none — all spec sections retained. The note about device_calendar being removed from MVP was not included (it's an internal decision, not contributor guidance).

Verification gaps:
- [VERIFY: wiki/design/ path — the spec said "wiki/design/Métra Screens Light.html" but the actual location confirmed by DESIGN-BIBLE.md and .git/config is "design/Métra Screens Light.html". Maintainer should confirm whether a wiki/design/ mirror is intended.]

Corrections applied:
- Repo URL fixed from spec's "paolosantucci" to "paolo-santucci" (confirmed from .git/config remote.origin.url).
-->
