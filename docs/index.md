---
layout: page
title: Mētra
subtitle: An app for listening to your own rhythm.
---
![Métra Logo](/assets/icon-light.svg)
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

## Platforms

| Platform | Status         |
| -------- | -------------- |
| Android  | In development |
| iOS      | In development |


-----

## Contributing

The project is in its early stages. You can find it on [GitHub](https://github.com/paolo-santucci/metra/).

-----

## License

Métra is distributed under the **GPL-3.0** license.  
Forks must keep the code open under the same license.

The privacy policy is published on [GitHub Pages](./privacy).

-----

<div markdown="1" align="center">

*From Ancient Greek μήτρα — womb, measure, origin.*  
*The same root as mother. The same root as matrix.*

</div>
