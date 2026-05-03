---
layout: page
title: Backup su cloud
---

[← Torna alla Guida](.) &nbsp;·&nbsp; [🇬🇧 English](../backup)

## Come funziona il backup di Métra

Métra è **local-first**: i tuoi dati non lasciano mai il dispositivo a meno che tu non scelga esplicitamente di farne un backup. La funzione di backup è completamente facoltativa.

Quando attivi il backup, Métra cifra l'intero database sul tuo dispositivo **prima** di caricarlo. Il provider cloud — Dropbox, Google Drive o OneDrive — riceve solo un blob opaco e illeggibile. Non ha accesso ai tuoi dati, e nemmeno nessun altro.

> **Non esiste il recupero della password.** La chiave di cifratura è derivata dalla tua passphrase e vive solo sul tuo dispositivo. Se perdi la passphrase, il backup non può essere recuperato. Conservala in un posto sicuro (es. un gestore di password).

---

## Collegare un provider cloud

<!-- SCREENSHOT PLACEHOLDER: backup-connect.png -->
<!-- Schermata backup prima della connessione: tre pulsanti provider (Dropbox, Google Drive, OneDrive). -->

1. Vai in **Impostazioni → Backup su cloud**.
2. Scegli il tuo provider preferito: **Dropbox**, **Google Drive** o **OneDrive**.
3. Verrai reindirizzata alla pagina di accesso del provider nel browser.
4. Dopo aver autorizzato la connessione, torni a Métra.

Métra richiede i permessi minimi necessari — solo l'accesso a una cartella dedicata, non all'intero spazio di archiviazione cloud.

---

## Creare un backup

<!-- SCREENSHOT PLACEHOLDER: backup-connected.png -->
<!-- Schermata backup dopo la connessione: email connessa, data ultimo backup, pulsanti "Esegui backup" e "Disconnetti". -->

Una volta collegata:

1. Tocca **Esegui backup**.
2. Métra ti chiede di inserire — o confermare — la tua **passphrase**. Questa passphrase viene usata per cifrare il file di backup. Sarà necessaria per il ripristino.
3. Il backup viene cifrato sul dispositivo e caricato. Viene mostrato un indicatore di avanzamento.
4. Al termine, la schermata mostra data e ora dell'ultimo backup riuscito.

> **Consiglio:** scegli una passphrase che ricorderai e conservala separatamente dal telefono (es. in un gestore di password). Non esiste nessuna opzione di recupero.

---

## Cosa viene salvato nel backup

Il backup contiene il contenuto completo del database cifrato:

- Tutte le registrazioni giornaliere (flusso, dolore, sintomi, note).
- I cicli derivati dalle registrazioni.
- Le impostazioni dell'app (durata del ciclo di riferimento, preferenze notifiche).

**Non** include lo stato delle notifiche locali — queste vengono ricreate automaticamente dopo un ripristino.

---

## Ripristinare da un backup

<!-- SCREENSHOT PLACEHOLDER: backup-restore.png -->
<!-- Flusso di ripristino: dialog inserimento passphrase, poi avanzamento, poi conferma completamento. -->

1. Installa Métra sul nuovo dispositivo (o dopo un ripristino di fabbrica).
2. Completa il flusso di benvenuto — i numeri inseriti non contano, verranno sovrascritti dal ripristino.
3. Vai in **Impostazioni → Backup su cloud**.
4. Collega lo stesso provider usato per il backup.
5. Tocca **Ripristina**.
6. Inserisci la tua passphrase.
7. Métra scarica il backup, lo decifra e sostituisce il database locale.

> **Attenzione:** il ripristino sovrascrive tutti i dati attualmente sul dispositivo. Questa operazione non può essere annullata.

---

## Scollegare il provider

Tocca **Disconnetti** nella schermata backup per scollegare l'account cloud. Il token OAuth viene rimosso dal dispositivo. Il file di backup già sul cloud **non viene eliminato** — devi farlo manualmente dallo storage cloud se vuoi rimuoverlo.

---

## Dettagli tecnici sulla sicurezza

- Algoritmo di cifratura: **AES-256-GCM**.
- Derivazione della chiave: **Argon2id** dalla tua passphrase.
- La chiave non viene mai salvata nel cloud, mai inviata a nessun server e mai conservata sul dispositivo — viene derivata dalla passphrase ogni volta.
- Il file di backup ha estensione `.enc` ed è archiviato in una cartella dedicata a Métra nel tuo account cloud.

Puoi verificare tutto questo leggendo il codice sorgente in `lib/data/services/encryption_service.dart`.

---

[← Torna alla Guida](.)
