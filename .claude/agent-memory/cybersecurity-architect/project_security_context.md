---
name: Progetto Métra — contesto sicurezza
description: Panoramica dell'architettura di sicurezza di Métra e dei riferimenti ai documenti chiave
type: project
---

App menstrual cycle tracker, Flutter/Dart, local-first, zero-knowledge cloud. Stack: Drift ORM + SQLCipher AES-256, flutter_secure_storage (Keychain iOS / EncryptedSharedPreferences Android), Riverpod 2.x, go_router.

Threat model canonico: `docs/security/threat-model.md` (versione 1.1 dopo P-1).
Analisi sicurezza P-1: `docs/security/p1-appsec-review.md`.

Architettura UI→Domain→Data: le feature non importano mai DAO/services direttamente (sempre via repository). Il domain non importa da data. Questa separazione è un controllo architetturale: riduce la superficie di attacco del layer domain e ne garantisce la testabilità.

Controlli critici verificati nel codice:
- `app_database.dart:143–171`: fail-secure cipher_version check + regex pre-PRAGMA
- `encryption_provider.dart:26`: AndroidOptions(encryptedSharedPreferences: true) impostato
- `save_daily_log.dart:41–53`: validazione futura-data + range painIntensity in use case
- `daily_entry_controller.dart:64`: commento esplicito no-log DailyLogEntity

**Why:** L'app tratta dati sanitari intimi. La local-first è un principio non negoziabile, non una scelta tecnica — qualsiasi proposta che preveda dati su server deve essere rifiutata.
**How to apply:** Ogni raccomandazione deve rispettare il vincolo local-first. I gap aperti hanno tutti target P-2 (GAP-01..05).
