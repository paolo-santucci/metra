#!/usr/bin/env bash
# Stamps GPL-3.0 header on Dart files missing it.
HEADER="// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
//
// Métra is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License,
// or (at your option) any later version.
//
// Métra is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Métra. If not, see <https://www.gnu.org/licenses/>.
"

find lib test -name "*.dart" 2>/dev/null | while read -r file; do
  if ! head -1 "$file" | grep -q "Copyright"; then
    echo "Stamping $file"
    printf '%s\n' "$HEADER" | cat - "$file" > /tmp/metra_hdr && mv /tmp/metra_hdr "$file"
  fi
done
