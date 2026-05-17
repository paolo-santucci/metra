// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
//
// Métra is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License,
// or (at your option) any later version.
//
// Métra is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Métra. If not, see <https://www.gnu.org/licenses/>.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:metra/core/util/nullable.dart';
import 'package:metra/domain/entities/app_settings_data.dart';
import 'package:metra/domain/entities/first_day_of_week_setting.dart';

String readAppSettingsDataSource() =>
    File('lib/domain/entities/app_settings_data.dart').readAsStringSync();

void main() {
  AppSettingsData makeSettings({
    String languageCode = 'it',
    bool? darkMode,
    bool painEnabled = true,
    bool notesEnabled = true,
    int notificationDaysBefore = 2,
    bool notificationsEnabled = false,
    String? dropboxEmail,
    DateTime? lastBackupAt,
    bool onboardingCompleted = false,
    int? declaredCycleLength,
    int notificationTimeMinutes = 540,
    FirstDayOfWeekSetting firstDayOfWeek = FirstDayOfWeekSetting.system,
    DateTime? lastLogOrSymptomWriteAt,
    bool backupSuspended = false,
  }) =>
      AppSettingsData(
        languageCode: languageCode,
        darkMode: darkMode,
        painEnabled: painEnabled,
        notesEnabled: notesEnabled,
        notificationDaysBefore: notificationDaysBefore,
        notificationsEnabled: notificationsEnabled,
        dropboxEmail: dropboxEmail,
        lastBackupAt: lastBackupAt,
        onboardingCompleted: onboardingCompleted,
        declaredCycleLength: declaredCycleLength,
        notificationTimeMinutes: notificationTimeMinutes,
        firstDayOfWeek: firstDayOfWeek,
        lastLogOrSymptomWriteAt: lastLogOrSymptomWriteAt,
        backupSuspended: backupSuspended,
      );

  group('AppSettingsData construction', () {
    test('stores all required fields and null optional fields by default', () {
      final settings = makeSettings();

      expect(settings.languageCode, 'it');
      expect(settings.darkMode, isNull);
      expect(settings.painEnabled, isTrue);
      expect(settings.notesEnabled, isTrue);
      expect(settings.notificationDaysBefore, 2);
      expect(settings.notificationsEnabled, isFalse);
      expect(settings.dropboxEmail, isNull);
      expect(settings.lastBackupAt, isNull);
      expect(settings.onboardingCompleted, isFalse);
      expect(settings.declaredCycleLength, isNull);
    });

    test('stores optional fields when provided', () {
      final backup = DateTime.utc(2026, 5, 1);
      final settings = makeSettings(
        darkMode: true,
        dropboxEmail: 'user@example.com',
        lastBackupAt: backup,
        onboardingCompleted: true,
        declaredCycleLength: 28,
      );

      expect(settings.darkMode, isTrue);
      expect(settings.dropboxEmail, 'user@example.com');
      expect(settings.lastBackupAt, backup);
      expect(settings.onboardingCompleted, isTrue);
      expect(settings.declaredCycleLength, 28);
    });

    test('darkMode can be explicitly set to false (not system)', () {
      final settings = makeSettings(darkMode: false);

      expect(settings.darkMode, isFalse);
    });
  });

  group('AppSettingsData.defaults factory', () {
    test('creates instance with expected default values', () {
      final defaults = AppSettingsData.defaults();

      expect(defaults.languageCode, '');
      expect(defaults.darkMode, isNull);
      expect(defaults.painEnabled, isTrue);
      expect(defaults.notesEnabled, isTrue);
      expect(defaults.notificationDaysBefore, 2);
      expect(defaults.notificationsEnabled, isFalse);
      expect(defaults.dropboxEmail, isNull);
      expect(defaults.lastBackupAt, isNull);
      expect(defaults.onboardingCompleted, isFalse);
      expect(defaults.declaredCycleLength, isNull);
    });
  });

  group('AppSettingsData equality', () {
    test('identical instance equals itself', () {
      final settings = makeSettings();
      expect(settings == settings, isTrue);
    });

    test('two instances with same field values are equal', () {
      final a = makeSettings(dropboxEmail: 'a@b.com', declaredCycleLength: 30);
      final b = makeSettings(dropboxEmail: 'a@b.com', declaredCycleLength: 30);

      expect(a, equals(b));
    });

    test('instances with different languageCode are not equal', () {
      final a = makeSettings(languageCode: 'it');
      final b = makeSettings(languageCode: 'en');

      expect(a, isNot(equals(b)));
    });

    test('instances with different darkMode are not equal', () {
      final a = makeSettings(darkMode: true);
      final b = makeSettings(darkMode: false);

      expect(a, isNot(equals(b)));
    });

    test('instances with different painEnabled are not equal', () {
      final a = makeSettings(painEnabled: true);
      final b = makeSettings(painEnabled: false);

      expect(a, isNot(equals(b)));
    });

    test('instances with different notesEnabled are not equal', () {
      final a = makeSettings(notesEnabled: true);
      final b = makeSettings(notesEnabled: false);

      expect(a, isNot(equals(b)));
    });

    test('instances with different notificationDaysBefore are not equal', () {
      final a = makeSettings(notificationDaysBefore: 1);
      final b = makeSettings(notificationDaysBefore: 3);

      expect(a, isNot(equals(b)));
    });

    test('instances with different notificationsEnabled are not equal', () {
      final a = makeSettings(notificationsEnabled: false);
      final b = makeSettings(notificationsEnabled: true);

      expect(a, isNot(equals(b)));
    });

    test('instances with different dropboxEmail are not equal', () {
      final a = makeSettings(dropboxEmail: 'a@example.com');
      final b = makeSettings(dropboxEmail: 'b@example.com');

      expect(a, isNot(equals(b)));
    });

    test('instances with different lastBackupAt are not equal', () {
      final a = makeSettings(lastBackupAt: DateTime.utc(2026, 5, 1));
      final b = makeSettings(lastBackupAt: DateTime.utc(2026, 5, 2));

      expect(a, isNot(equals(b)));
    });

    test('instances with different onboardingCompleted are not equal', () {
      final a = makeSettings(onboardingCompleted: false);
      final b = makeSettings(onboardingCompleted: true);

      expect(a, isNot(equals(b)));
    });

    test('instances with different declaredCycleLength are not equal', () {
      final a = makeSettings(declaredCycleLength: 28);
      final b = makeSettings(declaredCycleLength: 30);

      expect(a, isNot(equals(b)));
    });

    test('instance does not equal object of different type', () {
      final settings = makeSettings();

      // ignore: unrelated_type_equality_checks
      expect(settings == 'not settings', isFalse);
    });
  });

  group('AppSettingsData hashCode', () {
    test('equal objects have the same hashCode', () {
      final a = makeSettings(dropboxEmail: 'x@y.com', declaredCycleLength: 28);
      final b = makeSettings(dropboxEmail: 'x@y.com', declaredCycleLength: 28);

      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('AppSettingsData notificationTimeMinutes', () {
    test(
        'given_no_argument_when_constructed_then_notificationTimeMinutes_is_540',
        () {
      expect(AppSettingsData.defaults().notificationTimeMinutes, 540);
    });

    test(
        'given_notificationTimeMinutes_750_darkMode_true_when_copyWith_1080_then_propagates_and_preserves',
        () {
      final a = AppSettingsData(
        languageCode: 'it',
        painEnabled: true,
        notesEnabled: true,
        notificationDaysBefore: 2,
        notificationsEnabled: false,
        onboardingCompleted: false,
        notificationTimeMinutes: 750,
        darkMode: true,
      );
      final b = a.copyWith(notificationTimeMinutes: 1080);
      expect(b.notificationTimeMinutes, 1080);
      expect(b.darkMode, true);
    });

    test(
        'given_notificationTimeMinutes_750_when_copyWith_unrelated_field_then_preserves_notificationTimeMinutes',
        () {
      final a = AppSettingsData(
        languageCode: 'it',
        painEnabled: true,
        notesEnabled: true,
        notificationDaysBefore: 2,
        notificationsEnabled: false,
        onboardingCompleted: false,
        notificationTimeMinutes: 750,
      );
      expect(
        a.copyWith(darkMode: const Nullable(true)).notificationTimeMinutes,
        750,
      );
    });

    test(
        'given_same_notificationTimeMinutes_when_equality_check_then_equal_and_hashCode_matches',
        () {
      final a = AppSettingsData(
        languageCode: 'it',
        painEnabled: true,
        notesEnabled: true,
        notificationDaysBefore: 2,
        notificationsEnabled: false,
        onboardingCompleted: false,
        notificationTimeMinutes: 1,
      );
      final b = AppSettingsData(
        languageCode: 'it',
        painEnabled: true,
        notesEnabled: true,
        notificationDaysBefore: 2,
        notificationsEnabled: false,
        onboardingCompleted: false,
        notificationTimeMinutes: 1,
      );
      final c = AppSettingsData(
        languageCode: 'it',
        painEnabled: true,
        notesEnabled: true,
        notificationDaysBefore: 2,
        notificationsEnabled: false,
        onboardingCompleted: false,
        notificationTimeMinutes: 2,
      );
      expect(a == b, true);
      expect(a == c, false);
    });
  });

  group('AppSettingsData notificationTimeMinutes — constructor defaults', () {
    test(
        'given_no_notificationTimeMinutes_arg_when_constructed_then_defaults_to_540',
        () {
      final settings = AppSettingsData(
        languageCode: 'it',
        painEnabled: true,
        notesEnabled: true,
        notificationDaysBefore: 2,
        notificationsEnabled: false,
        onboardingCompleted: false,
      );
      expect(settings.notificationTimeMinutes, 540);
    });

    test('given_notificationTimeMinutes_720_when_constructed_then_returns_720',
        () {
      final settings = AppSettingsData(
        languageCode: 'it',
        painEnabled: true,
        notesEnabled: true,
        notificationDaysBefore: 2,
        notificationsEnabled: false,
        onboardingCompleted: false,
        notificationTimeMinutes: 720,
      );
      expect(settings.notificationTimeMinutes, 720);
    });
  });

  group('AppSettingsData notificationTimeMinutes — hashCode', () {
    test(
        'given_same_fields_except_notificationTimeMinutes_when_hashCode_compared_then_differs',
        () {
      final a = AppSettingsData(
        languageCode: 'it',
        painEnabled: true,
        notesEnabled: true,
        notificationDaysBefore: 2,
        notificationsEnabled: false,
        onboardingCompleted: false,
        notificationTimeMinutes: 540,
      );
      final b = AppSettingsData(
        languageCode: 'it',
        painEnabled: true,
        notesEnabled: true,
        notificationDaysBefore: 2,
        notificationsEnabled: false,
        onboardingCompleted: false,
        notificationTimeMinutes: 720,
      );
      expect(a.hashCode, isNot(equals(b.hashCode)));
    });
  });

  group('AppSettingsData purity (NFR-08)', () {
    test(
        'given_entity_source_file_when_grepped_then_no_flutter_or_TimeOfDay_import',
        () {
      // Verify the domain entity contains no Flutter framework imports —
      // the domain layer must remain pure Dart.
      final source = readAppSettingsDataSource();
      expect(
        source.contains('package:flutter'),
        isFalse,
        reason: 'domain entity must not import package:flutter',
      );
      expect(
        source.contains('TimeOfDay'),
        isFalse,
        reason: 'domain entity must not reference Flutter TimeOfDay',
      );
    });
  });

  group('AppSettingsData firstDayOfWeek', () {
    test('default is system', () {
      final defaults = AppSettingsData.defaults();
      expect(defaults.firstDayOfWeek, FirstDayOfWeekSetting.system);
    });

    test('copyWith updates firstDayOfWeek', () {
      final settings = makeSettings();
      final copy = settings.copyWith(
        firstDayOfWeek: FirstDayOfWeekSetting.sunday,
      );
      expect(copy.firstDayOfWeek, FirstDayOfWeekSetting.sunday);
    });

    test('copyWith preserves other fields when updating firstDayOfWeek', () {
      final settings = makeSettings(languageCode: 'it');
      final copy = settings.copyWith(
        firstDayOfWeek: FirstDayOfWeekSetting.monday,
      );
      expect(copy.languageCode, 'it');
    });

    test('copyWith without firstDayOfWeek preserves existing value', () {
      final settings = makeSettings(
        firstDayOfWeek: FirstDayOfWeekSetting.sunday,
      );
      final copy = settings.copyWith(languageCode: 'en');
      expect(copy.firstDayOfWeek, FirstDayOfWeekSetting.sunday);
    });

    test('equality — same firstDayOfWeek are equal', () {
      final a = makeSettings(firstDayOfWeek: FirstDayOfWeekSetting.sunday);
      final b = makeSettings(firstDayOfWeek: FirstDayOfWeekSetting.sunday);
      expect(a, equals(b));
    });

    test('equality — different firstDayOfWeek are not equal', () {
      final a = makeSettings(firstDayOfWeek: FirstDayOfWeekSetting.system);
      final b = makeSettings(firstDayOfWeek: FirstDayOfWeekSetting.monday);
      expect(a, isNot(equals(b)));
    });

    test('hashCode — same firstDayOfWeek produces same hashCode', () {
      final a = makeSettings(firstDayOfWeek: FirstDayOfWeekSetting.monday);
      final b = makeSettings(firstDayOfWeek: FirstDayOfWeekSetting.monday);
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('AppSettingsData lastLogOrSymptomWriteAt', () {
    test(
        'given_no_argument_when_constructed_then_lastLogOrSymptomWriteAt_is_null',
        () {
      final s = AppSettingsData(
        languageCode: 'it',
        painEnabled: true,
        notesEnabled: true,
        notificationDaysBefore: 2,
        notificationsEnabled: false,
        onboardingCompleted: false,
      );
      expect(s.lastLogOrSymptomWriteAt, isNull);
    });

    test(
        'given_same_lastLogOrSymptomWriteAt_when_equality_check_then_equal_and_hashCode_matches',
        () {
      final t = DateTime.utc(2026, 5, 14, 10);
      final a = makeSettings(lastLogOrSymptomWriteAt: t);
      final b = makeSettings(lastLogOrSymptomWriteAt: t);
      final c = makeSettings(lastLogOrSymptomWriteAt: null);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.hashCode, equals(b.hashCode));
    });

    test(
        'given_lastLogOrSymptomWriteAt_set_when_copyWith_unrelated_field_then_field_preserved',
        () {
      final t = DateTime.utc(2026, 5, 14, 10);
      final s = makeSettings(lastLogOrSymptomWriteAt: t);
      final after = s.copyWith(languageCode: 'en');
      expect(after.lastLogOrSymptomWriteAt, equals(t));
    });
  });

  group('AppSettingsData copyWith', () {
    test('returns equal object when no arguments supplied', () {
      final settings = makeSettings(dropboxEmail: 'a@b.com');
      final copy = settings.copyWith();

      expect(copy, equals(settings));
    });

    test('updates languageCode', () {
      final settings = makeSettings(languageCode: 'it');
      final copy = settings.copyWith(languageCode: 'en');

      expect(copy.languageCode, 'en');
    });

    test('updates darkMode', () {
      final settings = makeSettings(darkMode: null);
      final copy = settings.copyWith(darkMode: const Nullable(true));

      expect(copy.darkMode, isTrue);
    });

    test('updates painEnabled', () {
      final settings = makeSettings(painEnabled: true);
      final copy = settings.copyWith(painEnabled: false);

      expect(copy.painEnabled, isFalse);
    });

    test('updates notesEnabled', () {
      final settings = makeSettings(notesEnabled: true);
      final copy = settings.copyWith(notesEnabled: false);

      expect(copy.notesEnabled, isFalse);
    });

    test('updates notificationDaysBefore', () {
      final settings = makeSettings(notificationDaysBefore: 2);
      final copy = settings.copyWith(notificationDaysBefore: 5);

      expect(copy.notificationDaysBefore, 5);
    });

    test('updates notificationsEnabled', () {
      final settings = makeSettings(notificationsEnabled: false);
      final copy = settings.copyWith(notificationsEnabled: true);

      expect(copy.notificationsEnabled, isTrue);
    });

    test('updates dropboxEmail', () {
      final settings = makeSettings();
      final copy =
          settings.copyWith(dropboxEmail: const Nullable('new@example.com'));

      expect(copy.dropboxEmail, 'new@example.com');
    });

    test('updates lastBackupAt', () {
      final settings = makeSettings();
      final newDate = DateTime.utc(2026, 5, 4);
      final copy = settings.copyWith(lastBackupAt: Nullable(newDate));

      expect(copy.lastBackupAt, newDate);
    });

    test('updates onboardingCompleted', () {
      final settings = makeSettings(onboardingCompleted: false);
      final copy = settings.copyWith(onboardingCompleted: true);

      expect(copy.onboardingCompleted, isTrue);
    });

    test('copyWith preserves declaredCycleLength even when other fields change',
        () {
      final settings = makeSettings(
        declaredCycleLength: 28,
        languageCode: 'it',
      );
      final copy = settings.copyWith(languageCode: 'en');

      // declaredCycleLength is intentionally not a copyWith parameter
      expect(copy.declaredCycleLength, 28);
    });

    test('copyWith preserves null declaredCycleLength when other fields change',
        () {
      final settings = makeSettings(languageCode: 'it');
      final copy = settings.copyWith(languageCode: 'en');

      expect(copy.declaredCycleLength, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // New tests — Wave 2 / TASK-03
  // ---------------------------------------------------------------------------

  group('Nullable<T> copyWith semantics — FR-01', () {
    test(
        'given_darkMode_true_when_copyWith_Nullable_null_then_darkMode_is_null',
        () {
      final base = makeSettings(
        darkMode: true,
        dropboxEmail: 'a@b.com',
        lastBackupAt: DateTime.utc(2026, 1, 1),
        backupSuspended: true,
        lastLogOrSymptomWriteAt: DateTime.utc(2026, 1, 2),
        declaredCycleLength: 28,
      );
      final out = base.copyWith(darkMode: const Nullable(null));
      expect(out.darkMode, isNull);
      // All other fields must be unchanged.
      expect(out.notificationDaysBefore, base.notificationDaysBefore);
      expect(out.notificationTimeMinutes, base.notificationTimeMinutes);
      expect(out.languageCode, base.languageCode);
      expect(out.dropboxEmail, base.dropboxEmail);
      expect(out.lastBackupAt, base.lastBackupAt);
      expect(out.painEnabled, base.painEnabled);
      expect(out.notesEnabled, base.notesEnabled);
      expect(out.notificationsEnabled, base.notificationsEnabled);
      expect(out.onboardingCompleted, base.onboardingCompleted);
      expect(out.firstDayOfWeek, base.firstDayOfWeek);
      expect(out.declaredCycleLength, base.declaredCycleLength);
      expect(out.lastLogOrSymptomWriteAt, base.lastLogOrSymptomWriteAt);
      expect(out.backupSuspended, base.backupSuspended);
    });

    test(
        'given_darkMode_true_when_copyWith_Nullable_false_then_darkMode_is_false',
        () {
      final base = makeSettings(darkMode: true);
      final out = base.copyWith(darkMode: const Nullable(false));
      expect(out.darkMode, isFalse);
    });

    test(
        'given_dropboxEmail_set_when_copyWith_Nullable_null_then_email_is_null',
        () {
      final base = makeSettings(dropboxEmail: 'user@example.com');
      final out = base.copyWith(dropboxEmail: const Nullable(null));
      expect(out.dropboxEmail, isNull);
    });

    test(
        'given_dropboxEmail_null_when_copyWith_Nullable_new_email_then_email_set',
        () {
      final base = makeSettings();
      final out = base.copyWith(
        dropboxEmail: const Nullable('new@example.com'),
      );
      expect(out.dropboxEmail, 'new@example.com');
    });

    test(
        'given_lastBackupAt_set_when_copyWith_Nullable_null_then_timestamp_cleared',
        () {
      final base = makeSettings(lastBackupAt: DateTime.utc(2026, 5, 1));
      final out = base.copyWith(lastBackupAt: const Nullable(null));
      expect(out.lastBackupAt, isNull);
    });

    test(
        'given_lastBackupAt_null_when_copyWith_Nullable_date_then_timestamp_set',
        () {
      final newDate = DateTime.utc(2026, 1, 1);
      final base = makeSettings();
      final out = base.copyWith(lastBackupAt: Nullable(newDate));
      expect(out.lastBackupAt, newDate);
    });

    test(
        'given_all_params_omitted_when_copyWith_then_backupSuspended_lastLogOrSymptomWriteAt_declaredCycleLength_preserved',
        () {
      final someDate = DateTime.utc(2026, 3, 15);
      final base = makeSettings(
        backupSuspended: true,
        lastLogOrSymptomWriteAt: someDate,
        declaredCycleLength: 28,
      );
      final out = base.copyWith();
      expect(out.backupSuspended, isTrue);
      expect(out.lastLogOrSymptomWriteAt, someDate);
      expect(out.declaredCycleLength, 28);
    });

    test(
        'given_backupSuspended_true_when_copyWith_darkMode_Nullable_null_then_backupSuspended_unchanged',
        () {
      final base = makeSettings(backupSuspended: true, darkMode: true);
      final out = base.copyWith(darkMode: const Nullable(null));
      expect(out.backupSuspended, isTrue);
      expect(out.darkMode, isNull);
    });
  });

  group('Constructor-time range validation — FR-02', () {
    test(
        'given_notificationDaysBefore_0_when_constructed_then_throws_ArgumentError_with_correct_name_and_message',
        () {
      expect(
        () => AppSettingsData(
          languageCode: 'it',
          painEnabled: true,
          notesEnabled: true,
          notificationDaysBefore: 0,
          notificationsEnabled: false,
          onboardingCompleted: false,
        ),
        throwsA(
          allOf(
            isA<ArgumentError>(),
            predicate<ArgumentError>(
              (e) => e.name == 'notificationDaysBefore',
              'name == notificationDaysBefore',
            ),
            predicate<ArgumentError>(
              (e) => e.message.toString().contains('must be in [1, 7]'),
              'message contains "must be in [1, 7]"',
            ),
          ),
        ),
      );
    });

    test(
        'given_notificationDaysBefore_8_when_constructed_then_throws_ArgumentError_with_correct_name_and_message',
        () {
      expect(
        () => AppSettingsData(
          languageCode: 'it',
          painEnabled: true,
          notesEnabled: true,
          notificationDaysBefore: 8,
          notificationsEnabled: false,
          onboardingCompleted: false,
        ),
        throwsA(
          allOf(
            isA<ArgumentError>(),
            predicate<ArgumentError>(
              (e) => e.name == 'notificationDaysBefore',
              'name == notificationDaysBefore',
            ),
            predicate<ArgumentError>(
              (e) => e.message.toString().contains('must be in [1, 7]'),
              'message contains "must be in [1, 7]"',
            ),
          ),
        ),
      );
    });

    test(
        'given_notificationDaysBefore_1_lower_bound_when_constructed_then_stores_1',
        () {
      final settings = AppSettingsData(
        languageCode: 'it',
        painEnabled: true,
        notesEnabled: true,
        notificationDaysBefore: 1,
        notificationsEnabled: false,
        onboardingCompleted: false,
      );
      expect(settings.notificationDaysBefore, 1);
    });

    test(
        'given_notificationDaysBefore_7_upper_bound_when_constructed_then_stores_7',
        () {
      final settings = AppSettingsData(
        languageCode: 'it',
        painEnabled: true,
        notesEnabled: true,
        notificationDaysBefore: 7,
        notificationsEnabled: false,
        onboardingCompleted: false,
      );
      expect(settings.notificationDaysBefore, 7);
    });

    test(
        'given_notificationTimeMinutes_minus1_when_constructed_then_throws_ArgumentError_with_correct_name_and_message',
        () {
      expect(
        () => AppSettingsData(
          languageCode: 'it',
          painEnabled: true,
          notesEnabled: true,
          notificationDaysBefore: 2,
          notificationsEnabled: false,
          onboardingCompleted: false,
          notificationTimeMinutes: -1,
        ),
        throwsA(
          allOf(
            isA<ArgumentError>(),
            predicate<ArgumentError>(
              (e) => e.name == 'notificationTimeMinutes',
              'name == notificationTimeMinutes',
            ),
            predicate<ArgumentError>(
              (e) => e.message.toString().contains('must be in [0, 1439]'),
              'message contains "must be in [0, 1439]"',
            ),
          ),
        ),
      );
    });

    test(
        'given_notificationTimeMinutes_1440_when_constructed_then_throws_ArgumentError_with_correct_name_and_message',
        () {
      expect(
        () => AppSettingsData(
          languageCode: 'it',
          painEnabled: true,
          notesEnabled: true,
          notificationDaysBefore: 2,
          notificationsEnabled: false,
          onboardingCompleted: false,
          notificationTimeMinutes: 1440,
        ),
        throwsA(
          allOf(
            isA<ArgumentError>(),
            predicate<ArgumentError>(
              (e) => e.name == 'notificationTimeMinutes',
              'name == notificationTimeMinutes',
            ),
            predicate<ArgumentError>(
              (e) => e.message.toString().contains('must be in [0, 1439]'),
              'message contains "must be in [0, 1439]"',
            ),
          ),
        ),
      );
    });

    test(
        'given_notificationTimeMinutes_0_lower_bound_when_constructed_then_stores_0',
        () {
      final settings = AppSettingsData(
        languageCode: 'it',
        painEnabled: true,
        notesEnabled: true,
        notificationDaysBefore: 2,
        notificationsEnabled: false,
        onboardingCompleted: false,
        notificationTimeMinutes: 0,
      );
      expect(settings.notificationTimeMinutes, 0);
    });

    test(
        'given_notificationTimeMinutes_1439_upper_bound_when_constructed_then_stores_1439',
        () {
      final settings = AppSettingsData(
        languageCode: 'it',
        painEnabled: true,
        notesEnabled: true,
        notificationDaysBefore: 2,
        notificationsEnabled: false,
        onboardingCompleted: false,
        notificationTimeMinutes: 1439,
      );
      expect(settings.notificationTimeMinutes, 1439);
    });
  });

  group('backupSuspended field — FR-03', () {
    test('given_backupSuspended_true_when_constructed_then_field_stores_true',
        () {
      final settings = makeSettings(backupSuspended: true);
      expect(settings.backupSuspended, isTrue);
    });

    test(
        'given_instances_differing_only_in_backupSuspended_when_compared_then_not_equal',
        () {
      final a = makeSettings(backupSuspended: false);
      final b = makeSettings(backupSuspended: true);
      expect(a, isNot(equals(b)));
    });

    test(
        'given_two_instances_with_backupSuspended_false_and_all_equal_when_compared_then_equal_and_same_hashCode',
        () {
      final a = makeSettings(backupSuspended: false);
      final b = makeSettings(backupSuspended: false);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });
  });
}
