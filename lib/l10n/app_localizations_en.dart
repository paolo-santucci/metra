// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get common_appName => 'Mētra';

  @override
  String get common_loading => 'Loading…';

  @override
  String get common_save => 'Save';

  @override
  String get common_cancel => 'Cancel';

  @override
  String get common_delete => 'Delete';

  @override
  String get common_ok => 'OK';

  @override
  String get common_error_generic => 'Something went wrong. Please try again.';

  @override
  String get daily_entry_title => 'Daily log';

  @override
  String get daily_entry_flow_label => 'Flow';

  @override
  String get daily_entry_flow_none => 'No flow';

  @override
  String get daily_entry_flow_spotting => 'Spotting';

  @override
  String get daily_entry_flow_light => 'Light flow';

  @override
  String get daily_entry_flow_medium => 'Moderate flow';

  @override
  String get daily_entry_flow_heavy => 'Heavy flow';

  @override
  String get daily_entry_flow_veryHeavy => 'Very heavy flow';

  @override
  String get daily_entry_pain_label => 'Pain';

  @override
  String get daily_entry_pain_none => 'No pain';

  @override
  String get daily_entry_pain_mild => 'Mild';

  @override
  String get daily_entry_pain_moderate => 'Moderate';

  @override
  String get daily_entry_pain_severe => 'Severe';

  @override
  String get daily_entry_symptoms_label => 'Symptoms';

  @override
  String get daily_entry_symptom_cramps => 'Cramps';

  @override
  String get daily_entry_symptom_backPain => 'Back pain';

  @override
  String get daily_entry_symptom_headache => 'Headache';

  @override
  String get daily_entry_symptom_migraine => 'Migraine';

  @override
  String get daily_entry_symptom_bloating => 'Bloating';

  @override
  String get daily_entry_symptom_custom => 'Custom';

  @override
  String get daily_entry_symptom_custom_placeholder => 'Symptom name…';

  @override
  String get daily_entry_notes_label => 'Notes';

  @override
  String get daily_entry_notes_placeholder => 'Add a note…';

  @override
  String get daily_entry_save => 'Save';

  @override
  String get daily_entry_cancel => 'Cancel';

  @override
  String get daily_entry_delete_confirmation_title => 'Delete log';

  @override
  String get daily_entry_delete_confirmation_body =>
      'Delete the data for this day? This action cannot be undone.';

  @override
  String calendar_month_title(String month, String year) {
    return '$month $year';
  }

  @override
  String get calendar_prev_month => 'Previous month';

  @override
  String get calendar_next_month => 'Next month';

  @override
  String get calendar_today => 'Today';

  @override
  String get calendar_empty_state =>
      'No data logged for this month.\nTap a day to get started.';

  @override
  String get calendar_legend_flow => 'Flow';

  @override
  String get calendar_legend_spotting => 'Spotting';

  @override
  String get calendar_legend_prediction => 'Prediction';

  @override
  String get calendar_legend_notes => 'Notes';

  @override
  String get calendar_prediction_label => 'Next predicted cycle:';

  @override
  String get calendar_fab_label => 'Add or edit today\'s log';

  @override
  String get settings_language_label => 'Language';

  @override
  String get settings_theme_label => 'Theme';

  @override
  String get settings_theme_system => 'System';

  @override
  String get settings_theme_light => 'Light';

  @override
  String get settings_theme_dark => 'Dark';

  @override
  String get settings_notifications_label => 'Cycle reminder';

  @override
  String get settings_notifications_on => 'On';

  @override
  String get settings_notifications_off => 'Off';

  @override
  String get settings_backup_label => 'Cloud backup';

  @override
  String get settings_backup_not_configured => 'Not configured';

  @override
  String get settings_export_csv => 'Export CSV';

  @override
  String get settings_delete_all => 'Delete all data';

  @override
  String a11y_calendar_day_no_flow(String date) {
    return 'No data, $date';
  }

  @override
  String a11y_calendar_day_flow(String flowLevel, String date) {
    return '$flowLevel, $date';
  }

  @override
  String a11y_calendar_day_spotting(String date) {
    return 'Spotting, $date';
  }

  @override
  String a11y_calendar_day_has_note(String date) {
    return '$date, with note';
  }

  @override
  String a11y_calendar_day_prediction(String date) {
    return 'Predicted cycle, $date';
  }

  @override
  String a11y_calendar_day_today(String date) {
    return 'Today, $date';
  }
}
