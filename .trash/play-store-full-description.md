> **⚠ ARCHIVED — NOT current truth.** This document captured state at planning time. Current behavior may have diverged. Consult the current codebase or active spec docs.

# Métra — Play Store Full Description

> **Usage:** Paste each version into Play Console → Store presence → Main store listing → Full description.  
> **Limit:** 4 000 characters per language. Counts verified below.  
> **Voice source:** `canon/product-narrative.md` + `canon/product-vision.md`  
> **Written:** 2026-05-10

---

## 🇮🇹 Italiano (lingua predefinita)

*~2 450 caratteri — entro il limite di 4 000*

---

Mētra è un diario del ciclo mestruale. Privato. Locale. Tuo.

Le app di salute monetizzano i tuoi dati più intimi. Mētra no. Ogni registrazione vive sul tuo dispositivo, cifrata. Nessun server vede mai i tuoi dati in chiaro. Nessun algoritmo impara dal tuo corpo per servire gli interessi di qualcun altro.

**Cosa fa Mētra**

Ti aiuta a conoscere il tuo ritmo. Puoi registrare l'inizio e la fine del ciclo, l'intensità del flusso, i sintomi fisici, il dolore. Il calendario mensile mostra i tuoi pattern in modo visivo, essenziale, senza rumore. Le statistiche ti restituiscono quello che hai osservato, senza interpretarlo per te, senza confrontarti con una norma.

La previsione è onesta: non ti dice il giorno esatto, ti mostra una finestra di tre-cinque giorni, calcolata dalla tua storia personale e ponderata verso i cicli più recenti. Perché il tuo corpo non è una macchina, e uno strumento che lo finge ti sta mentendo in un modo che ti costa fiducia in te stessa.

**La privacy non è un'opzione. È l'architettura.**

• Tutti i dati restano sul tuo dispositivo
• Database cifrato con AES-256 (SQLCipher)
• Nessun account Mētra. Nessun server Mētra. Nessuna registrazione richiesta
• Backup cloud opzionale, cifrato end-to-end prima di lasciare il dispositivo
• Il provider cloud (Dropbox) vede solo un blob che non può leggere
• Zero telemetria. Zero analytics. Zero tracciamento
• Nessun dato condiviso con terze parti, mai

**Non è un tracker di fertilità**

Mētra non assume un ciclo di 28 giorni. Non presuppone un desiderio di gravidanza. Non invia notifiche motivazionali. Non assegna badge o premi streak. Non ha gamification. Non ha un modello di business che dipende dalla tua attenzione o dai tuoi dati.

È uno strumento che fa quello che dice, e nient'altro.

**Open source**

Il codice è pubblico, licenza GPL-3.0. Chiunque può verificare che Mētra faccia quello che promette. Chiunque può fare un fork, a patto di mantenerlo aperto. La trasparenza non è una funzionalità: è il modo in cui restiamo responsabili.

**Cosa trovi nell'app**

→ Calendario mensile con ciclo e sintomi
→ Registrazione giornaliera: flusso, dolore, sintomi, note libere
→ Previsione della data del prossimo ciclo (finestra probabilistica)
→ Statistiche: durata media, variabilità, storia completa
→ Backup cifrato su Dropbox
→ Export CSV dei tuoi dati
→ Tema chiaro e scuro
→ Italiano e inglese

Mētra è gratuita. Nessuna versione premium. Nessuna pubblicità. Nessun acquisto in-app.

Il nome viene dal greco antico: *mētra* (μήτρα) — utero, ma anche misura, matrice, metro. L'idea che il corpo abbia il proprio ritmo, la propria misura, il proprio tempo.

Abbiamo scelto quel nome perché il nome è la promessa.

---

## 🇬🇧 English

*~2 380 characters — within the 4 000 limit*

---

Mētra is a menstrual cycle diary. Private. Local. Yours.

Health apps routinely monetize your most intimate data. Mētra doesn't. Every entry lives on your device, encrypted. No server ever sees your data in plaintext. No algorithm learns from your body to serve someone else's interests.

**What Mētra does**

It helps you understand your own rhythm. Log cycle start and end, flow intensity, physical symptoms, pain. The monthly calendar shows your patterns clearly, without noise. Statistics give back what you observed, without interpreting it for you, without comparing you to a norm.

The prediction is honest: it doesn't give you the exact day, it shows you a three-to-five day window, calculated from your personal history, weighted toward your most recent cycles. Because your body is not a machine, and a tool that pretends otherwise is lying to you in a way that costs you trust in yourself.

**Privacy is not a setting. It's the architecture.**

• All data stays on your device
• Database encrypted with AES-256 (SQLCipher)
• No Mētra account. No Mētra server. No sign-up required
• Optional cloud backup, end-to-end encrypted before leaving your device
• The cloud provider (Dropbox) sees only an opaque blob it cannot read
• Zero telemetry. Zero analytics. Zero tracking
• No data shared with third parties. Ever.

**Not a fertility tracker**

Mētra does not assume a 28-day cycle. It does not presuppose a desire for pregnancy. It does not send motivational nudges. It does not award badges or streak rewards. It has no gamification. It has no business model that depends on your attention or your data.

It is a tool that does what it says, and nothing else.

**Open source**

The code is public, GPL-3.0 license. Anyone can verify that Mētra does what it promises. Anyone can fork it, as long as they keep it open. Transparency isn't a feature. It's how accountability works.

**What's in the app**

→ Monthly calendar with cycle and symptom visualization
→ Daily log: flow, pain, physical symptoms, free notes
→ Next cycle prediction (honest probability window)
→ Statistics: average duration, variability, full history
→ Encrypted backup to Dropbox
→ CSV export of your data
→ Light and dark theme
→ Italian and English

Mētra is free. No premium tier. No ads. No in-app purchases.

The name comes from Ancient Greek: *mētra* (μήτρα) — uterus, but also measure, matrix, meter. The idea that the body has its own rhythm, its own measure, its own time.

We chose that name because the name is the promise.

---

## Notes for Play Console

- **Default language:** Italian — paste the 🇮🇹 version first
- **Add translation:** Play Console → Translations → Add language → English (United Kingdom or United States) → paste 🇬🇧 version
- **Short description** (≤80 chars, separate field):
  - IT: `Diario del ciclo mestruale — privato, locale, cifrato.`
  - EN: `Menstrual cycle diary — private, local, encrypted.`
- Do **not** include HTML or markdown in Play Console — paste plain text only (the `→` bullet character is safe; `**bold**` is not rendered)
