# Audit OWASP MASVS v2 — Target L2

**Progetto:** Métra v0.1.0  
**Commit di riferimento:** b20f4d4  
**Data documento:** 2026-04-28  
**Redatto da:** Mobile Security Engineer (static review + gap analysis vs L1)  
**Riferimento baseline:** `docs/security/masvs-l1-baseline.md`

**Nota metodologica:** MASVS v2 definisce 24 controlli autonomi. Il task di riferimento citava 25 controlli; la discrepanza è dovuta all'inclusione di MASVS-PRIVACY (4 controlli) non presenti nell'enumerazione standard MASVS v2, ma inclusi nella baseline L1 per rilevanza clinica dell'app. Questo documento mantiene la struttura della baseline L1 (24 controlli) per coerenza. La soglia ≥80% è calcolata su 24 controlli (≥20 PASS/N-A/DEFERRED giustificato).

**Nota sul task originale:** Il task indicava "MASVS-CODE-2: obfuscation non configurata" come L2 gap. In MASVS v2, CODE-2 è "enforces app updates" e l'obfuscation è RESILIENCE-3. Il gap di obfuscation è tracciato correttamente sotto RESILIENCE-3, in continuità con la baseline L1.

---

## Tabella riassuntiva

| # | Controllo | Stato L1 | Stato L2 | Delta |
|---|-----------|----------|----------|-------|
| 1 | MASVS-STORAGE-1 | PASS (parziale) | **FAIL** | Protezione file iOS non impostata; IOSOptions assente |
| 2 | MASVS-STORAGE-2 | FAIL | **FAIL** | Stesso gap L1 + screenshot suppression mancante |
| 3 | MASVS-CRYPTO-1 | PASS | **PASS** | Nessun delta — algoritmi conformi |
| 4 | MASVS-CRYPTO-2 | PASS (con obs.) | **FAIL** | L2 richiede hardware-backed key; key in memoria come String |
| 5 | MASVS-AUTH-1 | N/A | **N/A** | Nessun auth remoto nel codice attuale |
| 6 | MASVS-AUTH-2 | N/A | **DEFERRED P-5** | Biometric app-lock: L2 gap, fuori scope MVP |
| 7 | MASVS-AUTH-3 | N/A | **DEFERRED P-5** | Re-auth su operazioni distruttive: L2 gap |
| 8 | MASVS-NETWORK-1 | PASS | **PASS** | Nessuna rete attiva; condizionale a P-6 |
| 9 | MASVS-NETWORK-2 | N/A | **DEFERRED P-6** | No endpoint proprietario; deferred a fase cloud |
| 10 | MASVS-PLATFORM-1 | PASS | **PASS** | Nessun delta — IPC non esposta |
| 11 | MASVS-PLATFORM-2 | N/A | **N/A** | Nessuna WebView |
| 12 | MASVS-PLATFORM-3 | PASS (parziale) | **DEFERRED P-5** | Screen overlay/screenshot suppression: deferred |
| 13 | MASVS-CODE-1 | PASS (cond.) | **FAIL** | minSdk non esplicito; StrongBox richiede ≥API 28 |
| 14 | MASVS-CODE-2 | N/A | **N/A** | Pre-release; update enforcement post-v1.0 |
| 15 | MASVS-CODE-3 | PASS (riserva) | **FAIL** | Dep scanner non in CI; L2 lo richiede esplicitamente |
| 16 | MASVS-CODE-4 | PASS (parziale) | **PASS (parziale)** | Validazione OK su perimetro attuale; da ricontrollare a F-01 |
| 17 | MASVS-RESILIENCE-1 | FAIL (def. P-7) | **DEFERRED P-7** | Root/jailbreak detection: deferred per roadmap |
| 18 | MASVS-RESILIENCE-2 | FAIL | **FAIL (blocker)** | Debug key in produzione: pre-release blocker |
| 19 | MASVS-RESILIENCE-3 | FAIL (def. P-7) | **DEFERRED P-7** | Obfuscation: deferred per roadmap |
| 20 | MASVS-RESILIENCE-4 | N/A | **DEFERRED P-7** | Anti-Frida: scarsamente compatibile con GPL-3.0 open source |
| 21 | MASVS-PRIVACY-1 | PASS | **PASS** | Nessun delta |
| 22 | MASVS-PRIVACY-2 | PASS | **PASS** | Nessun delta |
| 23 | MASVS-PRIVACY-3 | PASS (cond.) | **PASS (cond.)** | Privacy Policy pre-distribuzione: condizionale |
| 24 | MASVS-PRIVACY-4 | PASS (cond.) | **PASS (cond.)** | Funzionalità di cancellazione/export: condizionale |

