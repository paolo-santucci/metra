# Flutter Test Cold-Start Latency — Bug & Developer-Experience Assessment

**Date:** 2026-05-06
**Scope:** `pubspec.yaml`, `pubspec.lock`, `.github/workflows/quality.yml`, `.github/workflows/android.yml`, `.github/workflows/ios.yml`, `tools/`
**Analyst:** bug-hunter agent

---

## Executive Summary

The cold-start latency issue is real, affects both local development and CI, and has two distinct root causes: the absence of a Pub cache in CI runners (which forces a full network resolution on every run), and the absence of any enforced local shortcut (no Makefile, no dev script, no `--no-pub` wrapper). CI is _not_ broken by design — it does run `flutter pub get` before tests — but it pays the full network cost every run because no cache is restored. Locally, the penalty is amplified because `flutter test` without `--no-pub` also triggers dependency resolution even when `pubspec.lock` is current. There is no documented workaround and no script encoding the `--no-pub` shortcut.

---

## Finding 1 — CI: No Pub Cache Step in Any Workflow

**Severity:** HIGH (developer-experience; CI minutes wasted on every push)
**Category:** missing optimization / missing cache
**Location:** `.github/workflows/quality.yml:13-25`, `.github/workflows/android.yml:13-24`, `.github/workflows/ios.yml:13-24`

**Evidence:**

```yaml
# quality.yml — representative; android.yml and ios.yml are identical
- name: Setup Flutter
  uses: subosito/flutter-action@v2
  with:
    flutter-version: '3.x'
    channel: stable

- name: Install dependencies
  run: flutter pub get
```

No `cache: 'pub'` key is passed to `subosito/flutter-action`, and there is no explicit `actions/cache` step for the Pub cache (`~/.pub-cache`). The `subosito/flutter-action@v2` action supports a `cache: 'pub'` parameter that enables automatic caching of the Pub package cache between runs. Without it, every workflow run re-downloads all 147 hosted packages from pub.dev from scratch.

**Analysis:**

The lock file has 152 total resolved packages (147 hosted, 5 SDK). A cold download of 147 packages — including heavy transitive dependencies from `drift_dev` (which pulls the full Dart analyzer at `_fe_analyzer_shared 85.0.0`, `analyzer 7.6.0`, `analyzer_plugin 0.13.4`), `build_runner`, `riverpod_generator`, and the native-library wrappers (`sqlcipher_flutter_libs`, `flutter_local_notifications`) — easily accounts for 5–15 minutes of CI time per workflow on a shared runner. The same cost is paid by all three workflows (`quality.yml`, `android.yml`, `ios.yml`) independently, with no shared cache across jobs.

**Trigger:**

Every push to `main` or any PR triggers all three workflows simultaneously. Each runner starts clean, downloads the full package graph, and discards it on exit. On a moderate PR load (5 pushes/day), this wastes ~30–60 CI minutes/day across the three workflows.

**Impact:**

Slow CI feedback loop (feedback delayed), wasted free macOS minutes (which are scarce on free-tier GitHub Actions), and increased risk of flaky network-dependent failures (pub.dev timeouts).

---

## Finding 2 — CI: `flutter test` Without `--no-pub` (Redundant Resolution Pass)

**Severity:** MEDIUM
**Category:** redundant work / logic error
**Location:** `.github/workflows/quality.yml:44`

**Evidence:**

```yaml
- name: Install dependencies
  run: flutter pub get          # step 1: resolves dependencies

- name: Run tests with coverage
  run: flutter test --coverage  # step 2: resolves dependencies AGAIN (implicit --pub)
```

`flutter test` without `--no-pub` runs `flutter pub get` internally before running tests. Since the preceding step already ran `flutter pub get`, this performs a second resolution pass. The second pass is fast when the cache is warm (it verifies rather than downloads), but it is still non-zero overhead, and it is semantically redundant.

**Analysis:**

After `flutter pub get` has been run and `pubspec.lock` is current, invoking `flutter test` without `--no-pub` triggers an implicit pub resolution that re-reads and validates the lock file. On a cold runner without the Pub cache (see Finding 1), this second pass can re-initiate partial downloads of packages that were not fully cached by the first pass. On a warm cache, it adds ~5–15 seconds of lock-validation overhead per test run. The correct pattern is `flutter pub get` followed immediately by `flutter test --no-pub`, making the intent explicit and preventing any double-resolution.

