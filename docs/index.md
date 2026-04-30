<div align="center">

# Mētra

*An app for listening to your own rhythm.*

[![License: GPL-3.0](https://img.shields.io/badge/License-GPL--3.0-2B2521?style=flat-square)](https://www.gnu.org/licenses/gpl-3.0)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-2B2521?style=flat-square&logo=flutter&logoColor=C87456)](https://flutter.dev)
[![Status](https://img.shields.io/badge/Status-In%20development-C87456?style=flat-square)]()
[![Privacy](https://img.shields.io/badge/Data-Local--first-7A8471?style=flat-square)]()

</div>

-----

Métra is a free, open-source mobile app for menstrual cycle tracking.  
No proprietary servers. No ads. No data handed to third parties.  
Just a quiet tool that lives on your device.

The name comes from Ancient Greek *μήτρα* — womb, measure, origin. The same root as *mother* and *matrix*. An app that goes back to the beginning.

-----

## What it does

- **Daily log** — flow, symptoms, free-text notes. Done in three taps.
- **Monthly calendar** — circle-based view with semantic color coding for flow, predictions, and recorded symptoms.
- **Timeline and Table** — two views of the same history, toggled in a single gesture.
- **Statistics** — average cycle length, period duration, symptom frequency. Data as data, no editorial commentary from the app.
- **Prediction** — weighted moving average over 6 cycles. No magic, just transparent math.
- **Optional cloud backup** — Google Drive, Dropbox, OneDrive. End-to-end encrypted on the device *before* it leaves. The provider sees only an unreadable blob.
- **Export / Import CSV** — your data is yours, exportable at any time.

## What it doesn’t do

Métra is not a fertility tracker. It has no community, no gamification, no streaks, no badges, no algorithmic suggestions. It doesn’t ask you to create an account. It knows nothing about you beyond what you choose to record.

It is an intimate digital notebook — closer to a Moleskine than a fitness app.

-----

## Privacy by architecture

> *“Your data is encrypted on your phone before it ever leaves. The cloud provider sees only an unreadable file.”*

- **Local-first**: all data lives in a local, AES-256 encrypted database on the device (SQLCipher).
- **Zero-knowledge backup**: the encryption key never leaves the device. The cloud backup is an opaque blob.
- **No proprietary server**: Métra has no backend, no analytics, no telemetry of any kind.
- **Open-source**: the code is right here. Every privacy claim can be verified by reading the source.

-----

## Tech stack

| Component        | Choice                            |
| ---------------- | --------------------------------- |
| Framework        | Flutter 3.x                       |
| Database         | Drift ORM + SQLCipher             |
| State management | Riverpod 2.x                      |
| Cryptography     | AES-256-GCM + Argon2id            |
| Cycle prediction | Weighted Moving Average (N=6)     |
| Cloud backup     | Google Drive · Dropbox · OneDrive |

-----

## Platforms

| Platform | Status         |
| -------- | -------------- |
| Android  | In development |
| iOS      | In development |


-----

## Roadmap

```
Phase 0  [weeks 1–2]    Setup + encrypted database
Phase 1  [weeks 3–4]    Daily log + base calendar
Phase 2  [weeks 5–6]    Timeline, Table, Statistics
Phase 3  [week 7]       WMA prediction + notifications
Phase 4  [week 8]       Settings, IT/EN localization, dark mode
Phase 5  [weeks 9–10]   CSV export/import
Phase 6  [weeks 11–14]  E2E cloud sync
Phase 7  [weeks 15–16]  Accessibility, onboarding, store submission
```

The repository is in its early stages. Code will be added as development progresses.

-----


-----

## Contributing

The project is in its early stages. Contribution guidelines will be added once the codebase is stable.

In the meantime, if you want to follow development or suggest an idea, open an [Issue](../../issues).

-----

## License

Métra is distributed under the **GPL-3.0** license.  
Forks must keep the code open under the same license.

The privacy policy is published on [GitHub Pages](../../).

-----

<div align="center">

*From Ancient Greek μήτρα — womb, measure, origin.*  
*The same root as mother. The same root as matrix.*

</div>
