# AppSec Engineer Memory Index

- [False positives P-1/P-2](fp_p1_p2.md) — URL in GPL license header matches network grep; route date param is internal-only (not attacker-controlled)
- [False positives and known patterns P-3](fp_p3.md) — SharedPreferences persistence by flutter_local_notifications is by design (backup excluded); notificationDaysBefore clamp deferred to P-4
- [Curated dependencies](curated_deps.md) — fl_chart 0.68.0 pre-approved before P-2; flutter_local_notifications 17.2.4, flutter_timezone 3.0.1, timezone 0.9.4 added in P-3, no CVEs