**Conteggio L2:** PASS/PASS(parziale/cond.) = 9 | DEFERRED (giustificato) = 6 | FAIL = 5 | N/A = 4  
**Controlli conformi L2 (PASS + N/A + DEFERRED giustificato):** 19/24 = **79%** — appena sotto la soglia target ≥80%.  
**Percorso alla soglia:** risolvere STORAGE-2 (P-0b, già in piano) porta il conteggio a 20/24 = **83%**. Le FAIL rimanenti (STORAGE-1, CRYPTO-2, CODE-1, CODE-3) sono pianificate in sprint P-0b/P-1.

---

## MASVS-STORAGE — Archiviazione sicura dei dati

### MASVS-STORAGE-1
**Testo del controllo:** The app securely stores sensitive data.

| Campo | Valore |
|-------|--------|
| **Stato L2** | FAIL |
| **Gap vs L1** | L1 rilevava come hardening L2: (1) `NSFileProtectionComplete` non impostato su iOS; (2) `IOSOptions` assenti in `flutter_secure_storage`, con conseguente uso della accessibility class default (`first_unlock_this_device`) anziché `afterFirstUnlockThisDeviceOnly` o `whenUnlockedThisDeviceOnly`. |
| **Evidenza del gap** | `encryption_provider.dart:24-28`: `FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true))` — nessuna `iOptions` specificata. Default iOS di `flutter_secure_storage` è `KeychainAccessibility.first_unlock_this_device`, che lascia la chiave accessibile mentre il device è bloccato dopo il primo sblocco. Per un'app di salute, `whenUnlockedThisDeviceOnly` è il livello appropriato: la chiave è accessibile solo quando il device è sbloccato, e non migra al backup di iCloud. |
| **Remediation** | (1) In `encryption_provider.dart`, aggiungere `iOptions`: `FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true), iOptions: IOSOptions(accessibility: KeychainAccessibility.whenUnlockedThisDeviceOnly))`. (2) Per il file DB su iOS, impostare la protezione `NSFileProtectionComplete` sul path restituito da `getApplicationSupportDirectory()` tramite `setAttributes({NSFileProtectionKey: NSFileProtectionComplete}, atPath:)` in un method channel, oppure verificare che il path sia nel container con protezione di default `NSFileProtectionCompleteUntilFirstUserAuthentication` e documentare la decisione. |
| **Verifica** | Su device sbloccato, bloccare il device, poi tentare `adb shell` o accesso fisico al file — il DB deve risultare inaccessibile. Per iOS: `plutil -p <app-container>/Documents/metra.db` con device bloccato deve fallire con errore di protezione. |

### MASVS-STORAGE-2
**Testo del controllo:** The app prevents leakage of sensitive data.

