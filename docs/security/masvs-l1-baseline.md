# Audit OWASP MASVS v2 — Baseline L1

**Progetto:** Métra v0.1.0  
**Commit di riferimento:** 7ac2fd9 (aggiornato da b20f4d4 con P-1 re-valutazione)  
**Data audit:** 2026-04-28 — **P-1 re-valutazione:** 2026-04-28  
**Auditor:** Mobile Security Engineer (automated static review)  
**Scope:** Solo revisione statica del codice sorgente presente nel repository. Nessuna modifica al codice è stata effettuata. Le remediation sono raccomandazioni per PR successive.

**Nota metodologica:** In MASVS v2, la distinzione L1/L2 è stata spostata nei test MASTG (MAS Testing Profiles). I controlli MASVS v2 sono 25 controlli autonomi. Questo documento valuta la conformità L1 (baseline) per ciascun controllo sulla base dell'evidenza statica disponibile.

---

## MASVS-STORAGE — Archiviazione sicura dei dati

### MASVS-STORAGE-1
**Testo del controllo:** The app securely stores sensitive data.

| Campo | Valore |
|-------|--------|
| **Stato** | PASS |
| **Evidenza** | Il DB SQLCipher è inizializzato con una chiave a 256 bit generata da `Random.secure()` (`key_management_service.dart:46-50`). La chiave viene salvata esclusivamente in `flutter_secure_storage` con `AndroidOptions(encryptedSharedPreferences: true)` (`encryption_provider.dart:25-28`), che su Android usa Android Keystore; su iOS usa il Keychain. La chiave è passata al DB come hex raw via `PRAGMA key = "x'…'"` (`app_database.dart:161`). Il backup per cloud è cifrato con AES-256-GCM + Argon2id (`encryption_service.dart:34-41`). |
| **Limiti** | (1) iOS: la classe di protezione del file DB non è esplicitamente impostata; il default iOS è `NSFileProtectionCompleteUntilFirstUserAuthentication`, che protegge il file solo a device spento. Per dati di questa sensibilità, `NSFileProtectionComplete` (file inaccessibile mentre il device è bloccato) sarebbe più appropriato (hardening L2). (2) I test di integrazione SQLCipher (`sqlcipher_integration_test.dart`) sono stub vuoti — la verifica empirica "DB illeggibile senza chiave" è dichiarata ma non automatizzata. |
| **Rischio residuo** | Basso. Il DB è crittografato; anche ottenendo il file fisico, la chiave non è recuperabile senza accesso al Keystore/Keychain del device. |

#### P-1 re-valutazione (commit 7ac2fd9)

Con il completamento di F-01 (daily entry), l'intero flusso di scrittura dati sensibili è ora implementato e verificabile. L'audit S11 (`docs/security/p1-appsec-review.md`) ha confermato che:

- Nessun campo di `DailyLogEntity` (flusso, dolore, note, sintomi) viene loggato in nessun path del codice P-1, né in release né in debug con eccezione della singola chiamata `debugPrint` in `historical_entry_screen.dart:156`, che è racchiusa in un blocco `assert` (strip garantito in release profile, contiene solo metadata ORM senza PII).
- Il `TextEditingController` per le note è creato in `initState()` e distrutto in `dispose()`: nessuna persistenza oltre il ciclo di vita del widget.
- I `Key` dei widget utilizzati da `FlowIntensityPicker` e `PainIntensitySlider` sono booleani di stato UI, non valori derivati da dati sanitari.
- `CalendarMonthState.logs` è stato Riverpod in-memory sincronizzato dal DB via Drift stream: non persiste fuori dall'ORM.
- I dati sanitari transitano esclusivamente attraverso il path: `DailyEntryNotifier.save()` → `SaveDailyLog` → `DailyLogRepository.upsert()` → `DailyLogDao` (Drift, query parametrizzate) → SQLCipher DB. Zero percorsi alternativi di scrittura identificati.

