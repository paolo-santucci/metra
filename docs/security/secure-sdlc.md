# Secure SDLC — Métra

**Versione:** 1.0
**Data:** 2026-04-28
**Riferimento:** OWASP MASVS L1+L2, CLAUDE.md §11, §14

---

## 1. Protezione del branch principale

### Regole GitHub branch protection per `main`

Le seguenti regole devono essere configurate in **Settings → Branches → Branch protection rules** per il pattern `main`:

- `Require a pull request before merging` — abilitato, nessun direct push.
- `Required approving reviews: 1` — soglia minima. Nota: il progetto è attualmente sviluppato da un singolo maintainer (Paolo Santucci); la review può essere effettuata da un co-maintainer o richiesta esplicitamente prima di merge su path critici.
- `Dismiss stale pull request approvals when new commits are pushed` — abilitato.
- `Require status checks to pass before merging` — abilitato. Status check richiesti (da aggiungere man mano che i workflow CI sono creati):
  - `quality` (format + analyze + coverage)
  - `android-test` (build + test APK)
  - `security-scan` (secret scan, dependency review)
- `Require branches to be up to date before merging` — abilitato.
- `Do not allow bypassing the above settings` — abilitato, incluso per amministratori.
- `Require signed commits` — abilitato per raggiungere SLSA Livello 2+.

### CODEOWNERS

Creare il file `.github/CODEOWNERS` con la seguente configurazione per richiedere review esplicita sui path critici di sicurezza:

```
# File di sicurezza critica — require security review
lib/data/services/encryption_service.dart    @paolosantucci
lib/data/services/key_management_service.dart @paolosantucci
lib/data/database/app_database.dart          @paolosantucci
lib/core/errors/                             @paolosantucci
lib/providers/database_provider.dart         @paolosantucci
lib/providers/encryption_provider.dart       @paolosantucci

# Dipendenze e configurazione
pubspec.yaml                                 @paolosantucci
pubspec.lock                                 @paolosantucci
```

In un team multi-persona, sostituire `@paolosantucci` con il handle del security reviewer designato o con un team GitHub (`@org/security-reviewers`).

---

## 2. Checklist di review PR per path sensibili

Questa checklist è vincolante per ogni PR che tocca i file listati in CODEOWNERS o i path `lib/data/`, `lib/domain/`, `lib/core/errors/`.

Il reviewer deve verificare ogni punto prima di approvare. Una risposta "non applicabile" deve essere giustificata nel commento.

### 2.1 Crittografia e gestione chiavi

- [ ] Nessuna chiave, passphrase, o secret hardcoded nel codice o nei test. I test usano valori casuali generati a runtime, non costanti fisse.
- [ ] `flutter_secure_storage` è configurato con opzioni esplicite (vedi GAP-01 in `threat-model.md`): `IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device)` e `AndroidOptions(encryptedSharedPreferences: true)`.
- [ ] Qualsiasi modifica a `EncryptionService` è accompagnata da un test di round-trip (encrypt → decrypt) e da un test che verifica che due cifrature dello stesso plaintext con la stessa passphrase producano ciphertext diversi (salt/IV distinti).
- [ ] Il controllo `cipher_version` in `AppDatabase.openConnection()` (`app_database.dart:164–171`) non è stato rimosso né bypassato.
- [ ] La chiave hex non appare in nessun log, commento, o stringa di debug. Cercare occorrenze di `hexKey` o `_dbKeyStorageKey` in contesti di logging.

### 2.2 Logging e redaction

- [ ] Nessun `print()` o `debugPrint()` che esponga campi di `DailyLog`, `PainSymptom`, o valori `notes`. Qualsiasi log deve passare attraverso il wrapper redaction (quando implementato, vedi GAP-02).
- [ ] Le eccezioni catturate e riportate all'utente non includono stack trace grezzi con dati personali.
- [ ] Nessuna dipendenza da servizi di crash reporting di terze parti è stata introdotta (anti-pattern esplicito per Métra — CLAUDE.md §11).

### 2.3 Layer e dipendenze architetturali

- [ ] I layer rispettano la direzione `UI → Domain → Data` (CLAUDE.md §4). Nessun import da `lib/data/database/` o `lib/data/services/` direttamente da `lib/features/`.
- [ ] `lib/domain/` non importa da `lib/data/` o `lib/features/`.
- [ ] Qualsiasi nuova dipendenza in `pubspec.yaml` ha superato il processo descritto in `dependency-policy.md`. Il numero di dipendenze non è aumentato senza giustificazione documentata nella PR.
- [ ] `pubspec.lock` è aggiornato e committato insieme a `pubspec.yaml`.

### 2.4 Null safety e gestione degli errori

