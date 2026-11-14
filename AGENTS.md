---
docs-root: docs
---

# AGENTS.md

<!-- status-discipline-block:v3 BEGIN — managed by bootstrap-status-discipline skill; do not edit between sentinels -->

## ⭐️ Session Boot — MANDATORY

Before responding to the user's first message in any session:

1. Obtain the current state. If a `[status-inject]` section already appeared in this conversation, that **is** `./STATUS.yaml` — use it and do not read the file again. Otherwise read `./STATUS.yaml` yourself; if only the legacy `./STATUS.md` exists, read that instead — the next `/update-status` will migrate it to YAML.
2. Summarise it in **one line** before any other action: the active plan (if any), the most recent completion, and the most relevant in-progress item or blocker.
3. **If `pending-consolidation` is a non-empty array**, append a second line right after the summary: `⚠ <N> plan(s) archived with unconsolidated spec deltas — see pending-consolidation in STATUS.yaml`. This is a visibility signal, not a blocker — never refuse to proceed because of it.
4. If nothing was injected and no status file exists, ask the user for current project context before proceeding.

## ⚠️ Status Discipline — MANDATORY

Invoke the `update-status` skill (`/update-status`) **proactively**, without waiting to be asked, at every one of these:

- a completed task or logical group of changes;
- a `git commit`;
- a milestone, phase transition, or workflow handoff;
- a significant blocker;
- an explicit user signal: `"stop"`, `"checkpoint"`, `"save progress"`, `"end of session"`, `"that's it"`, `"talk to you tomorrow"`.

A `[status-freshness]` reminder in the conversation means unrecorded commits have already accumulated — act on it at the next natural break. Its **absence proves nothing**: that counter lives in the plugin process and does not survive a one-shot `opencode run`, so the triggers above hold whether or not the sidekick plugins are deployed here.

Do **not** defer to session-end. `STATUS.yaml` is the source of truth between sessions and must reflect reality at every checkpoint.

<!-- status-discipline-block:v3 END -->

## Project

Métra — privacy-first, local-first menstrual cycle tracker. Flutter app (Android + iOS), GPL-3.0, no backend, no telemetry. **Not** a fertility tracker; no gamification, no dark patterns. Non-negotiable invariants for any change: cloud providers only ever see encrypted blobs (zero-knowledge; key never leaves the device), all data local-first, WCAG 2.2 AA accessibility, no new dependencies without justification (`pubspec.yaml` is curated).

## Commands

- `make test` — `flutter test` (auto-runs `flutter pub get` only if `pubspec.yaml` is newer than the lockfile). `make test-full` = fresh `pub get` + full suite.
- Single test file (see the sqlite quirk below first): `flutter test test/domain/foo_test.dart`
- Codegen (Drift `.g.dart`, riverpod_generator) — required after editing `lib/data/database/**` or provider annotations:
  `dart run build_runner build --delete-conflicting-outputs`
- `dart format .` — CI fails on unformatted code. `flutter analyze` — strict (`strict-casts`, `strict-inference`, `strict-raw-types`, `require_trailing_commas`, `avoid_print`).
- `bash tools/check_license_headers.sh` — GPL-3.0 header must be on every hand-written `.dart` file in `lib/` and `test/` (generated `*.g.dart` / l10n excluded). Fix missing ones with `tools/add_license_header.sh`.

## CI — what a push to `main` must survive

`quality.yml` order: `flutter pub get --enforce-lockfile` → `build_runner build` → `dart format .` + `git diff --exit-code` (codegen must be deterministic and committed) → `flutter analyze` → license headers → `flutter test --coverage` → **80% line-coverage gate** (`*.g.dart` and `l10n` stripped before measuring).

- Flutter is pinned to **3.41.9** in all four workflows. When upgrading locally, update the pins in `.github/workflows/*.yml` (and `tools/setup-environment.sh`), then commit the refreshed `pubspec.lock`.
- `test/ci/workflow_assertions_test.dart` asserts the exact text of the workflow YAML files — editing `.github/workflows/` can break `flutter test`. `test/ci/play_publish_workflow_test.dart` does the same for `android-play.yml` (manual-only, internal default, exact action pin).
- `android-play.yml` publishes a signed AAB to a Play track. **Manual dispatch only** — never on push or tag (`v*` means iOS TestFlight). Requires `secrets.PLAY_SERVICE_ACCOUNT_JSON` in addition to the existing `KEYSTORE_*` set; it hard-fails without it rather than falling back to debug signing. `versionCode` is *not* bumped by CI — bump it in `android/app/build.gradle.kts` before each publish.
- `test/static/` contains grep-guard tests that scan `lib/features/backup/` and `lib/core/widgets/settings/` for forbidden patterns (token discipline, restore handling). Read them before touching those directories.

## Environment quirks