| Campo | Valore |
|-------|--------|
| **Stato L2** | FAIL |
| **Gap vs L1** | L1 già classificava come FAIL per `allowBackup` non disabilitato. L2 aggiunge: (1) nessuna soppressione degli screenshot nell'app switcher (FLAG_SECURE su Android, blur/oscuramento background su iOS); (2) i dati sanitari mostrati nella daily_entry screen saranno visibili nelle anteprime dell'app switcher. |
| **Evidenza del gap** | `AndroidManifest.xml`: `android:allowBackup` assente (default `true`). `Info.plist`: nessun `FLAG_SECURE` equivalente iOS configurato. Le schermate con note e sintomi (F-01, in sviluppo) non hanno protezione screenshot. |
| **Remediation** | (1) Stessa remediation L1: `android:allowBackup="false"` + `android:dataExtractionRules="@xml/data_extraction_rules"` in `AndroidManifest.xml`, con `res/xml/data_extraction_rules.xml` che esclude tutti i domini. (2) Android: in `MainActivity.kt` o via `FlutterActivity`, aggiungere `window.setFlags(WindowManager.LayoutParams.FLAG_SECURE, WindowManager.LayoutParams.FLAG_SECURE)` — nota: questo disabilita anche screenshot utente legittimi; valutare se applicare solo alle schermate di inserimento dati oppure configurare per build flavor. (3) iOS: implementare un `UIView` opaco sovrapposto nella callback `applicationWillResignActive` / `sceneWillDeactivate`. |
| **Verifica** | Android: `adb shell screencap -p` da una schermata di entry deve restituire schermata nera. Backup ADB: `adb backup -apk -f backup.ab com.paolosantucci.metra` deve produrre archivio vuoto. iOS: app switcher non deve mostrare contenuto reale delle schermate di entry. |

---

## MASVS-CRYPTO — Crittografia

### MASVS-CRYPTO-1
**Testo del controllo:** The app employs current strong cryptography and uses it according to industry best practices.

| Campo | Valore |
|-------|--------|
| **Stato L2** | PASS |
| **Gap vs L1** | Nessun gap L2 aggiuntivo. AES-256-GCM + Argon2id (memory=64MB, iter=3, par=4), IV/nonce randomico per operazione, salt randomico per derivazione: tutti conformi MASVS L2. SQLCipher AES-256-CBC per il DB locale. |
| **Evidenza** | `encryption_service.dart:34-41, 50-65` — implementazione invariata e conforme. |
| **Remediation** | Nessuna. |

### MASVS-CRYPTO-2
**Testo del controllo:** The app performs key management according to industry best practices.

| Campo | Valore |
|-------|--------|
| **Stato L2** | FAIL |
| **Gap vs L1** | L1 classificava PASS con osservazione su due punti: (1) chiave DB rappresentata come `String` Dart (non zeroizzabile); (2) `encryptedSharedPreferences: true` su Android usa una chiave AES wrappata da Android Keystore, ma non richiede esplicitamente hardware-backed (StrongBox). L2 eleva entrambi i punti. |
| **Evidenza del gap** | (a) `key_management_service.dart:30-37`: `getOrCreateDatabaseKey()` ritorna `String`. Le stringhe Dart sono immutabili e il GC non azzera la memoria — la chiave raw a 64 caratteri hex resta in memoria finché il GC non la raccoglie. (b) `encryption_provider.dart:25-26`: `AndroidOptions(encryptedSharedPreferences: true)` non imposta `keyCipherAlgorithm` o `storageCipherAlgorithm`, né usa `StrongBox` per forzare il backing hardware. Su device senza StrongBox (API < 28 o device low-end), la chiave di wrapping è software-backed. |
| **Remediation** | (1) Refactoring di `KeyManagementService`: restituire `Uint8List` invece di `String`; invocare `list.fillRange(0, list.length, 0)` dopo l'uso. Aggiornare `AppDatabase.openConnection` di conseguenza. (2) Valutare `AndroidOptions(encryptedSharedPreferences: true, keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding, storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding)` per i device con API ≥ 28, con fallback accettabile su API < 28. Il forcing di StrongBox non è possibile tramite `flutter_secure_storage` senza un method channel custom — documentare come acceptable residual risk se non implementato. |
| **Verifica** | Dumping di memoria del processo (con device rooted o Frida) durante una sessione aperta non deve mostrare la chiave DB in formato hex plaintext in aree di heap non cifrate — verificabile con `frida-ps` + script di memory search. |

---

## MASVS-AUTH — Autenticazione e Autorizzazione

