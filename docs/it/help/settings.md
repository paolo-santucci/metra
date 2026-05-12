---
layout: help
title: Impostazioni
subtitle: Lingua, tema, notifiche, campi di registrazione, dati. Cosa fa ogni controllo della scheda Impostazioni.
nav_title: Impostazioni
lang: it
lang_ref: help-settings
permalink: /it/help/settings/
help_order: 6
---

<!-- voice: IT tu/feminine, plain register, formality 2/5, no ceremony -->
<!-- source: lib/features/settings/settings_screen.dart + lib/l10n/app_it.arb -->

La scheda **Impostazioni** è il posto dove dai forma all'app: scegli la lingua, decidi quali campi tenere nel diario, stabilisci se e quando ricevere un promemoria. Alcune scelte riguardano anche la privacy: dove finiscono i tuoi dati, in quale formato, con quale accesso. Le modifiche vengono salvate automaticamente, senza pulsante di conferma.

---

## Preferenze

<!-- SCREENSHOT PLACEHOLDER: settings-preferences.png -->
<!-- Sezione Preferenze con le tre righe: Lingua, Tema, Primo giorno della settimana. -->

Aspetto e lingua: tre impostazioni che determinano come appare Mētra ogni volta che la apri.

| Controllo | Opzioni | Predefinito |
|---|---|---|
| **Lingua** | Automatica · Italiano · Inglese | Automatica (segue il sistema operativo) |
| **Tema** | Sistema · Chiaro · Scuro | Sistema (segue il sistema operativo) |
| **Primo giorno della settimana** | Automatico · Domenica · Lunedì | Automatico (segue il sistema operativo) |

**Primo giorno della settimana** cambia l'ordine delle intestazioni nella griglia del Calendario — la griglia si riordina nel momento stesso in cui cambi questa impostazione. Con "Domenica" la settimana parte da D; con "Lunedì" parte da L; con "Automatico" Mētra usa il valore impostato nelle preferenze di sistema del dispositivo. Vedi [Calendario](/it/help/calendar/) per i dettagli sulla griglia.

---

## Notifiche

<!-- SCREENSHOT PLACEHOLDER: settings-notifications.png -->
<!-- Sezione Notifiche con il toggle Promemoria ciclo attivo e le due righe di configurazione (Preavviso, Orario notifica). -->

Mētra non invia notifiche di propria iniziativa. Se vuoi un promemoria, lo attivi tu; se non lo vuoi, l'app tace.

**Promemoria ciclo**: attiva o disattiva il promemoria locale. Quando è attivo, Mētra pianifica una notifica in anticipo rispetto all'inizio previsto del prossimo ciclo.

Le due righe di configurazione sono attive solo quando il promemoria è abilitato.

**Preavviso**: quanti giorni prima dell'inizio previsto vuoi ricevere la notifica. Tocca la riga per aprire un selettore a rotella; il valore si aggiorna automaticamente mentre ruoti. Il campo accetta valori da 1 a 7 giorni.

**Orario notifica**: l'ora e i minuti in cui arriva la notifica nel giorno scelto. I minuti scattano a intervalli di 5.

> **Nota:** su alcuni dispositivi con ottimizzazione aggressiva della batteria (Samsung, Xiaomi, OnePlus), i promemoria possono arrivare in ritardo di qualche minuto.

---

## Registro

<!-- SCREENSHOT PLACEHOLDER: settings-log.png -->
<!-- Sezione Registro con i due toggle: Dolore e Note giornaliere. -->

Non tutte le persone vogliono registrare le stesse cose. Questi due toggle decidono quali campi compaiono nella scheda di registrazione giornaliera.

**Dolore**: quando disattivato, il selettore del livello di dolore non compare nella schermata Registrazione giornaliera né nel dettaglio del giorno. I dati già registrati restano nel database.

**Note giornaliere**: quando disattivato, il campo di testo libero è nascosto. Le note già salvate restano nel database.

Vedi [Registrazione giornaliera](/it/help/daily-entry/) per una descrizione dei campi.

---

## Dati

<!-- SCREENSHOT PLACEHOLDER: settings-data.png -->
<!-- Sezione Dati con le righe Backup cloud (stato), Esporta CSV e Importa CSV. -->

Da qui decidi se e come i tuoi dati si muovono: verso un cloud cifrato, verso un file CSV, o dentro da un file che hai esportato altrove.

**Backup cloud**: mostra "Configurato" se un account cloud è collegato, altrimenti "Non configurato". Tocca la riga per aprire la schermata di backup completa. Vedi [Backup su cloud](/it/help/backup/).

**Esporta CSV**: genera un file CSV con tutte le tue registrazioni e apre il foglio di condivisione del sistema. Prima della condivisione, Mētra mostra un avviso: il file CSV non è cifrato. Vedi [Importa ed esporta](/it/help/import-export/).

**Importa CSV**: apre il selettore file; dopo aver scelto il file, Mētra mostra una finestra per scegliere come gestire i dati esistenti (tre modalità: sostituisci tutto, sovrascrivi per data, mantieni i dati esistenti). Vedi [Importa ed esporta](/it/help/import-export/).

---

## Informazioni

<!-- SCREENSHOT PLACEHOLDER: settings-about.png -->
<!-- Sezione Informazioni con le tre righe: Guida, Codice sorgente, Informativa sulla privacy. -->

Dove trovare questa documentazione, il codice e la dichiarazione su come i dati vengono trattati.

**Guida**: apre questa documentazione nel browser.

**Codice sorgente**: apre il repository GitHub di Mētra. L'app è distribuita con licenza GPL-3.0: chiunque può leggere, modificare e ridistribuire il codice sorgente.

**Informativa sulla privacy**: apre l'informativa sulla privacy nel browser.

In fondo alla schermata trovi il numero di versione dell'app e un collegamento alla pagina Ko-fi per supportare il progetto.

---

## Azioni irreversibili

<!-- SCREENSHOT PLACEHOLDER: settings-danger.png -->
<!-- Sezione Azioni irreversibili con il pulsante rosso "Elimina tutti i dati". -->

**Elimina tutti i dati** — tocca questa riga per aprire una finestra di conferma. Se confermi, Mētra cancella l'intero database locale: tutte le registrazioni giornaliere e i cicli vengono eliminati. Le impostazioni dell'app restano invariate.

> ⚠️ Questa operazione non può essere annullata. Se non è stato effettuato un export CSV o un backup cloud, non esiste un server che possa recuperare i dati. Dopo la conferma, le registrazioni sono andate.
>
> Il backup cloud **non viene eliminato** automaticamente: se hai un backup su Dropbox, devi rimuoverlo manualmente dallo spazio di archiviazione cloud.

