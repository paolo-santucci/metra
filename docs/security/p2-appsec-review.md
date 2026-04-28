<!-- Copyright (C) 2026  Paolo Santucci — Métra Security Review -->

# P-2 AppSec Review

**Date:** 2026-04-28
**Scope:** Wave 3 additions (timeline, stats screens, cycle-summary and stats-data domain layer)
**Reviewer:** appsec-engineer (automated)

---

## 1. Scope

| # | File |
|---|------|
| 1 | `lib/domain/entities/cycle_summary.dart` |
| 2 | `lib/domain/entities/cycle_stats_data.dart` |
| 3 | `lib/domain/use_cases/get_cycle_summaries.dart` |
| 4 | `lib/domain/use_cases/compute_cycle_stats.dart` |
| 5 | `lib/providers/use_case_providers.dart` (new entries: `getCycleSummariesProvider`, `computeCycleStatsProvider`) |
| 6 | `lib/features/timeline/state/timeline_controller.dart` |
| 7 | `lib/features/timeline/widgets/timeline_card.dart` |
| 8 | `lib/features/timeline/widgets/timeline_view.dart` |
| 9 | `lib/features/timeline/widgets/table_view.dart` |
| 10 | `lib/features/timeline/timeline_screen.dart` |
| 11 | `lib/features/stats/state/stats_controller.dart` |
| 12 | `lib/features/stats/widgets/stat_card.dart` |
| 13 | `lib/features/stats/widgets/cycle_length_chart.dart` |
| 14 | `lib/features/stats/widgets/period_length_chart.dart` |
| 15 | `lib/features/stats/widgets/symptom_frequency_chart.dart` |
| 16 | `lib/features/stats/widgets/flow_intensity_chart.dart` |
| 17 | `lib/features/stats/stats_screen.dart` |

---

## 2. Methodology

Review is structured around **OWASP Mobile Top 10 (2024)** with emphasis on the controls most relevant to a display-only, local-first data layer:

- **M1 — Improper Credential Usage:** search for API keys, tokens, passwords, or hardcoded secrets in source and comments.
- **M2 — Inadequate Supply Chain Security:** verify no new dependencies were silently introduced; confirm `fl_chart` is a pre-approved, curated dependency (present in `pubspec.yaml` before this sprint).
- **M5 — Insecure Communication:** confirm no HTTP/HTTPS calls, no network sockets, no remote URL construction were introduced in P-2 files.
- **M9 — Insecure Data Storage:** verify no health data (`DailyLog`, symptoms, notes, flow intensity, dates) is written to system logs via `print`, `debugPrint`, or `dart:developer log()` in any production code path.

Additional checks performed:
- **Privacy / PII leakage:** semantic labels, widget keys, error handlers — confirmed no PII reaches untrusted sinks.
- **Injection surface:** navigation tap in `TimelineCard` constructs a local `go_router` path; verified it is an intra-app route, not an external URL.
- **Route parameter safety:** `app_router.dart:/daily-entry/:date` parses the `dateKey` via `int.parse` on split components; crash risk on malformed input (noted as Low — attacker surface is internal navigation only, documented below).

Tooling executed:
- Manual grep for `print|debugPrint|developer\.log` across all 17 files — no matches.
- Manual grep for `http|HttpClient|dio|Uri|socket|fetch|network` across domain and controller files — no matches (only GPL comment URL in license header).
- Manual grep for `apikey|password|secret|token|credential|bearer` — no matches.
- `pubspec.lock` verified: `fl_chart` resolves to `0.68.0`, consistent with `pubspec.yaml ^0.68.0`. Dependency was present before this sprint (pre-approved per CLAUDE.md §3).
- `semgrep` and `gitleaks` not installed in this environment; findings are based on manual review.

---

## 3. Findings

| Severity | OWASP | File | Finding | Recommendation |
|----------|-------|------|---------|----------------|
| Info | M1 | all 17 files | No credentials, API keys, tokens, or hardcoded secrets found anywhere in P-2 scope. | No action required. |
| Info | M2 | `pubspec.yaml` / `pubspec.lock` | `fl_chart` (resolved `0.68.0`) was already listed as a curated dependency in `pubspec.yaml` before this sprint. It was activated (uncommented) rather than newly introduced. No net-new dependency was added. No known CVEs in OSV database for this version. | Periodically run `flutter pub outdated` and `osv-scanner -r .` as part of CI to catch future advisories. |
| Info | M5 | all 17 files | Zero network I/O in P-2. No `http`, `HttpClient`, `Dio`, `Uri`, or socket usage found in any new file. `GetCycleSummaries` and `ComputeCycleStats` are pure in-process data pipelines over Drift streams. | No action required. |
| Info | M9 | all 17 files | No `print`, `debugPrint`, or `dart:developer log()` call found in any P-2 file. Health data (`CycleSummary`, `CycleDataPoint`, symptom frequencies, flow intensity, cycle dates) is held in Riverpod state only and never written to system logs. | No action required. |
| Low | M9 / CWE-248 | `lib/router/app_router.dart:48-53` | `int.parse(parts[N])` on the `:date` path parameter (produced by `timeline_card.dart:117`) is unguarded. An internally malformed date string (e.g. produced by a future bug in `toIso8601String().substring(0,10)`) would throw an uncaught `FormatException` at the router level, resulting in a blank/crash screen rather than a graceful error. The attacker surface is internal navigation only (the value is generated programmatically, not typed by the user) — exploitability is negligible. | Wrap the parse block in a `try/catch FormatException` and redirect to a safe fallback route. Example: `try { ... } on FormatException { return const ErrorScreen(); }` |

---

## 4. Threat model (synthesis)

**Assets:** Aggregated health data — `CycleSummary` (start/end dates, dominant flow, symptom types), `CycleStatsData` (cycle-length data points, symptom frequencies). These are derived views of `DailyLog` data already protected by SQLCipher at rest.

**Trust boundary:** All P-2 code executes exclusively inside the app process. Data flows are: SQLCipher DB → Drift ORM → Repository → Use Case → Riverpod state → Widget tree. No boundary crossing occurs; there is no IPC, no file write, no network egress, no clipboard write, no inter-app intent in these files.

**Attackers considered:**
- (a) A malicious app reading logcat/system logs on a rooted device — mitigated: no logging of health data confirmed.
- (b) A compromised dependency — mitigated: no new dependency introduced; `fl_chart` is a well-maintained, widely-used charting library with no open CVEs.
- (c) A developer accidentally leaking PII through debug instrumentation — mitigated: no debug calls found.

---

## 5. Verdict

**PASS**

Zero Critical findings. Zero High findings. One Low finding (internal route parameter parse, negligible exploitability). The P-2 surface is display-only, contains no network I/O, no credential usage, and no health-data logging. The local-first, zero-telemetry architecture is correctly preserved across all new files.

---

## 6. Defense-in-depth recommendations

Beyond the Low finding above, the following compensating controls are recommended for future sprints:

1. **Add `osv-scanner -r .` to CI** (`quality.yml` workflow) to automatically flag new dependency advisories on every push.
2. **Install `semgrep` in CI** with `p/owasp-top-ten` and `p/dart` rulesets to catch injection and logging patterns at scale as the codebase grows.
3. When the backup/sync surface (P-4+) is introduced, re-run M5 and M8 checks — that will be the first sprint where network I/O and data serialization boundaries are crossed.
