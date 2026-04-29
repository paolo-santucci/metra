---
name: L1 and L2 audit state
description: Status of MASVS v2 L1 baseline and L2 target documents for Métra, as of 2026-04-28
type: project
---

**L1 baseline:** `docs/security/masvs-l1-baseline.md`
- Commit reference: 7ac2fd9 (P-1, updated 2026-04-28)
- 14 PASS + 6 N/A + 4 FAIL = 88% L1 (excluding deferred P-7 FAILs) — above ≥80% threshold
- Controls promoted to PASS in P-1: STORAGE-1, PLATFORM-3, CODE-4 (all were "parziale")
- L1 hard FAILs: STORAGE-2 (allowBackup), RESILIENCE-2 (debug key signing)
- L1 deferred FAILs: RESILIENCE-1, RESILIENCE-3 (both deferred P-7)

**L2 target doc:** `docs/security/masvs-l2-targets.md`
- Commit reference: b20f4d4 (not updated in P-1 — no L2 gaps were closed)
- Current L2 score: 9 PASS + 4 N/A + 6 DEFERRED = 19/24 = **79%** — BELOW ≥80% threshold
- Tag v0.1.0-p1 is blocked by L2 < 80%. Unblocked by closing R-01 (STORAGE-2) → 83%.
- Active L2 FAILs: STORAGE-1, STORAGE-2, CRYPTO-2, CODE-1, CODE-3, RESILIENCE-2

**P-1 delta doc:** `docs/security/masvs-p1-delta.md` (new, 2026-04-28)

**Pre-distribution blocker (separate from deferred L2 items):** RESILIENCE-2 — release build signed with debug key. Must be fixed before any external distribution.

**Why:** Tracks what has been audited so incremental reviews can focus on new surfaces and avoid re-flagging closed issues.
**How to apply:** When doing review after a PR, cross-reference the L2 FAIL list to check if any were closed. Update both audit docs accordingly.
