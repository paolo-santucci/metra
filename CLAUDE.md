# CLAUDE.md — Instructions for Claude Code

> This file is the **primary context** for implementing Métra. Read it in full before writing any code. In case of conflict between this document and other sources, this one wins.

---

## 1. Project identity

**Name:** Métra (typographic wordmark: _Mētra_ with a macron on the e).
**What it is:** A mobile app for menstrual cycle tracking — **privacy-first**, **local-first**, **open-source** (GPL-3.0), free.
**What it is not:** Not a fertility tracker. Not a community. Not a SaaS. It is an _intimate digital notebook_ — closer to a Moleskine than to a fitness app.

**Etymology** (useful for class naming and documentation): from Ancient Greek _mētra_ (μήτρα) = womb, matrix, measure. Same Indo-European root as _mother_.

**Target user:** An adult person who wants to know her own rhythm without handing data to third parties. She is not looking for gamification, advice, or comparisons.

---

## 2. Core principles (non-negotiable)

Every PR, feature and refactor must respect these five principles. If a technical choice violates them, it must be rejected.

1. **Local-first.** Data lives on the user's device. No proprietary server. Ever. Cloud is _optional_ and serves only for backup/sync, never as source of truth.
2. **Zero-knowledge cloud.** The cloud provider (Google Drive / Dropbox / OneDrive) only ever sees **encrypted blobs**. The encryption key never leaves the device. There is no server-side password reset — because there is no server.
3. **No telemetry.** Zero analytics, zero third-party crash reporting, zero tracking. Diagnostic logs are local only and user-clearable.
4. **Accessibility built-in, not bolted-on.** WCAG 2.2 AA minimum, AAA where possible. An inaccessible screen is an incomplete screen — not a "todo for later".
5. **Respect the adult user.** No dark patterns, no gamification, no motivational notifications, no endless onboarding. The user knows what she is doing.

---

## 3. Tech stack

| Layer | Technology | Version |
|---|---|---|
| Framework | Flutter | 3.x |
| Language | Dart | latest stable |
| State management | Riverpod | ^2.5.1 |
| Local DB | Drift ORM | ^2.18.0 |
| DB encryption | SQLCipher (via `sqlcipher_flutter_libs`) | ^0.5.4 |
| Cryptography | `cryptography` package (AES-256-GCM + Argon2id) | ^2.7.0 |
| Keychain | `flutter_secure_storage` | ^9.2.2 |
| Routing | `go_router` | ^14.2.7 |
| Charts | `fl_chart` | ^0.68.0 |
| Fonts | `google_fonts` (Inter + DM Serif Display) | ^6.2.1 |
| Notifications | `flutter_local_notifications` + `flutter_timezone` | ^17.2.2 / ^3.0.0 |
| Device calendar | `device_calendar` | ^4.3.1 |
| Google OAuth | `google_sign_in` + `googleapis` | ^6.2.1 / ^13.2.0 |
| HTTP (Dropbox, OneDrive) | `http` | ^1.2.2 |
| File/Share/CSV | `file_picker` / `share_plus` / `csv` | ^8.1.2 / ^10.0.2 / ^6.0.0 |
| i18n | `intl` + Flutter gen_l10n | ^0.20.2 |

**Environment constraints:**
- Development on **Fedora Linux**. No Mac available.
- **Android**: development, emulator, physical device — all local.
- **iOS**: build via **GitHub Actions macOS runner** (free for public repos). Testing via **TestFlight** on a physical device. **No iOS simulator locally** — therefore: do not write code that depends on the iOS simulator to be verifiable.
- **License**: GPL-3.0 (every new source file must carry a license header).

---

## 4. Architecture

Layered structure, strictly unidirectional dependencies: `UI → Domain → Data`.

