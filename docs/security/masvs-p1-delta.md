# MASVS P-1 Delta — Métra

**Commit base:** b20f4d4 (P-0b)  
**Commit corrente:** 7ac2fd9 (P-1)  
**Data:** 2026-04-28  
**Redatto da:** Mobile Security Engineer (static review)  
**Perimetro P-1:** `features/daily_entry/**`, `features/calendar/**`, `providers/repository_providers.dart`, `providers/use_case_providers.dart`  
**Riferimento audit S11:** `docs/security/p1-appsec-review.md` (M1, M2, M9 — PASS)

---

## Controlli aggiornati

| Controllo | Stato P-0b | Stato P-1 | Motivazione del cambio |
|-----------|------------|-----------|------------------------|
| MASVS-STORAGE-1 | PASS (parziale) | **PASS** | F-01 implementato: flusso PII verificato end-to-end, nessuna fuga identificata |
| MASVS-PLATFORM-3 | PASS (parziale) | **PASS** | UI sensitiva ora presente e verificata; gap screenshot (R-06) confermato L2, non L1 |
| MASVS-CODE-4 | PASS (parziale) | **PASS** | `SaveDailyLog` implementa validazione esplicita (data, range, conflitti); Drift ORM garantisce query parametrizzate |
| MASVS-PRIVACY-4 | PASS (condizionale) | **PASS (condizionale)** | Delete per-giorno con dialog di conferma ora implementato; cancellazione bulk deferred a P-5 |

I quattro controlli che erano classificati "parziale" in attesa di F-01 sono stati rivalutati sul codice effettivo. In tutti i casi la classificazione sale o viene confermata; nessun controllo è peggiorato.

---

## Nuovi FAIL introdotti da P-1

**Nessuno.** Il perimetro P-1 non introduce nuove violazioni MASVS. Specificamente:

- Nessun dato PII è trasmesso via rete (superficie di rete invariata, INTERNET permission assente).
- Nessuna credential o segreto è introdotto nel codice sorgente.
- Nessun componente Android esportato aggiunto.
- Nessuna dipendenza di terze parti aggiunta a `pubspec.yaml` nel commit P-1.
- Il singolo `debugPrint` presente (`historical_entry_screen.dart:156`) è racchiuso in `assert()`, rimosso dal compilatore in release profile, e opera su metadata ORM senza PII (dettaglio: `docs/security/p1-appsec-review.md` §F-001).

---

## FAIL esistenti non risolti in P-1

| Controllo | FAIL | Stato in P-1 |
|-----------|------|--------------|
| MASVS-STORAGE-2 | `android:allowBackup` non disabilitato; `res/xml/` assente | **Non risolto** — `AndroidManifest.xml` invariato |
| MASVS-RESILIENCE-1 | Root/jailbreak detection assente | **Non risolto** — deferred P-7 |
| MASVS-RESILIENCE-2 | Release build firmata con debug key | **Non risolto** — deferred pre-distribuzione (R-10) |
| MASVS-RESILIENCE-3 | Obfuscation assente | **Non risolto** — deferred P-7 |

STORAGE-2 era target del plan per P-0b/P-1 (R-01 nel piano di remediation). La sua mancata risoluzione ha conseguenze sul punteggio L2 (vedi calcolo conformità).

---

## Gap P-1 da indirizzare nelle fasi successive

### 1. Screenshot protection — R-06 ora concreta (P-5)

Con F-01 implementato, le schermate `QuickEntryModal` e `HistoricalEntryScreen` mostrano dati sanitari in chiaro (flusso, dolore, note, sintomi). Il campo `_notesController` e il campo `_existingLog` in `_QuickEntryModalState` sono superfici PII vive in memoria di processo. Nell'app switcher, queste schermate producono anteprime contenenti dati sensitivi. La remediation (R-06: `FLAG_SECURE` Android + blur iOS in `sceneWillDeactivate`) era già pianificata a P-5; P-1 la rende non più teorica ma concreta. Priorità da confermare per P-5.

### 2. `TextFieldMetra` per note — keyboard suggestions (L2, P-5)

Il campo note in `HistoricalEntryScreen` (`TextFieldMetra`, `maxLines: null`) non imposta `enableSuggestions: false` né `autocorrect: false`. Il testo delle note sanitarie potrebbe entrare nel dizionario predittivo della tastiera dell'OS. Questo è un gap L2 (MASVS-PLATFORM-3 L2) non L1, ma diventa indirizzabile a P-5 quando la UI di Settings sarà implementata. Aggiungere entrambe le opzioni al widget `TextFieldMetra` per tutti i campi note sensibili.

### 3. Router: parsing della data senza gestione errori (hardening, sprint successivo)

`app_router.dart:48-53` esegue `int.parse(parts[0/1/2])` senza `try/catch` sul parametro di rotta `/daily-entry/:date`. Una stringa malformata provoca `FormatException` non gestita nel `GoRouter.builder`, con crash del frame. Il path è controllato (generato da `date.toIso8601String().substring(0, 10)` in `calendar_screen.dart:298`) e non esposto a input arbitrario esterno. Il rischio pratico è basso, ma la difesa in profondità consigliata è un `try/catch` con redirect a `/calendar` in caso di parsing failure. Non è un FAIL MASVS, ma un'osservazione CODE-4 da chiudere in una sprint vicina.

### 4. STORAGE-2 — sprint blocker per L2 ≥80%

R-01 (STORAGE-2: `allowBackup=false` + `data_extraction_rules.xml`) non è stato chiuso in P-1. Questo FAIL mantiene il punteggio L2 a 19/24 = **79%**, sotto la soglia ≥80% richiesta per il tag `v0.1.0-p1`. La fix richiede meno di un'ora di lavoro; è il blocco più urgente per procedere al tag di release.

