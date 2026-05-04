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

  /// Label for the spotting toggle in the daily entry form. Spotting and flow are mutually exclusive. 'Spotting' is an established medical loanword in Italian — do not translate.
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

  /// Symptom chip: fatigue
  ///
  /// In it, this message translates to:
  /// **'Stanchezza'**
  String get daily_entry_symptom_fatigue;

  /// Symptom chip: nausea
  ///
  /// In it, this message translates to:
  /// **'Nausea'**
  String get daily_entry_symptom_nausea;

  /// Symptom chip: breast tenderness
  ///
  /// In it, this message translates to:
  /// **'Tensione mammaria'**
  String get daily_entry_symptom_breastTenderness;

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
  /// **'Circostanze, colore, consistenza…'**
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

  /// Title for the prediction notification
  ///
  /// In it, this message translates to:
  /// **'Il tuo ciclo si avvicina'**
  String get notification_prediction_title;

  /// Body text for the prediction notification
  ///
  /// In it, this message translates to:
  /// **'La finestra stimata inizia tra {days} giorni'**
  String notification_prediction_body(int days);

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

  /// Settings backup row value when cloud backup is connected (BackupConnected). Flat-descriptive mirror of settings_backup_not_configured — never 'Connesso' or 'Attivo', never the account email.
  ///
  /// In it, this message translates to:
  /// **'Configurato'**
  String get settings_backup_configured;

  /// Settings action to export data as a CSV file
  ///
  /// In it, this message translates to:
  /// **'Esporta CSV'**
  String get settings_export_csv;

  /// Settings danger-zone action to delete all user data
  ///
  /// In it, this message translates to:
  /// **'Elimina tutti i dati'**
  String get settings_delete_all;

  /// Settings screen page title
  ///
  /// In it, this message translates to:
  /// **'Impostazioni'**
  String get settings_screen_title;

  /// Settings group header: appearance preferences
  ///
  /// In it, this message translates to:
  /// **'Preferenze'**
  String get settings_section_preferences;

  /// Settings group header: daily log options
  ///
  /// In it, this message translates to:
  /// **'Registro'**
  String get settings_section_log;

  /// Settings group header: notification options
  ///
  /// In it, this message translates to:
  /// **'Notifiche'**
  String get settings_section_notifications;

  /// Settings group header: privacy and data
  ///
  /// In it, this message translates to:
  /// **'Dati'**
  String get settings_section_privacy;

  /// Settings group header: danger zone (destructive actions)
  ///
  /// In it, this message translates to:
  /// **'Azioni irreversibili'**
  String get settings_section_danger;

  /// Settings toggle label: enable pain tracking in daily log
  ///
  /// In it, this message translates to:
  /// **'Dolore'**
  String get settings_pain_label;

  /// Settings toggle label: enable daily notes in daily log
  ///
  /// In it, this message translates to:
  /// **'Note giornaliere'**
  String get settings_notes_label;

  /// Settings row label: days before predicted cycle start for notification
  ///
  /// In it, this message translates to:
  /// **'Preavviso'**
  String get settings_advance_label;

  /// Current value displayed for the advance notification setting
  ///
  /// In it, this message translates to:
  /// **'{n, plural, =1{1 giorno prima} other{{n} giorni prima}}'**
  String settings_advance_value(int n);

  /// Language option: follow system locale
  ///
  /// In it, this message translates to:
  /// **'Automatica'**
  String get settings_language_system;

  /// Language option: Italian
  ///
  /// In it, this message translates to:
  /// **'Italiano'**
  String get settings_language_it;

  /// Language option: English
  ///
  /// In it, this message translates to:
  /// **'Inglese'**
  String get settings_language_en;

  /// Title of the delete-all confirmation dialog
  ///
  /// In it, this message translates to:
  /// **'Elimina tutti i dati'**
  String get settings_delete_all_confirm_title;

  /// Body text of the delete-all confirmation dialog
  ///
  /// In it, this message translates to:
  /// **'Questa operazione è irreversibile. Tutto il registro sarà eliminato. Le impostazioni resteranno invariate.'**
  String get settings_delete_all_confirm_body;

  /// Snackbar text shown for stub/not-yet-implemented settings rows
  ///
  /// In it, this message translates to:
  /// **'Prossimamente'**
  String get settings_coming_soon;

  /// Snackbar shown after delete-all data completes successfully
  ///
  /// In it, this message translates to:
  /// **'Dati eliminati'**
  String get settings_delete_all_done;

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

  /// Empty-state hint on the timeline and table views
  ///
  /// In it, this message translates to:
  /// **'Registra il tuo primo ciclo per vedere la timeline'**
  String get timeline_empty_hint;

  /// Badge on the current (in-progress) cycle card
  ///
  /// In it, this message translates to:
  /// **'In corso'**
  String get timeline_cycle_in_progress;

  /// Cycle length label on a timeline card, e.g. '28 g'
  ///
  /// In it, this message translates to:
  /// **'{n} g'**
  String timeline_cycle_length_days(int n);

  /// Accessibility label for a timeline card
  ///
  /// In it, this message translates to:
  /// **'Ciclo dal {start} al {end}, {n} giorni'**
  String timeline_card_a11y(String start, String end, int n);

  /// Accessibility label for an in-progress cycle card
  ///
  /// In it, this message translates to:
  /// **'Ciclo dal {start}, in corso'**
  String timeline_card_a11y_in_progress(String start);

  /// Archivio screen title (§ 10.1)
  ///
  /// In it, this message translates to:
  /// **'Archivio'**
  String get archive_title;

  /// Duration label on an archive card, e.g. 'Durata 5g'
  ///
  /// In it, this message translates to:
  /// **'Durata {n}g'**
  String archive_card_duration_days(int n);

  /// Footer line on an archive card, e.g. 'Ciclo 28g · dal 15 gen'
  ///
  /// In it, this message translates to:
  /// **'Ciclo {len}g · dal {day}'**
  String archive_card_footer(int len, String day);

  /// Table column header: month (§ 10.2)
  ///
  /// In it, this message translates to:
  /// **'Mese'**
  String get table_col_month;

  /// Table column header: cycle duration (§ 10.2)
  ///
  /// In it, this message translates to:
  /// **'Dur.'**
  String get table_col_duration;

  /// Table column header: flow (§ 10.2)
  ///
  /// In it, this message translates to:
  /// **'Flusso'**
  String get table_col_flow;

  /// Table column header: cycle length
  ///
  /// In it, this message translates to:
  /// **'Ciclo'**
  String get table_col_cycle;

  /// Placeholder shown when cycle length is unknown
  ///
  /// In it, this message translates to:
  /// **'—'**
  String get table_cycle_dash;

  /// Shown when there are no complete cycles to display
  ///
  /// In it, this message translates to:
  /// **'Dati insufficienti'**
  String get stats_insufficient_data;

  /// Statistiche screen header title (§ 11.1)
  ///
  /// In it, this message translates to:
  /// **'Statistiche'**
  String get stats_title;

  /// Statistiche screen header subtitle (§ 11.1)
  ///
  /// In it, this message translates to:
  /// **'Ultimi 6 cicli'**
  String get stats_subtitle;

  /// Summary card title (§ 11.3)
  ///
  /// In it, this message translates to:
  /// **'Durata media ciclo'**
  String get stats_card_cycle_length_title;

  /// Summary card unit: days
  ///
  /// In it, this message translates to:
  /// **'giorni'**
  String get stats_card_cycle_length_unit;

  /// Summary card sub: cycle length range
  ///
  /// In it, this message translates to:
  /// **'Range: {min}–{max}g'**
  String stats_card_cycle_length_sub(int min, int max);

  /// Summary card title (§ 11.3)
  ///
  /// In it, this message translates to:
  /// **'Durata media flusso'**
  String get stats_card_period_length_title;

  /// Summary card unit: days
  ///
  /// In it, this message translates to:
  /// **'giorni'**
  String get stats_card_period_length_unit;

  /// Summary card sub: period length range
  ///
  /// In it, this message translates to:
  /// **'Range: {min}–{max}g'**
  String stats_card_period_length_sub(int min, int max);

  /// Summary card title: average pain (§ 11.3)
  ///
  /// In it, this message translates to:
  /// **'Dolore medio'**
  String get stats_card_pain_title;

  /// Summary card unit: pain scale /3
  ///
  /// In it, this message translates to:
  /// **'/3'**
  String get stats_card_pain_unit;

  /// Pain trend sub: decreasing
  ///
  /// In it, this message translates to:
  /// **'Trend in calo'**
  String get stats_card_pain_trend_decreasing;

  /// Pain trend sub: increasing
  ///
  /// In it, this message translates to:
  /// **'Trend in aumento'**
  String get stats_card_pain_trend_increasing;

  /// Pain trend sub: stable
  ///
  /// In it, this message translates to:
  /// **'Trend stabile'**
  String get stats_card_pain_trend_stable;

  /// Summary card title: tracked cycles (§ 11.3)
  ///
  /// In it, this message translates to:
  /// **'Cicli tracciati'**
  String get stats_card_cycles_title;

  /// Summary card unit: total
  ///
  /// In it, this message translates to:
  /// **'totali'**
  String get stats_card_cycles_unit;

  /// MiniBar chart title: cycle length (§ 11.4)
  ///
  /// In it, this message translates to:
  /// **'Durata ciclo (giorni)'**
  String get stats_chart_cycle_length_title;

  /// MiniBar chart title: pain intensity (§ 11.4)
  ///
  /// In it, this message translates to:
  /// **'Intensità dolore (0–3)'**
  String get stats_chart_pain_title;

  /// Symptom frequency card title (§ 11.5)
  ///
  /// In it, this message translates to:
  /// **'Sintomi più frequenti'**
  String get stats_symptom_card_title;

  /// Segmented control label for timeline view
  ///
  /// In it, this message translates to:
  /// **'Timeline'**
  String get timeline_view_toggle;

  /// Segmented control label for table view
  ///
  /// In it, this message translates to:
  /// **'Tabella'**
  String get table_view_toggle;

  /// Settings action to import data from a CSV file
  ///
  /// In it, this message translates to:
  /// **'Importa CSV'**
  String get settings_import_csv;

  /// Privacy warning shown before sharing the CSV export
  ///
  /// In it, this message translates to:
  /// **'Questo file contiene dati sanitari in chiaro. Condividilo solo con app o persone di cui ti fidi.'**
  String get csv_export_privacy_warning;

  /// Confirm button on the CSV export privacy warning
  ///
  /// In it, this message translates to:
  /// **'Continua'**
  String get csv_export_privacy_confirm;

  /// Body of the dialog shown when the CSV has parse errors
  ///
  /// In it, this message translates to:
  /// **'Trovate {count} righe con dati non validi.'**
  String csv_import_errors_dialog(int count);

  /// Button to abort the import when parse errors are found
  ///
  /// In it, this message translates to:
  /// **'Annulla importazione'**
  String get csv_import_abort;

  /// Button to skip invalid rows and continue the import
  ///
  /// In it, this message translates to:
  /// **'Salta e continua'**
  String get csv_import_skip_continue;

  /// Title of the import mode picker dialog
  ///
  /// In it, this message translates to:
  /// **'Modalità importazione'**
  String get csv_import_mode_title;

  /// Import mode: delete all existing data, then import
  ///
  /// In it, this message translates to:
  /// **'Elimina tutto e importa'**
  String get csv_import_mode_delete;

  /// Import mode: upsert CSV rows, DB-only rows untouched
  ///
  /// In it, this message translates to:
  /// **'Importa e sovrascrivi'**
  String get csv_import_mode_overwrite;

  /// Import mode: insert only dates absent from DB
  ///
  /// In it, this message translates to:
  /// **'Importa, mantieni esistenti'**
  String get csv_import_mode_keep;

  /// Snackbar shown after a successful import with no skips
  ///
  /// In it, this message translates to:
  /// **'Importate {count} righe'**
  String csv_import_success(int count);

  /// Snackbar shown after a successful import where some rows were skipped
  ///
  /// In it, this message translates to:
  /// **'Importate {count} righe, saltate {skipped}'**
  String csv_import_success_skipped(int count, int skipped);

  /// Backup screen page title
  ///
  /// In it, this message translates to:
  /// **'Backup'**
  String get backup_screen_title;

  /// Body text shown on the backup screen when no provider is connected
  ///
  /// In it, this message translates to:
  /// **'I tuoi dati restano sul dispositivo. Collega Dropbox per conservare una copia cifrata nel cloud — solo tu puoi leggerla.'**
  String get backup_not_connected_body;

  /// Button to initiate Dropbox OAuth connection
  ///
  /// In it, this message translates to:
  /// **'Collega Dropbox'**
  String get backup_connect_dropbox;

  /// Status line showing the connected Dropbox account email
  ///
  /// In it, this message translates to:
  /// **'Connesso come: {email}'**
  String backup_connected_as(String email);

  /// Status shown when no backup has ever been created
  ///
  /// In it, this message translates to:
  /// **'Mai salvato'**
  String get backup_last_backup_never;

  /// Status showing the date and time of the last backup
  ///
  /// In it, this message translates to:
  /// **'Ultimo backup: {datetime}'**
  String backup_last_backup_at(String datetime);

  /// Button to trigger an immediate backup
  ///
  /// In it, this message translates to:
  /// **'Salva ora'**
  String get backup_now;

  /// Button to restore data from the cloud backup
  ///
  /// In it, this message translates to:
  /// **'Ripristina dal backup'**
  String get backup_restore;

  /// Button to disconnect the cloud provider account
  ///
  /// In it, this message translates to:
  /// **'Disconnetti'**
  String get backup_disconnect;

  /// Status text shown while a backup operation is running
  ///
  /// In it, this message translates to:
  /// **'Salvataggio in corso…'**
  String get backup_in_progress;

  /// Status text shown while a restore operation is running
  ///
  /// In it, this message translates to:
  /// **'Ripristino in corso…'**
  String get backup_restore_in_progress;

  /// Title of the passphrase setup dialog shown before the first backup
  ///
  /// In it, this message translates to:
  /// **'Imposta una passphrase'**
  String get backup_passphrase_title;

  /// Explanatory body text in the passphrase setup dialog
  ///
  /// In it, this message translates to:
  /// **'Questa passphrase cifra il tuo backup. Se la perdi, il backup non può essere recuperato — non esiste un reset.'**
  String get backup_passphrase_body;

  /// Label for the passphrase input field
  ///
  /// In it, this message translates to:
  /// **'Passphrase'**
  String get backup_passphrase_input_label;

  /// Label for the passphrase confirmation input field
  ///
  /// In it, this message translates to:
  /// **'Conferma passphrase'**
  String get backup_passphrase_confirm_label;

  /// Validation error shown when the two passphrase fields do not match
  ///
  /// In it, this message translates to:
  /// **'Le passphrase non corrispondono.'**
  String get backup_passphrase_mismatch;

  /// Validation error shown when the passphrase is shorter than 8 characters
  ///
  /// In it, this message translates to:
  /// **'La passphrase deve essere di almeno 8 caratteri.'**
  String get backup_passphrase_too_short;

  /// Confirm button in the passphrase setup dialog; acknowledges the no-reset warning
  ///
  /// In it, this message translates to:
  /// **'Ho capito — salva e fai il backup'**
  String get backup_passphrase_confirm_button;

  /// Title of the passphrase prompt shown before restoring a backup. The user must re-enter the passphrase used to encrypt the cloud backup.
  ///
  /// In it, this message translates to:
  /// **'Inserisci la passphrase'**
  String get backup_passphrase_unlock_title;

  /// Explanatory body text in the passphrase unlock dialog (restore flow)
  ///
  /// In it, this message translates to:
  /// **'Inserisci la passphrase usata per cifrare il backup. Senza la passphrase corretta il backup non può essere decifrato.'**
  String get backup_passphrase_unlock_body;

  /// Confirm button in the passphrase unlock dialog (restore flow)
  ///
  /// In it, this message translates to:
  /// **'Sblocca e ripristina'**
  String get backup_passphrase_unlock_button;

  /// Title of the restore confirmation dialog
  ///
  /// In it, this message translates to:
  /// **'Ripristinare il backup?'**
  String get backup_restore_confirm_title;

  /// Body text of the restore confirmation dialog
  ///
  /// In it, this message translates to:
  /// **'Tutti i dati attuali verranno sostituiti. Questa operazione non può essere annullata.'**
  String get backup_restore_confirm_body;

  /// Confirm button in the restore confirmation dialog
  ///
  /// In it, this message translates to:
  /// **'Ripristina'**
  String get backup_restore_confirm_button;

  /// Error message shown when the entered passphrase does not decrypt the backup
  ///
  /// In it, this message translates to:
  /// **'Passphrase errata. Riprova.'**
  String get backup_error_wrong_passphrase;

  /// Generic error message shown when a backup or restore operation fails
  ///
  /// In it, this message translates to:
  /// **'Backup fallito. Riprova.'**
  String get backup_error_generic;

  /// Error message shown when no backup file is found in the connected Dropbox account
  ///
  /// In it, this message translates to:
  /// **'Nessun backup trovato su Dropbox.'**
  String get backup_error_no_backup_found;

  /// Title of the Dropbox disconnect confirmation dialog
  ///
  /// In it, this message translates to:
  /// **'Disconnettere Dropbox?'**
  String get backup_disconnect_confirm_title;

  /// Body text of the Dropbox disconnect confirmation dialog
  ///
  /// In it, this message translates to:
  /// **'Il backup nel cloud non verrà eliminato.'**
  String get backup_disconnect_confirm_body;

  /// Confirm button in the Dropbox disconnect confirmation dialog
  ///
  /// In it, this message translates to:
  /// **'Disconnetti'**
  String get backup_disconnect_confirm_button;

  /// Title shown on the onboarding welcome screen
  ///
  /// In it, this message translates to:
  /// **'Il tuo ritmo,\ncustodito.'**
  String get onboarding_tagline;

  /// Body text on the onboarding welcome screen
  ///
  /// In it, this message translates to:
  /// **'Mētra è un quaderno silenzioso per conoscerti, ciclo dopo ciclo.\n\nTutto rimane sul tuo telefono: nessun account, nessun cloud richiesto.'**
  String get onboarding_privacy_line;

  /// Label for the last period date picker on onboarding
  ///
  /// In it, this message translates to:
  /// **'Primo giorno dell\'ultima mestruazione'**
  String get onboarding_last_period_question;

  /// Label for the cycle length stepper on onboarding
  ///
  /// In it, this message translates to:
  /// **'Quanto dura di solito il tuo ciclo?'**
  String get onboarding_cycle_length_question;

  /// Label for the period duration picker on onboarding screen
  ///
  /// In it, this message translates to:
  /// **'Durata flusso'**
  String get onboarding_period_duration_label;

  /// CTA button on the onboarding welcome screen
  ///
  /// In it, this message translates to:
  /// **'Inizia'**
  String get onboarding_get_started;

  /// Unit label for cycle length stepper
  ///
  /// In it, this message translates to:
  /// **'giorni'**
  String get onboarding_days_unit;

  /// Step counter shown on onboarding data page
  ///
  /// In it, this message translates to:
  /// **'Passo {current} di {total}'**
  String onboarding_step_label(int current, int total);

  /// Main headline on onboarding data-entry screen (step 2 of 2)
  ///
  /// In it, this message translates to:
  /// **'Raccontami\nil tuo ciclo.'**
  String get onboarding_headline;

  /// Subhead below headline on onboarding data-entry screen
  ///
  /// In it, this message translates to:
  /// **'Puoi sempre modificarlo dopo. Non servono risposte precise.'**
  String get onboarding_subhead;

  /// Micro-label above cycle-length stepper on onboarding
  ///
  /// In it, this message translates to:
  /// **'Durata media ciclo'**
  String get onboarding_cycle_length_label;

  /// CTA on onboarding data-entry screen; arrow is part of the label
  ///
  /// In it, this message translates to:
  /// **'Tutto pronto →'**
  String get onboarding_all_set;

  /// Placeholder text in the date input when no date is selected
  ///
  /// In it, this message translates to:
  /// **'Seleziona data'**
  String get onboarding_date_placeholder;

  /// Settings group header: about section
  ///
  /// In it, this message translates to:
  /// **'Informazioni'**
  String get settings_section_about;

  /// Settings row label: link to the privacy policy
  ///
  /// In it, this message translates to:
  /// **'Informativa sulla privacy'**
  String get settings_privacy_policy;

  /// Settings row label: link to the help centre
  ///
  /// In it, this message translates to:
  /// **'Guida'**
  String get settings_help_label;

  /// Settings row label: link to GitHub source code
  ///
  /// In it, this message translates to:
  /// **'Codice sorgente'**
  String get settings_github_label;

  /// Settings footer label above the Ko-Fi donation button
  ///
  /// In it, this message translates to:
  /// **'Sostieni il progetto'**
  String get settings_support_label;

  /// Ko-fi pill label in settings footer
  ///
  /// In it, this message translates to:
  /// **'Ko-fi · Sostieni il progetto'**
  String get settings_kofi_label;

  /// Chip label for no flow (user explicitly confirmed no bleeding)
  ///
  /// In it, this message translates to:
  /// **'Assente'**
  String get daily_entry_flow_chip_assente;

  /// Chip label for menstrual flow
  ///
  /// In it, this message translates to:
  /// **'Intensità'**
  String get daily_entry_flow_chip_intensita;

  /// Chip label for spotting. 'Spotting' is an established medical loanword in Italian — do not translate.
  ///
  /// In it, this message translates to:
  /// **'Spotting'**
  String get daily_entry_flow_chip_spotting;

  /// Dot label for light menstrual flow intensity
  ///
  /// In it, this message translates to:
  /// **'Leggero'**
  String get daily_entry_flow_intensity_light;

  /// Dot label for moderate menstrual flow intensity
  ///
  /// In it, this message translates to:
  /// **'Moderato'**
  String get daily_entry_flow_intensity_medium;

  /// Dot label for heavy menstrual flow intensity
  ///
  /// In it, this message translates to:
  /// **'Abbondante'**
  String get daily_entry_flow_intensity_heavy;

  /// Contextual note shown when spotting is selected
  ///
  /// In it, this message translates to:
  /// **'Piccola perdita fuori dal flusso mestruale. Non è necessariamente l\'inizio del ciclo.'**
  String get daily_entry_spotting_note;

  /// Confirmation text shown with a check icon when assente is selected
  ///
  /// In it, this message translates to:
  /// **'Nessun flusso oggi'**
  String get daily_entry_assente_confirmation;

  /// Save button label on daily entry screens
  ///
  /// In it, this message translates to:
  /// **'Salva giornata'**
  String get daily_entry_save_action;

  /// Today screen main heading
  ///
  /// In it, this message translates to:
  /// **'Come stai oggi?'**
  String get today_how_are_you;

  /// Pain intensity section heading
  ///
  /// In it, this message translates to:
  /// **'Intensità dolore'**
  String get today_pain_intensity_label;

  /// Free notes section heading
  ///
  /// In it, this message translates to:
  /// **'Nota libera'**
  String get today_notes_label;

  /// Notes text field placeholder
  ///
  /// In it, this message translates to:
  /// **'Scrivi qualcosa…'**
  String get today_notes_hint;

  /// Save button label
  ///
  /// In it, this message translates to:
  /// **'Salva giornata'**
  String get today_save_day;

  /// Add symptom chip label (the '+' icon is rendered separately in code)
  ///
  /// In it, this message translates to:
  /// **'Aggiungi'**
  String get today_add_symptom;

  /// Flow circle label: light
  ///
  /// In it, this message translates to:
  /// **'Lieve'**
  String get today_flow_lieve;

  /// Flow circle label: medium
  ///
  /// In it, this message translates to:
  /// **'Moderato'**
  String get today_flow_moderato;

  /// Flow circle label: heavy
  ///
  /// In it, this message translates to:
  /// **'Intenso'**
  String get today_flow_intenso;

  /// Pain circle label: no pain
  ///
  /// In it, this message translates to:
  /// **'Nessuno'**
  String get today_pain_none;

  /// Bottom nav tab: today entry
  ///
  /// In it, this message translates to:
  /// **'Oggi'**
  String get nav_oggi;

  /// Bottom nav tab: archive/timeline
  ///
  /// In it, this message translates to:
  /// **'Archivio'**
  String get nav_archivio;

  /// Calendar legend: flow/mestruazioni chip label
  ///
  /// In it, this message translates to:
  /// **'Mestruazioni'**
  String get calendar_legend_mestruazioni;

  /// Calendar legend: symptoms chip label
  ///
  /// In it, this message translates to:
  /// **'Sintomi'**
  String get calendar_legend_sintomi;

  /// Calendar legend: pain chip label
  ///
  /// In it, this message translates to:
  /// **'Dolore'**
  String get calendar_legend_dolore;

  /// Calendar day detail card: empty state when no log exists
  ///
  /// In it, this message translates to:
  /// **'Nessun dato registrato'**
  String get calendar_day_detail_no_data;

  /// Calendar day detail card: button to create a new entry for a day with no log
  ///
  /// In it, this message translates to:
  /// **'Aggiungi giornata'**
  String get calendar_day_detail_add;

  /// Calendar day detail card: button to open historical entry screen
  ///
  /// In it, this message translates to:
  /// **'Modifica giornata'**
  String get calendar_day_detail_edit;

  /// Calendar day detail card: cycle day number
  ///
  /// In it, this message translates to:
  /// **'Giorno {day} del ciclo'**
  String calendar_day_detail_cycle_day(int day);
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