```
lib/
├── main.dart
├── app.dart                        # MaterialApp, theme, router
├── l10n/                           # arb files + generated
├── core/
│   ├── constants/                  # enums, constants (no magic numbers/strings in UI)
│   ├── errors/                     # domain Exception types
│   ├── utils/                      # date helpers, formatters
│   └── theme/                      # MetraTheme (light/dark), tokens
├── data/
│   ├── database/
│   │   ├── app_database.dart       # Drift tables
│   │   └── daos/                   # DAO per entity
│   ├── services/
│   │   ├── encryption_service.dart
│   │   ├── cycle_prediction_service.dart
│   │   ├── backup/
│   │   │   ├── backup_service.dart
│   │   │   ├── providers/          # GoogleDriveProvider, DropboxProvider, OneDriveProvider
│   │   │   └── sync_orchestrator.dart
│   │   ├── csv_service.dart
│   │   ├── device_calendar_service.dart
│   │   └── notification_service.dart
│   └── repositories/               # facade over DAOs + services
├── domain/
│   ├── entities/                   # pure models (no Drift imports)
│   └── use_cases/                  # testable application logic
└── features/
    ├── onboarding/
    ├── calendar/                   # HOME — tab 1
    ├── timeline/                   # tab 2 (timeline/table toggle)
    ├── stats/                      # tab 3
    ├── settings/                   # tab 4
    ├── daily_entry/                # quick entry (modal from calendar)
    └── backup/                     # OAuth flow + sync UI
```

**Layering rules:**
- `domain/` never imports from `data/` or `features/`.
- `features/` never imports directly from `data/database/` or `data/services/` — always through `repositories/`.
- Domain errors must not leak Drift or HTTP types.

---

## 5. Data model (Drift entities)

| Entity | Key fields | Notes |
|---|---|---|
| `DailyLog` | `date`, `flowIntensity`, `spotting`, `otherDischarge`, `painIntensity`, `painEnabled`, `notes`, `notesEnabled` | One row per day. Never more than one. |
| `PainSymptom` | `dailyLogId` (FK), `symptomType` (cramps/back/headache/migraine/custom), `customLabel` | Many-to-one with DailyLog. |
| `CycleEntry` | `startDate`, `endDate`, `cycleLength`, `periodLength` | Derived from DailyLog, **persisted for performance**. Recomputed on mutation. |
| `SymptomTemplate` | User-defined custom pain types | |
| `AppSettings` | Singleton (`id = 1`) | All global preferences. Never more than one row. |
| `SyncLog` | Cloud operations audit trail | Local only, never synced. |

**Critical data flow (backup):**
```
Local DB (SQLCipher)
  → In-memory JSON snapshot
  → AES-256-GCM with key derived from user passphrase (Argon2id)
  → Opaque .enc blob
  → Upload to Cloud Provider
```

The provider never sees cleartext data. There is no path where the key leaves the device.

---

## 6. MVP features (priority order)

Develop **in this order**. Do not start feature N+1 before N is tested and working.

1. **F-01** — Daily entry (flow/spotting/pain/notes) — **≤3 taps**
2. **F-02** — Monthly calendar with semantic encoding (see §8.2)
3. **F-06** — Next cycle prediction (WMA, N=6) + configurable notification
4. **F-03** — Vertical timeline + **F-04** dense table (segmented control toggle)
5. **F-05** — Statistics (fl_chart: cycle length, flow duration, symptom frequency)
6. **F-07** — Settings (language, theme, pain/notes toggles, notifications, backup)
7. **F-08** — E2E cloud sync: Google Drive → Dropbox → OneDrive (in this priority order)
8. **F-09** — CSV export/import
9. **F-10** — Device calendar integration (device_calendar)

**Out of MVP (v1.1+):** iCloud (requires native Swift Method Channel), sharing with gynecologist, tablet layouts, home-screen widget.

---

## 7. Prediction algorithm

**Weighted Moving Average (WMA)** over the last N=6 complete cycles:

```
weights = [1, 2, 3, 4, 5, 6]  # most recent cycle weighs the most
avg_length = Σ(cycle_length[i] × weight[i]) / Σ(weights)
next_start = last_cycle_start + avg_length
```

