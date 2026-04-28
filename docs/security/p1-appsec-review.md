<!-- Copyright (C) 2026  Paolo Santucci — Métra Security Review -->

# P-1 AppSec Review

**Date:** 2026-04-28
**Scope:** Wave 2 additions (daily-entry screens, calendar, providers)
**Reviewer:** appsec-engineer (automated)

## Summary

| Control | Result |
|---------|--------|
| M1 — Improper Credential Usage | PASS |
| M2 — Inadequate Supply Chain | PASS |
| M9 — Insecure Data Storage | PASS |

**Overall verdict:** PASS

No Critical or High findings. One Info observation documented below.

---

## Threat model (synthesis)

**Assets:** `DailyLogEntity` fields (flow intensity, spotting, pain, notes), `PainSymptomData` (symptom types), `DateTime` family keys, Drift ORM data path from UI → repository → SQLCipher.

**Trust boundary:** All code in scope executes inside the app process. The app process itself is the trust boundary: data never crosses it except through the Drift ORM writing to the SQLCipher-encrypted database on-device. No network I/O touches any of these files. No IPC surface is introduced.

**Attackers considered:** (a) a malicious app reading system logs on a rooted/compromised device, (b) a compromised dependency introduced via pubspec.yaml, (c) a developer accidentally leaking PII through debug tooling left in production builds.

---

## Findings

### F-001 — `debugPrint` inside `assert` block: correct idiom, document explicitly

- **Severity:** Info
- **File:** `lib/features/daily_entry/historical_entry_screen.dart:155–158`
- **Description:** A `debugPrint` call that logs symptom-persistence failure details is wrapped in an `assert(() { debugPrint('replacePainSymptoms failed: $e'); return true; }())` block. The Dart compiler strips `assert` statements entirely in release mode (`dart compile` with `--no-enable-asserts`, Flutter release profile), so this `debugPrint` is unreachable in production. The technique is the canonical Dart idiom for debug-only side effects.

  The exception `$e` here is a Drift `InvalidDataException` or a platform storage error carrying only ORM metadata (symptom-type integer index, UTC date integer). It does not and cannot contain user-facing notes, flow values, or any PII from `DailyLogEntity` fields — the symptom-replace path receives only `PainSymptomData` objects whose sole field is `PainSymptomType` (an enum).

- **Recommendation:** No code change required. Add an inline comment making the guarantee explicit so a future reviewer does not "fix" this into a bare `debugPrint` outside the assert, which *would* be a Medium finding:

  ```dart
  // assert-wrapped: stripped in release builds (Dart --no-enable-asserts).
  // $e contains only Drift ORM metadata; no PII from DailyLogEntity reaches here.
  assert(() {
    debugPrint('replacePainSymptoms failed: $e');
    return true;
  }());
  ```

---

## Evidence base

### M1 — Improper Credential Usage

All files were searched for `print(`, `debugPrint(`, and Riverpod state exposure:

- No DB key or OAuth token reference exists anywhere in the daily-entry or calendar layer.
- The `dailyEntryProvider` family key is a `DateTime` normalized to UTC midnight. This is a temporal reference, not a secret. Its presence in provider state does not leak any user health data.
- Route parameter `/daily-entry/<yyyy-mm-dd>` encodes only a calendar date — explicitly acknowledged as non-sensitive in the audit brief and confirmed by reading `calendar_screen.dart:298` and the router configuration. The date does not encode which data fields are populated.
- `DailyEntryNotifier.save()` carries a `// Do not log DailyLogEntity fields — security requirement.` comment at line 61, with no logging statement following it. The same comment appears in `_HistoricalEntryScreenState._initFromLog()` at line 94.
- `DailyEntryNotifier.delete()` catches `(e, st)` and transitions to `AsyncError(e, st)` — the stack trace is held in Riverpod in-memory state, never written to persistent storage, and not rendered to the UI (the error state is consumed by a generic snack bar).
- `SaveDailyLog.call()` at line 72 constructs `StorageException('Failed to save daily log: $e')` wrapping the caught exception string. This string enters `Err<T>` and is eventually caught by `DailyEntryNotifier.save()` which sets `state = AsyncError(error, StackTrace.current)`. The string is never shown to the user: both `QuickEntryModal._save()` (line 96) and `HistoricalEntryScreen._save()` (line 136) check `is AsyncError` and render only `l10n.common_error_generic`. No internal exception detail reaches the screen or a log sink.