### MASVS-AUTH-1
**Testo del controllo:** The app uses secure authentication and authorization protocols and follows the relevant best practices.

| Campo | Valore |
|-------|--------|
| **Stato L2** | N/A |
| **Giustificazione** | Invariato da L1. Nessun endpoint remoto, nessuna credential server nel codice attuale. I pacchetti OAuth (`google_sign_in`, `googleapis`) sono in `pubspec.yaml` ma non attivati. Il controllo sarà rivalutato a P-6. |

### MASVS-AUTH-2
**Testo del controllo:** The app performs local authentication securely according to the platform best practices.

| Campo | Valore |
|-------|--------|
| **Stato L2** | DEFERRED P-5 |
| **Gap vs L1** | L1 era N/A per assenza di biometric. L2 introduce la possibilità di un optional biometric app-lock per proteggere l'accesso all'app su device condiviso. MASVS v2 richiede, se implementato, che l'autenticazione biometrica Android usi `BIOMETRIC_STRONG` (Class 3) con `CryptoObject` binding, e che iOS usi `kSecAccessControlBiometryCurrentSet` come access control per il Keychain item (invalidazione al re-enrollment). |
| **Giustificazione del deferral** | L'app è single-user local-first; il biometric lock è un'opzione UX non richiesta per MVP. Se implementato a P-5 (Settings), deve soddisfare i requisiti L2: Android `BiometricPrompt` con `BIOMETRIC_STRONG` + `CryptoObject`; iOS `LAContext` con ACL Keychain `kSecAccessControlBiometryCurrentSet`. Non usare `deviceOwnerAuthentication` (che accetta PIN/passcode come fallback senza CryptoObject binding). |
| **Remediation (P-5)** | Aggiungere `local_auth` + method channel custom per il binding CryptoObject Android. Documentare la scelta `BiometryCurrentSet` vs `BiometryAny` (preferire `CurrentSet` per invalidazione a re-enrollment). |

### MASVS-AUTH-3
**Testo del controllo:** The app secures sensitive operations with additional authentication.

| Campo | Valore |
|-------|--------|
| **Stato L2** | DEFERRED P-5 |
| **Gap vs L1** | L1 era N/A. L2 richiede re-autenticazione step-up per operazioni distruttive (cancellazione DB, sovrascrittura dati da backup remoto). A P-5/P-6, l'operazione "ripristina backup da cloud" sovrascrive tutti i dati locali — è un'operazione che richiede conferma esplicita e, idealmente, re-auth. |
| **Giustificazione del deferral** | Le operazioni distruttive non sono ancora implementate (F-07, F-08). Quando implementate, devono includere almeno una conferma a due step e, se l'app-lock è abilitato, re-autenticazione biometrica/PIN. |

---

## MASVS-NETWORK — Comunicazione di Rete

### MASVS-NETWORK-1
**Testo del controllo:** The app secures all network traffic according to the current best practices.

| Campo | Valore |
|-------|--------|
| **Stato L2** | PASS |
| **Gap vs L1** | Nessun gap L2 nel perimetro attuale. Invariato: nessuna chiamata di rete attiva. A P-6, il delta L2 rispetto a L1 richiede `network_security_config.xml` con `cleartextTrafficPermitted="false"` e certificate trust anchors espliciti (nessun trust di CA di sistema non necessarie); lato iOS, `NSAllowsArbitraryLoads` deve essere `false` (default). |
| **Evidenza** | `AndroidManifest.xml`: nessun permesso `INTERNET` nel manifest principale; nessun override ATS in `Info.plist`. |

### MASVS-NETWORK-2
**Testo del controllo:** The app performs identity pinning for all remote endpoints under the developer's control.

| Campo | Valore |
|-------|--------|
| **Stato L2** | DEFERRED P-6 |
| **Giustificazione** | Invariato da L1. Non esistono endpoint proprietari. I provider cloud (Google Drive, Dropbox, OneDrive) non sono sotto il controllo dello sviluppatore; il pinning verso di loro è sconsigliato per rischio di breakage. Quando P-6 introdurrà OAuth, valutare SPKI pinning sull'endpoint di token exchange se si usa un backend intermediario; altrimenti documentare la scelta di non pinnare provider di terze parti con trust CA system-managed. |

