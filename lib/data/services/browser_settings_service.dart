// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const MethodChannel _channel = MethodChannel('metra/browser_settings');

class BrowserSettingsService {
  const BrowserSettingsService();

  Future<bool> openAppDetails(String packageName) async {
    try {
      final ok = await _channel.invokeMethod<bool>(
        'openAppDetails',
        {'packageName': packageName},
      );
      return ok ?? false;
    } catch (e) {
      debugPrint('[BrowserSettings.openAppDetails] $e');
      return false;
    }
  }

  Future<bool> openAppsSettings() async {
    try {
      final ok = await _channel.invokeMethod<bool>('openAppsSettings');
      return ok ?? false;
    } catch (e) {
      debugPrint('[BrowserSettings.openAppsSettings] $e');
      return false;
    }
  }
}
