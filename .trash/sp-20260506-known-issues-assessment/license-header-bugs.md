# License Header Tool Bugs — Assessment Report

**Date:** 2026-05-06
**Scope:** `tools/add_license_header.sh`, `tools/check_license_headers.sh`
**Status of codebase:** No hand-written `.dart` file currently has an outdated header. All
generated-file bugs are latent — they will fire if `add_license_header.sh` is re-run.

---

## Findings

---

[MEDIUM] BUG-LH-001: `add_license_header.sh` skips files with outdated copyright lines
File: `tools/add_license_header.sh`:22
Category: logic-error
CWE: N/A (tooling correctness)
Evidence:
```bash
if ! head -1 "$file" | grep -q "Copyright"; then
```
Analysis:
The stamper's detection predicate is `head -1 | grep -q "Copyright"` — a broad substring
match on line 1 only. The checker's predicate is
`head -n 20 | grep -qF -- "// Copyright (C) 2026  Paolo Santucci"` — an exact fixed-string
match on the first 20 lines.

Any file whose first line contains the word "Copyright" but does not contain the exact
REQUIRED_LINE (e.g. wrong year, single space between year and name, different author name,
or copyright text on line 2+) will be:
- **Silently skipped** by `add_license_header.sh` (head -1 matches "Copyright")
- **Flagged as missing** by `check_license_headers.sh` (exact match fails)

This creates an irreconcilable state where the check fails but the fix tool does nothing,
forcing a manual `sed` workaround — which is the symptom reported.

Trigger: A contributor's file has `// Copyright (C) 2025 Paolo Santucci` (wrong year,
single space) on line 1. Running `check_license_headers.sh` prints `MISSING LICENSE HEADER`
for that file. Running `add_license_header.sh` exits without touching it. The CI check
continues to fail.

Impact: Incorrect license-check failures in CI that cannot be auto-remediated by the
provided fix tool. Maintainer must fix manually.

---

[HIGH] BUG-LH-002: `add_license_header.sh` stamps generated `.g.dart` and `app_localizations*.dart` files
File: `tools/add_license_header.sh`:21
Category: missing-validation / logic-error
Evidence:
```bash
find lib test -name "*.dart" 2>/dev/null | while read -r file; do
  if ! head -1 "$file" | grep -q "Copyright"; then
    echo "Stamping $file"
    printf '%s\n' "$HEADER" | cat - "$file" > /tmp/metra_hdr && mv /tmp/metra_hdr "$file"
  fi
done
```
Analysis:
`check_license_headers.sh` excludes three categories of generated files via a `case`
statement:
- `*.g.dart` (Drift/Riverpod code-gen)
- `*.freezed.dart`
- `lib/l10n/app_localizations*.dart`

`add_license_header.sh` has **no exclusion logic whatsoever**. The `find lib test -name
"*.dart"` command returns all `.dart` files including all three excluded categories.

The `.g.dart` files (5 files: `app_database.g.dart`, 4 DAO `.g.dart` files) start with
`// GENERATED CODE - DO NOT MODIFY BY HAND` — no "Copyright" on line 1. The stamper's
condition is satisfied and it would prepend the GPL-3.0 header.

The `app_localizations*.dart` files (3 files) start with `// ignore: unused_import` or
`import 'dart:async';` — also no "Copyright" on line 1. Same result.

Confirmed latent: the `.g.dart` files were added to the repo (2026-04-28) after the stamp
script was introduced (2026-04-27) and `add_license_header.sh` was never re-run after that
date. The generated files currently have no GPL header. If the script is run again (e.g.
after a contributor adds new files), it will corrupt all 8 generated files by prepending a
GPL comment block that `build_runner` / `flutter gen-l10n` will then overwrite on the next
code-gen run — but until that re-gen, the files carry a confusing and incorrect GPL header,
and diff noise will appear in every `git status`.

Trigger: Developer adds one new hand-written Dart file, runs `add_license_header.sh` to
stamp it, and the tool also stamps all `.g.dart` and `app_localizations` files in the same
pass.

Impact: Generated files corrupted with GPL headers. `git status` shows spurious diffs.
Until `build_runner` re-generates, the files falsely appear as GPL-licensed. If
`build_runner` is not immediately run, the corruption persists and may be committed.

---

