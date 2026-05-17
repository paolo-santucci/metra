# Assessment: Calendar Feature
## Feature: first-day-of-week-setting
## Date: 2026-05-10

---

## 1. Two hardcoded Monday-first points in `CalendarScreen`

### 1a. Day-of-week header labels

**Location**: `_CalendarScreenState.build()` (or a computed property near it)

**Current code** (approx.):
```dart
static final DateTime _weekAnchorMonday = DateTime(2024, 1, 1); // known Monday

List<String> get _dayLabels {
  final locale = Localizations.localeOf(context).toString();
  return List.generate(7, (i) =>
    DateFormat('EEEEE', locale)
      .format(_weekAnchorMonday.add(Duration(days: i)))
      .toUpperCase(),
  );
}
```
This always produces Mon–Sun order.

**Required change**: compute `firstWeekday` (resolved int, 1=Mon or 7=Sun), then:
```dart
List<String> _dayLabels(int firstWeekday) {
  final locale = Localizations.localeOf(context).toString();
  // offset from Monday anchor: (firstWeekday - 1) days
  // then rotate 7 positions with modulo
  return List.generate(7, (i) {
    final offset = (firstWeekday - 1 + i) % 7; // 0=Mon…6=Sun
    return DateFormat('EEEEE', locale)
        .format(_weekAnchorMonday.add(Duration(days: offset)))
        .toUpperCase();
  });
}
```

**Verification** (Monday-first, firstWeekday=1):
- i=0: (1-1+0)%7=0 → Mon ✓
- i=6: (1-1+6)%7=6 → Sun ✓

**Verification** (Sunday-first, firstWeekday=7):
- i=0: (7-1+0)%7=6 → Sun ✓
- i=1: (7-1+1)%7=0 → Mon ✓
- i=6: (7-1+6)%7=5 → Sat ✓

### 1b. Leading blanks in `_CalendarGrid`

**Current code**:
```dart
int get _leadingBlanks {
  // weekday: 1=Mon…7=Sun; subtract 1 for 0-based Monday-first offset
  return DateTime(year, month, 1).weekday - 1;
}
```

**Required change**: accept `firstWeekday` parameter:
```dart
int _leadingBlanks(int firstWeekday) {
  final firstOfMonth = DateTime(year, month, 1).weekday; // 1=Mon…7=Sun
  return (firstOfMonth - firstWeekday + 7) % 7;
}
```

**Verification** (May 1 2026 = Thursday, weekday=4):
- Monday-first (firstWeekday=1): (4-1+7)%7 = 3 blanks ✓ (Mon Tue Wed | Thu)
- Sunday-first (firstWeekday=7): (4-7+7)%7 = 4 blanks ✓ (Sun Mon Tue Wed | Thu)

---

## 2. `firstWeekday` resolution (widget level)

Resolved in `CalendarScreen.build()` before passing to children:

```dart
int _resolveFirstWeekday(
  FirstDayOfWeekSetting setting,
  BuildContext context,
) {
  return switch (setting) {
    FirstDayOfWeekSetting.monday => DateTime.monday,   // 1
    FirstDayOfWeekSetting.sunday => DateTime.sunday,   // 7
    FirstDayOfWeekSetting.system => () {
      // MaterialLocalizations.firstDayOfWeekIndex: 0=Sunday, 1=Monday
      final idx = MaterialLocalizations.of(context).firstDayOfWeekIndex;
      return idx == 0 ? DateTime.sunday : DateTime.monday;
    }(),
  };
}
```

Settings access:
```dart
final setting = ref.watch(settingsNotifierProvider)
    .valueOrNull?.firstDayOfWeek ?? FirstDayOfWeekSetting.system;
final firstWeekday = _resolveFirstWeekday(setting, context);
```

---

## 3. Widget parameter threading

`_DayOfWeekHeader` already accepts `labels: List<String>` — no widget change needed.

`_CalendarGrid` needs one new parameter:
```dart
final int firstWeekday; // 1=Monday or 7=Sunday
```

`_CalendarGrid._leadingBlanks` becomes a method taking `firstWeekday`.

---

## 4. Rebuild scope

`ref.watch(settingsNotifierProvider)` is already called in `CalendarScreen.build()` (or `_CalendarScreenState.build()`). The grid and header rebuild only when settings or month/year change — no new rebuild surface added.

No `GlobalKey`, no `Timer`, no `setState` needed.

---

## 5. Files in scope for this layer

| File | Action |
|------|--------|
| `lib/features/calendar/calendar_screen.dart` | MODIFY — `_dayLabels`, `_leadingBlanks`, `_resolveFirstWeekday`, `_CalendarGrid.firstWeekday` param |
