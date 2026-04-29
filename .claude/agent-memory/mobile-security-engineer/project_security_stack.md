---
name: Métra security stack
description: Security libraries, their configuration, and known gaps in Métra as of commit b20f4d4
type: project
---

Flutter 3.x + Dart, Riverpod 2.x, Drift ORM, SQLCipher via `sqlcipher_flutter_libs ^0.5.4`.

**Secure storage:** `flutter_secure_storage ^9.2.2`. Android: `AndroidOptions(encryptedSharedPreferences: true)` — uses Android Keystore, software-backed (no explicit StrongBox). iOS: NO `iOptions` set — default accessibility class is `first_unlock_this_device`, which is a confirmed L2 gap. Should be `KeychainAccessibility.whenUnlockedThisDeviceOnly`.

**Backup crypto:** `cryptography ^2.7.0`. AES-256-GCM + Argon2id (memory=64MB, iter=3, par=4). Random IV and salt per operation. Blob format: [16B salt][12B nonce][ciphertext][16B MAC]. Implementation in `lib/data/services/encryption_service.dart`.

**DB key management:** `lib/data/services/key_management_service.dart`. Key returned as `String` (not `Uint8List`) — not zeroizable after use, confirmed L2 gap. Key stored under `metra_db_encryption_key_v1` in secure storage.

**DB:** SQLCipher AES-256-CBC, key passed as `PRAGMA key = "x'<hex>'"`. Cipher version verified at open. Background isolate requires explicit `open.overrideFor(OperatingSystem.android, openCipherOnAndroid)` re-registration (already implemented correctly in `app_database.dart`).

**No network stack active in MVP.** `google_sign_in` / `googleapis` present in pubspec but commented. Cloud sync deferred to P-6.

**Why:** Understanding these details prevents re-auditing the same surface and helps identify if any of these gaps have been closed in subsequent PRs.
**How to apply:** When reviewing PRs touching encryption_provider.dart, key_management_service.dart, or AndroidManifest.xml, check against these known gaps first.
