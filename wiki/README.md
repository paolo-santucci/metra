# Mētra — Developer Wiki

Mētra (μήτρα) is a privacy-first, local-first, open-source menstrual cycle tracker for Android and iOS. This wiki is the entry point for contributors.

## Table of contents

- [What Mētra is — and is not](#what-mētra-is--and-is-not)
- [Five core principles](#five-core-principles)
- [Tech stack](#tech-stack)
- [Platform targets](#platform-targets)
- [Quick start](#quick-start)
- [Key repo files](#key-repo-files)
- [Design files](#design-files)
- [Wiki pages](#wiki-pages)
- [Current version](#current-version)

---

## What Mētra is — and is not

**Mētra** (wordmark: macron-ē, U+0113) is an intimate digital notebook for tracking menstrual cycles. Think Moleskine, not fitness app. License: GPL-3.0. Free.

| It is | It is not |
|---|---|
| A private, local diary of your rhythm | A fertility tracker |
| An open-source mobile app | A SaaS or cloud product |
| Privacy-first by architecture | An analytics platform |

**Etymology.** From Ancient Greek _mētra_ (μήτρα) = womb, matrix, measure. Same Indo-European root as _mother_. The etymological sense is useful for class naming and documentation.

**Target user.** An adult person who wants to know her own rhythm without handing data to third parties. She is not looking for gamification, medical advice, or social comparison.

---

## Five core principles

These are architectural constraints, not preferences. A contribution that violates one must be redesigned.

1. **Local-first.** Data lives on the user's device. No proprietary server. Cloud is optional and used only for encrypted backup — never as source of truth.
2. **Zero-knowledge cloud.** The cloud provider (Google Drive, Dropbox, OneDrive) sees only encrypted blobs. The encryption key never leaves the device. There is no server-side password reset because there is no server.
3. **No telemetry.** Zero analytics, zero third-party crash reporting, zero tracking. Diagnostic logs are local only and user-clearable.
4. **Accessibility built-in.** WCAG 2.2 AA minimum, AAA where possible. An inaccessible screen is an incomplete screen, not a backlog item.
5. **Respect the user.** No dark patterns, no gamification, no motivational notifications, no endless onboarding. The user knows what she is doing.

---

## Tech stack

| Layer | Technology | Version |
|---|---|---|
| Framework | Flutter | 3.x |
| Language | Dart | latest stable |
| State management | Riverpod (with code generation) | ^2.5.1 |
| Local DB | Drift ORM | ^2.18.0 |
| DB encryption | SQLCipher via `sqlcipher_flutter_libs` | ^0.5.4 |
| Cryptography | `cryptography` (AES-256-GCM + Argon2id) | ^2.7.0 |
| Keychain | `flutter_secure_storage` | ^9.2.2 |
| Routing | `go_router` | ^14.2.7 |
| Charts | `fl_chart` | ^0.68.0 |
| Fonts | Google Fonts (Inter + DM Serif Display) | ^6.2.1 |
| Notifications | `flutter_local_notifications` | ^17.2.2 |
| Export / Share | `file_picker`, `share_plus`, `csv` | ^8.1.2 / ^10.0.2 / ^6.0.0 |
| Cloud backup | Dropbox via `http` | ^1.2.2 |
| i18n | `intl` + Flutter gen_l10n | ^0.19.0 |

Italian is the primary locale. English is the mirror.

---

## Platform targets

| Platform | Status |
|---|---|
| Android | Primary development target; emulator and physical device available locally |
| iOS | Built via GitHub Actions macOS runner; distributed through TestFlight |

Development happens on Fedora Linux. There is no Mac locally and no iOS simulator. Do not write code that requires an iOS simulator to be verified.

---

## Quick start

```bash
# 1. Clone
git clone https://github.com/paolosantucci/metra.git
cd metra

# 2. Get dependencies
flutter pub get

# 3. Run code generation (Drift + Riverpod)
dart run build_runner build --delete-conflicting-outputs

# 4. Run tests
flutter test

# 5. Run on Android emulator or device
flutter run
```

**Before writing any UI:** read `design/DESIGN-BIBLE.md`. All UI changes must conform to it. If something is missing from the bible, update `wiki/design/Métra Screens Light.html` first, then the bible, then Flutter — never the reverse.

---

## Key repo files

| File | Role |
|---|---|
| `CLAUDE.md` | AI assistant instructions and project conventions |
| `STATUS.md` | Current phase, completed work, known issues |
| `design/DESIGN-BIBLE.md` | Canonical UI specification derived from the HTML mockup |
| `lib/core/theme/metra_colors.dart` | Color tokens |
| `lib/core/theme/metra_typography.dart` | Typography tokens |
| `lib/core/theme/metra_spacing.dart` | Spacing and radius tokens |
| `lib/core/widgets/metra_icon.dart` | MetraIcon widget + SVG constants |
| `lib/l10n/app_it.arb` | Italian copy (source of truth) |

---

## Design files

The `wiki/design/` directory contains the interactive HTML mockups that serve as the authoritative visual specification:

| File | Role |
|---|---|
| `wiki/design/Métra Screens Light.html` | **Canonical source of UI truth** (light theme) |
| `wiki/design/Métra Design System.html` | Design system catalog (the DESIGN-BIBLE takes precedence on any conflict) |
| `wiki/design/Métra App Icon.html` | App icon variants (light + dark, iOS + Android) |

The HTML mockups are not static images — open them in a browser to interact with the screens.

---

## Wiki pages

| Page | Contents |
|---|---|
| [`architecture.md`](architecture.md) | System architecture, Mermaid class diagram, layer rules, navigation |
| [`domain-model.md`](domain-model.md) | Domain entities, use cases, domain services |
| [`data-layer.md`](data-layer.md) | Database schema, repositories, encryption, backup |
| [`visual-identity.md`](visual-identity.md) | Design system, color tokens, typography, iconography, component catalog |
| [`contributing.md`](contributing.md) | How to contribute, code conventions, testing, CI/CD |

---

## Current version

`0.1.0` (MVP). The project follows SemVer; `pubspec.yaml` is the source of truth. The first public release will be `1.0.0`.
