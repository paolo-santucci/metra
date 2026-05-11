---
layout: post
title: "Mētra 1.0 — Prima versione stabile"
date: 2026-05-10
tags: [rilascio, aggiornamenti]
author: Paolo Santucci
excerpt: "La prima versione stabile di Mētra è disponibile per Android. Un quaderno digitale per il ciclo mestruale — privato, cifrato, open source."
lang: it
---

Oggi rilasciamo Mētra 1.0.

Non è una frase che scriviamo con leggerezza. Una versione stabile è una promessa: che il software funziona, che non rompe i tuoi dati, che puoi affidarti a essa con qualcosa di personale. Abbiamo costruito questa versione con quella responsabilità in testa.

---

## Perché un'altra app per il ciclo

La risposta breve: perché le app esistenti sono costruite intorno a una transazione che rifiutiamo.

I tuoi dati — intimi, fisiologici, profondamente personali — in cambio di una previsione. L'app impara il tuo corpo. L'azienda impara il tuo corpo. Inserzionisti, assicuratori, broker di dati: imparano anche loro, nel tempo, perché è così che funziona l'economia di quei prodotti.

Mētra rifiuta la transazione.

Ogni nota che scrivi resta sul tuo telefono, cifrata. Se scegli di fare un backup nel cloud, i tuoi dati vengono chiusi dentro una chiave che scegli tu prima di uscire — il provider vede un file che non può leggere. Non esiste un server Mētra. Non esiste un account Mētra. Non esiste nessun team Mētra che osserva il tuo ciclo per migliorare un modello che serve qualcun altro.

Quello che registri appartiene a te. Quello che impari appartiene a te.

---

## Cosa trovi nella 1.0

Mētra 1.0 è un tracker completo per il ciclo mestruale. Locale. Cifrato. Senza account.

**Diario quotidiano.** Flusso, intensità, sintomi personalizzabili, note libere. In tre tocchi. Non di più.

**Calendario mensile.** Una griglia di cerchi che mostrano flusso registrato, previsione e sintomi. Ogni colore ha un significato preciso — nessuno è decorativo. La navigazione tra i mesi non perde mai di vista il giorno che stavi guardando.

**Timeline e tabella.** Due viste dello stesso archivio storico. Puoi leggere i cicli passati come una sequenza narrativa o come una tabella dati, a seconda di come preferisci ragionare sulla tua storia.

**Statistiche.** Durata media del ciclo, durata media del periodo, frequenza dei sintomi per categoria. Numeri, non interpretazioni. L'app non ha opinioni sul tuo corpo.

**Previsione.** Una finestra di 3–5 giorni — non una data precisa. Calcolata con media mobile ponderata sugli ultimi sei cicli, eseguita interamente sul tuo dispositivo, senza nessun modello remoto. Il corpo non è una macchina; una previsione onesta lo riconosce, e restituisce un intervallo invece di una certezza falsa.

**Backup cifrato.** Google Drive, Dropbox, OneDrive. I dati vengono cifrati sul dispositivo — con una passphrase che scegli tu — prima di uscire. Il provider cloud vede un file che non può leggere. La chiave non lascia mai il tuo telefono. Non esiste un reset della password lato server, perché non esiste nessun server.

**Esporta e importa CSV.** I tuoi dati restano tuoi, in un formato aperto e leggibile da qualsiasi foglio di calcolo. Puoi uscire da Mētra in qualsiasi momento portando tutto con te.

**Localizzazione italiano e inglese.** L'app è completamente tradotta in entrambe le lingue, inclusi tutti i testi di interfaccia, le notifiche e i messaggi di errore.

---

## Cosa non trovi, e perché

Non trovi gamification. Non trovi streak. Non trovi notifiche motivazionali. Non trovi consigli su come ottimizzare il tuo ciclo.

Non trovi un account da creare, perché Mētra non ha un server a cui mandare i tuoi dati.

Non trovi analytics, perché non siamo interessati a sapere come usi l'app.

Non trovi un tracker della fertilità. Mētra non assume che tu stia cercando una gravidanza, né che tu abbia un ciclo di 28 giorni, né nessun'altra ipotesi sulla tua relazione con il tuo corpo.

Abbiamo costruito uno strumento. Il giudizio su come usarlo è tuo.

---

## Privacy per architettura

La privacy di Mētra non è una dichiarazione di intenti. È una scelta di architettura.

Tutti i dati vivono in un database locale cifrato con AES-256 tramite SQLCipher. La chiave di cifratura non lascia mai il dispositivo. Il backup nel cloud è end-to-end encrypted — non sappiamo cosa c'è dentro, perché non possiamo saperlo.

Nessun analytics. Nessuna telemetria. Nessun log remoto.

Il codice è open source sotto licenza GPL-3.0. Ogni affermazione in questo post può essere verificata leggendo il sorgente. Non chiediamo fiducia cieca: offriamo trasparenza verificabile.

[Leggi il codice su GitHub →](https://github.com/paolo-santucci/metra/)  
[Leggi la privacy policy →]({{ site.baseurl }}/privacy)

---

## Come scaricarla

Mētra 1.0 è disponibile ora per Android.  
L'APK è scaricabile direttamente da GitHub Releases — nessun app store richiesto.

iOS è disponibile su TestFlight e sarà distribuito sull'App Store nelle prossime settimane. Se vuoi partecipare al beta iOS, trovi le istruzioni nella [documentazione TestFlight]({{ site.baseurl }}/release/testflight-setup).

[Scarica Mētra per Android →](https://github.com/paolo-santucci/metra/releases)

---

## Cosa viene dopo

La 1.0 è un punto di partenza.

Il backlog è lungo e include: supporto per cicli atipici, temi aggiuntivi, ulteriori viste statistiche, notifiche configurabili, miglioramenti all'accessibilità. Nulla di questo sarà costruito per aumentare l'engagement. Sarà costruito se risponde a una sola domanda: *questo rende lo strumento più onesto, più utile, più affidabile?*

Se trovi un bug, [apri un issue su GitHub](https://github.com/paolo-santucci/metra/issues). Se vuoi contribuire al codice, il repository è aperto. Se vuoi sostenere il progetto economicamente, c'è un [link Ko-fi](https://ko-fi.com/D1D31YPYRX).

Grazie per aver scelto uno strumento che non ti usa in cambio.
