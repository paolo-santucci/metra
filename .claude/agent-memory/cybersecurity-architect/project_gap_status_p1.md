---
name: Gap status P-1
description: Stato verificato dei GAP da threat-model v1.0 dopo il completamento dello sprint P-1
type: project
---

Verificato leggendo i sorgenti effettivi al 2026-04-28 (commit post-P-1).

**GAP-01** — Parzialmente risolto. `lib/providers/encryption_provider.dart:26` imposta `AndroidOptions(encryptedSharedPreferences: true)`. Nessuna `IOSOptions` configurata: iOS usa default OS (accessibility non vincolata a first_unlock_this_device). Gap residuo: iOS. Target: P-2.

**GAP-02** — Ancora aperto. Nessun logging wrapper con redazione. P-1 ha aggiunto un solo `debugPrint` (`historical_entry_screen.dart:156`) dentro `assert(() {...}())` — compila fuori in release, stampa solo `$e` (testo eccezione), non campi di `DailyLogEntity`. Nessuna nuova violazione, ma il wrapper sistematico è ancora assente. Target: P-2.

**GAP-03** — Ancora aperto. `key_management_service.dart:32`: `if (existing != null && _isValidHexKey(existing))` — se `existing` è non-null ma malformato, si cade fuori dal branch e si rigenera la chiave silenziosamente (wipe silenzioso del DB). Deve diventare `StorageException` esplicita. Target: P-2.

**GAP-04** — Ancora aperto. Nessun `FLAG_SECURE` (Android) né `blurImage` (iOS). P-1 ha reso concrete le schermate sensibili: `HistoricalEntryScreen` (note, flusso, dolore visibili), `QuickEntryModal` (flusso), `CalendarScreen` (griglia biologica). Surface esposta aumentata rispetto a P-0b. Target: P-2.

**GAP-05** — Ancora aperto. `android:allowBackup` assente in `android/app/src/main/AndroidManifest.xml`. Target: P-2.

**Why:** Verifica diretta del codice sorgente effettivo, non assunzioni dalla documentazione precedente.
**How to apply:** Nella revisione P-2, prioritizzare GAP-04 (surface più ampia post-P-1) e GAP-03 (wipe silenzioso = perdita dati utente).