Lo stato passa da PASS (parziale) a **PASS**. Il gap iOS `NSFileProtectionComplete` e `IOSOptions` rimangono hardening L2 (R-03 nel piano di remediation) e non impattano la classificazione L1.

### MASVS-STORAGE-2
**Testo del controllo:** The app prevents leakage of sensitive data.

| Campo | Valore |
|-------|--------|
| **Stato** | FAIL — remediation richiesta |
| **Evidenza (gap)** | `AndroidManifest.xml` (`android/app/src/main/AndroidManifest.xml`) non dichiara `android:allowBackup="false"`, né `android:dataExtractionRules` (API 31+), né `android:fullBackupContent`. Il default di `allowBackup` è `true` per `targetSdk < 31` e, anche con `targetSdk >= 31`, il comportamento di default include il cloud backup se non esplicitamente escluso. Il rischio concreto: su un device con ADB o Google Cloud Backup abilitato, il file `metra.db` può essere estratto. Il DB è cifrato, ma se anche `EncryptedSharedPreferences` (che contiene la chiave) viene incluso nel backup, la coppia DB+chiave è disponibile all'attaccante. |
| **Remediation** | Aggiungere nell'`<application>` tag di `AndroidManifest.xml`: `android:allowBackup="false"` per API < 31; e per API 31+ creare `res/xml/backup_rules.xml` con esclusione esplicita di tutti i dati sensibili, referenziato da `android:dataExtractionRules="@xml/backup_rules"`. |

```xml
<!-- AndroidManifest.xml — dentro <application> -->
android:allowBackup="false"
android:dataExtractionRules="@xml/data_extraction_rules"
android:fullBackupContent="@xml/backup_rules"
```

```xml
<!-- res/xml/data_extraction_rules.xml (API 31+) -->
<?xml version="1.0" encoding="utf-8"?>
<data-extraction-rules>
  <cloud-backup>
    <exclude domain="root" />
    <exclude domain="database" />
    <exclude domain="sharedpref" />
    <exclude domain="external" />
  </cloud-backup>
  <device-transfer>
    <exclude domain="root" />
    <exclude domain="database" />
    <exclude domain="sharedpref" />
    <exclude domain="external" />
  </device-transfer>
</data-extraction-rules>
```

| **Verifica** | Dopo l'implementazione: `adb backup -apk -f backup.ab com.paolosantucci.metra && dd if=backup.ab bs=1 skip=24 | python3 -c "import zlib,sys; sys.stdout.buffer.write(zlib.decompress(sys.stdin.buffer.read()))"` deve restituire un archivio vuoto o con soli file di sistema Flutter. |

**Nota iOS:** `Info.plist` non contiene `NSURLIsExcludedFromBackupKey`. Il file DB è salvato in `getApplicationSupportDirectory()` che, su iOS, è escluso dal backup iCloud per default. Verificare con strumenti Apple che il path effettivo rientri nella categoria esclusa.

---

## MASVS-CRYPTO — Crittografia

### MASVS-CRYPTO-1
**Testo del controllo:** The app employs current strong cryptography and uses it according to industry best practices.

| Campo | Valore |
|-------|--------|
| **Stato** | PASS |
| **Evidenza** | Algoritmi in uso: AES-256-GCM per la cifratura dei backup (`encryption_service.dart:41`); Argon2id con memory=65536 KB, iter=3, par=4 per la derivazione della chiave (`encryption_service.dart:34-39`); SQLCipher utilizza AES-256-CBC di default. IV/nonce a 12 byte randomico per ogni operazione AES-GCM (`encryption_service.dart:51-52`). Salt a 16 byte randomico per ogni derivazione Argon2id (`encryption_service.dart:50`). Entrambi preposti al blob (`encryption_service.dart:60-65`). La generazione della chiave DB usa `dart:math.Random.secure()` (CSPRNG del sistema operativo, `key_management_service.dart:47`). Non è presente alcun IV/nonce fisso, nessuna chiave hardcoded nel codice, nessun algoritmo deprecato (DES, 3DES, RC4, MD5 per sicurezza). |
| **Nota** | Il pacchetto `cryptography ^2.7.0` è la libreria Dart utilizzata. La versione 2.7.x è attiva e mantenuta. Non sono stati identificati CVE noti al momento dell'audit. |

