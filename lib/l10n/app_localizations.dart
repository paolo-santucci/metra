import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_it.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('it'),
    Locale('en')
  ];

  /// App name displayed in the wordmark and title bar
  ///
  /// In it, this message translates to:
  /// **'Mētra'**
  String get common_appName;

  /// Generic loading indicator label
  ///
  /// In it, this message translates to:
  /// **'Caricamento…'**
  String get common_loading;

  /// Generic save button
  ///
  /// In it, this message translates to:
  /// **'Salva'**
  String get common_save;

  /// Generic cancel button
  ///
  /// In it, this message translates to:
  /// **'Annulla'**
  String get common_cancel;

  /// Generic delete button
  ///
  /// In it, this message translates to:
  /// **'Elimina'**
  String get common_delete;

  /// Generic confirmation button
  ///
  /// In it, this message translates to:
  /// **'OK'**
  String get common_ok;

  /// Generic error message shown when an operation fails unexpectedly
  ///
  /// In it, this message translates to:
  /// **'Qualcosa è andato storto. Riprova.'**
  String get common_error_generic;

  /// Title of the daily entry screen
  ///
  /// In it, this message translates to:
  /// **'Registro giornaliero'**
  String get daily_entry_title;

  /// Section heading for the flow intensity picker
  ///
  /// In it, this message translates to:
  /// **'Flusso'**
  String get daily_entry_flow_label;

  /// Flow level: no flow at all
  ///
  /// In it, this message translates to:
  /// **'Nessun flusso'**
  String get daily_entry_flow_none;

  /// Flow level: spotting (established medical loanword, do not translate)
  ///
  /// In it, this message translates to:
  /// **'Spotting'**
  String get daily_entry_flow_spotting;

  /// Flow level: light flow. Includes noun so it reads naturally in accessibility labels.
  ///
  /// In it, this message translates to:
  /// **'Flusso leggero'**
  String get daily_entry_flow_light;

  /// Flow level: moderate flow
  ///
  /// In it, this message translates to:
  /// **'Flusso moderato'**
  String get daily_entry_flow_medium;

  /// Flow level: heavy flow
  ///
  /// In it, this message translates to:
  /// **'Flusso intenso'**
  String get daily_entry_flow_heavy;

  /// Flow level: very heavy flow
  ///
  /// In it, this message translates to:
  /// **'Flusso molto intenso'**
  String get daily_entry_flow_veryHeavy;

  /// Section heading for the pain intensity slider
  ///
  /// In it, this message translates to:
  /// **'Dolore'**
  String get daily_entry_pain_label;

  /// Pain level: no pain
  ///
  /// In it, this message translates to:
  /// **'Nessun dolore'**
  String get daily_entry_pain_none;

  /// Pain level: mild pain
  ///
  /// In it, this message translates to:
  /// **'Lieve'**
  String get daily_entry_pain_mild;

  /// Pain level: moderate pain
  ///
  /// In it, this message translates to:
  /// **'Moderato'**
  String get daily_entry_pain_moderate;

  /// Pain level: severe pain
  ///
  /// In it, this message translates to:
  /// **'Intenso'**
  String get daily_entry_pain_severe;

  /// Section heading for the symptom chips
  ///
  /// In it, this message translates to:
  /// **'Sintomi'**
  String get daily_entry_symptoms_label;

  /// Symptom chip: menstrual cramps
  ///
  /// In it, this message translates to:
  /// **'Crampi'**
  String get daily_entry_symptom_cramps;

  /// Symptom chip: back pain
  ///
  /// In it, this message translates to:
  /// **'Mal di schiena'**
  String get daily_entry_symptom_backPain;

  /// Symptom chip: headache
  ///
  /// In it, this message translates to:
  /// **'Mal di testa'**
  String get daily_entry_symptom_headache;

  /// Symptom chip: migraine
  ///
  /// In it, this message translates to:
  /// **'Emicrania'**
  String get daily_entry_symptom_migraine;

  /// Symptom chip: bloating
  ///
  /// In it, this message translates to:
  /// **'Gonfiore'**
  String get daily_entry_symptom_bloating;

  /// Symptom chip: custom user-defined symptom
  ///
  /// In it, this message translates to:
  /// **'Personalizzato'**
  String get daily_entry_symptom_custom;

  /// Placeholder text for the custom symptom name input field
  ///
  /// In it, this message translates to:
  /// **'Nome del sintomo…'**
  String get daily_entry_symptom_custom_placeholder;

  /// Section heading for the notes field
  ///
  /// In it, this message translates to:
  /// **'Note'**
  String get daily_entry_notes_label;

  /// Placeholder text inside the notes text field
  ///
  /// In it, this message translates to:
  /// **'Aggiungi una nota…'**
  String get daily_entry_notes_placeholder;

  /// Save button on the daily entry screen
  ///
  /// In it, this message translates to:
  /// **'Salva'**
  String get daily_entry_save;

  /// Cancel button on the daily entry screen — discards unsaved changes
  ///
  /// In it, this message translates to:
  /// **'Annulla'**
  String get daily_entry_cancel;

  /// Title of the confirmation dialog when the user wants to delete a daily entry
  ///
  /// In it, this message translates to:
  /// **'Elimina registro'**
  String get daily_entry_delete_confirmation_title;

  /// Body text of the delete confirmation dialog
  ///
  /// In it, this message translates to:
  /// **'Eliminare i dati di questo giorno? Questa azione non può essere annullata.'**
  String get daily_entry_delete_confirmation_body;

  /// Month and year heading in the calendar header, e.g. 'aprile 2026'
  ///
  /// In it, this message translates to:
  /// **'{month} {year}'**
  String calendar_month_title(String month, String year);

  /// Accessibility label for the previous-month navigation button
  ///
  /// In it, this message translates to:
  /// **'Mese precedente'**
  String get calendar_prev_month;

  /// Accessibility label for the next-month navigation button
  ///
  /// In it, this message translates to:
  /// **'Mese successivo'**
  String get calendar_next_month;

  /// Label used to refer to today's date
  ///
  /// In it, this message translates to:
  /// **'Oggi'**
  String get calendar_today;

  /// Empty-state message shown when the calendar month has no logged entries
  ///
  /// In it, this message translates to:
  /// **'Nessun dato registrato per questo mese.\nTocca un giorno per iniziare.'**
  String get calendar_empty_state;

  /// Calendar legend entry for days with logged flow
  ///
  /// In it, this message translates to:
  /// **'Flusso'**
  String get calendar_legend_flow;

  /// Calendar legend entry for spotting days
  ///
  /// In it, this message translates to:
  /// **'Spotting'**
  String get calendar_legend_spotting;

  /// Calendar legend entry for predicted cycle days
  ///
  /// In it, this message translates to:
  /// **'Previsione'**
  String get calendar_legend_prediction;

  /// Calendar legend entry for days that have a note
  ///
  /// In it, this message translates to:
  /// **'Note'**
  String get calendar_legend_notes;

  /// Label preceding the predicted next cycle date range
  ///
  /// In it, this message translates to:
  /// **'Prossimo ritmo previsto:'**
  String get calendar_prediction_label;

  /// Accessibility label for the floating action button on the calendar screen
  ///
  /// In it, this message translates to:
  /// **'Aggiungi o modifica il registro di oggi'**
  String get calendar_fab_label;

  /// Settings row label for language selection
  ///
  /// In it, this message translates to:
  /// **'Lingua'**
  String get settings_language_label;

  /// Settings row label for theme selection
  ///
  /// In it, this message translates to:
  /// **'Tema'**
  String get settings_theme_label;

  /// Theme option: follow system setting
  ///
  /// In it, this message translates to:
  /// **'Sistema'**
  String get settings_theme_system;

  /// Theme option: light mode
  ///
  /// In it, this message translates to:
  /// **'Chiaro'**
  String get settings_theme_light;

  /// Theme option: dark mode
  ///
  /// In it, this message translates to:
  /// **'Scuro'**
  String get settings_theme_dark;

  /// Settings row label for cycle reminder notifications toggle
  ///
  /// In it, this message translates to:
  /// **'Promemoria ciclo'**
  String get settings_notifications_label;

  /// Notifications toggle state: on
  ///
  /// In it, this message translates to:
  /// **'Attive'**
  String get settings_notifications_on;

  /// Notifications toggle state: off
  ///
  /// In it, this message translates to:
  /// **'Disattivate'**
  String get settings_notifications_off;

  /// Settings row label for cloud backup (stub — UI ships later)
  ///
  /// In it, this message translates to:
  /// **'Backup cloud'**
  String get settings_backup_label;

  /// Settings backup row value when cloud backup has not been set up
  ///
  /// In it, this message translates to:
  /// **'Non configurato'**
  String get settings_backup_not_configured;

  /// Settings action to export data as a CSV file
  ///
  /// In it, this message translates to:
  /// **'Esporta CSV'**
  String get settings_export_csv;

  /// Settings danger-zone action to delete all user data
  ///
  /// In it, this message translates to:
  /// **'Cancella tutti i dati'**
  String get settings_delete_all;

  /// Accessibility label for a calendar day with no logged data
  ///
  /// In it, this message translates to:
  /// **'Nessun dato, {date}'**
  String a11y_calendar_day_no_flow(String date);

  /// Accessibility label for a calendar day with logged flow. flowLevel comes from daily_entry_flow_* labels (e.g. 'Flusso leggero, 15 aprile').
  ///
  /// In it, this message translates to:
  /// **'{flowLevel}, {date}'**
  String a11y_calendar_day_flow(String flowLevel, String date);

  /// Accessibility label for a calendar day with spotting logged
  ///
  /// In it, this message translates to:
  /// **'Spotting, {date}'**
  String a11y_calendar_day_spotting(String date);

  /// Accessibility label suffix added when a calendar day has a note
  ///
  /// In it, this message translates to:
  /// **'{date}, con nota'**
  String a11y_calendar_day_has_note(String date);

  /// Accessibility label for a predicted-cycle day on the calendar
  ///
  /// In it, this message translates to:
  /// **'Ciclo previsto, {date}'**
  String a11y_calendar_day_prediction(String date);

  /// Accessibility label for today's date on the calendar
  ///
  /// In it, this message translates to:
  /// **'Oggi, {date}'**
  String a11y_calendar_day_today(String date);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'it'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'it':
      return AppLocalizationsIt();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
