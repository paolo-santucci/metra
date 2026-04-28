# Dependency Policy — Métra

**Versione:** 1.0
**Data:** 2026-04-28
**Riferimento:** CLAUDE.md §11, §17 punto 6; GPL-3.0 license compatibility matrix

---

## 1. License gate

Métra è distribuita sotto licenza **GPL-3.0-only**. Ogni dipendenza — sia runtime che transitiva — deve essere compatibile con GPL-3.0. L'incompatibilità di una singola dipendenza transitiva rende l'intera distribuzione non conforme.

### 1.1 Identificatori SPDX approvati

Le seguenti licenze sono **approvate** per dipendenze runtime (`dependencies` in `pubspec.yaml`):

| SPDX Identifier | Note |
|---|---|
| `MIT` | Approvato senza riserve. |
| `Apache-2.0` | Approvato per GPL-3.0 (compatibile con GPLv3, non con GPLv2-only). Verificare che la dipendenza non includa una patent retaliation clause incompatibile. |
| `BSD-2-Clause` | Approvato. |
| `BSD-3-Clause` | Approvato. |
| `ISC` | Approvato (equivalente funzionale a BSD-2-Clause). |
| `LGPL-2.1-or-later` | Approvato. |
| `LGPL-3.0-only` | Approvato. |
| `LGPL-3.0-or-later` | Approvato. |
| `MPL-2.0` | Approvato con riserva: la MPL-2.0 è compatibile con GPL-3.0 a livello di file (file-level copyleft). Le modifiche ai file MPL devono rimanere sotto MPL. |
| `GPL-3.0-only` | Approvato (stessa licenza). |
| `GPL-3.0-or-later` | Approvato. |
| `PSF-2.0` | Approvato (Python Software Foundation License). |
| `Unlicense` | Approvato (dominio pubblico). |
| `CC0-1.0` | Approvato per risorse non-codice (font, immagini). |

### 1.2 Identificatori SPDX non approvati

Le seguenti licenze sono **esplicitamente vietate**. Una PR che introduce anche indirettamente una dipendenza con queste licenze deve essere bloccata:

| SPDX Identifier | Motivo |
|---|---|
| `GPL-2.0-only` | Incompatibile con GPL-3.0 (clausola "version 2 only"). |
| `GPL-2.0-or-later` senza eccezione GPLv3 | Attenzione: "or later" include GPL-3, ma verificare la formulazione esatta del NOTICE. |
| `AGPL-3.0-only` | Tecnicamente compatibile, ma introduce obblighi di distribuzione del sorgente via rete che non si applicano a un'app mobile. Evitare per semplicità. |
| `EPL-1.0`, `EPL-2.0` | Eclipse Public License — non compatibile con GPL-3.0. |
| `CDDL-1.0` | Common Development and Distribution License — non compatibile. |
| `BUSL-1.1` | Business Source License — proprietaria. |
| `CC-BY-NC-*` | Clausola non-commercial incompatibile con distribuzione libera. |
| `Proprietary` / `Commercial` / `UNLICENSED` | Vietato. |
| Nessuna licenza dichiarata | Vietato. Trattare come "tutti i diritti riservati". |

### 1.3 Casi ambigui

- **Apache-2.0 con GPLv2-only**: incompatibile. Apache-2.0 è compatibile con GPL-3, non con GPL-2-only. Se una dipendenza dichiara `GPL-2.0-or-later AND Apache-2.0`, la combinazione è compatibile.
- **Dipendenze dual-licensed**: scegliere la licenza compatibile con GPL-3.0 e documentarla nel commento di `pubspec.yaml`.
- **Licenze custom**: richiedere parere legale prima di accettare. Non approvare in autonomia.

### 1.4 Verifica delle dipendenze transitive

`dart pub deps --style=compact` elenca il grafo completo. Prima di ogni nuova aggiunta, eseguire il comando e verificare che nessuna dipendenza transitiva nuova introduca una licenza non approvata. Il gate CI `dependency-review-action` (configurato in `security-scan.yml`) automatizza questa verifica sulle PR.

