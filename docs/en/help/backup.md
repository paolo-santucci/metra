---
layout: page
title: Cloud backup
---

[← Back to Help](/metra/help/) &nbsp;·&nbsp; [🇮🇹 Italiano](/metra/help/it/backup)

## How Métra backup works

Métra is **local-first**: your data never leaves your device unless you explicitly choose to back it up. The backup feature is entirely optional.

When you enable backup, Métra encrypts your entire database on your device **before** uploading it. The cloud provider — Dropbox, Google Drive, or OneDrive — receives only an opaque, unreadable blob. It has no access to your data, and neither does anyone else.

> **There is no password reset.** The encryption key is derived from your passphrase and lives only on your device. If you lose the passphrase, the backup cannot be recovered. Keep it in a safe place (e.g. a password manager).

---

## Connecting a cloud provider

<!-- SCREENSHOT PLACEHOLDER: backup-connect.png -->
<!-- Backup screen before connection: three provider buttons (Dropbox, Google Drive, OneDrive). -->

1. Go to **Settings → Cloud backup**.
2. Choose your preferred provider: **Dropbox**, **Google Drive**, or **OneDrive**.
3. You will be redirected to the provider's login page in your browser.
4. After authorising the connection, you are returned to Métra.

Métra requests the minimum necessary permissions — only access to a dedicated app folder, not your full cloud storage.

---

## Creating a backup

<!-- SCREENSHOT PLACEHOLDER: backup-connected.png -->
<!-- Backup screen after connection: connected email, last backup date, "Back up now" and "Disconnect" buttons. -->

Once connected:

1. Tap **Backup now** (Esegui backup).
2. Métra asks you to enter — or confirm — your **passphrase**. This passphrase is used to encrypt the backup file. You will need it to restore.
3. The backup is encrypted on your device and uploaded. A progress indicator is shown.
4. When complete, the screen displays the date and time of the last successful backup.

> **Tip:** Choose a passphrase you will remember, and store it separately from your phone (e.g. in a password manager). There is no recovery option.

---

## What is backed up

The backup contains the complete contents of your encrypted database:

- All daily logs (flow, pain, symptoms, notes).
- Cycle entries derived from your logs.
- App settings (cycle-length baseline, notification preferences).

It does **not** include local notification schedule state — those are re-created automatically after a restore.

---

## Restoring from a backup

<!-- SCREENSHOT PLACEHOLDER: backup-restore.png -->
<!-- Restore flow: passphrase entry dialog, then progress, then success confirmation. -->

1. Install Métra on the new device (or after a factory reset).
2. Complete the onboarding flow — the baseline numbers do not matter, they will be overwritten by the restore.
3. Go to **Settings → Cloud backup**.
4. Connect to the same provider you used for the backup.
5. Tap **Restore** (Ripristina).
6. Enter your passphrase.
7. Métra downloads the backup, decrypts it, and replaces the local database.

> **Warning:** Restoring overwrites all data currently on the device. This action cannot be undone.

---

## Disconnecting

Tap **Disconnect** (Disconnetti) in the backup screen to unlink the cloud account. This removes the OAuth token from the device. The backup file already on the cloud is **not deleted** — you must delete it manually from your cloud storage if you want to remove it.

---

## Security details

- Encryption algorithm: **AES-256-GCM**.
- Key derivation: **Argon2id** from your passphrase.
- The key is never stored in the cloud, never sent to any server, and never persisted on the device itself — it is derived fresh from the passphrase each time.
- The backup file has a `.enc` extension and is stored in a dedicated Métra folder inside your cloud account.

You can verify all of this by reading the source code in `lib/data/services/encryption_service.dart`.

---

[← Back to Help](/metra/help/)