---

## MASVS-PLATFORM — Interazione con la Piattaforma

### MASVS-PLATFORM-1
**Testo del controllo:** The app uses IPC mechanisms securely.

| Campo | Valore |
|-------|--------|
| **Stato L2** | PASS |
| **Gap vs L1** | Nessun gap L2. Superficie IPC invariata: unica `<activity>` exported per LAUNCHER, nessun componente aggiuntivo. A P-6, i callback OAuth devono usare App Links verificati (Digital Asset Links) anziché URL scheme custom — requisito L2 esplicito per prevenire intent hijacking. |

### MASVS-PLATFORM-2
**Testo del controllo:** The app uses WebViews securely.

| Campo | Valore |
|-------|--------|
| **Stato L2** | N/A |
| **Giustificazione** | Nessuna WebView nel codice. Invariato. |

### MASVS-PLATFORM-3
**Testo del controllo:** The app uses the user interface securely.

| Campo | Valore |
|-------|--------|
| **Stato L2** | DEFERRED P-5 |
| **Gap vs L1** | L1 era PASS parziale per UI in sviluppo. L2 richiede esplicitamente: (1) soppressione screenshot su schermate con dati sensibili (vedi STORAGE-2 per la remediation tecnica); (2) disabilitazione dell'input autofill/suggestion su campi note sensibili; (3) i campi note in `DailyLog` non devono essere suggeriti dalla tastiera predittiva. |
| **Giustificazione del deferral** | Le schermate di input (daily_entry, settings backup) non sono ancora implementate. La soppressione screen overlay è pre-autorizzata come deferred a P-5 per il task. Quando implementate, i TextField per le note devono usare `enableSuggestions: false` e `autocorrect: false` per evitare che il testo finisca nel dizionario della tastiera. |

---

## MASVS-CODE — Qualità del Codice

### MASVS-CODE-1
**Testo del controllo:** The app requires an up-to-date platform version.

| Campo | Valore |
|-------|--------|
| **Stato L2** | FAIL |
| **Gap vs L1** | L1 era PASS condizionale con raccomandazione di impostare `minSdk = 26` esplicitamente. L2 eleva questo a FAIL perché: (1) `minSdk` è delegato a `flutter.minSdkVersion` (`build.gradle.kts:27`) — il valore effettivo è determinato dalla versione Flutter SDK in uso, non dal progetto; (2) `StrongBox` (hardware security module dedicato) richiede API 28+; (3) Android Keystore hardware-backed richiede almeno API 23, ma senza `minSdk` esplicito non vi è garanzia. |
| **Evidenza del gap** | `build.gradle.kts:27`: `minSdk = flutter.minSdkVersion`. Il default Flutter per nuovi progetti è tipicamente API 21. API 21 non garantisce hardware-backed Keystore né StrongBox. |
| **Remediation** | Sostituire in `build.gradle.kts`: `minSdk = 26` (Android 8.0, >96% device attivi a 2026). Se il target audience richiede supporto a device più vecchi, documentare il trade-off e impostare almeno `minSdk = 23` con nota esplicita sull'assenza di garanzie hardware-backed. |
| **Verifica** | `grep minSdk android/app/build.gradle.kts` deve mostrare un valore numerico, non `flutter.minSdkVersion`. |

### MASVS-CODE-2
**Testo del controllo:** The app has a mechanism for enforcing app updates.

| Campo | Valore |
|-------|--------|
| **Stato L2** | N/A |
| **Giustificazione** | Invariato da L1. App pre-release v0.1.0. In-App Update (Play Core) sarà rilevante a v1.0. |

### MASVS-CODE-3
**Testo del controllo:** The app only uses software components without known vulnerabilities.

