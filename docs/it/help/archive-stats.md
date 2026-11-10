---
layout: help
title: Archivio e Statistiche
subtitle: Le viste Timeline e Tabella, più la schermata Statistiche (durata del ciclo, sintomi frequenti).
nav_title: Archivio e Statistiche
lang: it
lang_ref: help-archive-stats
permalink: /it/help/archive-stats/
help_order: 3
---

## Scheda Archivio

La scheda **Archivio** (icona onda) raccoglie l'intera storia delle tue registrazioni. Puoi visualizzarla in due modi, selezionabili con il cursore in cima alla schermata, e restringere l'elenco ai soli cicli che ti interessano con la ricerca e i filtri.

---

### Ricerca e filtri

Il filtro si apre dall'icona a imbuto che sta sulla stessa riga del cursore Timeline/Tabella, a destra. All'inizio è chiusa e l'elenco mostra tutti i cicli: toccala per far comparire il campo di ricerca e la fila di chip, toccala di nuovo per chiuderli e azzerare il filtro.

Ricerca e filtri valgono solo per la vista Timeline. La vista Tabella mostra sempre la storia completa e non ha ricerca né filtri: se ci passi con un filtro attivo, il filtro viene azzerato.

Il campo **Cerca nelle note** cerca nel testo delle note libere che hai scritto nella registrazione dei giorni. Non distingue maiuscole da minuscole e ignora gli accenti: *perche* trova anche *perché*. L'elenco si aggiorna circa 300 millisecondi dopo l'ultima lettera, non a ogni carattere. La X a destra del campo svuota il testo cercato.

Sotto il campo c'è una fila di chip, uno per ogni sintomo registrato nei tuoi cicli, con le etichette personalizzate che hai scritto tu. I chip restano gli stessi anche mentre un filtro è attivo. Tocca un chip per selezionarlo, toccalo di nuovo per toglierlo.

Ricerca e filtri si combinano: un ciclo resta in elenco solo se ha tutti i sintomi che hai selezionato e, se hai scritto qualcosa nel campo di ricerca, solo se almeno una delle sue note contiene il testo cercato.

Con un filtro attivo compare una riga con il numero di cicli che corrispondono (per esempio 3 cicli) e l'azione **Rimuovi filtri**, che azzera insieme testo e chip. Se nessun ciclo corrisponde, al posto dell'elenco compare il messaggio **Nessun ciclo corrisponde ai filtri**, con l'azione **Rimuovi filtri** per ripartire.

Quando esci dalla scheda e rientri, ricerca e filtri ripartono da zero e il pannello si richiude.

---

### Vista Timeline

![Vista Timeline: il cursore Timeline/Tabella con l'icona a imbuto a destra, sotto il campo di ricerca nelle note e la fila di chip sintomi aperti, poi la lista verticale di card ciclo, ognuna con data di inizio, durata, pill flusso e chip sintomi.](/assets/archive-timeline-it.png)

La vista Timeline raggruppa le tue registrazioni per **ciclo**, mostrando un ciclo per card, dall'ultimo in cima fino al primo in fondo. Ogni card mostra:

- **Data di inizio** e **durata del ciclo** in giorni.
- Una serie di etichette color pastello a rappresentare quanto registrato durante quel ciclo:
	- terracotta con una goccia per il **flusso**, con scritta l'intensità o spotting;
	- malva con un fumine, per il **dolore**, con la relativa intensità;
	- ocra con una stella, per i **sintomi**, per tutti i sintomi registrati durante quel ciclo;
	- grigie con una penna, a indicare le **note**.

Scorri verso l'alto per risalire nel tempo. Tocca una card per aprire il Calendario sul mese in cui è iniziato quel ciclo.

---

### Vista Tabella

![Vista Tabella: il cursore Timeline/Tabella senza imbuto, perché la Tabella non filtra, poi le righe dei cicli con le colonne Mese, Ciclo, Durata e Flusso.](/assets/archive-table-it.png)

La vista Tabella mostra una riga per ogni mese registrato, utile quando vuoi confrontare più mesi in un colpo d'occhio. Colonne:

| Colonna | Contenuto                                  |
| ------- | ------------------------------------------ |
| Mese    | Mese e anno.                               |
| Ciclo   | Numero di giorni del ciclo.                |
| Durata  | Numero di giorni di flusso mestruale.      |
| Flusso  | Intensità media del flusso mestruale.      |

---

## Scheda Statistiche

![Schermata Statistiche: quattro card riepilogative in alto, poi grafici a barre.](/assets/stats-overview-it.png)

La scheda **Statistiche** è la parte numerica dello stesso archivio: dove la Vista Timeline e la Tabella mostrano i singoli giorni, qui Mētra calcola medie e distribuzioni sull'insieme dei parametri registrati durante i cicli. Tutti i calcoli avvengono localmente sul tuo dispositivo, nessun servizio esterno vede questi numeri.

---

### Card di riepilogo

Quattro valori di sintesi in cima alla schermata:

| Card                           | Significato                                                          |
| ------------------------------ | -------------------------------------------------------------------- |
| **Durata media del ciclo**     | Media in giorni di tutti i cicli completi registrati.                |
| **Durata media flusso**        | Media dei giorni consecutivi di mestruazione per ciclo.              |
| **Intensità media del dolore** | Media del dolore registrato su tutti i cicli, su una scala da 0 a 3. |
| **Cicli tracciati**            | Numero totale di cicli completi nella tua storia.                    |

Queste card si aggiornano ogni volta che salvi una nuova registrazione.

---

### Grafico durata cicli

<!-- SCREENSHOT PLACEHOLDER: stats-cycle-chart.png -->
<!-- Grafico a barre: una barra per ciclo, altezza = durata in giorni, colore terracotta. -->

Un grafico a barre che mostra la durata di ogni ciclo in ordine cronologico. Se il tuo ritmo ha cambiato passo negli ultimi mesi, qui si vede.

---

### Grafico intensità del dolore

<!-- SCREENSHOT PLACEHOLDER: stats-pain-chart.png -->
<!-- Grafico a barre: una barra per ciclo, altezza = intensità media del dolore per quel ciclo, scala 0–3. -->

Un grafico a barre che mostra l'intensità media del dolore per ogni ciclo, in ordine cronologico, sulla stessa scala 0–3 usata durante la registrazione quotidiana. Mētra calcola questo valore localmente, senza trasmettere nulla. Un picco in un ciclo isolato è visibile a colpo d'occhio.

---

### Grafico frequenza sintomi

![Grafico a barre orizzontale: una barra per tipo di sintomo, lunghezza = percentuale di cicli in cui è comparso.](/assets/stats-symptoms-chart-it.png)

Un grafico a barre orizzontale che mostra con quale frequenza ogni sintomo è comparso nei tuoi cicli registrati. I sintomi più frequenti appaiono in cima. Nel tempo, un pattern che non avevi notato può diventare evidente.

> **Nessun dato?** Le statistiche richiedono almeno un ciclo completo registrato. Un ciclo si considera completo una volta registrato l'inizio del ciclo successivo.
