// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
//
// Métra is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Métra is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Métra. If not, see <https://www.gnu.org/licenses/>.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Provides the app version string read from the native bundle at runtime.
///
/// On Android this reads [BuildConfig.VERSION_NAME]; on iOS it reads
/// [CFBundleShortVersionString] from [Info.plist]. Both values are set
/// by the `version` field in `pubspec.yaml` (the part before the `+`),
/// so the displayed version is always in sync with the installed build.
///
/// Prefer this over any hardcoded constant to avoid version drift.
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return info.version; // e.g. "1.0.0" — build number excluded
});