| Campo | Valore |
|-------|--------|
| **Stato L2** | FAIL |
| **Gap vs L1** | L1 era PASS con riserva per assenza di vulnerability scan automatizzato in CI. L2 classifica questo come FAIL perché la continuous dependency audit è un requisito esplicito del profilo L2, non un'osservazione opzionale. |
| **Evidenza del gap** | Nessun `osv-scanner` o `flutter pub audit` configurato nella pipeline CI. I file `.github/workflows/` non esistono nel repository al momento dell'audit. |
| **Remediation** | Aggiungere in `quality.yml` (GitHub Actions): `flutter pub audit --json` con exit-on-critical e upload dei risultati come artifact. Alternativa: `osv-scanner --lockfile pubspec.lock`. La pipeline deve fallire su vulnerabilità di severità HIGH o CRITICAL. |
| **Verifica** | `flutter pub audit` deve completare senza vulnerabilità HIGH/CRITICAL. Da eseguire ad ogni PR. |

### MASVS-CODE-4
**Testo del controllo:** The app validates and sanitizes all untrusted inputs.

| Campo | Valore |
|-------|--------|
| **Stato L2** | PASS (parziale — perimetro limitato) |
| **Gap vs L1** | Nessun delta sul perimetro attuale. La validazione su chiave DB e blob cifrato è invariata e corretta. Il perimetro si espanderà significativamente a F-01 (daily entry) e F-08 (import CSV/backup). La valutazione sarà aggiornata quando disponibili. |
| **Nota** | A F-09 (CSV import), la validazione degli input deserializzati è critica: validare lunghezza, tipo, range di date, intensità flow (0-4), e rifiutare record con campi non attesi prima dell'inserimento nel DB. |

---

## MASVS-RESILIENCE — Resilienza al Reverse Engineering

### MASVS-RESILIENCE-1
**Testo del controllo:** The app validates the integrity of the platform (root/jailbreak detection).

| Campo | Valore |
|-------|--------|
| **Stato L2** | DEFERRED P-7 |
| **Gap vs L1** | Invariato: nessun meccanismo di root/jailbreak detection. |
| **Giustificazione del deferral** | Deferral a P-7 confermato nel piano di sviluppo. Il threat model primario (pre-cloud, MVP local-first) è mitigato dalla crittografia del DB. A P-7: Play Integrity API (Android) + App Attest (iOS). La risposta deve essere un warning non bloccante per evitare falsi positivi su device legittimamente rooted. |

### MASVS-RESILIENCE-2
**Testo del controllo:** The app implements anti-tampering mechanisms.

| Campo | Valore |
|-------|--------|
| **Stato L2** | FAIL — pre-release blocker |
| **Gap vs L1** | Invariato da L1: la release build è firmata con la debug keystore (`build.gradle.kts:37`). |
| **Nota critica** | Questo FAIL è distinto dagli altri RESILIENCE deferral: non si tratta di hardening, ma di un prerequisito di distribuzione. Una APK firmata con debug key non può essere pubblicata su Play Store. La priorità è più alta di P-7: deve essere risolta prima di qualsiasi distribuzione esterna (TestFlight, Firebase App Distribution, Play Store). |
| **Remediation** | (1) Generare un release keystore con `keytool -genkey -v -keystore metra-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias metra`. (2) Configurare `signingConfigs.release` in `build.gradle.kts` con riferimento alle variabili d'ambiente CI (`KEYSTORE_PATH`, `KEYSTORE_PASSWORD`, ecc.). (3) Non committare il keystore nel repo; salvarlo come GitHub Secret cifrato. (4) Rimuovere `signingConfig = signingConfigs.getByName("debug")` dal blocco `release`. |
| **Verifica** | `apksigner verify --verbose release.apk` deve mostrare la firma del release keystore proprietario, non la debug key Android standard. |

### MASVS-RESILIENCE-3
**Testo del controllo:** The app implements anti-static analysis mechanisms (obfuscation).