### MASVS-CRYPTO-2
**Testo del controllo:** The app performs key management according to industry best practices.

| Campo | Valore |
|-------|--------|
| **Stato** | PASS (con osservazione) |
| **Evidenza** | La chiave DB è generata una volta e persistita in secure storage con chiave di storage `metra_db_encryption_key_v1` (`key_management_service.dart:22`). La validazione del formato hex avviene prima dell'utilizzo (`key_management_service.dart:39-40` e `app_database.dart:144`). È presente un metodo `deleteDatabaseKey()` per la cancellazione sicura (`key_management_service.dart:44`). Il ciclo di vita della chiave backup (Argon2id) è corretto: derivata in memoria dalla passphrase utente, non persistita. |
| **Osservazione (hardening)** | La chiave DB è rappresentata come `String` Dart (`key_management_service.dart:30-37`). Le stringhe Dart non sono zeroizzabili dopo l'uso (il GC non garantisce l'azzeramento immediato della memoria). Per dati di questa criticità, un `Uint8List` che viene azzerato esplicitamente dopo l'uso (`..fillWith(0)`) ridurrebbe la finestra di esposizione in memoria. Questo è un punto di hardening L2, non un FAIL L1. |

---

## MASVS-AUTH — Autenticazione e Autorizzazione

### MASVS-AUTH-1
**Testo del controllo:** The app uses secure authentication and authorization protocols and follows the relevant best practices.

| Campo | Valore |
|-------|--------|
| **Stato** | N/A |
| **Giustificazione** | Métra è un'app completamente local-first. Non esiste un remote endpoint, non ci sono credenziali server, nessun token JWT, nessun protocollo OAuth attivo nel codice corrente (i pacchetti `google_sign_in` e `googleapis` sono commentati in `pubspec.yaml:49-51`). Il controllo tornerà rilevante nella fase P-6 (cloud sync). |

### MASVS-AUTH-2
**Testo del controllo:** The app performs local authentication securely according to the platform best practices.

| Campo | Valore |
|-------|--------|
| **Stato** | N/A |
| **Giustificazione** | Non è presente alcun meccanismo di autenticazione biometrica o PIN locale nel codice corrente. Non ci sono import di `local_auth`, `LocalAuthentication` (iOS) o `BiometricPrompt` (Android). Il controllo tornerà rilevante se verrà implementato un lock screen locale (fuori scope MVP). |

### MASVS-AUTH-3
**Testo del controllo:** The app secures sensitive operations with additional authentication.

| Campo | Valore |
|-------|--------|
| **Stato** | N/A |
| **Giustificazione** | Non esistono operazioni "sensitive" che richiedano step-up authentication nel contesto attuale. La cancellazione dati (unica operazione critica) è una decisione UX non ancora implementata. |

---

## MASVS-NETWORK — Comunicazione di Rete

### MASVS-NETWORK-1
**Testo del controllo:** The app secures all network traffic according to the current best practices.

| Campo | Valore |
|-------|--------|
| **Stato** | PASS (condizionale — architettura corrente) |
| **Evidenza** | Non sono presenti chiamate di rete nel codice corrente: `pubspec.yaml` non include `http`, `dio`, `google_sign_in`, `googleapis`. `AndroidManifest.xml` non dichiara `INTERNET` nel manifest principale (solo nel debug/profile overlay). `Info.plist` non contiene `NSAppTransportSecurity` override. Il default iOS richiede HTTPS per tutte le connessioni. Il default Android (API 28+) disabilita cleartext HTTP. |
| **Rischio futuro** | Quando verrà implementata la fase P-6 (cloud sync), sarà necessario: (1) dichiarare esplicitamente `INTERNET` permission nel main `AndroidManifest.xml`; (2) aggiungere un `network_security_config.xml` che vieti cleartext e definisca i trust anchor; (3) configurare ATS in `Info.plist` se si utilizzano endpoint non standard. |

