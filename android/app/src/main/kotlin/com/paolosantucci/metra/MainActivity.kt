package com.paolosantucci.metra

import android.content.Intent
import android.os.Bundle
import com.linusu.flutter_web_auth_2.FlutterWebAuth2Plugin
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
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
