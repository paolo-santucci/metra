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
  String get daily_entry_symptom_fatigue => 'Stanchezza';

  @override
  String get daily_entry_symptom_nausea => 'Nausea';

  @override
  String get daily_entry_symptom_breastTenderness => 'Tensione mammaria';

  @override
  String get daily_entry_symptom_custom_placeholder => 'Nome del sintomo…';

  @override
  String get daily_entry_notes_label => 'Note';

  @override
  String get daily_entry_notes_placeholder =>
      'Circostanze, colore, consistenza…';

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
  String get notification_prediction_title => 'Il tuo ciclo si avvicina';

  @override
  String notification_prediction_body(int days) {
    return 'La finestra stimata inizia tra $days giorni';
  }

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
  String get settings_backup_configured => 'Configurato';

  @override
  String get settings_export_csv => 'Esporta CSV';

  @override
  String get settings_delete_all => 'Elimina tutti i dati';

  @override
  String get settings_screen_title => 'Impostazioni';

  @override
  String get settings_section_preferences => 'Preferenze';

  @override
  String get settings_section_log => 'Registro';

  @override
  String get settings_section_notifications => 'Notifiche';

  @override
  String get settings_section_privacy => 'Dati';

  @override
  String get settings_section_danger => 'Azioni irreversibili';

  @override
  String get settings_pain_label => 'Dolore';

  @override
  String get settings_notes_label => 'Note giornaliere';

  @override
  String get settings_advance_label => 'Preavviso';

  @override
  String settings_advance_value(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n giorni prima',
      one: '1 giorno prima',
    );
    return '$_temp0';
  }

  @override
  String get settings_language_system => 'Automatica';

  @override
  String get settings_language_it => 'Italiano';

  @override
  String get settings_language_en => 'Inglese';

  @override
  String get settings_delete_all_confirm_title => 'Elimina tutti i dati';

  @override
  String get settings_delete_all_confirm_body =>
      'Questa operazione è irreversibile. Tutto il registro sarà eliminato. Le impostazioni resteranno invariate.';

  @override
  String get settings_coming_soon => 'Prossimamente';

  @override
  String get settings_delete_all_done => 'Dati eliminati';

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
  String get archive_title => 'Archivio';

  @override
  String archive_card_duration_days(int n) {
    return 'Durata ${n}g';
  }

  @override
  String archive_card_footer(int len, String day) {
    return 'Ciclo ${len}g · dal $day';
  }

  @override
  String get table_col_month => 'Mese';

  @override
  String get table_col_duration => 'Dur.';

  @override
  String get table_col_flow => 'Flusso';

  @override
  String get table_col_cycle => 'Ciclo';

  @override
  String get table_cycle_dash => '—';

  @override
  String get stats_insufficient_data => 'Dati insufficienti';

  @override
  String get stats_title => 'Statistiche';

  @override
  String get stats_subtitle => 'Ultimi 6 cicli';

  @override
  String get stats_card_cycle_length_title => 'Durata media ciclo';

  @override
  String get stats_card_cycle_length_unit => 'giorni';

  @override
  String stats_card_cycle_length_sub(int min, int max) {
    return 'Range: $min–${max}g';
  }

  @override
  String get stats_card_period_length_title => 'Durata media flusso';

  @override
  String get stats_card_period_length_unit => 'giorni';

  @override
  String stats_card_period_length_sub(int min, int max) {
    return 'Range: $min–${max}g';
  }

  @override
  String get stats_card_pain_title => 'Dolore medio';

  @override
  String get stats_card_pain_unit => '/3';

  @override
  String get stats_card_pain_trend_decreasing => 'Trend in calo';

  @override
  String get stats_card_pain_trend_increasing => 'Trend in aumento';

  @override
  String get stats_card_pain_trend_stable => 'Trend stabile';

  @override
  String get stats_card_cycles_title => 'Cicli tracciati';

  @override
  String get stats_card_cycles_unit => 'totali';

  @override
  String get stats_chart_cycle_length_title => 'Durata ciclo (giorni)';

  @override
  String get stats_chart_pain_title => 'Intensità dolore (0–3)';

  @override
  String get stats_symptom_card_title => 'Sintomi più frequenti';

  @override
  String get timeline_view_toggle => 'Timeline';

  @override
  String get table_view_toggle => 'Tabella';

  @override
  String get settings_import_csv => 'Importa CSV';

  @override
  String get csv_export_privacy_warning =>
      'Questo file contiene dati sanitari in chiaro. Condividilo solo con app o persone di cui ti fidi.';

  @override
  String get csv_export_privacy_confirm => 'Continua';

  @override
  String csv_import_errors_dialog(int count) {
    return 'Trovate $count righe con dati non validi.';
  }

  @override
  String get csv_import_abort => 'Annulla importazione';

  @override
  String get csv_import_skip_continue => 'Salta e continua';

  @override
  String get csv_import_mode_title => 'Modalità importazione';

  @override
  String get csv_import_mode_delete => 'Elimina tutto e importa';

  @override
  String get csv_import_mode_overwrite => 'Importa e sovrascrivi';

  @override
  String get csv_import_mode_keep => 'Importa, mantieni esistenti';

  @override
  String csv_import_success(int count) {
    return 'Importate $count righe';
  }

  @override
  String csv_import_success_skipped(int count, int skipped) {
    return 'Importate $count righe, saltate $skipped';
  }

  @override
  String get backup_screen_title => 'Backup';

  @override
  String get backup_not_connected_body =>
      'I tuoi dati restano sul dispositivo. Collega Dropbox per conservare una copia cifrata nel cloud — solo tu puoi leggerla.';

  @override
  String get backup_connect_dropbox => 'Collega Dropbox';

  @override
  String backup_connected_as(String email) {
    return 'Connesso come: $email';
  }

  @override
  String get backup_last_backup_never => 'Mai salvato';

  @override
  String backup_last_backup_at(String datetime) {
    return 'Ultimo backup: $datetime';
  }

  @override
  String get backup_now => 'Salva ora';

  @override
  String get backup_restore => 'Ripristina dal backup';

  @override
  String get backup_disconnect => 'Disconnetti';

  @override
  String get backup_in_progress => 'Salvataggio in corso…';

  @override
  String get backup_restore_in_progress => 'Ripristino in corso…';

  @override
  String get backup_passphrase_title => 'Imposta una passphrase';

  @override
  String get backup_passphrase_body =>
      'Questa passphrase cifra il tuo backup. Se la perdi, il backup non può essere recuperato — non esiste un reset.';

  @override
  String get backup_passphrase_input_label => 'Passphrase';

  @override
  String get backup_passphrase_confirm_label => 'Conferma passphrase';

  @override
  String get backup_passphrase_mismatch => 'Le passphrase non corrispondono.';

  @override
  String get backup_passphrase_too_short =>
      'La passphrase deve essere di almeno 8 caratteri.';

  @override
  String get backup_passphrase_confirm_button =>
      'Ho capito — salva e fai il backup';

  @override
  String get backup_passphrase_unlock_title => 'Inserisci la passphrase';

  @override
  String get backup_passphrase_unlock_body =>
      'Inserisci la passphrase usata per cifrare il backup. Senza la passphrase corretta il backup non può essere decifrato.';

  @override
  String get backup_passphrase_unlock_button => 'Sblocca e ripristina';

  @override
  String get backup_restore_confirm_title => 'Ripristinare il backup?';

  @override
  String get backup_restore_confirm_body =>
      'Tutti i dati attuali verranno sostituiti. Questa operazione non può essere annullata.';

  @override
  String get backup_restore_confirm_button => 'Ripristina';

  @override
  String get backup_error_wrong_passphrase => 'Passphrase errata. Riprova.';

  @override
  String get backup_error_generic => 'Backup fallito. Riprova.';

  @override
  String get backup_error_no_backup_found =>
      'Nessun backup trovato su Dropbox.';

  @override
  String get backup_disconnect_confirm_title => 'Disconnettere Dropbox?';

  @override
  String get backup_disconnect_confirm_body =>
      'Il backup nel cloud non verrà eliminato.';

  @override
  String get backup_disconnect_confirm_button => 'Disconnetti';

  @override
  String get onboarding_tagline => 'Il tuo ritmo,\ncustodito.';

  @override
  String get onboarding_privacy_line =>
      'Mētra è un quaderno silenzioso per conoscerti, ciclo dopo ciclo.\n\nTutto rimane sul tuo telefono: nessun account, nessun cloud richiesto.';

  @override
  String get onboarding_last_period_question =>
      'Primo giorno dell\'ultima mestruazione';

  @override
  String get onboarding_cycle_length_question =>
      'Quanto dura di solito il tuo ciclo?';

  @override
  String get onboarding_period_duration_label => 'Durata mestruazioni';

  @override
  String get onboarding_get_started => 'Inizia';

  @override
  String get onboarding_days_unit => 'giorni';

  @override
  String onboarding_step_label(int current, int total) {
    return 'Passo $current di $total';
  }

  @override
  String get onboarding_headline => 'Raccontami\nil tuo ciclo.';

  @override
  String get onboarding_subhead =>
      'Puoi sempre modificarlo dopo. Non servono risposte precise.';

  @override
  String get onboarding_cycle_length_label => 'Durata media ciclo';

  @override
  String get onboarding_all_set => 'Tutto pronto →';

  @override
  String get onboarding_date_placeholder => 'Seleziona data';

  @override
  String get settings_section_about => 'Informazioni';

  @override
  String get settings_privacy_policy => 'Informativa sulla privacy';

  @override
  String get settings_help_label => 'Guida';

  @override
  String get settings_github_label => 'Codice sorgente';

  @override
  String get settings_support_label => 'Sostieni il progetto';

  @override
  String get settings_kofi_label => 'Ko-fi · Sostieni il progetto';

  @override
  String get daily_entry_flow_chip_assente => 'Assente';

  @override
  String get daily_entry_flow_chip_intensita => 'Intensità';

  @override
  String get daily_entry_flow_chip_spotting => 'Spotting';

  @override
  String get daily_entry_flow_intensity_light => 'Leggero';

  @override
  String get daily_entry_flow_intensity_medium => 'Moderato';

  @override
  String get daily_entry_flow_intensity_heavy => 'Abbondante';

  @override
  String get daily_entry_spotting_note =>
      'Piccola perdita fuori dal flusso mestruale. Non è necessariamente l\'inizio del ciclo.';

  @override
  String get daily_entry_assente_confirmation => 'Nessun flusso oggi';

  @override
  String get daily_entry_save_action => 'Salva giornata';

  @override
  String get today_how_are_you => 'Come stai oggi?';

  @override
  String get today_pain_intensity_label => 'Intensità dolore';

  @override
  String get today_notes_label => 'Nota libera';

  @override
  String get today_notes_hint => 'Scrivi qualcosa…';

  @override
  String get today_save_day => 'Salva giornata';

  @override
  String get today_add_symptom => 'Aggiungi';

  @override
  String get today_flow_lieve => 'Lieve';

  @override
  String get today_flow_moderato => 'Moderato';

  @override
  String get today_flow_intenso => 'Intenso';

  @override
  String get today_pain_none => 'Nessuno';

  @override
  String get nav_oggi => 'Oggi';

  @override
  String get nav_archivio => 'Archivio';

  @override
  String get calendar_legend_mestruazioni => 'Mestruazioni';

  @override
  String get calendar_legend_sintomi => 'Sintomi';

  @override
  String get calendar_legend_dolore => 'Dolore';

  @override
  String get calendar_day_detail_no_data => 'Nessun dato registrato';

  @override
  String get calendar_day_detail_add => 'Aggiungi giornata';

  @override
  String get calendar_day_detail_edit => 'Modifica giornata';

  @override
  String calendar_day_detail_cycle_day(int day) {
    return 'Giorno $day del ciclo';
  }
}