| Campo | Valore |
|-------|--------|
| **Stato L2** | DEFERRED P-7 |
| **Gap vs L1** | Invariato: nessun `isMinifyEnabled`, nessun `proguard-rules.pro`, nessun flag `--obfuscate` nella build pipeline Flutter. |
| **Giustificazione del deferral** | Deferral a P-7 confermato. L'app è GPL-3.0 open-source: l'obfuscation riduce la leggibilità del codice compilato ma non viola la licenza (il sorgente rimane pubblico). Il beneficio principale è rendere più costoso il reverse engineering per scopi fraudolenti (tamper, key extraction), non nascondere l'algoritmo. Implementare a P-7: `flutter build apk --obfuscate --split-debug-info=build/symbols` + R8/ProGuard sul wrapper Android. |

### MASVS-RESILIENCE-4
**Testo del controllo:** The app implements anti-dynamic analysis techniques.

| Campo | Valore |
|-------|--------|
| **Stato L2** | DEFERRED P-7 |
| **Giustificazione** | Invariato da L1. I meccanismi anti-Frida aggressivi sono scarsamente compatibili con la natura open-source GPL-3.0 del progetto e creano friction per i ricercatori di sicurezza legittimi. Rivalutare a v1.0 considerando il threat model finale. Se implementato, usare rilevamento passivo (es. verifica di `maps` del processo per librerie Frida note) senza hard-block. |

---

## MASVS-PRIVACY — Privacy

### MASVS-PRIVACY-1
**Testo del controllo:** The app minimizes access to sensitive data and resources.

| Campo | Valore |
|-------|--------|
| **Stato L2** | PASS |
| **Gap vs L1** | Nessun delta. Zero permissions dichiarate nel manifest principale, nessun SDK analitico. |

### MASVS-PRIVACY-2
**Testo del controllo:** The app prevents identification of the user.

| Campo | Valore |
|-------|--------|
| **Stato L2** | PASS |
| **Gap vs L1** | Nessun delta. Nessun identificatore utente raccolta, nessuna telemetria, backup cifrato senza metadati identificativi. |

### MASVS-PRIVACY-3
**Testo del controllo:** The app is transparent about data collection and usage.

| Campo | Valore |
|-------|--------|
| **Stato L2** | PASS (condizionale — pre-release) |
| **Gap vs L1** | Invariato: Privacy Policy su GitHub Pages prima della distribuzione. Da verificare a P-7. |

### MASVS-PRIVACY-4
**Testo del controllo:** The app offers user control over their data.

| Campo | Valore |
|-------|--------|
| **Stato L2** | PASS (condizionale — funzionalità in sviluppo) |
| **Gap vs L1** | Invariato: cancellazione completa via `deleteDatabaseKey()` + eliminazione file DB; export CSV (F-09). Da verificare a P-5/P-7. |

---

## Roadmap di remediation per gap L2

I FAIL bloccanti e i gap L2 sono mappati agli sprint del piano di sviluppo Métra (P-0 attraverso P-7).

### Sprint P-0b (corrente — DB encryption hardening)

| ID | Controllo | Azione | File target |
|----|-----------|--------|-------------|
| R-01 | MASVS-STORAGE-2 | Aggiungere `android:allowBackup="false"` + `android:dataExtractionRules` | `android/app/src/main/AndroidManifest.xml` + `res/xml/data_extraction_rules.xml` |
| R-02 | MASVS-CRYPTO-2 | Refactoring `getOrCreateDatabaseKey()` da `String` a `Uint8List`; azzeramento dopo uso | `lib/data/services/key_management_service.dart`, `lib/data/database/app_database.dart` |
| R-03 | MASVS-STORAGE-1 | Aggiungere `iOptions: IOSOptions(accessibility: KeychainAccessibility.whenUnlockedThisDeviceOnly)` | `lib/providers/encryption_provider.dart` |

### Sprint P-1 (qualità e CI)

