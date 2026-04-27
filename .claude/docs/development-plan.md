# Métra — Piano di Sviluppo App Tracciamento Ciclo Mestruale

## Contesto

Paolo vuole costruire un'app mobile privacy-first per il tracciamento del ciclo mestruale. L'app deve essere **local-first** (nessun server proprio), con sync cloud E2E cifrato e un look emotional design. L'obiettivo è solo la consapevolezza del ciclo, non il fertility tracking. L'app sarà gratuita.

Paolo è un Java developer senior con esperienza webapp, alla sua prima app mobile. Framework scelto: **Flutter (Dart)** — scelta motivata dalla vicinanza sintattica con Java (tipizzazione statica, classi, null safety).

---

## Ambiente di Sviluppo

- **OS sviluppo**: Fedora Linux — nessun Mac disponibile
- **Android**: sviluppo e test locali completi (emulatore + dispositivo fisico)
- **iOS**: build e pubblicazione tramite **GitHub Actions macOS runner** (gratuito per repo pubblici). Test via TestFlight su dispositivo fisico.
- **Simulatore iOS**: non disponibile in locale — usare TestFlight per test iOS
- **Licenza**: GPL-3.0 (open-source, fork devono mantenere codice aperto)

## Decisioni Chiave

| Decisione          | Scelta                              | Rationale                                                                                                                                                                                                                                                                                                        |
| ------------------ | ----------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nome               | **Métra**                           | Contiene utero + madre + origine in una parola sola. Corta, memorabile, l’accento sulla é la rende elegante e la differenzia dal “metra/metro” quotidiano. Il significato ginecologico è trasparente per chi conosce l’etimologia, ma per tutti ti gli altri è semplicemente una parola bellissima e misteriosa. |
| Framework          | Flutter 3.x                         | Dart simile a Java, widget system maturo, migliori performance calendario                                                                                                                                                                                                                                        |
| DB locale          | Drift ORM + SQLCipher               | Type-safe, reactive streams, cifratura AES-256 trasparente                                                                                                                                                                                                                                                       |
| State mgmt         | Riverpod 2.x                        | Type-safe, testabile, integra bene con Drift streams                                                                                                                                                                                                                                                             |
| Crittografia cloud | AES-256-GCM + Argon2id              | Zero-knowledge: il cloud provider vede solo blob opaco                                                                                                                                                                                                                                                           |
| Cloud MVP          | Google Drive, Dropbox, OneDrive     | iCloud richiede Method Channel Swift nativo (post-MVP se necessario)                                                                                                                                                                                                                                             |
| Previsione         | Weighted Moving Average (N=6 cicli) | Più reattiva della media semplice, gestisce variabilità                                                                                                                                                                                                                                                          |

---

## Architettura (Riassunto)

```
Flutter App (Riverpod + Drift + SQLCipher)
    │
    ├── UI: bottom nav 4 tab (Calendario / Timeline+Tabella / Statistiche / Impostazioni)
    ├── Domain: CyclePredictionService, EncryptionService, SyncOrchestrator
    └── Data: Drift DAO → SQLCipher DB (chiave in flutter_secure_storage)
                              │
                              └── [Encrypt] → blob .enc → Cloud Provider (OAuth2)
```

**Flusso dati critico**: DB locale → JSON in memoria → AES-256-GCM (chiave da Keychain) → upload blob opaco. Il provider non vede mai dati in chiaro.

---

## Modello Dati (Entità Drift)

- **DailyLog**: date, flowIntensity, spotting, otherDischarge, painIntensity, painEnabled, notes, notesEnabled
- **PainSymptom**: dailyLogId (FK), symptomType (cramps/back/headache/migraine/custom), customLabel
- **CycleEntry**: startDate, endDate, cycleLength, periodLength (calcolata da DailyLog, persistita per performance)
- **SymptomTemplate**: tipi dolore personalizzati dall'utente
- **AppSettings**: singleton (id=1), tutte le preferenze globali
- **SyncLog**: audit trail operazioni cloud

---

## Funzionalità MVP Prioritizzate

1. **F-01** Registrazione giornaliera (flusso / spotting / dolore / note) — ≤3 tap
2. **F-02** Calendario mensile con colori semantici (rosso=flusso, blu=previsione)
3. **F-06** Previsione prossimo ciclo (WMA) + notifica configurabile
4. **F-03** Timeline + **F-04** Tabella (toggle)
5. **F-05** Statistiche (fl_chart: lunghezza cicli, durata, frequenza sintomi)
6. **F-07** Impostazioni (lingua, tema, toggle dolore/note, notifiche, sync)
7. **F-08** Sync cloud E2E (Google Drive > Dropbox > OneDrive)
8. **F-09** Export/Import CSV
9. **F-10** Integrazione calendario dispositivo

