---
layout: help
title: Importa ed esporta (CSV)
subtitle: "Come esportare tutti i tuoi dati, modificarli in un foglio di calcolo e reimportarli; riferimento completo alle colonne."
nav_title: Importa ed esporta (CSV)
lang: it
lang_ref: help-import-export
permalink: /it/help/import-export/
help_order: 5
---

CSV è un formato aperto: nessun vendor lock-in, nessun algoritmo proprietario di mezzo, leggibile con qualsiasi foglio di calcolo o editor di testo. Mētra lo usa per import ed export perché è il formato che ti permette di portare via tutto, in qualsiasi momento. L'export contiene esattamente quello che hai registrato: Mētra non ha nessun altro concetto di "tua attività".

Casi d'uso concreti:

- Tenere un backup locale apribile in qualsiasi foglio di calcolo.
- Migrare i dati da un'altra app (se riesci a produrre il formato corretto).
- Modificare in blocco registrazioni passate fuori dall'app.
- Archiviazione a lungo termine in un formato aperto e non proprietario.

---

## Esportare i tuoi dati

<!-- SCREENSHOT PLACEHOLDER: settings-export.png -->
<!-- Schermata Impostazioni con la riga "Esporta CSV" evidenziata. -->

1. Vai in **Impostazioni**.
2. Tocca **Esporta CSV**.
3. Si apre il pannello di condivisione standard del dispositivo. Puoi salvare il file localmente, inviarlo al computer, o aprirlo direttamente in un foglio di calcolo.

L'export include una riga per ogni giorno con dati registrati, in ordine cronologico inverso (il più recente prima). I giorni senza registrazioni non sono inclusi.

---

## Importare i dati

<!-- SCREENSHOT PLACEHOLDER: settings-import.png -->
<!-- Schermata Impostazioni con la riga "Importa CSV" evidenziata. Dialog di conferma importazione. -->

1. Vai in **Impostazioni**.
2. Tocca **Importa CSV**.
3. Seleziona il file `.csv` dalla memoria del dispositivo.
4. Mētra analizza il file. Se alcune righe contengono errori, Mētra mostra un riepilogo prima di confermare, puoi annullare in questa fase.
5. Mētra apre il dialogo **Modalità importazione**. Scegli una delle tre opzioni descritte qui sotto.
6. Conferma per applicare.

### Modalità importazione

| Modalità                        | Cosa fa                                                                                                                                  |
| ------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| **Elimina tutto e importa**     | Cancella l'intero database, poi importa il file. Tutte le registrazioni esistenti vengono rimosse, incluse quelle non presenti nel file. |
| **Importa e sovrascrivi**       | Per ogni data nel file, sostituisce la registrazione esistente (se presente). Le date non presenti nel file non vengono modificate.      |
| **Importa, mantieni esistenti** | Importa solo le date che non hanno ancora una registrazione. Le registrazioni esistenti non vengono mai modificate.                      |

> ⚠️ **Attenzione — "Elimina tutto e importa" è irreversibile.** Prima di usare questa modalità, esegui un backup su cloud o un export come backup. Non è possibile annullare dopo la conferma.

---

## Riferimento al formato CSV

Il file segue le convenzioni standard: **codifica UTF-8**, **virgola come separatore** e **terminazioni di riga `\n`**. La prima riga è sempre l'intestazione. I valori che contengono virgole o doppi apici vengono racchiusi in doppi apici secondo lo standard RFC 4180.

### Riferimento alle colonne