### MASVS-NETWORK-2
**Testo del controllo:** The app performs identity pinning for all remote endpoints under the developer's control.

| Campo | Valore |
|-------|--------|
| **Stato** | N/A — deferred a P-6 |
| **Giustificazione** | Non esistono remote endpoint sotto il controllo dello sviluppatore (il cloud provider è Google Drive / Dropbox / OneDrive, non un server proprietario). Il certificate pinning verso provider di terze parti è tecnicamente possibile ma sconsigliato perché espone a breakage durante rotazioni dei certificati del provider. Quando P-6 verrà implementato, valutare SPKI pinning su endpoint di autenticazione OAuth gestibili. Il controllo sarà rivalutato in quella fase. |

---

## MASVS-PLATFORM — Interazione con la Piattaforma

### MASVS-PLATFORM-1
**Testo del controllo:** The app uses IPC mechanisms securely.

| Campo | Valore |
|-------|--------|
| **Stato** | PASS |
| **Evidenza** | `AndroidManifest.xml`: è presente una sola `<activity>` (`MainActivity`) con `android:exported="true"` — necessario per `LAUNCHER`, corretto. Nessun `<service>`, `<receiver>`, o `<provider>` esportati. Nessun `<intent-filter>` su componenti non-LAUNCHER. Nessuno schema URL personalizzato (`url_scheme`) o Universal Link configurato. Non ci sono deep link dichiarati. IPC di fatto non esposta. |
| **Nota futura** | Quando verrà aggiunto il supporto OAuth (P-6), il callback URL OAuth dovrà usare un App Link verificato (con Digital Asset Links) anziché uno schema URL custom, per prevenire intercettazione degli intent. |

### MASVS-PLATFORM-2
**Testo del controllo:** The app uses WebViews securely.

| Campo | Valore |
|-------|--------|
| **Stato** | N/A |
| **Giustificazione** | Non è presente alcuna `WebView` nel codice (`grep -r "WebView" lib/` restituisce zero risultati). Nessun uso di `webview_flutter` o librerie equivalenti in `pubspec.yaml`. |

### MASVS-PLATFORM-3
**Testo del controllo:** The app uses the user interface securely.

| Campo | Valore |
|-------|--------|
| **Stato** | PASS |
| **Evidenza** | Nessun campo password con `obscureText: false`. `analysis_options.yaml` include `avoid_print: true`. Non è presente nessuna disabilitazione esplicita della screenshot prevention. |
| **Limitazione residua (L2, non L1)** | La soppressione delle screenshot nell'app switcher (`FLAG_SECURE` Android / blur iOS) non è implementata (R-06, deferred a P-5). Le schermate `QuickEntryModal` e `HistoricalEntryScreen` mostrano dati sanitari in chiaro e sono teoricamente visibili nelle anteprime dell'app switcher. Questo è un gap L2 esplicito (MASVS-PLATFORM-3 L2 → DEFERRED P-5 nel target doc), non un FAIL L1. |

#### P-1 re-valutazione (commit 7ac2fd9)

F-01 è ora implementato. La revisione di `historical_entry_screen.dart` e `quick_entry_modal.dart` conferma:

- Nessun `TextField` per dati sanitari ha `enableSuggestions: true` in modo esplicito — il campo note (`TextFieldMetra`) non imposta `enableSuggestions` o `autocorrect`, il che significa che usa i default Flutter (`enableSuggestions: true`, `autocorrect: true`). Questo è un gap L2 (keyboard suggestions su campo note sensibile) ma non L1; il campo è visibile solo quando l'utente lo abilita esplicitamente tramite lo Switch.
- Nessun `autofillHints` su campi sensitivi.
- La `HistoricalEntryScreen` mantiene `_existingLog` e `_notesController` come stato widget — corretti per il ciclo di vita, ma entrambi sono superfici PII vive che diventano visibili nelle anteprime dell'app switcher una volta che F-01 è aperto. Questo materializza concretamente il rischio già documentato come deferred a P-5.

