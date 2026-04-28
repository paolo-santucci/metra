# Threat Model — Métra

**Versione:** 1.1
**Data:** 2026-04-28
**Autori:** Paolo Santucci (owner), revisione architetturale sicurezza P-0c / P-1
**Metodo:** STRIDE per i data path tecnici; LINDDUN per gli asset di privacy
**Ambito:** P-0b completato — DB cifrato, EncryptionService, provider Riverpod. P-1 completato — UI daily entry (QuickEntryModal, HistoricalEntryScreen), calendar grid con stream Drift, SaveDailyLog use case, RecomputeCycleEntries. Cloud sync (P-6) modellato come prospettico.
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

| ID | Gap | Priorità | Owner | Target | Status P-1 |
|---|---|---|---|---|---|
| GAP-01 | `flutter_secure_storage` senza opzioni esplicite (iOS accessibility, Android EncryptedSharedPreferences) | Alta | Dev | P-1 | Parzialmente risolto — `AndroidOptions(encryptedSharedPreferences: true)` impostato in `encryption_provider.dart:26`. iOS: nessuna `IOSOptions` configurata, accessibility usa il default OS. Ancora aperto per iOS — target: P-2 |
| GAP-02 | Assenza wrapper logging con redazione campi `DailyLog`/`notes` in release build | Alta | Dev | P-1 | Ancora aperto — nessun wrapper di redazione implementato. P-1 non ha introdotto nuove violazioni: il solo `debugPrint` aggiunto (`historical_entry_screen.dart:156`) è dentro `assert(() {...}())` (compilato fuori in release) e stampa solo il testo dell'eccezione, non campi di `DailyLogEntity`. Target: P-2 |
| GAP-03 | Rigenerazione silenziosa della chiave DB in caso di validazione fallita invece di eccezione esplicita | Media | Dev | P-1 | Ancora aperto — `key_management_service.dart:32`: se `existing != null` ma `_isValidHexKey` fallisce, il branch non è preso e si procede alla rigenerazione silenziosa (line 34–35), equivalente a un wipe silenzioso del DB. Target: P-2 |
| GAP-04 | `FLAG_SECURE` (Android) / `blurImage` (iOS) assenti su schermate sensibili | Alta | Dev | P-1 | Ancora aperto — P-1 ha reso concrete le schermate sensibili (HistoricalEntryScreen, QuickEntryModal). Il campo note è ora visibile a schermo. Nessuna protezione screenshot implementata. Target: P-2 |
| GAP-05 | `android:allowBackup` non configurato esplicitamente — rischio backup ADB della chiave | Alta | Dev | P-1 | Ancora aperto — `android:allowBackup` assente in `AndroidManifest.xml`. Target: P-2 |
| GAP-06 | Nessun indicatore di forza passphrase backup e requisito minimo lunghezza | Media | Dev | P-6 | Non in scope P-1 |
| GAP-07 | Blob backup senza versioning (rollback attack prospettico) | Bassa | Dev | P-6 | Non in scope P-1 |
| GAP-08 | Correlazione metadata blob cloud (dimensione/timing) | Bassa | Arch | P-6 (padding) | Non in scope P-1 |
| GAP-09 | Avviso obbligatorio export CSV "dati in chiaro" non ancora implementato | Alta | Dev | P-5 | Non in scope P-1 |

---

## 6. Delta P-1 — Path daily entry e calendar grid

Questa sezione estende il modello P-0b per coprire i data path introdotti da P-1: inserimento dati utente tramite UI reale (`QuickEntryModal`, `HistoricalEntryScreen`), stream del calendario mensile e ricalcolo cicli post-salvataggio.

---

### 6.1 Path A+C: Inserimento dati utente → `SaveDailyLog` → `DailyLogDao`

**Descrizione del path:** L'utente inserisce dati di flow, dolore e note in `QuickEntryModal` (oggi) o `HistoricalEntryScreen` (data arbitraria passata). Il widget costruisce un `DailyLogEntity` e chiama `DailyEntryNotifier.save()` → `SaveDailyLog` use case → `DailyLogRepositoryImpl.saveDailyLog()` → `DailyLogDao.upsertDailyLog()` (Drift, `insertOnConflictUpdate`, parametrizzato) → SQLCipher DB.

