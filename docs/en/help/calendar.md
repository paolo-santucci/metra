---
layout: help
title: Calendar and visual language
subtitle: How to read the monthly grid, what each colour and icon means, and how predictions work.
nav_title: Calendar
lang: en
lang_ref: help-calendar
permalink: /en/help/calendar/
help_order: 1
---

The **Calendar** tab is the main screen of Métra. It shows a monthly grid where every day carries visual information about what you logged — or what the app predicts.

---

## The monthly grid

<!-- SCREENSHOT PLACEHOLDER: calendar-overview.png -->
<!-- Full calendar screen showing a typical month with flow days, a predicted window, and symptom dots. -->

Each day is a small cell. Days in the past may carry coloured cells and icons under the date number; days in the future may carry prediction markers.

Tap any day to open its **day detail card**, which shows the full entry for that date.

Use the **← →** arrows in the header to move between months.

---

## Visual language — colours

Métra uses a fixed colour vocabulary. Once you learn it you can read an entire month at a glance.

| Colour | Name | Meaning |
|---|---|---|
| **Terracotta** (warm red-orange) | Flow | A day logged as menstruation (full or spotting). |
| **Lavender** (muted purple) | Prediction | A day the app predicts will fall inside your next period window. |
| **Ochre** (warm gold) | Symptom | The day has at least one symptom logged (e.g. headache, bloating). |
| **Mauve** (dusty rose) | Pain | The day has a pain intensity recorded. |

---

## Visual language — icons

Small icons appear **under the day number** in the grid and inside the day detail card.

| Icon | Meaning |
|---|---|
| Filled drop | Menstruation logged for this day. |
| Outline drop | Predicted menstruation (no entry yet). |
| Four-point star | At least one symptom recorded. |
| Lightning bolt | Pain intensity recorded. |
| Crescent moon | Current cycle day indicator in the calendar header. |

---

## The legend strip

<!-- SCREENSHOT PLACEHOLDER: calendar-legend.png -->
<!-- The thin legend bar beneath the day-of-week header showing all four icons with their labels. -->

A legend strip sits just below the day-of-week header (L M M G V S D / M T W T F S S). It shows all four icons with their labels so you never need to memorise them.

---

## Predictions

Métra calculates a predicted start date for your next period using a **weighted moving average** of your last six logged cycles. More recent cycles carry more weight.

- The prediction window appears as **lavender outline cells** in the calendar.
- A **"Giorno N" / "Day N"** label in the calendar header shows where you are in your current cycle.
- The prediction updates automatically every time you save a daily entry that starts a new cycle.

The app uses transparent mathematics — no black-box algorithm, no "AI" claims. The formula is documented in the source code.

> **No logged cycles yet?** The prediction is based on the baseline you set during onboarding. It becomes more accurate after two or three cycles.

---

## The day detail card

<!-- SCREENSHOT PLACEHOLDER: calendar-day-detail.png -->
<!-- Day detail card showing flow pill, pain pill, symptom chips, and notes. -->

Tapping a day slides up a card with:

- **Flow pill** — the logged flow type and intensity, or the predicted status.
- **Pain pill** — pain level (Lieve / Moderata / Intensa), if recorded.
- **Symptom chips** — one chip per symptom recorded that day.
- **Notes** — free-text note, if any.
- **Edit button** — opens the [daily entry screen](daily-entry) for that day.