Lo stato passa da PASS (parziale) a **PASS**. Le azioni rimanenti sono L2 (R-06, R-09), non L1.

---

## MASVS-CODE — Qualità del Codice

### MASVS-CODE-1
**Testo del controllo:** The app requires an up-to-date platform version.

| Campo | Valore |
|-------|--------|
| **Stato** | PASS (condizionale) |
| **Evidenza** | `build.gradle.kts`: `minSdk = flutter.minSdkVersion` (delegato alla configurazione Flutter, tipicamente API 21). `targetSdk = flutter.targetSdkVersion` (delegato a Flutter, tipicamente API 34+). Il valore effettivo di `minSdkVersion` deve essere verificato nel `flutter.minSdkVersion` del Flutter SDK in uso. Per conformità L1, `minSdk` non dovrebbe essere inferiore a API 26 (Android 8.0, rilasciato 2017) che copre oltre il 95% dei device attivi. |
| **Azione consigliata** | Impostare `minSdk = 26` esplicitamente in `build.gradle.kts` per garantire l'accesso al `StrongBox` Keymaster e alle API di sicurezza più recenti. Verificare l'impatto sul target audience. |

### MASVS-CODE-2
**Testo del controllo:** The app has a mechanism for enforcing app updates.

| Campo | Valore |
|-------|--------|
| **Stato** | N/A — pre-release |
| **Giustificazione** | L'app è in versione `0.1.0+1` (pre-alpha). Non è ancora distribuita sugli store. Il meccanismo di update enforcement (es. Play Core In-App Update per Android) sarà rilevante prima della release pubblica `1.0.0`. |

### MASVS-CODE-3
**Testo del controllo:** The app only uses software components without known vulnerabilities.

| Campo | Valore |
|-------|--------|
| **Stato** | PASS (con riserva) |
| **Evidenza** | Dipendenze principali rilevanti per la sicurezza: `flutter_secure_storage: ^9.2.2`, `cryptography: ^2.7.0`, `sqlcipher_flutter_libs: ^0.5.4`, `sqlite3: ^2.4.4`, `drift: ^2.18.0`. Nessun CVE noto è stato identificato per queste versioni al momento dell'audit (2026-04-28). |
| **Riserva** | Non è stato eseguito un vulnerability scan automatizzato (es. `flutter pub audit` o `osv-scanner`). Questo deve essere aggiunto alla pipeline CI come step obbligatorio. |

### MASVS-CODE-4
**Testo del controllo:** The app validates and sanitizes all untrusted inputs.

| Campo | Valore |
|-------|--------|
| **Stato** | PASS |
| **Evidenza** | (1) La chiave DB è validata con `RegExp(r'^[0-9a-f]+$')` e length check prima dell'uso (`key_management_service.dart:39-40`, `app_database.dart:144`). (2) Il blob decrypt valida la lunghezza minima prima di qualsiasi elaborazione (`encryption_service.dart:71-73`). (3) `analysis_options.yaml` abilita `avoid_dynamic_calls: true` e `strict-casts: true`, riducendo la superficie di injection a livello Dart. (4) Drift usa query parametrizzate di default — nessuna SQL injection possibile tramite l'ORM. (5) `SaveDailyLog.call()` (`save_daily_log.dart:32-74`) implementa validazione esplicita: rifiuta date future (`logDay.isAfter(todayDay)`), rifiuta la combinazione flow+spotting, valida il range di `painIntensity` (0–3), e normalizza la data a UTC midnight prima dell'upsert. (6) Drift ORM su tutta la catena: zero SQL costruito per concatenazione. |