**Rules:**
- Require **at least 3 complete cycles** to generate a prediction. Below this threshold: show "insufficient data" state — do not guess.
- The prediction is a **3–5 day window**, never a single day (this communicates inherent uncertainty).
- Recompute on every mutation of `CycleEntry`.
- The service is **pure and testable**: `CyclePredictionService.predict(List<CycleEntry>) → Prediction?`. No side effects, no DB access.

---

## 8. Design system

### 8.1 Palette

**Light mode** (every color has a semantic role, never decorative):

| Name | Hex | Role |
|---|---|---|
| Sand | `#F4EDE2` | Primary background |
| Terracotta | `#C87456` | Primary accent, current flow |
| Dusty ochre | `#D4A26A` | Secondary accent, warmth, notes |
| Night lavender | `#5B4E7A` | Predictions, future data |
| Moss | `#7A8471` | Confirmations, "ok" states |
| Ink | `#2B2521` | Primary text (never pure black) |

**Dark mode** (designed as its own experience, **not an inversion**):

| Name | Hex | Role |
|---|---|---|
| Deep night | `#1A1410` | Background (warm brown-black) |
| Muted terracotta | `#B86848` | Flow |
| Light lavender | `#9B8FBF` | Predictions |
| Ivory | `#EDE4D3` | Primary text (never pure white) |

**⚠️ Contrast verification.** `#C87456` on `#F4EDE2` likely **does not pass WCAG AA** for small text. A darker variant for text is needed (e.g. `#9B4E32`). Verify every combination with a tool like Stark before committing.

### 8.2 Calendar semantic encoding

| State | Representation |
|---|---|
| Flow logged | **Solid terracotta** circle |
| Light flow / spotting | **Terracotta outline** or faded circle |
| Next cycle prediction | **Lavender outline** circle (3–5 day range) |
| Day with notes/symptoms | Small **ochre dot** under the circle |
| Today | **Thin ring** around the circle (not fill) |

**Color-blind safety:** every state must be distinguishable without color (shape: filled/outline/dot). Never rely on color alone for critical information.

### 8.3 Typography

| Role | Font | Size |
|---|---|---|
| Display (day numbers, hero) | DM Serif Display | 32–48pt |
| Title (sections) | DM Serif Display | 22–26pt |
| Body | Inter Regular | 16pt (min) |
| Caption | Inter Regular | 13pt |

Line-height: 1.5 body, 1.2 display. Max 4 hierarchy levels. Fonts loaded via `google_fonts`.

The "Mētra" wordmark uses DM Serif Display with a distinctive graphic macron — **do not replace it with a Unicode glyph**, it is an identity element.

### 8.4 Iconography

- **Line icons, 1.5–2pt stroke, rounded terminations.**
- Never filled icons, never duotone, never emoji in the UI.
- Visual reference: 19th-century botanical book illustrations, stripped down.
- Recurring language elements: **moon phases, thin waves, open spirals, tiny stars**.
- Use sparingly.

### 8.5 Shapes and surfaces

- **Circles**, not squares, for cyclic elements (calendar days).
- Corner radius: 12–16pt for cards, 8pt for inputs.
- **No glassmorphism, no neumorphism, no aggressive gradients.**
- Subtle shadows, at most one perceivable elevation level.
- Paper grain texture (very low opacity) allowed as background, never as decoration.

---

## 9. Anti-patterns (explicitly reject)

These are not "avoid if possible" — they are **forbidden**. If you find one in existing code, remove it. If someone requests one, explain why we don't do it.

- ❌ Saccharine pastel pink, "Hey girl!" language
- ❌ Gamification: streaks, badges, levels, motivational progress bars
- ❌ Decorative emoji in the UI (this app is a place of intimacy, not a chat)
- ❌ "Your longest cycle!" or any editorial commentary on the user's data
- ❌ 3D Dribbble-style illustrations with cute characters
- ❌ Motivational notifications ("Keep it up!")
- ❌ Dark mode as a light-mode inversion (it must be designed)
- ❌ AI suggestions on note fields
- ❌ Community, sharing, social, comparison with other users
- ❌ Long onboarding forms — ask **only** for last period date + average length (default 28)
- ❌ Clinical language where unnecessary ("Day 14 of your rhythm", not "Day 14 of your cycle")