---

## 2. Criteri per aggiungere nuove dipendenze

### 2.1 Criteri obbligatori (tutti devono essere soddisfatti)

Prima di aprire una PR che aggiunge una dipendenza runtime, il richiedente deve documentare nel messaggio di commit o nella descrizione della PR la risposta a ciascun punto:

1. **Necessità:** qual è il requisito funzionale? Perché non può essere soddisfatto con le dipendenze già in `pubspec.yaml`? (CLAUDE.md §17 punto 6: "justify why it can't be done with existing ones")

2. **Pub Points ≥ 130/160:** verificare su pub.dev. Soglia derogabile solo per pacchetti Flutter SDK (`sdk: flutter`) o pacchetti Dart/Flutter team.

3. **Publisher verificato** (`verified publisher` badge) su pub.dev. Publisher accettati senza ulteriori verifiche: `flutter.dev`, `dart.dev`, `google.dev`, `material.io`. Per altri publisher: verificare la reputazione del maintainer.

4. **Ultima release entro 12 mesi:** un pacchetto senza release nell'ultimo anno è da considerare abbandonato. Verificare anche se esiste un fork mantenuto.

5. **Almeno 2 maintainer attivi** oppure pacchetto di proprietà di un team ufficiale Flutter/Dart/Google. Un pacchetto con singolo maintainer rappresenta un rischio di abbandono.

6. **Licenza approvata** (§1.1): verificare sia la licenza della dipendenza diretta sia delle sue dipendenze transitive nuove.

7. **Analisi della superficie di attacco:** la dipendenza accede a dati sanitari, storage sicuro, rete, o filesystem? In caso affermativo, è necessaria una review di sicurezza del codice sorgente della dipendenza prima dell'aggiunta.

8. **`pubspec.lock` aggiornato** e incluso nella PR.

### 2.2 Criteri per `dev_dependencies`

I criteri 1–5 si applicano. Il criterio 6 (licenza) è meno restrittivo: MIT, Apache-2.0, BSD-2/3-Clause sono accettati senza verifica delle transitive, purché la dipendenza non introduca eseguibili distribuiti nel binario finale.

Il criterio 7 (analisi superficie di attacco) non si applica ai tool di build puri che non hanno accesso a dati runtime.

### 2.3 Dipendenze non accettate

Indipendentemente dai criteri sopra, le seguenti categorie di dipendenze sono vietate:

- **SDK di analytics o telemetria** (Firebase Analytics, Mixpanel, Amplitude, ecc.) — anti-pattern esplicito CLAUDE.md §11.
- **SDK di crash reporting di terze parti** (Sentry, Crashlytics, ecc.) — anti-pattern esplicito CLAUDE.md §11.
- **SDK di advertising o tracking** (AdMob, Facebook SDK, ecc.).
- **Qualsiasi pacchetto che trasmette dati a server non sotto controllo dell'utente** senza consenso esplicito e E2E encryption.

---

## 3. CVE response SLA

### 3.1 Tabella SLA

| Severità CVSS | Soglia CVSS v3.1 | SLA per patch o workaround | Note |
|---|---|---|---|
| **Critical** | CVSS ≥ 9.0 | < 30 giorni | Se la vulnerabilità è attivamente sfruttata (CISA KEV), il target scende a 7 giorni. |
| **High** | CVSS 7.0–8.9 | < 90 giorni | Se non esiste patch upstream, documentare il workaround e aprire issue di tracking. |
| **Medium** | CVSS 4.0–6.9 | < 180 giorni | Pianificare nella release più vicina utile. |
| **Low** | CVSS < 4.0 | Prossima release pianificata | Non è bloccante. |

### 3.2 Processo di risposta CVE

