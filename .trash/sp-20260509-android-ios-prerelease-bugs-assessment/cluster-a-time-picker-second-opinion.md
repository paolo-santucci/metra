# Time Picker Dial — Second Opinion

## 1. Verdict

The bug-hunter was **partially correct**: `dotRadius` and the ring geometry are indeed hardcoded and unreachable via `TimePickerThemeData`, but the cited values are wrong (dial is `256×256`, not `280×280`), the claimed "~20 px overlap" mis-measures the geometry, and the report missed that `dialTextStyle` **is** overridable — and that Métra's override is actively making the visual crowding worse.

---

## 2. Evidence

| Fact | Source |
|---|---|
| `_kTimePickerInnerDialOffset = 28.0` | `time_picker.dart:49` |
| `_kTimePickerDialPadding = 28.0` | `time_picker.dart:51` |
| M3 `dialSize = Size.square(256.0)` (not 280) | `time_picker.dart:3747–3748` |
| M3 `dotRadius = 48.0 / 2 = 24.0` | `time_picker.dart:3757–3758` |
| `dotRadius` is read from `defaultTheme`, not `timePickerTheme` | `time_picker.dart:1691` |
| `dialTextStyle` IS in `TimePickerThemeData` | `time_picker_theme.dart:60` |
| M3 24-hour dial places hours 12–23 at `inner: true` | `time_picker.dart:1533` |
| Inner-ring labels use `textScaler: clamp(maxScaleFactor: 2.0)` | `time_picker.dart:1517` |
| Dial widget is `SizedBox.fromSize(size: defaultTheme.dialSize)` — no override path | `time_picker.dart:3044–3045` |

**Geometry (256×256 dial):**
- `dialRadius = 128`, `labelRadius = 100`, `innerLabelRadius = 72`
- When selector is on outer ring: selector edge extends inward to **76 px**
- Inner ring label center is at **72 px** — selector edge clears label center by **+4 px**
- The "20 px overlap" in the bug report is not geometrically correct for the single-selector scenario

**M3 same-theta intentional behavior:** When the outer-ring label (e.g. "11") is selected, the code clips the selected-color version of the same-theta inner label (e.g. "23") *inside* the selector circle via `clipPath + selectedLabels` (`time_picker.dart:1117–1122`). This is M3 spec, not a bug. It looks like the inner label is "inside" the selector because it is — on purpose.

---

## 3. Why Google's apps look fine

Google's reference apps use the M3 default `dialTextStyle = bodyLarge` (≈14–16 pt, w400), which fits within the 28 px gap between label rings. Métra overrides to `fontSize: 18, fontWeight: w600` (`settings_screen.dart:499–502`), inflating the glyphs by ~15 % in height and making strokes visibly thicker. With only 4 px geometric clearance between the selector edge and the inner-ring label center, the larger label bounding box crosses into the selector circle noticeably. Google's apps do render the same same-theta inner label inside the selector (it is M3 spec), but with default-sized thin labels the effect is barely visible. Métra's bolder labels make it conspicuous.

---

## 4. Viable Fix Paths

**Fix A — Remove the `dialTextStyle` override** (recommended)

In `settings_screen.dart`, delete `dialTextStyle: Theme.of(ctx).textTheme.bodyLarge?.copyWith(...)`.  
The dial will inherit the M3 default `bodyLarge` from `_TimePickerDefaultsM3.dialTextStyle` (line 3777–3778 of time_picker.dart).  
Effort: delete 4 lines. Downside: none; the default is exactly what Material 3 intends for this context.

**Fix B — Tune `hourMinuteTextStyle` for the header**

The M3 default for dial mode is `displayLarge` (time_picker.dart:3908), which maps to Métra's `displayHero = DM Serif Display 56 pt`. Métra's current override (52 pt) is actually *smaller* than what the theme would inject without the override — so unsetting it would make the header larger, not smaller. The fix is to keep the override but reduce to a calmer size (36–40 pt). This is independent of the dial crowding issue.  
Effort: change `fontSize: 52` to `fontSize: 38` (1 line). Downside: none; aligns with M3 guidance (~`displayMedium` which is typically 45 pt, but Métra's DM Serif Display merits slightly smaller).

**Fix C — `TimePickerEntryMode.input`**

Completely removes the dial and shows numeric text fields. No geometry issues.  
Effort: add `initialEntryMode: TimePickerEntryMode.input` to `showTimePicker()` (1 line). Downside: significant UX regression — no visual clock, unfamiliar on Android, not matching the Métra design voice.

**Fix D — `MediaQuery` text-scale override on the builder**

Wrapping the dialog in `MediaQuery(data: MediaQuery.of(ctx).copyWith(textScaler: TextScaler.noScaling), ...)` would not help: the label painter already clamps the scaler at 2.0 (`time_picker.dart:1517`), and the issue is the `fontSize` in the override, not system text scaling.  
Effort: medium. Verdict: ineffective for this problem.

**Fix E — Custom dial widget**

Full replacement of the dial. Weeks of work. Not viable for this milestone.

---

## 5. Recommendation

Apply Fix A (remove `dialTextStyle` override) and Fix B (lower `hourMinuteTextStyle` to ≈38 pt) — both are one-line changes in `settings_screen.dart`. Before declaring done, confirm on a device whether the remaining same-theta inner-label artifact is visible: if the selector sits on "11" and "23" appears inside the blue circle, that is M3 spec behavior and not a rendering defect.