---

## 10. Accessibility (binding requirements)

WCAG 2.2 AA minimum, AAA where possible. A UI PR is rejected if:

- **Contrast**: normal text < 4.5:1, large text < 3:1, non-text UI elements < 3:1. Applies to light **and** dark.
- **Tap targets**: < 44×44pt (iOS) or < 48×48dp (Android). Includes calendar day circles — extended hit area if the visual circle is smaller.
- **Dynamic Type**: layout breaks at 200% scale. Test calendar and table (highest-risk spots).
- **Color-blind**: critical information communicated by color alone.
- **Screen reader**: interactive widgets without a meaningful `Semantics` label. Never "red circle" — always "Medium flow, April 15". Test with **TalkBack and VoiceOver** (the latter via TestFlight).
- **Reduce motion**: animations not respecting `MediaQuery.of(context).disableAnimations`. Provide a static fallback or a light cross-fade.
- **Visible focus**: on Bluetooth keyboard navigation, outline < 2pt or color-only.

**Inclusive language:**
- Feminine as semantic neutral (the primary audience is cis women).
- Avoid formulations that exclude trans / non-binary users.
- Zero references to motherhood as implicit goal. Zero "every woman knows that...". Zero "mother nature".
- Address the user as **"you"**, never as "women".

**Localization:**
- IT primary, EN secondary from day one.
- IT is on average 20–30% longer than EN: test layouts with real IT strings.
- All UI string literals in `.arb` files. Zero hardcoded strings in widgets.

---

## 11. Security and privacy (binding requirements)

1. **SQLCipher DB key**: generated randomly on first launch, saved **only** in `flutter_secure_storage` (iOS Keychain / Android Keystore). Never logged, never in SharedPreferences, never held in memory longer than necessary.
2. **Cloud backup passphrase**: chosen by the user, never saved. Derived to a key with **Argon2id** (parameters: memory 64MB, iterations 3, parallelism 4 — verify it is tolerable on low-end devices).
3. **Backup encryption**: **AES-256-GCM**. Random IV per backup. Nonce included in the blob.
4. **OAuth**: native provider flow. Never handle username/password directly. Tokens saved in secure storage, never in DB.
5. **No logging of sensitive data.** `print`/`debugPrint` of `DailyLog`, symptoms, or notes is a bug. Use a logging wrapper that redacts automatically in release builds.
6. **Cleartext CSV export**: OK — it is explicitly user-requested. But the UI must warn clearly before sharing.
7. **No third-party crash reporting.** If debugging is needed, local log clearable from Settings.

---

## 12. Dart/Flutter code conventions

**Style:**
- Formatter: `dart format` on everything. CI fails if unformatted.
- Linter: `flutter_lints` + custom rules in `analysis_options.yaml` (prefer_const, avoid_print, require_trailing_commas).
- **Strict null safety**. Never use `!` without a comment explaining why it is safe.

**Naming:**
- Classes `UpperCamelCase`, files `lower_snake_case.dart`.
- Riverpod providers: `Provider` suffix (`calendarStateProvider`, `dailyLogRepositoryProvider`).
- Use cases: `VerbNoun` (`SaveDailyLog`, `PredictNextCycle`).
- No cryptic acronyms. `CycleEntry`, not `CE`.

**State management:**
- Riverpod 2.x, **code generation with `riverpod_generator`** where it helps.
- `AsyncNotifier` for state with loading/error. Never `FutureProvider` for mutable state.
- Never `setState` in large widgets — isolate state in a Notifier.
- Drift streams → Riverpod: use `StreamProvider.autoDispose` with care for lifecycle.

**UI:**
- Stateless widgets when possible.
- Aggressive breakdown: a widget over 150 lines must be split.
- Never business logic in `build()`. Use a notifier.
- `const` constructors everywhere possible (the linter enforces it).

