// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get common_appName => 'Mētra';

  @override
  String get common_loading => 'Caricamento…';

  @override
  String get common_save => 'Salva';

  @override
  String get common_cancel => 'Annulla';

  @override
  String get common_delete => 'Elimina';

  @override
  String get common_ok => 'OK';

  @override
  String get common_error_generic => 'Qualcosa è andato storto. Riprova.';

  @override
  String get daily_entry_title => 'Registro giornaliero';

  @override
  String get daily_entry_flow_label => 'Flusso';

  @override
  String get daily_entry_flow_none => 'Nessun flusso';

  @override
  String get daily_entry_flow_spotting => 'Spotting';

  @override
  String get daily_entry_flow_light => 'Flusso leggero';

  @override
  String get daily_entry_flow_medium => 'Flusso moderato';

  @override
  String get daily_entry_flow_heavy => 'Flusso intenso';

  @override
  String get daily_entry_flow_veryHeavy => 'Flusso molto intenso';

  @override
  String get daily_entry_pain_label => 'Dolore';

  @override
  String get daily_entry_pain_none => 'Nessun dolore';

  @override
  String get daily_entry_pain_mild => 'Lieve';

  @override
  String get daily_entry_pain_moderate => 'Moderato';

  @override
  String get daily_entry_pain_severe => 'Intenso';

  @override
  String get daily_entry_symptoms_label => 'Sintomi';

  @override
  String get daily_entry_symptom_cramps => 'Crampi';

  @override
  String get daily_entry_symptom_backPain => 'Mal di schiena';

  @override
  String get daily_entry_symptom_headache => 'Mal di testa';

  @override
  String get daily_entry_symptom_migraine => 'Emicrania';

  @override
  String get daily_entry_symptom_bloating => 'Gonfiore';

  @override
  String get daily_entry_symptom_custom => 'Personalizzato';

  @override
  String get daily_entry_symptom_custom_placeholder => 'Nome del sintomo…';

  @override
  String get daily_entry_notes_label => 'Note';

  @override
  String get daily_entry_notes_placeholder => 'Aggiungi una nota…';

  @override
  String get daily_entry_save => 'Salva';

  @override
  String get daily_entry_cancel => 'Annulla';

  @override
  String get daily_entry_delete_confirmation_title => 'Elimina registro';

  @override
  String get daily_entry_delete_confirmation_body =>
      'Eliminare i dati di questo giorno? Questa azione non può essere annullata.';

  @override
  String calendar_month_title(String month, String year) {
    return '$month $year';
  }

  @override
  String get calendar_prev_month => 'Mese precedente';

  @override
  String get calendar_next_month => 'Mese successivo';

  @override
  String get calendar_today => 'Oggi';

  @override
  String get calendar_empty_state =>
      'Nessun dato registrato per questo mese.\nTocca un giorno per iniziare.';

  @override
  String get calendar_legend_flow => 'Flusso';

  @override
  String get calendar_legend_spotting => 'Spotting';

  @override
  String get calendar_legend_prediction => 'Previsione';

  @override
  String get calendar_legend_notes => 'Note';

  @override
  String get calendar_prediction_label => 'Prossimo ritmo previsto:';

  @override
  String get calendar_fab_label => 'Aggiungi o modifica il registro di oggi';

  @override
  String get settings_language_label => 'Lingua';

  @override
  String get settings_theme_label => 'Tema';

  @override
  String get settings_theme_system => 'Sistema';

  @override
  String get settings_theme_light => 'Chiaro';

  @override
  String get settings_theme_dark => 'Scuro';

  @override
  String get settings_notifications_label => 'Promemoria ciclo';

  @override
  String get settings_notifications_on => 'Attive';

  @override
  String get settings_notifications_off => 'Disattivate';

  @override
  String get settings_backup_label => 'Backup cloud';

  @override
  String get settings_backup_not_configured => 'Non configurato';

  @override
  String get settings_export_csv => 'Esporta CSV';

  @override
  String get settings_delete_all => 'Cancella tutti i dati';

  @override
  String a11y_calendar_day_no_flow(String date) {
    return 'Nessun dato, $date';
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
    return '$date, con nota';
  }

  @override
  String a11y_calendar_day_prediction(String date) {
    return 'Ciclo previsto, $date';
  }

  @override
  String a11y_calendar_day_today(String date) {
    return 'Oggi, $date';
  }

  @override
  String get timeline_empty_hint =>
      'Registra il tuo primo ciclo per vedere la timeline';

  @override
  String get timeline_cycle_in_progress => 'In corso';

  @override
  String timeline_cycle_length_days(int n) {
    return '$n g';
  }

  @override
  String timeline_card_a11y(String start, String end, int n) {
    return 'Ciclo dal $start al $end, $n giorni';
  }

  @override
  String timeline_card_a11y_in_progress(String start) {
    return 'Ciclo dal $start, in corso';
  }

  @override
  String get table_col_start => 'Inizio';

  @override
  String get table_col_cycle => 'Ciclo';

  @override
  String get table_col_period => 'Mestr.';

  @override
  String get table_col_symptoms => 'Sintomi';

  @override
  String get table_cycle_dash => '—';

  @override
  String get stats_cycle_length_title => 'Lunghezza ciclo';

  @override
  String get stats_period_length_title => 'Durata mestruazione';

  @override
  String get stats_symptoms_title => 'Sintomi frequenti';

  @override
  String get stats_flow_title => 'Intensità flusso';

  @override
  String get stats_insufficient_data => 'Dati insufficienti';

  @override
  String stats_cycle_length_avg(int n) {
    return '$n g in media';
  }

  @override
  String stats_period_length_avg(int n) {
    return '$n g in media';
  }

  @override
  String stats_n_days(int n) {
    return '$n giorni';
  }

  @override
  String get timeline_view_toggle => 'Timeline';

  @override
  String get table_view_toggle => 'Tabella';
}