[MEDIUM] BUG-LH-003: Silent data loss on write failure — no `set -euo pipefail`
File: `tools/add_license_header.sh`:1
Category: error-swallow / resource-leak
Evidence:
```bash
printf '%s\n' "$HEADER" | cat - "$file" > /tmp/metra_hdr && mv /tmp/metra_hdr "$file"
```
Analysis:
`add_license_header.sh` has no `set -euo pipefail`. The stamper writes to a fixed temp path
`/tmp/metra_hdr` and then replaces the source file with `mv`. If the `printf | cat >
/tmp/metra_hdr` step fails mid-write (disk full, write error), `> /tmp/metra_hdr` will have
truncated the temp file. The `&&` guard prevents `mv` from running in that case — correct —
but without `set -e`, the loop continues and the next iteration will:
1. Overwrite `/tmp/metra_hdr` with a fresh file, masking the error.
2. The failed file retains its original content (since `mv` did not run) — the data is safe.

The deeper risk: if `mv` itself fails (e.g., cross-device move — though `/tmp` and the
working directory are typically the same filesystem), without `set -e` the failure is
invisible and `$file` is left in its pre-truncation state or partially replaced.

Additionally, the hardcoded `/tmp/metra_hdr` path is a single-instance temp file with no
`mktemp`. Two concurrent invocations of the script would interleave writes to the same
path, producing file corruption. In practice the script is single-threaded (sequential
`while read` loop), but CI tooling could run it in parallel.

Trigger: Disk-full condition during a stamp pass; or two CI jobs running the script
concurrently against the same working tree.

Impact: Silent failure; corrupted or zero-byte source file if `mv` runs on a partial write.

---

[LOW] BUG-LH-004: `check_license_headers.sh` `case` exclusion pattern tested against full
path but documented as simple extensions
File: `tools/check_license_headers.sh`:14-16
Category: logic-error (minor)
Evidence:
```bash
case "$file" in
  *.g.dart|*.freezed.dart) continue ;;
  lib/l10n/app_localizations*.dart) continue ;;
esac
```
Analysis:
`find lib test ... -print0` outputs paths relative to the script's CWD (e.g.,
`lib/data/database/app_database.g.dart`). The `case` glob `*.g.dart` correctly matches
because bash `case` uses `fnmatch` where `*` matches `/`. The exclusions work correctly
today. The defect is that the `lib/l10n/app_localizations*.dart` pattern is hardcoded as a
relative path from the project root. If the script is ever invoked from a subdirectory, the
`find` output changes prefix and the exclusion silently stops matching, causing false
failures for l10n files. `add_license_header.sh` has no such issue only because it has no
exclusions at all.

Trigger: `cd tools && bash check_license_headers.sh` — find output is `../lib/l10n/...`,
the literal `lib/l10n/...` pattern no longer matches, l10n files are checked and fail.

Impact: False CI failure on l10n files if the working directory is changed.

---

## Summary

4 findings: 0 critical, 1 high, 2 medium, 1 low

Highest-risk area: `tools/add_license_header.sh`

Current state: All bugs are latent. No source file currently has a corrupted or outdated
header. The bugs will trigger the next time `add_license_header.sh` is run on a repository
that contains `.g.dart` or `app_localizations*.dart` files (which it does, as of 2026-04-28).

---

## Spec Inputs

### Root Cause Analysis

The two scripts were written independently and their detection predicates diverged:

| Script | Detection predicate | Excludes generated files |
|---|---|---|
| `add_license_header.sh` | `head -1 \| grep -q "Copyright"` (substring, line 1 only) | No |
| `check_license_headers.sh` | `head -n 20 \| grep -qF -- "$REQUIRED_LINE"` (exact match, 20 lines) | Yes |

The root cause of BUG-LH-001 is that the stamper uses a weaker detection predicate than the
checker. Any file that satisfies the stamper's "already has a header" check but fails the
checker's exact-match test falls into an unrecoverable state for automated tooling.

The root cause of BUG-LH-002 is that the stamper's exclusion logic was never written. The
checker was introduced on 2026-04-28 (after the stamper on 2026-04-27) and added exclusions
for generated files; those exclusions were never backported to the stamper.

### Affected Components and Files

- `tools/add_license_header.sh` — the broken fix tool (all four bugs have at least one root
  here)