- Development happens inside a Linux distrobox — **no Mac, no iOS simulator**. iOS builds run only on the GitHub Actions macOS runner; iOS verification is TestFlight on a physical device. Do not write code whose verification depends on a local iOS simulator.
- Drift/SQLCipher tests need a native `libsqlite3.so` the distrobox lacks. Workaround before running tests locally:
  `mkdir -p /tmp/sqlitelib && ln -sf /usr/lib/x86_64-linux-gnu/libsqlite3.so.0 /tmp/sqlitelib/libsqlite3.so` then `LD_LIBRARY_PATH=/tmp/sqlitelib flutter test`
- Fresh machine bootstrap: `bash tools/setup-environment.sh` (Ubuntu 24.04/26.04 incl. Distrobox; installs Flutter 3.41.9, JDK 17, Android SDKs, native sqlite/SQLCipher libs; `--dry-run` available).
- Pre-commit: lefthook (`sudo dnf install lefthook && lefthook install` once per clone) formats staged `.dart` files in place.
- Backup-related builds need OAuth credentials via `--dart-define=DROPBOX_APP_KEY=... --dart-define=GOOGLE_OAUTH_CLIENT_ID=...` (CI injects them from secrets).
- Known flaky: `save_daily_log_test.dart` future-date rejection fails intermittently near Italian midnight UTC (timezone/DST boundary) — re-run before investigating.

## Architecture

Entry: `lib/main.dart` → `lib/app.dart` (MaterialApp, theme, go_router). Layers are strictly unidirectional, UI → Domain → Data:

- `lib/domain/` — pure business logic; never imports from `data/` or `features/`.
- `lib/data/` — `database/` (Drift + SQLCipher; **schemaVersion 11** in `app_database.dart`, migrations via `onUpgrade`), `repositories/`, `services/`.
- `lib/features/` — UI + Riverpod state. Never imports `data/database/` or `data/services/` directly — always through `repositories/`. Domain errors must not leak Drift/HTTP types.
- `lib/providers/` — Riverpod providers (`*Provider` suffix); `lib/l10n/` — localizations.

Cloud backup (`lib/data/services/backup/`) is multi-provider: Dropbox, Google Drive, iCloud — **one active provider at a time**; iCloud is iOS/iPadOS-only and must stay hidden on Android. OAuth is raw PKCE via `flutter_web_auth_2` (callback scheme `metra://oauth-callback`).

## Conventions that differ from defaults

- **Italian is the l10n template**: `lib/l10n/app_it.arb` is the template ARB (`l10n.yaml`), not English. Every user-facing string goes in both `app_it.arb` and `app_en.arb`.
- Commits: English, conventional format (`feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`). Every commit leaves tests green — no half-finished implementations.
- If a UX detail isn't specified in the design docs, **ask, don't invent** — the design has a precise voice, and a wrong pattern is a regression, not an iteration.
- Read related repository/DAO/provider files before touching `data/` — layering means a change there can break `features/`.

## Versioning & release

Two independent version sources — updating `pubspec.yaml` alone does NOT bump Android:

- iOS: `pubspec.yaml` `version:` (currently `1.1.1+26`); the iOS build number is overridden by CI (`--build-number=$GITHUB_RUN_NUMBER` in `ios.yml`).
- Android: pinned in `android/app/build.gradle.kts` (`versionCode` must strictly increase per Play Store submission).

Tags `v*` trigger the TestFlight upload workflow; `android.yml` builds debug + release APK and signed AAB on every push to `main` (release falls back to debug signing when the keystore secret is absent, e.g. on forks).

Publishing to Play is a separate, human-triggered step: `android-play.yml` (`workflow_dispatch`, `track` = `internal` | `alpha` | `beta` | `production`, default `internal`) rebuilds the AAB, verifies it with `jarsigner`, and uploads it through the Play Developer API. CI never bumps `versionCode`; bump it in `android/app/build.gradle.kts` in its own commit first. Setup: `docs/guides/play-store-publishing.md`.

## Docs map

`docs/` is the internal doc root **and** the public Jekyll site (GitHub Pages). Key locations:

- `docs/canon/spec/INDEX.md` — canonical app spec, one slice per domain (backup, calendar, encryption, …). Consult before writing any text describing current product behavior.
- `docs/canon/product-vision.md`, `product-narrative.md`, `ui-design-bible.md` — vision, voice, UI source of truth.
- `docs/plans/` + `docs/specs/` (with `archive/`) — sprint plans and specs; workflow state lives in `STATUS.yaml`.
- `docs/it/help/` + `docs/en/help/` — **user-facing** help pages. They drift when features ship without a doc update (has happened repeatedly); when auditing them, diff against the canon spec and the code, never trust the existing prose.
- `docs/guides/cloud-provider-setup.md` — provider credential provisioning (not on the public site). `docs/guides/play-store-publishing.md` — Play service account, secret setup, track dispatch (not on the public site).

