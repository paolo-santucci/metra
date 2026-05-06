#!/usr/bin/env bash
# Copyright (C) 2026  Paolo Santucci
#
# This file is part of Métra.
#
# Métra is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published
# by the Free Software Foundation, either version 3 of the License,
# or (at your option) any later version.
#
# Métra is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Métra. If not, see <https://www.gnu.org/licenses/>.

set -euo pipefail
cd "$(dirname "$0")/.."

# shellcheck source=tools/license_header_constants.sh
source "tools/license_header_constants.sh"

# Use CLI args as file list if given, otherwise scan lib/ and test/
if [ "$#" -gt 0 ]; then
  files=("$@")
else
  mapfile -t files < <(find lib test -type f -name '*.dart' 2>/dev/null)
fi

for f in "${files[@]}"; do
  skip_generated_file "$f" && continue

  # Already stamped? (check first 20 lines for exact REQUIRED_LINE)
  if head -n 20 "$f" | grep -qF "$REQUIRED_LINE"; then
    continue
  fi

  # Prepend header using a temp file (race-safe, error-safe)
  TMP=$(mktemp)
  trap 'rm -f "$TMP"' EXIT
  printf '%s\n' "$HEADER" > "$TMP"
  cat "$f" >> "$TMP"
  mv "$TMP" "$f"
  trap - EXIT
done
