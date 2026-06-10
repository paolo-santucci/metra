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

La scheda **Archivio** (icona onda) raccoglie l'intera storia delle tue registrazioni. È la parte dell'app che non prevede azioni, solo lettura. Puoi visualizzarla in due modi, selezionabili con il cursore in cima alla schermata.

---

### Vista Timeline

![Vista Timeline: lista verticale di card ciclo, ognuna con data di inizio, durata, pill flusso e chip sintomi.](/assets/archive-timeline-it.png)

La vista Timeline raggruppa le tue registrazioni per **ciclo**, mostrando un ciclo per card, dall'ultimo in cima fino al primo in fondo. Ogni card mostra:

- **Data di inizio** e **durata del ciclo** in giorni.
- Una serie di etichette color pastello a rappresentare quanto registrato durante quel ciclo:
	- terracotta con una goccia per il **flusso**, con scritta l'intensità o spotting;
	- malva con un fumine, per il **dolore**, con la relativa intensità;
	- ocra con una stella, per i **sintomi**, per tutti i sintomi registrati durante quel ciclo;
	- grigie con una penna, a indicare le **note**.

Scorri verso l'alto per risalire nel tempo.

---

### Vista Tabella

![Vista Tabella: righe sono i giorni, colonne sono data, flusso, dolore, sintomi, note. Celle con codice colore.](/assets/archive-table-it.png)

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