| ID | Controllo | Azione | File target |
|----|-----------|--------|-------------|
| R-04 | MASVS-CODE-3 | Aggiungere `flutter pub audit` + `osv-scanner` a `quality.yml` | `.github/workflows/quality.yml` (da creare) |
| R-05 | MASVS-CODE-1 | Impostare `minSdk = 26` esplicito | `android/app/build.gradle.kts` |

### Sprint P-5 (Settings + UI screens)

| ID | Controllo | Azione | Note |
|----|-----------|--------|------|
| R-06 | MASVS-PLATFORM-3 | Screenshot suppression su schermate sensitive (`FLAG_SECURE` Android, blur iOS) | Valutare se globale o per-schermata |
| R-07 | MASVS-AUTH-2 | Biometric app-lock opzionale con `BIOMETRIC_STRONG` + CryptoObject binding | Dipende da decisione UX P-5 |
| R-08 | MASVS-AUTH-3 | Re-auth su cancellazione DB e ripristino backup | Da implementare con F-07/F-08 |
| R-09 | MASVS-STORAGE-2 | Screenshot suppression (componente UI della remediation completa) | Coordinato con R-06 |

### Pre-distribuzione (prima di qualsiasi release esterna)

| ID | Controllo | Azione | Priorità |
|----|-----------|--------|----------|
| R-10 | MASVS-RESILIENCE-2 | Generare release keystore proprietario; rimuovere debug signing dalla release build | **BLOCCANTE — non distribuire senza questa fix** |

### Sprint P-6 (Cloud sync)

| ID | Controllo | Azione | Note |
|----|-----------|--------|------|
| R-11 | MASVS-NETWORK-1 | Aggiungere `network_security_config.xml` con `cleartextTrafficPermitted="false"` | Quando si aggiunge `INTERNET` permission |
| R-12 | MASVS-PLATFORM-1 | OAuth callback via App Links verificati (Digital Asset Links) | Non URL scheme custom |
| R-13 | MASVS-AUTH-1 | Rivalutare autenticazione OAuth; token in secure storage, non nel DB | Quando attivati `google_sign_in`/OAuth |

### Sprint P-7 (Polish + Release)

| ID | Controllo | Azione | Note |
|----|-----------|--------|------|
| R-14 | MASVS-RESILIENCE-1 | Play Integrity API (Android) + App Attest (iOS) | Warning non bloccante |
| R-15 | MASVS-RESILIENCE-3 | `flutter build --obfuscate --split-debug-info` + R8/ProGuard | Conforme con GPL-3.0 (sorgente rimane pubblico) |
| R-16 | MASVS-RESILIENCE-4 | Rivalutare anti-Frida nel contesto threat model v1.0 | Probabilmente solo rilevamento passivo |
| R-17 | MASVS-PRIVACY-3 | Verificare pubblicazione Privacy Policy su GitHub Pages | Pre-store submission |
| R-18 | MASVS-CODE-2 | Implementare Play Core In-App Update | Post-v1.0 launch |

---

## Cosa NON è stato analizzato a questo livello L2

- **Test dinamici** (Frida, Objection, MobSF): richiedono device fisico. I gap di CRYPTO-2 (key in memoria) e RESILIENCE-1/2/3 richiedono validazione dinamica.
- **Analisi CVE dipendenze**: `flutter pub audit` non eseguito in questa sessione — è a sua volta un L2 FAIL (R-04).
- **Swift nativo in `ios/Runner/`**: solo boilerplate `AppDelegate.swift`. La protezione file iOS (`NSFileProtectionComplete`) richiede method channel non presente — gap documentato in STORAGE-1.
- **Pipeline CI/CD**: i workflow GitHub Actions non esistono nel repository. I requisiti CODE-3 (dep scan) e le build release sono prerequisiti bloccanti.
- **Schermate UI F-01/F-08**: non ancora implementate — PLATFORM-3, CODE-4, AUTH-3 saranno rivalutati quando disponibili.
- **Performance Argon2id su device low-end**: i parametri (memory=64MB, iter=3) devono essere testati su hardware entry-level Android (Snapdragon 400-series, 2GB RAM) prima della release.