| Colonna          | Tipo    | Obbligatoria | Descrizione                                                                                                                                                                                                                  |
| ---------------- | ------- | ------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `date`           | Stringa | **Sì**       | Data in formato `YYYY-MM-DD` (es. `2025-04-15`). Deve essere una data di calendario valida.                                                                                                                                  |
| `flow_type`      | Intero  | **Sì**       | Tipo di flusso categoriale. Vedi [Valori di flow_type](#valori-di-flow_type).                                                                                                                                                |
| `flow`           | Intero  | No           | Intensità del flusso mestruale. Vedi [Valori di flow](#valori-di-flow). Significativo solo quando `flow_type` è `1`. Se `flow_type` è `1` e questa colonna è vuota, l'intensità assume il valore predefinito `1` (Moderato). |
| `pain_intensity` | Intero  | No           | Livello di dolore: `1` = Lieve, `2` = Moderato, `3` = Intenso. Vuoto = nessun dolore registrato.                                                                                                                             |
| `symptoms`       | Stringa | No           | Lista di token sintomi separata da punto e virgola. Vuota o omessa se nessuno. Vedi [Token sintomi](#token-sintomi).                                                                                                         |
| `notes`          | Stringa | No           | Nota in testo libero. Vuota o omessa se assente. Racchiusa in doppi apici se contiene virgole o ritorni a capo.                                                                                                              |
| `cycle_start`    | Intero  | No           | `1` se questo giorno è l'inizio di un nuovo ciclo, `0` altrimenti. **Solo export** — questa colonna viene ignorata in import. Mētra ricalcola i confini del ciclo automaticamente.                                           |

---

### Valori di flow_type

La colonna `flow_type` codifica uno di tre stati mutuamente esclusivi:

| Valore | Significato |
|---|---|
| `0` | **Assente** — hai confermato esplicitamente nessun sanguinamento. |
| `1` | **Mestruazioni** — flusso mestruale attivo. L'intensità `flow` è significativa. |
| `2` | **Spotting** — perdite leggere e irregolari. L'intensità `flow` viene ignorata. |

`flow_type` è obbligatorio in ogni riga. Usa `0` (Assente) per registrare esplicitamente un giorno senza sanguinamento.

---

### Valori di flow

La colonna `flow` è significativa solo quando `flow_type` è `1` (Mestruazioni). Se omessa o vuota con `flow_type=1`, l'intensità viene registrata come **Moderato** (`1`).

| Valore | Significato                                                         |
| ------ | ------------------------------------------------------------------- |
| `0`    | Leggero                                                             |
| `1`    | Moderato — valore predefinito quando `flow_type=1` e `flow` è vuoto |
| `2`    | Abbondante                                                          |

---

### Token sintomi

La colonna `symptoms` è una lista di token separata da punto e virgola. I token distinguono maiuscole e minuscole.

**Token predefiniti:**

| Token              | Significato       |
| ------------------ | ----------------- |
| `backPain`         | Mal di schiena    |
| `headache`         | Mal di testa      |
| `bloating`         | Gonfiore          |
| `fatigue`          | Stanchezza        |
| `nausea`           | Nausea            |
| `breastTenderness` | Tensione mammaria |

**Sintomi personalizzati** usano il prefisso `custom:` seguito dal testo dell'etichetta, es. `custom:Dolore pelvico`. L'etichetta viene riprodotta esattamente come digitata.

**Esempio** — una riga con due sintomi, uno predefinito e uno personalizzato:

```
symptoms
headache;custom:Dolore pelvico
```

Più sintomi nella stessa cella:

```
headache;backPain;bloating
```

---

### File di esempio

```csv
date,flow_type,flow,pain_intensity,symptoms,notes,cycle_start
2025-05-01,1,0,2,headache;bloating,Primo giorno,1
2025-05-02,1,1,1,headache,,0
2025-05-03,1,1,,,, 0
2025-05-04,1,0,,,Mi sento meglio,0
2025-05-05,0,,,,, 0
2025-05-06,0,,,,,0
```

---

## Risoluzione degli errori di importazione

Se Mētra rifiuta alcune righe, viene mostrata una lista di errori prima di confermare l'importazione. Ogni errore specifica:

- **Numero di riga** nel file (l'intestazione è la riga 1, quindi i dati iniziano dalla riga 2).
- **Colonna** in cui è stato trovato il problema.
- **Valore grezzo** rifiutato.
- **Motivo** — una spiegazione in linguaggio semplice.

La maggior parte degli errori ricade in categorie prevedibili. Le date nel formato `15/04/2025` sono un inciampo frequente — Mētra si aspetta `2025-04-15`. `flow_type` mancante è l'altro caso più comune, specialmente nei file prodotti da altre app.

| Problema | Soluzione |
|---|---|
| `date` non in formato `YYYY-MM-DD` | Cambia `15/04/2025` → `2025-04-15`. |
| `date` mancante | Ogni riga deve avere una data. Le righe senza data vengono saltate. |
| `flow_type` mancante o fuori intervallo | `flow_type` è obbligatorio. Usa `0`, `1` o `2`. |
| `flow` fuori intervallo | Usa `0`, `1`, `2`, o lascia vuoto (predefinito `1` quando `flow_type=1`). |
| `pain_intensity` fuori intervallo | Usa `1`, `2`, `3`, o lascia vuoto. |

Le righe con errori vengono saltate; le righe valide vengono comunque importate.