**Error handling:**
- Use `Result<T, E>` or `sealed class` for expected errors. `throw` only for programming errors.
- Never `catch(e) {}` without at least a local log.
- User-facing errors are in IT/EN, never raw stack traces.

---

## 13. Testing

**Mandatory:**
- Unit tests on every service in `data/services/` and `domain/use_cases/`. Minimum 80% coverage.
- Specific tests on `CyclePredictionService`: cases with 0, 1, 2, 3, 6, 10 cycles. Edge cases: very short/long cycles, missing cycles.
- Tests on `EncryptionService`: encrypt → decrypt round-trip, different IVs produce different output, wrong key fails gracefully.
- Widget tests on main screens (calendar, daily entry, stats).
- Integration test for the flow: log cycle → prediction updated → notification scheduled.

**E2E verification checklist** (before every release):
1. **Encrypted DB**: open DB file with SQLite browser without the key → fails.
2. **Prediction**: enter 3+ cycles → predicted date matches manual WMA.
3. **E2E encryption**: back up to Google Drive → download `.enc` → verify it is unreadable binary → restore on a second device → data is identical.
4. **Device calendar**: enable sync → "Cycle start" appears in the native calendar.
5. **CSV round-trip**: export → edit a field → import → DB updated correctly.
6. **Notification**: set "1 day before" → advance system date → notification received.
7. **Dynamic Type 200%**: no truncation or broken layout on calendar/table.
8. **TalkBack/VoiceOver**: logging flow completable without sight.

---

## 14. CI/CD

**GitHub Actions** (public repo → free macOS runner):
- `android.yml` workflow: lint + test + build APK on every push.
- `ios.yml` workflow: lint + test + build IPA + upload TestFlight on tag `v*`.
- `quality.yml` workflow: `dart format --set-exit-if-changed` + `flutter analyze` + coverage report.

**Versioning:** SemVer. `pubspec.yaml` is the source of truth. MVP = `0.1.0`, first public release = `1.0.0`.

**Privacy Policy:** published on GitHub Pages (`https://<user>.github.io/metra/privacy`). Link in Settings.

---

## 15. Reference roadmap (16 weeks)

Keep it in mind when planning work, but it is not rigid:

| Phase | Weeks | Output |
|---|---|---|
| 0 — Setup + DB | 1–2 | App boots, navigates, encrypted DB works |
| 1 — Data entry | 3–4 | Daily logging + basic calendar |
| 2 — Views + Stats | 5–6 | Timeline, Table, Statistics |
| 3 — Predictions + Notifications | 7 | WMA live, notifications scheduled |
| 4 — Settings + L10n | 8 | IT+EN, dark mode, toggles working |
| 5 — Export + Device calendar | 9–10 | CSV, device_calendar |
| 6 — Cloud sync | 11–14 | Google Drive + Dropbox + OneDrive |
| 7 — Polish + Release | 15–16 | Accessibility polished, onboarding, store submission |

---

## 16. Decisions already made (do not reopen without strong reason)

- iCloud is **deferred to v1.1** (requires native Swift Method Channel).
- **Automatic sync on app open** + always-available manual button. No background sync (unreliable on iOS).
- **Multi-device conflicts**: "latest backup wins", with user warning before overwrite.
- **Historical data entry**: included in the MVP, with a dedicated UI distinct from quick entry.
- **No local `.enc` export**. CSV is sufficient for offline data portability.
- **GPL-3.0 license** confirmed. License header in every source file.
- **Sharing with gynecologist**: post-MVP.

---

## 17. Operating instructions for Claude Code

When working on this project:

1. **Read first, write later.** Before touching a file, check related files (repository, DAO, provider). This project has strict layering — a change in `data/` can break `features/`.

2. **One feature at a time.** Don't mix setup, business logic, and UI in the same PR. Work in small vertical slices.

3. **Ask before inventing.** If a UX detail isn't specified in the design brief, **ask** — don't invent patterns. The design has a precise voice; getting it wrong is a regression, not an iteration.

