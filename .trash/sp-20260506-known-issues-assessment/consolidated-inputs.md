# Consolidated Assessment — Known Issues

**Date:** 2026-05-06
**Issues assessed:** 3 (from STATUS.md Known Issues section)
**Modules assessed:** `tools/`, `test/data/services/backup/`, `.github/workflows/`

---

## Per-Module Findings

<details>
<summary>tools/ — License header scripts (4 findings)</summary>

See: `license-header-bugs.md`

- **[HIGH] BUG-LH-002** — `add_license_header.sh` stamps generated `.g.dart` and `app_localizations*.dart` files (no exclusion list)
- **[MEDIUM] BUG-LH-001** — Stamper skips files with outdated copyright (wrong year/spacing); checker catches them → irreconcilable state requiring `sed`
- **[MEDIUM] BUG-LH-003** — No `set -euo pipefail`, hardcoded `/tmp/metra_hdr` temp path (race condition, silent failures)
- **[LOW] BUG-LH-004** — `check_license_headers.sh` l10n exclusion uses CWD-relative path, fails if run outside repo root

</details>

<details>
<summary>test/data/services/backup/ — sync_orchestrator_test.dart flakiness (3 findings)</summary>

See: `sync-orchestrator-flaky-bugs.md`

- **[HIGH] BUG-001** — `EncryptionService` Argon2id (64 MB, 3 iterations) not injectable; 7 real KDF derivations per file run; under full-suite parallelism, 2-chain restore tests cross 30 s timeout wall
- **[MEDIUM] BUG-002** — `upload failure` test silently runs full Argon2id before intentional failure point; adds unexpected KDF cost
- **[LOW] BUG-003** — `syncLogRepo.appended.clear()` in `seedBackup()` is redundant; creates fragile contract with setUp

</details>

<details>
<summary>.github/workflows/ — flutter test cold start (4 findings)</summary>

See: `flutter-test-cold-start-bugs.md`

- **[HIGH] BUG-CI-01** — No `cache: 'pub'` in `subosito/flutter-action` in any of the 3 workflows; 147 packages re-downloaded on every run
- **[MEDIUM] BUG-CI-02** — `quality.yml` runs `flutter pub get` then `flutter test` without `--no-pub` (double resolution)
- **[MEDIUM] BUG-LOCAL-01** — No local test runner script enforcing `--no-pub` + staleness guard
- **[LOW] BUG-CI-03** — Actions pinned to mutable `@v2` tag (supply-chain risk with DROPBOX_APP_KEY in scope)

</details>

---

## Unified Spec Inputs

### Root Causes

| Issue | Root Cause |
|-------|-----------|
| License stamper skips outdated | Predicate checks `head -1 \| grep -q "Copyright"` — any copyright string passes; checker uses exact REQUIRED_LINE comparison |
| Generated files not excluded from stamper | `check_license_headers.sh` has exclusion `case` block; `add_license_header.sh` does not |
| `sync_orchestrator_test.dart` flaky | `EncryptionService` has no injectable KDF; 7 real Argon2id derivations under suite parallelism exhaust 30 s timeout |
| `flutter test` cold start | No pub cache in CI; no `--no-pub` in test invocation; no local wrapper script |

### Affected Components and Files

**Issue 1 (license scripts):**
- `tools/add_license_header.sh` — stamper logic (detection predicate, exclusion list, temp file, error handling)
- `tools/check_license_headers.sh` — l10n exclusion path (CWD-sensitivity)

**Issue 2 (flaky test):**
- `lib/data/services/encryption_service.dart` — Argon2id static final, no injection point
- `test/data/services/backup/sync_orchestrator_test.dart` — `_make()` factory, restore group tests

**Issue 3 (flutter test speed):**
- `.github/workflows/quality.yml` — missing `cache: 'pub'`, missing `--no-pub`
- `.github/workflows/android.yml` — missing `cache: 'pub'`
- `.github/workflows/ios.yml` — missing `cache: 'pub'`
- `Makefile` (to be created) — local test wrapper

### Constraints

1. GPL-3.0 header format is canonical; the REQUIRED_LINE in `check_license_headers.sh` is the authoritative format.
2. New scripts in `tools/` must carry GPL-3.0 header.
3. `EncryptionService` fix must not change production behavior; only test code should receive the lightweight KDF.
4. `--no-pub` in CI is safe only after a successful `flutter pub get` (already present as a preceding step in quality.yml).
5. Pub cache must be keyed on `pubspec.lock` hash to auto-invalidate on dependency changes.
6. Makefile staleness guard: compare `pubspec.yaml` mtime vs `pubspec.lock` mtime.
7. `encryption_service_test.dart` already has its own `Timeout(Duration(minutes: 3))` and tests real KDF — do not change it.

### Cross-Module Concerns

- The license stamper bug (Issue 1) could corrupt generated files if re-run; this would also break the CI license check gate and potentially the quality workflow's codegen check.
- The Argon2id injection fix (Issue 2) touches `EncryptionService` which is also exercised by `sync_orchestrator_test.dart`, `encryption_service_test.dart`, and potentially future backup-related tests — the injection seam must be backward-compatible.
- Pinning CI Actions to SHAs (Issue 3, LOW) should be done in all three workflow files atomically to avoid partial security posture.

### Suggested Fix Approaches

**Fix A — `add_license_header.sh` rewrite:**
1. Read `REQUIRED_LINE` from the same source as the checker (hardcode or share via sourced variable).
2. Mirror checker's exclusion `case` block exactly.
3. Detection: check if first 20 lines contain `REQUIRED_LINE`; if not, prepend header (whether missing or outdated — use `grep -F` on first 20 lines).
4. Replace `/tmp/metra_hdr` with `mktemp`; add `trap 'rm -f "$TMP"' EXIT`.
5. Add `set -euo pipefail`.

**Fix B — `check_license_headers.sh` CWD guard:**
- Change l10n exclusion from `lib/l10n/...` to a `*app_localizations*` glob pattern (path-independent).

**Fix C — `EncryptionService` KDF injection:**
- Add optional `Argon2id? kdfOverride` parameter to `EncryptionService` constructor.
- In `_make()` in `sync_orchestrator_test.dart`, pass `Argon2id(memory: 256, iterations: 1, parallelism: 1, hashLength: 32)`.
- Production code unchanged (default = current production config).

**Fix D — CI pub caching + `--no-pub`:**
- Add `cache: 'pub'` to `subosito/flutter-action` in all three workflows.
- Add `--no-pub` to `flutter test --coverage` in `quality.yml`.

**Fix E — Local Makefile:**
- Create `Makefile` with staleness-aware `test` target.
- Add GPL-3.0 header as `#`-prefixed comment block.

**Fix F — Pin Action SHAs (optional, LOW):**
- Pin `subosito/flutter-action@v2` to the current SHA in all three workflow files.
