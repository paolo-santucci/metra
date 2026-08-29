// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/browser_settings_service.dart';

const String chromePackage = 'com.android.chrome';

final browserSettingsServiceProvider = Provider<BrowserSettingsService>(
  (_) => const BrowserSettingsService(),
);
