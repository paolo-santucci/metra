// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $DailyLogsTable extends DailyLogs
    with TableInfo<$DailyLogsTable, DailyLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DailyLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
      'date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _flowIntensityMeta =
      const VerificationMeta('flowIntensity');
  @override
  late final GeneratedColumn<int> flowIntensity = GeneratedColumn<int>(
      'flow_intensity', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _spottingMeta =
      const VerificationMeta('spotting');
  @override
  late final GeneratedColumn<bool> spotting = GeneratedColumn<bool>(
      'spotting', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("spotting" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _otherDischargeMeta =
      const VerificationMeta('otherDischarge');
  @override
  late final GeneratedColumn<bool> otherDischarge = GeneratedColumn<bool>(
      'other_discharge', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("other_discharge" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _painEnabledMeta =
      const VerificationMeta('painEnabled');
  @override
  late final GeneratedColumn<bool> painEnabled = GeneratedColumn<bool>(
      'pain_enabled', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("pain_enabled" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _painIntensityMeta =
      const VerificationMeta('painIntensity');
  @override
  late final GeneratedColumn<int> painIntensity = GeneratedColumn<int>(
      'pain_intensity', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _notesEnabledMeta =
      const VerificationMeta('notesEnabled');
  @override
  late final GeneratedColumn<bool> notesEnabled = GeneratedColumn<bool>(
      'notes_enabled', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("notes_enabled" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        date,
        flowIntensity,
        spotting,
        otherDischarge,
        painEnabled,
        painIntensity,
        notesEnabled,
        notes
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'daily_logs';
  @override
  VerificationContext validateIntegrity(Insertable<DailyLog> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('date')) {
      context.handle(
          _dateMeta, date.isAcceptableOrUnknown(data['date']!, _dateMeta));
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('flow_intensity')) {
      context.handle(
          _flowIntensityMeta,
          flowIntensity.isAcceptableOrUnknown(
              data['flow_intensity']!, _flowIntensityMeta));
    }
    if (data.containsKey('spotting')) {
      context.handle(_spottingMeta,
          spotting.isAcceptableOrUnknown(data['spotting']!, _spottingMeta));
    }
    if (data.containsKey('other_discharge')) {
      context.handle(
          _otherDischargeMeta,
          otherDischarge.isAcceptableOrUnknown(
              data['other_discharge']!, _otherDischargeMeta));
    }
    if (data.containsKey('pain_enabled')) {
      context.handle(
          _painEnabledMeta,
          painEnabled.isAcceptableOrUnknown(
              data['pain_enabled']!, _painEnabledMeta));
    }
    if (data.containsKey('pain_intensity')) {
      context.handle(
          _painIntensityMeta,
          painIntensity.isAcceptableOrUnknown(
              data['pain_intensity']!, _painIntensityMeta));
    }
    if (data.containsKey('notes_enabled')) {
      context.handle(
          _notesEnabledMeta,
          notesEnabled.isAcceptableOrUnknown(
              data['notes_enabled']!, _notesEnabledMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {date};
  @override
  DailyLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DailyLog(
      date: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}date'])!,
      flowIntensity: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}flow_intensity']),
      spotting: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}spotting'])!,
      otherDischarge: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}other_discharge'])!,
      painEnabled: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}pain_enabled'])!,
      painIntensity: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}pain_intensity']),
      notesEnabled: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}notes_enabled'])!,
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes']),
    );
  }

  @override
  $DailyLogsTable createAlias(String alias) {
    return $DailyLogsTable(attachedDatabase, alias);
  }
}

class DailyLog extends DataClass implements Insertable<DailyLog> {
  final DateTime date;
  final int? flowIntensity;
  final bool spotting;
  final bool otherDischarge;
  final bool painEnabled;
  final int? painIntensity;
  final bool notesEnabled;
  final String? notes;
  const DailyLog(
      {required this.date,
      this.flowIntensity,
      required this.spotting,
      required this.otherDischarge,
      required this.painEnabled,
      this.painIntensity,
      required this.notesEnabled,
      this.notes});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['date'] = Variable<DateTime>(date);
    if (!nullToAbsent || flowIntensity != null) {
      map['flow_intensity'] = Variable<int>(flowIntensity);
    }
    map['spotting'] = Variable<bool>(spotting);
    map['other_discharge'] = Variable<bool>(otherDischarge);
    map['pain_enabled'] = Variable<bool>(painEnabled);
    if (!nullToAbsent || painIntensity != null) {
      map['pain_intensity'] = Variable<int>(painIntensity);
    }
    map['notes_enabled'] = Variable<bool>(notesEnabled);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  DailyLogsCompanion toCompanion(bool nullToAbsent) {
    return DailyLogsCompanion(
      date: Value(date),
      flowIntensity: flowIntensity == null && nullToAbsent
          ? const Value.absent()
          : Value(flowIntensity),
      spotting: Value(spotting),
      otherDischarge: Value(otherDischarge),
      painEnabled: Value(painEnabled),
      painIntensity: painIntensity == null && nullToAbsent
          ? const Value.absent()
          : Value(painIntensity),
      notesEnabled: Value(notesEnabled),
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
    );
  }

  factory DailyLog.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DailyLog(
      date: serializer.fromJson<DateTime>(json['date']),
      flowIntensity: serializer.fromJson<int?>(json['flowIntensity']),
      spotting: serializer.fromJson<bool>(json['spotting']),
      otherDischarge: serializer.fromJson<bool>(json['otherDischarge']),
      painEnabled: serializer.fromJson<bool>(json['painEnabled']),
      painIntensity: serializer.fromJson<int?>(json['painIntensity']),
      notesEnabled: serializer.fromJson<bool>(json['notesEnabled']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'date': serializer.toJson<DateTime>(date),
      'flowIntensity': serializer.toJson<int?>(flowIntensity),
      'spotting': serializer.toJson<bool>(spotting),
      'otherDischarge': serializer.toJson<bool>(otherDischarge),
      'painEnabled': serializer.toJson<bool>(painEnabled),
      'painIntensity': serializer.toJson<int?>(painIntensity),
      'notesEnabled': serializer.toJson<bool>(notesEnabled),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  DailyLog copyWith(
          {DateTime? date,
          Value<int?> flowIntensity = const Value.absent(),
          bool? spotting,
          bool? otherDischarge,
          bool? painEnabled,
          Value<int?> painIntensity = const Value.absent(),
          bool? notesEnabled,
          Value<String?> notes = const Value.absent()}) =>
      DailyLog(
        date: date ?? this.date,
        flowIntensity:
            flowIntensity.present ? flowIntensity.value : this.flowIntensity,
        spotting: spotting ?? this.spotting,
        otherDischarge: otherDischarge ?? this.otherDischarge,
        painEnabled: painEnabled ?? this.painEnabled,
        painIntensity:
            painIntensity.present ? painIntensity.value : this.painIntensity,
        notesEnabled: notesEnabled ?? this.notesEnabled,
        notes: notes.present ? notes.value : this.notes,
      );
  DailyLog copyWithCompanion(DailyLogsCompanion data) {
    return DailyLog(
      date: data.date.present ? data.date.value : this.date,
      flowIntensity: data.flowIntensity.present
          ? data.flowIntensity.value
          : this.flowIntensity,
      spotting: data.spotting.present ? data.spotting.value : this.spotting,
      otherDischarge: data.otherDischarge.present
          ? data.otherDischarge.value
          : this.otherDischarge,
      painEnabled:
          data.painEnabled.present ? data.painEnabled.value : this.painEnabled,
      painIntensity: data.painIntensity.present
          ? data.painIntensity.value
          : this.painIntensity,
      notesEnabled: data.notesEnabled.present
          ? data.notesEnabled.value
          : this.notesEnabled,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DailyLog(')
          ..write('date: $date, ')
          ..write('flowIntensity: $flowIntensity, ')
          ..write('spotting: $spotting, ')
          ..write('otherDischarge: $otherDischarge, ')
          ..write('painEnabled: $painEnabled, ')
          ..write('painIntensity: $painIntensity, ')
          ..write('notesEnabled: $notesEnabled, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(date, flowIntensity, spotting, otherDischarge,
      painEnabled, painIntensity, notesEnabled, notes);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DailyLog &&
          other.date == this.date &&
          other.flowIntensity == this.flowIntensity &&
          other.spotting == this.spotting &&
          other.otherDischarge == this.otherDischarge &&
          other.painEnabled == this.painEnabled &&
          other.painIntensity == this.painIntensity &&
          other.notesEnabled == this.notesEnabled &&
          other.notes == this.notes);
}

class DailyLogsCompanion extends UpdateCompanion<DailyLog> {
  final Value<DateTime> date;
  final Value<int?> flowIntensity;
  final Value<bool> spotting;
  final Value<bool> otherDischarge;
  final Value<bool> painEnabled;
  final Value<int?> painIntensity;
  final Value<bool> notesEnabled;
  final Value<String?> notes;
  final Value<int> rowid;
  const DailyLogsCompanion({
    this.date = const Value.absent(),
    this.flowIntensity = const Value.absent(),
    this.spotting = const Value.absent(),
    this.otherDischarge = const Value.absent(),
    this.painEnabled = const Value.absent(),
    this.painIntensity = const Value.absent(),
    this.notesEnabled = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DailyLogsCompanion.insert({
    required DateTime date,
    this.flowIntensity = const Value.absent(),
    this.spotting = const Value.absent(),
    this.otherDischarge = const Value.absent(),
    this.painEnabled = const Value.absent(),
    this.painIntensity = const Value.absent(),
    this.notesEnabled = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : date = Value(date);
  static Insertable<DailyLog> custom({
    Expression<DateTime>? date,
    Expression<int>? flowIntensity,
    Expression<bool>? spotting,
    Expression<bool>? otherDischarge,
    Expression<bool>? painEnabled,
    Expression<int>? painIntensity,
    Expression<bool>? notesEnabled,
    Expression<String>? notes,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (date != null) 'date': date,
      if (flowIntensity != null) 'flow_intensity': flowIntensity,
      if (spotting != null) 'spotting': spotting,
      if (otherDischarge != null) 'other_discharge': otherDischarge,
      if (painEnabled != null) 'pain_enabled': painEnabled,
      if (painIntensity != null) 'pain_intensity': painIntensity,
      if (notesEnabled != null) 'notes_enabled': notesEnabled,
      if (notes != null) 'notes': notes,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DailyLogsCompanion copyWith(
      {Value<DateTime>? date,
      Value<int?>? flowIntensity,
      Value<bool>? spotting,
      Value<bool>? otherDischarge,
      Value<bool>? painEnabled,
      Value<int?>? painIntensity,
      Value<bool>? notesEnabled,
      Value<String?>? notes,
      Value<int>? rowid}) {
    return DailyLogsCompanion(
      date: date ?? this.date,
      flowIntensity: flowIntensity ?? this.flowIntensity,
      spotting: spotting ?? this.spotting,
      otherDischarge: otherDischarge ?? this.otherDischarge,
      painEnabled: painEnabled ?? this.painEnabled,
      painIntensity: painIntensity ?? this.painIntensity,
      notesEnabled: notesEnabled ?? this.notesEnabled,
      notes: notes ?? this.notes,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (flowIntensity.present) {
      map['flow_intensity'] = Variable<int>(flowIntensity.value);
    }
    if (spotting.present) {
      map['spotting'] = Variable<bool>(spotting.value);
    }
    if (otherDischarge.present) {
      map['other_discharge'] = Variable<bool>(otherDischarge.value);
    }
    if (painEnabled.present) {
      map['pain_enabled'] = Variable<bool>(painEnabled.value);
    }
    if (painIntensity.present) {
      map['pain_intensity'] = Variable<int>(painIntensity.value);
    }
    if (notesEnabled.present) {
      map['notes_enabled'] = Variable<bool>(notesEnabled.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DailyLogsCompanion(')
          ..write('date: $date, ')
          ..write('flowIntensity: $flowIntensity, ')
          ..write('spotting: $spotting, ')
          ..write('otherDischarge: $otherDischarge, ')
          ..write('painEnabled: $painEnabled, ')
          ..write('painIntensity: $painIntensity, ')
          ..write('notesEnabled: $notesEnabled, ')
          ..write('notes: $notes, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PainSymptomsTable extends PainSymptoms
    with TableInfo<$PainSymptomsTable, PainSymptom> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PainSymptomsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _dailyLogDateMeta =
      const VerificationMeta('dailyLogDate');
  @override
  late final GeneratedColumn<DateTime> dailyLogDate = GeneratedColumn<DateTime>(
      'daily_log_date', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES daily_logs (date) ON DELETE CASCADE'));
  static const VerificationMeta _symptomTypeMeta =
      const VerificationMeta('symptomType');
  @override
  late final GeneratedColumn<int> symptomType = GeneratedColumn<int>(
      'symptom_type', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _customLabelMeta =
      const VerificationMeta('customLabel');
  @override
  late final GeneratedColumn<String> customLabel = GeneratedColumn<String>(
      'custom_label', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, dailyLogDate, symptomType, customLabel];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pain_symptoms';
  @override
  VerificationContext validateIntegrity(Insertable<PainSymptom> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('daily_log_date')) {
      context.handle(
          _dailyLogDateMeta,
          dailyLogDate.isAcceptableOrUnknown(
              data['daily_log_date']!, _dailyLogDateMeta));
    } else if (isInserting) {
      context.missing(_dailyLogDateMeta);
    }
    if (data.containsKey('symptom_type')) {
      context.handle(
          _symptomTypeMeta,
          symptomType.isAcceptableOrUnknown(
              data['symptom_type']!, _symptomTypeMeta));
    } else if (isInserting) {
      context.missing(_symptomTypeMeta);
    }
    if (data.containsKey('custom_label')) {
      context.handle(
          _customLabelMeta,
          customLabel.isAcceptableOrUnknown(
              data['custom_label']!, _customLabelMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PainSymptom map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PainSymptom(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      dailyLogDate: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}daily_log_date'])!,
      symptomType: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}symptom_type'])!,
      customLabel: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}custom_label']),
    );
  }

  @override
  $PainSymptomsTable createAlias(String alias) {
    return $PainSymptomsTable(attachedDatabase, alias);
  }
}

class PainSymptom extends DataClass implements Insertable<PainSymptom> {
  final int id;
  final DateTime dailyLogDate;
  final int symptomType;
  final String? customLabel;
  const PainSymptom(
      {required this.id,
      required this.dailyLogDate,
      required this.symptomType,
      this.customLabel});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['daily_log_date'] = Variable<DateTime>(dailyLogDate);
    map['symptom_type'] = Variable<int>(symptomType);
    if (!nullToAbsent || customLabel != null) {
      map['custom_label'] = Variable<String>(customLabel);
    }
    return map;
  }

  PainSymptomsCompanion toCompanion(bool nullToAbsent) {
    return PainSymptomsCompanion(
      id: Value(id),
      dailyLogDate: Value(dailyLogDate),
      symptomType: Value(symptomType),
      customLabel: customLabel == null && nullToAbsent
          ? const Value.absent()
          : Value(customLabel),
    );
  }

  factory PainSymptom.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PainSymptom(
      id: serializer.fromJson<int>(json['id']),
      dailyLogDate: serializer.fromJson<DateTime>(json['dailyLogDate']),
      symptomType: serializer.fromJson<int>(json['symptomType']),
      customLabel: serializer.fromJson<String?>(json['customLabel']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'dailyLogDate': serializer.toJson<DateTime>(dailyLogDate),
      'symptomType': serializer.toJson<int>(symptomType),
      'customLabel': serializer.toJson<String?>(customLabel),
    };
  }

  PainSymptom copyWith(
          {int? id,
          DateTime? dailyLogDate,
          int? symptomType,
          Value<String?> customLabel = const Value.absent()}) =>
      PainSymptom(
        id: id ?? this.id,
        dailyLogDate: dailyLogDate ?? this.dailyLogDate,
        symptomType: symptomType ?? this.symptomType,
        customLabel: customLabel.present ? customLabel.value : this.customLabel,
      );
  PainSymptom copyWithCompanion(PainSymptomsCompanion data) {
    return PainSymptom(
      id: data.id.present ? data.id.value : this.id,
      dailyLogDate: data.dailyLogDate.present
          ? data.dailyLogDate.value
          : this.dailyLogDate,
      symptomType:
          data.symptomType.present ? data.symptomType.value : this.symptomType,
      customLabel:
          data.customLabel.present ? data.customLabel.value : this.customLabel,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PainSymptom(')
          ..write('id: $id, ')
          ..write('dailyLogDate: $dailyLogDate, ')
          ..write('symptomType: $symptomType, ')
          ..write('customLabel: $customLabel')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, dailyLogDate, symptomType, customLabel);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PainSymptom &&
          other.id == this.id &&
          other.dailyLogDate == this.dailyLogDate &&
          other.symptomType == this.symptomType &&
          other.customLabel == this.customLabel);
}

class PainSymptomsCompanion extends UpdateCompanion<PainSymptom> {
  final Value<int> id;
  final Value<DateTime> dailyLogDate;
  final Value<int> symptomType;
  final Value<String?> customLabel;
  const PainSymptomsCompanion({
    this.id = const Value.absent(),
    this.dailyLogDate = const Value.absent(),
    this.symptomType = const Value.absent(),
    this.customLabel = const Value.absent(),
  });
  PainSymptomsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime dailyLogDate,
    required int symptomType,
    this.customLabel = const Value.absent(),
  })  : dailyLogDate = Value(dailyLogDate),
        symptomType = Value(symptomType);
  static Insertable<PainSymptom> custom({
    Expression<int>? id,
    Expression<DateTime>? dailyLogDate,
    Expression<int>? symptomType,
    Expression<String>? customLabel,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (dailyLogDate != null) 'daily_log_date': dailyLogDate,
      if (symptomType != null) 'symptom_type': symptomType,
      if (customLabel != null) 'custom_label': customLabel,
    });
  }

  PainSymptomsCompanion copyWith(
      {Value<int>? id,
      Value<DateTime>? dailyLogDate,
      Value<int>? symptomType,
      Value<String?>? customLabel}) {
    return PainSymptomsCompanion(
      id: id ?? this.id,
      dailyLogDate: dailyLogDate ?? this.dailyLogDate,
      symptomType: symptomType ?? this.symptomType,
      customLabel: customLabel ?? this.customLabel,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (dailyLogDate.present) {
      map['daily_log_date'] = Variable<DateTime>(dailyLogDate.value);
    }
    if (symptomType.present) {
      map['symptom_type'] = Variable<int>(symptomType.value);
    }
    if (customLabel.present) {
      map['custom_label'] = Variable<String>(customLabel.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PainSymptomsCompanion(')
          ..write('id: $id, ')
          ..write('dailyLogDate: $dailyLogDate, ')
          ..write('symptomType: $symptomType, ')
          ..write('customLabel: $customLabel')
          ..write(')'))
        .toString();
  }
}

class $CycleEntriesTable extends CycleEntries
    with TableInfo<$CycleEntriesTable, CycleEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CycleEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _startDateMeta =
      const VerificationMeta('startDate');
  @override
  late final GeneratedColumn<DateTime> startDate = GeneratedColumn<DateTime>(
      'start_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _endDateMeta =
      const VerificationMeta('endDate');
  @override
  late final GeneratedColumn<DateTime> endDate = GeneratedColumn<DateTime>(
      'end_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _cycleLengthMeta =
      const VerificationMeta('cycleLength');
  @override
  late final GeneratedColumn<int> cycleLength = GeneratedColumn<int>(
      'cycle_length', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _periodLengthMeta =
      const VerificationMeta('periodLength');
  @override
  late final GeneratedColumn<int> periodLength = GeneratedColumn<int>(
      'period_length', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, startDate, endDate, cycleLength, periodLength];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cycle_entries';
  @override
  VerificationContext validateIntegrity(Insertable<CycleEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('start_date')) {
      context.handle(_startDateMeta,
          startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta));
    } else if (isInserting) {
      context.missing(_startDateMeta);
    }
    if (data.containsKey('end_date')) {
      context.handle(_endDateMeta,
          endDate.isAcceptableOrUnknown(data['end_date']!, _endDateMeta));
    }
    if (data.containsKey('cycle_length')) {
      context.handle(
          _cycleLengthMeta,
          cycleLength.isAcceptableOrUnknown(
              data['cycle_length']!, _cycleLengthMeta));
    }
    if (data.containsKey('period_length')) {
      context.handle(
          _periodLengthMeta,
          periodLength.isAcceptableOrUnknown(
              data['period_length']!, _periodLengthMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CycleEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CycleEntry(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      startDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}start_date'])!,
      endDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}end_date']),
      cycleLength: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}cycle_length']),
      periodLength: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}period_length']),
    );
  }

  @override
  $CycleEntriesTable createAlias(String alias) {
    return $CycleEntriesTable(attachedDatabase, alias);
  }
}

class CycleEntry extends DataClass implements Insertable<CycleEntry> {
  final int id;
  final DateTime startDate;
  final DateTime? endDate;
  final int? cycleLength;
  final int? periodLength;
  const CycleEntry(
      {required this.id,
      required this.startDate,
      this.endDate,
      this.cycleLength,
      this.periodLength});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['start_date'] = Variable<DateTime>(startDate);
    if (!nullToAbsent || endDate != null) {
      map['end_date'] = Variable<DateTime>(endDate);
    }
    if (!nullToAbsent || cycleLength != null) {
      map['cycle_length'] = Variable<int>(cycleLength);
    }
    if (!nullToAbsent || periodLength != null) {
      map['period_length'] = Variable<int>(periodLength);
    }
    return map;
  }

  CycleEntriesCompanion toCompanion(bool nullToAbsent) {
    return CycleEntriesCompanion(
      id: Value(id),
      startDate: Value(startDate),
      endDate: endDate == null && nullToAbsent
          ? const Value.absent()
          : Value(endDate),
      cycleLength: cycleLength == null && nullToAbsent
          ? const Value.absent()
          : Value(cycleLength),
      periodLength: periodLength == null && nullToAbsent
          ? const Value.absent()
          : Value(periodLength),
    );
  }

  factory CycleEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CycleEntry(
      id: serializer.fromJson<int>(json['id']),
      startDate: serializer.fromJson<DateTime>(json['startDate']),
      endDate: serializer.fromJson<DateTime?>(json['endDate']),
      cycleLength: serializer.fromJson<int?>(json['cycleLength']),
      periodLength: serializer.fromJson<int?>(json['periodLength']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'startDate': serializer.toJson<DateTime>(startDate),
      'endDate': serializer.toJson<DateTime?>(endDate),
      'cycleLength': serializer.toJson<int?>(cycleLength),
      'periodLength': serializer.toJson<int?>(periodLength),
    };
  }

  CycleEntry copyWith(
          {int? id,
          DateTime? startDate,
          Value<DateTime?> endDate = const Value.absent(),
          Value<int?> cycleLength = const Value.absent(),
          Value<int?> periodLength = const Value.absent()}) =>
      CycleEntry(
        id: id ?? this.id,
        startDate: startDate ?? this.startDate,
        endDate: endDate.present ? endDate.value : this.endDate,
        cycleLength: cycleLength.present ? cycleLength.value : this.cycleLength,
        periodLength:
            periodLength.present ? periodLength.value : this.periodLength,
      );
  CycleEntry copyWithCompanion(CycleEntriesCompanion data) {
    return CycleEntry(
      id: data.id.present ? data.id.value : this.id,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
      cycleLength:
          data.cycleLength.present ? data.cycleLength.value : this.cycleLength,
      periodLength: data.periodLength.present
          ? data.periodLength.value
          : this.periodLength,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CycleEntry(')
          ..write('id: $id, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('cycleLength: $cycleLength, ')
          ..write('periodLength: $periodLength')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, startDate, endDate, cycleLength, periodLength);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CycleEntry &&
          other.id == this.id &&
          other.startDate == this.startDate &&
          other.endDate == this.endDate &&
          other.cycleLength == this.cycleLength &&
          other.periodLength == this.periodLength);
}

class CycleEntriesCompanion extends UpdateCompanion<CycleEntry> {
  final Value<int> id;
  final Value<DateTime> startDate;
  final Value<DateTime?> endDate;
  final Value<int?> cycleLength;
  final Value<int?> periodLength;
  const CycleEntriesCompanion({
    this.id = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.cycleLength = const Value.absent(),
    this.periodLength = const Value.absent(),
  });
  CycleEntriesCompanion.insert({
    this.id = const Value.absent(),
    required DateTime startDate,
    this.endDate = const Value.absent(),
    this.cycleLength = const Value.absent(),
    this.periodLength = const Value.absent(),
  }) : startDate = Value(startDate);
  static Insertable<CycleEntry> custom({
    Expression<int>? id,
    Expression<DateTime>? startDate,
    Expression<DateTime>? endDate,
    Expression<int>? cycleLength,
    Expression<int>? periodLength,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (cycleLength != null) 'cycle_length': cycleLength,
      if (periodLength != null) 'period_length': periodLength,
    });
  }

  CycleEntriesCompanion copyWith(
      {Value<int>? id,
      Value<DateTime>? startDate,
      Value<DateTime?>? endDate,
      Value<int?>? cycleLength,
      Value<int?>? periodLength}) {
    return CycleEntriesCompanion(
      id: id ?? this.id,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      cycleLength: cycleLength ?? this.cycleLength,
      periodLength: periodLength ?? this.periodLength,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<DateTime>(startDate.value);
    }
    if (endDate.present) {
      map['end_date'] = Variable<DateTime>(endDate.value);
    }
    if (cycleLength.present) {
      map['cycle_length'] = Variable<int>(cycleLength.value);
    }
    if (periodLength.present) {
      map['period_length'] = Variable<int>(periodLength.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CycleEntriesCompanion(')
          ..write('id: $id, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('cycleLength: $cycleLength, ')
          ..write('periodLength: $periodLength')
          ..write(')'))
        .toString();
  }
}

class $SymptomTemplatesTable extends SymptomTemplates
    with TableInfo<$SymptomTemplatesTable, SymptomTemplate> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SymptomTemplatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
      'label', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _isActiveMeta =
      const VerificationMeta('isActive');
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
      'is_active', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_active" IN (0, 1))'),
      defaultValue: const Constant(true));
  @override
  List<GeneratedColumn> get $columns => [id, label, isActive];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'symptom_templates';
  @override
  VerificationContext validateIntegrity(Insertable<SymptomTemplate> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('label')) {
      context.handle(
          _labelMeta, label.isAcceptableOrUnknown(data['label']!, _labelMeta));
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('is_active')) {
      context.handle(_isActiveMeta,
          isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SymptomTemplate map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SymptomTemplate(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      label: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}label'])!,
      isActive: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_active'])!,
    );
  }

  @override
  $SymptomTemplatesTable createAlias(String alias) {
    return $SymptomTemplatesTable(attachedDatabase, alias);
  }
}

class SymptomTemplate extends DataClass implements Insertable<SymptomTemplate> {
  final int id;
  final String label;
  final bool isActive;
  const SymptomTemplate(
      {required this.id, required this.label, required this.isActive});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['label'] = Variable<String>(label);
    map['is_active'] = Variable<bool>(isActive);
    return map;
  }

  SymptomTemplatesCompanion toCompanion(bool nullToAbsent) {
    return SymptomTemplatesCompanion(
      id: Value(id),
      label: Value(label),
      isActive: Value(isActive),
    );
  }

  factory SymptomTemplate.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SymptomTemplate(
      id: serializer.fromJson<int>(json['id']),
      label: serializer.fromJson<String>(json['label']),
      isActive: serializer.fromJson<bool>(json['isActive']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'label': serializer.toJson<String>(label),
      'isActive': serializer.toJson<bool>(isActive),
    };
  }

  SymptomTemplate copyWith({int? id, String? label, bool? isActive}) =>
      SymptomTemplate(
        id: id ?? this.id,
        label: label ?? this.label,
        isActive: isActive ?? this.isActive,
      );
  SymptomTemplate copyWithCompanion(SymptomTemplatesCompanion data) {
    return SymptomTemplate(
      id: data.id.present ? data.id.value : this.id,
      label: data.label.present ? data.label.value : this.label,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SymptomTemplate(')
          ..write('id: $id, ')
          ..write('label: $label, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, label, isActive);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SymptomTemplate &&
          other.id == this.id &&
          other.label == this.label &&
          other.isActive == this.isActive);
}

class SymptomTemplatesCompanion extends UpdateCompanion<SymptomTemplate> {
  final Value<int> id;
  final Value<String> label;
  final Value<bool> isActive;
  const SymptomTemplatesCompanion({
    this.id = const Value.absent(),
    this.label = const Value.absent(),
    this.isActive = const Value.absent(),
  });
  SymptomTemplatesCompanion.insert({
    this.id = const Value.absent(),
    required String label,
    this.isActive = const Value.absent(),
  }) : label = Value(label);
  static Insertable<SymptomTemplate> custom({
    Expression<int>? id,
    Expression<String>? label,
    Expression<bool>? isActive,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (label != null) 'label': label,
      if (isActive != null) 'is_active': isActive,
    });
  }

  SymptomTemplatesCompanion copyWith(
      {Value<int>? id, Value<String>? label, Value<bool>? isActive}) {
    return SymptomTemplatesCompanion(
      id: id ?? this.id,
      label: label ?? this.label,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SymptomTemplatesCompanion(')
          ..write('id: $id, ')
          ..write('label: $label, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _languageCodeMeta =
      const VerificationMeta('languageCode');
  @override
  late final GeneratedColumn<String> languageCode = GeneratedColumn<String>(
      'language_code', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('it'));
  static const VerificationMeta _darkModeMeta =
      const VerificationMeta('darkMode');
  @override
  late final GeneratedColumn<bool> darkMode = GeneratedColumn<bool>(
      'dark_mode', aliasedName, true,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("dark_mode" IN (0, 1))'));
  static const VerificationMeta _painEnabledMeta =
      const VerificationMeta('painEnabled');
  @override
  late final GeneratedColumn<bool> painEnabled = GeneratedColumn<bool>(
      'pain_enabled', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("pain_enabled" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _notesEnabledMeta =
      const VerificationMeta('notesEnabled');
  @override
  late final GeneratedColumn<bool> notesEnabled = GeneratedColumn<bool>(
      'notes_enabled', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("notes_enabled" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _notificationDaysBeforeMeta =
      const VerificationMeta('notificationDaysBefore');
  @override
  late final GeneratedColumn<int> notificationDaysBefore = GeneratedColumn<int>(
      'notification_days_before', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(2));
  static const VerificationMeta _notificationsEnabledMeta =
      const VerificationMeta('notificationsEnabled');
  @override
  late final GeneratedColumn<bool> notificationsEnabled = GeneratedColumn<bool>(
      'notifications_enabled', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("notifications_enabled" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        languageCode,
        darkMode,
        painEnabled,
        notesEnabled,
        notificationDaysBefore,
        notificationsEnabled
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(Insertable<AppSetting> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('language_code')) {
      context.handle(
          _languageCodeMeta,
          languageCode.isAcceptableOrUnknown(
              data['language_code']!, _languageCodeMeta));
    }
    if (data.containsKey('dark_mode')) {
      context.handle(_darkModeMeta,
          darkMode.isAcceptableOrUnknown(data['dark_mode']!, _darkModeMeta));
    }
    if (data.containsKey('pain_enabled')) {
      context.handle(
          _painEnabledMeta,
          painEnabled.isAcceptableOrUnknown(
              data['pain_enabled']!, _painEnabledMeta));
    }
    if (data.containsKey('notes_enabled')) {
      context.handle(
          _notesEnabledMeta,
          notesEnabled.isAcceptableOrUnknown(
              data['notes_enabled']!, _notesEnabledMeta));
    }
    if (data.containsKey('notification_days_before')) {
      context.handle(
          _notificationDaysBeforeMeta,
          notificationDaysBefore.isAcceptableOrUnknown(
              data['notification_days_before']!, _notificationDaysBeforeMeta));
    }
    if (data.containsKey('notifications_enabled')) {
      context.handle(
          _notificationsEnabledMeta,
          notificationsEnabled.isAcceptableOrUnknown(
              data['notifications_enabled']!, _notificationsEnabledMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AppSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSetting(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      languageCode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}language_code'])!,
      darkMode: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}dark_mode']),
      painEnabled: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}pain_enabled'])!,
      notesEnabled: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}notes_enabled'])!,
      notificationDaysBefore: attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}notification_days_before'])!,
      notificationsEnabled: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}notifications_enabled'])!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSetting extends DataClass implements Insertable<AppSetting> {
  final int id;
  final String languageCode;
  final bool? darkMode;
  final bool painEnabled;
  final bool notesEnabled;
  final int notificationDaysBefore;
  final bool notificationsEnabled;
  const AppSetting(
      {required this.id,
      required this.languageCode,
      this.darkMode,
      required this.painEnabled,
      required this.notesEnabled,
      required this.notificationDaysBefore,
      required this.notificationsEnabled});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['language_code'] = Variable<String>(languageCode);
    if (!nullToAbsent || darkMode != null) {
      map['dark_mode'] = Variable<bool>(darkMode);
    }
    map['pain_enabled'] = Variable<bool>(painEnabled);
    map['notes_enabled'] = Variable<bool>(notesEnabled);
    map['notification_days_before'] = Variable<int>(notificationDaysBefore);
    map['notifications_enabled'] = Variable<bool>(notificationsEnabled);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(
      id: Value(id),
      languageCode: Value(languageCode),
      darkMode: darkMode == null && nullToAbsent
          ? const Value.absent()
          : Value(darkMode),
      painEnabled: Value(painEnabled),
      notesEnabled: Value(notesEnabled),
      notificationDaysBefore: Value(notificationDaysBefore),
      notificationsEnabled: Value(notificationsEnabled),
    );
  }

  factory AppSetting.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSetting(
      id: serializer.fromJson<int>(json['id']),
      languageCode: serializer.fromJson<String>(json['languageCode']),
      darkMode: serializer.fromJson<bool?>(json['darkMode']),
      painEnabled: serializer.fromJson<bool>(json['painEnabled']),
      notesEnabled: serializer.fromJson<bool>(json['notesEnabled']),
      notificationDaysBefore:
          serializer.fromJson<int>(json['notificationDaysBefore']),
      notificationsEnabled:
          serializer.fromJson<bool>(json['notificationsEnabled']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'languageCode': serializer.toJson<String>(languageCode),
      'darkMode': serializer.toJson<bool?>(darkMode),
      'painEnabled': serializer.toJson<bool>(painEnabled),
      'notesEnabled': serializer.toJson<bool>(notesEnabled),
      'notificationDaysBefore': serializer.toJson<int>(notificationDaysBefore),
      'notificationsEnabled': serializer.toJson<bool>(notificationsEnabled),
    };
  }

  AppSetting copyWith(
          {int? id,
          String? languageCode,
          Value<bool?> darkMode = const Value.absent(),
          bool? painEnabled,
          bool? notesEnabled,
          int? notificationDaysBefore,
          bool? notificationsEnabled}) =>
      AppSetting(
        id: id ?? this.id,
        languageCode: languageCode ?? this.languageCode,
        darkMode: darkMode.present ? darkMode.value : this.darkMode,
        painEnabled: painEnabled ?? this.painEnabled,
        notesEnabled: notesEnabled ?? this.notesEnabled,
        notificationDaysBefore:
            notificationDaysBefore ?? this.notificationDaysBefore,
        notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      );
  AppSetting copyWithCompanion(AppSettingsCompanion data) {
    return AppSetting(
      id: data.id.present ? data.id.value : this.id,
      languageCode: data.languageCode.present
          ? data.languageCode.value
          : this.languageCode,
      darkMode: data.darkMode.present ? data.darkMode.value : this.darkMode,
      painEnabled:
          data.painEnabled.present ? data.painEnabled.value : this.painEnabled,
      notesEnabled: data.notesEnabled.present
          ? data.notesEnabled.value
          : this.notesEnabled,
      notificationDaysBefore: data.notificationDaysBefore.present
          ? data.notificationDaysBefore.value
          : this.notificationDaysBefore,
      notificationsEnabled: data.notificationsEnabled.present
          ? data.notificationsEnabled.value
          : this.notificationsEnabled,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSetting(')
          ..write('id: $id, ')
          ..write('languageCode: $languageCode, ')
          ..write('darkMode: $darkMode, ')
          ..write('painEnabled: $painEnabled, ')
          ..write('notesEnabled: $notesEnabled, ')
          ..write('notificationDaysBefore: $notificationDaysBefore, ')
          ..write('notificationsEnabled: $notificationsEnabled')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, languageCode, darkMode, painEnabled,
      notesEnabled, notificationDaysBefore, notificationsEnabled);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSetting &&
          other.id == this.id &&
          other.languageCode == this.languageCode &&
          other.darkMode == this.darkMode &&
          other.painEnabled == this.painEnabled &&
          other.notesEnabled == this.notesEnabled &&
          other.notificationDaysBefore == this.notificationDaysBefore &&
          other.notificationsEnabled == this.notificationsEnabled);
}

class AppSettingsCompanion extends UpdateCompanion<AppSetting> {
  final Value<int> id;
  final Value<String> languageCode;
  final Value<bool?> darkMode;
  final Value<bool> painEnabled;
  final Value<bool> notesEnabled;
  final Value<int> notificationDaysBefore;
  final Value<bool> notificationsEnabled;
  const AppSettingsCompanion({
    this.id = const Value.absent(),
    this.languageCode = const Value.absent(),
    this.darkMode = const Value.absent(),
    this.painEnabled = const Value.absent(),
    this.notesEnabled = const Value.absent(),
    this.notificationDaysBefore = const Value.absent(),
    this.notificationsEnabled = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    this.id = const Value.absent(),
    this.languageCode = const Value.absent(),
    this.darkMode = const Value.absent(),
    this.painEnabled = const Value.absent(),
    this.notesEnabled = const Value.absent(),
    this.notificationDaysBefore = const Value.absent(),
    this.notificationsEnabled = const Value.absent(),
  });
  static Insertable<AppSetting> custom({
    Expression<int>? id,
    Expression<String>? languageCode,
    Expression<bool>? darkMode,
    Expression<bool>? painEnabled,
    Expression<bool>? notesEnabled,
    Expression<int>? notificationDaysBefore,
    Expression<bool>? notificationsEnabled,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (languageCode != null) 'language_code': languageCode,
      if (darkMode != null) 'dark_mode': darkMode,
      if (painEnabled != null) 'pain_enabled': painEnabled,
      if (notesEnabled != null) 'notes_enabled': notesEnabled,
      if (notificationDaysBefore != null)
        'notification_days_before': notificationDaysBefore,
      if (notificationsEnabled != null)
        'notifications_enabled': notificationsEnabled,
    });
  }

  AppSettingsCompanion copyWith(
      {Value<int>? id,
      Value<String>? languageCode,
      Value<bool?>? darkMode,
      Value<bool>? painEnabled,
      Value<bool>? notesEnabled,
      Value<int>? notificationDaysBefore,
      Value<bool>? notificationsEnabled}) {
    return AppSettingsCompanion(
      id: id ?? this.id,
      languageCode: languageCode ?? this.languageCode,
      darkMode: darkMode ?? this.darkMode,
      painEnabled: painEnabled ?? this.painEnabled,
      notesEnabled: notesEnabled ?? this.notesEnabled,
      notificationDaysBefore:
          notificationDaysBefore ?? this.notificationDaysBefore,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (languageCode.present) {
      map['language_code'] = Variable<String>(languageCode.value);
    }
    if (darkMode.present) {
      map['dark_mode'] = Variable<bool>(darkMode.value);
    }
    if (painEnabled.present) {
      map['pain_enabled'] = Variable<bool>(painEnabled.value);
    }
    if (notesEnabled.present) {
      map['notes_enabled'] = Variable<bool>(notesEnabled.value);
    }
    if (notificationDaysBefore.present) {
      map['notification_days_before'] =
          Variable<int>(notificationDaysBefore.value);
    }
    if (notificationsEnabled.present) {
      map['notifications_enabled'] = Variable<bool>(notificationsEnabled.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('id: $id, ')
          ..write('languageCode: $languageCode, ')
          ..write('darkMode: $darkMode, ')
          ..write('painEnabled: $painEnabled, ')
          ..write('notesEnabled: $notesEnabled, ')
          ..write('notificationDaysBefore: $notificationDaysBefore, ')
          ..write('notificationsEnabled: $notificationsEnabled')
          ..write(')'))
        .toString();
  }
}

class $SyncLogsTable extends SyncLogs with TableInfo<$SyncLogsTable, SyncLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _timestampMeta =
      const VerificationMeta('timestamp');
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
      'timestamp', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _providerMeta =
      const VerificationMeta('provider');
  @override
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
      'provider', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _operationMeta =
      const VerificationMeta('operation');
  @override
  late final GeneratedColumn<String> operation = GeneratedColumn<String>(
      'operation', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _successMeta =
      const VerificationMeta('success');
  @override
  late final GeneratedColumn<bool> success = GeneratedColumn<bool>(
      'success', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("success" IN (0, 1))'));
  static const VerificationMeta _errorMessageMeta =
      const VerificationMeta('errorMessage');
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
      'error_message', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, timestamp, provider, operation, success, errorMessage];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_logs';
  @override
  VerificationContext validateIntegrity(Insertable<SyncLog> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('timestamp')) {
      context.handle(_timestampMeta,
          timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta));
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('provider')) {
      context.handle(_providerMeta,
          provider.isAcceptableOrUnknown(data['provider']!, _providerMeta));
    } else if (isInserting) {
      context.missing(_providerMeta);
    }
    if (data.containsKey('operation')) {
      context.handle(_operationMeta,
          operation.isAcceptableOrUnknown(data['operation']!, _operationMeta));
    } else if (isInserting) {
      context.missing(_operationMeta);
    }
    if (data.containsKey('success')) {
      context.handle(_successMeta,
          success.isAcceptableOrUnknown(data['success']!, _successMeta));
    } else if (isInserting) {
      context.missing(_successMeta);
    }
    if (data.containsKey('error_message')) {
      context.handle(
          _errorMessageMeta,
          errorMessage.isAcceptableOrUnknown(
              data['error_message']!, _errorMessageMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncLog(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      timestamp: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}timestamp'])!,
      provider: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}provider'])!,
      operation: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}operation'])!,
      success: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}success'])!,
      errorMessage: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}error_message']),
    );
  }

  @override
  $SyncLogsTable createAlias(String alias) {
    return $SyncLogsTable(attachedDatabase, alias);
  }
}

class SyncLog extends DataClass implements Insertable<SyncLog> {
  final int id;
  final DateTime timestamp;
  final String provider;
  final String operation;
  final bool success;
  final String? errorMessage;
  const SyncLog(
      {required this.id,
      required this.timestamp,
      required this.provider,
      required this.operation,
      required this.success,
      this.errorMessage});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['timestamp'] = Variable<DateTime>(timestamp);
    map['provider'] = Variable<String>(provider);
    map['operation'] = Variable<String>(operation);
    map['success'] = Variable<bool>(success);
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    return map;
  }

  SyncLogsCompanion toCompanion(bool nullToAbsent) {
    return SyncLogsCompanion(
      id: Value(id),
      timestamp: Value(timestamp),
      provider: Value(provider),
      operation: Value(operation),
      success: Value(success),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
    );
  }

  factory SyncLog.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncLog(
      id: serializer.fromJson<int>(json['id']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      provider: serializer.fromJson<String>(json['provider']),
      operation: serializer.fromJson<String>(json['operation']),
      success: serializer.fromJson<bool>(json['success']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'provider': serializer.toJson<String>(provider),
      'operation': serializer.toJson<String>(operation),
      'success': serializer.toJson<bool>(success),
      'errorMessage': serializer.toJson<String?>(errorMessage),
    };
  }

  SyncLog copyWith(
          {int? id,
          DateTime? timestamp,
          String? provider,
          String? operation,
          bool? success,
          Value<String?> errorMessage = const Value.absent()}) =>
      SyncLog(
        id: id ?? this.id,
        timestamp: timestamp ?? this.timestamp,
        provider: provider ?? this.provider,
        operation: operation ?? this.operation,
        success: success ?? this.success,
        errorMessage:
            errorMessage.present ? errorMessage.value : this.errorMessage,
      );
  SyncLog copyWithCompanion(SyncLogsCompanion data) {
    return SyncLog(
      id: data.id.present ? data.id.value : this.id,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      provider: data.provider.present ? data.provider.value : this.provider,
      operation: data.operation.present ? data.operation.value : this.operation,
      success: data.success.present ? data.success.value : this.success,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncLog(')
          ..write('id: $id, ')
          ..write('timestamp: $timestamp, ')
          ..write('provider: $provider, ')
          ..write('operation: $operation, ')
          ..write('success: $success, ')
          ..write('errorMessage: $errorMessage')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, timestamp, provider, operation, success, errorMessage);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncLog &&
          other.id == this.id &&
          other.timestamp == this.timestamp &&
          other.provider == this.provider &&
          other.operation == this.operation &&
          other.success == this.success &&
          other.errorMessage == this.errorMessage);
}

class SyncLogsCompanion extends UpdateCompanion<SyncLog> {
  final Value<int> id;
  final Value<DateTime> timestamp;
  final Value<String> provider;
  final Value<String> operation;
  final Value<bool> success;
  final Value<String?> errorMessage;
  const SyncLogsCompanion({
    this.id = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.provider = const Value.absent(),
    this.operation = const Value.absent(),
    this.success = const Value.absent(),
    this.errorMessage = const Value.absent(),
  });
  SyncLogsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime timestamp,
    required String provider,
    required String operation,
    required bool success,
    this.errorMessage = const Value.absent(),
  })  : timestamp = Value(timestamp),
        provider = Value(provider),
        operation = Value(operation),
        success = Value(success);
  static Insertable<SyncLog> custom({
    Expression<int>? id,
    Expression<DateTime>? timestamp,
    Expression<String>? provider,
    Expression<String>? operation,
    Expression<bool>? success,
    Expression<String>? errorMessage,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (timestamp != null) 'timestamp': timestamp,
      if (provider != null) 'provider': provider,
      if (operation != null) 'operation': operation,
      if (success != null) 'success': success,
      if (errorMessage != null) 'error_message': errorMessage,
    });
  }

  SyncLogsCompanion copyWith(
      {Value<int>? id,
      Value<DateTime>? timestamp,
      Value<String>? provider,
      Value<String>? operation,
      Value<bool>? success,
      Value<String?>? errorMessage}) {
    return SyncLogsCompanion(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      provider: provider ?? this.provider,
      operation: operation ?? this.operation,
      success: success ?? this.success,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (operation.present) {
      map['operation'] = Variable<String>(operation.value);
    }
    if (success.present) {
      map['success'] = Variable<bool>(success.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncLogsCompanion(')
          ..write('id: $id, ')
          ..write('timestamp: $timestamp, ')
          ..write('provider: $provider, ')
          ..write('operation: $operation, ')
          ..write('success: $success, ')
          ..write('errorMessage: $errorMessage')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $DailyLogsTable dailyLogs = $DailyLogsTable(this);
  late final $PainSymptomsTable painSymptoms = $PainSymptomsTable(this);
  late final $CycleEntriesTable cycleEntries = $CycleEntriesTable(this);
  late final $SymptomTemplatesTable symptomTemplates =
      $SymptomTemplatesTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final $SyncLogsTable syncLogs = $SyncLogsTable(this);
  late final DailyLogDao dailyLogDao = DailyLogDao(this as AppDatabase);
  late final CycleEntryDao cycleEntryDao = CycleEntryDao(this as AppDatabase);
  late final AppSettingsDao appSettingsDao =
      AppSettingsDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        dailyLogs,
        painSymptoms,
        cycleEntries,
        symptomTemplates,
        appSettings,
        syncLogs
      ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules(
        [
          WritePropagation(
            on: TableUpdateQuery.onTableName('daily_logs',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('pain_symptoms', kind: UpdateKind.delete),
            ],
          ),
        ],
      );
}

typedef $$DailyLogsTableCreateCompanionBuilder = DailyLogsCompanion Function({
  required DateTime date,
  Value<int?> flowIntensity,
  Value<bool> spotting,
  Value<bool> otherDischarge,
  Value<bool> painEnabled,
  Value<int?> painIntensity,
  Value<bool> notesEnabled,
  Value<String?> notes,
  Value<int> rowid,
});
typedef $$DailyLogsTableUpdateCompanionBuilder = DailyLogsCompanion Function({
  Value<DateTime> date,
  Value<int?> flowIntensity,
  Value<bool> spotting,
  Value<bool> otherDischarge,
  Value<bool> painEnabled,
  Value<int?> painIntensity,
  Value<bool> notesEnabled,
  Value<String?> notes,
  Value<int> rowid,
});

final class $$DailyLogsTableReferences
    extends BaseReferences<_$AppDatabase, $DailyLogsTable, DailyLog> {
  $$DailyLogsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PainSymptomsTable, List<PainSymptom>>
      _painSymptomsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.painSymptoms,
              aliasName: $_aliasNameGenerator(
                  db.dailyLogs.date, db.painSymptoms.dailyLogDate));

  $$PainSymptomsTableProcessedTableManager get painSymptomsRefs {
    final manager = $$PainSymptomsTableTableManager($_db, $_db.painSymptoms)
        .filter((f) =>
            f.dailyLogDate.date.sqlEquals($_itemColumn<DateTime>('date')!));

    final cache = $_typedResult.readTableOrNull(_painSymptomsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$DailyLogsTableFilterComposer
    extends Composer<_$AppDatabase, $DailyLogsTable> {
  $$DailyLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get date => $composableBuilder(
      column: $table.date, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get flowIntensity => $composableBuilder(
      column: $table.flowIntensity, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get spotting => $composableBuilder(
      column: $table.spotting, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get otherDischarge => $composableBuilder(
      column: $table.otherDischarge,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get painEnabled => $composableBuilder(
      column: $table.painEnabled, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get painIntensity => $composableBuilder(
      column: $table.painIntensity, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get notesEnabled => $composableBuilder(
      column: $table.notesEnabled, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnFilters(column));

  Expression<bool> painSymptomsRefs(
      Expression<bool> Function($$PainSymptomsTableFilterComposer f) f) {
    final $$PainSymptomsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.date,
        referencedTable: $db.painSymptoms,
        getReferencedColumn: (t) => t.dailyLogDate,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PainSymptomsTableFilterComposer(
              $db: $db,
              $table: $db.painSymptoms,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$DailyLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $DailyLogsTable> {
  $$DailyLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get date => $composableBuilder(
      column: $table.date, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get flowIntensity => $composableBuilder(
      column: $table.flowIntensity,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get spotting => $composableBuilder(
      column: $table.spotting, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get otherDischarge => $composableBuilder(
      column: $table.otherDischarge,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get painEnabled => $composableBuilder(
      column: $table.painEnabled, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get painIntensity => $composableBuilder(
      column: $table.painIntensity,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get notesEnabled => $composableBuilder(
      column: $table.notesEnabled,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnOrderings(column));
}

class $$DailyLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DailyLogsTable> {
  $$DailyLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<int> get flowIntensity => $composableBuilder(
      column: $table.flowIntensity, builder: (column) => column);

  GeneratedColumn<bool> get spotting =>
      $composableBuilder(column: $table.spotting, builder: (column) => column);

  GeneratedColumn<bool> get otherDischarge => $composableBuilder(
      column: $table.otherDischarge, builder: (column) => column);

  GeneratedColumn<bool> get painEnabled => $composableBuilder(
      column: $table.painEnabled, builder: (column) => column);

  GeneratedColumn<int> get painIntensity => $composableBuilder(
      column: $table.painIntensity, builder: (column) => column);

  GeneratedColumn<bool> get notesEnabled => $composableBuilder(
      column: $table.notesEnabled, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  Expression<T> painSymptomsRefs<T extends Object>(
      Expression<T> Function($$PainSymptomsTableAnnotationComposer a) f) {
    final $$PainSymptomsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.date,
        referencedTable: $db.painSymptoms,
        getReferencedColumn: (t) => t.dailyLogDate,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PainSymptomsTableAnnotationComposer(
              $db: $db,
              $table: $db.painSymptoms,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$DailyLogsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $DailyLogsTable,
    DailyLog,
    $$DailyLogsTableFilterComposer,
    $$DailyLogsTableOrderingComposer,
    $$DailyLogsTableAnnotationComposer,
    $$DailyLogsTableCreateCompanionBuilder,
    $$DailyLogsTableUpdateCompanionBuilder,
    (DailyLog, $$DailyLogsTableReferences),
    DailyLog,
    PrefetchHooks Function({bool painSymptomsRefs})> {
  $$DailyLogsTableTableManager(_$AppDatabase db, $DailyLogsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DailyLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DailyLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DailyLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<DateTime> date = const Value.absent(),
            Value<int?> flowIntensity = const Value.absent(),
            Value<bool> spotting = const Value.absent(),
            Value<bool> otherDischarge = const Value.absent(),
            Value<bool> painEnabled = const Value.absent(),
            Value<int?> painIntensity = const Value.absent(),
            Value<bool> notesEnabled = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DailyLogsCompanion(
            date: date,
            flowIntensity: flowIntensity,
            spotting: spotting,
            otherDischarge: otherDischarge,
            painEnabled: painEnabled,
            painIntensity: painIntensity,
            notesEnabled: notesEnabled,
            notes: notes,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required DateTime date,
            Value<int?> flowIntensity = const Value.absent(),
            Value<bool> spotting = const Value.absent(),
            Value<bool> otherDischarge = const Value.absent(),
            Value<bool> painEnabled = const Value.absent(),
            Value<int?> painIntensity = const Value.absent(),
            Value<bool> notesEnabled = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DailyLogsCompanion.insert(
            date: date,
            flowIntensity: flowIntensity,
            spotting: spotting,
            otherDischarge: otherDischarge,
            painEnabled: painEnabled,
            painIntensity: painIntensity,
            notesEnabled: notesEnabled,
            notes: notes,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$DailyLogsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({painSymptomsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (painSymptomsRefs) db.painSymptoms],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (painSymptomsRefs)
                    await $_getPrefetchedData<DailyLog, $DailyLogsTable,
                            PainSymptom>(
                        currentTable: table,
                        referencedTable: $$DailyLogsTableReferences
                            ._painSymptomsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$DailyLogsTableReferences(db, table, p0)
                                .painSymptomsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.dailyLogDate == item.date),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$DailyLogsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $DailyLogsTable,
    DailyLog,
    $$DailyLogsTableFilterComposer,
    $$DailyLogsTableOrderingComposer,
    $$DailyLogsTableAnnotationComposer,
    $$DailyLogsTableCreateCompanionBuilder,
    $$DailyLogsTableUpdateCompanionBuilder,
    (DailyLog, $$DailyLogsTableReferences),
    DailyLog,
    PrefetchHooks Function({bool painSymptomsRefs})>;
typedef $$PainSymptomsTableCreateCompanionBuilder = PainSymptomsCompanion
    Function({
  Value<int> id,
  required DateTime dailyLogDate,
  required int symptomType,
  Value<String?> customLabel,
});
typedef $$PainSymptomsTableUpdateCompanionBuilder = PainSymptomsCompanion
    Function({
  Value<int> id,
  Value<DateTime> dailyLogDate,
  Value<int> symptomType,
  Value<String?> customLabel,
});

final class $$PainSymptomsTableReferences
    extends BaseReferences<_$AppDatabase, $PainSymptomsTable, PainSymptom> {
  $$PainSymptomsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $DailyLogsTable _dailyLogDateTable(_$AppDatabase db) =>
      db.dailyLogs.createAlias($_aliasNameGenerator(
          db.painSymptoms.dailyLogDate, db.dailyLogs.date));

  $$DailyLogsTableProcessedTableManager get dailyLogDate {
    final $_column = $_itemColumn<DateTime>('daily_log_date')!;

    final manager = $$DailyLogsTableTableManager($_db, $_db.dailyLogs)
        .filter((f) => f.date.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_dailyLogDateTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$PainSymptomsTableFilterComposer
    extends Composer<_$AppDatabase, $PainSymptomsTable> {
  $$PainSymptomsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get symptomType => $composableBuilder(
      column: $table.symptomType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get customLabel => $composableBuilder(
      column: $table.customLabel, builder: (column) => ColumnFilters(column));

  $$DailyLogsTableFilterComposer get dailyLogDate {
    final $$DailyLogsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.dailyLogDate,
        referencedTable: $db.dailyLogs,
        getReferencedColumn: (t) => t.date,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$DailyLogsTableFilterComposer(
              $db: $db,
              $table: $db.dailyLogs,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PainSymptomsTableOrderingComposer
    extends Composer<_$AppDatabase, $PainSymptomsTable> {
  $$PainSymptomsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get symptomType => $composableBuilder(
      column: $table.symptomType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get customLabel => $composableBuilder(
      column: $table.customLabel, builder: (column) => ColumnOrderings(column));

  $$DailyLogsTableOrderingComposer get dailyLogDate {
    final $$DailyLogsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.dailyLogDate,
        referencedTable: $db.dailyLogs,
        getReferencedColumn: (t) => t.date,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$DailyLogsTableOrderingComposer(
              $db: $db,
              $table: $db.dailyLogs,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PainSymptomsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PainSymptomsTable> {
  $$PainSymptomsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get symptomType => $composableBuilder(
      column: $table.symptomType, builder: (column) => column);

  GeneratedColumn<String> get customLabel => $composableBuilder(
      column: $table.customLabel, builder: (column) => column);

  $$DailyLogsTableAnnotationComposer get dailyLogDate {
    final $$DailyLogsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.dailyLogDate,
        referencedTable: $db.dailyLogs,
        getReferencedColumn: (t) => t.date,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$DailyLogsTableAnnotationComposer(
              $db: $db,
              $table: $db.dailyLogs,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PainSymptomsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PainSymptomsTable,
    PainSymptom,
    $$PainSymptomsTableFilterComposer,
    $$PainSymptomsTableOrderingComposer,
    $$PainSymptomsTableAnnotationComposer,
    $$PainSymptomsTableCreateCompanionBuilder,
    $$PainSymptomsTableUpdateCompanionBuilder,
    (PainSymptom, $$PainSymptomsTableReferences),
    PainSymptom,
    PrefetchHooks Function({bool dailyLogDate})> {
  $$PainSymptomsTableTableManager(_$AppDatabase db, $PainSymptomsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PainSymptomsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PainSymptomsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PainSymptomsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<DateTime> dailyLogDate = const Value.absent(),
            Value<int> symptomType = const Value.absent(),
            Value<String?> customLabel = const Value.absent(),
          }) =>
              PainSymptomsCompanion(
            id: id,
            dailyLogDate: dailyLogDate,
            symptomType: symptomType,
            customLabel: customLabel,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required DateTime dailyLogDate,
            required int symptomType,
            Value<String?> customLabel = const Value.absent(),
          }) =>
              PainSymptomsCompanion.insert(
            id: id,
            dailyLogDate: dailyLogDate,
            symptomType: symptomType,
            customLabel: customLabel,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$PainSymptomsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({dailyLogDate = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (dailyLogDate) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.dailyLogDate,
                    referencedTable:
                        $$PainSymptomsTableReferences._dailyLogDateTable(db),
                    referencedColumn: $$PainSymptomsTableReferences
                        ._dailyLogDateTable(db)
                        .date,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$PainSymptomsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PainSymptomsTable,
    PainSymptom,
    $$PainSymptomsTableFilterComposer,
    $$PainSymptomsTableOrderingComposer,
    $$PainSymptomsTableAnnotationComposer,
    $$PainSymptomsTableCreateCompanionBuilder,
    $$PainSymptomsTableUpdateCompanionBuilder,
    (PainSymptom, $$PainSymptomsTableReferences),
    PainSymptom,
    PrefetchHooks Function({bool dailyLogDate})>;
typedef $$CycleEntriesTableCreateCompanionBuilder = CycleEntriesCompanion
    Function({
  Value<int> id,
  required DateTime startDate,
  Value<DateTime?> endDate,
  Value<int?> cycleLength,
  Value<int?> periodLength,
});
typedef $$CycleEntriesTableUpdateCompanionBuilder = CycleEntriesCompanion
    Function({
  Value<int> id,
  Value<DateTime> startDate,
  Value<DateTime?> endDate,
  Value<int?> cycleLength,
  Value<int?> periodLength,
});

class $$CycleEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $CycleEntriesTable> {
  $$CycleEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get startDate => $composableBuilder(
      column: $table.startDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get endDate => $composableBuilder(
      column: $table.endDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get cycleLength => $composableBuilder(
      column: $table.cycleLength, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get periodLength => $composableBuilder(
      column: $table.periodLength, builder: (column) => ColumnFilters(column));
}

class $$CycleEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CycleEntriesTable> {
  $$CycleEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get startDate => $composableBuilder(
      column: $table.startDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get endDate => $composableBuilder(
      column: $table.endDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get cycleLength => $composableBuilder(
      column: $table.cycleLength, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get periodLength => $composableBuilder(
      column: $table.periodLength,
      builder: (column) => ColumnOrderings(column));
}

class $$CycleEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CycleEntriesTable> {
  $$CycleEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<DateTime> get endDate =>
      $composableBuilder(column: $table.endDate, builder: (column) => column);

  GeneratedColumn<int> get cycleLength => $composableBuilder(
      column: $table.cycleLength, builder: (column) => column);

  GeneratedColumn<int> get periodLength => $composableBuilder(
      column: $table.periodLength, builder: (column) => column);
}

class $$CycleEntriesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CycleEntriesTable,
    CycleEntry,
    $$CycleEntriesTableFilterComposer,
    $$CycleEntriesTableOrderingComposer,
    $$CycleEntriesTableAnnotationComposer,
    $$CycleEntriesTableCreateCompanionBuilder,
    $$CycleEntriesTableUpdateCompanionBuilder,
    (CycleEntry, BaseReferences<_$AppDatabase, $CycleEntriesTable, CycleEntry>),
    CycleEntry,
    PrefetchHooks Function()> {
  $$CycleEntriesTableTableManager(_$AppDatabase db, $CycleEntriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CycleEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CycleEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CycleEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<DateTime> startDate = const Value.absent(),
            Value<DateTime?> endDate = const Value.absent(),
            Value<int?> cycleLength = const Value.absent(),
            Value<int?> periodLength = const Value.absent(),
          }) =>
              CycleEntriesCompanion(
            id: id,
            startDate: startDate,
            endDate: endDate,
            cycleLength: cycleLength,
            periodLength: periodLength,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required DateTime startDate,
            Value<DateTime?> endDate = const Value.absent(),
            Value<int?> cycleLength = const Value.absent(),
            Value<int?> periodLength = const Value.absent(),
          }) =>
              CycleEntriesCompanion.insert(
            id: id,
            startDate: startDate,
            endDate: endDate,
            cycleLength: cycleLength,
            periodLength: periodLength,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CycleEntriesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CycleEntriesTable,
    CycleEntry,
    $$CycleEntriesTableFilterComposer,
    $$CycleEntriesTableOrderingComposer,
    $$CycleEntriesTableAnnotationComposer,
    $$CycleEntriesTableCreateCompanionBuilder,
    $$CycleEntriesTableUpdateCompanionBuilder,
    (CycleEntry, BaseReferences<_$AppDatabase, $CycleEntriesTable, CycleEntry>),
    CycleEntry,
    PrefetchHooks Function()>;
typedef $$SymptomTemplatesTableCreateCompanionBuilder
    = SymptomTemplatesCompanion Function({
  Value<int> id,
  required String label,
  Value<bool> isActive,
});
typedef $$SymptomTemplatesTableUpdateCompanionBuilder
    = SymptomTemplatesCompanion Function({
  Value<int> id,
  Value<String> label,
  Value<bool> isActive,
});

class $$SymptomTemplatesTableFilterComposer
    extends Composer<_$AppDatabase, $SymptomTemplatesTable> {
  $$SymptomTemplatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get label => $composableBuilder(
      column: $table.label, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnFilters(column));
}

class $$SymptomTemplatesTableOrderingComposer
    extends Composer<_$AppDatabase, $SymptomTemplatesTable> {
  $$SymptomTemplatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get label => $composableBuilder(
      column: $table.label, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnOrderings(column));
}

class $$SymptomTemplatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SymptomTemplatesTable> {
  $$SymptomTemplatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);
}

class $$SymptomTemplatesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SymptomTemplatesTable,
    SymptomTemplate,
    $$SymptomTemplatesTableFilterComposer,
    $$SymptomTemplatesTableOrderingComposer,
    $$SymptomTemplatesTableAnnotationComposer,
    $$SymptomTemplatesTableCreateCompanionBuilder,
    $$SymptomTemplatesTableUpdateCompanionBuilder,
    (
      SymptomTemplate,
      BaseReferences<_$AppDatabase, $SymptomTemplatesTable, SymptomTemplate>
    ),
    SymptomTemplate,
    PrefetchHooks Function()> {
  $$SymptomTemplatesTableTableManager(
      _$AppDatabase db, $SymptomTemplatesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SymptomTemplatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SymptomTemplatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SymptomTemplatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> label = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
          }) =>
              SymptomTemplatesCompanion(
            id: id,
            label: label,
            isActive: isActive,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String label,
            Value<bool> isActive = const Value.absent(),
          }) =>
              SymptomTemplatesCompanion.insert(
            id: id,
            label: label,
            isActive: isActive,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SymptomTemplatesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SymptomTemplatesTable,
    SymptomTemplate,
    $$SymptomTemplatesTableFilterComposer,
    $$SymptomTemplatesTableOrderingComposer,
    $$SymptomTemplatesTableAnnotationComposer,
    $$SymptomTemplatesTableCreateCompanionBuilder,
    $$SymptomTemplatesTableUpdateCompanionBuilder,
    (
      SymptomTemplate,
      BaseReferences<_$AppDatabase, $SymptomTemplatesTable, SymptomTemplate>
    ),
    SymptomTemplate,
    PrefetchHooks Function()>;
typedef $$AppSettingsTableCreateCompanionBuilder = AppSettingsCompanion
    Function({
  Value<int> id,
  Value<String> languageCode,
  Value<bool?> darkMode,
  Value<bool> painEnabled,
  Value<bool> notesEnabled,
  Value<int> notificationDaysBefore,
  Value<bool> notificationsEnabled,
});
typedef $$AppSettingsTableUpdateCompanionBuilder = AppSettingsCompanion
    Function({
  Value<int> id,
  Value<String> languageCode,
  Value<bool?> darkMode,
  Value<bool> painEnabled,
  Value<bool> notesEnabled,
  Value<int> notificationDaysBefore,
  Value<bool> notificationsEnabled,
});

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get languageCode => $composableBuilder(
      column: $table.languageCode, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get darkMode => $composableBuilder(
      column: $table.darkMode, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get painEnabled => $composableBuilder(
      column: $table.painEnabled, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get notesEnabled => $composableBuilder(
      column: $table.notesEnabled, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get notificationDaysBefore => $composableBuilder(
      column: $table.notificationDaysBefore,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get notificationsEnabled => $composableBuilder(
      column: $table.notificationsEnabled,
      builder: (column) => ColumnFilters(column));
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get languageCode => $composableBuilder(
      column: $table.languageCode,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get darkMode => $composableBuilder(
      column: $table.darkMode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get painEnabled => $composableBuilder(
      column: $table.painEnabled, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get notesEnabled => $composableBuilder(
      column: $table.notesEnabled,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get notificationDaysBefore => $composableBuilder(
      column: $table.notificationDaysBefore,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get notificationsEnabled => $composableBuilder(
      column: $table.notificationsEnabled,
      builder: (column) => ColumnOrderings(column));
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get languageCode => $composableBuilder(
      column: $table.languageCode, builder: (column) => column);

  GeneratedColumn<bool> get darkMode =>
      $composableBuilder(column: $table.darkMode, builder: (column) => column);

  GeneratedColumn<bool> get painEnabled => $composableBuilder(
      column: $table.painEnabled, builder: (column) => column);

  GeneratedColumn<bool> get notesEnabled => $composableBuilder(
      column: $table.notesEnabled, builder: (column) => column);

  GeneratedColumn<int> get notificationDaysBefore => $composableBuilder(
      column: $table.notificationDaysBefore, builder: (column) => column);

  GeneratedColumn<bool> get notificationsEnabled => $composableBuilder(
      column: $table.notificationsEnabled, builder: (column) => column);
}

class $$AppSettingsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AppSettingsTable,
    AppSetting,
    $$AppSettingsTableFilterComposer,
    $$AppSettingsTableOrderingComposer,
    $$AppSettingsTableAnnotationComposer,
    $$AppSettingsTableCreateCompanionBuilder,
    $$AppSettingsTableUpdateCompanionBuilder,
    (AppSetting, BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>),
    AppSetting,
    PrefetchHooks Function()> {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> languageCode = const Value.absent(),
            Value<bool?> darkMode = const Value.absent(),
            Value<bool> painEnabled = const Value.absent(),
            Value<bool> notesEnabled = const Value.absent(),
            Value<int> notificationDaysBefore = const Value.absent(),
            Value<bool> notificationsEnabled = const Value.absent(),
          }) =>
              AppSettingsCompanion(
            id: id,
            languageCode: languageCode,
            darkMode: darkMode,
            painEnabled: painEnabled,
            notesEnabled: notesEnabled,
            notificationDaysBefore: notificationDaysBefore,
            notificationsEnabled: notificationsEnabled,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> languageCode = const Value.absent(),
            Value<bool?> darkMode = const Value.absent(),
            Value<bool> painEnabled = const Value.absent(),
            Value<bool> notesEnabled = const Value.absent(),
            Value<int> notificationDaysBefore = const Value.absent(),
            Value<bool> notificationsEnabled = const Value.absent(),
          }) =>
              AppSettingsCompanion.insert(
            id: id,
            languageCode: languageCode,
            darkMode: darkMode,
            painEnabled: painEnabled,
            notesEnabled: notesEnabled,
            notificationDaysBefore: notificationDaysBefore,
            notificationsEnabled: notificationsEnabled,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AppSettingsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AppSettingsTable,
    AppSetting,
    $$AppSettingsTableFilterComposer,
    $$AppSettingsTableOrderingComposer,
    $$AppSettingsTableAnnotationComposer,
    $$AppSettingsTableCreateCompanionBuilder,
    $$AppSettingsTableUpdateCompanionBuilder,
    (AppSetting, BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>),
    AppSetting,
    PrefetchHooks Function()>;
typedef $$SyncLogsTableCreateCompanionBuilder = SyncLogsCompanion Function({
  Value<int> id,
  required DateTime timestamp,
  required String provider,
  required String operation,
  required bool success,
  Value<String?> errorMessage,
});
typedef $$SyncLogsTableUpdateCompanionBuilder = SyncLogsCompanion Function({
  Value<int> id,
  Value<DateTime> timestamp,
  Value<String> provider,
  Value<String> operation,
  Value<bool> success,
  Value<String?> errorMessage,
});

class $$SyncLogsTableFilterComposer
    extends Composer<_$AppDatabase, $SyncLogsTable> {
  $$SyncLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get provider => $composableBuilder(
      column: $table.provider, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get operation => $composableBuilder(
      column: $table.operation, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get success => $composableBuilder(
      column: $table.success, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get errorMessage => $composableBuilder(
      column: $table.errorMessage, builder: (column) => ColumnFilters(column));
}

class $$SyncLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncLogsTable> {
  $$SyncLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get provider => $composableBuilder(
      column: $table.provider, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get operation => $composableBuilder(
      column: $table.operation, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get success => $composableBuilder(
      column: $table.success, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get errorMessage => $composableBuilder(
      column: $table.errorMessage,
      builder: (column) => ColumnOrderings(column));
}

class $$SyncLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncLogsTable> {
  $$SyncLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<String> get operation =>
      $composableBuilder(column: $table.operation, builder: (column) => column);

  GeneratedColumn<bool> get success =>
      $composableBuilder(column: $table.success, builder: (column) => column);

  GeneratedColumn<String> get errorMessage => $composableBuilder(
      column: $table.errorMessage, builder: (column) => column);
}

class $$SyncLogsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SyncLogsTable,
    SyncLog,
    $$SyncLogsTableFilterComposer,
    $$SyncLogsTableOrderingComposer,
    $$SyncLogsTableAnnotationComposer,
    $$SyncLogsTableCreateCompanionBuilder,
    $$SyncLogsTableUpdateCompanionBuilder,
    (SyncLog, BaseReferences<_$AppDatabase, $SyncLogsTable, SyncLog>),
    SyncLog,
    PrefetchHooks Function()> {
  $$SyncLogsTableTableManager(_$AppDatabase db, $SyncLogsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<DateTime> timestamp = const Value.absent(),
            Value<String> provider = const Value.absent(),
            Value<String> operation = const Value.absent(),
            Value<bool> success = const Value.absent(),
            Value<String?> errorMessage = const Value.absent(),
          }) =>
              SyncLogsCompanion(
            id: id,
            timestamp: timestamp,
            provider: provider,
            operation: operation,
            success: success,
            errorMessage: errorMessage,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required DateTime timestamp,
            required String provider,
            required String operation,
            required bool success,
            Value<String?> errorMessage = const Value.absent(),
          }) =>
              SyncLogsCompanion.insert(
            id: id,
            timestamp: timestamp,
            provider: provider,
            operation: operation,
            success: success,
            errorMessage: errorMessage,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SyncLogsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SyncLogsTable,
    SyncLog,
    $$SyncLogsTableFilterComposer,
    $$SyncLogsTableOrderingComposer,
    $$SyncLogsTableAnnotationComposer,
    $$SyncLogsTableCreateCompanionBuilder,
    $$SyncLogsTableUpdateCompanionBuilder,
    (SyncLog, BaseReferences<_$AppDatabase, $SyncLogsTable, SyncLog>),
    SyncLog,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$DailyLogsTableTableManager get dailyLogs =>
      $$DailyLogsTableTableManager(_db, _db.dailyLogs);
  $$PainSymptomsTableTableManager get painSymptoms =>
      $$PainSymptomsTableTableManager(_db, _db.painSymptoms);
  $$CycleEntriesTableTableManager get cycleEntries =>
      $$CycleEntriesTableTableManager(_db, _db.cycleEntries);
  $$SymptomTemplatesTableTableManager get symptomTemplates =>
      $$SymptomTemplatesTableTableManager(_db, _db.symptomTemplates);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
  $$SyncLogsTableTableManager get syncLogs =>
      $$SyncLogsTableTableManager(_db, _db.syncLogs);
}
