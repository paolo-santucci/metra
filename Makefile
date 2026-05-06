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

SHELL := /bin/bash

.DEFAULT_GOAL := help
.PHONY: help test test-full

# Evaluate once at parse time: non-empty when pub get is needed.
PUB_GET_NEEDED := $(shell [ ! -f pubspec.lock ] || [ pubspec.yaml -nt pubspec.lock ] && echo yes)

help:  ## Show available targets
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*## / {printf "  %-12s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

test:  ## Run tests (auto-installs deps if pubspec.yaml changed)
ifeq ($(PUB_GET_NEEDED),yes)
	flutter pub get
endif
	flutter test --no-pub

test-full:  ## Run full test suite with fresh pub get
	flutter pub get
	flutter test
