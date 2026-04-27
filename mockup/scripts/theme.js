/* SPDX-License-Identifier: GPL-3.0-only — Métra mockup */

/*
 * theme.js — Toggle light/dark e reduced motion.
 * Persiste in localStorage (chiavi: metra_mockup_theme, metra_mockup_reduced_motion).
 * Espone Theme.set / Theme.toggle / Theme.current e ReducedMotion.set / .toggle / .current.
 */

(function () {
  'use strict';

  var STORAGE_KEY_THEME = 'metra_mockup_theme';
  var STORAGE_KEY_RM = 'metra_mockup_reduced_motion';
  var THEME_BTN_ID = 'btn-toggle-theme';
  var LANG_BTN_ID = 'btn-toggle-lang';
  var RM_BTN_ID = 'btn-toggle-reduced-motion';

  // ---------- Storage helpers (silent on QuotaExceeded / private mode) ----------

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
      /* storage indisponibile: degrade silenzioso */
    }
  }

  // ---------- Theme ----------

  function detectSystemTheme() {
    if (window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches) {
      return 'dark';
    }
    return 'light';
  }

  function currentTheme() {
    return document.documentElement.getAttribute('data-theme') || 'light';
  }

  function setTheme(theme) {
    if (theme !== 'light' && theme !== 'dark') return;
    document.documentElement.setAttribute('data-theme', theme);
    safeSet(STORAGE_KEY_THEME, theme);
    updateThemeButton();
  }

  function toggleTheme() {
    setTheme(currentTheme() === 'light' ? 'dark' : 'light');
  }

  function updateThemeButton() {
    var btn = document.getElementById(THEME_BTN_ID);
    if (!btn) return;
    var isDark = currentTheme() === 'dark';
    btn.setAttribute('aria-pressed', isDark ? 'true' : 'false');
  }

  function initTheme() {
    var stored = safeGet(STORAGE_KEY_THEME);
    var theme = (stored === 'light' || stored === 'dark') ? stored : detectSystemTheme();
    setTheme(theme);
  }

  // ---------- Reduced motion ----------

  function detectSystemReducedMotion() {
    if (window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
      return true;
    }
    return false;
  }

  function currentReducedMotion() {
    return document.documentElement.getAttribute('data-reduced-motion') === 'true';
  }

  function setReducedMotion(enabled) {
    var value = enabled ? 'true' : 'false';
    if (enabled) {
      document.documentElement.setAttribute('data-reduced-motion', 'true');
    } else {
      document.documentElement.removeAttribute('data-reduced-motion');
    }
    safeSet(STORAGE_KEY_RM, value);
    updateReducedMotionButton();
  }

  function toggleReducedMotion() {
    setReducedMotion(!currentReducedMotion());
  }

  function updateReducedMotionButton() {
    var btn = document.getElementById(RM_BTN_ID);
    if (!btn) return;
    btn.setAttribute('aria-pressed', currentReducedMotion() ? 'true' : 'false');
  }

  function initReducedMotion() {
    var stored = safeGet(STORAGE_KEY_RM);
    var enabled;
    if (stored === 'true') enabled = true;
    else if (stored === 'false') enabled = false;
    else enabled = detectSystemReducedMotion();
    setReducedMotion(enabled);
  }

  // ---------- Wiring toolbar ----------

  function bindButtons() {
    var themeBtn = document.getElementById(THEME_BTN_ID);
    if (themeBtn) themeBtn.addEventListener('click', toggleTheme);

    var rmBtn = document.getElementById(RM_BTN_ID);
    if (rmBtn) rmBtn.addEventListener('click', toggleReducedMotion);

    // Il toggle lingua è gestito da i18n.js, ma marchiamo qui aria-pressed
    // come informazione di stato visiva uniforme.
    var langBtn = document.getElementById(LANG_BTN_ID);
    if (langBtn) {
      langBtn.addEventListener('click', function () {
        // Aggiornamento aria-pressed delegato a i18n.js dopo lo switch.
      });
    }
  }

  function init() {
    initTheme();
    initReducedMotion();
    bindButtons();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

  // API pubblica.
  window.Theme = {
    set: setTheme,
    toggle: toggleTheme,
    current: currentTheme
  };

  window.ReducedMotion = {
    set: setReducedMotion,
    toggle: toggleReducedMotion,
    current: currentReducedMotion
  };
})();
