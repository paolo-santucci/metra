---
layout: help
title: Cloud backup
subtitle: "How to connect Dropbox and what \"end-to-end encrypted\" means in practice."
nav_title: Cloud backup
lang: en
lang_ref: help-backup
permalink: /en/help/backup/
help_order: 4
---

## How Mētra backup works

Your data never leaves your device unless you decide it should. **Local-first** is not a feature toggle, it is the default state. Backup is an option, not an expectation.

When you enable it, Mētra encrypts your entire database on your device **before** uploading it. Dropbox receives a blob it cannot read. No one else has access to your data, including the people who wrote the code.

> ⚠️ **There is no passphrase reset.** The encryption key is derived from your passphrase and lives only on your device — not on any server, not in the cloud. If you lose the passphrase, the backup cannot be recovered. Keep it somewhere safe, separate from your phone (e.g. a password manager).

---

## Connecting a cloud provider

![Backup screen before connection: Dropbox connect button.](/assets/backup-connect-en.png)

1. Go to **Settings → Cloud backup**.
2. Tap **Connect Dropbox**.
3. Your browser opens the provider's login page.
4. Once you authorise the connection, you're returned to Mētra.

Mētra requests the minimum permissions: only access to a dedicated app folder, not your full cloud storage.

---

## Creating a backup

![Backup screen after connection: connected email, last backup date, "Back up now" and "Disconnect" buttons.](/assets/backup-connected-en.png)

Once connected:

1. Tap **Back up now**.
2. On your **first backup**, Mētra asks you to set a passphrase. This passphrase is stored securely on your device (iOS Keychain / Android Keystore) and reused automatically for all subsequent backups — you will not be prompted again unless you disconnect and reconnect.
3. Mētra encrypts the database on your device and uploads it. A progress indicator shows the status.
4. When complete, the screen displays the date and time of the last successful backup.

> **On the passphrase:** there is no recovery option, because there is no server that could perform one. Choose a passphrase you will remember and store it separately from your phone.

After the initial backup, Mētra will perform periodic backups automatically.

Mētra automatically keeps the 3 most recent encrypted backups in the cloud folder; older blobs are pruned after each successful upload. No user-tunable setting — local-first / respect-the-adult-user posture.

---

## What is backed up

The backup contains:

- All daily logs (flow, pain, symptoms, notes).

App settings (theme, language, notifications, cycle-length baseline) are **not** included. After restoring, you will need to re-configure those preferences.

It does **not** include local notification schedule state: those are re-created automatically after a restore.

---

## Restoring from a backup

![Restore flow: backup picker sheet (scroll wheel), then passphrase entry, then progress and success confirmation.](/assets/backup-restore-en.png)

1. Install Mētra on the new device (or after a factory reset).
2. Complete the onboarding flow, the baseline numbers do not matter, they will be overwritten by the restore.
3. Go to **Settings → Cloud backup**.
4. Connect your Dropbox account. If backups are found, Mētra will indicate it and show when the most recent one was created.
5. Tap **Restore from backup** and confirm in the warning dialog that current data will be replaced.
6. A picker sheet appears: scroll the wheel to select the backup version you want. Each entry shows date and time (up to 3 backups available, newest at the top).
7. Tap **Restore** to confirm, or **Cancel** to go back.
8. Enter your passphrase. Mētra downloads the chosen backup, decrypts it, and replaces the local database.

> ⚠️ **Warning:** Restoring overwrites all data currently on the device. This action cannot be undone.

---

## Disconnecting the provider

Tap **Disconnect** in the backup screen to unlink the cloud account. The backup files already on the cloud are **not deleted**, you must delete them manually from the Dropbox app or website.

Mētra retains up to the 3 most recent encrypted backups in the app folder.

---

## Technical security details

- Encryption algorithm: **AES-256-GCM**.
- Key derivation: **Argon2id** from your passphrase.
- The derived encryption key is never stored anywhere — not in the cloud, not on the device. It is computed from your passphrase on demand, used, then discarded. Your passphrase itself is stored in the device's secure hardware storage (iOS Keychain / Android Keystore) so that subsequent backups can run without prompting you.
- The backup file has a `.enc` extension and is stored in a dedicated Mētra folder inside your cloud account.

These are not marketing claims: they are specific choices in the code. You can verify them in `lib/data/services/encryption_service.dart`.