Per il Path C (storico), la data arriva come parametro URL `/daily-entry/:date` e viene parsata in `app_router.dart:48–53` con `split('-')` + `int.parse()` prima di essere passata a `HistoricalEntryScreen`.

Rispetto a §2.1 (che modellava il path a livello di DAO senza UI), questo path aggiunge: la validazione temporale in `SaveDailyLog`, il parsing del parametro URL, la visualizzazione del campo note a schermo, e la catena di errori Riverpod.

| STRIDE | Minaccia | Likelihood | Impact | Priorità | Controllo esistente | Gap / Azione |
|---|---|---|---|---|---|---|
| Spoofing | Inserimento di un log con data futura per falsificare il contesto temporale dell'evento. | Bassa — richiede la costruzione manuale di un `DailyLogEntity` con data futura, che la normale UI non consente. | Medio | Bassa | `SaveDailyLog` (line 41–46): normalizza la data a UTC midnight e lancia `ValidationException` se `logDay.isAfter(todayDay)`. Il risultato `Err` è restituito al notifier senza propagare al framework. | Nota: l'inserimento di date passate è consentito per design (entry storico è una feature P-1). La minaccia speculare — data eccessivamente lontana nel passato — non ha mitigazione ma l'impatto è basso (nessun effetto di sicurezza, solo qualità del dato). |
| Tampering | Iniezione SQL tramite campo `notes` (ora un `TextField` reale) o campo `customLabel`. | Bassa — Drift usa query parametrizzate. | Critico | Bassa | Drift ORM parametrizza tutti i campi. `DailyLogDao.upsertDailyLog` usa `DailyLogsCompanion` → parametri bind. Nessuna interpolazione di stringa. (Vedi analisi completa in §2.1.) | Verificare che nessuna query futura usi `customStatement` con interpolazione. |
| Tampering | Manomissione del parametro URL `:date` per iniettare una data malformata (es. `"2026-99-99"` o `"../../etc"`). | Bassa — nessun `intent-filter` deep-link registrato in `AndroidManifest.xml`; il routing è esclusivamente interno all'app. | Basso | Bassa | `app_router.dart:48–53`: `int.parse()` su `parts[0..2]` lancia `FormatException` su input non numerico. `DateTime.utc()` lancia `ArgumentError` su valori fuori range. Entrambe le eccezioni si propagano come crash del route builder — non è un fail-secure elegante, ma non espone dati. | Nessuna superficie di attacco esterna verificata (nessun deep-link intent). Se in futuro si aggiungono App Links/Universal Links, aggiungere try/catch nel route builder con redirect a un error screen. |
| Tampering | Il `PainIntensitySlider` potrebbe essere manipolato per inviare valori fuori range [0–3]. | Molto bassa — il widget Flutter `Slider` garantisce il clamping nel range configurato; il valore non può uscire dal widget. | Basso | Bassa | `PainIntensitySlider` usa `Slider` Flutter con `min: 0`, `max: 3`. `SaveDailyLog` (line 48–53) aggiunge un controllo difensivo: rifiuta `painIntensity` fuori da `[0, _maxPainIntensity]` con `ValidationException`. Defense-in-depth corretto. | Nessuna azione richiesta. |
| Repudiation | N/A — app single-user, nessun audit trail lato server richiesto. | — | — | N/A | — | — |
| Information Disclosure | Note libere (campo `TextField`) ora visibili a schermo: rischio screenshot OS in background e shoulder surfing. | Alta — comportamento OS default; nessuna protezione schermata attiva. | Alto | Alta | SQLCipher protegge le note a riposo. Drift parametrizza la scrittura. Nessuna protezione per la visualizzazione a schermo. | **GAP-04 ancora aperto.** `FLAG_SECURE` (Android) e `blurImage` (iOS) non implementati. Target: P-2. Vedi §6.4. |
| Information Disclosure | `debugPrint` di campi `DailyLogEntity` in log di sviluppo. | Bassa in P-1 — l'unico `debugPrint` aggiunto (`historical_entry_screen.dart:156`) è dentro `assert(() {...}())`, compila fuori in release, e stampa solo il testo dell'eccezione (non campi entità). | Alto (se avvenisse) | Bassa (P-1 non introduce violazioni) | Commento esplicito `// Do not log DailyLogEntity fields — security requirement` in `daily_entry_controller.dart:64`. Il pattern `assert()` garantisce la compilazione fuori in release. | **GAP-02 ancora aperto** per il wrapper sistematico. In P-1 nessuna nuova violazione introdotta. Target: P-2. |
| Denial of Service | Invio ripetuto di richieste di salvataggio per saturare il DB SQLite. | Molto bassa — app single-user, nessun accesso concorrente esterno; SQLite serializza le scritture. | Basso | Bassa | Sandbox OS isola il file DB. La UI non consente batch automatici. | N/A. |
| Elevation of Privilege | N/A — nessun cambio di boundary di fiducia rispetto a §2.1. | — | — | N/A | — | — |

