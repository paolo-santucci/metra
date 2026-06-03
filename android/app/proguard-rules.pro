# Copyright (C) 2026  Paolo Santucci
#
# This file is part of Métra.
#
# Métra is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published
# by the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Métra is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Métra. If not, see <https://www.gnu.org/licenses/>.

# ──────────────────────────────────────────────────────────────────────────────
# Gson + R8 compatibility
# Reference: https://github.com/google/gson/blob/main/Troubleshooting.md
#
# R8 removes generic type signatures by default. Gson 2.10+ requires them to be
# present at runtime for TypeToken to work. Without these rules,
# FlutterLocalNotificationsPlugin.loadScheduledNotifications() throws:
#   IllegalStateException: TypeToken must be created with a type argument
# which crashes cancel() before zonedSchedule() is ever reached, so no alarm
# is ever registered with AlarmManager.
# ──────────────────────────────────────────────────────────────────────────────

# Keep generic signatures on all classes and fields — required by Gson's
# TypeToken to inspect parameterised types at runtime.
-keepattributes Signature
-keepattributes *Annotation*

# Gson streams are reflectively accessed.
-keep class com.google.gson.stream.** { *; }
-dontwarn sun.misc.**

# TypeAdapter / factory / serialiser / deserialiser implementations must
# survive shrinking so Gson can discover them at runtime.
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# Prevent R8 from nulling out @SerializedName-annotated fields.
-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Preserve TypeToken and all anonymous subclasses (new TypeToken<List<Foo>>(){}).
# R8 3.0+ requires allowobfuscation + allowshrinking to keep these correctly.
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken

# ──────────────────────────────────────────────────────────────────────────────
# flutter_local_notifications plugin
#
# The plugin's consumer rules do not cover Gson 2.10+ TypeToken semantics.
# Keep all plugin classes so R8 does not strip or rename any field accessed
# via reflection in loadScheduledNotifications().
# ──────────────────────────────────────────────────────────────────────────────
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Tink cryptographic library — used by flutter_secure_storage 9.x via
# EncryptedSharedPreferences (encryptedSharedPreferences: true).
# Tink registers key type managers via reflection at runtime; R8 strips them
# without these rules, causing NoClassDefFoundError on cold start when the
# database encryption key is read from secure storage.
-keep class com.google.crypto.tink.** { *; }
-dontwarn com.google.crypto.tink.**

# androidx.security.crypto — consumer ProGuard rules are absent from the AAR;
# keep the EncryptedSharedPreferences entry points explicitly.
-keep class androidx.security.crypto.** { *; }
-dontwarn androidx.security.crypto.**

# flutter_web_auth_2 — KeepAliveService is declared android:exported="true" in
# the manifest; R8 may rename it if not kept explicitly (Service, not FlutterPlugin).
-keep class com.linusu.flutter_web_auth_2.** { *; }
-dontwarn com.linusu.flutter_web_auth_2.**

# ──────────────────────────────────────────────────────────────────────────────
# App package — belt-and-suspenders keep for all application-layer classes.
#
# proguard-android-optimize.txt enables class-merging and other aggressive
# optimisations that can rename or inline the app's own Activity/Service/
# BroadcastReceiver entries before the manifest-referenced-class automatic keep
# fires, causing ClassNotFoundException: MainActivity on cold start.
# Explicitly keeping the entire app package costs nothing (a few dozen classes)
# and makes R8's behaviour deterministic regardless of AGP or R8 version.
# ──────────────────────────────────────────────────────────────────────────────
-keep class com.paolosantucci.metraapp.** { *; }
