# Métra — Implementation Spec (2026-05-01)

Source of truth: `design/Métra Screens Light.html` · `design/Métra Quick Entry.html`  
Screenshots analyzed: calendar (10:06) and today/quick-entry (10:07) on 2026-05-01.

---

## CALENDAR FIXES

### C-1 · Remove FAB from calendar screen

**Problem:** A terracotta `FloatingActionButton` (+ icon) is present at `calendar_screen.dart:169–177`.  
It navigates to `/oggi` (today's screen) — nothing in the design mockup includes this button.  
The only add/edit action on the calendar is the "Modifica giornata" button inside the day-detail card.

**Design spec:** `ScreenCalendario` in `Métra Screens Light.html` — no FAB anywhere. The whole screen is a `flexDirection: column` that fits within the phone without any overlay element.

**Change required:**  
`lib/features/calendar/calendar_screen.dart` — delete the `floatingActionButton` parameter from `Scaffold` (lines 163–178). The scaffold should be:
```dart
return Scaffold(
  backgroundColor: bgColor,
  body: SafeArea(...),
  // no floatingActionButton
);
```

---

### C-2 · Day cells: rounded squares, not circles

**Problem:** `CalendarDay` (`calendar_day.dart`) renders all day states as circles (diameter 36dp). Design uses `borderRadius: 12` on a `48×48dp` square.

**Design spec** (`Métra Screens Light.html`, `CalDay` component):
```js
width: 48, height: 48, borderRadius: 12
background: isSel  ? C.inchiostro            // selected  → solid ink fill, no border
          : isFlow ? `${C.terracotta}22`      // flow      → tinted terracotta, thin border terracotta44
          : 'transparent'                     // default   → transparent
border:    isSel  ? 'none'
         : isFlow ? `1px solid ${C.terracotta}44`
         : isPred ? `1.5px dashed ${C.lavanda}66`   // prediction → lavender dashed border
         : '1px solid transparent'
```
Text color:
```js
color: isSel ? C.sabbia     // white text on ink
     : isFlow ? C.inchiostro
     : 'rgba(43,37,33,0.6)'  // faded ink for empty days
fontWeight: isSel ? 600 : 400
```
**Today indicator:** The design has NO explicit "today" indicator. Keep a subtle today ring in the implementation (thin 1.5pt ink ring) as a usability necessity, but size it as a rounded-rect ring, not a circle.

**Changes required — `lib/features/calendar/widgets/calendar_day.dart`:**

1. Replace `BoxShape.circle` with `borderRadius: BorderRadius.circular(12)` everywhere.
2. Cell size: `48×48dp` (currently 36dp circle diameter).
3. State logic:
   - **Selected**: `color: textPrimary (ink)`, text `color: bgPrimary (sand)`, `fontWeight: w600`, no border.
   - **Flow (mestruazioni)**: `color: accentFlow.withValues(alpha: 0.13)`, `border: 1px solid accentFlow.withValues(alpha: 0.27)`.
   - **Spotting**: `color: accentFlow.withValues(alpha: 0.07)`, `border: 1px dashed accentFlow.withValues(alpha: 0.22)`.
   - **Prediction**: `color: transparent`, `border: 1.5px dashed accentPrediction.withValues(alpha: 0.40)`.
   - **Today (unselected)**: `border: 1.5px solid textPrimary.withValues(alpha: 0.35)`, rounded-rect.
   - **Default**: transparent, faded text.
4. Text: `fontSize: 15`, `fontFamily: Inter`, weight as above.

---

### C-3 · Fill empty space below grid — day-detail card always visible

**Problem:** `_DayDetailCard` only renders `if (_selectedDate != null)`. When the screen first loads with no selection, a large empty area (~200dp) appears below the last calendar row.

**Design spec:** Day-detail card has `flex: 1` — it always fills the remaining space. Default selection = today's date.

**Changes required — `lib/features/calendar/calendar_screen.dart`:**

1. Initialize `_selectedDate` to today's date in `_CalendarScreenState`:
   ```dart
   late DateTime _selectedDate;

   @override
   void initState() {
     super.initState();
     final now = DateTime.now();
     _selectedDate = DateTime.utc(now.year, now.month, now.day);
   }
   ```
2. Remove the `if (_selectedDate != null)` guard — card is always shown.
3. Change all `_selectedDate!` → `_selectedDate` (non-nullable now).
4. `_CalendarGrid` gets `selectedDate: _selectedDate` (always a value).
5. `onDaySelected` callback: `setState(() => _selectedDate = date)`.
6. Pass `log: monthState.logs[_selectedDate]` to `_DayDetailCard` — may be null (that's fine, card shows "Nessun dato registrato").

---

### C-4 · "Modifica giornata" — confirm route and fix FAB confusion

**Analysis:** The route itself is correct: `context.push('/daily-entry/$dateStr')` → `HistoricalEntryScreen`. The user confusion is caused by the FAB navigating to `/oggi` (a wrong shortcut). Removing the FAB (C-1) resolves C-4.

**Verify:** `lib/router/app_router.dart` route `/daily-entry/:date` must map to `HistoricalEntryScreen(date: date)`. Confirm `HistoricalEntryScreen` loads existing log data for that date and pre-populates the form. No code change needed beyond C-1.

---

## QUICK-ENTRY FIXES

### Q-1 · Flow intensity dots — soft halo, fixed size

**Problem:** Selected dot grows from 36→48dp and shows a hard 2px border. Design uses a fixed-size dot with a soft semi-transparent halo ring.

**Design spec** (`Métra Quick Entry.html`, `FlowDot` component):
```js
// Dot: R=18, viewBox=50×50
// Unselected: filled circle, color at lower opacity
// Selected: same filled circle + <circle r={R+5} stroke=terracotta strokeWidth="1.2" opacity="0.3" fill="none" />
// → soft outer ring at R+5 (23px from center), 1.2pt stroke, 30% opacity
// Label: color = sel ? C.tc_scura : 'rgba(43,37,33,0.4)', fontWeight = sel ? 600 : 400
```

**Changes required — `lib/features/daily_entry/widgets/flow_intensity_dots.dart`:**

1. Remove size change on selection — dot Container stays `36×36dp` always.
2. Remove `Border.all(...)` on selected state.
3. Wrap dot in a `Stack` or use `CustomPaint` to draw the halo ring when selected:
   - Halo circle: center same as dot, `radius = 18 + 5 = 23dp`, stroke `1.2dp`, `accentFlow.withValues(alpha: 0.30)`, no fill.
   - Or: `Container(width: 46, height: 46)` with `BoxDecoration(shape: BoxShape.circle, border: Border.all(color: accentFlow.withValues(alpha: 0.30), width: 1.2))` wrapping the filled `36dp` dot with centered alignment.
4. Label: when selected → `color: accentFlowStrong (tc_scura)`, `fontWeight: w600`. Unselected → `color: textPrimary.withValues(alpha: 0.40)`, `fontWeight: w400`.
5. Spacing: gap between dots = `10dp` (not 8dp), using `SizedBox(width: 10)`.
6. Layout: use `Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min)` — do NOT use `Expanded` on each dot.
7. Outer padding: `EdgeInsets.fromLTRB(0, 16, 0, 2)`.

---

### Q-2 · Flow intensity spacing — fixed gap, centered

Already covered in Q-1 item 5–7 above.

**Summary:** Replace `Expanded` flex with centered fixed-gap row. Gap = 10dp. Vertical padding: 16dp top, 2dp bottom.

---

### Q-3 · Pain circles — soft halo + label color

**Problem:** Selected pain circle shows a hard 2.5px border. Label color doesn't change. Design uses same soft-halo pattern as flow dots but in malva.

**Design spec** (`Métra Quick Entry.html`, `PainDot` component):
```js
// Halo when selected: r={R+5}, stroke=C.malva, strokeWidth="1.2", opacity="0.28", fill="none"
// Label: color = sel ? C.malva : 'rgba(43,37,33,0.38)', fontWeight = sel ? 600 : 400
```

**Changes required — `lib/features/daily_entry/widgets/circle_pain_picker.dart`:**

1. Remove hard `BorderSide` on selected state.
2. Add halo ring: same technique as Q-1 — outer ring `radius + 5dp`, `1.2dp` stroke, `accentPain (malva).withValues(alpha: 0.28)`.
3. Label: when selected → `color: accentPain`, `fontWeight: w600`. Unselected → `color: textPrimary.withValues(alpha: 0.38)`, `fontWeight: w400`.
4. Dot size: fixed, same unselected/selected.

---

### Q-4 · Symptom chips — terracotta fill only, no border, no checkmark when selected

**Problem:** Selected symptom chip shows:
- A 1.5px border (`borderSelected = accentWarmthStrong`) — design shows NO border (transparent).
- A 12px checkmark icon — design shows no checkmark in chip, only fill + text color change.

**Design spec** (`Métra Quick Entry.html`, chip component):
```js
background: selected ? C.terracotta : 'rgba(43,37,33,0.07)'
border: `1px solid ${selected ? 'transparent' : 'rgba(43,37,33,0.12)'}`
color:  selected ? C.sabbia : C.inchiostro       // sand text on terracotta, ink text on light
```

**Changes required — `lib/core/widgets/choice_chip_metra.dart`:**

1. When selected: `Border.all(color: Colors.transparent)` (or remove border entirely).
2. When selected: background = `accentFlow` (terracotta), text = `bgPrimary` (sand/white).
3. Remove the checkmark `Icon(Icons.check, ...)` from the selected branch entirely.
4. Token mapping:
   - `bgSelected` → `MetraColors.light/dark.accentFlow` (terracotta)
   - `fgSelected` → `MetraColors.light/dark.bgPrimary` (sand for light, deepNight for dark)
   - `bgDefault` → `textPrimary.withValues(alpha: 0.07)`
   - `borderDefault` → `textPrimary.withValues(alpha: 0.12)`
   - `borderSelected` → `Colors.transparent`

> **Note:** The current ochre/warmth theme for chips was a deliberate deviation from the design. These changes revert to the design's terracotta + sand pattern.

---

### Q-5 · "+ Aggiungi" button — inline custom symptom input

**Problem:** `_AddSymptomChip` is a static widget with no `onTap` handler.

**Design spec** (`Métra Screens Light.html`, inline symptom editor, lines 782–812):
- Tap "Aggiungi" → inline text field replaces the chip
- Placeholder: `"es. Vertigini"`
- Typing → "OK" button appears alongside the text field
- Confirm → adds the symptom as a new chip (custom type) + closes editor
- Empty/dismiss → reverts to "+ Aggiungi" chip

**Changes required:**

1. Convert `_AddSymptomChip` in `today_screen.dart` from `StatelessWidget` to a stateful inline widget (or lift state to `_TodayScreenState`).
2. Add a `bool _addingSymptom` flag and a `TextEditingController _customSymptomController` to `_TodayScreenState`.
3. When `_addingSymptom == false`: show the existing dashed "+ Aggiungi" chip with `onTap: () => setState(() => _addingSymptom = true)`.
4. When `_addingSymptom == true`: show a compact `TextField` (border: same dashed style, height 36dp) with "OK" `TextButton` adjacent. On OK: if text non-empty, add `PainSymptomType.custom` entry (or a string-keyed custom type) to `_selectedSymptoms`. On dismiss/empty: `setState(() => _addingSymptom = false)`.

> **Domain note:** `PainSymptomType.custom` exists in the enum. Persistence of custom symptom *names* requires schema work (currently `PainSymptomType` is an enum without a label). For now, implement the UI gesture and store it as `PainSymptomType.custom` with the label shown inline only.

---

## ADDITIONAL GAPS (beyond the 7 known issues)

### G-1 · Missing Onboarding Privacy screen (screen 2 of 3)

**Status:** CRITICAL — entire screen missing.

**Design spec** (`Métra Screens Light.html`, `ScreenOnboarding2`):
- Screen 2 of a 3-step flow ("Passo 2 di 3")
- Heading: "La tua privacy è il fondamento."
- Three trust-building items with icons:
  1. Lock icon — "Tutto sul tuo dispositivo" / "I dati non lasciano mai il tuo telefono."
  2. Cloud-off icon — "Nessun account necessario" / "Usi l'app senza registrarti da nessuna parte."
  3. Export icon — "Esporti sempre i tuoi dati" / "Puoi scaricare tutto in qualsiasi momento."
- CTA: "Continua" button (dark ink, same as welcome CTA)

**Changes required:**

1. Add a third `PageView` child to `OnboardingScreen` (`onboarding_screen.dart`).
2. Create `_PrivacyPage` widget following the same two-zone layout as `_WelcomePage`.
3. Update step progress bar from `total: 2` to `total: 3`; page 1 shows step 1/3, privacy shows 2/3, data entry shows 3/3.
4. Add l10n strings (`app_it.arb`, `app_en.arb`):
   - `onboarding_privacy_heading`
   - `onboarding_privacy_item1_title` / `_body`
   - `onboarding_privacy_item2_title` / `_body`
   - `onboarding_privacy_item3_title` / `_body`
   - `onboarding_privacy_continue`
5. Update `onboarding_screen_test.dart`: step counter assertions.

---

### G-2 · Calendar day-detail card — show symptoms

**Status:** Moderate — card exists but shows only flow badge and "Nessun dato".

**Design spec** (`Métra Screens Light.html`, day detail card):
- If the day has symptoms logged, show up to 2 symptom chips below the flow badge (same ochre chip style).
- A "+N" overflow label if more than 2.

**Changes required — `lib/features/calendar/calendar_screen.dart` (`_DayDetailCard`):**

1. Accept a `List<PainSymptomData>? symptoms` parameter.
2. If `symptoms?.isNotEmpty == true`, render a `Wrap` of up to 2 `ChoiceChipMetra` (display-only, `onSelected: (_) {}`) below the flow row.
3. If `symptoms!.length > 2`, append a `Text('+${symptoms.length - 2}')` label.
4. Load symptoms via `ref.watch(painSymptomsProvider(selectedDate))` in `CalendarScreen` and pass them down.

---

### G-3 · Historical entry screen — verify pre-population

**Status:** Needs verification.

`HistoricalEntryScreen` at `lib/features/daily_entry/historical_entry_screen.dart` should load the existing `DailyLogEntity` for the given date and pre-populate the form. Confirm:
- Flow type / intensity pre-populated.
- Pain intensity pre-populated.
- Symptoms pre-populated.
- Notes pre-populated.

If any field is not loading from the provider, fix the `_initFromLog` / `_initSymptoms` pattern (same as `TodayScreen`).

---

## IMPLEMENTATION ORDER (recommended)

| Priority | Issue | Effort | Files |
|----------|-------|--------|-------|
| P0 | C-1: Remove FAB | XS | `calendar_screen.dart` |
| P0 | C-3: Default selected date + always show card | S | `calendar_screen.dart` |
| P0 | C-2: Rounded-square day cells | M | `calendar_day.dart` |
| P1 | Q-4: Symptom chip colors (no border, no checkmark, terracotta) | S | `choice_chip_metra.dart` |
| P1 | Q-1/Q-2: Flow intensity dots (soft halo, fixed size, centered) | M | `flow_intensity_dots.dart` |
| P1 | Q-3: Pain circles (soft halo, label color) | M | `circle_pain_picker.dart` |
| P2 | Q-5: "+ Aggiungi" inline input | M | `today_screen.dart` |
| P2 | G-1: Privacy onboarding screen | L | `onboarding_screen.dart`, l10n |
| P3 | G-2: Symptom chips in day-detail card | M | `calendar_screen.dart` |
| P3 | G-3: Verify HistoricalEntryScreen pre-population | S | `historical_entry_screen.dart` |
| P3 | C-4: Verify route (no change expected) | XS | `app_router.dart` |

---

## KEY DESIGN TOKENS (for reference)

```
C.sabbia         = #F4EDE2   → MetraColors.light.bgPrimary
C.terracotta     = #C87456   → MetraColors.light.accentFlow
C.tc_scura       = #9A4D32   → MetraColors.light.accentFlowStrong
C.inchiostro     = #2B2521   → MetraColors.light.textPrimary
C.surface        = #FAF5EE   → MetraColors.light.bgSurface
C.malva          = #9E7488   → MetraColors.light.accentPain
C.ocra           = #D4A26A   → MetraColors.light.accentWarmth
C.lavanda        = #5B4E7A   → MetraColors.light.accentPrediction
```

Section card background: `C.surface` + top/bottom border `rgba(43,37,33,0.07)` = `textPrimary.withValues(alpha: 0.07)`.
