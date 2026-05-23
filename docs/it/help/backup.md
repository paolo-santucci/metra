---
layout: help
title: Backup su cloud
subtitle: "Come collegare Dropbox e cosa significa concretamente \"crittografia end-to-end\"."
nav_title: Backup su cloud
lang: it
lang_ref: help-backup
permalink: /it/help/backup/
help_order: 4
---

## Come funziona il backup di Mētra

I tuoi dati non lasciano mai il dispositivo a meno che tu non lo decida. Questa è la premessa di Mētra: **local-first** non è una modalità, è l'impostazione predefinita. Il backup è un'opzione, non un'aspettativa.

Quando lo attivi, Mētra cifra l'intero database sul tuo dispositivo **prima** di caricarlo. Dropbox riceve un blob opaco che non può leggere. Nessun altro ha accesso ai tuoi dati, incluso chi ha scritto il codice.

> ⚠️ **Non esiste il recupero della passphrase.** La chiave di cifratura è derivata dalla tua passphrase e vive solo sul tuo dispositivo, non su un server, non nel cloud. Se perdi la passphrase, il backup non può essere recuperato. Conservala in un posto sicuro, separato dal telefono (es. un gestore di password).

---

## Collegare un provider cloud

![Schermata backup prima della connessione: pulsante di connessione Dropbox.](/metra/assets/backup-connect-it.png)

1. Vai in **Impostazioni → Backup cloud**.
2. Tocca **Collega Dropbox**.
3. Verrai reindirizzata alla pagina di accesso del provider nel browser.
4. Dopo aver autorizzato la connessione, torni a Mētra.

Mētra richiede i permessi minimi: solo l'accesso a una cartella dedicata, non all'intero spazio di archiviazione cloud.

---

## Creare un backup

![Schermata backup dopo la connessione: email connessa, data ultimo backup, pulsanti \"Esegui backup\" e \"Disconnetti\".](/metra/assets/backup-connected-it.png)

Una volta collegata:

1. Tocca **Salva ora**.
2. Mētra ti chiede la tua **passphrase**, quella usata per cifrare il file. Ti servirà identica per il ripristino.
3. Mētra cifra il database sul dispositivo e lo carica. Un indicatore di avanzamento mostra lo stato.
4. Al termine, la schermata mostra data e ora dell'ultimo backup riuscito.

> **Nota sulla passphrase:** non esiste nessuna opzione di recupero, perché non esiste nessun server che potrebbe eseguirlo. Scegli una passphrase che ricorderai e conservala separatamente dal telefono.

Dopo il backup iniziale, Mētra provvederà autonomamente a fare backup periodici.

Mētra mantiene automaticamente i 3 backup cifrati più recenti nella cartella cloud; quelli più vecchi vengono rimossi dopo ogni backup riuscito. Nessuna impostazione modificabile — è la postura local-first / rispetta-l'utente-adulto.

---

## Cosa viene salvato nel backup

Il backup contiene il contenuto completo del database cifrato:

- Tutte le registrazioni giornaliere (flusso, dolore, sintomi, note).
- I cicli derivati dalle registrazioni.
- Le impostazioni dell'app (durata del ciclo di riferimento, preferenze notifiche).

**Non** include lo stato delle notifiche locali, queste vengono ricreate automaticamente dopo un ripristino.

---

## Ripristinare da un backup

![Flusso di ripristino: pannello di selezione versione, poi inserimento passphrase, poi avanzamento e conferma completamento.](/metra/assets/backup-restore-it.png)

1. Installa Mētra sul nuovo dispositivo (o dopo un ripristino di fabbrica).
2. Completa il flusso di benvenuto, i numeri inseriti non contano, verranno sovrascritti dal ripristino.
3. Vai in **Impostazioni → Backup cloud**.
4. Collega il tuo account Dropbox. Se sono presenti backup ti verrà indicato e sarà riportata la data dell'ultimo.
5. Tocca **Ripristina da backup** e conferma nella finestra di avviso che i dati attuali verranno sostituiti.
6. Apparirà un pannello con una rotella di selezione: scorri per scegliere la versione da ripristinare. Ogni voce mostra data, ora e dimensione del file (fino a 3 backup disponibili, il più recente è quello più in alto).
7. Tocca **Ripristina** per confermare, oppure **Annulla** per tornare indietro.
8. Inserisci la tua passphrase. Mētra scarica il backup scelto, lo decifra e sostituisce il database locale.

> ⚠️ **Attenzione:** il ripristino sovrascrive tutti i dati attualmente sul dispositivo. Questa operazione non può essere annullata.

---

## Scollegare il provider

Tocca **Disconnetti** nella schermata backup per scollegare l'account cloud. I file di backup già sul cloud **non vengono eliminati**, devi farlo manualmente dall'app o dal sito di Dropbox.

Mētra conserva fino a 3 backup cifrati più recenti nella cartella dell'app.

---

## Dettagli tecnici sulla sicurezza

- Algoritmo di cifratura: **AES-256-GCM**.
- Derivazione della chiave: **Argon2id** dalla tua passphrase.
- La chiave non viene mai salvata nel cloud, mai inviata a nessun server e mai conservata sul dispositivo: viene derivata dalla passphrase ogni volta che ne hai bisogno, poi scartata.
- Il file di backup ha estensione `.enc` ed è archiviato in una cartella dedicata a Mētra nel tuo account cloud.

Questi non sono annunci di marketing: sono le scelte specifiche nel codice. Puoi verificarlo leggendo `lib/data/services/encryption_service.dart`.
