// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
//
// Métra is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Métra is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Métra. If not, see <https://www.gnu.org/licenses/>.

package com.paolosantucci.metraapp

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import com.linusu.flutter_web_auth_2.FlutterWebAuth2Plugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val kBatteryOptChannel = "metra/battery_optimization"

    // Registers the battery-optimisation MethodChannel so Flutter can query
    // PowerManager.isIgnoringBatteryOptimizations and fire the OS settings
    // intent without adding a new native library.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, kBatteryOptChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isIgnoring" -> {
                        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
                            // Android < 6.0 (API 23): Doze mode does not exist —
                            // treat as whitelisted.
                            result.success(true)
                        } else {
                            val pm = getSystemService(POWER_SERVICE) as PowerManager
                            result.success(pm.isIgnoringBatteryOptimizations(packageName))
                        }
                    }
                    "openSettings" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val intent = Intent(
                                Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                            ).also { it.data = Uri.parse("package:$packageName") }
                            startActivity(intent)
                        }
                        // Android < 23: no-op.
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // Hosting the OAuth intent-filter on MainActivity (singleTop) instead of
    // flutter_web_auth_2's CallbackActivity keeps the redirect inside the app's
    // existing task — Chrome's Custom Tab is then properly hidden by the time
    // the Future resolves. The plugin's CallbackActivity is provided by the
    // package source but no longer registered in AndroidManifest.xml, so we
    // resolve the pending callback ourselves via its public static map.
    //
    // Order matters: consumeOAuthCallback runs BEFORE super.onCreate /
    // super.onNewIntent. Otherwise FlutterActivity would forward the intent
    // URL into Flutter's route-information stream and go_router would throw
    // "no routes for location: metra://oauth-callback/...".
    override fun onCreate(savedInstanceState: Bundle?) {
        consumeOAuthCallback(intent)
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        consumeOAuthCallback(intent)
        super.onNewIntent(intent)
    }

    private fun consumeOAuthCallback(intent: Intent?) {
        val url = intent?.data ?: return
        if (url.scheme == "metra") {
            // Resolve the pending Future (no-op if process-death wiped the
            // static callbacks map; user just retries).
            FlutterWebAuth2Plugin.callbacks.remove(url.scheme)?.success(url.toString())
            // Strip data + action so go_router and any other intent-data
            // consumer can't pick the OAuth URL up after super dispatches.
            intent.data = null
            intent.action = null
        }
    }
}
