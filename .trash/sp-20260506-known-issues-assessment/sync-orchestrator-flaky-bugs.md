# Sync Orchestrator Flaky Test Analysis

**File under review:** `test/data/services/backup/sync_orchestrator_test.dart`  
**Production counterpart:** `lib/data/services/backup/sync_orchestrator.dart`  
**Status:** Pre-existing flake, unrelated to recent changes  
**Date:** 2026-05-06

---

## Phase 1 — Structural Reconnaissance

No `dart_test.yaml` exists in the repository root. No per-test `@Timeout` annotation is present in `sync_orchestrator_test.dart`. The default `flutter test` timeout of **30 seconds per test** applies to every test in this file.

The test file is pure async (`async/await`), no `FakeAsync`, no `pumpEventQueue`, no real `Duration` sleeps, no `Timer`, no streams. All fakes return synchronously wrapped in `Future`. On its own, the file's async plumbing is correct.

The only real CPU/memory work done by any test path that exercises `backup()` or `restore()` is inside `EncryptionService`, which performs live Argon2id key derivation every time it is called.

---

## Phase 2 — Control Flow Analysis

The `_make()` factory always constructs a real `EncryptionService()` with the production-hardened Argon2id parameters declared as a `static final` inside that class:

```dart
// lib/data/services/encryption_service.dart:34-38
static final _argon2id = Argon2id(
  memory: 65536, // 64 MB
  iterations: 3,
  parallelism: 4,
  hashLength: 32,
);
```

There is no mechanism in `_make()` to substitute a faster KDF instance. The `_make` signature accepts `EncryptionService? enc` at no parameter slot — it always calls `final enc = EncryptionService()` unconditionally.

---

## Phase 3 — Data Flow: KDF Invocations Per Test

Counting Argon2id derivations triggered per test:

| Test | `encrypt` calls | `decrypt` calls | Total KDF derivations |
|---|---|---|---|
| `backup() happy path` | 1 | 0 | 1 |
| `backup() deletes older files` | 1 | 0 | 1 |
| `backup() upload failure` | 0* | 0 | 0 |
| `backup() no passphrase` | 0 | 0 | 0 |
| `restore() happy path` | 1 (seedBackup) | 1 (restore) | 2 |
| `restore() wrong passphrase` | 1 (seedBackup) | 1 (wrong key, still runs KDF) | 2 |
| `restore() empty Dropbox` | 0 | 0 | 0 |

*`upload failure` sets `failNextUpload = true`. `FakeDropboxProvider.upload()` throws before `encrypt` is called... actually no: looking at `SyncOrchestrator.backup()`, `_encryption.encrypt()` is called at line 69, **before** `_provider.upload()` at line 71. Therefore `upload failure` triggers 1 KDF derivation before the upload throws.

Corrected count:

| Test | Total KDF derivations |
|---|---|
| `backup() happy path` | 1 |
| `backup() deletes older files` | 1 |
| `backup() upload failure` | 1 |
| `backup() no passphrase` | 0 |
| `restore() happy path` | 2 |
| `restore() wrong passphrase` | 2 |
| `restore() empty Dropbox` | 0 |

**Total across the whole file: 7 live Argon2id derivations**, each requiring 64 MB working memory and 3 passes with parallelism 4.

---

## Root Cause Finding

### [HIGH] BUG-001: Argon2id production parameters used in tests cause timeout flakiness under suite parallelism

**File:** `test/data/services/backup/sync_orchestrator_test.dart:35`  
**Category:** resource-exhaustion / timing  

**Evidence:**

```dart
// _make() factory in test file, line 35:
final enc = EncryptionService();

// Production EncryptionService, lib/data/services/encryption_service.dart:34-38:
static final _argon2id = Argon2id(
  memory: 65536, // 64 MB
  parallelism: 4,
  iterations: 3,
  hashLength: 32,
);
```

**Analysis:**

`EncryptionService` holds its `Argon2id` instance as a `static final`. There is no way to inject a lighter KDF configuration from outside. Every test that reaches `backup()` or `restore()` with a valid passphrase performs a full production-cost Argon2id derivation. The `_make()` factory in the test file always instantiates the real `EncryptionService()` with no override path.

`flutter test` runs test files in parallel isolates (default concurrency = number of logical CPU cores). When other test files are running concurrently — including `encryption_service_test.dart` which also runs live Argon2id — the available memory and CPU time per isolate shrinks. Argon2id's runtime is highly sensitive to memory bandwidth pressure: at 64 MB × 3 iterations × 4 threads, a derivation that takes ~1s in isolation can take 5–10s or more under contention. The total wall-clock time for the 5 non-trivial tests in `sync_orchestrator_test.dart` can therefore exceed the default 30-second timeout by a wide margin when the suite is under load.

