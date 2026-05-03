---
layout: page
title: Import and Export (CSV)
---

[← Back to Help](/metra/help/) &nbsp;·&nbsp; [🇮🇹 Italiano](/metra/help/it/import-export)

Métra can export all your daily logs to a plain CSV file, and import them back. This is useful for:

- Keeping a local backup you can open in any spreadsheet app.
- Migrating data from another app (if you can produce the right format).
- Bulk-editing past entries outside the app.
- Long-term archiving in an open, non-proprietary format.

---

## Exporting your data

<!-- SCREENSHOT PLACEHOLDER: settings-export.png -->
<!-- Settings screen with the "Export CSV" row highlighted. -->

1. Go to **Settings** (gear icon).
2. Tap **Esporta CSV** (Export CSV).
3. Your device's standard share sheet opens. You can save the file locally, send it to a computer, or open it in a spreadsheet app directly.

The export includes every day you have ever logged, in reverse chronological order (most recent first). Days you have never opened the app for are not included.

---

## Importing data

<!-- SCREENSHOT PLACEHOLDER: settings-import.png -->
<!-- Settings screen with the "Import CSV" row highlighted. The import confirmation dialog. -->

1. Go to **Settings**.
2. Tap **Importa CSV** (Import CSV).
3. Pick the `.csv` file from your device storage.
4. Métra parses the file. If any rows contain errors, a summary is shown before committing — you can cancel at this point.
5. Confirm to apply. Imported rows overwrite any existing entry for the same date.

> **Import is additive and date-keyed.** If you import a file that contains a row for 2025-03-15 and a row for that date already exists, the imported row replaces it. Dates not present in the file are left untouched.

---

## CSV format reference

The file uses **UTF-8 encoding**, **comma delimiters**, and **`\n` line endings**. The first row is always the header. Values that contain commas or double-quotes are enclosed in double-quotes following standard RFC 4180.

### Column reference

| Column | Type | Required | Description |
|---|---|---|---|
| `date` | String | **Yes** | Date in `YYYY-MM-DD` format (e.g. `2025-04-15`). Must be a valid calendar date. |
| `flow_type` | Integer | **Yes** | Categorical flow type. See [Flow type values](#flow-type-values). |
| `flow` | Integer | No | Menstrual flow intensity. See [Flow intensity values](#flow-intensity-values). Only meaningful when `flow_type` is `1`. If `flow_type` is `1` and this column is empty, the intensity defaults to `1` (Moderate). |
| `pain_intensity` | Integer | No | Pain level: `1` = Mild, `2` = Moderate, `3` = Severe. Empty = no pain recorded. |
| `symptoms` | String | No | Semicolon-separated list of symptom tokens. Empty or omitted if none. See [Symptom tokens](#symptom-tokens). |
| `notes` | String | No | Free-text note. Empty or omitted if none. Double-quoted if it contains commas or newlines. |
| `cycle_start` | Integer | No | `1` if this day is the start of a new cycle, `0` otherwise. **Export-only** — this column is ignored on import. Métra recomputes cycle boundaries automatically. |

---

### Flow type values

The `flow_type` column encodes one of three mutually exclusive states:

| Value | Meaning |
|---|---|
| `0` | **Assente** — the user explicitly confirmed no bleeding. |
| `1` | **Mestruazioni** — active menstrual flow. `flow` intensity is meaningful. |
| `2` | **Spotting** — light, irregular spotting. `flow` intensity is ignored. |

`flow_type` is required on every row. Use `0` (Assente) to explicitly record a day with no bleeding.

---

### Flow intensity values

The `flow` column is only meaningful when `flow_type` is `1` (Mestruazioni). If it is omitted or left empty while `flow_type` is `1`, the intensity is recorded as **Moderate** (`1`).

| Value | Meaning |
|---|---|
| `0` | Light (Leggero) |
| `1` | Moderate (Moderato) — default when `flow_type=1` and `flow` is empty |
| `2` | Heavy (Abbondante) |

> **Legacy note:** older exports may contain a `spotting` column (0/1) instead of `flow_type`, and `flow` values `0–4` where `0` means no flow. Métra imports both formats automatically — you do not need to convert old files.

---

### Symptom tokens

The `symptoms` column is a semicolon-separated list of tokens. Tokens are case-sensitive.

**Built-in tokens:**

| Token | Meaning |
|---|---|
| `cramps` | Crampi (Cramps) |
| `backPain` | Mal di schiena (Back pain) |
| `headache` | Mal di testa (Headache) |
| `migraine` | Emicrania (Migraine) |
| `bloating` | Gonfiore (Bloating) |
| `fatigue` | Stanchezza (Fatigue) |
| `nausea` | Nausea |
| `breastTenderness` | Tensione al seno (Breast tenderness) |

**Custom symptoms** use the prefix `custom:` followed by the label text, e.g. `custom:Dolore pelvico`. The label is reproduced exactly as typed.

**Example** — a row with two symptoms, one built-in and one custom:

```
symptoms
cramps;custom:Dolore alla schiena
```

Multiple symptoms in one cell:

```
cramps;headache;bloating
```

---

### Example file

```csv
date,flow_type,flow,pain_intensity,symptoms,notes,cycle_start
2025-05-01,1,0,2,cramps;bloating,First day,1
2025-05-02,1,1,1,cramps,,0
2025-05-03,1,1,,,, 0
2025-05-04,1,0,,,Feeling better,0
2025-05-05,0,,,,, 0
2025-05-06,0,,,,,0
```

---

## Troubleshooting import errors

If Métra rejects some rows, a list of errors is shown before you confirm the import. Each error specifies:

- **Row number** in the file (header is row 1, so data starts at row 2).
- **Column** where the problem was found.
- **Raw value** that was rejected.
- **Reason** — a plain-English explanation.

Common causes:

| Problem | Fix |
|---|---|
| `date` not in `YYYY-MM-DD` format | Change `15/04/2025` → `2025-04-15`. |
| `date` missing | Every row must have a date. Rows without one are skipped. |
| `flow_type` missing or out of range | `flow_type` is required. Use `0`, `1`, or `2`. |
| `flow` out of range | Use `0`, `1`, `2`, or leave empty (defaults to `1` when `flow_type=1`). |
| `pain_intensity` out of range | Use `1`, `2`, `3`, or leave empty. |

Rows with errors are skipped; valid rows are still imported.

---

[← Back to Help](/metra/help/)
