# Threat Model — Métra

**Versione:** 1.0
**Data:** 2026-04-28
**Autori:** Paolo Santucci (owner), revisione architetturale sicurezza P-0c
**Metodo:** STRIDE per i data path tecnici; LINDDUN per gli asset di privacy
**Ambito:** P-0b completato — DB cifrato, EncryptionService, provider Riverpod. Cloud sync (P-6) modellato come prospettico.
**Revisione programmata:** ad ogni release maggiore o ogni 6 mesi.

---

## 1. Asset e boundary di fiducia

### Asset critici

| Asset | Posizione | Custode | Sensibilità |
|---|---|---|---|
| Chiave DB SQLCipher | `flutter_secure_storage` (iOS Keychain / Android EncryptedSharedPreferences) | `KeyManagementService` | Massima — perdita = dati inaccessibili |
| Note libere utente (`DailyLogs.notes`) | DB SQLCipher `metra.db` | `DailyLogDao` | Massima — salute personale, intime |
| Dati di flusso e intensità dolore | DB SQLCipher `metra.db` | `DailyLogDao` | Alta — dato sanitario |
| Cicli e pattern temporali | DB SQLCipher `metra.db` | `CycleEntryDao` | Alta — rivela pattern biologici |
| Blob di backup cifrato | Cloud provider (P-6, prospettico) | `EncryptionService` | Alta — cifrato E2E, provider opaco |
| Passphrase di backup | Mai persistita | Utente | Massima — perdita = irrecuperabilità |
| Preferenze `AppSettings` | DB SQLCipher | `AppSettingsDao` | Bassa |
| Audit log cloud (`SyncLogs`) | DB SQLCipher, locale | `AppSettingsDao` | Bassa |

### Boundary di fiducia

Il modello non ha boundary di rete in scope per P-0b. L'unico confine rilevante è: **processo Dart ↔ flutter_secure_storage (OS keystore)**. La comunicazione avviene tramite platform channel. Nessun dato transita su rete fino a P-6.

---

## 2. Analisi STRIDE per data path

### 2.1 Input utente → `DailyLogDao.upsertDailyLog` → DB SQLCipher

**Descrizione del path:** L'utente inserisce dati (flow, pain, note) nella UI → il widget chiama un use-case o notifier Riverpod → `DailyLogDao.upsertDailyLog` (`lib/data/database/daos/daily_log_dao.dart:35`) costruisce un `DailyLogsCompanion` e chiama `insertOnConflictUpdate` → Drift genera SQL parametrizzato → SQLCipher esegue sul file `metra.db` in `getApplicationSupportDirectory()`.

| STRIDE | Minaccia | Likelihood | Impact | Priorità | Controllo esistente | Gap / Azione |
|---|---|---|---|---|---|---|
| Spoofing | N/A — nessuna autenticazione tra componenti locali; l'app è single-user, single-process. | — | — | N/A | — | — |
| Tampering | Iniezione SQL tramite campo `notes` o `customLabel`. | Bassa — Drift usa query parametrizzate. | Critico | Media | Drift ORM parametrizza tutte le query. `customLabel` è `TextColumn` passato come parametro, non interpolato. | Verificare che nessun DAO futuro usi `customStatement` con interpolazione di stringa. |
| Repudiation | Utente nega di aver inserito un dato. | Bassa | Bassa | Bassa | Nessun meccanismo di firma per i log locali (non richiesto — app single-user). | N/A per il modello locale. |
| Information Disclosure | Leakage di `notes` o dati di flusso in log di debug tramite `print`/`debugPrint`. | Media — rischio durante lo sviluppo. | Alto | Alta | Nessun wrapper di logging con redaction attualmente implementato. | **Implementare wrapper di logging che oscura i campi `DailyLog` in release build.** Vedere §5 gap. |
| Denial of Service | Inserimento massivo di righe da input malevolo (improbabile in app locale). | Molto bassa | Bassa | Bassa | DB path = `getApplicationSupportDirectory()` (sandbox privata, non accessibile ad altre app). | N/A. |
| Elevation of Privilege | Un'altra app legge `metra.db` direttamente. | Bassa — Android: `/data/data/<pkg>/files` privato per default; iOS: sandbox. | Alto | Media | Directory app-private su entrambe le piattaforme. SQLCipher: file illeggibile senza chiave. | Nessuna azione immediata richiesta. Documentare la dipendenza dal modello di sandbox OS. |

