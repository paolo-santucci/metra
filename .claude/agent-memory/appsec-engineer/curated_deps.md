---
name: Curated dependencies baseline
description: Dependencies confirmed as pre-approved (curated in pubspec.yaml before the sprint under review)
type: project
---

The following dependencies were present in `pubspec.yaml` before any sprint work began and are considered curated/pre-approved for supply-chain purposes:

- `fl_chart: ^0.68.0` (resolved `0.68.0`) — charting library, activated (uncommented) in P-2, no new addition. No CVEs as of 2026-04-28.

- `flutter_local_notifications: ^17.2.2` (resolved `17.2.4`) — added in P-3. No CVEs as of 2026-04-29. Both Android BroadcastReceivers declared `exported="false"`. Persists notification title/body to app-private SharedPreferences for boot rescheduling — this is by design and the notification content was verified to contain zero health data.
- `flutter_timezone: ^3.0.0` (resolved `3.0.1`) — added in P-3. Reads IANA timezone via platform channel, no network I/O. No CVEs as of 2026-04-29.
- `timezone: ^0.9.0` (resolved `0.9.4`) — added in P-3. Loads bundled IANA data asset, no network I/O. No CVEs as of 2026-04-29.

**Why:** CLAUDE.md §3 lists the full curated stack. Any dependency that appears there before a sprint is not a supply-chain finding; only net-new additions require justification.

**How to apply:** Before filing an M2 finding, check whether the dep was already in pubspec.yaml in a prior commit. If yes, mark as Info (pre-approved) rather than a finding.