### M2 — Inadequate Supply Chain

`git diff main -- pubspec.yaml pubspec.lock` shows no changes to runtime dependencies in the P-1 wave commit (`f9671df`). The only pubspec.yaml delta is the addition of `test/goldens_fonts/` under the `flutter.assets` section — a test-only font asset, not a package dependency.

All imports in the eleven audited files are exclusively:
- `dart:async` (Dart SDK)
- `package:flutter/material.dart`
- `package:flutter_riverpod/flutter_riverpod.dart`
- `package:go_router/go_router.dart`
- `package:intl/intl.dart`
- `package:drift/drift.dart` (in the repository layer only)
- `package:metra/…` (project-internal paths)

No unexpected third-party packages. No hard-coded URLs, tokens, or API keys appear anywhere in the audited surface.

### M9 — Insecure Data Storage

The only `debugPrint` in the scope is F-001 above, which is release-stripped and carries no PII.

Widget `Key` values were audited across all files:
- `ValueKey<String>('loading')`, `ValueKey<String>('error')`, `ValueKey<String>('form')` — literal strings, no data.
- `ValueKey<bool>(selected)` in `FlowIntensityPicker` — Boolean selection state, not user health data.
- `ValueKey<bool>(true)` / `ValueKey<bool>(false)` in `PainIntensitySlider` — Boolean visibility state.
- `const ValueKey<bool>(true/false)` in `_SliderContent` — Compile-time constants.

No `Key(log.notes)`, `Key(log.flowIntensity.toString())`, or any PII-derived key was found.

`TextEditingController` for notes is created in `initState()` and disposed in `dispose()` — standard Flutter lifecycle, no retention beyond widget lifetime.

`_existingLog` held in `_QuickEntryModalState` is necessary to preserve pain/notes fields during the save-merge operation (the quick-entry modal only edits flow/spotting and must not destroy existing pain data). It is a `ConsumerStatefulWidget` field — disposed with the widget when `context.pop()` is called. This is the correct pattern.

`CalendarMonthState.logs` holds a `Map<DateTime, DailyLogEntity>` for the displayed month. This is in-memory Riverpod state, synchronized from the SQLCipher DB via Drift stream. It is not persisted anywhere outside the ORM and is garbage-collected when `calendarMonthProvider` is disposed. No PII leaks from this map into logs, keys, or navigation state.

---

## Defense-in-depth observations

These are not findings but complementary controls worth maintaining:

1. The `analysis_options.yaml` rule `avoid_print` is already active per the P-1 commit message, which means any bare `print(` call outside an `assert` block will fail CI. This is the correct systemic control for the whole PII-logging risk class.
2. The `// Do not log DailyLogEntity fields — security requirement.` inline comment pattern establishes a useful convention. Keeping it at every `DailyLogEntity` parameter entry point (save, initFromLog) documents the threat model inline.
3. `_symptomsInitialized` guard in `HistoricalEntryScreen._save()` prevents a race condition where symptom chips saving over an empty set could silently erase DB data before the async load completes. This is a correctness control that also reduces the blast radius of a partial data-loss scenario.

---

## Conclusion

The eleven files audited pass all three OWASP Mobile controls under review. No secrets are logged, no new packages were introduced, and all user PII (notes, flow, pain, symptoms) stays within the Drift ORM write path to the SQLCipher-encrypted database. The single observation (F-001) confirms that the one `debugPrint` present is correctly stripped in release builds using the canonical Dart assert idiom and operates on ORM metadata rather than health data. The codebase applies the `l10n.common_error_generic` pattern consistently for all user-visible error states, preventing internal exception details from reaching the UI. This review does not block tagging `v0.1.0-p1`.