---

### 2.2 Ciclo di vita della chiave DB: generazione → `flutter_secure_storage` → chiamata `PRAGMA key`

**Descrizione del path:** Al primo avvio, `KeyManagementService.getOrCreateDatabaseKey()` (`lib/data/services/key_management_service.dart:30`) invoca `_generateHexKey()` (line 46) che usa `Random.secure()` per generare 32 byte → formato hex a 64 caratteri → scritto in `flutter_secure_storage` con chiave `metra_db_encryption_key_v1`. Ad ogni avvio successivo, letto dallo storage sicuro, validato con regex (`_isValidHexKey`, line 39), poi passato a `AppDatabase.openConnection()` (`lib/data/database/app_database.dart:143`). Qui, line 144, viene applicato un `RegExp(r'^[0-9a-fA-F]{64}$')` prima di interpolare la stringa nell'istruzione `PRAGMA key = "x'$hexKey'"` (line 161).

| STRIDE | Minaccia | Likelihood | Impact | Priorità | Controllo esistente | Gap / Azione |
|---|---|---|---|---|---|---|
| Spoofing | Chiave sostituita da un'app malevola nello storage. | Molto bassa — richiede compromissione del keystore OS. | Critico | Bassa | Keystore OS (Keychain / EncryptedSharedPreferences) isola per package ID. | N/A in assenza di root/jailbreak. |
| Tampering | Chiave corrotta nello storage: `_isValidHexKey` ritorna `false` → viene rigenerata una nuova chiave → DB diventa inaccessibile. | Bassa | Critico | Media | `_isValidHexKey` (line 39) previene uso di chiave malformata. `cipher_version` check (app_database.dart:164–171) rileva SQLCipher non caricato. | La rigenerazione silenziosa della chiave in caso di validazione fallita equivale a un wipe silenzioso. **Convertire in `StorageException` esplicita invece di rigenerare.** |
| Tampering | Interpolazione SQL nel `PRAGMA key`: se `hexKey` contenesse `'` o caratteri speciali potrebbe rompere la sintassi. | Molto bassa — il regex a line 144 blocca tutto ciò che non è `[0-9a-fA-F]{64}`. | Alto | Bassa | Regex di validazione su `openConnection` (line 144) mitiga completamente. | Il controllo è corretto. Documentare esplicitamente il rationale nei commenti. |
| Repudiation | N/A. | — | — | N/A | — | — |
| Information Disclosure | Chiave leakage in log, crash report, o variabile Dart con vita lunga in memoria. | Media — rischio concreto durante sviluppo. | Critico | Alta | Nessun meccanismo di redaction attuale. `KeyManagementService` non logga la chiave. | **Mai loggare `hexKey`. Aggiungere lint rule / hook per rilevare `print(hexKey)`.** Azzerare la stringa in memoria dopo l'uso ove possibile (limitato in Dart — documentare). |
| Information Disclosure | `flutter_secure_storage` usa opzioni di default: iOS senza `accessibility: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, Android senza `AndroidOptions(encryptedSharedPreferences: true)` espliciti. | Media — comportamento implicito OS, non una scelta consapevole. | Alto | Alta | Keystore OS fornisce protezione di base. | **Gap noto: configurare `flutter_secure_storage` con opzioni esplicite.** Vedere §5. |
| Denial of Service | `flutter_secure_storage` non disponibile (es. primo avvio su emulatore senza keystore). | Bassa | Alta | Media | `getOrCreateDatabaseKey` propaga l'eccezione al chiamante (`DatabaseNotifier.build`). | Il provider Riverpod deve presentare uno stato di errore leggibile — non un crash silenzioso. |
| Elevation of Privilege | Chiave accessibile ad altre app tramite backup ADB. | Media — backup ADB estrae `shared_prefs` su dispositivi non cifrati. | Critico | Alta | `flutter_secure_storage` usa Android Keystore su Android 6+. | Verificare che `android:allowBackup="false"` o backup rules escludano il keystore. Da implementare in `AndroidManifest.xml` (fuori scope P-0b, ma gap noto). |

**Nota sul controllo `cipher_version` (app_database.dart:164–171):** questo check è un controllo fail-secure esplicito. Se SQLCipher non è linkato correttamente, il DB verrebbe aperto senza cifratura. Il `StateError` garantisce un fallimento rumoroso invece di silenzioso. Questo pattern è corretto e deve essere preservato in ogni refactor di `openConnection`.

---

### 2.3 Campo note libere `DailyLogs.notes` (asset ad alta sensibilità)

**Descrizione:** `DailyLogs.notes` (`app_database.dart:44`) è una `TextColumn` nullable. L'utente può inserire testo libero di salute personale. L'unica protezione di confidenzialità a riposo è SQLCipher sull'intero file DB.

| STRIDE | Minaccia | Likelihood | Impact | Priorità | Controllo esistente | Gap / Azione |
|---|---|---|---|---|---|---|
| Spoofing | N/A | — | — | N/A | — | — |
| Tampering | Modifica diretta del file DB se l'attaccante ha accesso al filesystem. | Bassa — richiede root. | Alto | Bassa | SQLCipher: modifica senza chiave corrotta produce errore di autenticazione GCM. | N/A. |
| Repudiation | N/A | — | — | N/A | — | — |
| Information Disclosure | Note visualizzate in log di debug, crash report, o clipboard sniffing. | Media | Critico | Alta | Nessun wrapper redaction. Nessun crash reporter di terze parti (design principle). | **Wrapper logging con redazione automatica dei campi `DailyLog` in release.** La colonna `notes` non deve mai apparire in `toString()` di un'entità Drift esposta a log. |
| Information Disclosure | Screenshot dell'app in background cattura note visibili. | Alta — comportamento OS default. | Alto | Alta | Nessuna protezione attuale. | **Implementare `FLAG_SECURE` (Android) e `blurImage` (iOS) per schermate sensibili.** Gap noto P-0c. |
| Denial of Service | N/A | — | — | N/A | — | — |
| Elevation of Privilege | N/A | — | — | N/A | — | — |

---

### 2.4 `EncryptionService` → blob di backup (P-6, prospettico)

**Descrizione:** `EncryptionService.encrypt()` (`lib/data/services/encryption_service.dart:49`) riceve i dati DB come `Uint8List` e una passphrase utente. Genera 16 byte di salt (`_randomBytes`, line 51) e 12 byte di IV (line 52) con `Random.secure()`. Deriva la chiave con Argon2id (memory=64MB, iter=3, par=4, hashLength=32, line 34–38). Cifra con AES-256-GCM (line 54–58). Il blob risultante è `[salt][IV][ciphertext][MAC-16-byte]`. Il provider cloud vede solo questo blob opaco.

**Questo path è prospettico — P-6 non ancora implementato. Le minacce sono modellate ora per guidare l'implementazione.**

| STRIDE | Minaccia | Likelihood | Impact | Priorità | Controllo esistente | Gap / Azione |
|---|---|---|---|---|---|---|
| Spoofing | Backup su account cloud dell'attaccante (se il flusso OAuth P-6 è compromesso). | Bassa — richiede phishing OAuth. | Alto | Media | Salt+IV random per ogni cifratura: il blob è inutile senza la passphrase. | Implementare validazione token OAuth in storage sicuro (non DB). |
| Tampering | Blob modificato sul cloud: GCM authentication tag rileva la modifica. | Bassa | Alto | Bassa | Il GCM MAC (16 byte, line 64) verifica l'integrità. `SecretBoxAuthenticationError` propagato come `CryptoException` (line 87). | Il controllo è corretto. |
| Tampering | Downgrade a blob di versione precedente (rollback attack). | Bassa | Media | Bassa | Nessun versioning del blob attuale. | Aggiungere un prefisso di versione al blob (es. 1 byte version tag) in P-6. |
| Repudiation | L'utente nega di aver fatto backup. | Bassa | Bassa | Bassa | `SyncLogs` locale registra ogni operazione. | `SyncLogs` non è incluso nel blob di backup — intenzionale. |
| Information Disclosure | Correlazione di traffico: upload periodico rivela pattern di utilizzo al provider. | Media | Bassa | Bassa | Nessuna mitigazione (fuori scope per un'app senza server). | Documentare come limitazione accettata — il contenuto rimane opaco. |
| Information Disclosure | Passphrase debole: deriva chiave deducibile. | Media | Critico | Alta | Argon2id con parametri forti (64MB mem) ostacola brute-force. Nessuna policy di complessità UI. | Implementare indicatore di forza passphrase e requisito minimo (≥12 caratteri) in P-6 UI. |
| Information Disclosure | Salt/IV non random — riuso → vulnerabilità GCM. | Molto bassa — `Random.secure()` utilizzato. | Critico | Bassa | `_randomBytes` usa `Random.secure()` (line 96). | N/A. |
| Information Disclosure | Passphrase memorizzata in memoria Dart dopo l'uso. | Media | Alto | Media | Nessuna zeroizzazione (limitazione Dart — GC non garantisce). | Documentare limitazione; minimizzare il tempo di vita della variabile passphrase. |
| Denial of Service | Passphrase persa = dati irrecuperabili (no server-side recovery). | Media — rischio reale per utenti non tecnici. | Alto | Alta | Design intent: zero-knowledge implica no recovery. | **Obbligo UX P-6: avviso chiaro e obbligatorio "Salva la passphrase — non esiste recupero".** |
| Elevation of Privilege | N/A | — | — | N/A | — | — |

---

### 2.5 Singleton `AppSettings` (lingua, notifiche, preferenze)

**Descrizione:** `AppSettings` (`app_database.dart:78–91`) è una riga singleton (sempre `id=1`). Contiene `languageCode`, `darkMode`, `painEnabled`, `notesEnabled`, `notificationDaysBefore`, `notificationsEnabled`. Nessun dato sanitario diretto.

Questo path ha superficie di attacco minima: singolo processo locale, nessun dato sensibile, nessuna autenticazione richiesta.

| STRIDE | Minaccia | Likelihood | Impact | Priorità | Controllo esistente | Gap / Azione |
|---|---|---|---|---|---|---|
| Tampering | Modifica di `notificationsEnabled = false` da un'app con accesso root, disabilitando notifiche. | Molto bassa | Bassa | Bassa | SQLCipher protegge il file. | N/A. |
| Information Disclosure | `languageCode` rivela la lingua preferita dell'utente se il DB è accessibile. | Molto bassa — non è dato sanitario. | Molto bassa | N/A | SQLCipher. | N/A. |
| Spoofing / Repudiation / DoS / EoP | N/A per questo path. | — | — | N/A | — | — |

---

## 3. Analisi LINDDUN per asset di privacy

**Metodo:** matrice asset × categoria LINDDUN (7 categorie).
**Nota:** L'architettura local-first di Métra elimina per costruzione le minacce di Linking e Identification server-side. Questa è una feature progettuale deliberata, non un'assenza di analisi.

Categorie LINDDUN:
- **L** — Linking (collegare record diversi per inferire identità)
- **I** — Identifying (identificare un individuo da dati anonimi)
- **N** — Non-repudiation (impossibilità per l'utente di negare azioni)
- **D** — Detecting (rilevare che un individuo usa il servizio)
- **Di** — Disclosure of information (divulgazione di dati a terzi)
- **U** — Unawareness (utente non consapevole del trattamento)
- **C** — Non-compliance (violazione normativa GDPR/NIS2)

| Asset di privacy | L | I | N | D | Di | U | C |
|---|---|---|---|---|---|---|---|
| **Note libere (`notes`)** | Basso — locale, nessun server | Basso — no account, no profilo | Basso — log locale non condiviso | Basso — no telemetria | **Medio** — screenshot OS, log debug, clipboard | Basso — utente inserisce consapevolmente | Basso — GDPR: trattamento locale, nessun trasferimento |
| **Storia di flusso (flowIntensity)** | Basso | Basso | N/A | Basso | **Medio** — export CSV non cifrato (P-5) | **Medio** — warning export non ancora implementato | Basso |
| **Record di dolore (PainSymptoms)** | Basso | Basso | N/A | Basso | **Medio** — export CSV, screenshot | Basso | Basso |
| **Pattern di ciclo (CycleEntries)** | **Medio (P-6)** — se blob cifrato correlabile per dimensione/timing | Basso — nessun identificativo | N/A | Basso | Basso — cifrato E2E nel backup | **Alto (P-6)** — utente deve essere informata che la dimensione del blob può variare | Basso |

### Analisi dettagliata per categoria

**Linking (L):** In architettura local-first pura (P-0b–P-5) il rischio è trascurabile: nessun dato lascia il dispositivo. In P-6 (backup cloud), un attaccante con accesso all'account cloud potrebbe correlare la frequenza e le dimensioni dei blob con pattern di utilizzo. Il contenuto rimane opaco (E2E cifrato), ma la metadata cloud (timestamp upload, dimensione blob) può essere correlabile. Mitigazione prospettica: upload con padding a blocchi fissi per mascherare la dimensione reale.

**Identifying (I):** Métra non raccoglie nome, email, o identificativi. Nessun account Métra. Il rischio di de-anonimizzazione è basso per costruzione. L'account cloud (P-6) è del provider, non di Métra.

**Non-repudiation (N):** `SyncLogs` registra operazioni cloud localmente. L'utente può sempre visualizzare e cancellare questi log da Impostazioni. Non viene creato un audit trail non cancellabile — questo è intenzionale (GDPR art. 17).

**Detecting (D):** Nessuna telemetria, nessun analytics, nessun ping a server Métra. Il rischio di rilevazione è limitato al traffico verso il cloud provider dell'utente (già noto all'utente) in P-6.

**Disclosure of information (Di):** Il rischio principale è locale: screenshot OS in background (gap documentato §2.3), export CSV non cifrato (futura funzione P-5 — must show warning esplicito), log di debug con dati non redatti (gap documentato §2.2). Nessuna terza parte riceve dati in scope attuale.

**Unawareness (U):** L'export CSV (P-5) è il momento di maggior rischio: l'utente potrebbe non capire che il file è in chiaro. La UI deve mostrare un avviso obbligatorio prima di ogni export. Per il backup cloud (P-6), la semantica "solo tu hai la chiave" deve essere comunicata chiaramente durante il setup della passphrase.

**Non-compliance (C):** Métra non ha server, non trasferisce dati, non usa analytics. Il trattamento è interamente locale, per uso personale. GDPR artt. 2(2)(c) (eccezione attività personale) e 4(5) (pseudonimizzazione tramite cifratura) sono rilevanti. L'assenza di un DPO e di una privacy policy "classica" è accettabile per un'app GPL senza server. La Privacy Policy su GitHub Pages (§14 CLAUDE.md) deve tuttavia documentare esplicitamente l'assenza di raccolta dati.

---

## 4. Controlli esistenti — riepilogo

| Controllo | File / Classe | Status |
|---|---|---|
| DB cifrato con SQLCipher AES-256 | `app_database.dart:143–177` | Implementato |
| Chiave 256-bit da `Random.secure()` | `key_management_service.dart:46–50` | Implementato |
| Validazione formato chiave pre-PRAGMA | `app_database.dart:144` | Implementato |
| Fail-secure `cipher_version` check | `app_database.dart:164–171` | Implementato |
| Storage chiave in OS keystore | `key_management_service.dart:24`, `flutter_secure_storage` | Implementato (opzioni default — gap) |
| Argon2id per derivazione chiave backup | `encryption_service.dart:34–38` | Implementato |
| AES-256-GCM per backup blob | `encryption_service.dart:41` | Implementato |
| Salt + IV random per ogni cifratura | `encryption_service.dart:51–52` | Implementato |
| GCM authentication tag (16 byte) | `encryption_service.dart:64` | Implementato |
| Nessun crash reporter di terze parti | Design | Implementato |
| Directory DB in sandbox privata | `database_provider.dart:48` (`getApplicationSupportDirectory`) | Implementato |

---

## 5. Gap noti e roadmap di remediation

| ID | Gap | Priorità | Owner | Target |
|---|---|---|---|---|
| GAP-01 | `flutter_secure_storage` senza opzioni esplicite (iOS accessibility, Android EncryptedSharedPreferences) | Alta | Dev | P-1 |
| GAP-02 | Assenza wrapper logging con redazione campi `DailyLog`/`notes` in release build | Alta | Dev | P-1 |
| GAP-03 | Rigenerazione silenziosa della chiave DB in caso di validazione fallita invece di eccezione esplicita | Media | Dev | P-1 |
| GAP-04 | `FLAG_SECURE` (Android) / `blurImage` (iOS) assenti su schermate sensibili | Alta | Dev | P-1 |
| GAP-05 | `android:allowBackup` non configurato esplicitamente — rischio backup ADB della chiave | Alta | Dev | P-1 |
| GAP-06 | Nessun indicatore di forza passphrase backup e requisito minimo lunghezza | Media | Dev | P-6 |
| GAP-07 | Blob backup senza versioning (rollback attack prospettico) | Bassa | Dev | P-6 |
| GAP-08 | Correlazione metadata blob cloud (dimensione/timing) | Bassa | Arch | P-6 (padding) |
| GAP-09 | Avviso obbligatorio export CSV "dati in chiaro" non ancora implementato | Alta | Dev | P-5 |