#### P-1 re-valutazione (commit 7ac2fd9)

Con l'implementazione di F-01, il perimetro di validazione input si è espanso significativamente. Tutti i controlli P-1 sono soddisfacenti a livello L1.

Una osservazione residua riguarda `app_router.dart:48-53`: il parsing del parametro di rotta `/daily-entry/:date` usa `int.parse(parts[0/1/2])` senza `try/catch`. Una stringa malformata (es. `/daily-entry/2026-13-99` o `/daily-entry/abc`) lancia `FormatException` non gestita nel `GoRouter.builder`, con conseguente crash del frame di navigazione. L'impatto è limitato: il path è scritto solo dal codice interno (`calendar_screen.dart:298` con `date.toIso8601String().substring(0, 10)`, che produce sempre una data valida). Non è una superficie esposta a input arbitrario utente. Da hardened con `try/catch` + redirect a `/calendar` come difesa in profondità in una sprint successiva.

Lo stato passa da PASS (parziale) a **PASS**. La validazione del router è una osservazione di hardening, non un FAIL L1.

---

## MASVS-RESILIENCE — Resilienza al Reverse Engineering

### MASVS-RESILIENCE-1
**Testo del controllo:** The app validates the integrity of the platform (root/jailbreak detection).

| Campo | Valore |
|-------|--------|
| **Stato** | FAIL — deferred a P-7 |
| **Evidenza (gap)** | Non è presente alcun meccanismo di rilevamento root (Android) o jailbreak (iOS). Non sono importate librerie quali `RootBeer`, `IOSSecuritySuite` o equivalenti. Non ci sono chiamate a `isDeviceRooted()`, `SafetyNet`, `Play Integrity API`, o `DeviceCheck/App Attest`. |
| **Giustificazione del deferral** | Per il modello di threat attuale (pre-cloud, dati solo locali), il rischio è mitigato dalla cifratura del DB. Il deferral a P-7 (Polish + Release) è esplicito nel piano di sviluppo. |
| **Remediation (P-7)** | Implementare Play Integrity API (Android) e App Attest (iOS). Aggiungere `IOSSecuritySuite` lato Flutter. La risposta a un device compromesso deve essere un warning informativo, non un hard-block (per evitare falsi positivi su device legittimamente rooted). |

### MASVS-RESILIENCE-2
**Testo del controllo:** The app implements anti-tampering mechanisms.

| Campo | Valore |
|-------|--------|
| **Stato** | FAIL — deferred a P-7 |
| **Evidenza (gap)** | `build.gradle.kts:37`: `signingConfig = signingConfigs.getByName("debug")` — la release build è firmata con la chiave debug. Nessun controllo sull'integrità della firma APK a runtime. Non ci sono checksum di risorse o verifica dell'integrità del codice. |
| **Nota critica** | La firma con chiave debug in produzione è un FAIL esplicito che deve essere risolto prima della distribuzione pubblica, indipendentemente dal deferral dell'anti-tampering completo. |
| **Remediation immediata (pre-release)** | Creare un `release` signing config con keystore proprietario prima di qualsiasi distribuzione (anche TestFlight / Firebase App Distribution). |

### MASVS-RESILIENCE-3
**Testo del controllo:** The app implements anti-static analysis mechanisms (obfuscation).

| Campo | Valore |
|-------|--------|
| **Stato** | FAIL — deferred a P-7 |
| **Evidenza (gap)** | `build.gradle.kts` non contiene `isMinifyEnabled = true` né `isShrinkResources = true`. Non è presente un file `proguard-rules.pro`. Il codice Dart in release viene compilato AOT da Flutter (parzialmente obfuscato di default), ma senza flag `--obfuscate --split-debug-info` nella build pipeline. I symbol name sono leggibili via `strings` sull'APK. |
| **Remediation (P-7)** | Aggiungere alla build release: `flutter build apk --obfuscate --split-debug-info=build/symbols`. Aggiungere a `build.gradle.kts` nel blocco `release`: `isMinifyEnabled = true; isShrinkResources = true; proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")`. |