**Trigger:**

Any CI run of `quality.yml`. The double-resolution is deterministic, not conditional.

**Impact:**

Additional 5–30 seconds per `quality.yml` run (minor on CI, but the pattern is subtly wrong and misleads developers who copy the CI invocation locally).

---

## Finding 3 — Local: No Makefile, Script, or Tool Encoding `--no-pub` Shortcut

**Severity:** MEDIUM
**Category:** missing validation / developer-experience gap
**Location:** Project root (no `Makefile`, `justfile`, `run_tests.sh`, or equivalent found)

**Evidence:**

```
$ find /home/paolo/Sviluppo/metra -maxdepth 2 \
    \( -name "Makefile" -o -name "justfile" -o -name "*.sh" -o -name "run_tests*" \)
/home/paolo/Sviluppo/metra/tools/add_license_header.sh
/home/paolo/Sviluppo/metra/tools/check_license_headers.sh
```

The only shell scripts in the project are the license-header tools. No test runner script exists. The workaround (`flutter test --no-pub`) is undocumented and unenforced.

**Analysis:**

The `--no-pub` flag is safe precisely when `pubspec.lock` is already current — i.e., after an explicit `flutter pub get` or after any CI `Install dependencies` step. It is _unsafe_ when the lock file is stale (a developer has edited `pubspec.yaml` but not run `flutter pub get`). Without a script that enforces the pre-condition check, a developer who blindly uses `--no-pub` after editing `pubspec.yaml` will run tests against mismatched dependencies, producing silent false passes or mysterious failures.

A safe local wrapper must:
1. Detect whether `pubspec.yaml` has been modified since `pubspec.lock` was last written.
2. If stale: run `flutter pub get` first, then `flutter test --no-pub`.
3. If current: skip to `flutter test --no-pub` directly.

Without this enforcement, the workaround is only partially correct: it works for developers who remember the pre-condition but silently fails for those who do not.

**Trigger:**

A developer edits `pubspec.yaml` (adds a dependency), does not run `flutter pub get`, then runs `flutter test --no-pub` from a cached script or muscle memory. Tests execute against the old lock, not the new one. The new dependency resolves at import time to a stale version or is absent, yielding compilation errors that are confusing because the pub graph was bypassed.

**Impact:**

Silent test-against-wrong-dependencies scenario; misleading test results; risk of shipping code whose test coverage was validated against a different dependency set than production.

---

## Finding 4 — CI: `subosito/flutter-action@v2` Pinned to Floating Tag (No SHA Pin)

**Severity:** LOW
**Category:** dependency hygiene / supply-chain risk
**CWE:** CWE-829 (Inclusion of Functionality from Untrusted Control Sphere)
**Location:** `.github/workflows/quality.yml:17`, `android.yml:17`, `ios.yml:17`

**Evidence:**

```yaml
uses: subosito/flutter-action@v2
```

Pinned to a mutable tag (`@v2`) rather than an immutable commit SHA. If the `subosito/flutter-action` repository is compromised or the `v2` tag is force-pushed, all three workflows would silently execute arbitrary code in the CI environment, which has access to repository secrets (`DROPBOX_APP_KEY`).

**Analysis:**

This is a well-known GitHub Actions supply-chain risk. The security-baseline rule "Pin dependency versions" applies to Actions as well as Pub packages. `@v2` is a mutable pointer. The immutable form is `subosito/flutter-action@<full-sha256>`.

**Trigger:**

Malicious or accidental force-push to the `subosito/flutter-action` `v2` tag. The next CI run picks up the altered action.

**Impact:**

Potential secret exfiltration (`DROPBOX_APP_KEY`) or arbitrary code execution in CI.

---

## Summary of Findings

```
SUMMARY: 4 findings (0 critical, 1 high, 2 medium, 1 low)
Highest-risk area: .github/workflows/ (all three workflows share the same pattern)
Recommended next action: Add pub cache to subosito/flutter-action; add --no-pub to flutter test in CI; add Makefile with staleness-aware test target; pin Actions to commit SHAs.
```

---

## Spec Inputs

### Root Cause Analysis

**Is this a local-only issue, a CI-only issue, or both?**

Both, with different root causes:

