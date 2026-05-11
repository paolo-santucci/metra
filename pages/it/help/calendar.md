---
layout: page
title: Calendario e linguaggio visivo
---

[← Torna alla Guida](/metra/help/it/) &nbsp;·&nbsp; [🇬🇧 English](/metra/help/calendar)

La scheda **Calendario** è la schermata principale di Métra. Mostra una griglia mensile in cui ogni giorno porta informazioni visive su ciò che hai registrato — o su ciò che l'app prevede.

---

## La griglia mensile

<!-- SCREENSHOT PLACEHOLDER: calendar-overview.png -->
<!-- Schermata calendario con un mese tipico: giorni di flusso, finestra di previsione, puntini di sintomi. -->

Ogni giorno è una piccola cella. I giorni passati possono avere celle colorate e icone sotto il numero del giorno; i giorni futuri possono avere indicatori di previsione.

Tocca qualsiasi giorno per aprire il suo **pannello di dettaglio**, che mostra tutto ciò che è stato registrato per quella data.

Usa le frecce **← →** nell'intestazione per spostarti tra i mesi.

---

## Linguaggio visivo — i colori

Métra usa un vocabolario cromatico fisso. Una volta imparato, puoi leggere un intero mese a colpo d'occhio.

| Colore | Nome | Significato |
|---|---|---|
| **Terracotta** (rosso-arancio caldo) | Flusso | Un giorno registrato come mestruazione (normale o spotting). |
| **Lavanda** (viola tenue) | Previsione | Un giorno che l'app prevede cada nella prossima finestra di mestruazioni. |
| **Ocra** (oro caldo) | Sintomi | Il giorno ha almeno un sintomo registrato (es. mal di testa, gonfiore). |
| **Malva** (rosa cipria) | Dolore | Il giorno ha un'intensità del dolore registrata. |

---

## Linguaggio visivo — le icone

Piccole icone appaiono **sotto il numero del giorno** nella griglia e nel pannello di dettaglio.

| Icona | Significato |
|---|---|
| Goccia piena | Mestruazione registrata per questo giorno. |
| Goccia vuota (contorno) | Mestruazione prevista (nessuna registrazione ancora). |
| Stella a quattro punte | Almeno un sintomo registrato. |
| Fulmine | Intensità del dolore registrata. |
| Luna crescente | Indicatore del giorno del ciclo corrente nell'intestazione del calendario. |

---

## La striscia legenda

<!-- SCREENSHOT PLACEHOLDER: calendar-legend.png -->
<!-- La striscia legenda sotto l'intestazione dei giorni della settimana: le quattro icone con le loro etichette. -->

Una striscia legenda si trova appena sotto l'intestazione dei giorni della settimana (L M M G V S D). Mostra tutte e quattro le icone con le relative etichette, così non devi memorizzarle.

---

## Le previsioni

Métra calcola la data di inizio prevista del prossimo ciclo usando una **media mobile ponderata** degli ultimi sei cicli registrati. I cicli più recenti hanno peso maggiore.

- La finestra di previsione appare come **celle con contorno lavanda** nel calendario.
- Un'etichetta **"Giorno N"** nell'intestazione del calendario mostra a che punto sei nel ciclo corrente.
- La previsione si aggiorna automaticamente ogni volta che salvi una registrazione che avvia un nuovo ciclo.

L'app usa matematica trasparente — nessun algoritmo opaco, nessuna pretesa di "intelligenza artificiale". La formula è documentata nel codice sorgente.

> **Nessun ciclo registrato ancora?** La previsione si basa sui valori inseriti durante il primo avvio. Diventa più precisa dopo due o tre cicli.

---

## Il pannello di dettaglio del giorno

<!-- SCREENSHOT PLACEHOLDER: calendar-day-detail.png -->
<!-- Pannello di dettaglio: pill del flusso, pill del dolore, chip dei sintomi, note. -->

Toccando un giorno si apre un pannello con:

- **Pill flusso** — il tipo e l'intensità del flusso registrato, oppure lo stato previsto.
- **Pill dolore** — il livello di dolore (Lieve / Moderata / Intensa), se registrato.
- **Chip sintomi** — un chip per ogni sintomo registrato quel giorno.
- **Note** — la nota in testo libero, se presente.
- **Pulsante Modifica** — apre la [schermata di registrazione](daily-entry) per quel giorno.

---

[← Torna alla Guida](/metra/help/it/)
