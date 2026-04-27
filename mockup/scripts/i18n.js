/* SPDX-License-Identifier: GPL-3.0-only — Métra mockup */

/*
 * i18n.js — Toggle IT/EN minimal per il mockup.
 * Sostituisce textContent di ogni elemento con data-i18n="key.path"
 * cercando la chiave nel dizionario STRINGS. In W1 è popolato solo IT;
 * EN viene completato in W2 dall'agent en-it-software-translator.
 *
 * Espone I18n.set(lang), I18n.t(key), I18n.current().
 * Persiste in localStorage (chiave metra_mockup_lang).
 */

(function () {
  'use strict';

  var STORAGE_KEY = 'metra_mockup_lang';
  var LANG_BTN_ID = 'btn-toggle-lang';
  var SUPPORTED = ['it', 'en'];
  var DEFAULT_LANG = 'it';

  // Dizionario stringhe. W1: IT completo. W2: il traduttore aggiungerà EN.
  var STRINGS = {
    it: {
      /* ── App ────────────────────────────────────────────────────── */
      'app.name': 'Métra',

      /* ── Tab bar ─────────────────────────────────────────────────── */
      'tab.calendar': 'Calendario',
      'tab.timeline': 'Timeline',
      'tab.stats': 'Statistiche',
      'tab.settings': 'Impostazioni',

      /* ── Toolbar mockup ──────────────────────────────────────────── */
      'toolbar.theme': 'Tema',
      'toolbar.lang': 'Lingua',
      'toolbar.reduceMotion': 'Riduci animazioni',
      'toolbar.screen': 'Schermata',

      /* ── Placeholder (schermata generica) ────────────────────────── */
      'screen.placeholder.title': 'Métra',
      'screen.placeholder.body': 'Mockup in costruzione.',
      'screen.upcoming': 'In arrivo.',

      /* ── Onboarding ──────────────────────────────────────────────── */
      'onboarding.headline': 'I tuoi dati,\nsolo tuoi.',
      'onboarding.promise1.title': 'Tutto sul tuo dispositivo',
      'onboarding.promise1.caption': 'Zero server nostri, zero connessione richiesta.',
      'onboarding.promise2.title': 'Cloud opzionale, sempre cifrato',
      'onboarding.promise2.caption': 'Il backup è end-to-end: solo tu hai la chiave.',
      'onboarding.promise3.title': 'Nessun tracciamento, nessuna pubblicità',
      'onboarding.promise3.caption': 'Open source, licenza GPL-3.0. Tutto verificabile.',
      'onboarding.tagline': "Un taccuino digitale, non un'app wellness.",
      'onboarding.cta': 'Inizia',

      /* ── Calendar ────────────────────────────────────────────────── */
      'calendar.monthYear': 'aprile 2026',
      'calendar.prevMonth': 'Mese precedente',
      'calendar.nextMonth': 'Mese successivo',
      'calendar.legend.flow': 'Flusso',
      'calendar.legend.spotting': 'Spotting',
      'calendar.legend.prediction': 'Previsione',
      'calendar.legend.notes': 'Note',
      'calendar.prediction.label': 'Prossimo ritmo previsto:',
      'calendar.prediction.date': '9–13 maggio',
      'calendar.fab.label': 'Aggiungi o modifica il registro di oggi',
      'calendar.dayCard.date': '26 aprile',
      'calendar.dayCard.flow': 'Flusso',
      'calendar.dayCard.edit': 'Modifica',

      /* ── Daily entry ─────────────────────────────────────────────── */
      'daily.back': 'Torna al calendario',
      'daily.date': '26 aprile 2026',
      'daily.flow.label': 'Flusso',
      'daily.flow.hint': 'Trascina verso l\'alto per registrare',
      'daily.flow.level.0': 'Nessuno',
      'daily.flow.level.1': 'Spotting',
      'daily.flow.level.2': 'Leggero',
      'daily.flow.level.3': 'Medio',
      'daily.flow.level.4': 'Abbondante',
      'daily.pain.label': 'Dolore',
      'daily.pain.hint': 'Tieni premuto per registrare',
      'daily.pain.undo': 'Annulla',
      'daily.pain.level.0': 'Nessuno',
      'daily.pain.level.1': 'Lieve',
      'daily.pain.level.2': 'Moderato',
      'daily.pain.level.3': 'Intenso',
      'daily.symptoms.label': 'Sintomi',
      'daily.symptom.cramps': 'Crampi',
      'daily.symptom.headache': 'Mal di testa',
      'daily.symptom.back': 'Schiena',
      'daily.symptom.fatigue': 'Stanchezza',
      'daily.symptom.add': 'Aggiungi',
      'daily.symptom.add.placeholder': 'Nome del sintomo…',
      'daily.symptom.add.ok': 'OK',
      'daily.notes.label': 'Note',
      'daily.notes.placeholder': 'Aggiungi una nota…',
      'daily.save': 'Salva',

      /* ── Timeline ────────────────────────────────────────────────── */
      'timeline.view.timeline': 'Timeline',
      'timeline.view.table': 'Tabella',
      'timeline.cycle.current.dates': '13–18 apr 2026',
      'timeline.cycle.inProgress': 'In corso',
      'timeline.cycle.days': '6 giorni',
      'timeline.cycle.length': 'Ciclo: — g (in corso)',
      'timeline.cycle.march.dates': '15–20 mar 2026',
      'timeline.cycle.march.length': '28 g',
      'timeline.cycle.days2': '6 giorni',
      'timeline.cycle.length2': 'Ciclo: 28 g',
      'timeline.cycle.feb.dates': '16–21 feb 2026',
      'timeline.cycle.feb.length': '28 g',
      'timeline.cycle.days3': '6 giorni',
      'timeline.cycle.length3': 'Ciclo: 28 g',
      'timeline.table.start': 'Inizio',
      'timeline.table.cycleLen': 'Ciclo',
      'timeline.table.periodLen': 'Mestr.',
      'timeline.table.symptoms': 'Sintomi',
      'timeline.table.row1.start': '13 apr',
      'timeline.table.row1.cycle': '—',
      'timeline.table.row1.period': '6 g',
      'timeline.table.row1.symptoms': 'Crampi',
      'timeline.table.row2.start': '15 mar',
      'timeline.table.row2.cycle': '28 g',
      'timeline.table.row2.period': '6 g',
      'timeline.table.row2.symptoms': '—',
      'timeline.table.row3.start': '16 feb',
      'timeline.table.row3.cycle': '28 g',
      'timeline.table.row3.period': '6 g',
      'timeline.table.row3.symptoms': 'Schiena',

      /* ── Statistiche ─────────────────────────────────────────────── */
      'stats.cycleLength.title': 'Lunghezza ciclo',
      'stats.cycleLength.average': '28 g in media',
      'stats.periodLength.title': 'Durata mestruazione',
      'stats.periodLength.average': '6 g in media',
      'stats.symptoms.title': 'Sintomi frequenti',
      'stats.symptom.cramps': 'Crampi',
      'stats.symptom.fatigue': 'Stanchezza',
      'stats.symptom.back': 'Schiena',
      'stats.flowIntensity.title': 'Intensità flusso',
      'stats.flow.feb': 'feb',
      'stats.flow.mar': 'mar',
      'stats.flow.apr': 'apr',
      'stats.flow.labels': 'feb: Medio · mar: Medio · apr: Abbondante',

      /* ── Impostazioni ────────────────────────────────────────────── */
      'settings.group.preferences': 'Preferenze',
      'settings.language.label': 'Lingua',
      'settings.language.value': 'Italiano',
      'settings.theme.label': 'Tema',
      'settings.theme.value': 'Chiaro',
      'settings.group.log': 'Registro',
      'settings.pain.label': 'Traccia dolore',
      'settings.notes.label': 'Note giornaliere',
      'settings.group.notifications': 'Notifiche',
      'settings.notifications.label': 'Promemoria ciclo',
      'settings.advance.label': 'Anticipo',
      'settings.advance.value': '1 giorno prima',
      'settings.group.privacy': 'Privacy e dati',
      'settings.backup.label': 'Backup cloud',
      'settings.backup.value': 'Google Drive',
      'settings.exportCSV': 'Esporta CSV',
      'settings.deleteAll': 'Cancella tutti i dati',
      'settings.group.danger': 'Zona pericolosa',
      'settings.version': 'Métra 0.1.0-dev',
      'settings.license': 'GPL-3.0 — Codice sorgente',

      /* ── Backup ──────────────────────────────────────────────────── */
      'backup.back': 'Torna alle impostazioni',
      'backup.title': 'Backup',
      'backup.step1.title': 'I tuoi dati restano tuoi',
      'backup.step1.body': 'Il backup viene cifrato sul tuo dispositivo prima di essere caricato. Nemmeno noi possiamo leggerlo.',
      'backup.step1.bullet1': 'Solo tu hai la chiave',
      'backup.step1.bullet2': 'Scegli tu dove salvare',
      'backup.step1.bullet3': 'Ripristino su qualsiasi tuo dispositivo',
      'backup.step2.title': 'Dove vuoi salvare?',
      'backup.provider.gdrive': 'Google Drive',
      'backup.provider.dropbox': 'Dropbox',
      'backup.provider.onedrive': 'OneDrive',
      'backup.step3.title': 'Crea una passphrase',
      'backup.step3.warning': 'Questa passphrase cifra i tuoi dati. Non la salviamo: se la perdi, non possiamo recuperare il backup.',
      'backup.step3.fieldLabel1': 'Passphrase',
      'backup.step3.fieldLabel2': 'Ripeti passphrase',
      'backup.step3.placeholder1': '••••••••••••',
      'backup.step3.placeholder2': '••••••••••••',
      'backup.step3.showPassphrase': 'Mostra passphrase',
      'backup.step3.showPassphrase2': 'Mostra ripetizione passphrase',
      'backup.step3.activate': 'Attiva backup',
      'backup.next': 'Avanti',
      'backup.next2': 'Avanti',
      'backup.prev': 'Indietro',
      'backup.prev2': 'Indietro'
    },
    en: {
      /* ── Legacy W1 placeholders (unused, kept for parity) ────────── */
      'screen.placeholder.title': 'Métra',
      'screen.placeholder.body': 'Mockup under construction.',
      'screen.upcoming': 'Coming soon.',

      /* ── App / toolbar ───────────────────────────────────────────── */
      'app.name': 'Métra',
      'tab.calendar': 'Calendar',
      'tab.timeline': 'Timeline',
      'tab.stats': 'Statistics',
      'tab.settings': 'Settings',
      'toolbar.theme': 'Theme',
      'toolbar.lang': 'Language',
      'toolbar.reduceMotion': 'Reduce motion',
      'toolbar.screen': 'Screen',

      /* ── Onboarding ──────────────────────────────────────────────── */
      'onboarding.headline': 'Your data,\nyours alone.',
      'onboarding.promise1.title': 'Everything on your device',
      'onboarding.promise1.caption': 'No servers. No internet required.',
      'onboarding.promise2.title': 'Optional cloud, always encrypted',
      'onboarding.promise2.caption': 'End-to-end backup — only you hold the key.',
      'onboarding.promise3.title': 'No tracking, no advertising',
      'onboarding.promise3.caption': 'Open source, GPL-3.0 licence. Fully auditable.',
      'onboarding.tagline': "A digital notebook, not a wellness app.",
      'onboarding.cta': 'Get started',

      /* ── Calendar ────────────────────────────────────────────────── */
      'calendar.monthYear': 'April 2026',
      'calendar.prevMonth': 'Previous month',
      'calendar.nextMonth': 'Next month',
      'calendar.legend.flow': 'Flow',
      'calendar.legend.spotting': 'Spotting',
      'calendar.legend.prediction': 'Prediction',
      'calendar.legend.notes': 'Notes',
      'calendar.prediction.label': 'Next predicted cycle:',
      'calendar.prediction.date': '9–13 May',
      'calendar.fab.label': "Add or edit today's log",
      'calendar.dayCard.date': '26 April',
      'calendar.dayCard.flow': 'Flow',
      'calendar.dayCard.edit': 'Edit',

      /* ── Daily entry ─────────────────────────────────────────────── */
      'daily.back': 'Back to calendar',
      'daily.date': 'April 26, 2026',
      'daily.flow.label': 'Flow',
      'daily.flow.hint': 'Drag up to record',
      'daily.flow.level.0': 'None',
      'daily.flow.level.1': 'Spotting',
      'daily.flow.level.2': 'Light',
      'daily.flow.level.3': 'Medium',
      'daily.flow.level.4': 'Heavy',
      'daily.pain.label': 'Pain',
      'daily.pain.hint': 'Hold to record',
      'daily.pain.undo': 'Undo',
      'daily.pain.level.0': 'None',
      'daily.pain.level.1': 'Mild',
      'daily.pain.level.2': 'Moderate',
      'daily.pain.level.3': 'Severe',

      'daily.symptoms.label': 'Symptoms',
      'daily.symptom.cramps': 'Cramps',
      'daily.symptom.headache': 'Headache',
      'daily.symptom.back': 'Back pain',
      'daily.symptom.fatigue': 'Fatigue',
      'daily.symptom.add': 'Add',
      'daily.symptom.add.placeholder': 'Symptom name…',
      'daily.symptom.add.ok': 'OK',
      'daily.notes.label': 'Notes',
      'daily.notes.placeholder': 'Add a note…',
      'daily.save': 'Save',

      /* ── Timeline ────────────────────────────────────────────────── */
      'timeline.view.timeline': 'Timeline',
      'timeline.view.table': 'Table',
      'timeline.cycle.current.dates': '13–18 Apr 2026',
      'timeline.cycle.inProgress': 'In progress',
      'timeline.cycle.days': '6 days',
      'timeline.cycle.length': 'Cycle: — d (in progress)',
      'timeline.cycle.march.dates': '15–20 Mar 2026',
      'timeline.cycle.march.length': '28 d',
      'timeline.cycle.days2': '6 days',
      'timeline.cycle.length2': 'Cycle: 28 d',
      'timeline.cycle.feb.dates': '16–21 Feb 2026',
      'timeline.cycle.feb.length': '28 d',
      'timeline.cycle.days3': '6 days',
      'timeline.cycle.length3': 'Cycle: 28 d',
      'timeline.table.start': 'Start',
      'timeline.table.cycleLen': 'Cycle',
      'timeline.table.periodLen': 'Period',
      'timeline.table.symptoms': 'Symptoms',
      'timeline.table.row1.start': '13 Apr',
      'timeline.table.row1.cycle': '—',
      'timeline.table.row1.period': '6 d',
      'timeline.table.row1.symptoms': 'Cramps',
      'timeline.table.row2.start': '15 Mar',
      'timeline.table.row2.cycle': '28 d',
      'timeline.table.row2.period': '6 d',
      'timeline.table.row2.symptoms': '—',
      'timeline.table.row3.start': '16 Feb',
      'timeline.table.row3.cycle': '28 d',
      'timeline.table.row3.period': '6 d',
      'timeline.table.row3.symptoms': 'Back pain',

      /* ── Statistics ──────────────────────────────────────────────── */
      'stats.cycleLength.title': 'Cycle length',
      'stats.cycleLength.average': '28 d average',
      'stats.periodLength.title': 'Period length',
      'stats.periodLength.average': '6 d average',
      'stats.symptoms.title': 'Common symptoms',
      'stats.symptom.cramps': 'Cramps',
      'stats.symptom.fatigue': 'Fatigue',
      'stats.symptom.back': 'Back pain',
      'stats.flowIntensity.title': 'Flow intensity',
      'stats.flow.feb': 'Feb',
      'stats.flow.mar': 'Mar',
      'stats.flow.apr': 'Apr',
      'stats.flow.labels': 'Feb: Medium · Mar: Medium · Apr: Heavy',

      /* ── Settings ────────────────────────────────────────────────── */
      'settings.group.preferences': 'Preferences',
      'settings.language.label': 'Language',
      'settings.language.value': 'English',
      'settings.theme.label': 'Theme',
      'settings.theme.value': 'Light',
      'settings.group.log': 'Log',
      'settings.pain.label': 'Track pain',
      'settings.notes.label': 'Daily notes',
      'settings.group.notifications': 'Notifications',
      'settings.notifications.label': 'Cycle reminder',
      'settings.advance.label': 'Advance notice',
      'settings.advance.value': '1 day before',
      'settings.group.privacy': 'Privacy & data',
      'settings.backup.label': 'Cloud backup',
      'settings.backup.value': 'Google Drive',
      'settings.exportCSV': 'Export CSV',
      'settings.deleteAll': 'Delete all data',
      'settings.group.danger': 'Danger zone',
      'settings.version': 'Métra 0.1.0-dev',
      'settings.license': 'GPL-3.0 — Source code',

      /* ── Backup ──────────────────────────────────────────────────── */
      'backup.back': 'Back to settings',
      'backup.title': 'Backup',
      'backup.step1.title': 'Your data stays yours',
      'backup.step1.body': 'Your backup is encrypted on your device before it is uploaded. Even we cannot read it.',
      'backup.step1.bullet1': 'Only you hold the key',
      'backup.step1.bullet2': 'You choose where to save',
      'backup.step1.bullet3': 'Restore on any of your devices',
      'backup.step2.title': 'Where do you want to save?',
      'backup.provider.gdrive': 'Google Drive',
      'backup.provider.dropbox': 'Dropbox',
      'backup.provider.onedrive': 'OneDrive',
      'backup.step3.title': 'Create a passphrase',
      'backup.step3.warning': 'This passphrase encrypts your data. We do not store it: if you lose it, we cannot recover your backup.',
      'backup.step3.fieldLabel1': 'Passphrase',
      'backup.step3.fieldLabel2': 'Repeat passphrase',
      'backup.step3.placeholder1': '••••••••••••',
      'backup.step3.placeholder2': '••••••••••••',
      'backup.step3.showPassphrase': 'Show passphrase',
      'backup.step3.showPassphrase2': 'Show repeated passphrase',
      'backup.step3.activate': 'Enable backup',
      'backup.next': 'Next',
      'backup.next2': 'Next',
      'backup.prev': 'Back',
      'backup.prev2': 'Back'
    }
  };

  // ---------- Storage helpers ----------

  function safeGet(key) {
    try {
      return window.localStorage.getItem(key);
    } catch (_e) {
      return null;
    }
  }

  function safeSet(key, value) {
    try {
      window.localStorage.setItem(key, value);
    } catch (_e) {
      /* degrade silenzioso */
    }
  }

  // ---------- Lookup ----------

  function currentLang() {
    return document.documentElement.getAttribute('data-lang') || DEFAULT_LANG;
  }

  function t(key) {
    var lang = currentLang();
    var bundle = STRINGS[lang] || {};
    if (Object.prototype.hasOwnProperty.call(bundle, key)) {
      return bundle[key];
    }
    // Fallback alla lingua di default (IT in W1).
    var fallback = STRINGS[DEFAULT_LANG] || {};
    if (Object.prototype.hasOwnProperty.call(fallback, key)) {
      return fallback[key];
    }
    return key;
  }

  function applyTranslations() {
    // 1) Sostituzione testo: data-i18n="key.path" → textContent.
    //    NB: textContent sovrascrive anche figli HTML. NON usare su
    //    elementi con struttura interna (es. .wordmark) — usare invece
    //    aria-label hardcoded o un pattern dedicato.
    var nodes = document.querySelectorAll('[data-i18n]');
    Array.prototype.forEach.call(nodes, function (node) {
      var key = node.getAttribute('data-i18n');
      if (!key) return;
      node.textContent = t(key);
    });

    // 2) Sostituzione attributi accessibili: data-i18n-aria-label,
    //    data-i18n-title, data-i18n-placeholder. Utile per icone-only,
    //    input form, tooltip — la struttura interna resta intatta.
    var attrMap = [
      { data: 'data-i18n-aria-label', attr: 'aria-label' },
      { data: 'data-i18n-title',      attr: 'title' },
      { data: 'data-i18n-placeholder', attr: 'placeholder' }
    ];
    attrMap.forEach(function (entry) {
      var els = document.querySelectorAll('[' + entry.data + ']');
      Array.prototype.forEach.call(els, function (el) {
        var key = el.getAttribute(entry.data);
        if (key) el.setAttribute(entry.attr, t(key));
      });
    });
  }

  // ---------- Set / toggle ----------

  function setLang(lang) {
    if (SUPPORTED.indexOf(lang) === -1) return;
    document.documentElement.setAttribute('lang', lang);
    document.documentElement.setAttribute('data-lang', lang);
    safeSet(STORAGE_KEY, lang);
    applyTranslations();
    updateLangButton();
  }

  function toggleLang() {
    setLang(currentLang() === 'it' ? 'en' : 'it');
  }

  function updateLangButton() {
    var btn = document.getElementById(LANG_BTN_ID);
    if (!btn) return;
    btn.setAttribute('aria-pressed', currentLang() === 'en' ? 'true' : 'false');
  }

  function bindButton() {
    var btn = document.getElementById(LANG_BTN_ID);
    if (btn) btn.addEventListener('click', toggleLang);
  }

  function init() {
    var stored = safeGet(STORAGE_KEY);
    var lang = (SUPPORTED.indexOf(stored) !== -1) ? stored : DEFAULT_LANG;
    setLang(lang);
    bindButton();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

  // API pubblica.
  window.I18n = {
    set: setLang,
    toggle: toggleLang,
    t: t,
    current: currentLang
  };
})();