---

### 6.2 Path B: `CalendarMonthNotifier` → `GetMonthLogs` → stream DB

**Descrizione del path:** `CalendarMonthNotifier.build()` inizializza uno stream Drift mensile tramite `GetMonthLogs(year, month)` → `DailyLogRepository.watchMonth()` → `DailyLogDao` → SQLCipher DB. Il path è **read-only**: nessuna scrittura, nessun input utente diretto se non la navigazione mese precedente/successivo.

Superficie di attacco ridotta: l'unico input esterno è la selezione del mese (intero `year`, intero `month`), costruita internamente dal notifier con aritmetica verificata. Non esiste path da input utente grezzo a parametro di query DB.

| STRIDE | Minaccia | Likelihood | Impact | Priorità | Controllo esistente | Gap / Azione |
|---|---|---|---|---|---|---|
| Spoofing | N/A — path read-only, nessuna identità da verificare. | — | — | N/A | — | — |
| Tampering | N/A — nessuna scrittura in questo path. | — | — | N/A | — | — |
| Repudiation | N/A | — | — | N/A | — | — |
| Information Disclosure | Dati del mese (flow, dolore) visualizzati nella griglia calendario: stessi rischi di screenshot di §6.1 (ID) e §2.3. | Alta | Alto | Alta | SQLCipher protegge a riposo. Nessuna protezione schermata. | Stesso gap di GAP-04. La calendar screen espone i dati di flow con encoding semantico (cerchi terracotta). Incluso nell'implementazione attesa di FLAG_SECURE in P-2. |
| Denial of Service | Stream Drift che emette un volume elevato di aggiornamenti se il DB è mutato rapidamente. | Molto bassa — la navigazione mensile cancella e ricrea la subscription; nessuna query non limitata. `watchMonth` filtra per `(year, month)` — O(giorni del mese), non O(intera tabella). | Basso | Bassa | `_subscribeToMonth` cancella la subscription precedente prima di crearne una nuova (`_logSub?.cancel()`). | N/A. |
| Elevation of Privilege | N/A | — | — | N/A | — | — |

---

### 6.3 Path A/C: `RecomputeCycleEntries` post-salvataggio

**Descrizione del path:** Dopo ogni salvataggio riuscito (`DailyEntryNotifier.save()`, line 71–72), viene invocato `RecomputeCycleEntries.call()`, che esegue `DailyLogRepository.getAllOrderedByDate()` → lettura dell'intera tabella `DailyLogs` → algoritmo `_compute()` → `CycleEntryRepository.replaceAll()`. Il ricalcolo è sincrono rispetto al salvataggio: l'utente deve attendere il completamento prima che lo stato si aggiorni.

| STRIDE | Minaccia | Likelihood | Impact | Priorità | Controllo esistente | Gap / Azione |
|---|---|---|---|---|---|---|
| Tampering | Un salvataggio con dati manipolati (es. flow intensity forged) altera la derivazione dei cicli. | Bassa — i controlli in `SaveDailyLog` validano il payload prima della persistenza. | Medio | Bassa | `SaveDailyLog` valida flow+spotting (mutuamente esclusivi), range `painIntensity`, data non futura. Drift parametrizza la scrittura. | La catena di validazione è corretta. Documentare che `_compute()` è una funzione pura testabile indipendentemente (già esposta come `RecomputeCycleEntries.compute()` static). |
| Denial of Service | Un singolo salvataggio scatena un ricalcolo su tutta la cronologia: costo proporzionale al numero di righe. | Molto bassa — volume realistico: ~1 riga/giorno × anni = poche migliaia di righe. `_compute()` è O(N) single-pass (loop a line 69). Nessun loop annidato, nessun algoritmo quadratico. | Basso | Bassa | `_compute()` è single-pass su `flowDays` (un sottoinsieme di `DailyLogs`). Limite naturale: N < 10.000 per qualsiasi uso realistico. | Documentare il bound esplicito in un commento in `recompute_cycle_entries.dart`. Nessuna azione di sicurezza richiesta. |
| Information Disclosure | `getAllOrderedByDate()` carica l'intera cronologia in memoria per la durata del ricalcolo. | Bassa | Medio | Bassa | I dati risiedono nella sandbox privata dell'app, già decifrati dal layer Drift/SQLCipher nel processo app. Nessuna esposizione a processi terzi. | N/A in architettura local-only. |
| Spoofing / Repudiation / Elevation of Privilege | N/A per questo path. | — | — | N/A | — | — |

