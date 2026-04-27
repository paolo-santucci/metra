# Design Brief — Métra

**Deliverable richiesto:** Mockup ad alta fedeltà delle schermate principali dell'app mobile **Métra**, ottimizzate per iOS e Android (Flutter 3.x), in light e dark mode, con specifiche di design system riutilizzabili.

---

### 1. Contesto del prodotto

**Cos'è Métra.** Un'app mobile gratuita e open-source per il tracciamento del ciclo mestruale, privacy-first. Local-first: tutti i dati vivono sul dispositivo dell'utente, cifrati. Il backup cloud è opzionale e end-to-end encrypted, su provider scelto dall'utente (Google Drive, Dropbox, OneDrive).

**Cosa Métra non è.** Non è un fertility tracker. Non è una community. Non è un servizio SaaS. È un _quaderno digitale intimo_ — più vicino a un Moleskine che a un'app di fitness.

**L'utente tipo.** Una persona adulta che vuole conoscere il proprio ritmo senza cedere dati a terzi. Non cerca gamification, non cerca consigli, non cerca confronti con altre utenti. Cerca uno strumento silenzioso, elegante, rispettoso.

**Il nome.** _Mētra_ (con macron come firma tipografica sul logo; _Métra_ o _Metra_ nelle scritture informali). Dal greco antico ῥμήτρα = utero, stessa radice IE di madre, misura, matrice. Il nome stesso è la promessa: un'app che torna alle origini.

---

### 2. Anima del design

Il design deve trasmettere **tre sensazioni simultanee**: calore organico, antichità serena, custodia silenziosa. Se una sola di queste manca, il design ha fallito.

**Calore organico.** L'app deve sentirsi come un oggetto di terracotta in mano — tiepida, terrosa, imperfetta nei dettagli giusti. Niente superfici vetrose, niente neon, niente gradient aggressivi. Forme arrotondate ma non puerili. Texture sottili (grana della carta, velatura organica) usate con discrezione.

**Antichità serena.** Métra ha una radice millenaria. Il design deve evocare qualcosa che esiste da sempre: le proporzioni della ceramica greca, la tipografia dei libri stampati, il silenzio di un chiostro. Non "vintage" né "retrò" — piuttosto _atemporale_. Un'app che potrebbe essere esistita sia nel 1950 sia nel 2050.

**Custodia silenziosa.** Ogni elemento grafico deve comunicare che i dati dell'utente sono al sicuro. Serrature, cerchi chiusi, forme che contengono. Nessun elemento che suggerisca "condivisione", "social", "connessione esterna". L'architettura visiva è introversa.

**Anti-patterns da rifiutare esplicitamente:**

- Rosa pastello saccarino e lingua "Hey girl!"
- Gamification: streak, badge, livelli, progress bar motivazionali
- Glassmorphism aggressivo, neumorfismo anni '20, stile iOS 7 flat
- Illustrazioni 3D stile Dribbble con personaggi carini
- Emoji decorative nell'UI (l'app è un luogo serio di intimità, non un chat)
- Dark mode che è solo "light mode invertita": deve essere progettata come esperienza propria

---

### 3. Sistema cromatico

**Palette light mode (proposta di partenza, raffinabile):**

- _Sabbia_: `#F4EDE2` (background primario, caldo avorio terroso)
- _Terracotta_: `#C87456` (accento primario, flusso, attenzione)
- _Ocra polverosa_: `#D4A26A` (accento secondario, warmth)
- _Lavanda notte_: `#5B4E7A` (accento cool per previsioni e dati futuri)
- _Muschio_: `#7A8471` (verde smorzato per conferme, stati "ok")
- _Inchiostro_: `#2B2521` (testo primario — mai nero puro)

**Palette dark mode (non inversione):**

- _Notte fonda_: `#1A1410` (background, marrone-nero caldo)
- _Terracotta spenta_: `#B86848` (flusso)
- _Lavanda chiara_: `#9B8FBF` (previsioni)
- _Avorio_: `#EDE4D3` (testo primario — mai bianco puro)

