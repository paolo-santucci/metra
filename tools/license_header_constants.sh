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
#
# -----------------------------------------------------------------------
# Shared constants sourced by add_license_header.sh and
# check_license_headers.sh.  Do NOT execute this file directly.
# Update this file — NOT the individual scripts — when the canonical
# copyright line or GPL header block needs to change.
# -----------------------------------------------------------------------

REQUIRED_LINE="// Copyright (C) 2026  Paolo Santucci"

# Full GPL-3.0 Dart header block prepended to every hand-written .dart file.
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
// along with Métra. If not, see <https://www.gnu.org/licenses/>."

# skip_generated_file <path>
# Returns 0 (skip) if the given file path matches a generated-file pattern,
# returns 1 (process) otherwise.
# Covers: *.g.dart, *.freezed.dart, *.mocks.dart, *app_localizations*.dart,
#         */.dart_tool/*, */build/*
skip_generated_file() {
  case "$1" in
    *.g.dart | *.freezed.dart | *.mocks.dart) return 0 ;;
    *app_localizations*.dart)                 return 0 ;;
    */.dart_tool/* | */build/*)               return 0 ;;
    *) return 1 ;;
  esac
}