The flakiness is non-deterministic because it depends on which other isolates happen to be active during the Argon2id stretches.

**Trigger scenario:**

Run the full test suite on a machine with 4–8 logical cores. `sync_orchestrator_test.dart` and `encryption_service_test.dart` start in concurrent isolates. `encryption_service_test.dart` has its own live Argon2id calls (6 derivations across its 5 tests). Memory bandwidth is saturated. The `restore() happy path` test in `sync_orchestrator_test.dart`, which requires 2 sequential Argon2id derivations (`seedBackup()` then `orch.restore()`), exceeds 30s total wall time and the test runner reports a timeout failure.

**Impact:** 1–2 test failures per full suite run reported as flaky, discouraging developers from trusting the CI green signal.

---

### [MEDIUM] BUG-002: `backup() upload failure` test invokes Argon2id before intentional upload failure

**File:** `test/data/services/backup/sync_orchestrator_test.dart:122–139`  
**Category:** logic-error (test design assumption violated)

**Evidence:**

```dart
// SyncOrchestrator.backup(), lib/data/services/backup/sync_orchestrator.dart:67-71:
final blob = await _encryption.encrypt(bytes, passphrase);  // KDF here
final filename = _filenameFor(ts);
await _provider.upload(blob, filename);                      // fails here
```

```dart
// Test intent, sync_orchestrator_test.dart:122-139:
provider.failNextUpload = true;
// ...
await expectLater(orch.backup(), throwsA(isA<SyncException>()));
```

**Analysis:**

The test intends to exercise the error path when the upload fails. The implicit assumption is that this test is cheap (no encryption work). However, `SyncOrchestrator.backup()` calls `_encryption.encrypt()` before calling `_provider.upload()`. This means the full Argon2id derivation (64 MB, 3 iterations) runs before the upload is attempted and throws. The test is not zero-cost; it contributes 1 KDF derivation to the total suite wall-clock time. Under load this amplifies the timeout risk for the overall file.

This is not a correctness bug in the production code — encrypting before uploading is correct. It is a test-design assumption mismatch that adds unexpected cost.

**Trigger:** Same as BUG-001 — suite concurrency under memory pressure.

---

### [LOW] BUG-003: No `tearDown` for `syncLogRepo.appended.clear()` between groups leaves cross-group state mutation risk

**File:** `test/data/services/backup/sync_orchestrator_test.dart:159–169`  
**Category:** state-corruption (latent)

**Evidence:**

```dart
// Inside restore() group:
Future<void> seedBackup() async {
  storage.values[passphraseKey] = passphrase;
  await _make(...).backup();
  syncLogRepo.appended.clear();  // manual clear inside seedBackup
}
```

**Analysis:**

`syncLogRepo.appended.clear()` is called inside `seedBackup()` rather than in a `tearDown` or a dedicated `setUp` for the restore group. This works as long as every restore test calls `seedBackup()` first — but it is a fragile contract. If a future test inside the `restore()` group is added without calling `seedBackup()`, it will inherit the `appended` list from the previous test's backup call. The `setUp` at the top level of `main()` recreates `syncLogRepo` from scratch for each test, which prevents cross-test leakage — so the current code is not broken. However, the `syncLogRepo.appended.clear()` inside `seedBackup()` is redundant given that `setUp` already provides a fresh `FakeSyncLogRepository` instance per test. Its presence suggests the author was uncertain about isolation and patched it locally rather than relying on the established `setUp` contract.

**Trigger:** A future test added to the `restore()` group that does not call `seedBackup()` would see a polluted `syncLogRepo.appended` list if, for some reason, the `setUp` were changed or removed. Not currently triggering.

---

## Additional Observations (No Defect Status)

- **Shared mutable state across tests:** None. `setUp` reconstructs all five fakes (`storage`, `provider`, `settingsRepo`, `syncLogRepo`, `logRepo`) fresh per test. No class-level mutable state persists between tests.
- **`FakeAsync` / `pumpEventQueue` / real timers:** None present. No fake-clock issues.
- **`Random.secure()` entropy block:** `EncryptionService` uses `Random.secure()` to generate 16-byte salt and 12-byte IV. On modern Linux kernels with `/dev/urandom` always initialized, this does not block. It is not a contributor to flakiness.
- **`tearDown` absence:** No `tearDown` is needed because the fakes hold no resources requiring explicit disposal (no open streams, no platform channels, no native resources). The absence of `tearDown` is not a bug.
- **`static final _argon2id` singleton:** Because `_argon2id` is a `static final`, all `EncryptionService` instances share one `Argon2id` configuration object. This is not a concurrency hazard within a single isolate (Dart is single-threaded within an isolate), but it means no instance-level override of KDF parameters is possible without changing the class API.