- [ ] Nessun uso di `!` (force-unwrap) senza un commento che spieghi perché è sicuro in quel contesto (CLAUDE.md §12).
- [ ] Gli errori di sicurezza usano i tipi sealed di `MetraException` (`lib/core/errors/metra_exception.dart`): `StorageException`, `EncryptionException`, `CryptoException`. Nessun `throw Exception('...')` generico su path critici.
- [ ] Le eccezioni di `flutter_secure_storage` sono gestite esplicitamente (non assorbite con `catch(e) {}`).

### 2.5 Drift ORM e accesso DB

- [ ] Nessuna query SQL raw (`customStatement`, `execute` con interpolazione di stringa) su dati non validati.
- [ ] Ogni nuovo DAO include test unitari con DB in-memory.
- [ ] `PRAGMA foreign_keys = ON` non è stato rimosso da `openConnection`.

### 2.6 Accessibilità e privacy UI

- [ ] Le schermate che mostrano `notes` o dati di flusso implementano `FLAG_SECURE` / `blurImage` (quando GAP-04 sarà risolto). Fino ad allora, la PR deve documentare esplicitamente che questo gap rimane aperto.
- [ ] Nessun dato sanitario è visibile nel recente/switcher di app (app background screenshot).

---

## 3. Policy supply chain

### 3.1 Criteri per l'aggiunta di nuove dipendenze

Prima di aggiungere qualsiasi pacchetto a `pubspec.yaml`, il richiedente deve verificare tutti i criteri seguenti e documentarli nel messaggio di commit o nella descrizione della PR:

**Criteri obbligatori:**

1. **Punteggio pub.dev** ≥ 130/160 (Pub Points). Eccezioni solo per pacchetti Flutter SDK o Dart team.
2. **Publisher verificato** su pub.dev (`verified publisher` badge), o pacchetto pubblicato da `flutter.dev`, `dart.dev`, o `google.dev`.
3. **Ultima release** negli ultimi 12 mesi (pacchetti abbandonati introducono debt di sicurezza non gestibile).
4. **Manutenzione attiva**: almeno 2 maintainer, oppure pacchetto di proprietà di Flutter/Dart/Google team.
5. **Licenza compatibile** con GPL-3.0 — vedere `dependency-policy.md` per l'elenco SPDX approvato. Eseguire `dart pub deps` e verificare tutte le dipendenze transitive.
6. **`pubspec.lock` committato** dopo ogni aggiunta: il lock file è la fonte di verità per build riproducibili.
7. **Alternativa esistente verificata**: documentare perché non è possibile soddisfare il requisito con le dipendenze già presenti in `pubspec.yaml` (CLAUDE.md §17 punto 6).

**Criteri per `dev_dependencies`** (meno stringenti):

- Criteri 1–4 si applicano.
- Licenza: MIT, Apache-2.0, BSD-2/3-Clause accettati anche per dev-only.
- Non devono introdurre dipendenze runtime transitive non dichiarate.

### 3.2 Revisione periodica delle dipendenze

- **Frequenza**: settimanale, ogni lunedì.
- **Strumenti**: `dart pub outdated` per versioni deprecate; `dart pub deps` per grafo completo.
- **CVE scanning**: quando disponibile, GitHub Dependency Review Action sul workflow `security-scan.yml` (da creare). In alternativa, consultare manualmente l'advisory database di pub.dev.
- **Azione**: ogni dipendenza con vulnerabilità nota deve seguire le SLA definite in `dependency-policy.md`.

### 3.3 Gestione di `pubspec.lock`

`pubspec.lock` deve essere committato in ogni PR che modifica `pubspec.yaml`. Non accettare PR che aggiornano `pubspec.yaml` senza aggiornare il lock file. Questo garantisce build riproducibili e rende visibile nella diff ogni cambio di versione transitiva.

---

## 4. Gate di sicurezza CI/CD

**Nota:** I workflow GitHub Actions sono pianificati e non ancora presenti nel repository. Le specifiche seguenti descrivono i gate da implementare, non quelli esistenti.

### 4.1 Workflow `quality.yml` (ogni push e ogni PR)

```yaml
# Gate da implementare in .github/workflows/quality.yml
steps:
  - name: Format check
    run: dart format --set-exit-if-changed .

  - name: Static analysis
    run: flutter analyze --fatal-infos

  - name: Tests + coverage
    run: flutter test --coverage
    # Coverage minima: 80% su lib/data/services/ e lib/domain/

  - name: Dependency check
    run: dart pub outdated --no-dev-dependencies
```

### 4.2 Workflow `android.yml` (ogni push, ogni PR)

```yaml
# Gate da implementare in .github/workflows/android.yml
steps:
  - name: Build APK (debug)
    run: flutter build apk --debug

  - name: Run integration tests
    # Test su emulatore Android: DB cifrato, ciclo vita chiave
```

### 4.3 Workflow `security-scan.yml` (ogni PR, ogni push a main)