---

### 6.4 Note libere — aggiornamento del modello (aggiornamento §2.3)

In P-0b, la minaccia di Information Disclosure per screenshot del campo `notes` era classificata come **prospettica** (§2.3, seconda riga ID), perché la UI non era ancora implementata. Con P-1, `HistoricalEntryScreen` include un `TextField` per le note (line 326–332) e il valore è visibile a schermo quando `_notesEnabled == true`.

**Stato aggiornato:**

Il rischio di screenshot OS (LINDDUN categoria Di) è ora **concreto**, non più prospettico. La minaccia era già classificata Priorità Alta in §2.3; questa conferma non modifica la priorità ma aggiorna lo stato da "rischio prospettico" a "superficie esposta in produzione".

I controlli esistenti a riposo rimangono invariati e sufficienti per P-1:
- SQLCipher AES-256 protegge `notes` nel file DB.
- Drift parametrizza la scrittura: nessun rischio di SQL injection.
- L'entità `DailyLogEntity` non ha `toString()` override che esponga campi.

Il gap residuo — `FLAG_SECURE` (Android) e `blurImage`/`ignoreInRecents` (iOS) — rimane aperto (GAP-04). La sua applicazione deve coprire almeno: `HistoricalEntryScreen` (note visibili), `QuickEntryModal` (flow visibile), e la `CalendarScreen` (pattern biologico visibile). La mitigazione è schedulata per P-2.

**Nota sull'`assert` a `historical_entry_screen.dart:155–159`:** il `debugPrint` di failure di `replacePainSymptoms` stampa solo il testo dell'eccezione (`$e`), non campi di `DailyLogEntity`. In release mode, il blocco `assert()` viene eliminato dal compilatore. Non costituisce una nuova violazione di §11 CLAUDE.md.

---

### 6.5 Aggiornamento gap table

Vedi tabella aggiornata in §5. Riepilogo delle variazioni rispetto alla versione 1.0:

**GAP-01** — Parzialmente risolto. `AndroidOptions(encryptedSharedPreferences: true)` è configurato in `lib/providers/encryption_provider.dart:26`. L'opzione iOS (`IOSOptions` con `accessibility: IOSAccessibility.first_unlock_this_device`) non è impostata: il comportamento su iOS resta il default OS. Gap residuo: iOS. Target spostato a P-2.

**GAP-02** — Ancora aperto. Nessun wrapper di redazione sistematico implementato. P-1 non introduce nuove violazioni (l'unico `debugPrint` aggiunto è in `assert`, stampa solo testo di eccezione, compila fuori in release). Target spostato a P-2.

**GAP-03** — Ancora aperto. `key_management_service.dart:32`: il ramo `if (existing != null && _isValidHexKey(existing))` non è preso quando `existing` è non-null ma malformato, causando rigenerazione silenziosa della chiave (wipe silenzioso del DB). Deve essere convertito in `StorageException` esplicita. Target spostato a P-2.

**GAP-04** — Ancora aperto. P-1 ha reso concrete le schermate sensibili. La superficie esposta è aumentata: `HistoricalEntryScreen` (note, flusso, dolore), `QuickEntryModal` (flusso), `CalendarScreen` (griglia con encoding biologico). Target spostato a P-2.

**GAP-05** — Ancora aperto. `android:allowBackup` assente in `android/app/src/main/AndroidManifest.xml`. Target spostato a P-2.