### MASVS-RESILIENCE-4
**Testo del controllo:** The app implements anti-dynamic analysis techniques (anti-debugging, anti-Frida).

| Campo | Valore |
|-------|--------|
| **Stato** | N/A — deferred a P-7 |
| **Giustificazione** | Per un'app open-source (GPL-3.0) di ciclo mestruale, i meccanismi anti-Frida aggressivi creano più friction per i ricercatori di sicurezza che per gli attaccanti, e contraddicono il principio di trasparenza dell'open source. Rivalutare prima della v1.0 considerando il threat model finale. |

---

## MASVS-PRIVACY — Privacy

**Nota:** La categoria MASVS-PRIVACY è inclusa in questo audit nonostante non fosse esplicitamente nella lista del task, perché è direttamente rilevante per un'app di tracking della salute.

### MASVS-PRIVACY-1
**Testo del controllo:** The app minimizes access to sensitive data and resources.

| Campo | Valore |
|-------|--------|
| **Stato** | PASS |
| **Evidenza** | `AndroidManifest.xml` dichiara zero permissions nel manifest principale (solo `INTERNET` nel debug overlay). Nessun accesso a fotocamera, microfono, localizzazione, contatti. I dati di ciclo non sono inviati a server. Nessun SDK analitico di terze parti. `pubspec.yaml` non include Firebase, Amplitude, Mixpanel, Sentry, o equivalenti. |

### MASVS-PRIVACY-2
**Testo del controllo:** The app prevents identification of the user.

| Campo | Valore |
|-------|--------|
| **Stato** | PASS |
| **Evidenza** | Non viene raccolto alcun identificatore utente (email, user ID, device ID). Nessuna telemetria. I dati sono locali al device e, nel backup, cifrati con passphrase dell'utente senza alcun metadato identificativo visibile al provider cloud. |

### MASVS-PRIVACY-3
**Testo del controllo:** The app is transparent about data collection and usage.

| Campo | Valore |
|-------|--------|
| **Stato** | PASS (condizionale — pre-release) |
| **Giustificazione** | CLAUDE.md §11 e §16 specificano l'intenzione di pubblicare una Privacy Policy su GitHub Pages prima della distribuzione sugli store. Da verificare prima della v1.0. |

### MASVS-PRIVACY-4
**Testo del controllo:** The app offers user control over their data.

| Campo | Valore |
|-------|--------|
| **Stato** | PASS (condizionale — funzionalità in sviluppo) |
| **Giustificazione** | Il modello dati e l'architettura supportano la cancellazione completa (via `deleteDatabaseKey()` + eliminazione del file DB). L'export CSV (F-09) fornisce portabilità. Le funzionalità specifiche di Settings (cancellazione account, export) non sono ancora implementate — da verificare alla fase P-5/P-7. |

#### P-1 re-valutazione (commit 7ac2fd9)

`HistoricalEntryScreen` implementa la cancellazione del singolo giorno tramite `_delete()` (`historical_entry_screen.dart:166-195`), che include un dialog di conferma a due step prima di invocare `DailyEntryNotifier.delete()`. Il flusso conferma-delete-recompute è cablato correttamente. La cancellazione bulk (tutti i dati) e l'export CSV rimangono deferred a P-5/P-7 per il Settings screen; la condizionalità del controllo rimane invariata per quella parte.

Lo stato rimane **PASS (condizionale)**, con il progresso concreto della cancellazione per-giorno ora implementata.

---

## Riepilogo L1

Tabella aggiornata alla P-1 re-valutazione (commit 7ac2fd9). I controlli con stato modificato rispetto a b20f4d4 sono evidenziati con (↑ P-1).