```yaml
# Gate da implementare in .github/workflows/security-scan.yml
steps:
  - name: Secret scanning
    uses: gitleaks/gitleaks-action@v2
    # Configurazione: blocca su leak di chiavi, token, pattern hex a 64 char

  - name: Dependency review
    uses: actions/dependency-review-action@v4
    with:
      fail-on-severity: high
      license-check: true
      allow-licenses: MIT, Apache-2.0, BSD-2-Clause, BSD-3-Clause, ISC, GPL-3.0-only, GPL-3.0-or-later, LGPL-2.1-or-later, LGPL-3.0-only, LGPL-3.0-or-later, MPL-2.0, PSF-2.0, Unlicense, CC0-1.0

  - name: SBOM generation
    uses: anchore/sbom-action@v0
    with:
      format: cyclonedx-json
      output-file: sbom.json
```

### 4.4 Workflow `ios.yml` (tag `v*`, su macOS runner)

```yaml
# Gate da implementare in .github/workflows/ios.yml
steps:
  - name: Build IPA
    run: flutter build ipa --release

  - name: Upload TestFlight
    # Richiede certificati Apple in GitHub Secrets (encrypted)
    # Chiavi non hardcoded — usare environment secrets
```

### 4.5 Gate bloccanti vs. informativi

| Gate | Tipo | Comportamento |
|---|---|---|
| `dart format` | Bloccante | Fail se codice non formattato |
| `flutter analyze` | Bloccante | Fail su errori e warning (--fatal-infos) |
| Copertura test < 80% su path critici | Bloccante | Fail |
| Secret scan (gitleaks) | Bloccante | Fail su qualsiasi secret rilevato |
| Dipendenza con CVE Critical/High | Bloccante | Fail |
| Licenza incompatibile | Bloccante | Fail |
| SBOM generation | Informativo | Non bloccante, artefatto salvato |

---

## 5. Incident response

### 5.1 Classificazione e SLA di risposta

| Severità | Criteri | SLA notifica | SLA patch | SLA comunicazione pubblica |
|---|---|---|---|---|
| **Critical** | Perdita di dati utente, accesso non autorizzato a DB/chiavi, distribuzione di binari compromessi | Immediata (entro 1 ora da rilevazione) | < 30 giorni | Entro 72 ore dalla conferma |
| **High** | Vulnerabilità sfruttabile con accesso fisico al dispositivo, bypass di controlli di autenticazione | Entro 24 ore | < 90 giorni | Entro 7 giorni dalla conferma |
| **Medium** | Vulnerabilità che richiede condizioni particolari o accesso privilegiato | Entro 72 ore | < 180 giorni | Alla release di fix |
| **Low** | Hardening incrementale, best practice non rispettate senza impatto diretto | Alla prossima release pianificata | Pianificato | N/A |

### 5.2 Processo di risposta

**Fase 1 — Rilevazione e triage (0–24 ore):**
1. Aprire un issue GitHub privato (o GitHub Security Advisory se il repo è pubblico) con label `security`.
2. Classificare la severità secondo la tabella §5.1.
3. Determinare se la vulnerabilità è già sfruttabile nelle versioni rilasciate su TestFlight/store.

**Fase 2 — Containment (24–72 ore per Critical/High):**
1. Se la vulnerabilità è in una release distribuita: valutare kill switch (forza aggiornamento) o rimozione dall'app store.
2. Creare branch `hotfix/sec-<id>` da `main`.
3. Non discutere dettagli tecnici della vulnerabilità in canali pubblici prima della patch.

**Fase 3 — Fix e verifica:**
1. Implementare la patch sul branch hotfix.
2. La PR di fix richiede review (anche su progetto solo — revisione personale documentata).
3. Eseguire tutti i gate CI incluso security-scan.
4. Aggiornare `threat-model.md` per riflettere il controllo aggiunto o il gap chiuso.

**Fase 4 — Release e comunicazione:**
1. Tag `v<semver>` sulla release di fix.
2. `CHANGELOG.md` con entry nel formato: `Security: [CWE-XXX] Descrizione della vulnerabilità e della fix.`
3. GitHub Security Advisory pubblicato (se applicabile).
4. Aggiornare la Privacy Policy su GitHub Pages se il bug ha impatto sulla gestione dei dati.

**Fase 5 — Post-mortem:**
1. Post-mortem blameless entro 7 giorni dalla fix.
2. Aggiornare checklist di review PR (§2) se il bug sarebbe stato rilevabile in review.
3. Aggiornare o aggiungere test di regressione.

### 5.3 Canale di segnalazione vulnerabilità

Configurare `SECURITY.md` nella root del repository con:
- Indirizzo email per responsible disclosure (es. `security@paolosantucci.com`).
- Indicazione di usare GitHub Private Security Advisory per segnalazioni strutturate.
- Impegno a rispondere entro 5 giorni lavorativi.
- Policy di no-public-disclosure prima della patch (coordinated disclosure).