---

## Calcolo conformità L1

**Struttura (24 controlli, invariata):**

| Categoria | PASS | FAIL | N/A | Totale |
|-----------|------|------|-----|--------|
| STORAGE | 1 | 1 | 0 | 2 |
| CRYPTO | 2 | 0 | 0 | 2 |
| AUTH | 0 | 0 | 3 | 3 |
| NETWORK | 1 | 0 | 1 | 2 |
| PLATFORM | 2 | 0 | 1 | 3 |
| CODE | 3 | 0 | 1 | 4 |
| RESILIENCE | 0 | 3 | 1 | 4 |
| PRIVACY | 4 | 0 | 0 | 4 |
| **Totale** | **13** | **4** | **7** | **24** |

N/A: AUTH-1, AUTH-2, AUTH-3, NETWORK-2, PLATFORM-2, CODE-2, RESILIENCE-4.

**Controlli applicabili:** 24 − 7 (N/A) = **17**  
**PASS (inclusi condizionale/riserva):** 13  
**Conformità L1 lorda:** 13/17 = **76%**  
**Conformità L1 escludendo FAIL deferred P-7** (RESILIENCE-1, RESILIENCE-3): 13/15 = **87%** — sopra la soglia ≥80%.

I FAIL bloccanti pre-distribuzione sono STORAGE-2 e RESILIENCE-2. STORAGE-2 è il target immediato del piano; RESILIENCE-2 è un prerequisito distinto da soddisfare prima di qualsiasi distribuzione esterna.

**Nota metodologica sul conteggio PASS:** STORAGE-1, PLATFORM-3, CODE-4 passano da "parziale" a PASS pieno. PRIVACY-4 rimane condizionale ma è conteggiata PASS per l'implementazione parziale verificata. CODE-1 e CODE-3 rimangono rispettivamente "condizionale" e "con riserva" ma non FAIL a livello L1, perché la condizionalità riguarda configurazioni da verificare su device (CODE-1: valore effettivo `minSdk`) e tool non eseguiti (CODE-3: `flutter pub audit`), non violazioni del controllo nel codice.

---

## Calcolo conformità L2

Struttura invariata rispetto al documento `masvs-l2-targets.md` (commit b20f4d4): P-1 non chiude nessun gap L2. Il punteggio è identico al baseline.

| Stato L2 | Conteggio | Note |
|----------|-----------|------|
| PASS (inclusi condizionali/parziali) | 9 | CRYPTO-1, NETWORK-1, PLATFORM-1, CODE-4, PRIVACY-1-4 — CODE-4 promosso da "parziale" a PASS pieno in P-1, senza effetto numerico (era già conteggiato PASS nel baseline) |
| N/A | 4 | AUTH-1, PLATFORM-2, CODE-2, RESILIENCE-4 |
| DEFERRED giustificato | 6 | AUTH-2 (P-5), AUTH-3 (P-5), NETWORK-2 (P-6), PLATFORM-3 (P-5), RESILIENCE-1 (P-7), RESILIENCE-3 (P-7) |
| FAIL | 5 | STORAGE-1, STORAGE-2, CRYPTO-2, CODE-1, CODE-3 + RESILIENCE-2 (pre-distrib. blocker) |

**Totale conformi L2** (PASS + N/A + DEFERRED): 9 + 4 + 6 = **19/24 = 79%** — invariato rispetto a b20f4d4.

La soglia ≥80% (≥20/24) **non è raggiunta**.

Il delta rispetto alla proiezione del documento L2 (che stimava 83% dopo la fix R-01) è interamente dovuto alla mancata chiusura di STORAGE-2 in P-1. Risolvere R-01 porta il conteggio a 20/24 = **83%**, sopra la soglia.

**Nota:** RESILIENCE-2 (debug key signing) è conteggiato come FAIL separato ma rientra nel conteggio FAIL sopra. Non è un DEFERRED — è un FAIL bloccante pre-distribuzione distinto dagli item deferred a P-7.

---

## Verdict

**L1: PASS condizionale** — 87% escludendo i FAIL deferred a P-7 (13/15 applicabili non-deferred). I due FAIL bloccanti (STORAGE-2, RESILIENCE-2) sono noti e pianificati.

**L2: FAIL — soglia ≥80% non raggiunta (79%).** Unico blocco: STORAGE-2 (R-01). Il tag `v0.1.0-p1` non deve essere apposto finché R-01 non è chiuso. La stima di effort è < 1 ora (aggiunta di tre attributi in `AndroidManifest.xml` + creazione di `res/xml/data_extraction_rules.xml`).

**Azioni bloccanti immediate:**

1. **R-01** — `android:allowBackup="false"` + `android:dataExtractionRules="@xml/data_extraction_rules"` in `AndroidManifest.xml`; creare `android/app/src/main/res/xml/data_extraction_rules.xml` con esclusione di tutti i domini. Questo sblocca L2 ≥80% e risolve STORAGE-2 L1.
2. **R-10** — Generare release keystore prima di qualsiasi distribuzione esterna (non blocca il tag locale `v0.1.0-p1` ma blocca PlayStore/TestFlight).

**Azioni da pianificare (non bloccanti per il tag):**

3. **R-06/R-09** (P-5) — `FLAG_SECURE` Android + blur iOS sulle schermate daily_entry. Ora concreta dopo F-01.
4. **Keyboard suggestions** (P-5) — `enableSuggestions: false`, `autocorrect: false` su `TextFieldMetra` per note.
5. **Router date parsing** (sprint prossima) — `try/catch` + redirect su `int.parse` in `app_router.dart:48-53`.
