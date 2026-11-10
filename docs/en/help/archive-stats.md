---
layout: help
title: Archive and Statistics
subtitle: The Timeline and Table views, plus the Statistics screen (cycle length, symptom frequency).
nav_title: Archive and Statistics
lang: en
lang_ref: help-archive-stats
permalink: /en/help/archive-stats/
help_order: 3
---

## Archive tab

The **Archive** tab (wave icon) holds the full record of your logged entries. You can view it in two ways, switchable with a segmented control at the top of the screen, and narrow the list down to the cycles that interest you with search and filters.

---

### Search and filters

Filters open from the funnel icon on the same line as the Timeline/Table switch, on the right. It starts closed and the list shows every cycle: tap it to reveal the search field and the chip row, tap it again to hide them and reset the filters.

Search and filters apply to the Timeline view only. The Table view always shows the full history and has neither search nor filters: switching to it clears any active filter.

The **Search in notes** field looks through the free notes you wrote when logging your days. It ignores capital letters and accents: *perche* also finds *perché*. The list updates about 300 milliseconds after the last letter, not on every character. The X on the right of the field clears the text you searched for.

Below the field is a row of chips, one for each symptom recorded in your cycles, including the custom labels you wrote yourself. The chips stay the same even while a filter is active. Tap a chip to select it, tap it again to remove it.

Search and filters combine: a cycle stays in the list only if it has all the symptoms you selected and, if you typed something into the search field, only if at least one of its notes contains the text you searched for. A cycle with the right symptoms but no matching note does not stay.

While a filter is active and at least one cycle matches, a row shows how many cycles match (3 cycles, for example) along with the **Clear filters** action, which resets the text and the chips together. When no cycle matches, the list is replaced by the message **No cycles match the filters**, with the same **Clear filters** action to start over.

When you leave the tab and come back, search and filters start from zero and the panel closes again.

---

### Timeline view

![Timeline view: the Timeline/Table switch with the funnel icon on its right, the search-in-notes field and the row of symptom chips open below it, then the vertical list of cycle cards, each showing start date, length, flow pill, and symptom chips.](/assets/archive-timeline-en.png)

The Timeline view groups your entries by **cycle**, one card per cycle, most recent at the top, earliest at the bottom. Each card shows:

- **Start date** and **cycle length** in days.
- A series of pastel-coloured labels summarising what was logged during that cycle:
	- terracotta with a droplet for **flow**, showing the intensity or spotting;
	- mauve with a lightning bolt for **pain**, showing the recorded intensity;
	- ochre with a star for **symptoms**, covering all symptoms logged during that cycle;
	- grey with a pen icon, indicating **notes**.

Scroll up to go further back. Tap a card to open the Calendar, focused on the month that cycle started in.

---

### Table view

![Table view: the Timeline/Table switch with no funnel, since the Table view does not filter, then the cycle rows with the columns Month, Cycle, Dur., and Flow.](/assets/archive-table-en.png)

The Table view shows one row per logged month, useful when you want to compare several months at a glance. Columns:

| Column | Content                                      |
| ------ | -------------------------------------------- |
| Month  | Month and year.                              |
| Cycle  | Number of days in the cycle.                 |
| Dur.   | Number of menstrual flow days.               |
| Flow   | Average menstrual flow intensity.            |

---

## Statistics tab

![Statistics screen: four summary cards at top, then bar charts.](/assets/stats-overview-en.png)

The **Statistics** tab is the numerical side of the same archive: where the Timeline and Table show individual days, here Mētra calculates averages and distributions across the full set of parameters logged during your cycles. All calculations run locally on your device — no external service ever sees these numbers.

---

### Summary cards

Four headline figures at the top of the screen:

| Card                          | Meaning                                                               |
| ----------------------------- | --------------------------------------------------------------------- |
| **Average cycle length**      | Mean number of days across all complete logged cycles.                |
| **Average period length**     | Mean number of consecutive menstruation days per cycle.               |
| **Average pain**              | Mean pain level recorded across all cycles, on a 0–3 scale.          |
| **Tracked cycles**            | Total number of complete cycles in your history.                      |

These cards update every time you save a new entry.

---

### Cycle length chart

<!-- SCREENSHOT PLACEHOLDER: stats-cycle-chart.png -->
<!-- Bar chart: one bar per cycle, height = length in days, terracotta colour. -->

A bar chart showing the length of each cycle in chronological order. If your rhythm has shifted over recent months, this is where it shows.

---

### Pain intensity chart

<!-- SCREENSHOT PLACEHOLDER: stats-pain-chart.png -->
<!-- Bar chart: one bar per cycle, height = average pain intensity for that cycle, 0–3 scale. -->

A bar chart showing the average pain intensity for each cycle in chronological order, on the same 0–3 scale used when logging. Mētra calculates this locally, nothing transmitted. An outlier cycle stands out immediately.

---

### Symptom frequency chart

![Horizontal bar chart: one bar per symptom type, length = percentage of cycles in which it appeared.](/assets/stats-symptoms-chart-en.png)

A horizontal bar chart showing how often each symptom has appeared across your recorded cycles. The most frequent symptoms appear at the top. Over time, a pattern you had not noticed can become clear.

> **No data?** Statistics require at least one complete cycle to be logged. A cycle is considered complete once the start of the next cycle is recorded.
