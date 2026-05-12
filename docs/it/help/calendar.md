---
layout: help
title: Calendario e linguaggio visivo
subtitle: Come leggere la griglia mensile, cosa significano colori e icone, come funzionano le previsioni.
nav_title: Calendario
lang: it
lang_ref: help-calendar
permalink: /it/help/calendar/
help_order: 1
---

La scheda **Calendario** è la schermata principale di Mētra. È qui che il linguaggio visivo dell'app prende forma: colori, icone, una finestra di previsione, un vocabolario piccolo, ma tutto da imparare.

---

## La griglia mensile

![Schermata calendario con un mese tipico: giorni di flusso, icone dei sintomi.](/metra/asset/calendar-overview-it.png)

Ogni giorno è una piccola cella. I giorni passati possono avere celle colorate e icone sotto il numero; i giorni futuri possono avere indicatori di previsione.

Tocca qualsiasi giorno per aprire il suo **pannello di dettaglio**, che mostra tutto ciò che è stato registrato per quella data.

Le frecce **← →** nell'intestazione spostano il mese; il pulsante **Oggi** riporta al mese corrente da qualsiasi punto. Puoi anche scorrere orizzontalmente sulla griglia: verso destra per il mese precedente, verso sinistra per quello successivo, ma lo scorrimento in avanti si ferma al mese successivo a quello corrente.

---

## Linguaggio visivo: i colori

Mētra usa un vocabolario cromatico fisso: quattro colori, quattro significati. Una volta che li conosci, un mese intero si legge a colpo d'occhio.

| Colore | Nome | Significato |
|---|---|---|
| **Terracotta** (rosso-arancio caldo) | Flusso | Un giorno con flusso mestruale o spotting registrato. |
| **Lavanda** (viola tenue) | Previsione | Un giorno che l'app prevede rientri nella prossima finestra mestruale. |
| **Ocra** (oro caldo) | Sintomi | Il giorno ha almeno un sintomo registrato (es. mal di testa, gonfiore). |
| **Malva** (rosa cipria) | Dolore | Il giorno ha un'intensità del dolore registrata. |

---

## Linguaggio visivo: le icone

Sei icone completano il vocabolario. Appaiono **sotto il numero del giorno** nella griglia e nel pannello di dettaglio.

| Icona                   | Significato                                                                |
| ----------------------- | -------------------------------------------------------------------------- |
| Goccia piena            | Mestruazione registrata per questo giorno.                                 |
| Goccia vuota (contorno) | Mestruazione prevista (nessuna registrazione ancora).                      |
| Stella                  | Almeno un sintomo registrato.                                              |
| Fulmine                 | Intensità del dolore registrata.                                           |
| Penna                   | Una nota in testo libero è presente per questo giorno.                     |

---

## La striscia legenda

![La striscia legenda sotto l'intestazione dei giorni della settimana: le cinque icone con le loro etichette.](/metra/assets/calendar-legend-it.png)

La striscia legenda si trova appena sotto la griglia del calendario. Mostra le cinque icone descritte sopra con le relative etichette: il vocabolario completo, sempre a portata di sguardo.

---

## Le previsioni

La matematica è aperta, non in una scatola nera. Mētra calcola la data di inizio prevista del prossimo ciclo usando una **media mobile ponderata** degli ultimi sei cicli registrati; i cicli più recenti hanno peso maggiore. Nessuna intelligenza artificiale, nessun modello opaco, la formula è documentata nel codice sorgente.

- La finestra di previsione appare come **celle con contorno lavanda** nel calendario.
- La previsione si aggiorna automaticamente ogni volta che salvi una registrazione che avvia un nuovo ciclo.

> **Nessun ciclo registrato ancora?** La previsione si basa sui valori inseriti durante il primo avvio. Diventa più precisa dopo due o tre cicli.

---

## Il pannello di dettaglio del giorno

Tocca un giorno per aprire un pannello che raccoglie tutto ciò che riguarda quella data:

- Un'etichetta **"Giorno N"** indica a che punto sei nel ciclo corrente.
- **Pill flusso** — il tipo e l'intensità del flusso registrato, oppure lo stato previsto.
- **Pill dolore** — il livello di dolore (Lieve / Moderato / Intenso), se registrato.
- **Chip sintomi** — un chip per ogni sintomo registrato quel giorno.
- **Note** — la nota in testo libero, se presente.
- Pulsante **Aggiungi giornata** o **Modifica giornata** — apre la [schermata di registrazione](/it/help/daily-entry/) per quel giorno.
