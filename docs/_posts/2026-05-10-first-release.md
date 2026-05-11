---
layout: page
title: "Mētra 1.0 — First Stable Release"
date: 2026-05-10
tags: [release, updates]
author: Paolo Santucci
excerpt: "The first stable version of Mētra is available for Android. A digital notebook for menstrual cycle tracking — private, encrypted, open source."
lang: en
---

Today we are releasing Mētra 1.0.

That is not a sentence we write lightly. A stable release is a commitment: that the software works, that it does not break your data, that you can trust it with something personal. We built this version with that responsibility in mind.

---

## Why another cycle tracker

The short answer: because the existing ones are built around a transaction we refuse.

Your data — intimate, physiological, deeply personal — in exchange for a prediction. The app learns your body. The company learns your body. Advertisers, insurers, data brokers: they learn too, eventually, because that is how the economics of those products work.

Mētra refuses the transaction.

Every log entry you make stays on your phone, encrypted. If you choose to back up to the cloud, your data is locked inside a key you choose before it leaves the device — the provider sees a file it cannot read. There is no Mētra server. There is no Mētra account. There is no Mētra team watching your cycle to improve a model that benefits someone else.

What you record belongs to you. What you learn belongs to you.

---

## What's in 1.0

Mētra 1.0 is a complete menstrual cycle tracker. Local. Encrypted. No account required.

**Daily log.** Flow, intensity, customisable symptoms, free-text notes. Three taps. No more.

**Monthly calendar.** A grid of circles showing recorded flow, prediction, and symptoms. Every colour has a precise meaning — none is decorative. Navigating between months never loses the day you were looking at.

**Timeline and table.** Two views of the same historical archive. You can read past cycles as a narrative sequence or as a data table, depending on how you prefer to think about your history.

**Statistics.** Average cycle length, period duration, symptom frequency by category. Numbers, not interpretations. The app has no opinions about your body.

**Prediction.** A window of 3–5 days — not a precise date. Calculated with an exponential weighted moving average over the last six cycles, running entirely on your device, without any remote model. The body is not a machine; an honest prediction acknowledges that, and returns a range instead of a false certainty.

**Encrypted backup.** Google Drive, Dropbox, OneDrive. Your data is encrypted on the device — with a passphrase you choose — before it leaves. The cloud provider sees a file it cannot read. The key never leaves your phone. There is no server-side password reset, because there is no server.

**Export and import CSV.** Your data remains yours, in an open format readable by any spreadsheet. You can leave Mētra at any time and take everything with you.

**Full Italian and English localisation.** The app is completely translated into both languages, including all interface text, notifications, and error messages.

---

## What you won't find, and why

You won't find gamification. You won't find streaks. You won't find motivational notifications. You won't find advice on how to optimise your cycle.

You won't find an account to create, because Mētra has no server to send your data to.

You won't find analytics, because we are not interested in knowing how you use the app.

You won't find a fertility tracker. Mētra does not assume you are trying to conceive, or that you have a 28-day cycle, or any other assumption about your relationship with your body.

We built a tool. The judgment of how to use it is yours.

---

## Privacy by architecture

Mētra's privacy is not a statement of intent. It is an architectural choice.

All data lives in a local database encrypted with AES-256 via SQLCipher. The encryption key never leaves the device. Cloud backup is end-to-end encrypted — we do not know what is inside it, because we cannot know.

No analytics. No telemetry. No remote logs.

The code is open source under the GPL-3.0 license. Every claim in this post can be verified by reading the source. We are not asking for blind trust: we are offering verifiable transparency.

[Read the source on GitHub →](https://github.com/paolo-santucci/metra/)  
[Read the privacy policy →]({{ site.baseurl }}/privacy)

---

## How to download it

Mētra 1.0 is available now for Android.  
The APK can be downloaded directly from GitHub Releases — no app store required.

iOS is available on TestFlight and will be distributed on the App Store in the coming weeks. If you want to participate in the iOS beta, find the instructions in the [TestFlight documentation]({{ site.baseurl }}/release/testflight-setup).

[Download Mētra for Android →](https://github.com/paolo-santucci/metra/releases)

---

## What comes next

1.0 is a starting point.

The backlog is long and includes: support for atypical cycles, additional themes, further statistical views, configurable notifications, and accessibility improvements. None of this will be built to increase engagement. It will be built if it answers one question: *does this make the tool more honest, more useful, more trustworthy?*

If you find a bug, [open an issue on GitHub](https://github.com/paolo-santucci/metra/issues). If you want to contribute code, the repository is open. If you want to support the project financially, there is a [Ko-fi link](https://ko-fi.com/D1D31YPYRX).

Thank you for choosing a tool that does not use you in return.