**Regole cromatiche.** Il colore non è mai decorativo: ogni tinta ha un significato semantico. Terracotta = flusso corrente. Lavanda = previsione futura. Muschio = registrato con successo. Ocra = accenti neutri caldi. La palette deve superare il test del daltonismo (usare icone e forme oltre al colore per comunicare stato). Mai affidare un'informazione critica al solo colore.

---

### 4. Tipografia

**Coppia proposta:**

- _Headings:_ **DM Serif Display** — serif moderno con grazie aperte, evoca la tipografia dei libri stampati senza essere vintage. Per titoli di sezione, numeri di giorno, accenti editoriali.
- _Body e UI:_ **Inter** — sans-serif contemporaneo, leggibilità impeccabile a tutte le dimensioni, ottimo per interfacce. Per testo corrente, bottoni, micro-copy.

**Regole.** Gerarchia massimo a 4 livelli (display, title, body, caption). Line-height generoso (1.5 per body, 1.2 per display). Dimensione minima body: 16pt. Font supportano piena localizzazione IT + EN + estensione futura. Il wordmark "Mētra" usa DM Serif Display con macron grafico distintivo (la linea orizzontale sopra la _e_ può diventare elemento di identità visiva — richiamo all'orizzonte, alla luna piena, al cerchio aperto).

---

### 5. Linguaggio iconografico

Stile: **line icons da 1.5–2pt stroke**, terminazioni arrotondate, angoli smussati. Mai icone piene (troppo aggressive), mai icone duotone (troppo Dribbble). Riferimento visivo: le illustrazioni di libri di botanica del XIX secolo, depurate e ridotte all'essenziale.

Elementi grafici ricorrenti da sviluppare come linguaggio visivo: fasi lunari (cerchi pieni/crescenti/calanti), onde sottili, spirali aperte, piccole stelle minuscole. Usare con parsimonia — meglio un'icona in meno che una di troppo.

**Illustrazioni.** Se presenti (schermata vuota, onboarding, stati d'errore), devono essere line-art organiche, monocromatiche o due colori max, mai con personaggi umani. Suggerimento: elementi naturali (una conchiglia spiralata, una luna velata, un ramo fiorito) — metafore più che mascotte.

---

### 6. Schermate da consegnare

#### 6.1 Onboarding (3 schermate)

Primo contatto con l'utente. Deve fare tre cose, in quest'ordine:

1. Presentare Métra con una frase del manifesto (_"Un'app per ascoltare la tua misura"_).
2. Spiegare la promessa di privacy in un'immagine grafica, non in un testo legale (visualizzazione concettuale: telefono con lucchetto, cloud opzionale separato da una linea netta).
3. Chiedere solo il minimo indispensabile: data dell'ultimo ciclo noto (se la conosce), lunghezza media ciclo (con default 28, modificabile). Tutto il resto si configura dopo.

Tono: accogliente, mai paternalistico. L'utente è adulta, lo sa fare.

#### 6.2 Calendario (home principale)

Vista mensile. Giorni come cerchi (non quadrati) — le forme rotonde rinforzano il tema ciclico. Giorno corrente evidenziato con anello sottile, non con fill. Codifica:

- _Terracotta piena_ = giorni di flusso registrati
- _Terracotta sfumata / outline_ = flusso leggero o spotting
- _Lavanda outline_ = previsione prossimo ciclo (fascia di 3-5 giorni, non un singolo giorno)
- _Punto ocra_ = giorno con note o sintomi registrati

Swipe orizzontale cambia mese. Tap su giorno apre il data entry.

In alto: indicatore di fase ciclo attuale in linguaggio non-clinico ("Giorno 14 del tuo ritmo" invece di "Giorno 14 del ciclo"). A destra: piccola indicazione fase lunare corrispondente (ornamentale, non funzionale).

#### 6.3 Registrazione giornaliera (quick entry)

Deve essere completabile in ≤3 tap/gesti. La schermata è a lista verticale, densità media, nessun scroll necessario per le sezioni core.

Le due interazioni principali — flusso e dolore — sono progettate come **gesti naturali che evocano il corpo**, non come controlli tecnici. Il risultato deve essere ipnotico, tattile, degno di screenshot — ma mai giocoso o gamificato.

**Flusso — "Rising Fill" (trascinamento verticale)**

Un cerchio terracotta di 120×120pt al centro della zona. L'utente trascina il dito verso l'alto sull'intera area (non solo sul cerchio): il liquido sale dal basso come acqua in un vaso. Ogni ~28pt di spostamento verticale avanza di un livello. I 5 livelli sono: _nessuno_ (0%) / _spotting_ (18%) / _leggero_ (40%) / _medio_ (65%) / _abbondante_ (90%).

Dettagli dell'animazione:

- **Superficie liquida ondeggiante.** Il bordo superiore del riempimento non è una linea dritta: ondeggia in modo organico animando il `border-radius` (ciclo asimmetrico di 2.2s, ease-in-out, infinite). Riferimento: la superficie di un liquido in una coppa tenuta in mano.
- **Gradiente del liquido.** `linear-gradient(180deg, rgba(200,116,86,0.82) 0%, #C87456 100%)` — più luminoso in alto, più denso in basso, a simulare la profondità.
- **Transizione dell'altezza.** `0.18s cubic-bezier(0.25, 0.46, 0.45, 0.94)` — rapida ma con coda morbida, mai meccanica.
- **Label del livello.** Posizionata **sopra** il cerchio (non sotto: il pollice dell'utente non deve nasconderla durante il gesto). DM Serif Display italic 22pt, colore terracotta. Invisibile a livello 0; appare con fade-in 0.28s quando il livello sale da 0; scompare con fade-out 0.28s quando il livello torna a 0. Quando il livello cambia da un valore non-zero a un altro (es. da _leggero_ a _medio_), esegue un **cross-fade morbido**: la label precedente sfuma mentre quella nuova appare, con fade-out 0.14s e fade-in 0.14s in parallelo (overlap totale). Sotto il cerchio, un hint "Trascina verso l'alto per registrare" in Inter 12pt opacity 0.38 — svanisce con lo stesso fade appena inizia l'interazione.
- **Feedback aptico.** Vibrazione corta (~10ms) ad ogni cambio di livello.
- **Micro-animazione al rilascio.** Il cerchio esegue un pulse — `scale(1) → 1.07 → 0.98 → 1` in 350ms con `cubic-bezier(0.36, 0.07, 0.19, 0.97)`. La shadow si espande brevemente (`0 4px 32px rgba(200,116,86,0.4)`) e rientra. È il "respiro" che dice "ricevuto".
- **Nessun label laterale, nessun marker tick.** La metafora del contenitore che si riempie è sufficiente; aggiungere etichette tecniche al lato romperebbe il tono.

Al primo avvio dell'app, un overlay tutorial spiega l'interazione con un'animazione dimostrativa (un cerchio che si riempie e si svuota in loop, con un indicatore di dito che sale — durata 2.4s in loop). L'overlay si chiude con un tap su "Ho capito" e non riappare.

**Dolore — "Pain Pulse" (long press)**

Un cerchio lavanda di 140×140pt. L'utente **tiene premuto**; il cerchio inizia immediatamente a pulsare come un battito. Ogni ~780ms di pressione sostenuta, il livello avanza di uno (1→3). Rilasciando si conferma il livello corrente.

Le 3 intensità sono: _lieve / moderato / intenso_ — mai numeri, mai 1-10.

La pressione produce **tre animazioni simultanee**, tutte sincronizzate:

- **Pulse del riempimento.** Un cerchio interno lavanda scala da 0.82 a 0.95 in loop. La durata dell'animazione varia per livello:
    - Livello 1 (lieve): 2.4s — quasi un respiro
    - Livello 2 (moderato): 1.3s — ritmo costante
    - Livello 3 (intenso): 0.55s — rapido, ansioso
  L'opacità del riempimento aumenta con il livello: 0.18/0.30 (lieve), 0.30/0.50 (moderato), 0.50/0.75 (intenso) min/max.
- **Wobble del bordo.** Il bordo del cerchio si deforma con `border-radius` asimmetrico animato (stesso principio del liquido del flusso, ma applicato al perimetro intero). La velocità di deformazione scala col livello: 3.8s (lieve) → 2.0s (moderato) → 0.85s (intenso). Più alto il dolore, più inquieto il bordo.
- **Glow esterno.** Un alone radiale `rgba(91,78,122,0.25)` appare attorno al cerchio durante la pressione (fade-in 0.4s), scompare al rilascio.

Guida temporale: un **arco SVG sottile** (stroke 1.5pt, `#9B8FBF`) ruota attorno al cerchio e si riempie da 0% a 100% in ~2.4 secondi totali (il tempo necessario a raggiungere il livello 3). Sparisce al rilascio. È un indicatore implicito — non un timer visibile in secondi.

Stati visivi:

- **Label del livello** sopra il cerchio: DM Serif Display italic 26pt, colore lavanda. Segue esattamente la stessa logica della label del flusso: invisibile a livello 0; fade-in 0.28s quando il livello sale da 0; fade-out 0.28s quando torna a 0; **cross-fade morbido** (fade-out 0.14s + fade-in 0.14s in parallelo, overlap totale) quando cambia da un livello all'altro (es. da _lieve_ a _moderato_).
- **Tre dot** sotto il cerchio (7×7pt, lavanda): si riempiono progressivamente e scalano a 1.3× con `cubic-bezier(0.34, 1.56, 0.64, 1)` al cambio di livello.
- **Al rilascio**: bloom di conferma — `scale(1) → 1.18 → 0.96 → 1` in 450ms. Il cerchio si stabilizza statico (wobble e pulse si fermano), il riempimento rimane visibile all'opacità del livello confermato. Feedback aptico pattern `[10, 30, 10]`: un doppio tap morbido — la firma sonora della conferma.

**Correzione fine post-rilascio.** Dopo il rilascio, per circa **3 secondi**, i tre dot sotto il cerchio rimangono tappabili: un tap su un dot porta direttamente al livello corrispondente senza dover ripetere il gesto di pressione. Durante questa finestra i dot crescono leggermente (da 7×7pt a 10×10pt) con transizione 0.2s, per segnalare visivamente che sono interattivi; il cerchio resta statico con il riempimento del livello corrente. Trascorsi 3 secondi senza interazione, i dot tornano al loro stato indicativo (7×7pt, non tappabili) e il valore è considerato confermato definitivamente. Questa finestra risolve il caso in cui l'utente, durante il long press, oltrepassa il livello desiderato: invece di ripetere tutto il gesto, tocca il dot giusto. Il tap su un dot innesca un micro-bloom più contenuto del cerchio (`scale(1) → 1.08 → 1` in 250ms), un cross-fade della label del livello (come sopra) e un feedback aptico leggero (~10ms).

Per modificare il valore dopo che la finestra di 3 secondi è scaduta, l'utente ripete il gesto completo (premi, tieni, rilascia).

**Sintomi e note**

- **Chip tipologie dolore**: pill button minimalisti (Crampi / Schiena / Testa / Emicrania / + altro). Bordo 1.5pt, border-radius 20pt. Selezionati: border e testo lavanda, background `rgba(91,78,122,0.10)`. Toggle semplice al tap.
- **Note libere**: textarea border-radius 14pt, height 68pt, max 500 caratteri. Focus: border lavanda. Placeholder in italiano discreto ("Note libere…"). **Nessuna AI suggestion, nessun autocomplete, nessun correttore invadente.**

**Pulsante Salva**

Full-width, border-radius 16pt, background terracotta piena `#C87456`, testo sabbia, Inter 15pt weight 600. Active: `scale(0.98)` + background `#A85C3E`. Niente altri CTA che distraggano — né "Annulla", né "Elimina", né "Condividi". La chiusura avviene dalla X in alto a destra; la X non cancella nulla, semplicemente torna al calendario senza salvare (con conferma se c'è un'entry non salvata).

**Regole trasversali di queste interazioni**

- **Mai esporre numeri.** L'utente vede etichette qualitative (lieve, abbondante), mai scale numeriche.
- **Mai gamification.** Il pulse del dolore non "premia" l'utente; descrive uno stato. Il fill del flusso non è una progress bar; è un contenitore.
- **Accessibilità**: entrambe le interazioni devono avere un fallback tap-based per chi non può fare gesti prolungati (impostazione nelle preferenze di accessibilità o attiva automaticamente con `reduceMotion`). In modalità fallback, tap ripetuti sul cerchio avanzano il livello; long-press conferma.
- **Reduce motion**: se il setting di sistema è attivo, wobble/pulse/glow si sostituiscono con un semplice cross-fade 200ms tra stati discreti. L'interazione resta la stessa; solo l'animazione continua diventa statica.

**Fuori scope per questa schermata (v1):** tracciamento di secrezioni/perdite non mestruali. Sarà valutato in versioni successive se richiesto dalle utenti.

#### 6.4 Timeline + Tabella (toggle)

Due viste della stessa cronologia:

- _Timeline_: scroll verticale, un'entry per giorno, formato narrativo (dataa + riassunto sintetico)
- _Tabella_: griglia densa, colonne per categoria, ordinabile

Il toggle è un segmented control minimalista, non due tab separate.

#### 6.5 Statistiche

Quattro schede scrollabili:

1. Lunghezza media ciclo (numero grande + micro-grafico ultimi 6 cicli)
2. Durata media flusso
3. Frequenza sintomi (bar chart orizzontale, sintomi in ordine di frequenza)
4. Cronologia ultimi 12 cicli (fl_chart line)

Stile grafici: linee sottili, aree con fill a bassa opacità (~15%), assi discreti, nessuna griglia pesante. Zero emoji, zero celebrazioni ("Il tuo ciclo più lungo!" → no). Dati come dati, nessun commento editoriale dell'app.

#### 6.6 Impostazioni

Struttura a sezioni raggruppate:

- _Il tuo ritmo_ (lunghezza media, toggle per tracciare dolore/note/altro)
- _Notifiche_ (giorni prima, orario, toggle generale)
- _Aspetto_ (tema: automatico/chiaro/scuro; lingua)
- _Backup_ (stato, provider, ultima sincronizzazione, "Sincronizza ora", "Cambia provider")
- _Dati_ (Esporta CSV, Importa CSV, Elimina tutto)
- _Su Métra_ (versione, link al codice su GitHub, privacy policy, licenza GPL-3.0)

Stile list: rows con padding generoso, separatori sottili (non divider pesanti), chevron solo dove effettivamente porta a sub-view.

#### 6.7 Flusso di backup cloud (3-4 schermate)

Deve essere rassicurante e trasparente. Schermata che spiega graficamente: "I tuoi dati vengono cifrati sul tuo telefono prima di partire. Il provider vede solo un file illeggibile." Usa illustrazione concettuale: flusso da telefono → blob cifrato → cloud. Scegli provider (Google Drive / Dropbox / OneDrive come card orizzontali). Autorizzazione OAuth nativa del provider. Schermata finale di conferma con data-ora ultimo backup.

#### 6.8 Stati vuoti

Almeno 3 da progettare: primo avvio senza dati, statistiche senza cicli sufficienti, ricerca senza risultati. Tono del microcopy: presenza serena, non scuse né promesse. Illustrazione minimale line-art, una frase breve, un CTA se appropriato.

---

### 7. Accessibilità (WCAG 2.2 AA minimum, AAA dove possibile)

L'accessibilità non è un livello "da aggiungere dopo": è parte integrante del design che consegni. Qualunque mockup che viola queste regole va rifatto, non corretto.

**Contrasto colore.** Testo normale: ratio minimo 4.5:1. Testo large (≥18pt regular o ≥14pt bold): 3:1. Elementi UI non testuali (icone, bordi di input): 3:1 contro il loro sfondo. Questo vale sia in light che in dark mode. La palette terracotta/sabbia deve essere verificata — probabilmente il terracotta `#C87456` su sabbia `#F4EDE2` non passa AA per testo piccolo; servirà una variante più scura per il testo.

**Target tattili.** Tutti gli elementi interattivi ≥44×44pt (iOS HIG) e ≥48×48dp (Material). Include i cerchietti dei giorni sul calendario — che dovranno quindi essere grandi almeno così, oppure avere un'area di tap invisibile estesa.

**Dynamic Type.** Il layout deve reggere il testo ingrandito fino a 200% senza rompersi. Niente testo in immagini (eccetto il logo). Niente troncamenti con "..." su label critiche. Testa specificamente la schermata calendario e la tabella — sono i punti più a rischio.

**Color-blind safety.** Nessuna informazione comunicata dal solo colore. Flusso/previsione/registrato devono essere distinguibili anche per chi ha deuteranopia o protanopia: usa forme diverse (cerchio pieno vs outline vs punto), icone, pattern sottili oltre al colore. Testare la palette con simulatori (es. Stark plugin di Figma).

**Screen reader.** Ogni elemento interattivo ha una label semantica significativa ("Flusso medio, 15 aprile" non "cerchio rosso"). Ordine di lettura logico, landmark ARIA corretti, annunci di stato per operazioni asincrone (backup completato, salvataggio riuscito). In Flutter: `Semantics` widget su tutti i custom painter del calendario. Deve essere testato con TalkBack e VoiceOver.

**Reduce motion.** Rispettare il setting di sistema. Animazioni di transizione devono avere un fallback statico o un cross-fade leggero. Niente parallax, niente auto-scroll, niente elementi che si muovono senza interazione dell'utente.

**Focus visibile.** Per navigazione da tastiera esterna (iPadOS, Android con Bluetooth keyboard): indicatore di focus chiaro, minimo 2pt di outline ad alto contrasto. Non affidare il focus al solo cambio di colore.

**Linguaggio inclusivo.** Tutte le label devono essere declinate al femminile come neutro semantico (l'utenza primaria è donna cis), ma evitare formulazioni che escludano utenti trans o non-binari che potrebbero usare l'app. Evitare "madre natura", "ogni donna sa che...", riferimenti a maternità come scopo implicito. Parla dell'utente come "tu", mai come "le donne".

**Localizzazione.** Mockup in italiano come principale, con testi di prova anche in inglese per verificare che il layout regga testi più lunghi (IT tende a essere 20-30% più lungo di EN). Prevedere pseudo-localizzazione come verifica.

---

### 8. Deliverables attesi

File Figma organizzato con:

- Cover: mockup hero delle 3 schermate più rappresentative (light mode)
- Pagina _Design System_: colori (con nome + ruolo semantico + hex), tipografia (scala completa), iconografia (libreria), componenti base (button, input, card, list row, toggle, chip)
- Pagina _Schermate — Light_: tutte le schermate sopra elencate, in light mode, a risoluzione iPhone 15 Pro (393×852) come riferimento
- Pagina _Schermate — Dark_: stesse schermate in dark mode
- Pagina _Stati e micro-interazioni_: hover, pressed, disabled, loading, empty, error per ogni componente principale
- Pagina _Accessibilità_: screenshot annotati che evidenziano contrasti, target sizes, flusso screen reader, comportamento con Dynamic Type a 200%
- Prototipo interattivo cliccabile delle flow principali (onboarding, quick entry, backup setup)

---

### 9. Fuori scope per questa iterazione

Non serve progettare ora: animazioni complesse, illustrazioni custom per marketing, app icon finale, materiali per lo store (screenshot promozionali), versioni per tablet. Ci concentriamo sull'esperienza mobile core; il resto viene dopo che il sistema è validato.

---

### 10. Una frase per ricordarsi dell'anima

Prima di consegnare ogni schermata, guardala e chiediti: _"Questa è un'app che una donna potrebbe consultare in un momento di quiete, da sola, la sera — e sentirsi a casa?"_ Se la risposta è dubbia, il design non è finito.