- `tools/check_license_headers.sh` — BUG-LH-004 (working-directory sensitivity)
- Files that would be incorrectly stamped if `add_license_header.sh` is re-run:
  - `lib/data/database/app_database.g.dart`
  - `lib/data/database/daos/app_settings_dao.g.dart`
  - `lib/data/database/daos/cycle_entry_dao.g.dart`
  - `lib/data/database/daos/daily_log_dao.g.dart`
  - `lib/data/database/daos/sync_log_dao.g.dart`
  - `lib/l10n/app_localizations.dart`
  - `lib/l10n/app_localizations_en.dart`
  - `lib/l10n/app_localizations_it.dart`

### Constraints the Fix Must Respect

1. **GPL-3.0 header format.** The canonical header is exactly the 16-line block in the
   `HEADER` variable of `add_license_header.sh`. The `REQUIRED_LINE` in
   `check_license_headers.sh` is `// Copyright (C) 2026  Paolo Santucci` (double space
   between year and name). Any fix must preserve this exact string as the detection anchor.
2. **Both scripts must use the same predicate.** The only durable fix is for the stamper to
   adopt the checker's exact `REQUIRED_LINE` detection. Defining `REQUIRED_LINE` in one
   place (ideally sourced or duplicated with a comment cross-reference) prevents future
   drift.
3. **Do not modify generated files.** The fix must add exclusion logic to
   `add_license_header.sh` that mirrors `check_license_headers.sh` exactly.
4. **Idempotency.** Running `add_license_header.sh` twice must produce the same result as
   running it once. The current stamper is already idempotent for "missing header" files
   (re-run would find "Copyright" on line 1 and skip). The updated stamper for "outdated
   header" must also be idempotent.

### Suggested Fix Approach

**Step 1 — align the detection predicates**

Replace `add_license_header.sh`'s inner condition:

```bash
# Before (broken: broad substring, line 1 only)
if ! head -1 "$file" | grep -q "Copyright"; then

# After (aligned with checker's exact predicate)
REQUIRED_LINE="// Copyright (C) 2026  Paolo Santucci"
if ! head -n 20 "$file" | grep -qF -- "$REQUIRED_LINE"; then
```

This single change makes the stamper detect "outdated" headers and also files where the
copyright line appears after line 1.

**Step 2 — add generated-file exclusions**

Mirror the `case` block from `check_license_headers.sh` verbatim:

```bash
find lib test -name "*.dart" -print0 2>/dev/null | while IFS= read -r -d '' file; do
  case "$file" in
    *.g.dart|*.freezed.dart) continue ;;
    lib/l10n/app_localizations*.dart) continue ;;
  esac
  ...
done
```

Using `-print0` + `IFS= read -r -d ''` also fixes handling of filenames with spaces (not
currently a concern, but correct practice).

**Step 3 — handle outdated headers (strip before re-stamp)**

When a file contains some `Copyright` line but not the exact `REQUIRED_LINE`, the fix must
strip the old header before prepending the new one. A minimal approach:

```bash
if head -n 20 "$file" | grep -qF -- "Copyright"; then
  # Has some copyright block but not the required one — strip the old header
  # Remove from line 1 through the closing GPL line, plus one trailing blank line
  sed -i '1,/along with.*see <https:\/\/www\.gnu\.org\/licenses\/>\./d' "$file"
  # Remove one leading blank line if present after the old header
  sed -i '1{/^[[:space:]]*$/d}' "$file"
fi
echo "Stamping $file"
printf '%s\n' "$HEADER" | cat - "$file" > /tmp/metra_hdr_$$ && mv /tmp/metra_hdr_$$ "$file"
```

Using `/tmp/metra_hdr_$$` (process-ID suffix via `mktemp` or `$$`) addresses the temp-file
race in BUG-LH-003.

**Step 4 — add `set -euo pipefail`**

Add `set -euo pipefail` at the top of `add_license_header.sh`, after the shebang, to
ensure write failures abort the script rather than silently continuing.

**Step 5 — (optional) make check_license_headers.sh CWD-independent**

To fix BUG-LH-004, replace the hardcoded relative path `lib/l10n/app_localizations*.dart`
with `*/lib/l10n/app_localizations*.dart` or use the `[[ "$file" == */l10n/app_localizations* ]]`
guard so it matches regardless of the prefix.