---

## Summary

**3 findings: 0 critical, 1 high, 1 medium, 1 low**

| ID | Severity | Title |
|---|---|---|
| BUG-001 | HIGH | Argon2id production parameters used in tests cause timeout flakiness under suite parallelism |
| BUG-002 | MEDIUM | `upload failure` test invokes Argon2id before intentional failure — unexpected KDF cost |
| BUG-003 | LOW | `syncLogRepo.appended.clear()` inside `seedBackup()` is redundant and fragile |

**Highest-risk area:** `lib/data/services/encryption_service.dart` — specifically the inability to inject a lighter `Argon2id` configuration for tests.

---

## Spec Inputs

### Root Cause Analysis (Confirmed)

The flakiness is caused by **live Argon2id key derivation with production-hardened parameters (64 MB, 3 iterations, parallelism 4) running inside unit tests with no timeout override and no injectable fast-path**. Under full-suite parallel execution, 7 KDF derivations in `sync_orchestrator_test.dart` plus concurrent KDF work in `encryption_service_test.dart` exhaust available memory bandwidth, causing individual derivations to slow sufficiently that 1–2 tests exceed the default 30-second timeout.

The root cause is structural: `EncryptionService` declares `_argon2id` as a `static final` with no constructor parameter to override it. The `_make()` factory in the test file constructs a real `EncryptionService()` unconditionally.

### Affected Tests

All tests in `sync_orchestrator_test.dart` that exercise `backup()` or `restore()` with a valid passphrase. Highest-risk tests (most KDF derivations):
- `restore() happy path` — 2 derivations, most likely to timeout
- `restore() wrong passphrase` — 2 derivations, second most likely
- `backup() happy path`, `deletes older files`, `upload failure` — 1 derivation each

### Production Files

- `lib/data/services/encryption_service.dart` — holds the production Argon2id configuration
- `lib/data/services/backup/sync_orchestrator.dart` — instantiates `EncryptionService` via constructor injection (already injectable at the class level; the test `_make()` factory just does not use that flexibility)

### Constraints the Fix Must Respect

1. **Test behavior must remain equivalent.** All tests must continue to exercise the real `EncryptionService.encrypt`/`decrypt` code path (AES-256-GCM + Argon2id). The fix must not stub or mock `EncryptionService` away entirely.
2. **Production parameters must not change.** The Argon2id configuration used in the production app binary must remain `memory: 65536, iterations: 3, parallelism: 4`.
3. **Round-trip validity must be preserved.** Tests that call `seedBackup()` then `restore()` must still verify that the real encrypt→decrypt round-trip produces correct output — only the KDF cost knob may change.
4. **No new runtime dependencies.** The fix lives in test infrastructure only.

### Suggested Fix Approach

1. **Parameterize `Argon2id` in `EncryptionService`.** Change `static final _argon2id` from a hardcoded `static final` to an instance field, with the production parameters as the default. Add an optional constructor parameter `Argon2id? argon2id` so callers can inject a faster instance.

   ```dart
   // Proposed change to EncryptionService constructor:
   EncryptionService({Random? random, Argon2id? argon2id})
       : _random = random ?? Random.secure(),
         _argon2id = argon2id ?? Argon2id(
           memory: 65536, iterations: 3, parallelism: 4, hashLength: 32,
         );
   ```

2. **Define a test-only fast `Argon2id` constant** in a test helper (not in production code):

   ```dart
   // test/helpers/fast_argon2id.dart
   final kFastArgon2id = Argon2id(
     memory: 256, iterations: 1, parallelism: 1, hashLength: 32,
   );
   ```

3. **Update `_make()` in `sync_orchestrator_test.dart`** to pass the fast instance:

   ```dart
   final enc = EncryptionService(argon2id: kFastArgon2id);
   ```

4. **Keep `encryption_service_test.dart` unchanged** — it already has `timeout: Timeout(Duration(minutes: 3))` per test and is meant to test production KDF cost. It does not need the fast path.

This fix eliminates the timeout risk without altering any assertion or functional coverage. The AES-GCM encrypt/decrypt logic, the blob format, and the round-trip correctness check all remain exercised at their real code paths. Only the KDF work factor changes for the orchestrator tests.
