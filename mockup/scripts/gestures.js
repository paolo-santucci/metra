/* SPDX-License-Identifier: GPL-3.0-only — Métra mockup */

/*
 * gestures.js — Interazioni gestuali per le schermate Wave 2.
 *
 * Moduli:
 *   1. RisingFill   — drag verticale per il livello flusso (design brief §6.3)
 *   2. PainPulse    — long-press per il livello dolore (design brief §6.3)
 *   3. TimelineToggle — segmented control Timeline ↔ Tabella
 *   4. BackupSteps  — navigazione multi-step nel flusso backup
 *
 * Convenzioni:
 *   - Nessun inline script nell'HTML. Tutto qui.
 *   - Rispetta prefers-reduced-motion e data-reduced-motion="true".
 *   - Tap target ≥ 44px (garantito in CSS).
 *   - Nessun hex hardcoded: le variabili colore sono in CSS.
 */

(function () {
  'use strict';

  /* ========================================================================
     Utility
     ====================================================================== */

  function isReducedMotion() {
    if (document.documentElement.getAttribute('data-reduced-motion') === 'true') {
      return true;
    }
    if (window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
      return true;
    }
    return false;
  }

  function clamp(value, min, max) {
    return Math.min(Math.max(value, min), max);
  }

  /* ========================================================================
     1. RisingFill (design brief §6.3)
     ========================================================================
     Elemento target: [data-gesture="rising-fill"]
     Attributi:
       data-level="N"  (N = 0..4)
       .rising-fill__fill     → height aggiornata via style
       [data-fill-label]      → textContent + opacity (cross-fade)
       [data-fill-hint]       → svanisce al primo gesto
       .rising-fill__circle   → bloom class al rilascio

     5 livelli → altezze: 0% / 18% / 40% / 65% / 90%
     Labels: Nessuno / Spotting / Leggero / Medio / Abbondante
     ====================================================================== */

  var FILL_LEVELS = [
    { pct: 0,  label: 'Nessuno' },
    { pct: 18, label: 'Spotting' },
    { pct: 40, label: 'Leggero' },
    { pct: 65, label: 'Medio' },
    { pct: 90, label: 'Abbondante' }
  ];

  function applyFillLevel(el, level) {
    var data = FILL_LEVELS[level] || FILL_LEVELS[0];
    var fill = el.querySelector('.rising-fill__fill');
    var labelEl = el.querySelector('[data-fill-label]');
    var circle = el.querySelector('.rising-fill__circle');

    if (fill) fill.style.height = data.pct + '%';

    if (labelEl) {
      if (level === 0) {
        labelEl.classList.remove('rising-fill__label--visible');
        labelEl.removeAttribute('data-current-label');
      } else {
        var prevLabel = labelEl.getAttribute('data-current-label');
        if (prevLabel && prevLabel !== data.label) {
          /* Cross-fade: fade-out 140ms, swap, fade-in 140ms */
          labelEl.style.transition = 'opacity 0.14s ease';
          labelEl.style.opacity = '0';
          if (labelEl._crossFadeTimer) clearTimeout(labelEl._crossFadeTimer);
          labelEl._crossFadeTimer = setTimeout(function () {
            labelEl.textContent = data.label;
            labelEl.style.opacity = '';
            labelEl.style.transition = '';
            labelEl.classList.add('rising-fill__label--visible');
          }, 140);
        } else {
          labelEl.textContent = data.label;
          labelEl.classList.add('rising-fill__label--visible');
        }
        labelEl.setAttribute('data-current-label', data.label);
      }
    }

    if (circle) {
      circle.setAttribute('aria-valuenow', String(level));
      circle.setAttribute('aria-valuetext', data.label);
    }

    el.setAttribute('data-level', String(level));
  }

  function initRisingFill(el) {
    var circle = el.querySelector('.rising-fill__circle');
    if (!circle) return;

    var startLevel = parseInt(el.getAttribute('data-level') || '0', 10);
    applyFillLevel(el, startLevel);

    var hint = el.querySelector('[data-fill-hint]');
    var hintHidden = false;

    function hideHint() {
      if (!hintHidden && hint) {
        hint.classList.add('rising-fill__hint--hidden');
        hintHidden = true;
      }
    }

    function triggerBloom() {
      if (isReducedMotion()) return;
      circle.classList.remove('rising-fill__circle--bloom');
      /* Force reflow per riavviare l'animazione */
      void circle.offsetWidth;
      circle.classList.add('rising-fill__circle--bloom');
      circle.addEventListener('animationend', function onEnd() {
        circle.classList.remove('rising-fill__circle--bloom');
        circle.removeEventListener('animationend', onEnd);
      });
    }

    var dragStartY = null;
    var dragStartLevel = null;
    var DRAG_PX_PER_LEVEL = 28;

    function onPointerDown(evt) {
      if (evt.button !== undefined && evt.button !== 0) return;
      circle.setPointerCapture(evt.pointerId);
      dragStartY = evt.clientY;
      dragStartLevel = parseInt(el.getAttribute('data-level') || '0', 10);
      hideHint();
    }

    function onPointerMove(evt) {
      if (dragStartY === null) return;
      var delta = dragStartY - evt.clientY; /* positivo = su = più fill */
      var levelDelta = Math.round(delta / DRAG_PX_PER_LEVEL);
      var newLevel = clamp(dragStartLevel + levelDelta, 0, FILL_LEVELS.length - 1);
      var current = parseInt(el.getAttribute('data-level') || '0', 10);
      if (newLevel !== current) applyFillLevel(el, newLevel);
    }

    function onPointerUp(evt) {
      if (dragStartY === null) return;
      var totalDelta = Math.abs(evt.clientY - dragStartY);
      if (totalDelta < 4) {
        /* Tap: metà superiore +1, metà inferiore -1 (fallback reduced-motion) */
        var rect = circle.getBoundingClientRect();
        var relY = evt.clientY - rect.top;
        var cur = parseInt(el.getAttribute('data-level') || '0', 10);
        var newLevel = relY < rect.height / 2
          ? clamp(cur + 1, 0, FILL_LEVELS.length - 1)
          : clamp(cur - 1, 0, FILL_LEVELS.length - 1);
        applyFillLevel(el, newLevel);
      }
      triggerBloom();
      dragStartY = null;
      dragStartLevel = null;
    }

    function onPointerCancel() {
      dragStartY = null;
      dragStartLevel = null;
    }

    /* Tastiera: frecce su/giù */
    function onKeyDown(evt) {
      var cur = parseInt(el.getAttribute('data-level') || '0', 10);
      if (evt.key === 'ArrowUp' || evt.key === 'ArrowRight') {
        evt.preventDefault();
        hideHint();
        applyFillLevel(el, clamp(cur + 1, 0, FILL_LEVELS.length - 1));
      } else if (evt.key === 'ArrowDown' || evt.key === 'ArrowLeft') {
        evt.preventDefault();
        hideHint();
        applyFillLevel(el, clamp(cur - 1, 0, FILL_LEVELS.length - 1));
      }
    }

    circle.addEventListener('pointerdown', onPointerDown);
    circle.addEventListener('pointermove', onPointerMove);
    circle.addEventListener('pointerup', onPointerUp);
    circle.addEventListener('pointercancel', onPointerCancel);
    circle.addEventListener('keydown', onKeyDown);
  }

  /* ========================================================================
     2. PainPulse (design brief §6.3)
     ========================================================================
     Elemento target: [data-gesture="pain-pulse"]
     data-pulse-level="N"  (N = 0..3)

     Long-press 780ms × livello avanza 0→1→2→3 (stop a 3).
     Durante pressione:
       - Arc SVG stroke-dashoffset: 427→0 in 2400ms
       - classe --pressing sul cerchio (glow box-shadow)
     Al rilascio (commit livello):
       - bloom sul cerchio
       - finestra correzione 3s (dot crescono, diventano tappabili)
       - undo button per 3s

     Reduced motion: tap singolo avanza il livello (no long-press, no animazioni).
     Labels: Nessuno / Lieve / Moderato / Intenso (mai numeri).
     ====================================================================== */

  var PULSE_LEVELS = ['Nessuno', 'Lieve', 'Moderato', 'Intenso'];
  var PULSE_MAX = 3;
  var PAIN_PULSE_MS = 780;
  var ARC_TOTAL_MS = 2400;
  var ARC_CIRCUMFERENCE = 427; /* 2π × 68 ≈ 427 */

  function applyPulseLevel(el, level) {
    var data = PULSE_LEVELS[level] || PULSE_LEVELS[0];
    var labelEl = el.querySelector('[data-pulse-label]');
    var circle = el.querySelector('.pain-pulse__circle');
    var dots = el.querySelectorAll('.pain-pulse__dot');

    el.setAttribute('data-pulse-level', String(level));

    if (circle) {
      circle.setAttribute('aria-valuenow', String(level));
      circle.setAttribute('aria-valuetext', data);
    }

    if (labelEl) {
      if (level === 0) {
        labelEl.classList.remove('pain-pulse__label--visible');
        labelEl.removeAttribute('data-current-label');
      } else {
        var prevLabel = labelEl.getAttribute('data-current-label');
        if (prevLabel && prevLabel !== data) {
          labelEl.style.transition = 'opacity 0.14s ease';
          labelEl.style.opacity = '0';
          if (labelEl._crossFadeTimer) clearTimeout(labelEl._crossFadeTimer);
          labelEl._crossFadeTimer = setTimeout(function () {
            labelEl.textContent = data;
            labelEl.style.opacity = '';
            labelEl.style.transition = '';
            labelEl.classList.add('pain-pulse__label--visible');
          }, 140);
        } else {
          labelEl.textContent = data;
          labelEl.classList.add('pain-pulse__label--visible');
        }
        labelEl.setAttribute('data-current-label', data);
      }
    }

    /* Aggiorna dot: i dot ≤ level sono "active"; bump 1.3× sul dot corrispondente */
    Array.prototype.forEach.call(dots, function (dot, idx) {
      var dotLevel = idx + 1;
      if (dotLevel <= level) {
        dot.classList.add('pain-pulse__dot--active');
      } else {
        dot.classList.remove('pain-pulse__dot--active');
      }
      if (dotLevel === level && level > 0) {
        dot.classList.remove('pain-pulse__dot--bump');
        void dot.offsetWidth;
        dot.classList.add('pain-pulse__dot--bump');
        dot.addEventListener('animationend', function onEnd() {
          dot.classList.remove('pain-pulse__dot--bump');
          dot.removeEventListener('animationend', onEnd);
        });
      }
    });
  }

  function initPainPulse(el) {
    var circle = el.querySelector('.pain-pulse__circle');
    var arcTrack = el.querySelector('.pain-pulse__arc-track');
    if (!circle) return;

    var initLevel = parseInt(el.getAttribute('data-pulse-level') || '0', 10);
    applyPulseLevel(el, initLevel);

    var longPressTimer = null;
    var arcTimer = null;
    var correctionTimer = null;
    var prevLevel = 0;

    function startArc() {
      if (!arcTrack || isReducedMotion()) return;
      var startTime = Date.now();
      arcTrack.style.strokeDashoffset = String(ARC_CIRCUMFERENCE);
      arcTimer = setInterval(function () {
        var elapsed = Date.now() - startTime;
        var progress = Math.min(elapsed / ARC_TOTAL_MS, 1);
        arcTrack.style.strokeDashoffset = String(ARC_CIRCUMFERENCE * (1 - progress));
        if (progress >= 1) {
          clearInterval(arcTimer);
          arcTimer = null;
        }
      }, 16);
    }

    function resetArc() {
      if (arcTimer) { clearInterval(arcTimer); arcTimer = null; }
      if (arcTrack) arcTrack.style.strokeDashoffset = String(ARC_CIRCUMFERENCE);
    }

    function triggerBloom() {
      if (isReducedMotion()) return;
      circle.classList.remove('pain-pulse__circle--bloom');
      void circle.offsetWidth;
      circle.classList.add('pain-pulse__circle--bloom');
      circle.addEventListener('animationend', function onEnd() {
        circle.classList.remove('pain-pulse__circle--bloom');
        circle.removeEventListener('animationend', onEnd);
      });
    }

    function startCorrectionWindow() {
      el.classList.add('pain-pulse--correction-window');
      if (correctionTimer) clearTimeout(correctionTimer);
      correctionTimer = setTimeout(function () {
        el.classList.remove('pain-pulse--correction-window');
        correctionTimer = null;
      }, 3000);
    }

    function showUndo() {
      var undoEl = el.querySelector('.pain-pulse__undo');
      if (!undoEl) return;
      undoEl.classList.add('pain-pulse__undo--visible');
      clearTimeout(undoEl._undoTimer);
      undoEl._undoTimer = setTimeout(function () {
        undoEl.classList.remove('pain-pulse__undo--visible');
      }, 3000);
    }

    function commit() {
      var cur = parseInt(el.getAttribute('data-pulse-level') || '0', 10);
      if (cur >= PULSE_MAX) return;
      prevLevel = cur;
      applyPulseLevel(el, cur + 1);
      resetArc();
      circle.classList.remove('pain-pulse__circle--pressing');
      triggerBloom();
      startCorrectionWindow();
      showUndo();
    }

    function onPointerDown(evt) {
      if (evt.button !== undefined && evt.button !== 0) return;

      if (isReducedMotion()) {
        /* Fallback: tap avanza subito (senza long-press) */
        var cur = parseInt(el.getAttribute('data-pulse-level') || '0', 10);
        prevLevel = cur;
        applyPulseLevel(el, cur < PULSE_MAX ? cur + 1 : 0);
        showUndo();
        return;
      }

      circle.classList.add('pain-pulse__circle--pressing');
      startArc();

      var currentLevel = parseInt(el.getAttribute('data-pulse-level') || '0', 10);
      if (currentLevel < PULSE_MAX) {
        longPressTimer = setTimeout(function () {
          longPressTimer = null;
          commit();
        }, PAIN_PULSE_MS);
      }
    }

    function onPointerUp() {
      if (longPressTimer !== null) {
        clearTimeout(longPressTimer);
        longPressTimer = null;
      }
      resetArc();
      circle.classList.remove('pain-pulse__circle--pressing');
    }

    function onPointerCancel() { onPointerUp(); }

    /* Tap su dot durante la finestra di correzione 3s */
    var dots = el.querySelectorAll('.pain-pulse__dot');
    Array.prototype.forEach.call(dots, function (dot) {
      dot.addEventListener('click', function (evt) {
        evt.stopPropagation();
        if (!el.classList.contains('pain-pulse--correction-window')) return;
        var targetLevel = parseInt(dot.getAttribute('data-dot') || '0', 10);
        if (targetLevel < 1 || targetLevel > PULSE_MAX) return;
        prevLevel = parseInt(el.getAttribute('data-pulse-level') || '0', 10);
        applyPulseLevel(el, targetLevel);
        if (!isReducedMotion()) {
          /* Mini-bloom contenuto */
          circle.classList.remove('pain-pulse__circle--bloom');
          void circle.offsetWidth;
          circle.classList.add('pain-pulse__circle--bloom');
          circle.addEventListener('animationend', function onEnd() {
            circle.classList.remove('pain-pulse__circle--bloom');
            circle.removeEventListener('animationend', onEnd);
          });
        }
        if (correctionTimer) clearTimeout(correctionTimer);
        el.classList.remove('pain-pulse--correction-window');
        showUndo();
      });
    });

    /* Undo button */
    var undoEl = el.querySelector('.pain-pulse__undo');
    if (undoEl) {
      undoEl.addEventListener('click', function (evt) {
        evt.stopPropagation();
        clearTimeout(undoEl._undoTimer);
        undoEl.classList.remove('pain-pulse__undo--visible');
        applyPulseLevel(el, prevLevel);
        el.classList.remove('pain-pulse--correction-window');
      });
    }

    /* Tastiera: frecce su/giù come fallback */
    circle.addEventListener('keydown', function (evt) {
      var cur = parseInt(el.getAttribute('data-pulse-level') || '0', 10);
      if (evt.key === 'ArrowUp' || evt.key === 'ArrowRight') {
        evt.preventDefault();
        if (cur < PULSE_MAX) { prevLevel = cur; applyPulseLevel(el, cur + 1); showUndo(); }
      } else if (evt.key === 'ArrowDown' || evt.key === 'ArrowLeft') {
        evt.preventDefault();
        if (cur > 0) { prevLevel = cur; applyPulseLevel(el, cur - 1); showUndo(); }
      }
    });

    circle.addEventListener('pointerdown', onPointerDown);
    circle.addEventListener('pointerup', onPointerUp);
    circle.addEventListener('pointercancel', onPointerCancel);
  }

  /* ========================================================================
     3. TimelineToggle
     ========================================================================
     Listener per .segmented-control__option nella schermata timeline.
     Click → aria-selected, mostra/nascondi .timeline-view e .table-view.
     ====================================================================== */

  function initTimelineToggle() {
    var screen = document.querySelector('[data-screen="timeline"]');
    if (!screen) return;

    var options = screen.querySelectorAll('.segmented-control__option');
    var timelineView = screen.querySelector('.timeline-view');
    var tableView = screen.querySelector('.table-view');
    if (!options.length || !timelineView || !tableView) return;

    function switchView(selectedOption) {
      Array.prototype.forEach.call(options, function (opt) {
        var isSelected = opt === selectedOption;
        opt.setAttribute('aria-selected', isSelected ? 'true' : 'false');
        if (isSelected) {
          opt.classList.add('segmented-control__option--active');
        } else {
          opt.classList.remove('segmented-control__option--active');
        }
      });

      var target = selectedOption.getAttribute('data-view');
      if (target === 'timeline') {
        timelineView.removeAttribute('hidden');
        tableView.setAttribute('hidden', '');
      } else if (target === 'table') {
        tableView.removeAttribute('hidden');
        timelineView.setAttribute('hidden', '');
      }
    }

    Array.prototype.forEach.call(options, function (opt) {
      opt.addEventListener('click', function () {
        switchView(opt);
      });
      opt.addEventListener('keydown', function (evt) {
        if (evt.key === 'Enter' || evt.key === ' ') {
          evt.preventDefault();
          switchView(opt);
        }
      });
    });
  }

  /* ========================================================================
     4. BackupSteps
     ========================================================================
     Naviga tra i 3 step del flusso backup aggiornando data-step su
     .backup-steps e i dot di progresso.

     Bottoni con data-step-next e data-step-prev nelle sezioni.
     ====================================================================== */

  function updateBackupProgress(stepsEl, currentStep, totalSteps) {
    var dots = stepsEl.parentElement
      ? stepsEl.parentElement.querySelectorAll('.backup-progress__dot')
      : [];
    Array.prototype.forEach.call(dots, function (dot, index) {
      if (index + 1 === currentStep) {
        dot.classList.add('backup-progress__dot--active');
      } else {
        dot.classList.remove('backup-progress__dot--active');
      }
    });
  }

  function initBackupSteps() {
    var screen = document.querySelector('[data-screen="backup"]');
    if (!screen) return;

    var stepsEl = screen.querySelector('.backup-steps');
    if (!stepsEl) return;

    var TOTAL_STEPS = 3;
    var currentStep = 1;

    function goToStep(step) {
      step = clamp(step, 1, TOTAL_STEPS);
      currentStep = step;
      stepsEl.setAttribute('data-step', String(step));
      updateBackupProgress(stepsEl, step, TOTAL_STEPS);
    }

    /* Inizializza al primo step */
    goToStep(1);

    screen.addEventListener('click', function (evt) {
      var target = evt.target;
      /* Cerca data-step-next */
      while (target && target !== screen) {
        if (target.hasAttribute && target.hasAttribute('data-step-next')) {
          goToStep(currentStep + 1);
          return;
        }
        if (target.hasAttribute && target.hasAttribute('data-step-prev')) {
          goToStep(currentStep - 1);
          return;
        }
        target = target.parentNode;
      }
    });
  }

  /* ========================================================================
     5. Provider selection (step 2 backup)
     ====================================================================== */

  function initProviderSelection() {
    var screen = document.querySelector('[data-screen="backup"]');
    if (!screen) return;

    var options = screen.querySelectorAll('.provider-option');

    function selectProvider(selectedOption) {
      Array.prototype.forEach.call(options, function (opt) {
        var isSelected = opt === selectedOption;
        if (isSelected) {
          opt.classList.add('provider-option--selected');
          opt.setAttribute('aria-checked', 'true');
        } else {
          opt.classList.remove('provider-option--selected');
          opt.setAttribute('aria-checked', 'false');
        }
      });
    }

    Array.prototype.forEach.call(options, function (opt) {
      opt.setAttribute('role', 'radio');
      opt.setAttribute('tabindex', '0');
      opt.addEventListener('click', function () { selectProvider(opt); });
      opt.addEventListener('keydown', function (evt) {
        if (evt.key === 'Enter' || evt.key === ' ') {
          evt.preventDefault();
          selectProvider(opt);
        }
      });
    });

    /* Seleziona il primo di default */
    if (options.length > 0) {
      selectProvider(options[0]);
    }
  }

  /* ========================================================================
     6. Passphrase visibility toggle
     ====================================================================== */

  function initPassphraseToggles() {
    var screen = document.querySelector('[data-screen="backup"]');
    if (!screen) return;

    var toggleBtns = screen.querySelectorAll('.passphrase-field__toggle');
    Array.prototype.forEach.call(toggleBtns, function (btn) {
      btn.addEventListener('click', function () {
        var field = btn.closest('.passphrase-field');
        if (!field) return;
        var input = field.querySelector('.input-text');
        if (!input) return;
        var isPassword = input.type === 'password';
        input.type = isPassword ? 'text' : 'password';
        btn.setAttribute('aria-pressed', isPassword ? 'true' : 'false');
        btn.setAttribute('aria-label', isPassword ? 'Nascondi passphrase' : 'Mostra passphrase');
        /* Ruota l'icona occhio via classe */
        btn.classList.toggle('passphrase-field__toggle--visible', isPassword);
      });
    });
  }

  /* ========================================================================
     Init — attendiamo DOMContentLoaded
     ====================================================================== */

  /* ---------- Symptom Add ------------------------------------------------ */
  function initSymptomAdd() {
    var chipsEl = document.querySelector('.screen--daily-entry .daily-chips');
    var addBtn  = document.getElementById('symptom-add-btn');
    var form    = document.getElementById('symptom-add-form');
    var input   = document.getElementById('symptom-add-input');
    if (!chipsEl || !addBtn || !form || !input) return;

    function openForm() {
      addBtn.hidden = true;
      addBtn.setAttribute('aria-expanded', 'true');
      form.hidden = false;
      input.value = '';
      input.focus();
    }

    function closeForm() {
      form.hidden = true;
      addBtn.hidden = false;
      addBtn.setAttribute('aria-expanded', 'false');
    }

    function addChip(rawLabel) {
      var label = rawLabel.trim();
      if (!label) { closeForm(); return; }
      var chip = document.createElement('button');
      chip.type = 'button';
      chip.className = 'chip chip--selected';
      chip.setAttribute('aria-pressed', 'true');
      chip.innerHTML =
        '<svg viewBox="0 0 16 16" width="12" height="12" fill="none"' +
        ' stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true">' +
        '<path d="M3 8l3 3 7-7"/></svg>' +
        '<span>' + label.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;') + '</span>';
      chip.addEventListener('click', function () {
        var pressed = chip.getAttribute('aria-pressed') === 'true';
        chip.setAttribute('aria-pressed', String(!pressed));
        chip.classList.toggle('chip--selected', !pressed);
      });
      chipsEl.insertBefore(chip, addBtn);
      closeForm();
    }

    addBtn.addEventListener('click', openForm);

    form.addEventListener('submit', function (e) {
      e.preventDefault();
      addChip(input.value);
    });

    input.addEventListener('keydown', function (e) {
      if (e.key === 'Escape') { e.preventDefault(); closeForm(); }
    });

    input.addEventListener('blur', function () {
      setTimeout(function () {
        if (!form.contains(document.activeElement)) { closeForm(); }
      }, 150);
    });
  }

  function initAll() {
    /* Rising Fill (flusso) */
    var risingEls = document.querySelectorAll('[data-gesture="rising-fill"]');
    Array.prototype.forEach.call(risingEls, function (el) { initRisingFill(el); });

    /* Pain Pulse (dolore) */
    var pulseEls = document.querySelectorAll('[data-gesture="pain-pulse"]');
    Array.prototype.forEach.call(pulseEls, function (el) { initPainPulse(el); });

    /* Timeline toggle */
    initTimelineToggle();

    /* Backup steps */
    initBackupSteps();

    /* Provider selection */
    initProviderSelection();

    /* Passphrase toggle */
    initPassphraseToggles();

    /* Symptom add */
    initSymptomAdd();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initAll);
  } else {
    initAll();
  }

})();