4. **Show the diff, don't rewrite.** When modifying a file, use targeted `str_replace`. Don't regenerate the whole file if one function changes.

5. **Accessibility as a requirement, not a feature.** If you are creating an interactive widget and not thinking about `Semantics` and tap size, stop and rethink.

6. **Never introduce new dependencies without justification.** `pubspec.yaml` is already curated. If a new lib is needed, justify why it can't be done with existing ones.

7. **Tests alongside code.** A service without unit tests is not done. Complex widgets without widget tests are not done.

8. **Commit messages in English**, conventional format (`feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`). The project is open-source: the git log is public and part of the documentation.

9. **When in architectural doubt**, favor the choice that:
   - Keeps the domain pure (testable without Flutter).
   - Keeps the data layer swappable (we might replace Drift one day).
   - Reduces coupling between features.

10. **Sources of truth** (in order of precedence when they conflict):
    1. This `CLAUDE.md`
    2. `Design Brief — Métra.md`
    3. `Development Plan — Métra.md`
    4. The specific GitHub issue for the task in progress

---

## 18. Execution guidelines

These rules govern *how* Claude Code operates on this project. They complement §17 (project-specific operating instructions) and **override** the orchestration protocol where they conflict.

### 18.1 Multi-agent coordination

Use multiple specialized sub-agents for both planning and execution phases to ensure comprehensive analysis and high-quality output. Deploy sub-agents in parallel when possible to optimize workflow efficiency.

### 18.2 Requirements preservation

Before implementing any changes, modifications, or new features:

1. Thoroughly analyze existing application requirements and functionality.
2. Ensure all proposed changes maintain backward compatibility.
3. Verify that new implementations do not compromise or modify existing core functionality.
4. If conflicts arise between new requirements and existing functionality, **STOP** and request explicit guidance on how to proceed.

### 18.3 Implementation standards

When developing new features:

- Implement actual functionality, never create simulations or placeholder code.
- If a requested feature is implementable, build the complete working solution.
- If a requested feature is not implementable, clearly state "cannot be implemented" with specific technical reasons.
- Do not create mock implementations that simulate the requested behavior.

### 18.4 Testing approach

When conducting tests:

- Maintain complete objectivity in test execution and result reporting.
- Focus on accurately mapping what works and what does not work.
- Report actual test results, not idealized outcomes.
- Do not manipulate tests to achieve expected results.
- Document failures and issues honestly for subsequent debugging and resolution.
- The goal is comprehensive understanding of system behavior, not perfect initial results.

> _Always think **ultra hard** about the complete implications of any changes before proceeding with implementation._

### 18.5 Token economy

These rules **override** the orchestration protocol when there is tension.

**Prohibitions**

- **No restatement** of the request. Go straight to the output, don't open with "I understand you want…" or "So I'll…".
- **No meta commentary** on orchestration choices beyond the opening declaration line. Don't justify *why* an agent is a fit: let it work.
- **No final recap** of what each agent said. Closing synthesis contains only consolidated decisions, open points, next steps — not a recap.
- **No disclaimers or self-caveats** ("it's worth noting…", "keep in mind that…", "of course this depends on context…") unless they add substantive information.
- **No closing pleasantries** ("hope this helps", "let me know if…").
- **No superfluous code comments**: comment only non-obvious logic, never what restates the function name.

**Format**

- **Compact prose, not decorative bullet lists**: use bullets only for genuinely parallel information (≥3 comparable items). For explanations, analysis, decisions use prose.
- **Minimal markdown**: no H2/H3 headers for responses that fit in two paragraphs.

### 18.6 Interaction language

Interaction is **English-only**, in both directions. If the user accidentally writes in another language, still respond in English.

---

## 19. The soul check

Before opening a PR, look at the app on a device and ask yourself:

> _"Is this an app that a woman could open in a quiet moment, alone, in the evening — and feel at home?"_

If the answer is unsure, **it is not done**.
