/* SPDX-License-Identifier: GPL-3.0-only — Métra mockup */

/*
 * router.js — Router minimal vanilla per le 8 schermate del mockup.
 * Espone Router.go(slug), Router.list(), Router.current().
 * Sincronizza data-screen sullo stage, data-active sulla schermata,
 * hash URL, indicator nella toolbar globale, aria-selected sulla tab bar.
 */

(function () {
  'use strict';

  var DEFAULT_SCREEN = 'onboarding';
  var STAGE_SELECTOR = '.stage';
  var SCREEN_SELECTOR = '[data-screen]';
  var INDICATOR_ID = 'screen-indicator';
  var TAB_SELECTOR = '.tab-bar__tab[data-tab]';
  var ROUTE_TRIGGER_SELECTOR = '[data-route]';

  function getStage() {
    return document.querySelector(STAGE_SELECTOR);
  }

  function getScreens() {
    var stage = getStage();
    if (!stage) return [];
    // Solo i figli diretti dello stage che dichiarano data-screen.
    return Array.prototype.filter.call(
      stage.children,
      function (el) { return el.hasAttribute('data-screen'); }
    );
  }

  function listSlugs() {
    return getScreens().map(function (el) {
      return el.getAttribute('data-screen');
    });
  }

  function currentSlug() {
    var stage = getStage();
    if (!stage) return null;
    return stage.getAttribute('data-screen');
  }

  function readHashSlug() {
    var hash = window.location.hash || '';
    // Formato atteso: #screen=slug
    var match = hash.match(/^#screen=([a-z0-9_-]+)$/i);
    return match ? match[1] : null;
  }

  function writeHashSlug(slug) {
    var newHash = '#screen=' + slug;
    if (window.location.hash !== newHash) {
      // Evita di triggerare hashchange ricorsivo.
      history.replaceState(null, '', newHash);
    }
  }

  function updateIndicator(slug) {
    var indicator = document.getElementById(INDICATOR_ID);
    if (indicator) {
      indicator.textContent = slug;
    }
  }

  function updateTabSelection(slug) {
    var tabs = document.querySelectorAll(TAB_SELECTOR);
    Array.prototype.forEach.call(tabs, function (tab) {
      var isActive = tab.getAttribute('data-tab') === slug;
      tab.setAttribute('aria-selected', isActive ? 'true' : 'false');
    });
  }

  function go(slug) {
    var screens = getScreens();
    if (screens.length === 0) return false;

    var slugs = screens.map(function (el) {
      return el.getAttribute('data-screen');
    });

    // Validazione: se lo slug non esiste, fallback al default o al primo disponibile.
    if (slugs.indexOf(slug) === -1) {
      if (slugs.indexOf(DEFAULT_SCREEN) !== -1) {
        slug = DEFAULT_SCREEN;
      } else {
        slug = slugs[0];
      }
    }

    // Aggiorna lo stage.
    var stage = getStage();
    if (stage) {
      stage.setAttribute('data-screen', slug);
    }

    // Mostra solo la schermata richiesta.
    screens.forEach(function (el) {
      if (el.getAttribute('data-screen') === slug) {
        el.setAttribute('data-active', 'true');
      } else {
        el.removeAttribute('data-active');
      }
    });

    writeHashSlug(slug);
    updateIndicator(slug);
    updateTabSelection(slug);

    return true;
  }

  function bindRouteTriggers() {
    document.addEventListener('click', function (event) {
      var target = event.target;
      // Risali per trovare un elemento con data-route.
      while (target && target !== document.body) {
        if (target.hasAttribute && target.hasAttribute('data-route')) {
          var slug = target.getAttribute('data-route');
          if (slug) {
            event.preventDefault();
            go(slug);
          }
          return;
        }
        target = target.parentNode;
      }
    });
  }

  function bindHashChange() {
    window.addEventListener('hashchange', function () {
      var slug = readHashSlug();
      if (slug) {
        go(slug);
      }
    });
  }

  function init() {
    bindRouteTriggers();
    bindHashChange();
    var initial = readHashSlug() || DEFAULT_SCREEN;
    go(initial);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

  // API pubblica.
  window.Router = {
    go: go,
    list: listSlugs,
    current: currentSlug
  };
})();
