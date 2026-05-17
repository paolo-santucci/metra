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
  String get common_restore => 'Restore';

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
  String get daily_entry_symptom_fatigue => 'Fatigue';

  @override
  String get daily_entry_symptom_nausea => 'Nausea';

  @override
  String get daily_entry_symptom_breastTenderness => 'Breast tenderness';

  @override
  String get daily_entry_symptom_custom_placeholder => 'Symptom name…';

  @override
  String get daily_entry_notes_label => 'Notes';

  @override
  String get daily_entry_notes_placeholder =>
      'Circumstances, colour, consistency…';

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
  String get notification_prediction_title => 'Your cycle is approaching';

  @override
  String notification_prediction_body(num days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'in $days days',
      one: 'tomorrow',
    );
    return '$_temp0';
  }

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
  String get settings_first_day_of_week_label => 'First day of week';

  @override
  String get settings_first_day_of_week_system => 'Automatic';

  @override
  String get settings_first_day_of_week_sunday => 'Sunday';

  @override
  String get settings_first_day_of_week_monday => 'Monday';

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
  String get settings_backup_configured => 'Configured';

  @override
  String get settings_export_csv => 'Export CSV';

  @override
  String get settings_delete_all => 'Delete all data';

  @override
  String get settings_screen_title => 'Settings';

  @override
  String get settings_section_preferences => 'Preferences';

  @override
  String get settings_section_log => 'Log';

  @override
  String get settings_section_notifications => 'Notifications';

  @override
  String get settings_section_privacy => 'Data';

  @override
  String get settings_section_danger => 'Irreversible actions';

  @override
  String get settings_pain_label => 'Pain';

  @override
  String get settings_notes_label => 'Daily notes';

  @override
  String get settings_advance_label => 'Advance notice';

  @override
  String settings_advance_value(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n days before',
      one: '1 day before',
    );
    return '$_temp0';
  }

  @override
  String get settings_notification_time_label => 'Reminder time';

  @override
  String settings_notification_time_value(String time) {
    return '$time';
  }

  @override
  String get settings_battery_optimization_label => 'Background scheduling';

  @override
  String get settings_battery_optimization_subtitle =>
      'Opens system settings to exempt Mētra from battery optimisation. Cycle reminders will arrive at the scheduled time.';

  @override
  String get settings_battery_optimization_semantics_label =>
      'Open battery optimisation settings';

  @override
  String get settings_language_system => 'Automatic';

  @override
  String get settings_language_it => 'Italian';

  @override
  String get settings_language_en => 'English';

  @override
  String get settings_delete_all_confirm_title => 'Delete all data';

  @override
  String get settings_delete_all_confirm_body =>
      'This cannot be undone. All log entries will be deleted. Your settings will remain unchanged.';

  @override
  String get settings_coming_soon => 'Coming soon';

  @override
  String get settings_delete_all_done => 'Data deleted';

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

  @override
  String get timeline_empty_hint => 'Log your first cycle to see the timeline';

  @override
  String get timeline_cycle_in_progress => 'In progress';

  @override
  String timeline_cycle_length_days(int n) {
    return '$n d';
  }

  @override
  String timeline_card_a11y(String start, String end, int n) {
    return 'Cycle from $start to $end, $n days';
  }

  @override
  String timeline_card_a11y_in_progress(String start) {
    return 'Cycle from $start, in progress';
  }

  @override
  String get archive_title => 'Archive';

  @override
  String archive_card_duration_days(int n) {
    return 'Duration ${n}d';
  }

  @override
  String archive_card_footer(int len, String day) {
    return 'Cycle ${len}d · from $day';
  }

  @override
  String get archive_card_duration_unknown => 'Duration —';

  @override
  String archive_card_footer_unknown(String day) {
    return 'Cycle — · from $day';
  }

  @override
  String get archive_card_note_label => 'Note';

  @override
  String get table_col_month => 'Month';

  @override
  String get table_col_duration => 'Dur.';

  @override
  String get table_col_flow => 'Flow';

  @override
  String get table_col_cycle => 'Cycle';

  @override
  String get table_cycle_dash => '—';

  @override
  String table_days_short(int n) {
    return '${n}d';
  }

  @override
  String get stats_insufficient_data => 'Insufficient data';

  @override
  String get stats_title => 'Statistics';

  @override
  String get stats_subtitle => 'Last 6 cycles';

  @override
  String get stats_card_cycle_length_title => 'Average cycle length';

  @override
  String get stats_card_cycle_length_unit => 'days';

  @override
  String stats_card_cycle_length_sub(int min, int max) {
    return 'Range: $min–${max}d';
  }

  @override
  String get stats_card_period_length_title => 'Average period length';

  @override
  String get stats_card_period_length_unit => 'days';

  @override
  String stats_card_period_length_sub(int min, int max) {
    return 'Range: $min–${max}d';
  }

  @override
  String get stats_card_pain_title => 'Average pain';

  @override
  String get stats_card_pain_unit => '/3';

  @override
  String get stats_card_pain_trend_decreasing => 'Trend: decreasing';

  @override
  String get stats_card_pain_trend_increasing => 'Trend: increasing';

  @override
  String get stats_card_pain_trend_stable => 'Trend: stable';

  @override
  String get stats_card_cycles_title => 'Tracked cycles';

  @override
  String get stats_card_cycles_unit => 'total';

  @override
  String get stats_chart_cycle_length_title => 'Cycle length (days)';

  @override
  String get stats_chart_pain_title => 'Pain intensity (0–3)';

  @override
  String get stats_symptom_card_title => 'Most frequent symptoms';

  @override
  String get timeline_view_toggle => 'Timeline';

  @override
  String get table_view_toggle => 'Table';

  @override
  String get settings_import_csv => 'Import CSV';

  @override
  String get csv_export_privacy_warning =>
      'This file contains your health data in plain text. Only share with apps or people you trust.';

  @override
  String get csv_export_privacy_confirm => 'Continue';

  @override
  String csv_import_errors_dialog(int count) {
    return 'Found $count rows with invalid data.';
  }

  @override
  String get csv_import_abort => 'Abort';

  @override
  String get csv_import_skip_continue => 'Skip & Continue';

  @override
  String get csv_import_mode_title => 'Import mode';

  @override
  String get csv_import_mode_delete => 'Delete all data and import';

  @override
  String get csv_import_mode_overwrite => 'Import and overwrite';

  @override
  String get csv_import_mode_keep => 'Import, keep existing';

  @override
  String csv_import_success(int count) {
    return 'Imported $count rows';
  }

  @override
  String csv_import_success_skipped(int count, int skipped) {
    return 'Imported $count rows, skipped $skipped';
  }

  @override
  String get backup_screen_title => 'Backup';

  @override
  String get backup_not_connected_body =>
      'Your data stays on your device. Connect Dropbox to keep an encrypted copy in the cloud — only you can read it.';

  @override
  String get backup_connect_dropbox => 'Connect Dropbox';

  @override
  String backup_connected_as(String email) {
    return 'Connected as: $email';
  }

  @override
  String get backup_last_backup_never => 'Never backed up';

  @override
  String backup_last_backup_at(String datetime) {
    return 'Last backup: $datetime';
  }

  @override
  String get backup_now => 'Back up now';

  @override
  String get backup_restore => 'Restore from backup';

  @override
  String get backup_disconnect => 'Disconnect';

  @override
  String get backup_in_progress => 'Backing up…';

  @override
  String get backup_restore_in_progress => 'Restoring…';

  @override
  String get backup_passphrase_title => 'Set a backup passphrase';

  @override
  String get backup_passphrase_body =>
      'This passphrase encrypts your backup. If you lose it, your backup cannot be recovered — there is no reset.';

  @override
  String get backup_passphrase_input_label => 'Passphrase';

  @override
  String get backup_passphrase_confirm_label => 'Confirm passphrase';

  @override
  String get backup_passphrase_mismatch => 'Passphrases do not match.';

  @override
  String get backup_passphrase_too_short =>
      'Passphrase must be at least 8 characters.';

  @override
  String get backup_passphrase_confirm_button =>
      'I understand — save and back up';

  @override
  String get backup_passphrase_unlock_title => 'Enter passphrase';

  @override
  String get backup_passphrase_unlock_body =>
      'Enter the passphrase used to encrypt the backup. Without the correct passphrase the backup cannot be decrypted.';

  @override
  String get backup_passphrase_unlock_button => 'Unlock and restore';

  @override
  String get backup_restore_confirm_title => 'Restore backup?';

  @override
  String get backup_restore_confirm_body =>
      'This will replace all current data. This cannot be undone.';

  @override
  String get backup_restore_confirm_button => 'Restore';

  @override
  String get backup_error_wrong_passphrase =>
      'Wrong passphrase. Please try again.';

  @override
  String get backup_error_generic => 'Backup failed. Please try again.';

  @override
  String get backup_error_no_backup_found => 'No backup found in your Dropbox.';

  @override
  String get backup_disconnect_confirm_title => 'Disconnect Dropbox?';

  @override
  String get backup_disconnect_confirm_body =>
      'Your cloud backup will not be deleted.';

  @override
  String get backup_disconnect_confirm_button => 'Disconnect';

  @override
  String get onboarding_tagline => 'Your rhythm,\ncherished.';

  @override
  String get onboarding_privacy_line =>
      'Mētra is a quiet journal to know yourself, cycle after cycle.\n\nEverything stays on your phone: no account, no cloud required.';

  @override
  String get onboarding_last_period_question =>
      'First day of your last menstruation';

  @override
  String get onboarding_cycle_length_question =>
      'How long is your cycle usually?';

  @override
  String get onboarding_period_duration_label => 'Flow duration';

  @override
  String get onboarding_get_started => 'Get started';

  @override
  String get onboarding_days_unit => 'days';

  @override
  String onboarding_step_label(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get onboarding_headline => 'Tell me\nabout your cycle.';

  @override
  String get onboarding_subhead =>
      'You can always change this later. No precise answers needed.';

  @override
  String get onboarding_cycle_length_label => 'Average cycle length';

  @override
  String get onboarding_all_set => 'All set →';

  @override
  String get onboarding_date_placeholder => 'Select date';

  @override
  String get settings_section_about => 'About';

  @override
  String get settings_privacy_policy => 'Privacy policy';

  @override
  String get settings_help_label => 'Guide';

  @override
  String get settings_github_label => 'Source code';

  @override
  String get settings_support_label => 'Support the project';

  @override
  String get settings_kofi_label => 'Ko-fi · Support the project';

  @override
  String get daily_entry_flow_chip_assente => 'Absent';

  @override
  String get daily_entry_flow_chip_intensita => 'Intensity';

  @override
  String get daily_entry_flow_chip_spotting => 'Spotting';

  @override
  String get daily_entry_flow_intensity_light => 'Light';

  @override
  String get daily_entry_flow_intensity_medium => 'Moderate';

  @override
  String get daily_entry_flow_intensity_heavy => 'Heavy';

  @override
  String get daily_entry_spotting_note =>
      'Small spotting outside menstrual flow. It is not necessarily the start of a new cycle.';

  @override
  String get daily_entry_assente_confirmation => 'No flow today';

  @override
  String get daily_entry_save_action => 'Save day';

  @override
  String get today_how_are_you => 'How are you today?';

  @override
  String get today_pain_intensity_label => 'Pain intensity';

  @override
  String get today_notes_label => 'Free note';

  @override
  String get today_notes_hint => 'Circumstances, colour, consistency…';

  @override
  String get today_save_day => 'Save day';

  @override
  String get today_add_symptom => 'Add';

  @override
  String get today_flow_lieve => 'Light';

  @override
  String get today_flow_moderato => 'Moderate';

  @override
  String get today_flow_intenso => 'Heavy';

  @override
  String get today_pain_none => 'None';

  @override
  String get nav_oggi => 'Today';

  @override
  String get nav_archivio => 'Archive';

  @override
  String get nav_calendario => 'Calendar';

  @override
  String get nav_statistiche => 'Statistics';

  @override
  String get nav_impostazioni => 'Settings';

  @override
  String get calendar_legend_mestruazioni => 'Menstruation';

  @override
  String get calendar_legend_sintomi => 'Symptoms';

  @override
  String get calendar_legend_dolore => 'Pain';

  @override
  String get calendar_day_detail_no_data => 'No data logged';

  @override
  String get calendar_day_detail_add => 'Add day';

  @override
  String get calendar_day_detail_edit => 'Edit day';

  @override
  String calendar_day_detail_cycle_day(int day) {
    return 'Cycle day $day';
  }

  @override
  String get csvImportConfirmDeleteTitle => 'Destructive import';

  @override
  String get csvImportConfirmDeleteBody =>
      'This action will delete all existing data and replace it with the contents of the imported file. This cannot be undone.';

  @override
  String get csvImportConfirmDeleteAction => 'Delete and import';
}
