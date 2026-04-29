---
date: 2026-04-29
decision: P-6 implements Dropbox only; Google Drive and OneDrive deferred to v1.1+
status: decided
---

For the first public release (v1.0), cloud sync ships with Dropbox only.
Google Drive and OneDrive will be added in v1.1 once the provider abstraction is proven.

Rationale: reduces OAuth surface area for the initial release; Dropbox uses
a standard OAuth 2.0 + PKCE flow with no additional SDK dependency beyond `http`.