**Rilevazione:**
- GitHub Dependabot alerts (quando attivato sul repository).
- `dart pub outdated` nella revisione settimanale.
- Advisory database pub.dev.
- Mailing list e security advisory dei pacchetti critici (seguire release di `cryptography`, `flutter_secure_storage`, `drift`, `sqlcipher_flutter_libs`).

**Triage:**
1. Valutare se la funzionalità vulnerabile è effettivamente usata da Métra (spesso le CVE riguardano path non invocati).
2. Classificare la severità contestualizzata (una CVE Critical su un path non raggiungibile può scalare a Medium).
3. Aprire un issue GitHub con label `security` e `dependency-vuln`.

**Fix:**
1. Aggiornare la dipendenza alla versione patched: `dart pub upgrade <package>`.
2. Se la versione patched non è ancora disponibile, valutare:
   - `dependency_overrides` in `pubspec.yaml` per forzare una versione sicura (documentare il motivo con un commento `# CVE-XXXX-XXXXX: override until <package>@<version> is released`).
   - Rimozione della funzionalità che usa la dipendenza vulnerabile.
   - Sostituzione con alternativa sicura.
3. Eseguire tutti i test e i gate CI prima del merge.
4. Entry nel `CHANGELOG.md` con riferimento CVE.

### 3.3 Dipendenze ad alto rischio da monitorare

Le seguenti dipendenze hanno accesso diretto a dati critici e devono essere monitorate con priorità:

| Pacchetto | Motivo | Canale di monitoring |
|---|---|---|
| `cryptography` | Implementa Argon2id e AES-256-GCM | GitHub Releases, pub.dev advisories |
| `flutter_secure_storage` | Custodisce la chiave del DB SQLCipher | GitHub Releases, pub.dev advisories |
| `sqlcipher_flutter_libs` | Linka SQLCipher — vulnerabilità nel C layer | GitHub Releases, SQLCipher upstream advisories |
| `drift` | ORM che costruisce le query sul DB cifrato | GitHub Releases, pub.dev advisories |
| `sqlite3` | Binding per `open.overrideFor` | GitHub Releases |

---

## 4. Processo di richiesta eccezioni

### 4.1 Quando è necessaria un'eccezione

Un'eccezione è necessaria quando si vuole aggiungere una dipendenza che:
- Non soddisfa uno o più criteri obbligatori di §2.1.
- Ha una licenza in lista grigia (non in §1.1 né in §1.2).
- È un pacchetto con singolo maintainer e meno di 130 Pub Points.

### 4.2 Formato della richiesta

Aprire un issue GitHub con label `dependency-exception` e titolo `[DEP-EXCEPTION] <package>@<version>`.

Il corpo dell'issue deve contenere:

```
## Pacchetto
Nome: <package>
Versione: <version>
Licenza SPDX: <license>
pub.dev: <url>

## Criterio non soddisfatto
<quale criterio di §2.1 o §1.1 non è soddisfatto e perché>

## Giustificazione
<perché questo pacchetto è necessario — cosa non può fare nessuna alternativa già presente>

## Analisi del rischio
<impatto del rischio specifico del criterio non soddisfatto>

## Mitigazioni proposte
<come si riduce il rischio: auditing del codice sorgente, pin di versione, isolamento, ecc.>

## Alternativa valutata e scartata
<quale alternativa è stata considerata e perché non è sufficiente>
```

### 4.3 Approvazione

- Per eccezioni di licenza: richiede conferma esplicita del maintainer (Paolo Santucci) documentata nell'issue.
- Per eccezioni di qualità (Pub Points, maintainer): approvazione documentata nell'issue + revisione del codice sorgente del pacchetto.
- Le eccezioni approvate devono essere rinnovate se la dipendenza non viene aggiornata entro 12 mesi.

### 4.4 Registro delle eccezioni

Le eccezioni approvate devono essere documentate con un commento inline in `pubspec.yaml`:

```yaml
dependencies:
  some_package: ^1.2.3  # DEP-EXCEPTION approved 2026-04-28: <motivo breve>
```

E referenziate nell'issue GitHub corrispondente.
