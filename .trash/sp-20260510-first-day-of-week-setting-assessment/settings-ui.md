# Assessment: Settings UI
## Feature: first-day-of-week-setting
## Date: 2026-05-10

---

## 1. Settings screen change — `lib/features/settings/settings_screen.dart`

### New row in "Preferenze" section

Currently the Preferenze section has: Language, Theme.
New row to add: First day of week (after Theme, before any other row).

Pattern to follow: `_showLanguagePicker` / `_showThemePicker` — modal bottom sheet
with `ListTile` options and a leading `Icon` for the selected item.

### New method: `_showFirstDayOfWeekPicker`

```dart
void _showFirstDayOfWeekPicker(BuildContext context, AppSettingsData settings) {
  final l10n = AppLocalizations.of(context)!;
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: false,   // consistent with other pickers
    builder: (_) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final value in FirstDayOfWeekSetting.values)
            ListTile(
              title: Text(_firstDayLabel(value, l10n)),
              trailing: settings.firstDayOfWeek == value
                  ? const Icon(Icons.check)
                  : null,
              onTap: () {
                ref.read(settingsNotifierProvider.notifier).save(
                  settings.copyWith(firstDayOfWeek: value),
                );
                Navigator.of(context).pop();
              },
            ),
        ],
      ),
    ),
  );
}

static String _firstDayLabel(FirstDayOfWeekSetting v, AppLocalizations l10n) =>
    switch (v) {
      FirstDayOfWeekSetting.system => l10n.settings_first_day_of_week_system,
      FirstDayOfWeekSetting.sunday => l10n.settings_first_day_of_week_sunday,
      FirstDayOfWeekSetting.monday => l10n.settings_first_day_of_week_monday,
    };
```

### New `_SettingsRow` in build tree

```dart
_SettingsRow(
  label: l10n.settings_first_day_of_week_label,
  valueText: _firstDayLabel(settings.firstDayOfWeek, l10n),
  onTap: () => _showFirstDayOfWeekPicker(context, settings),
),
```

Note: `copyWith` is safe here (unlike the dark-mode workaround). `firstDayOfWeek`
is a non-nullable enum — no full-constructor workaround needed.

---

## 2. L10n keys — `lib/l10n/app_en.arb` and `lib/l10n/app_it.arb`

### English (app_en.arb)
```json
"settings_first_day_of_week_label": "First day of week",
"settings_first_day_of_week_system": "System",
"settings_first_day_of_week_sunday": "Sunday",
"settings_first_day_of_week_monday": "Monday"
```

### Italian (app_it.arb)
```json
"settings_first_day_of_week_label": "Primo giorno della settimana",
"settings_first_day_of_week_system": "Automatico",
"settings_first_day_of_week_sunday": "Domenica",
"settings_first_day_of_week_monday": "Lunedì"
```

Note: "Automatico" is preferred over "Sistema" for Italian — more natural in a
consumer-app context.

---

## 3. Wave-0 design artifact updates (mandatory before any Flutter UI change)

Per the UI change protocol, the following must be updated **before** any Flutter
code in this feature is written:

1. **`docs/design/metra-screens-light.html`** — add the new row in the Preferences
   section of the Settings screen mockup. Show it with "Automatico" as the default
   value (Italian UI). Row style matches existing Language / Theme rows.

2. **`.claude/docs/canon/ui-design-bible.md`** — document the new row in the
   Settings screen section with the three option values and their Italian/English
   translations.

This is Wave-0 in the build plan and blocks all other waves.

---

## 4. `SettingsNotifier` — no changes needed

`save(AppSettingsData)` already persists any `AppSettingsData`. No changes to
`lib/features/settings/state/settings_notifier.dart`.

---

## 5. Files in scope for this layer

| File | Action |
|------|--------|
| `docs/design/metra-screens-light.html` | MODIFY (Wave-0) — add first-day-of-week row |
| `.claude/docs/canon/ui-design-bible.md` | MODIFY (Wave-0) — document new setting |
| `lib/features/settings/settings_screen.dart` | MODIFY — new row + picker method |
| `lib/l10n/app_en.arb` | MODIFY — 4 new keys |
| `lib/l10n/app_it.arb` | MODIFY — 4 new keys |
