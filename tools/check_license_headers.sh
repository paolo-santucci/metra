#!/usr/bin/env bash
# Verifies that every hand-written .dart file under lib/ and test/ contains
# the GPL-3.0 copyright header. Generated files (*.g.dart, *.freezed.dart)
# are excluded — they carry a "GENERATED CODE" marker instead.
# Exits 1 if any non-generated file is missing the header.

set -euo pipefail

REQUIRED_LINE="// Copyright (C) 2026  Paolo Santucci"
FAILURES=0

while IFS= read -r -d '' file; do
  # Skip generated files produced by build_runner
  case "$file" in
    *.g.dart|*.freezed.dart) continue ;;
  esac

  if ! head -n 20 "$file" | grep -qF -- "$REQUIRED_LINE"; then
    echo "MISSING LICENSE HEADER: $file"
    FAILURES=$((FAILURES + 1))
  fi
done < <(find lib test -name "*.dart" -print0 2>/dev/null)

if [ "$FAILURES" -gt 0 ]; then
  echo ""
  echo "ERROR: $FAILURES file(s) are missing the license header."
  echo "Run tools/add_license_header.sh to stamp them, then commit."
  exit 1
fi

echo "OK: all hand-written .dart files carry the license header."