| Context | Root cause | Symptom |
|---|---|---|
| Local development | No enforced `--no-pub` wrapper; no staleness guard | >30 min cold start when `flutter test` re-resolves 147 packages |
| CI (`quality.yml`) | No Pub cache configured in `subosito/flutter-action`; `flutter test` runs without `--no-pub` (double-resolution) | Every run downloads full package graph; ~5–15 min overhead |
| CI (`android.yml`, `ios.yml`) | No Pub cache configured | Same as above for build steps |

The local cold-start is the more severe developer-experience pain (>30 min vs. ~5–15 min in CI) because the local Pub cache may be cold after a clean install or OS reinstall, whereas CI runners always start cold.

The CI issue is less painful per-run but compounds with frequency: every push to main and every PR triggers all three workflows, each paying the full package-download cost.

### Affected Workflows and Scripts

- `.github/workflows/quality.yml` — `flutter pub get` + `flutter test --coverage` (no cache, double-resolution)
- `.github/workflows/android.yml` — `flutter pub get` (no cache)
- `.github/workflows/ios.yml` — `flutter pub get` × 2 (two jobs: `build_ios` and `deploy_testflight`, each running `flutter pub get` independently with no shared cache)
- No local dev scripts exist. No Makefile, justfile, or `tools/test.sh`.

### Constraints

1. **CI must remain reliable.** `--no-pub` must never be used in CI without a prior `flutter pub get` step that has succeeded. The existing `Install dependencies` step satisfies this precondition, so `--no-pub` on the `flutter test` step is safe in CI.
2. **`--no-pub` is only safe when `pubspec.lock` is current.** Any script encoding this shortcut locally must guard against a stale lock file (compare `pubspec.yaml` mtime against `pubspec.lock` mtime, or use `dart pub deps --json` to detect mismatches).
3. **Pub cache correctness.** GitHub Actions Pub cache keyed on `pubspec.lock` hash is safe: a lock-file change invalidates the cache, forcing a fresh `flutter pub get`. This is the correct cache key.
4. **License headers on new scripts.** Per project conventions, any new shell script in `tools/` must carry the GPL-3.0 license header.
5. **`subosito/flutter-action` cache parameter.** Passing `cache: 'pub'` to `subosito/flutter-action@v2` is the minimal CI fix and does not require any workflow restructuring.

### Suggested Fix Approach

**Fix 1 (CI — HIGH priority): Enable Pub cache in `subosito/flutter-action`**

In all three workflow files, change:

```yaml
- name: Setup Flutter
  uses: subosito/flutter-action@v2
  with:
    flutter-version: '3.x'
    channel: stable
```

to:

```yaml
- name: Setup Flutter
  uses: subosito/flutter-action@v2
  with:
    flutter-version: '3.x'
    channel: stable
    cache: 'pub'
```

This instructs the action to restore and save `~/.pub-cache` keyed on `pubspec.lock`. On a cache hit, `flutter pub get` completes in seconds (offline validation only). On a cache miss, the full download runs and the result is cached for subsequent runs.

**Fix 2 (CI — MEDIUM priority): Add `--no-pub` to `flutter test` in `quality.yml`**

Change:

```yaml
- name: Run tests with coverage
  run: flutter test --coverage
```

to:

```yaml
- name: Run tests with coverage
  run: flutter test --no-pub --coverage
```

This is safe because the `Install dependencies` step immediately precedes it. Eliminates the redundant second resolution pass.

**Fix 3 (Local — MEDIUM priority): Add a `Makefile` with a staleness-aware `test` target**

Create `/home/paolo/Sviluppo/metra/Makefile`:

```makefile
.PHONY: test pub-get

# Run tests. If pubspec.yaml is newer than pubspec.lock (stale lock),
# run flutter pub get first. Otherwise skip to --no-pub for speed.
test:
	@if [ pubspec.yaml -nt pubspec.lock ]; then \
	  echo "pubspec.lock is stale — running flutter pub get first..."; \
	  flutter pub get; \
	fi
	flutter test --no-pub

pub-get:
	flutter pub get
```

The `pubspec.yaml -nt pubspec.lock` shell test (`-nt` = newer-than) is a POSIX-compatible staleness guard. It correctly handles the case where a developer edits `pubspec.yaml` without running `flutter pub get`.

**Fix 4 (CI — LOW priority): Pin `subosito/flutter-action` to a commit SHA**

Replace `uses: subosito/flutter-action@v2` with `uses: subosito/flutter-action@<full-commit-sha>` in all three workflow files to eliminate the mutable-tag supply-chain risk (CWE-829).