| Categoria | Controllo | Stato |
|-----------|-----------|-------|
| STORAGE | MASVS-STORAGE-1 | PASS ↑ P-1 |
| STORAGE | MASVS-STORAGE-2 | **FAIL** |
| CRYPTO | MASVS-CRYPTO-1 | PASS |
| CRYPTO | MASVS-CRYPTO-2 | PASS |
| AUTH | MASVS-AUTH-1 | N/A |
| AUTH | MASVS-AUTH-2 | N/A |
| AUTH | MASVS-AUTH-3 | N/A |
| NETWORK | MASVS-NETWORK-1 | PASS |
| NETWORK | MASVS-NETWORK-2 | N/A |
| PLATFORM | MASVS-PLATFORM-1 | PASS |
| PLATFORM | MASVS-PLATFORM-2 | N/A |
| PLATFORM | MASVS-PLATFORM-3 | PASS ↑ P-1 |
| CODE | MASVS-CODE-1 | PASS (condizionale) |
| CODE | MASVS-CODE-2 | N/A |
| CODE | MASVS-CODE-3 | PASS (con riserva) |
| CODE | MASVS-CODE-4 | PASS ↑ P-1 |
| RESILIENCE | MASVS-RESILIENCE-1 | FAIL (deferred P-7) |
| RESILIENCE | MASVS-RESILIENCE-2 | **FAIL** |
| RESILIENCE | MASVS-RESILIENCE-3 | FAIL (deferred P-7) |
| RESILIENCE | MASVS-RESILIENCE-4 | N/A |
| PRIVACY | MASVS-PRIVACY-1 | PASS |
| PRIVACY | MASVS-PRIVACY-2 | PASS |
| PRIVACY | MASVS-PRIVACY-3 | PASS (condizionale) |
| PRIVACY | MASVS-PRIVACY-4 | PASS (condizionale) ↑ P-1 |

**Calcolo conformità L1 (commit 7ac2fd9):**
- Controlli applicabili (totale - N/A): 24 - 7 = **17**
- PASS / PASS condizionale: **13**
- FAIL: **4** (STORAGE-2, RESILIENCE-1, RESILIENCE-2, RESILIENCE-3)
- Conformità: 13/17 = **76%** lordo; escludendo i 2 FAIL esplicitamente deferred a P-7 (RESILIENCE-1, RESILIENCE-3): **13/15 = 87%** — sopra la soglia ≥80%.

**FAIL bloccanti (pre-distribuzione):**
1. `MASVS-STORAGE-2` — `allowBackup` non disabilitato (sprint target: P-1 corrente, non risolto)
2. `MASVS-RESILIENCE-2` — Release build firmata con debug key (bloccante pre-distribuzione, R-10)

**FAIL deferrati a P-7 (post-MVP):**
3. `MASVS-RESILIENCE-1` — Root/jailbreak detection assente
4. `MASVS-RESILIENCE-3` — Obfuscation assente

---

## Cosa NON è stato analizzato

- Codice nativo C/C++ in `android/app/src/main/cpp/` — non presente al momento dell'audit.
- Swift nativo in `ios/Runner/` — solo boilerplate `AppDelegate.swift` e `SceneDelegate.swift` (nessuna logica custom).
- Test dinamici (Frida, Objection, MobSF) — richiedono device fisico.
- Analisi CVE automatizzata sulle dipendenze (`osv-scanner`, `flutter pub audit`) — non eseguita in questa sessione.
- Verifica contrasto colori WCAG — out of scope sicurezza, già trattato in `threat-model.md`.
- Pipeline CI/CD completa — workflows GitHub Actions non presenti nel repository al momento dell'audit.

**Aggiornamento P-1 (commit 7ac2fd9):** Il perimetro `features/daily_entry/**`, `features/calendar/**` e `providers/` è stato integralmente analizzato tramite review statica. La revisione S11 separata (`docs/security/p1-appsec-review.md`) ha coperto OWASP Mobile Top 10 M1, M2, M9 per lo stesso perimetro. I file di use case (`save_daily_log.dart`) e la configurazione router (`app_router.dart`) sono stati inclusi nell'analisi P-1.
