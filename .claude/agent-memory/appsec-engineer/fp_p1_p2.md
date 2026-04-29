---
name: False positives P-1 and P-2
description: Known grep false positives to suppress in future reviews of this codebase
type: feedback
---

Two recurring false positives when grepping for network/URL patterns:

1. **GPL license header** — every source file contains `<https://www.gnu.org/licenses/>` in its copyright block. Grep for `https` or `url` will always match line 16 of every `.dart` file. Exclude comment lines or license headers from network-I/O checks.

2. **`/daily-entry/:date` route parameter** — `TimelineCard` constructs the navigation path as `context.push('/daily-entry/$dateKey')` where `dateKey = cycle.startDate.toIso8601String().substring(0, 10)`. This is an intra-app `go_router` route, not an external URL. The value is programmatically generated from a `DateTime`, not user-typed. Not an SSRF/injection vector. Documented as Low (CWE-248: unguarded `int.parse`) in p2-appsec-review.md.

**Why:** Both patterns will recur in every future sprint review. Flagging them wastes triage time.

**How to apply:** Skip these patterns when they appear alone without a genuine network sink or external URL construction.