---

## File Critici da Creare (Fase 0)

- `pubspec.yaml` — dipendenze complete
- `lib/data/database/app_database.dart` — tabelle Drift
- `lib/data/services/encryption_service.dart` — AES-256-GCM + Argon2id
- `lib/data/services/cycle_prediction_service.dart` — algoritmo WMA
- `lib/features/calendar/providers/calendar_provider.dart` — Riverpod notifier principale
- `ios/Runner/CloudKitChannel.swift` — method channel iCloud (post-MVP)

---

## Dipendenze Principali (pubspec.yaml)

```yaml
flutter_riverpod: ^2.5.1
drift: ^2.18.0 / drift_flutter + sqlcipher_flutter_libs: ^0.5.4
cryptography: ^2.7.0          # AES-256-GCM, Argon2id
flutter_secure_storage: ^9.2.2
go_router: ^14.2.7
fl_chart: ^0.68.0
google_fonts: ^6.2.1          # Inter + DM Serif Display
flutter_local_notifications: ^17.2.2 + flutter_timezone: ^3.0.0
device_calendar: ^4.3.1
google_sign_in: ^6.2.1 + googleapis: ^13.2.0
http: ^1.2.2                  # Dropbox + OneDrive REST
file_picker: ^8.1.2 + share_plus: ^10.0.2 + csv: ^6.0.0
intl: ^0.19.0
```

---

## Roadmap (16 settimane, Java dev che apprende Flutter)

| Fase | Settimane | Output |
|---|---|---|
| 0 — Setup + DB | 1-2 | App avvia, naviga, DB cifrato funziona |
| 1 — Data entry | 3-4 | Registrazione giornaliera + Calendario base |
| 2 — Viste + Stats | 5-6 | Timeline, Tabella, Statistiche |
| 3 — Previsioni + Notifiche | 7 | WMA operativo, notifiche schedulate |
| 4 — Settings + L10n | 8 | IT+EN, dark mode, toggle funzionanti |
| 5 — Export + Calendario | 9-10 | CSV, device_calendar |
| 6 — Sync Cloud | 11-14 | Google Drive + Dropbox + OneDrive |
| 7 — Polish + Release | 15-16 | Accessibilità, onboarding, store submission |

---

## Domande Aperte (da rispondere prima/durante sviluppo)

- **DQ-01**: Keychain trasparente?
- ~~**DQ-03**~~: **Risolto** — iCloud rimandato a v1.1. MVP include Google Drive, Dropbox, OneDrive.
- ~~**DQ-05**~~: **Risolto** — Sync automatico all'apertura dell'app + pulsante manuale sempre disponibile. Background sync non implementato (inaffidabile su iOS).
- ~~**DQ-06**~~: **Risolto** — Conflitto multi-device: wins the latest backup. L'utente viene avvisato prima della sovrascrittura.
- ~~**DQ-07**~~: **Risolto** — Inserimento dati storici incluso nel MVP. Richiede UI dedicata (distinta dalla registrazione quotidiana).
- ~~**DQ-08**~~: **Rimandato** — Condivisione statistiche con il ginecologo post-MVP.
- ~~**DQ-09**~~: **Risolto** — Nessun export `.enc` locale. Il CSV è sufficiente come portabilità dati offline.
- ~~**DQ-10**~~: **Risolto** — App open-source su GitHub, licenza **GPL-3.0**. Privacy Policy pubblicata via GitHub Pages (es. `https://tuonome.github.io/Métra/privacy`). Accettato da App Store e Google Play.

---

## Verifica (come testare end-to-end)

1. **DB cifrato**: chiudere e riaprire app → dati persistono. Aprire file DB con SQLite browser senza chiave → fallisce.
2. **Previsione**: inserire 3+ cicli con date note → verificare che la data prevista corrisponda alla WMA manuale.
3. **E2E encryption**: fare backup su Google Drive → scaricare il file `.enc` → verificare che sia binario illeggibile. Ripristinare su secondo dispositivo → dati identici.
4. **Calendario dispositivo**: abilitare sync → verificare evento "Inizio ciclo" creato nel calendario nativo.
5. **CSV round-trip**: export → modifica un campo → import → verificare aggiornamento in DB.
6. **Notifica**: impostare notifica 1 giorno prima → avanzare data di sistema → verificare notifica ricevuta.
