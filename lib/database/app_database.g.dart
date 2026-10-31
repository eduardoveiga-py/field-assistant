// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $PeopleTable extends People with TableInfo<$PeopleTable, PersonEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PeopleTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addressMeta = const VerificationMeta(
    'address',
  );
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
    'address',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _latitudeMeta = const VerificationMeta(
    'latitude',
  );
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
    'latitude',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _longitudeMeta = const VerificationMeta(
    'longitude',
  );
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
    'longitude',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _firstContactAtMeta = const VerificationMeta(
    'firstContactAt',
  );
  @override
  late final GeneratedColumn<DateTime> firstContactAt =
      GeneratedColumn<DateTime>(
        'first_contact_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('interessado'),
  );
  static const VerificationMeta _preferredScheduleMeta = const VerificationMeta(
    'preferredSchedule',
  );
  @override
  late final GeneratedColumn<String> preferredSchedule =
      GeneratedColumn<String>(
        'preferred_schedule',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _generalNotesMeta = const VerificationMeta(
    'generalNotes',
  );
  @override
  late final GeneratedColumn<String> generalNotes = GeneratedColumn<String>(
    'general_notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contactRestrictionsMeta =
      const VerificationMeta('contactRestrictions');
  @override
  late final GeneratedColumn<String> contactRestrictions =
      GeneratedColumn<String>(
        'contact_restrictions',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
    'tags',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _lastContactAtMeta = const VerificationMeta(
    'lastContactAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastContactAt =
      GeneratedColumn<DateTime>(
        'last_contact_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _nextActionAtMeta = const VerificationMeta(
    'nextActionAt',
  );
  @override
  late final GeneratedColumn<DateTime> nextActionAt = GeneratedColumn<DateTime>(
    'next_action_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nextActionNoteMeta = const VerificationMeta(
    'nextActionNote',
  );
  @override
  late final GeneratedColumn<String> nextActionNote = GeneratedColumn<String>(
    'next_action_note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    phone,
    address,
    latitude,
    longitude,
    firstContactAt,
    status,
    preferredSchedule,
    generalNotes,
    contactRestrictions,
    tags,
    lastContactAt,
    nextActionAt,
    nextActionNote,
    createdAt,
    updatedAt,
    deletedAt,
    revision,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'people';
  @override
  VerificationContext validateIntegrity(
    Insertable<PersonEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    }
    if (data.containsKey('address')) {
      context.handle(
        _addressMeta,
        address.isAcceptableOrUnknown(data['address']!, _addressMeta),
      );
    }
    if (data.containsKey('latitude')) {
      context.handle(
        _latitudeMeta,
        latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta),
      );
    }
    if (data.containsKey('longitude')) {
      context.handle(
        _longitudeMeta,
        longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta),
      );
    }
    if (data.containsKey('first_contact_at')) {
      context.handle(
        _firstContactAtMeta,
        firstContactAt.isAcceptableOrUnknown(
          data['first_contact_at']!,
          _firstContactAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_firstContactAtMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('preferred_schedule')) {
      context.handle(
        _preferredScheduleMeta,
        preferredSchedule.isAcceptableOrUnknown(
          data['preferred_schedule']!,
          _preferredScheduleMeta,
        ),
      );
    }
    if (data.containsKey('general_notes')) {
      context.handle(
        _generalNotesMeta,
        generalNotes.isAcceptableOrUnknown(
          data['general_notes']!,
          _generalNotesMeta,
        ),
      );
    }
    if (data.containsKey('contact_restrictions')) {
      context.handle(
        _contactRestrictionsMeta,
        contactRestrictions.isAcceptableOrUnknown(
          data['contact_restrictions']!,
          _contactRestrictionsMeta,
        ),
      );
    }
    if (data.containsKey('tags')) {
      context.handle(
        _tagsMeta,
        tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta),
      );
    }
    if (data.containsKey('last_contact_at')) {
      context.handle(
        _lastContactAtMeta,
        lastContactAt.isAcceptableOrUnknown(
          data['last_contact_at']!,
          _lastContactAtMeta,
        ),
      );
    }
    if (data.containsKey('next_action_at')) {
      context.handle(
        _nextActionAtMeta,
        nextActionAt.isAcceptableOrUnknown(
          data['next_action_at']!,
          _nextActionAtMeta,
        ),
      );
    }
    if (data.containsKey('next_action_note')) {
      context.handle(
        _nextActionNoteMeta,
        nextActionNote.isAcceptableOrUnknown(
          data['next_action_note']!,
          _nextActionNoteMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PersonEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PersonEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      ),
      address: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address'],
      ),
      latitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}latitude'],
      ),
      longitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}longitude'],
      ),
      firstContactAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}first_contact_at'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      preferredSchedule: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preferred_schedule'],
      ),
      generalNotes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}general_notes'],
      ),
      contactRestrictions: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}contact_restrictions'],
      ),
      tags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags'],
      )!,
      lastContactAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_contact_at'],
      ),
      nextActionAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_action_at'],
      ),
      nextActionNote: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}next_action_note'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
    );
  }

  @override
  $PeopleTable createAlias(String alias) {
    return $PeopleTable(attachedDatabase, alias);
  }
}

class PersonEntry extends DataClass implements Insertable<PersonEntry> {
  final String id;
  final String name;
  final String? phone;
  final String? address;
  final double? latitude;
  final double? longitude;
  final DateTime firstContactAt;
  final String status;
  final String? preferredSchedule;
  final String? generalNotes;
  final String? contactRestrictions;
  final String tags;
  final DateTime? lastContactAt;
  final DateTime? nextActionAt;
  final String? nextActionNote;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int revision;
  const PersonEntry({
    required this.id,
    required this.name,
    this.phone,
    this.address,
    this.latitude,
    this.longitude,
    required this.firstContactAt,
    required this.status,
    this.preferredSchedule,
    this.generalNotes,
    this.contactRestrictions,
    required this.tags,
    this.lastContactAt,
    this.nextActionAt,
    this.nextActionNote,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.revision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    if (!nullToAbsent || address != null) {
      map['address'] = Variable<String>(address);
    }
    if (!nullToAbsent || latitude != null) {
      map['latitude'] = Variable<double>(latitude);
    }
    if (!nullToAbsent || longitude != null) {
      map['longitude'] = Variable<double>(longitude);
    }
    map['first_contact_at'] = Variable<DateTime>(firstContactAt);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || preferredSchedule != null) {
      map['preferred_schedule'] = Variable<String>(preferredSchedule);
    }
    if (!nullToAbsent || generalNotes != null) {
      map['general_notes'] = Variable<String>(generalNotes);
    }
    if (!nullToAbsent || contactRestrictions != null) {
      map['contact_restrictions'] = Variable<String>(contactRestrictions);
    }
    map['tags'] = Variable<String>(tags);
    if (!nullToAbsent || lastContactAt != null) {
      map['last_contact_at'] = Variable<DateTime>(lastContactAt);
    }
    if (!nullToAbsent || nextActionAt != null) {
      map['next_action_at'] = Variable<DateTime>(nextActionAt);
    }
    if (!nullToAbsent || nextActionNote != null) {
      map['next_action_note'] = Variable<String>(nextActionNote);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['revision'] = Variable<int>(revision);
    return map;
  }

  PeopleCompanion toCompanion(bool nullToAbsent) {
    return PeopleCompanion(
      id: Value(id),
      name: Value(name),
      phone: phone == null && nullToAbsent
          ? const Value.absent()
          : Value(phone),
      address: address == null && nullToAbsent
          ? const Value.absent()
          : Value(address),
      latitude: latitude == null && nullToAbsent
          ? const Value.absent()
          : Value(latitude),
      longitude: longitude == null && nullToAbsent
          ? const Value.absent()
          : Value(longitude),
      firstContactAt: Value(firstContactAt),
      status: Value(status),
      preferredSchedule: preferredSchedule == null && nullToAbsent
          ? const Value.absent()
          : Value(preferredSchedule),
      generalNotes: generalNotes == null && nullToAbsent
          ? const Value.absent()
          : Value(generalNotes),
      contactRestrictions: contactRestrictions == null && nullToAbsent
          ? const Value.absent()
          : Value(contactRestrictions),
      tags: Value(tags),
      lastContactAt: lastContactAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastContactAt),
      nextActionAt: nextActionAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextActionAt),
      nextActionNote: nextActionNote == null && nullToAbsent
          ? const Value.absent()
          : Value(nextActionNote),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      revision: Value(revision),
    );
  }

  factory PersonEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PersonEntry(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      phone: serializer.fromJson<String?>(json['phone']),
      address: serializer.fromJson<String?>(json['address']),
      latitude: serializer.fromJson<double?>(json['latitude']),
      longitude: serializer.fromJson<double?>(json['longitude']),
      firstContactAt: serializer.fromJson<DateTime>(json['firstContactAt']),
      status: serializer.fromJson<String>(json['status']),
      preferredSchedule: serializer.fromJson<String?>(
        json['preferredSchedule'],
      ),
      generalNotes: serializer.fromJson<String?>(json['generalNotes']),
      contactRestrictions: serializer.fromJson<String?>(
        json['contactRestrictions'],
      ),
      tags: serializer.fromJson<String>(json['tags']),
      lastContactAt: serializer.fromJson<DateTime?>(json['lastContactAt']),
      nextActionAt: serializer.fromJson<DateTime?>(json['nextActionAt']),
      nextActionNote: serializer.fromJson<String?>(json['nextActionNote']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      revision: serializer.fromJson<int>(json['revision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'phone': serializer.toJson<String?>(phone),
      'address': serializer.toJson<String?>(address),
      'latitude': serializer.toJson<double?>(latitude),
      'longitude': serializer.toJson<double?>(longitude),
      'firstContactAt': serializer.toJson<DateTime>(firstContactAt),
      'status': serializer.toJson<String>(status),
      'preferredSchedule': serializer.toJson<String?>(preferredSchedule),
      'generalNotes': serializer.toJson<String?>(generalNotes),
      'contactRestrictions': serializer.toJson<String?>(contactRestrictions),
      'tags': serializer.toJson<String>(tags),
      'lastContactAt': serializer.toJson<DateTime?>(lastContactAt),
      'nextActionAt': serializer.toJson<DateTime?>(nextActionAt),
      'nextActionNote': serializer.toJson<String?>(nextActionNote),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'revision': serializer.toJson<int>(revision),
    };
  }

  PersonEntry copyWith({
    String? id,
    String? name,
    Value<String?> phone = const Value.absent(),
    Value<String?> address = const Value.absent(),
    Value<double?> latitude = const Value.absent(),
    Value<double?> longitude = const Value.absent(),
    DateTime? firstContactAt,
    String? status,
    Value<String?> preferredSchedule = const Value.absent(),
    Value<String?> generalNotes = const Value.absent(),
    Value<String?> contactRestrictions = const Value.absent(),
    String? tags,
    Value<DateTime?> lastContactAt = const Value.absent(),
    Value<DateTime?> nextActionAt = const Value.absent(),
    Value<String?> nextActionNote = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    int? revision,
  }) => PersonEntry(
    id: id ?? this.id,
    name: name ?? this.name,
    phone: phone.present ? phone.value : this.phone,
    address: address.present ? address.value : this.address,
    latitude: latitude.present ? latitude.value : this.latitude,
    longitude: longitude.present ? longitude.value : this.longitude,
    firstContactAt: firstContactAt ?? this.firstContactAt,
    status: status ?? this.status,
    preferredSchedule: preferredSchedule.present
        ? preferredSchedule.value
        : this.preferredSchedule,
    generalNotes: generalNotes.present ? generalNotes.value : this.generalNotes,
    contactRestrictions: contactRestrictions.present
        ? contactRestrictions.value
        : this.contactRestrictions,
    tags: tags ?? this.tags,
    lastContactAt: lastContactAt.present
        ? lastContactAt.value
        : this.lastContactAt,
    nextActionAt: nextActionAt.present ? nextActionAt.value : this.nextActionAt,
    nextActionNote: nextActionNote.present
        ? nextActionNote.value
        : this.nextActionNote,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    revision: revision ?? this.revision,
  );
  PersonEntry copyWithCompanion(PeopleCompanion data) {
    return PersonEntry(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      phone: data.phone.present ? data.phone.value : this.phone,
      address: data.address.present ? data.address.value : this.address,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      firstContactAt: data.firstContactAt.present
          ? data.firstContactAt.value
          : this.firstContactAt,
      status: data.status.present ? data.status.value : this.status,
      preferredSchedule: data.preferredSchedule.present
          ? data.preferredSchedule.value
          : this.preferredSchedule,
      generalNotes: data.generalNotes.present
          ? data.generalNotes.value
          : this.generalNotes,
      contactRestrictions: data.contactRestrictions.present
          ? data.contactRestrictions.value
          : this.contactRestrictions,
      tags: data.tags.present ? data.tags.value : this.tags,
      lastContactAt: data.lastContactAt.present
          ? data.lastContactAt.value
          : this.lastContactAt,
      nextActionAt: data.nextActionAt.present
          ? data.nextActionAt.value
          : this.nextActionAt,
      nextActionNote: data.nextActionNote.present
          ? data.nextActionNote.value
          : this.nextActionNote,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      revision: data.revision.present ? data.revision.value : this.revision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PersonEntry(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('phone: $phone, ')
          ..write('address: $address, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('firstContactAt: $firstContactAt, ')
          ..write('status: $status, ')
          ..write('preferredSchedule: $preferredSchedule, ')
          ..write('generalNotes: $generalNotes, ')
          ..write('contactRestrictions: $contactRestrictions, ')
          ..write('tags: $tags, ')
          ..write('lastContactAt: $lastContactAt, ')
          ..write('nextActionAt: $nextActionAt, ')
          ..write('nextActionNote: $nextActionNote, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    phone,
    address,
    latitude,
    longitude,
    firstContactAt,
    status,
    preferredSchedule,
    generalNotes,
    contactRestrictions,
    tags,
    lastContactAt,
    nextActionAt,
    nextActionNote,
    createdAt,
    updatedAt,
    deletedAt,
    revision,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PersonEntry &&
          other.id == this.id &&
          other.name == this.name &&
          other.phone == this.phone &&
          other.address == this.address &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.firstContactAt == this.firstContactAt &&
          other.status == this.status &&
          other.preferredSchedule == this.preferredSchedule &&
          other.generalNotes == this.generalNotes &&
          other.contactRestrictions == this.contactRestrictions &&
          other.tags == this.tags &&
          other.lastContactAt == this.lastContactAt &&
          other.nextActionAt == this.nextActionAt &&
          other.nextActionNote == this.nextActionNote &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.revision == this.revision);
}

class PeopleCompanion extends UpdateCompanion<PersonEntry> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> phone;
  final Value<String?> address;
  final Value<double?> latitude;
  final Value<double?> longitude;
  final Value<DateTime> firstContactAt;
  final Value<String> status;
  final Value<String?> preferredSchedule;
  final Value<String?> generalNotes;
  final Value<String?> contactRestrictions;
  final Value<String> tags;
  final Value<DateTime?> lastContactAt;
  final Value<DateTime?> nextActionAt;
  final Value<String?> nextActionNote;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> revision;
  final Value<int> rowid;
  const PeopleCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.phone = const Value.absent(),
    this.address = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.firstContactAt = const Value.absent(),
    this.status = const Value.absent(),
    this.preferredSchedule = const Value.absent(),
    this.generalNotes = const Value.absent(),
    this.contactRestrictions = const Value.absent(),
    this.tags = const Value.absent(),
    this.lastContactAt = const Value.absent(),
    this.nextActionAt = const Value.absent(),
    this.nextActionNote = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PeopleCompanion.insert({
    required String id,
    required String name,
    this.phone = const Value.absent(),
    this.address = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    required DateTime firstContactAt,
    this.status = const Value.absent(),
    this.preferredSchedule = const Value.absent(),
    this.generalNotes = const Value.absent(),
    this.contactRestrictions = const Value.absent(),
    this.tags = const Value.absent(),
    this.lastContactAt = const Value.absent(),
    this.nextActionAt = const Value.absent(),
    this.nextActionNote = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       firstContactAt = Value(firstContactAt),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<PersonEntry> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? phone,
    Expression<String>? address,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<DateTime>? firstContactAt,
    Expression<String>? status,
    Expression<String>? preferredSchedule,
    Expression<String>? generalNotes,
    Expression<String>? contactRestrictions,
    Expression<String>? tags,
    Expression<DateTime>? lastContactAt,
    Expression<DateTime>? nextActionAt,
    Expression<String>? nextActionNote,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? revision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (address != null) 'address': address,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (firstContactAt != null) 'first_contact_at': firstContactAt,
      if (status != null) 'status': status,
      if (preferredSchedule != null) 'preferred_schedule': preferredSchedule,
      if (generalNotes != null) 'general_notes': generalNotes,
      if (contactRestrictions != null)
        'contact_restrictions': contactRestrictions,
      if (tags != null) 'tags': tags,
      if (lastContactAt != null) 'last_contact_at': lastContactAt,
      if (nextActionAt != null) 'next_action_at': nextActionAt,
      if (nextActionNote != null) 'next_action_note': nextActionNote,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (revision != null) 'revision': revision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PeopleCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? phone,
    Value<String?>? address,
    Value<double?>? latitude,
    Value<double?>? longitude,
    Value<DateTime>? firstContactAt,
    Value<String>? status,
    Value<String?>? preferredSchedule,
    Value<String?>? generalNotes,
    Value<String?>? contactRestrictions,
    Value<String>? tags,
    Value<DateTime?>? lastContactAt,
    Value<DateTime?>? nextActionAt,
    Value<String?>? nextActionNote,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? revision,
    Value<int>? rowid,
  }) {
    return PeopleCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      firstContactAt: firstContactAt ?? this.firstContactAt,
      status: status ?? this.status,
      preferredSchedule: preferredSchedule ?? this.preferredSchedule,
      generalNotes: generalNotes ?? this.generalNotes,
      contactRestrictions: contactRestrictions ?? this.contactRestrictions,
      tags: tags ?? this.tags,
      lastContactAt: lastContactAt ?? this.lastContactAt,
      nextActionAt: nextActionAt ?? this.nextActionAt,
      nextActionNote: nextActionNote ?? this.nextActionNote,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      revision: revision ?? this.revision,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (firstContactAt.present) {
      map['first_contact_at'] = Variable<DateTime>(firstContactAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (preferredSchedule.present) {
      map['preferred_schedule'] = Variable<String>(preferredSchedule.value);
    }
    if (generalNotes.present) {
      map['general_notes'] = Variable<String>(generalNotes.value);
    }
    if (contactRestrictions.present) {
      map['contact_restrictions'] = Variable<String>(contactRestrictions.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (lastContactAt.present) {
      map['last_contact_at'] = Variable<DateTime>(lastContactAt.value);
    }
    if (nextActionAt.present) {
      map['next_action_at'] = Variable<DateTime>(nextActionAt.value);
    }
    if (nextActionNote.present) {
      map['next_action_note'] = Variable<String>(nextActionNote.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PeopleCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('phone: $phone, ')
          ..write('address: $address, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('firstContactAt: $firstContactAt, ')
          ..write('status: $status, ')
          ..write('preferredSchedule: $preferredSchedule, ')
          ..write('generalNotes: $generalNotes, ')
          ..write('contactRestrictions: $contactRestrictions, ')
          ..write('tags: $tags, ')
          ..write('lastContactAt: $lastContactAt, ')
          ..write('nextActionAt: $nextActionAt, ')
          ..write('nextActionNote: $nextActionNote, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $VisitsTable extends Visits with TableInfo<$VisitsTable, VisitEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VisitsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _personIdMeta = const VerificationMeta(
    'personId',
  );
  @override
  late final GeneratedColumn<String> personId = GeneratedColumn<String>(
    'person_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES people (id)',
    ),
  );
  static const VerificationMeta _dateTimeFieldMeta = const VerificationMeta(
    'dateTimeField',
  );
  @override
  late final GeneratedColumn<DateTime> dateTimeField =
      GeneratedColumn<DateTime>(
        'date_time_field',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _contactTypeMeta = const VerificationMeta(
    'contactType',
  );
  @override
  late final GeneratedColumn<String> contactType = GeneratedColumn<String>(
    'contact_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resultMeta = const VerificationMeta('result');
  @override
  late final GeneratedColumn<String> result = GeneratedColumn<String>(
    'result',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _topicsDiscussedMeta = const VerificationMeta(
    'topicsDiscussed',
  );
  @override
  late final GeneratedColumn<String> topicsDiscussed = GeneratedColumn<String>(
    'topics_discussed',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scriptureOrPubMeta = const VerificationMeta(
    'scriptureOrPub',
  );
  @override
  late final GeneratedColumn<String> scriptureOrPub = GeneratedColumn<String>(
    'scripture_or_pub',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _expressedQuestionMeta = const VerificationMeta(
    'expressedQuestion',
  );
  @override
  late final GeneratedColumn<String> expressedQuestion =
      GeneratedColumn<String>(
        'expressed_question',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _nextStepMeta = const VerificationMeta(
    'nextStep',
  );
  @override
  late final GeneratedColumn<String> nextStep = GeneratedColumn<String>(
    'next_step',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _suggestedReturnDateMeta =
      const VerificationMeta('suggestedReturnDate');
  @override
  late final GeneratedColumn<DateTime> suggestedReturnDate =
      GeneratedColumn<DateTime>(
        'suggested_return_date',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _appointmentIdMeta = const VerificationMeta(
    'appointmentId',
  );
  @override
  late final GeneratedColumn<String> appointmentId = GeneratedColumn<String>(
    'appointment_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    personId,
    dateTimeField,
    contactType,
    result,
    notes,
    topicsDiscussed,
    scriptureOrPub,
    expressedQuestion,
    nextStep,
    suggestedReturnDate,
    appointmentId,
    createdAt,
    updatedAt,
    deletedAt,
    revision,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'visits';
  @override
  VerificationContext validateIntegrity(
    Insertable<VisitEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('person_id')) {
      context.handle(
        _personIdMeta,
        personId.isAcceptableOrUnknown(data['person_id']!, _personIdMeta),
      );
    } else if (isInserting) {
      context.missing(_personIdMeta);
    }
    if (data.containsKey('date_time_field')) {
      context.handle(
        _dateTimeFieldMeta,
        dateTimeField.isAcceptableOrUnknown(
          data['date_time_field']!,
          _dateTimeFieldMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dateTimeFieldMeta);
    }
    if (data.containsKey('contact_type')) {
      context.handle(
        _contactTypeMeta,
        contactType.isAcceptableOrUnknown(
          data['contact_type']!,
          _contactTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contactTypeMeta);
    }
    if (data.containsKey('result')) {
      context.handle(
        _resultMeta,
        result.isAcceptableOrUnknown(data['result']!, _resultMeta),
      );
    } else if (isInserting) {
      context.missing(_resultMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('topics_discussed')) {
      context.handle(
        _topicsDiscussedMeta,
        topicsDiscussed.isAcceptableOrUnknown(
          data['topics_discussed']!,
          _topicsDiscussedMeta,
        ),
      );
    }
    if (data.containsKey('scripture_or_pub')) {
      context.handle(
        _scriptureOrPubMeta,
        scriptureOrPub.isAcceptableOrUnknown(
          data['scripture_or_pub']!,
          _scriptureOrPubMeta,
        ),
      );
    }
    if (data.containsKey('expressed_question')) {
      context.handle(
        _expressedQuestionMeta,
        expressedQuestion.isAcceptableOrUnknown(
          data['expressed_question']!,
          _expressedQuestionMeta,
        ),
      );
    }
    if (data.containsKey('next_step')) {
      context.handle(
        _nextStepMeta,
        nextStep.isAcceptableOrUnknown(data['next_step']!, _nextStepMeta),
      );
    }
    if (data.containsKey('suggested_return_date')) {
      context.handle(
        _suggestedReturnDateMeta,
        suggestedReturnDate.isAcceptableOrUnknown(
          data['suggested_return_date']!,
          _suggestedReturnDateMeta,
        ),
      );
    }
    if (data.containsKey('appointment_id')) {
      context.handle(
        _appointmentIdMeta,
        appointmentId.isAcceptableOrUnknown(
          data['appointment_id']!,
          _appointmentIdMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VisitEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VisitEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      personId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}person_id'],
      )!,
      dateTimeField: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date_time_field'],
      )!,
      contactType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}contact_type'],
      )!,
      result: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}result'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      topicsDiscussed: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}topics_discussed'],
      ),
      scriptureOrPub: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scripture_or_pub'],
      ),
      expressedQuestion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}expressed_question'],
      ),
      nextStep: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}next_step'],
      ),
      suggestedReturnDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}suggested_return_date'],
      ),
      appointmentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}appointment_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
    );
  }

  @override
  $VisitsTable createAlias(String alias) {
    return $VisitsTable(attachedDatabase, alias);
  }
}

class VisitEntry extends DataClass implements Insertable<VisitEntry> {
  final String id;
  final String personId;
  final DateTime dateTimeField;
  final String contactType;
  final String result;
  final String? notes;
  final String? topicsDiscussed;
  final String? scriptureOrPub;
  final String? expressedQuestion;
  final String? nextStep;
  final DateTime? suggestedReturnDate;
  final String? appointmentId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int revision;
  const VisitEntry({
    required this.id,
    required this.personId,
    required this.dateTimeField,
    required this.contactType,
    required this.result,
    this.notes,
    this.topicsDiscussed,
    this.scriptureOrPub,
    this.expressedQuestion,
    this.nextStep,
    this.suggestedReturnDate,
    this.appointmentId,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.revision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['person_id'] = Variable<String>(personId);
    map['date_time_field'] = Variable<DateTime>(dateTimeField);
    map['contact_type'] = Variable<String>(contactType);
    map['result'] = Variable<String>(result);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || topicsDiscussed != null) {
      map['topics_discussed'] = Variable<String>(topicsDiscussed);
    }
    if (!nullToAbsent || scriptureOrPub != null) {
      map['scripture_or_pub'] = Variable<String>(scriptureOrPub);
    }
    if (!nullToAbsent || expressedQuestion != null) {
      map['expressed_question'] = Variable<String>(expressedQuestion);
    }
    if (!nullToAbsent || nextStep != null) {
      map['next_step'] = Variable<String>(nextStep);
    }
    if (!nullToAbsent || suggestedReturnDate != null) {
      map['suggested_return_date'] = Variable<DateTime>(suggestedReturnDate);
    }
    if (!nullToAbsent || appointmentId != null) {
      map['appointment_id'] = Variable<String>(appointmentId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['revision'] = Variable<int>(revision);
    return map;
  }

  VisitsCompanion toCompanion(bool nullToAbsent) {
    return VisitsCompanion(
      id: Value(id),
      personId: Value(personId),
      dateTimeField: Value(dateTimeField),
      contactType: Value(contactType),
      result: Value(result),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      topicsDiscussed: topicsDiscussed == null && nullToAbsent
          ? const Value.absent()
          : Value(topicsDiscussed),
      scriptureOrPub: scriptureOrPub == null && nullToAbsent
          ? const Value.absent()
          : Value(scriptureOrPub),
      expressedQuestion: expressedQuestion == null && nullToAbsent
          ? const Value.absent()
          : Value(expressedQuestion),
      nextStep: nextStep == null && nullToAbsent
          ? const Value.absent()
          : Value(nextStep),
      suggestedReturnDate: suggestedReturnDate == null && nullToAbsent
          ? const Value.absent()
          : Value(suggestedReturnDate),
      appointmentId: appointmentId == null && nullToAbsent
          ? const Value.absent()
          : Value(appointmentId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      revision: Value(revision),
    );
  }

  factory VisitEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VisitEntry(
      id: serializer.fromJson<String>(json['id']),
      personId: serializer.fromJson<String>(json['personId']),
      dateTimeField: serializer.fromJson<DateTime>(json['dateTimeField']),
      contactType: serializer.fromJson<String>(json['contactType']),
      result: serializer.fromJson<String>(json['result']),
      notes: serializer.fromJson<String?>(json['notes']),
      topicsDiscussed: serializer.fromJson<String?>(json['topicsDiscussed']),
      scriptureOrPub: serializer.fromJson<String?>(json['scriptureOrPub']),
      expressedQuestion: serializer.fromJson<String?>(
        json['expressedQuestion'],
      ),
      nextStep: serializer.fromJson<String?>(json['nextStep']),
      suggestedReturnDate: serializer.fromJson<DateTime?>(
        json['suggestedReturnDate'],
      ),
      appointmentId: serializer.fromJson<String?>(json['appointmentId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      revision: serializer.fromJson<int>(json['revision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'personId': serializer.toJson<String>(personId),
      'dateTimeField': serializer.toJson<DateTime>(dateTimeField),
      'contactType': serializer.toJson<String>(contactType),
      'result': serializer.toJson<String>(result),
      'notes': serializer.toJson<String?>(notes),
      'topicsDiscussed': serializer.toJson<String?>(topicsDiscussed),
      'scriptureOrPub': serializer.toJson<String?>(scriptureOrPub),
      'expressedQuestion': serializer.toJson<String?>(expressedQuestion),
      'nextStep': serializer.toJson<String?>(nextStep),
      'suggestedReturnDate': serializer.toJson<DateTime?>(suggestedReturnDate),
      'appointmentId': serializer.toJson<String?>(appointmentId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'revision': serializer.toJson<int>(revision),
    };
  }

  VisitEntry copyWith({
    String? id,
    String? personId,
    DateTime? dateTimeField,
    String? contactType,
    String? result,
    Value<String?> notes = const Value.absent(),
    Value<String?> topicsDiscussed = const Value.absent(),
    Value<String?> scriptureOrPub = const Value.absent(),
    Value<String?> expressedQuestion = const Value.absent(),
    Value<String?> nextStep = const Value.absent(),
    Value<DateTime?> suggestedReturnDate = const Value.absent(),
    Value<String?> appointmentId = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    int? revision,
  }) => VisitEntry(
    id: id ?? this.id,
    personId: personId ?? this.personId,
    dateTimeField: dateTimeField ?? this.dateTimeField,
    contactType: contactType ?? this.contactType,
    result: result ?? this.result,
    notes: notes.present ? notes.value : this.notes,
    topicsDiscussed: topicsDiscussed.present
        ? topicsDiscussed.value
        : this.topicsDiscussed,
    scriptureOrPub: scriptureOrPub.present
        ? scriptureOrPub.value
        : this.scriptureOrPub,
    expressedQuestion: expressedQuestion.present
        ? expressedQuestion.value
        : this.expressedQuestion,
    nextStep: nextStep.present ? nextStep.value : this.nextStep,
    suggestedReturnDate: suggestedReturnDate.present
        ? suggestedReturnDate.value
        : this.suggestedReturnDate,
    appointmentId: appointmentId.present
        ? appointmentId.value
        : this.appointmentId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    revision: revision ?? this.revision,
  );
  VisitEntry copyWithCompanion(VisitsCompanion data) {
    return VisitEntry(
      id: data.id.present ? data.id.value : this.id,
      personId: data.personId.present ? data.personId.value : this.personId,
      dateTimeField: data.dateTimeField.present
          ? data.dateTimeField.value
          : this.dateTimeField,
      contactType: data.contactType.present
          ? data.contactType.value
          : this.contactType,
      result: data.result.present ? data.result.value : this.result,
      notes: data.notes.present ? data.notes.value : this.notes,
      topicsDiscussed: data.topicsDiscussed.present
          ? data.topicsDiscussed.value
          : this.topicsDiscussed,
      scriptureOrPub: data.scriptureOrPub.present
          ? data.scriptureOrPub.value
          : this.scriptureOrPub,
      expressedQuestion: data.expressedQuestion.present
          ? data.expressedQuestion.value
          : this.expressedQuestion,
      nextStep: data.nextStep.present ? data.nextStep.value : this.nextStep,
      suggestedReturnDate: data.suggestedReturnDate.present
          ? data.suggestedReturnDate.value
          : this.suggestedReturnDate,
      appointmentId: data.appointmentId.present
          ? data.appointmentId.value
          : this.appointmentId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      revision: data.revision.present ? data.revision.value : this.revision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VisitEntry(')
          ..write('id: $id, ')
          ..write('personId: $personId, ')
          ..write('dateTimeField: $dateTimeField, ')
          ..write('contactType: $contactType, ')
          ..write('result: $result, ')
          ..write('notes: $notes, ')
          ..write('topicsDiscussed: $topicsDiscussed, ')
          ..write('scriptureOrPub: $scriptureOrPub, ')
          ..write('expressedQuestion: $expressedQuestion, ')
          ..write('nextStep: $nextStep, ')
          ..write('suggestedReturnDate: $suggestedReturnDate, ')
          ..write('appointmentId: $appointmentId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    personId,
    dateTimeField,
    contactType,
    result,
    notes,
    topicsDiscussed,
    scriptureOrPub,
    expressedQuestion,
    nextStep,
    suggestedReturnDate,
    appointmentId,
    createdAt,
    updatedAt,
    deletedAt,
    revision,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VisitEntry &&
          other.id == this.id &&
          other.personId == this.personId &&
          other.dateTimeField == this.dateTimeField &&
          other.contactType == this.contactType &&
          other.result == this.result &&
          other.notes == this.notes &&
          other.topicsDiscussed == this.topicsDiscussed &&
          other.scriptureOrPub == this.scriptureOrPub &&
          other.expressedQuestion == this.expressedQuestion &&
          other.nextStep == this.nextStep &&
          other.suggestedReturnDate == this.suggestedReturnDate &&
          other.appointmentId == this.appointmentId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.revision == this.revision);
}

class VisitsCompanion extends UpdateCompanion<VisitEntry> {
  final Value<String> id;
  final Value<String> personId;
  final Value<DateTime> dateTimeField;
  final Value<String> contactType;
  final Value<String> result;
  final Value<String?> notes;
  final Value<String?> topicsDiscussed;
  final Value<String?> scriptureOrPub;
  final Value<String?> expressedQuestion;
  final Value<String?> nextStep;
  final Value<DateTime?> suggestedReturnDate;
  final Value<String?> appointmentId;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> revision;
  final Value<int> rowid;
  const VisitsCompanion({
    this.id = const Value.absent(),
    this.personId = const Value.absent(),
    this.dateTimeField = const Value.absent(),
    this.contactType = const Value.absent(),
    this.result = const Value.absent(),
    this.notes = const Value.absent(),
    this.topicsDiscussed = const Value.absent(),
    this.scriptureOrPub = const Value.absent(),
    this.expressedQuestion = const Value.absent(),
    this.nextStep = const Value.absent(),
    this.suggestedReturnDate = const Value.absent(),
    this.appointmentId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VisitsCompanion.insert({
    required String id,
    required String personId,
    required DateTime dateTimeField,
    required String contactType,
    required String result,
    this.notes = const Value.absent(),
    this.topicsDiscussed = const Value.absent(),
    this.scriptureOrPub = const Value.absent(),
    this.expressedQuestion = const Value.absent(),
    this.nextStep = const Value.absent(),
    this.suggestedReturnDate = const Value.absent(),
    this.appointmentId = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       personId = Value(personId),
       dateTimeField = Value(dateTimeField),
       contactType = Value(contactType),
       result = Value(result),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<VisitEntry> custom({
    Expression<String>? id,
    Expression<String>? personId,
    Expression<DateTime>? dateTimeField,
    Expression<String>? contactType,
    Expression<String>? result,
    Expression<String>? notes,
    Expression<String>? topicsDiscussed,
    Expression<String>? scriptureOrPub,
    Expression<String>? expressedQuestion,
    Expression<String>? nextStep,
    Expression<DateTime>? suggestedReturnDate,
    Expression<String>? appointmentId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? revision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (personId != null) 'person_id': personId,
      if (dateTimeField != null) 'date_time_field': dateTimeField,
      if (contactType != null) 'contact_type': contactType,
      if (result != null) 'result': result,
      if (notes != null) 'notes': notes,
      if (topicsDiscussed != null) 'topics_discussed': topicsDiscussed,
      if (scriptureOrPub != null) 'scripture_or_pub': scriptureOrPub,
      if (expressedQuestion != null) 'expressed_question': expressedQuestion,
      if (nextStep != null) 'next_step': nextStep,
      if (suggestedReturnDate != null)
        'suggested_return_date': suggestedReturnDate,
      if (appointmentId != null) 'appointment_id': appointmentId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (revision != null) 'revision': revision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VisitsCompanion copyWith({
    Value<String>? id,
    Value<String>? personId,
    Value<DateTime>? dateTimeField,
    Value<String>? contactType,
    Value<String>? result,
    Value<String?>? notes,
    Value<String?>? topicsDiscussed,
    Value<String?>? scriptureOrPub,
    Value<String?>? expressedQuestion,
    Value<String?>? nextStep,
    Value<DateTime?>? suggestedReturnDate,
    Value<String?>? appointmentId,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? revision,
    Value<int>? rowid,
  }) {
    return VisitsCompanion(
      id: id ?? this.id,
      personId: personId ?? this.personId,
      dateTimeField: dateTimeField ?? this.dateTimeField,
      contactType: contactType ?? this.contactType,
      result: result ?? this.result,
      notes: notes ?? this.notes,
      topicsDiscussed: topicsDiscussed ?? this.topicsDiscussed,
      scriptureOrPub: scriptureOrPub ?? this.scriptureOrPub,
      expressedQuestion: expressedQuestion ?? this.expressedQuestion,
      nextStep: nextStep ?? this.nextStep,
      suggestedReturnDate: suggestedReturnDate ?? this.suggestedReturnDate,
      appointmentId: appointmentId ?? this.appointmentId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      revision: revision ?? this.revision,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (personId.present) {
      map['person_id'] = Variable<String>(personId.value);
    }
    if (dateTimeField.present) {
      map['date_time_field'] = Variable<DateTime>(dateTimeField.value);
    }
    if (contactType.present) {
      map['contact_type'] = Variable<String>(contactType.value);
    }
    if (result.present) {
      map['result'] = Variable<String>(result.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (topicsDiscussed.present) {
      map['topics_discussed'] = Variable<String>(topicsDiscussed.value);
    }
    if (scriptureOrPub.present) {
      map['scripture_or_pub'] = Variable<String>(scriptureOrPub.value);
    }
    if (expressedQuestion.present) {
      map['expressed_question'] = Variable<String>(expressedQuestion.value);
    }
    if (nextStep.present) {
      map['next_step'] = Variable<String>(nextStep.value);
    }
    if (suggestedReturnDate.present) {
      map['suggested_return_date'] = Variable<DateTime>(
        suggestedReturnDate.value,
      );
    }
    if (appointmentId.present) {
      map['appointment_id'] = Variable<String>(appointmentId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VisitsCompanion(')
          ..write('id: $id, ')
          ..write('personId: $personId, ')
          ..write('dateTimeField: $dateTimeField, ')
          ..write('contactType: $contactType, ')
          ..write('result: $result, ')
          ..write('notes: $notes, ')
          ..write('topicsDiscussed: $topicsDiscussed, ')
          ..write('scriptureOrPub: $scriptureOrPub, ')
          ..write('expressedQuestion: $expressedQuestion, ')
          ..write('nextStep: $nextStep, ')
          ..write('suggestedReturnDate: $suggestedReturnDate, ')
          ..write('appointmentId: $appointmentId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BibleStudiesTable extends BibleStudies
    with TableInfo<$BibleStudiesTable, BibleStudyEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BibleStudiesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('local_user'),
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('ativo'),
  );
  static const VerificationMeta _publicationIdMeta = const VerificationMeta(
    'publicationId',
  );
  @override
  late final GeneratedColumn<String> publicationId = GeneratedColumn<String>(
    'publication_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _languageMeta = const VerificationMeta(
    'language',
  );
  @override
  late final GeneratedColumn<String> language = GeneratedColumn<String>(
    'language',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pt'),
  );
  static const VerificationMeta _currentLessonMeta = const VerificationMeta(
    'currentLesson',
  );
  @override
  late final GeneratedColumn<int> currentLesson = GeneratedColumn<int>(
    'current_lesson',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _currentParagraphMeta = const VerificationMeta(
    'currentParagraph',
  );
  @override
  late final GeneratedColumn<int> currentParagraph = GeneratedColumn<int>(
    'current_paragraph',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _manualReferenceMeta = const VerificationMeta(
    'manualReference',
  );
  @override
  late final GeneratedColumn<String> manualReference = GeneratedColumn<String>(
    'manual_reference',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _frequencyMeta = const VerificationMeta(
    'frequency',
  );
  @override
  late final GeneratedColumn<String> frequency = GeneratedColumn<String>(
    'frequency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('semanal'),
  );
  static const VerificationMeta _learningGoalsMeta = const VerificationMeta(
    'learningGoals',
  );
  @override
  late final GeneratedColumn<String> learningGoals = GeneratedColumn<String>(
    'learning_goals',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pendingDoubtsMeta = const VerificationMeta(
    'pendingDoubts',
  );
  @override
  late final GeneratedColumn<String> pendingDoubts = GeneratedColumn<String>(
    'pending_doubts',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nextTopicMeta = const VerificationMeta(
    'nextTopic',
  );
  @override
  late final GeneratedColumn<String> nextTopic = GeneratedColumn<String>(
    'next_topic',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pauseOrCloseReasonMeta =
      const VerificationMeta('pauseOrCloseReason');
  @override
  late final GeneratedColumn<String> pauseOrCloseReason =
      GeneratedColumn<String>(
        'pause_or_close_reason',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastSessionAtMeta = const VerificationMeta(
    'lastSessionAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSessionAt =
      GeneratedColumn<DateTime>(
        'last_session_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _nextPlannedAtMeta = const VerificationMeta(
    'nextPlannedAt',
  );
  @override
  late final GeneratedColumn<DateTime> nextPlannedAt =
      GeneratedColumn<DateTime>(
        'next_planned_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    ownerId,
    startedAt,
    status,
    publicationId,
    language,
    currentLesson,
    currentParagraph,
    manualReference,
    frequency,
    learningGoals,
    pendingDoubts,
    nextTopic,
    pauseOrCloseReason,
    lastSessionAt,
    nextPlannedAt,
    createdAt,
    updatedAt,
    deletedAt,
    revision,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bible_studies';
  @override
  VerificationContext validateIntegrity(
    Insertable<BibleStudyEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('publication_id')) {
      context.handle(
        _publicationIdMeta,
        publicationId.isAcceptableOrUnknown(
          data['publication_id']!,
          _publicationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_publicationIdMeta);
    }
    if (data.containsKey('language')) {
      context.handle(
        _languageMeta,
        language.isAcceptableOrUnknown(data['language']!, _languageMeta),
      );
    }
    if (data.containsKey('current_lesson')) {
      context.handle(
        _currentLessonMeta,
        currentLesson.isAcceptableOrUnknown(
          data['current_lesson']!,
          _currentLessonMeta,
        ),
      );
    }
    if (data.containsKey('current_paragraph')) {
      context.handle(
        _currentParagraphMeta,
        currentParagraph.isAcceptableOrUnknown(
          data['current_paragraph']!,
          _currentParagraphMeta,
        ),
      );
    }
    if (data.containsKey('manual_reference')) {
      context.handle(
        _manualReferenceMeta,
        manualReference.isAcceptableOrUnknown(
          data['manual_reference']!,
          _manualReferenceMeta,
        ),
      );
    }
    if (data.containsKey('frequency')) {
      context.handle(
        _frequencyMeta,
        frequency.isAcceptableOrUnknown(data['frequency']!, _frequencyMeta),
      );
    }
    if (data.containsKey('learning_goals')) {
      context.handle(
        _learningGoalsMeta,
        learningGoals.isAcceptableOrUnknown(
          data['learning_goals']!,
          _learningGoalsMeta,
        ),
      );
    }
    if (data.containsKey('pending_doubts')) {
      context.handle(
        _pendingDoubtsMeta,
        pendingDoubts.isAcceptableOrUnknown(
          data['pending_doubts']!,
          _pendingDoubtsMeta,
        ),
      );
    }
    if (data.containsKey('next_topic')) {
      context.handle(
        _nextTopicMeta,
        nextTopic.isAcceptableOrUnknown(data['next_topic']!, _nextTopicMeta),
      );
    }
    if (data.containsKey('pause_or_close_reason')) {
      context.handle(
        _pauseOrCloseReasonMeta,
        pauseOrCloseReason.isAcceptableOrUnknown(
          data['pause_or_close_reason']!,
          _pauseOrCloseReasonMeta,
        ),
      );
    }
    if (data.containsKey('last_session_at')) {
      context.handle(
        _lastSessionAtMeta,
        lastSessionAt.isAcceptableOrUnknown(
          data['last_session_at']!,
          _lastSessionAtMeta,
        ),
      );
    }
    if (data.containsKey('next_planned_at')) {
      context.handle(
        _nextPlannedAtMeta,
        nextPlannedAt.isAcceptableOrUnknown(
          data['next_planned_at']!,
          _nextPlannedAtMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BibleStudyEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BibleStudyEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      publicationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}publication_id'],
      )!,
      language: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language'],
      )!,
      currentLesson: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current_lesson'],
      ),
      currentParagraph: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current_paragraph'],
      ),
      manualReference: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}manual_reference'],
      ),
      frequency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}frequency'],
      )!,
      learningGoals: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}learning_goals'],
      ),
      pendingDoubts: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pending_doubts'],
      ),
      nextTopic: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}next_topic'],
      ),
      pauseOrCloseReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pause_or_close_reason'],
      ),
      lastSessionAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_session_at'],
      ),
      nextPlannedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_planned_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
    );
  }

  @override
  $BibleStudiesTable createAlias(String alias) {
    return $BibleStudiesTable(attachedDatabase, alias);
  }
}

class BibleStudyEntry extends DataClass implements Insertable<BibleStudyEntry> {
  final String id;
  final String title;
  final String ownerId;
  final DateTime startedAt;
  final String status;
  final String publicationId;
  final String language;
  final int? currentLesson;
  final int? currentParagraph;
  final String? manualReference;
  final String frequency;
  final String? learningGoals;
  final String? pendingDoubts;
  final String? nextTopic;
  final String? pauseOrCloseReason;
  final DateTime? lastSessionAt;
  final DateTime? nextPlannedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int revision;
  const BibleStudyEntry({
    required this.id,
    required this.title,
    required this.ownerId,
    required this.startedAt,
    required this.status,
    required this.publicationId,
    required this.language,
    this.currentLesson,
    this.currentParagraph,
    this.manualReference,
    required this.frequency,
    this.learningGoals,
    this.pendingDoubts,
    this.nextTopic,
    this.pauseOrCloseReason,
    this.lastSessionAt,
    this.nextPlannedAt,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.revision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['owner_id'] = Variable<String>(ownerId);
    map['started_at'] = Variable<DateTime>(startedAt);
    map['status'] = Variable<String>(status);
    map['publication_id'] = Variable<String>(publicationId);
    map['language'] = Variable<String>(language);
    if (!nullToAbsent || currentLesson != null) {
      map['current_lesson'] = Variable<int>(currentLesson);
    }
    if (!nullToAbsent || currentParagraph != null) {
      map['current_paragraph'] = Variable<int>(currentParagraph);
    }
    if (!nullToAbsent || manualReference != null) {
      map['manual_reference'] = Variable<String>(manualReference);
    }
    map['frequency'] = Variable<String>(frequency);
    if (!nullToAbsent || learningGoals != null) {
      map['learning_goals'] = Variable<String>(learningGoals);
    }
    if (!nullToAbsent || pendingDoubts != null) {
      map['pending_doubts'] = Variable<String>(pendingDoubts);
    }
    if (!nullToAbsent || nextTopic != null) {
      map['next_topic'] = Variable<String>(nextTopic);
    }
    if (!nullToAbsent || pauseOrCloseReason != null) {
      map['pause_or_close_reason'] = Variable<String>(pauseOrCloseReason);
    }
    if (!nullToAbsent || lastSessionAt != null) {
      map['last_session_at'] = Variable<DateTime>(lastSessionAt);
    }
    if (!nullToAbsent || nextPlannedAt != null) {
      map['next_planned_at'] = Variable<DateTime>(nextPlannedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['revision'] = Variable<int>(revision);
    return map;
  }

  BibleStudiesCompanion toCompanion(bool nullToAbsent) {
    return BibleStudiesCompanion(
      id: Value(id),
      title: Value(title),
      ownerId: Value(ownerId),
      startedAt: Value(startedAt),
      status: Value(status),
      publicationId: Value(publicationId),
      language: Value(language),
      currentLesson: currentLesson == null && nullToAbsent
          ? const Value.absent()
          : Value(currentLesson),
      currentParagraph: currentParagraph == null && nullToAbsent
          ? const Value.absent()
          : Value(currentParagraph),
      manualReference: manualReference == null && nullToAbsent
          ? const Value.absent()
          : Value(manualReference),
      frequency: Value(frequency),
      learningGoals: learningGoals == null && nullToAbsent
          ? const Value.absent()
          : Value(learningGoals),
      pendingDoubts: pendingDoubts == null && nullToAbsent
          ? const Value.absent()
          : Value(pendingDoubts),
      nextTopic: nextTopic == null && nullToAbsent
          ? const Value.absent()
          : Value(nextTopic),
      pauseOrCloseReason: pauseOrCloseReason == null && nullToAbsent
          ? const Value.absent()
          : Value(pauseOrCloseReason),
      lastSessionAt: lastSessionAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSessionAt),
      nextPlannedAt: nextPlannedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextPlannedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      revision: Value(revision),
    );
  }

  factory BibleStudyEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BibleStudyEntry(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      ownerId: serializer.fromJson<String>(json['ownerId']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      status: serializer.fromJson<String>(json['status']),
      publicationId: serializer.fromJson<String>(json['publicationId']),
      language: serializer.fromJson<String>(json['language']),
      currentLesson: serializer.fromJson<int?>(json['currentLesson']),
      currentParagraph: serializer.fromJson<int?>(json['currentParagraph']),
      manualReference: serializer.fromJson<String?>(json['manualReference']),
      frequency: serializer.fromJson<String>(json['frequency']),
      learningGoals: serializer.fromJson<String?>(json['learningGoals']),
      pendingDoubts: serializer.fromJson<String?>(json['pendingDoubts']),
      nextTopic: serializer.fromJson<String?>(json['nextTopic']),
      pauseOrCloseReason: serializer.fromJson<String?>(
        json['pauseOrCloseReason'],
      ),
      lastSessionAt: serializer.fromJson<DateTime?>(json['lastSessionAt']),
      nextPlannedAt: serializer.fromJson<DateTime?>(json['nextPlannedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      revision: serializer.fromJson<int>(json['revision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'ownerId': serializer.toJson<String>(ownerId),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'status': serializer.toJson<String>(status),
      'publicationId': serializer.toJson<String>(publicationId),
      'language': serializer.toJson<String>(language),
      'currentLesson': serializer.toJson<int?>(currentLesson),
      'currentParagraph': serializer.toJson<int?>(currentParagraph),
      'manualReference': serializer.toJson<String?>(manualReference),
      'frequency': serializer.toJson<String>(frequency),
      'learningGoals': serializer.toJson<String?>(learningGoals),
      'pendingDoubts': serializer.toJson<String?>(pendingDoubts),
      'nextTopic': serializer.toJson<String?>(nextTopic),
      'pauseOrCloseReason': serializer.toJson<String?>(pauseOrCloseReason),
      'lastSessionAt': serializer.toJson<DateTime?>(lastSessionAt),
      'nextPlannedAt': serializer.toJson<DateTime?>(nextPlannedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'revision': serializer.toJson<int>(revision),
    };
  }

  BibleStudyEntry copyWith({
    String? id,
    String? title,
    String? ownerId,
    DateTime? startedAt,
    String? status,
    String? publicationId,
    String? language,
    Value<int?> currentLesson = const Value.absent(),
    Value<int?> currentParagraph = const Value.absent(),
    Value<String?> manualReference = const Value.absent(),
    String? frequency,
    Value<String?> learningGoals = const Value.absent(),
    Value<String?> pendingDoubts = const Value.absent(),
    Value<String?> nextTopic = const Value.absent(),
    Value<String?> pauseOrCloseReason = const Value.absent(),
    Value<DateTime?> lastSessionAt = const Value.absent(),
    Value<DateTime?> nextPlannedAt = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    int? revision,
  }) => BibleStudyEntry(
    id: id ?? this.id,
    title: title ?? this.title,
    ownerId: ownerId ?? this.ownerId,
    startedAt: startedAt ?? this.startedAt,
    status: status ?? this.status,
    publicationId: publicationId ?? this.publicationId,
    language: language ?? this.language,
    currentLesson: currentLesson.present
        ? currentLesson.value
        : this.currentLesson,
    currentParagraph: currentParagraph.present
        ? currentParagraph.value
        : this.currentParagraph,
    manualReference: manualReference.present
        ? manualReference.value
        : this.manualReference,
    frequency: frequency ?? this.frequency,
    learningGoals: learningGoals.present
        ? learningGoals.value
        : this.learningGoals,
    pendingDoubts: pendingDoubts.present
        ? pendingDoubts.value
        : this.pendingDoubts,
    nextTopic: nextTopic.present ? nextTopic.value : this.nextTopic,
    pauseOrCloseReason: pauseOrCloseReason.present
        ? pauseOrCloseReason.value
        : this.pauseOrCloseReason,
    lastSessionAt: lastSessionAt.present
        ? lastSessionAt.value
        : this.lastSessionAt,
    nextPlannedAt: nextPlannedAt.present
        ? nextPlannedAt.value
        : this.nextPlannedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    revision: revision ?? this.revision,
  );
  BibleStudyEntry copyWithCompanion(BibleStudiesCompanion data) {
    return BibleStudyEntry(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      status: data.status.present ? data.status.value : this.status,
      publicationId: data.publicationId.present
          ? data.publicationId.value
          : this.publicationId,
      language: data.language.present ? data.language.value : this.language,
      currentLesson: data.currentLesson.present
          ? data.currentLesson.value
          : this.currentLesson,
      currentParagraph: data.currentParagraph.present
          ? data.currentParagraph.value
          : this.currentParagraph,
      manualReference: data.manualReference.present
          ? data.manualReference.value
          : this.manualReference,
      frequency: data.frequency.present ? data.frequency.value : this.frequency,
      learningGoals: data.learningGoals.present
          ? data.learningGoals.value
          : this.learningGoals,
      pendingDoubts: data.pendingDoubts.present
          ? data.pendingDoubts.value
          : this.pendingDoubts,
      nextTopic: data.nextTopic.present ? data.nextTopic.value : this.nextTopic,
      pauseOrCloseReason: data.pauseOrCloseReason.present
          ? data.pauseOrCloseReason.value
          : this.pauseOrCloseReason,
      lastSessionAt: data.lastSessionAt.present
          ? data.lastSessionAt.value
          : this.lastSessionAt,
      nextPlannedAt: data.nextPlannedAt.present
          ? data.nextPlannedAt.value
          : this.nextPlannedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      revision: data.revision.present ? data.revision.value : this.revision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BibleStudyEntry(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('ownerId: $ownerId, ')
          ..write('startedAt: $startedAt, ')
          ..write('status: $status, ')
          ..write('publicationId: $publicationId, ')
          ..write('language: $language, ')
          ..write('currentLesson: $currentLesson, ')
          ..write('currentParagraph: $currentParagraph, ')
          ..write('manualReference: $manualReference, ')
          ..write('frequency: $frequency, ')
          ..write('learningGoals: $learningGoals, ')
          ..write('pendingDoubts: $pendingDoubts, ')
          ..write('nextTopic: $nextTopic, ')
          ..write('pauseOrCloseReason: $pauseOrCloseReason, ')
          ..write('lastSessionAt: $lastSessionAt, ')
          ..write('nextPlannedAt: $nextPlannedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    title,
    ownerId,
    startedAt,
    status,
    publicationId,
    language,
    currentLesson,
    currentParagraph,
    manualReference,
    frequency,
    learningGoals,
    pendingDoubts,
    nextTopic,
    pauseOrCloseReason,
    lastSessionAt,
    nextPlannedAt,
    createdAt,
    updatedAt,
    deletedAt,
    revision,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BibleStudyEntry &&
          other.id == this.id &&
          other.title == this.title &&
          other.ownerId == this.ownerId &&
          other.startedAt == this.startedAt &&
          other.status == this.status &&
          other.publicationId == this.publicationId &&
          other.language == this.language &&
          other.currentLesson == this.currentLesson &&
          other.currentParagraph == this.currentParagraph &&
          other.manualReference == this.manualReference &&
          other.frequency == this.frequency &&
          other.learningGoals == this.learningGoals &&
          other.pendingDoubts == this.pendingDoubts &&
          other.nextTopic == this.nextTopic &&
          other.pauseOrCloseReason == this.pauseOrCloseReason &&
          other.lastSessionAt == this.lastSessionAt &&
          other.nextPlannedAt == this.nextPlannedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.revision == this.revision);
}

class BibleStudiesCompanion extends UpdateCompanion<BibleStudyEntry> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> ownerId;
  final Value<DateTime> startedAt;
  final Value<String> status;
  final Value<String> publicationId;
  final Value<String> language;
  final Value<int?> currentLesson;
  final Value<int?> currentParagraph;
  final Value<String?> manualReference;
  final Value<String> frequency;
  final Value<String?> learningGoals;
  final Value<String?> pendingDoubts;
  final Value<String?> nextTopic;
  final Value<String?> pauseOrCloseReason;
  final Value<DateTime?> lastSessionAt;
  final Value<DateTime?> nextPlannedAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> revision;
  final Value<int> rowid;
  const BibleStudiesCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.publicationId = const Value.absent(),
    this.language = const Value.absent(),
    this.currentLesson = const Value.absent(),
    this.currentParagraph = const Value.absent(),
    this.manualReference = const Value.absent(),
    this.frequency = const Value.absent(),
    this.learningGoals = const Value.absent(),
    this.pendingDoubts = const Value.absent(),
    this.nextTopic = const Value.absent(),
    this.pauseOrCloseReason = const Value.absent(),
    this.lastSessionAt = const Value.absent(),
    this.nextPlannedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BibleStudiesCompanion.insert({
    required String id,
    required String title,
    this.ownerId = const Value.absent(),
    required DateTime startedAt,
    this.status = const Value.absent(),
    required String publicationId,
    this.language = const Value.absent(),
    this.currentLesson = const Value.absent(),
    this.currentParagraph = const Value.absent(),
    this.manualReference = const Value.absent(),
    this.frequency = const Value.absent(),
    this.learningGoals = const Value.absent(),
    this.pendingDoubts = const Value.absent(),
    this.nextTopic = const Value.absent(),
    this.pauseOrCloseReason = const Value.absent(),
    this.lastSessionAt = const Value.absent(),
    this.nextPlannedAt = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       startedAt = Value(startedAt),
       publicationId = Value(publicationId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<BibleStudyEntry> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? ownerId,
    Expression<DateTime>? startedAt,
    Expression<String>? status,
    Expression<String>? publicationId,
    Expression<String>? language,
    Expression<int>? currentLesson,
    Expression<int>? currentParagraph,
    Expression<String>? manualReference,
    Expression<String>? frequency,
    Expression<String>? learningGoals,
    Expression<String>? pendingDoubts,
    Expression<String>? nextTopic,
    Expression<String>? pauseOrCloseReason,
    Expression<DateTime>? lastSessionAt,
    Expression<DateTime>? nextPlannedAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? revision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (ownerId != null) 'owner_id': ownerId,
      if (startedAt != null) 'started_at': startedAt,
      if (status != null) 'status': status,
      if (publicationId != null) 'publication_id': publicationId,
      if (language != null) 'language': language,
      if (currentLesson != null) 'current_lesson': currentLesson,
      if (currentParagraph != null) 'current_paragraph': currentParagraph,
      if (manualReference != null) 'manual_reference': manualReference,
      if (frequency != null) 'frequency': frequency,
      if (learningGoals != null) 'learning_goals': learningGoals,
      if (pendingDoubts != null) 'pending_doubts': pendingDoubts,
      if (nextTopic != null) 'next_topic': nextTopic,
      if (pauseOrCloseReason != null)
        'pause_or_close_reason': pauseOrCloseReason,
      if (lastSessionAt != null) 'last_session_at': lastSessionAt,
      if (nextPlannedAt != null) 'next_planned_at': nextPlannedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (revision != null) 'revision': revision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BibleStudiesCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String>? ownerId,
    Value<DateTime>? startedAt,
    Value<String>? status,
    Value<String>? publicationId,
    Value<String>? language,
    Value<int?>? currentLesson,
    Value<int?>? currentParagraph,
    Value<String?>? manualReference,
    Value<String>? frequency,
    Value<String?>? learningGoals,
    Value<String?>? pendingDoubts,
    Value<String?>? nextTopic,
    Value<String?>? pauseOrCloseReason,
    Value<DateTime?>? lastSessionAt,
    Value<DateTime?>? nextPlannedAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? revision,
    Value<int>? rowid,
  }) {
    return BibleStudiesCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      ownerId: ownerId ?? this.ownerId,
      startedAt: startedAt ?? this.startedAt,
      status: status ?? this.status,
      publicationId: publicationId ?? this.publicationId,
      language: language ?? this.language,
      currentLesson: currentLesson ?? this.currentLesson,
      currentParagraph: currentParagraph ?? this.currentParagraph,
      manualReference: manualReference ?? this.manualReference,
      frequency: frequency ?? this.frequency,
      learningGoals: learningGoals ?? this.learningGoals,
      pendingDoubts: pendingDoubts ?? this.pendingDoubts,
      nextTopic: nextTopic ?? this.nextTopic,
      pauseOrCloseReason: pauseOrCloseReason ?? this.pauseOrCloseReason,
      lastSessionAt: lastSessionAt ?? this.lastSessionAt,
      nextPlannedAt: nextPlannedAt ?? this.nextPlannedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      revision: revision ?? this.revision,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (publicationId.present) {
      map['publication_id'] = Variable<String>(publicationId.value);
    }
    if (language.present) {
      map['language'] = Variable<String>(language.value);
    }
    if (currentLesson.present) {
      map['current_lesson'] = Variable<int>(currentLesson.value);
    }
    if (currentParagraph.present) {
      map['current_paragraph'] = Variable<int>(currentParagraph.value);
    }
    if (manualReference.present) {
      map['manual_reference'] = Variable<String>(manualReference.value);
    }
    if (frequency.present) {
      map['frequency'] = Variable<String>(frequency.value);
    }
    if (learningGoals.present) {
      map['learning_goals'] = Variable<String>(learningGoals.value);
    }
    if (pendingDoubts.present) {
      map['pending_doubts'] = Variable<String>(pendingDoubts.value);
    }
    if (nextTopic.present) {
      map['next_topic'] = Variable<String>(nextTopic.value);
    }
    if (pauseOrCloseReason.present) {
      map['pause_or_close_reason'] = Variable<String>(pauseOrCloseReason.value);
    }
    if (lastSessionAt.present) {
      map['last_session_at'] = Variable<DateTime>(lastSessionAt.value);
    }
    if (nextPlannedAt.present) {
      map['next_planned_at'] = Variable<DateTime>(nextPlannedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BibleStudiesCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('ownerId: $ownerId, ')
          ..write('startedAt: $startedAt, ')
          ..write('status: $status, ')
          ..write('publicationId: $publicationId, ')
          ..write('language: $language, ')
          ..write('currentLesson: $currentLesson, ')
          ..write('currentParagraph: $currentParagraph, ')
          ..write('manualReference: $manualReference, ')
          ..write('frequency: $frequency, ')
          ..write('learningGoals: $learningGoals, ')
          ..write('pendingDoubts: $pendingDoubts, ')
          ..write('nextTopic: $nextTopic, ')
          ..write('pauseOrCloseReason: $pauseOrCloseReason, ')
          ..write('lastSessionAt: $lastSessionAt, ')
          ..write('nextPlannedAt: $nextPlannedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StudyParticipantsTable extends StudyParticipants
    with TableInfo<$StudyParticipantsTable, StudyParticipantEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StudyParticipantsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _studyIdMeta = const VerificationMeta(
    'studyId',
  );
  @override
  late final GeneratedColumn<String> studyId = GeneratedColumn<String>(
    'study_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES bible_studies (id)',
    ),
  );
  static const VerificationMeta _personIdMeta = const VerificationMeta(
    'personId',
  );
  @override
  late final GeneratedColumn<String> personId = GeneratedColumn<String>(
    'person_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES people (id)',
    ),
  );
  static const VerificationMeta _isPrimaryMeta = const VerificationMeta(
    'isPrimary',
  );
  @override
  late final GeneratedColumn<bool> isPrimary = GeneratedColumn<bool>(
    'is_primary',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_primary" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    studyId,
    personId,
    isPrimary,
    createdAt,
    updatedAt,
    deletedAt,
    revision,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'study_participants';
  @override
  VerificationContext validateIntegrity(
    Insertable<StudyParticipantEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('study_id')) {
      context.handle(
        _studyIdMeta,
        studyId.isAcceptableOrUnknown(data['study_id']!, _studyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_studyIdMeta);
    }
    if (data.containsKey('person_id')) {
      context.handle(
        _personIdMeta,
        personId.isAcceptableOrUnknown(data['person_id']!, _personIdMeta),
      );
    } else if (isInserting) {
      context.missing(_personIdMeta);
    }
    if (data.containsKey('is_primary')) {
      context.handle(
        _isPrimaryMeta,
        isPrimary.isAcceptableOrUnknown(data['is_primary']!, _isPrimaryMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StudyParticipantEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StudyParticipantEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      studyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}study_id'],
      )!,
      personId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}person_id'],
      )!,
      isPrimary: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_primary'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
    );
  }

  @override
  $StudyParticipantsTable createAlias(String alias) {
    return $StudyParticipantsTable(attachedDatabase, alias);
  }
}

class StudyParticipantEntry extends DataClass
    implements Insertable<StudyParticipantEntry> {
  final String id;
  final String studyId;
  final String personId;
  final bool isPrimary;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int revision;
  const StudyParticipantEntry({
    required this.id,
    required this.studyId,
    required this.personId,
    required this.isPrimary,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.revision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['study_id'] = Variable<String>(studyId);
    map['person_id'] = Variable<String>(personId);
    map['is_primary'] = Variable<bool>(isPrimary);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['revision'] = Variable<int>(revision);
    return map;
  }

  StudyParticipantsCompanion toCompanion(bool nullToAbsent) {
    return StudyParticipantsCompanion(
      id: Value(id),
      studyId: Value(studyId),
      personId: Value(personId),
      isPrimary: Value(isPrimary),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      revision: Value(revision),
    );
  }

  factory StudyParticipantEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StudyParticipantEntry(
      id: serializer.fromJson<String>(json['id']),
      studyId: serializer.fromJson<String>(json['studyId']),
      personId: serializer.fromJson<String>(json['personId']),
      isPrimary: serializer.fromJson<bool>(json['isPrimary']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      revision: serializer.fromJson<int>(json['revision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'studyId': serializer.toJson<String>(studyId),
      'personId': serializer.toJson<String>(personId),
      'isPrimary': serializer.toJson<bool>(isPrimary),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'revision': serializer.toJson<int>(revision),
    };
  }

  StudyParticipantEntry copyWith({
    String? id,
    String? studyId,
    String? personId,
    bool? isPrimary,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    int? revision,
  }) => StudyParticipantEntry(
    id: id ?? this.id,
    studyId: studyId ?? this.studyId,
    personId: personId ?? this.personId,
    isPrimary: isPrimary ?? this.isPrimary,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    revision: revision ?? this.revision,
  );
  StudyParticipantEntry copyWithCompanion(StudyParticipantsCompanion data) {
    return StudyParticipantEntry(
      id: data.id.present ? data.id.value : this.id,
      studyId: data.studyId.present ? data.studyId.value : this.studyId,
      personId: data.personId.present ? data.personId.value : this.personId,
      isPrimary: data.isPrimary.present ? data.isPrimary.value : this.isPrimary,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      revision: data.revision.present ? data.revision.value : this.revision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StudyParticipantEntry(')
          ..write('id: $id, ')
          ..write('studyId: $studyId, ')
          ..write('personId: $personId, ')
          ..write('isPrimary: $isPrimary, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    studyId,
    personId,
    isPrimary,
    createdAt,
    updatedAt,
    deletedAt,
    revision,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StudyParticipantEntry &&
          other.id == this.id &&
          other.studyId == this.studyId &&
          other.personId == this.personId &&
          other.isPrimary == this.isPrimary &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.revision == this.revision);
}

class StudyParticipantsCompanion
    extends UpdateCompanion<StudyParticipantEntry> {
  final Value<String> id;
  final Value<String> studyId;
  final Value<String> personId;
  final Value<bool> isPrimary;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> revision;
  final Value<int> rowid;
  const StudyParticipantsCompanion({
    this.id = const Value.absent(),
    this.studyId = const Value.absent(),
    this.personId = const Value.absent(),
    this.isPrimary = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StudyParticipantsCompanion.insert({
    required String id,
    required String studyId,
    required String personId,
    this.isPrimary = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       studyId = Value(studyId),
       personId = Value(personId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<StudyParticipantEntry> custom({
    Expression<String>? id,
    Expression<String>? studyId,
    Expression<String>? personId,
    Expression<bool>? isPrimary,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? revision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (studyId != null) 'study_id': studyId,
      if (personId != null) 'person_id': personId,
      if (isPrimary != null) 'is_primary': isPrimary,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (revision != null) 'revision': revision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StudyParticipantsCompanion copyWith({
    Value<String>? id,
    Value<String>? studyId,
    Value<String>? personId,
    Value<bool>? isPrimary,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? revision,
    Value<int>? rowid,
  }) {
    return StudyParticipantsCompanion(
      id: id ?? this.id,
      studyId: studyId ?? this.studyId,
      personId: personId ?? this.personId,
      isPrimary: isPrimary ?? this.isPrimary,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      revision: revision ?? this.revision,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (studyId.present) {
      map['study_id'] = Variable<String>(studyId.value);
    }
    if (personId.present) {
      map['person_id'] = Variable<String>(personId.value);
    }
    if (isPrimary.present) {
      map['is_primary'] = Variable<bool>(isPrimary.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StudyParticipantsCompanion(')
          ..write('id: $id, ')
          ..write('studyId: $studyId, ')
          ..write('personId: $personId, ')
          ..write('isPrimary: $isPrimary, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StudySessionsTable extends StudySessions
    with TableInfo<$StudySessionsTable, StudySessionEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StudySessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _studyIdMeta = const VerificationMeta(
    'studyId',
  );
  @override
  late final GeneratedColumn<String> studyId = GeneratedColumn<String>(
    'study_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES bible_studies (id)',
    ),
  );
  static const VerificationMeta _dateTimeFieldMeta = const VerificationMeta(
    'dateTimeField',
  );
  @override
  late final GeneratedColumn<DateTime> dateTimeField =
      GeneratedColumn<DateTime>(
        'date_time_field',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _publicationCodeMeta = const VerificationMeta(
    'publicationCode',
  );
  @override
  late final GeneratedColumn<String> publicationCode = GeneratedColumn<String>(
    'publication_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lessonCoveredMeta = const VerificationMeta(
    'lessonCovered',
  );
  @override
  late final GeneratedColumn<int> lessonCovered = GeneratedColumn<int>(
    'lesson_covered',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _paragraphsCoveredMeta = const VerificationMeta(
    'paragraphsCovered',
  );
  @override
  late final GeneratedColumn<String> paragraphsCovered =
      GeneratedColumn<String>(
        'paragraphs_covered',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _sessionNotesMeta = const VerificationMeta(
    'sessionNotes',
  );
  @override
  late final GeneratedColumn<String> sessionNotes = GeneratedColumn<String>(
    'session_notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pendingQuestionsMeta = const VerificationMeta(
    'pendingQuestions',
  );
  @override
  late final GeneratedColumn<String> pendingQuestions = GeneratedColumn<String>(
    'pending_questions',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nextStepMeta = const VerificationMeta(
    'nextStep',
  );
  @override
  late final GeneratedColumn<String> nextStep = GeneratedColumn<String>(
    'next_step',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('realizada'),
  );
  static const VerificationMeta _participantIdsMeta = const VerificationMeta(
    'participantIds',
  );
  @override
  late final GeneratedColumn<String> participantIds = GeneratedColumn<String>(
    'participant_ids',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    studyId,
    dateTimeField,
    publicationCode,
    lessonCovered,
    paragraphsCovered,
    sessionNotes,
    pendingQuestions,
    nextStep,
    status,
    participantIds,
    createdAt,
    updatedAt,
    deletedAt,
    revision,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'study_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<StudySessionEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('study_id')) {
      context.handle(
        _studyIdMeta,
        studyId.isAcceptableOrUnknown(data['study_id']!, _studyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_studyIdMeta);
    }
    if (data.containsKey('date_time_field')) {
      context.handle(
        _dateTimeFieldMeta,
        dateTimeField.isAcceptableOrUnknown(
          data['date_time_field']!,
          _dateTimeFieldMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dateTimeFieldMeta);
    }
    if (data.containsKey('publication_code')) {
      context.handle(
        _publicationCodeMeta,
        publicationCode.isAcceptableOrUnknown(
          data['publication_code']!,
          _publicationCodeMeta,
        ),
      );
    }
    if (data.containsKey('lesson_covered')) {
      context.handle(
        _lessonCoveredMeta,
        lessonCovered.isAcceptableOrUnknown(
          data['lesson_covered']!,
          _lessonCoveredMeta,
        ),
      );
    }
    if (data.containsKey('paragraphs_covered')) {
      context.handle(
        _paragraphsCoveredMeta,
        paragraphsCovered.isAcceptableOrUnknown(
          data['paragraphs_covered']!,
          _paragraphsCoveredMeta,
        ),
      );
    }
    if (data.containsKey('session_notes')) {
      context.handle(
        _sessionNotesMeta,
        sessionNotes.isAcceptableOrUnknown(
          data['session_notes']!,
          _sessionNotesMeta,
        ),
      );
    }
    if (data.containsKey('pending_questions')) {
      context.handle(
        _pendingQuestionsMeta,
        pendingQuestions.isAcceptableOrUnknown(
          data['pending_questions']!,
          _pendingQuestionsMeta,
        ),
      );
    }
    if (data.containsKey('next_step')) {
      context.handle(
        _nextStepMeta,
        nextStep.isAcceptableOrUnknown(data['next_step']!, _nextStepMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('participant_ids')) {
      context.handle(
        _participantIdsMeta,
        participantIds.isAcceptableOrUnknown(
          data['participant_ids']!,
          _participantIdsMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StudySessionEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StudySessionEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      studyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}study_id'],
      )!,
      dateTimeField: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date_time_field'],
      )!,
      publicationCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}publication_code'],
      ),
      lessonCovered: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lesson_covered'],
      ),
      paragraphsCovered: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}paragraphs_covered'],
      ),
      sessionNotes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_notes'],
      ),
      pendingQuestions: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pending_questions'],
      ),
      nextStep: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}next_step'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      participantIds: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}participant_ids'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
    );
  }

  @override
  $StudySessionsTable createAlias(String alias) {
    return $StudySessionsTable(attachedDatabase, alias);
  }
}

class StudySessionEntry extends DataClass
    implements Insertable<StudySessionEntry> {
  final String id;
  final String studyId;
  final DateTime dateTimeField;
  final String? publicationCode;
  final int? lessonCovered;
  final String? paragraphsCovered;
  final String? sessionNotes;
  final String? pendingQuestions;
  final String? nextStep;
  final String status;
  final String participantIds;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int revision;
  const StudySessionEntry({
    required this.id,
    required this.studyId,
    required this.dateTimeField,
    this.publicationCode,
    this.lessonCovered,
    this.paragraphsCovered,
    this.sessionNotes,
    this.pendingQuestions,
    this.nextStep,
    required this.status,
    required this.participantIds,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.revision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['study_id'] = Variable<String>(studyId);
    map['date_time_field'] = Variable<DateTime>(dateTimeField);
    if (!nullToAbsent || publicationCode != null) {
      map['publication_code'] = Variable<String>(publicationCode);
    }
    if (!nullToAbsent || lessonCovered != null) {
      map['lesson_covered'] = Variable<int>(lessonCovered);
    }
    if (!nullToAbsent || paragraphsCovered != null) {
      map['paragraphs_covered'] = Variable<String>(paragraphsCovered);
    }
    if (!nullToAbsent || sessionNotes != null) {
      map['session_notes'] = Variable<String>(sessionNotes);
    }
    if (!nullToAbsent || pendingQuestions != null) {
      map['pending_questions'] = Variable<String>(pendingQuestions);
    }
    if (!nullToAbsent || nextStep != null) {
      map['next_step'] = Variable<String>(nextStep);
    }
    map['status'] = Variable<String>(status);
    map['participant_ids'] = Variable<String>(participantIds);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['revision'] = Variable<int>(revision);
    return map;
  }

  StudySessionsCompanion toCompanion(bool nullToAbsent) {
    return StudySessionsCompanion(
      id: Value(id),
      studyId: Value(studyId),
      dateTimeField: Value(dateTimeField),
      publicationCode: publicationCode == null && nullToAbsent
          ? const Value.absent()
          : Value(publicationCode),
      lessonCovered: lessonCovered == null && nullToAbsent
          ? const Value.absent()
          : Value(lessonCovered),
      paragraphsCovered: paragraphsCovered == null && nullToAbsent
          ? const Value.absent()
          : Value(paragraphsCovered),
      sessionNotes: sessionNotes == null && nullToAbsent
          ? const Value.absent()
          : Value(sessionNotes),
      pendingQuestions: pendingQuestions == null && nullToAbsent
          ? const Value.absent()
          : Value(pendingQuestions),
      nextStep: nextStep == null && nullToAbsent
          ? const Value.absent()
          : Value(nextStep),
      status: Value(status),
      participantIds: Value(participantIds),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      revision: Value(revision),
    );
  }

  factory StudySessionEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StudySessionEntry(
      id: serializer.fromJson<String>(json['id']),
      studyId: serializer.fromJson<String>(json['studyId']),
      dateTimeField: serializer.fromJson<DateTime>(json['dateTimeField']),
      publicationCode: serializer.fromJson<String?>(json['publicationCode']),
      lessonCovered: serializer.fromJson<int?>(json['lessonCovered']),
      paragraphsCovered: serializer.fromJson<String?>(
        json['paragraphsCovered'],
      ),
      sessionNotes: serializer.fromJson<String?>(json['sessionNotes']),
      pendingQuestions: serializer.fromJson<String?>(json['pendingQuestions']),
      nextStep: serializer.fromJson<String?>(json['nextStep']),
      status: serializer.fromJson<String>(json['status']),
      participantIds: serializer.fromJson<String>(json['participantIds']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      revision: serializer.fromJson<int>(json['revision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'studyId': serializer.toJson<String>(studyId),
      'dateTimeField': serializer.toJson<DateTime>(dateTimeField),
      'publicationCode': serializer.toJson<String?>(publicationCode),
      'lessonCovered': serializer.toJson<int?>(lessonCovered),
      'paragraphsCovered': serializer.toJson<String?>(paragraphsCovered),
      'sessionNotes': serializer.toJson<String?>(sessionNotes),
      'pendingQuestions': serializer.toJson<String?>(pendingQuestions),
      'nextStep': serializer.toJson<String?>(nextStep),
      'status': serializer.toJson<String>(status),
      'participantIds': serializer.toJson<String>(participantIds),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'revision': serializer.toJson<int>(revision),
    };
  }

  StudySessionEntry copyWith({
    String? id,
    String? studyId,
    DateTime? dateTimeField,
    Value<String?> publicationCode = const Value.absent(),
    Value<int?> lessonCovered = const Value.absent(),
    Value<String?> paragraphsCovered = const Value.absent(),
    Value<String?> sessionNotes = const Value.absent(),
    Value<String?> pendingQuestions = const Value.absent(),
    Value<String?> nextStep = const Value.absent(),
    String? status,
    String? participantIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    int? revision,
  }) => StudySessionEntry(
    id: id ?? this.id,
    studyId: studyId ?? this.studyId,
    dateTimeField: dateTimeField ?? this.dateTimeField,
    publicationCode: publicationCode.present
        ? publicationCode.value
        : this.publicationCode,
    lessonCovered: lessonCovered.present
        ? lessonCovered.value
        : this.lessonCovered,
    paragraphsCovered: paragraphsCovered.present
        ? paragraphsCovered.value
        : this.paragraphsCovered,
    sessionNotes: sessionNotes.present ? sessionNotes.value : this.sessionNotes,
    pendingQuestions: pendingQuestions.present
        ? pendingQuestions.value
        : this.pendingQuestions,
    nextStep: nextStep.present ? nextStep.value : this.nextStep,
    status: status ?? this.status,
    participantIds: participantIds ?? this.participantIds,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    revision: revision ?? this.revision,
  );
  StudySessionEntry copyWithCompanion(StudySessionsCompanion data) {
    return StudySessionEntry(
      id: data.id.present ? data.id.value : this.id,
      studyId: data.studyId.present ? data.studyId.value : this.studyId,
      dateTimeField: data.dateTimeField.present
          ? data.dateTimeField.value
          : this.dateTimeField,
      publicationCode: data.publicationCode.present
          ? data.publicationCode.value
          : this.publicationCode,
      lessonCovered: data.lessonCovered.present
          ? data.lessonCovered.value
          : this.lessonCovered,
      paragraphsCovered: data.paragraphsCovered.present
          ? data.paragraphsCovered.value
          : this.paragraphsCovered,
      sessionNotes: data.sessionNotes.present
          ? data.sessionNotes.value
          : this.sessionNotes,
      pendingQuestions: data.pendingQuestions.present
          ? data.pendingQuestions.value
          : this.pendingQuestions,
      nextStep: data.nextStep.present ? data.nextStep.value : this.nextStep,
      status: data.status.present ? data.status.value : this.status,
      participantIds: data.participantIds.present
          ? data.participantIds.value
          : this.participantIds,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      revision: data.revision.present ? data.revision.value : this.revision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StudySessionEntry(')
          ..write('id: $id, ')
          ..write('studyId: $studyId, ')
          ..write('dateTimeField: $dateTimeField, ')
          ..write('publicationCode: $publicationCode, ')
          ..write('lessonCovered: $lessonCovered, ')
          ..write('paragraphsCovered: $paragraphsCovered, ')
          ..write('sessionNotes: $sessionNotes, ')
          ..write('pendingQuestions: $pendingQuestions, ')
          ..write('nextStep: $nextStep, ')
          ..write('status: $status, ')
          ..write('participantIds: $participantIds, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    studyId,
    dateTimeField,
    publicationCode,
    lessonCovered,
    paragraphsCovered,
    sessionNotes,
    pendingQuestions,
    nextStep,
    status,
    participantIds,
    createdAt,
    updatedAt,
    deletedAt,
    revision,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StudySessionEntry &&
          other.id == this.id &&
          other.studyId == this.studyId &&
          other.dateTimeField == this.dateTimeField &&
          other.publicationCode == this.publicationCode &&
          other.lessonCovered == this.lessonCovered &&
          other.paragraphsCovered == this.paragraphsCovered &&
          other.sessionNotes == this.sessionNotes &&
          other.pendingQuestions == this.pendingQuestions &&
          other.nextStep == this.nextStep &&
          other.status == this.status &&
          other.participantIds == this.participantIds &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.revision == this.revision);
}

class StudySessionsCompanion extends UpdateCompanion<StudySessionEntry> {
  final Value<String> id;
  final Value<String> studyId;
  final Value<DateTime> dateTimeField;
  final Value<String?> publicationCode;
  final Value<int?> lessonCovered;
  final Value<String?> paragraphsCovered;
  final Value<String?> sessionNotes;
  final Value<String?> pendingQuestions;
  final Value<String?> nextStep;
  final Value<String> status;
  final Value<String> participantIds;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> revision;
  final Value<int> rowid;
  const StudySessionsCompanion({
    this.id = const Value.absent(),
    this.studyId = const Value.absent(),
    this.dateTimeField = const Value.absent(),
    this.publicationCode = const Value.absent(),
    this.lessonCovered = const Value.absent(),
    this.paragraphsCovered = const Value.absent(),
    this.sessionNotes = const Value.absent(),
    this.pendingQuestions = const Value.absent(),
    this.nextStep = const Value.absent(),
    this.status = const Value.absent(),
    this.participantIds = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StudySessionsCompanion.insert({
    required String id,
    required String studyId,
    required DateTime dateTimeField,
    this.publicationCode = const Value.absent(),
    this.lessonCovered = const Value.absent(),
    this.paragraphsCovered = const Value.absent(),
    this.sessionNotes = const Value.absent(),
    this.pendingQuestions = const Value.absent(),
    this.nextStep = const Value.absent(),
    this.status = const Value.absent(),
    this.participantIds = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       studyId = Value(studyId),
       dateTimeField = Value(dateTimeField),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<StudySessionEntry> custom({
    Expression<String>? id,
    Expression<String>? studyId,
    Expression<DateTime>? dateTimeField,
    Expression<String>? publicationCode,
    Expression<int>? lessonCovered,
    Expression<String>? paragraphsCovered,
    Expression<String>? sessionNotes,
    Expression<String>? pendingQuestions,
    Expression<String>? nextStep,
    Expression<String>? status,
    Expression<String>? participantIds,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? revision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (studyId != null) 'study_id': studyId,
      if (dateTimeField != null) 'date_time_field': dateTimeField,
      if (publicationCode != null) 'publication_code': publicationCode,
      if (lessonCovered != null) 'lesson_covered': lessonCovered,
      if (paragraphsCovered != null) 'paragraphs_covered': paragraphsCovered,
      if (sessionNotes != null) 'session_notes': sessionNotes,
      if (pendingQuestions != null) 'pending_questions': pendingQuestions,
      if (nextStep != null) 'next_step': nextStep,
      if (status != null) 'status': status,
      if (participantIds != null) 'participant_ids': participantIds,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (revision != null) 'revision': revision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StudySessionsCompanion copyWith({
    Value<String>? id,
    Value<String>? studyId,
    Value<DateTime>? dateTimeField,
    Value<String?>? publicationCode,
    Value<int?>? lessonCovered,
    Value<String?>? paragraphsCovered,
    Value<String?>? sessionNotes,
    Value<String?>? pendingQuestions,
    Value<String?>? nextStep,
    Value<String>? status,
    Value<String>? participantIds,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? revision,
    Value<int>? rowid,
  }) {
    return StudySessionsCompanion(
      id: id ?? this.id,
      studyId: studyId ?? this.studyId,
      dateTimeField: dateTimeField ?? this.dateTimeField,
      publicationCode: publicationCode ?? this.publicationCode,
      lessonCovered: lessonCovered ?? this.lessonCovered,
      paragraphsCovered: paragraphsCovered ?? this.paragraphsCovered,
      sessionNotes: sessionNotes ?? this.sessionNotes,
      pendingQuestions: pendingQuestions ?? this.pendingQuestions,
      nextStep: nextStep ?? this.nextStep,
      status: status ?? this.status,
      participantIds: participantIds ?? this.participantIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      revision: revision ?? this.revision,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (studyId.present) {
      map['study_id'] = Variable<String>(studyId.value);
    }
    if (dateTimeField.present) {
      map['date_time_field'] = Variable<DateTime>(dateTimeField.value);
    }
    if (publicationCode.present) {
      map['publication_code'] = Variable<String>(publicationCode.value);
    }
    if (lessonCovered.present) {
      map['lesson_covered'] = Variable<int>(lessonCovered.value);
    }
    if (paragraphsCovered.present) {
      map['paragraphs_covered'] = Variable<String>(paragraphsCovered.value);
    }
    if (sessionNotes.present) {
      map['session_notes'] = Variable<String>(sessionNotes.value);
    }
    if (pendingQuestions.present) {
      map['pending_questions'] = Variable<String>(pendingQuestions.value);
    }
    if (nextStep.present) {
      map['next_step'] = Variable<String>(nextStep.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (participantIds.present) {
      map['participant_ids'] = Variable<String>(participantIds.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StudySessionsCompanion(')
          ..write('id: $id, ')
          ..write('studyId: $studyId, ')
          ..write('dateTimeField: $dateTimeField, ')
          ..write('publicationCode: $publicationCode, ')
          ..write('lessonCovered: $lessonCovered, ')
          ..write('paragraphsCovered: $paragraphsCovered, ')
          ..write('sessionNotes: $sessionNotes, ')
          ..write('pendingQuestions: $pendingQuestions, ')
          ..write('nextStep: $nextStep, ')
          ..write('status: $status, ')
          ..write('participantIds: $participantIds, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppointmentsTable extends Appointments
    with TableInfo<$AppointmentsTable, AppointmentEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppointmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _personIdMeta = const VerificationMeta(
    'personId',
  );
  @override
  late final GeneratedColumn<String> personId = GeneratedColumn<String>(
    'person_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES people (id)',
    ),
  );
  static const VerificationMeta _studyIdMeta = const VerificationMeta(
    'studyId',
  );
  @override
  late final GeneratedColumn<String> studyId = GeneratedColumn<String>(
    'study_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES bible_studies (id)',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startTimeMeta = const VerificationMeta(
    'startTime',
  );
  @override
  late final GeneratedColumn<DateTime> startTime = GeneratedColumn<DateTime>(
    'start_time',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endTimeMeta = const VerificationMeta(
    'endTime',
  );
  @override
  late final GeneratedColumn<DateTime> endTime = GeneratedColumn<DateTime>(
    'end_time',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMinutesMeta = const VerificationMeta(
    'durationMinutes',
  );
  @override
  late final GeneratedColumn<int> durationMinutes = GeneratedColumn<int>(
    'duration_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(30),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('planejado'),
  );
  static const VerificationMeta _previousAppointmentIdMeta =
      const VerificationMeta('previousAppointmentId');
  @override
  late final GeneratedColumn<String> previousAppointmentId =
      GeneratedColumn<String>(
        'previous_appointment_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _locationNotesMeta = const VerificationMeta(
    'locationNotes',
  );
  @override
  late final GeneratedColumn<String> locationNotes = GeneratedColumn<String>(
    'location_notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reminderMinutesBeforeMeta =
      const VerificationMeta('reminderMinutesBefore');
  @override
  late final GeneratedColumn<int> reminderMinutesBefore = GeneratedColumn<int>(
    'reminder_minutes_before',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _secondReminderMinutesBeforeMeta =
      const VerificationMeta('secondReminderMinutesBefore');
  @override
  late final GeneratedColumn<int> secondReminderMinutesBefore =
      GeneratedColumn<int>(
        'second_reminder_minutes_before',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _isProvisionalMeta = const VerificationMeta(
    'isProvisional',
  );
  @override
  late final GeneratedColumn<bool> isProvisional = GeneratedColumn<bool>(
    'is_provisional',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_provisional" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    personId,
    studyId,
    title,
    startTime,
    endTime,
    durationMinutes,
    status,
    previousAppointmentId,
    locationNotes,
    reminderMinutesBefore,
    secondReminderMinutesBefore,
    isProvisional,
    createdAt,
    updatedAt,
    deletedAt,
    revision,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'appointments';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppointmentEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('person_id')) {
      context.handle(
        _personIdMeta,
        personId.isAcceptableOrUnknown(data['person_id']!, _personIdMeta),
      );
    }
    if (data.containsKey('study_id')) {
      context.handle(
        _studyIdMeta,
        studyId.isAcceptableOrUnknown(data['study_id']!, _studyIdMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('start_time')) {
      context.handle(
        _startTimeMeta,
        startTime.isAcceptableOrUnknown(data['start_time']!, _startTimeMeta),
      );
    } else if (isInserting) {
      context.missing(_startTimeMeta);
    }
    if (data.containsKey('end_time')) {
      context.handle(
        _endTimeMeta,
        endTime.isAcceptableOrUnknown(data['end_time']!, _endTimeMeta),
      );
    } else if (isInserting) {
      context.missing(_endTimeMeta);
    }
    if (data.containsKey('duration_minutes')) {
      context.handle(
        _durationMinutesMeta,
        durationMinutes.isAcceptableOrUnknown(
          data['duration_minutes']!,
          _durationMinutesMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('previous_appointment_id')) {
      context.handle(
        _previousAppointmentIdMeta,
        previousAppointmentId.isAcceptableOrUnknown(
          data['previous_appointment_id']!,
          _previousAppointmentIdMeta,
        ),
      );
    }
    if (data.containsKey('location_notes')) {
      context.handle(
        _locationNotesMeta,
        locationNotes.isAcceptableOrUnknown(
          data['location_notes']!,
          _locationNotesMeta,
        ),
      );
    }
    if (data.containsKey('reminder_minutes_before')) {
      context.handle(
        _reminderMinutesBeforeMeta,
        reminderMinutesBefore.isAcceptableOrUnknown(
          data['reminder_minutes_before']!,
          _reminderMinutesBeforeMeta,
        ),
      );
    }
    if (data.containsKey('second_reminder_minutes_before')) {
      context.handle(
        _secondReminderMinutesBeforeMeta,
        secondReminderMinutesBefore.isAcceptableOrUnknown(
          data['second_reminder_minutes_before']!,
          _secondReminderMinutesBeforeMeta,
        ),
      );
    }
    if (data.containsKey('is_provisional')) {
      context.handle(
        _isProvisionalMeta,
        isProvisional.isAcceptableOrUnknown(
          data['is_provisional']!,
          _isProvisionalMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AppointmentEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppointmentEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      personId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}person_id'],
      ),
      studyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}study_id'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      startTime: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_time'],
      )!,
      endTime: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}end_time'],
      )!,
      durationMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_minutes'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      previousAppointmentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}previous_appointment_id'],
      ),
      locationNotes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location_notes'],
      ),
      reminderMinutesBefore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reminder_minutes_before'],
      ),
      secondReminderMinutesBefore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}second_reminder_minutes_before'],
      ),
      isProvisional: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_provisional'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
    );
  }

  @override
  $AppointmentsTable createAlias(String alias) {
    return $AppointmentsTable(attachedDatabase, alias);
  }
}

class AppointmentEntry extends DataClass
    implements Insertable<AppointmentEntry> {
  final String id;
  final String? personId;
  final String? studyId;
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final int durationMinutes;
  final String status;
  final String? previousAppointmentId;
  final String? locationNotes;
  final int? reminderMinutesBefore;
  final int? secondReminderMinutesBefore;
  final bool isProvisional;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int revision;
  const AppointmentEntry({
    required this.id,
    this.personId,
    this.studyId,
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    required this.status,
    this.previousAppointmentId,
    this.locationNotes,
    this.reminderMinutesBefore,
    this.secondReminderMinutesBefore,
    required this.isProvisional,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.revision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || personId != null) {
      map['person_id'] = Variable<String>(personId);
    }
    if (!nullToAbsent || studyId != null) {
      map['study_id'] = Variable<String>(studyId);
    }
    map['title'] = Variable<String>(title);
    map['start_time'] = Variable<DateTime>(startTime);
    map['end_time'] = Variable<DateTime>(endTime);
    map['duration_minutes'] = Variable<int>(durationMinutes);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || previousAppointmentId != null) {
      map['previous_appointment_id'] = Variable<String>(previousAppointmentId);
    }
    if (!nullToAbsent || locationNotes != null) {
      map['location_notes'] = Variable<String>(locationNotes);
    }
    if (!nullToAbsent || reminderMinutesBefore != null) {
      map['reminder_minutes_before'] = Variable<int>(reminderMinutesBefore);
    }
    if (!nullToAbsent || secondReminderMinutesBefore != null) {
      map['second_reminder_minutes_before'] = Variable<int>(
        secondReminderMinutesBefore,
      );
    }
    map['is_provisional'] = Variable<bool>(isProvisional);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['revision'] = Variable<int>(revision);
    return map;
  }

  AppointmentsCompanion toCompanion(bool nullToAbsent) {
    return AppointmentsCompanion(
      id: Value(id),
      personId: personId == null && nullToAbsent
          ? const Value.absent()
          : Value(personId),
      studyId: studyId == null && nullToAbsent
          ? const Value.absent()
          : Value(studyId),
      title: Value(title),
      startTime: Value(startTime),
      endTime: Value(endTime),
      durationMinutes: Value(durationMinutes),
      status: Value(status),
      previousAppointmentId: previousAppointmentId == null && nullToAbsent
          ? const Value.absent()
          : Value(previousAppointmentId),
      locationNotes: locationNotes == null && nullToAbsent
          ? const Value.absent()
          : Value(locationNotes),
      reminderMinutesBefore: reminderMinutesBefore == null && nullToAbsent
          ? const Value.absent()
          : Value(reminderMinutesBefore),
      secondReminderMinutesBefore:
          secondReminderMinutesBefore == null && nullToAbsent
          ? const Value.absent()
          : Value(secondReminderMinutesBefore),
      isProvisional: Value(isProvisional),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      revision: Value(revision),
    );
  }

  factory AppointmentEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppointmentEntry(
      id: serializer.fromJson<String>(json['id']),
      personId: serializer.fromJson<String?>(json['personId']),
      studyId: serializer.fromJson<String?>(json['studyId']),
      title: serializer.fromJson<String>(json['title']),
      startTime: serializer.fromJson<DateTime>(json['startTime']),
      endTime: serializer.fromJson<DateTime>(json['endTime']),
      durationMinutes: serializer.fromJson<int>(json['durationMinutes']),
      status: serializer.fromJson<String>(json['status']),
      previousAppointmentId: serializer.fromJson<String?>(
        json['previousAppointmentId'],
      ),
      locationNotes: serializer.fromJson<String?>(json['locationNotes']),
      reminderMinutesBefore: serializer.fromJson<int?>(
        json['reminderMinutesBefore'],
      ),
      secondReminderMinutesBefore: serializer.fromJson<int?>(
        json['secondReminderMinutesBefore'],
      ),
      isProvisional: serializer.fromJson<bool>(json['isProvisional']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      revision: serializer.fromJson<int>(json['revision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'personId': serializer.toJson<String?>(personId),
      'studyId': serializer.toJson<String?>(studyId),
      'title': serializer.toJson<String>(title),
      'startTime': serializer.toJson<DateTime>(startTime),
      'endTime': serializer.toJson<DateTime>(endTime),
      'durationMinutes': serializer.toJson<int>(durationMinutes),
      'status': serializer.toJson<String>(status),
      'previousAppointmentId': serializer.toJson<String?>(
        previousAppointmentId,
      ),
      'locationNotes': serializer.toJson<String?>(locationNotes),
      'reminderMinutesBefore': serializer.toJson<int?>(reminderMinutesBefore),
      'secondReminderMinutesBefore': serializer.toJson<int?>(
        secondReminderMinutesBefore,
      ),
      'isProvisional': serializer.toJson<bool>(isProvisional),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'revision': serializer.toJson<int>(revision),
    };
  }

  AppointmentEntry copyWith({
    String? id,
    Value<String?> personId = const Value.absent(),
    Value<String?> studyId = const Value.absent(),
    String? title,
    DateTime? startTime,
    DateTime? endTime,
    int? durationMinutes,
    String? status,
    Value<String?> previousAppointmentId = const Value.absent(),
    Value<String?> locationNotes = const Value.absent(),
    Value<int?> reminderMinutesBefore = const Value.absent(),
    Value<int?> secondReminderMinutesBefore = const Value.absent(),
    bool? isProvisional,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    int? revision,
  }) => AppointmentEntry(
    id: id ?? this.id,
    personId: personId.present ? personId.value : this.personId,
    studyId: studyId.present ? studyId.value : this.studyId,
    title: title ?? this.title,
    startTime: startTime ?? this.startTime,
    endTime: endTime ?? this.endTime,
    durationMinutes: durationMinutes ?? this.durationMinutes,
    status: status ?? this.status,
    previousAppointmentId: previousAppointmentId.present
        ? previousAppointmentId.value
        : this.previousAppointmentId,
    locationNotes: locationNotes.present
        ? locationNotes.value
        : this.locationNotes,
    reminderMinutesBefore: reminderMinutesBefore.present
        ? reminderMinutesBefore.value
        : this.reminderMinutesBefore,
    secondReminderMinutesBefore: secondReminderMinutesBefore.present
        ? secondReminderMinutesBefore.value
        : this.secondReminderMinutesBefore,
    isProvisional: isProvisional ?? this.isProvisional,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    revision: revision ?? this.revision,
  );
  AppointmentEntry copyWithCompanion(AppointmentsCompanion data) {
    return AppointmentEntry(
      id: data.id.present ? data.id.value : this.id,
      personId: data.personId.present ? data.personId.value : this.personId,
      studyId: data.studyId.present ? data.studyId.value : this.studyId,
      title: data.title.present ? data.title.value : this.title,
      startTime: data.startTime.present ? data.startTime.value : this.startTime,
      endTime: data.endTime.present ? data.endTime.value : this.endTime,
      durationMinutes: data.durationMinutes.present
          ? data.durationMinutes.value
          : this.durationMinutes,
      status: data.status.present ? data.status.value : this.status,
      previousAppointmentId: data.previousAppointmentId.present
          ? data.previousAppointmentId.value
          : this.previousAppointmentId,
      locationNotes: data.locationNotes.present
          ? data.locationNotes.value
          : this.locationNotes,
      reminderMinutesBefore: data.reminderMinutesBefore.present
          ? data.reminderMinutesBefore.value
          : this.reminderMinutesBefore,
      secondReminderMinutesBefore: data.secondReminderMinutesBefore.present
          ? data.secondReminderMinutesBefore.value
          : this.secondReminderMinutesBefore,
      isProvisional: data.isProvisional.present
          ? data.isProvisional.value
          : this.isProvisional,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      revision: data.revision.present ? data.revision.value : this.revision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppointmentEntry(')
          ..write('id: $id, ')
          ..write('personId: $personId, ')
          ..write('studyId: $studyId, ')
          ..write('title: $title, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('durationMinutes: $durationMinutes, ')
          ..write('status: $status, ')
          ..write('previousAppointmentId: $previousAppointmentId, ')
          ..write('locationNotes: $locationNotes, ')
          ..write('reminderMinutesBefore: $reminderMinutesBefore, ')
          ..write('secondReminderMinutesBefore: $secondReminderMinutesBefore, ')
          ..write('isProvisional: $isProvisional, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    personId,
    studyId,
    title,
    startTime,
    endTime,
    durationMinutes,
    status,
    previousAppointmentId,
    locationNotes,
    reminderMinutesBefore,
    secondReminderMinutesBefore,
    isProvisional,
    createdAt,
    updatedAt,
    deletedAt,
    revision,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppointmentEntry &&
          other.id == this.id &&
          other.personId == this.personId &&
          other.studyId == this.studyId &&
          other.title == this.title &&
          other.startTime == this.startTime &&
          other.endTime == this.endTime &&
          other.durationMinutes == this.durationMinutes &&
          other.status == this.status &&
          other.previousAppointmentId == this.previousAppointmentId &&
          other.locationNotes == this.locationNotes &&
          other.reminderMinutesBefore == this.reminderMinutesBefore &&
          other.secondReminderMinutesBefore ==
              this.secondReminderMinutesBefore &&
          other.isProvisional == this.isProvisional &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.revision == this.revision);
}

class AppointmentsCompanion extends UpdateCompanion<AppointmentEntry> {
  final Value<String> id;
  final Value<String?> personId;
  final Value<String?> studyId;
  final Value<String> title;
  final Value<DateTime> startTime;
  final Value<DateTime> endTime;
  final Value<int> durationMinutes;
  final Value<String> status;
  final Value<String?> previousAppointmentId;
  final Value<String?> locationNotes;
  final Value<int?> reminderMinutesBefore;
  final Value<int?> secondReminderMinutesBefore;
  final Value<bool> isProvisional;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> revision;
  final Value<int> rowid;
  const AppointmentsCompanion({
    this.id = const Value.absent(),
    this.personId = const Value.absent(),
    this.studyId = const Value.absent(),
    this.title = const Value.absent(),
    this.startTime = const Value.absent(),
    this.endTime = const Value.absent(),
    this.durationMinutes = const Value.absent(),
    this.status = const Value.absent(),
    this.previousAppointmentId = const Value.absent(),
    this.locationNotes = const Value.absent(),
    this.reminderMinutesBefore = const Value.absent(),
    this.secondReminderMinutesBefore = const Value.absent(),
    this.isProvisional = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppointmentsCompanion.insert({
    required String id,
    this.personId = const Value.absent(),
    this.studyId = const Value.absent(),
    required String title,
    required DateTime startTime,
    required DateTime endTime,
    this.durationMinutes = const Value.absent(),
    this.status = const Value.absent(),
    this.previousAppointmentId = const Value.absent(),
    this.locationNotes = const Value.absent(),
    this.reminderMinutesBefore = const Value.absent(),
    this.secondReminderMinutesBefore = const Value.absent(),
    this.isProvisional = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       startTime = Value(startTime),
       endTime = Value(endTime),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<AppointmentEntry> custom({
    Expression<String>? id,
    Expression<String>? personId,
    Expression<String>? studyId,
    Expression<String>? title,
    Expression<DateTime>? startTime,
    Expression<DateTime>? endTime,
    Expression<int>? durationMinutes,
    Expression<String>? status,
    Expression<String>? previousAppointmentId,
    Expression<String>? locationNotes,
    Expression<int>? reminderMinutesBefore,
    Expression<int>? secondReminderMinutesBefore,
    Expression<bool>? isProvisional,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? revision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (personId != null) 'person_id': personId,
      if (studyId != null) 'study_id': studyId,
      if (title != null) 'title': title,
      if (startTime != null) 'start_time': startTime,
      if (endTime != null) 'end_time': endTime,
      if (durationMinutes != null) 'duration_minutes': durationMinutes,
      if (status != null) 'status': status,
      if (previousAppointmentId != null)
        'previous_appointment_id': previousAppointmentId,
      if (locationNotes != null) 'location_notes': locationNotes,
      if (reminderMinutesBefore != null)
        'reminder_minutes_before': reminderMinutesBefore,
      if (secondReminderMinutesBefore != null)
        'second_reminder_minutes_before': secondReminderMinutesBefore,
      if (isProvisional != null) 'is_provisional': isProvisional,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (revision != null) 'revision': revision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppointmentsCompanion copyWith({
    Value<String>? id,
    Value<String?>? personId,
    Value<String?>? studyId,
    Value<String>? title,
    Value<DateTime>? startTime,
    Value<DateTime>? endTime,
    Value<int>? durationMinutes,
    Value<String>? status,
    Value<String?>? previousAppointmentId,
    Value<String?>? locationNotes,
    Value<int?>? reminderMinutesBefore,
    Value<int?>? secondReminderMinutesBefore,
    Value<bool>? isProvisional,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? revision,
    Value<int>? rowid,
  }) {
    return AppointmentsCompanion(
      id: id ?? this.id,
      personId: personId ?? this.personId,
      studyId: studyId ?? this.studyId,
      title: title ?? this.title,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      status: status ?? this.status,
      previousAppointmentId:
          previousAppointmentId ?? this.previousAppointmentId,
      locationNotes: locationNotes ?? this.locationNotes,
      reminderMinutesBefore:
          reminderMinutesBefore ?? this.reminderMinutesBefore,
      secondReminderMinutesBefore:
          secondReminderMinutesBefore ?? this.secondReminderMinutesBefore,
      isProvisional: isProvisional ?? this.isProvisional,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      revision: revision ?? this.revision,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (personId.present) {
      map['person_id'] = Variable<String>(personId.value);
    }
    if (studyId.present) {
      map['study_id'] = Variable<String>(studyId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (startTime.present) {
      map['start_time'] = Variable<DateTime>(startTime.value);
    }
    if (endTime.present) {
      map['end_time'] = Variable<DateTime>(endTime.value);
    }
    if (durationMinutes.present) {
      map['duration_minutes'] = Variable<int>(durationMinutes.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (previousAppointmentId.present) {
      map['previous_appointment_id'] = Variable<String>(
        previousAppointmentId.value,
      );
    }
    if (locationNotes.present) {
      map['location_notes'] = Variable<String>(locationNotes.value);
    }
    if (reminderMinutesBefore.present) {
      map['reminder_minutes_before'] = Variable<int>(
        reminderMinutesBefore.value,
      );
    }
    if (secondReminderMinutesBefore.present) {
      map['second_reminder_minutes_before'] = Variable<int>(
        secondReminderMinutesBefore.value,
      );
    }
    if (isProvisional.present) {
      map['is_provisional'] = Variable<bool>(isProvisional.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppointmentsCompanion(')
          ..write('id: $id, ')
          ..write('personId: $personId, ')
          ..write('studyId: $studyId, ')
          ..write('title: $title, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('durationMinutes: $durationMinutes, ')
          ..write('status: $status, ')
          ..write('previousAppointmentId: $previousAppointmentId, ')
          ..write('locationNotes: $locationNotes, ')
          ..write('reminderMinutesBefore: $reminderMinutesBefore, ')
          ..write('secondReminderMinutesBefore: $secondReminderMinutesBefore, ')
          ..write('isProvisional: $isProvisional, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ActivityRecordsTable extends ActivityRecords
    with TableInfo<$ActivityRecordsTable, ActivityRecordEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ActivityRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationSecondsMeta = const VerificationMeta(
    'durationSeconds',
  );
  @override
  late final GeneratedColumn<int> durationSeconds = GeneratedColumn<int>(
    'duration_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modalityMeta = const VerificationMeta(
    'modality',
  );
  @override
  late final GeneratedColumn<String> modality = GeneratedColumn<String>(
    'modality',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    date,
    durationSeconds,
    modality,
    notes,
    createdAt,
    updatedAt,
    deletedAt,
    revision,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'activity_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<ActivityRecordEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
        _durationSecondsMeta,
        durationSeconds.isAcceptableOrUnknown(
          data['duration_seconds']!,
          _durationSecondsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_durationSecondsMeta);
    }
    if (data.containsKey('modality')) {
      context.handle(
        _modalityMeta,
        modality.isAcceptableOrUnknown(data['modality']!, _modalityMeta),
      );
    } else if (isInserting) {
      context.missing(_modalityMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ActivityRecordEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ActivityRecordEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      durationSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_seconds'],
      )!,
      modality: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}modality'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
    );
  }

  @override
  $ActivityRecordsTable createAlias(String alias) {
    return $ActivityRecordsTable(attachedDatabase, alias);
  }
}

class ActivityRecordEntry extends DataClass
    implements Insertable<ActivityRecordEntry> {
  final String id;
  final DateTime date;
  final int durationSeconds;
  final String modality;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int revision;
  const ActivityRecordEntry({
    required this.id,
    required this.date,
    required this.durationSeconds,
    required this.modality,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.revision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['date'] = Variable<DateTime>(date);
    map['duration_seconds'] = Variable<int>(durationSeconds);
    map['modality'] = Variable<String>(modality);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['revision'] = Variable<int>(revision);
    return map;
  }

  ActivityRecordsCompanion toCompanion(bool nullToAbsent) {
    return ActivityRecordsCompanion(
      id: Value(id),
      date: Value(date),
      durationSeconds: Value(durationSeconds),
      modality: Value(modality),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      revision: Value(revision),
    );
  }

  factory ActivityRecordEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ActivityRecordEntry(
      id: serializer.fromJson<String>(json['id']),
      date: serializer.fromJson<DateTime>(json['date']),
      durationSeconds: serializer.fromJson<int>(json['durationSeconds']),
      modality: serializer.fromJson<String>(json['modality']),
      notes: serializer.fromJson<String?>(json['notes']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      revision: serializer.fromJson<int>(json['revision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'date': serializer.toJson<DateTime>(date),
      'durationSeconds': serializer.toJson<int>(durationSeconds),
      'modality': serializer.toJson<String>(modality),
      'notes': serializer.toJson<String?>(notes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'revision': serializer.toJson<int>(revision),
    };
  }

  ActivityRecordEntry copyWith({
    String? id,
    DateTime? date,
    int? durationSeconds,
    String? modality,
    Value<String?> notes = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    int? revision,
  }) => ActivityRecordEntry(
    id: id ?? this.id,
    date: date ?? this.date,
    durationSeconds: durationSeconds ?? this.durationSeconds,
    modality: modality ?? this.modality,
    notes: notes.present ? notes.value : this.notes,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    revision: revision ?? this.revision,
  );
  ActivityRecordEntry copyWithCompanion(ActivityRecordsCompanion data) {
    return ActivityRecordEntry(
      id: data.id.present ? data.id.value : this.id,
      date: data.date.present ? data.date.value : this.date,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
      modality: data.modality.present ? data.modality.value : this.modality,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      revision: data.revision.present ? data.revision.value : this.revision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ActivityRecordEntry(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('modality: $modality, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    date,
    durationSeconds,
    modality,
    notes,
    createdAt,
    updatedAt,
    deletedAt,
    revision,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ActivityRecordEntry &&
          other.id == this.id &&
          other.date == this.date &&
          other.durationSeconds == this.durationSeconds &&
          other.modality == this.modality &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.revision == this.revision);
}

class ActivityRecordsCompanion extends UpdateCompanion<ActivityRecordEntry> {
  final Value<String> id;
  final Value<DateTime> date;
  final Value<int> durationSeconds;
  final Value<String> modality;
  final Value<String?> notes;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> revision;
  final Value<int> rowid;
  const ActivityRecordsCompanion({
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.modality = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ActivityRecordsCompanion.insert({
    required String id,
    required DateTime date,
    required int durationSeconds,
    required String modality,
    this.notes = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       date = Value(date),
       durationSeconds = Value(durationSeconds),
       modality = Value(modality),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ActivityRecordEntry> custom({
    Expression<String>? id,
    Expression<DateTime>? date,
    Expression<int>? durationSeconds,
    Expression<String>? modality,
    Expression<String>? notes,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? revision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (date != null) 'date': date,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (modality != null) 'modality': modality,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (revision != null) 'revision': revision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ActivityRecordsCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? date,
    Value<int>? durationSeconds,
    Value<String>? modality,
    Value<String?>? notes,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? revision,
    Value<int>? rowid,
  }) {
    return ActivityRecordsCompanion(
      id: id ?? this.id,
      date: date ?? this.date,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      modality: modality ?? this.modality,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      revision: revision ?? this.revision,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<int>(durationSeconds.value);
    }
    if (modality.present) {
      map['modality'] = Variable<String>(modality.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ActivityRecordsCompanion(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('modality: $modality, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncQueueTable extends SyncQueue
    with TableInfo<$SyncQueueTable, SyncQueueEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncQueueTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operationMeta = const VerificationMeta(
    'operation',
  );
  @override
  late final GeneratedColumn<String> operation = GeneratedColumn<String>(
    'operation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    entityType,
    entityId,
    operation,
    payload,
    createdAt,
    attempts,
    lastError,
    status,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_queue';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncQueueEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('operation')) {
      context.handle(
        _operationMeta,
        operation.isAcceptableOrUnknown(data['operation']!, _operationMeta),
      );
    } else if (isInserting) {
      context.missing(_operationMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncQueueEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncQueueEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      operation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
    );
  }

  @override
  $SyncQueueTable createAlias(String alias) {
    return $SyncQueueTable(attachedDatabase, alias);
  }
}

class SyncQueueEntry extends DataClass implements Insertable<SyncQueueEntry> {
  final String id;
  final String entityType;
  final String entityId;
  final String operation;
  final String payload;
  final DateTime createdAt;
  final int attempts;
  final String? lastError;
  final String status;
  const SyncQueueEntry({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payload,
    required this.createdAt,
    required this.attempts,
    this.lastError,
    required this.status,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    map['operation'] = Variable<String>(operation);
    map['payload'] = Variable<String>(payload);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['status'] = Variable<String>(status);
    return map;
  }

  SyncQueueCompanion toCompanion(bool nullToAbsent) {
    return SyncQueueCompanion(
      id: Value(id),
      entityType: Value(entityType),
      entityId: Value(entityId),
      operation: Value(operation),
      payload: Value(payload),
      createdAt: Value(createdAt),
      attempts: Value(attempts),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      status: Value(status),
    );
  }

  factory SyncQueueEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncQueueEntry(
      id: serializer.fromJson<String>(json['id']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String>(json['entityId']),
      operation: serializer.fromJson<String>(json['operation']),
      payload: serializer.fromJson<String>(json['payload']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      attempts: serializer.fromJson<int>(json['attempts']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      status: serializer.fromJson<String>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String>(entityId),
      'operation': serializer.toJson<String>(operation),
      'payload': serializer.toJson<String>(payload),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'attempts': serializer.toJson<int>(attempts),
      'lastError': serializer.toJson<String?>(lastError),
      'status': serializer.toJson<String>(status),
    };
  }

  SyncQueueEntry copyWith({
    String? id,
    String? entityType,
    String? entityId,
    String? operation,
    String? payload,
    DateTime? createdAt,
    int? attempts,
    Value<String?> lastError = const Value.absent(),
    String? status,
  }) => SyncQueueEntry(
    id: id ?? this.id,
    entityType: entityType ?? this.entityType,
    entityId: entityId ?? this.entityId,
    operation: operation ?? this.operation,
    payload: payload ?? this.payload,
    createdAt: createdAt ?? this.createdAt,
    attempts: attempts ?? this.attempts,
    lastError: lastError.present ? lastError.value : this.lastError,
    status: status ?? this.status,
  );
  SyncQueueEntry copyWithCompanion(SyncQueueCompanion data) {
    return SyncQueueEntry(
      id: data.id.present ? data.id.value : this.id,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      operation: data.operation.present ? data.operation.value : this.operation,
      payload: data.payload.present ? data.payload.value : this.payload,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueEntry(')
          ..write('id: $id, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('operation: $operation, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    entityType,
    entityId,
    operation,
    payload,
    createdAt,
    attempts,
    lastError,
    status,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncQueueEntry &&
          other.id == this.id &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.operation == this.operation &&
          other.payload == this.payload &&
          other.createdAt == this.createdAt &&
          other.attempts == this.attempts &&
          other.lastError == this.lastError &&
          other.status == this.status);
}

class SyncQueueCompanion extends UpdateCompanion<SyncQueueEntry> {
  final Value<String> id;
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<String> operation;
  final Value<String> payload;
  final Value<DateTime> createdAt;
  final Value<int> attempts;
  final Value<String?> lastError;
  final Value<String> status;
  final Value<int> rowid;
  const SyncQueueCompanion({
    this.id = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.operation = const Value.absent(),
    this.payload = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncQueueCompanion.insert({
    required String id,
    required String entityType,
    required String entityId,
    required String operation,
    required String payload,
    required DateTime createdAt,
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       entityType = Value(entityType),
       entityId = Value(entityId),
       operation = Value(operation),
       payload = Value(payload),
       createdAt = Value(createdAt);
  static Insertable<SyncQueueEntry> custom({
    Expression<String>? id,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<String>? operation,
    Expression<String>? payload,
    Expression<DateTime>? createdAt,
    Expression<int>? attempts,
    Expression<String>? lastError,
    Expression<String>? status,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (operation != null) 'operation': operation,
      if (payload != null) 'payload': payload,
      if (createdAt != null) 'created_at': createdAt,
      if (attempts != null) 'attempts': attempts,
      if (lastError != null) 'last_error': lastError,
      if (status != null) 'status': status,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncQueueCompanion copyWith({
    Value<String>? id,
    Value<String>? entityType,
    Value<String>? entityId,
    Value<String>? operation,
    Value<String>? payload,
    Value<DateTime>? createdAt,
    Value<int>? attempts,
    Value<String?>? lastError,
    Value<String>? status,
    Value<int>? rowid,
  }) {
    return SyncQueueCompanion(
      id: id ?? this.id,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      operation: operation ?? this.operation,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
      status: status ?? this.status,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (operation.present) {
      map['operation'] = Variable<String>(operation.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueCompanion(')
          ..write('id: $id, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('operation: $operation, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('status: $status, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $VoiceNotesTable extends VoiceNotes
    with TableInfo<$VoiceNotesTable, VoiceNoteEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VoiceNotesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _personIdMeta = const VerificationMeta(
    'personId',
  );
  @override
  late final GeneratedColumn<String> personId = GeneratedColumn<String>(
    'person_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES people (id)',
    ),
  );
  static const VerificationMeta _visitIdMeta = const VerificationMeta(
    'visitId',
  );
  @override
  late final GeneratedColumn<String> visitId = GeneratedColumn<String>(
    'visit_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES visits (id)',
    ),
  );
  static const VerificationMeta _studyIdMeta = const VerificationMeta(
    'studyId',
  );
  @override
  late final GeneratedColumn<String> studyId = GeneratedColumn<String>(
    'study_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES bible_studies (id)',
    ),
  );
  static const VerificationMeta _audioFilePathMeta = const VerificationMeta(
    'audioFilePath',
  );
  @override
  late final GeneratedColumn<String> audioFilePath = GeneratedColumn<String>(
    'audio_file_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _audioDurationSecondsMeta =
      const VerificationMeta('audioDurationSeconds');
  @override
  late final GeneratedColumn<int> audioDurationSeconds = GeneratedColumn<int>(
    'audio_duration_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _transcriptionMeta = const VerificationMeta(
    'transcription',
  );
  @override
  late final GeneratedColumn<String> transcription = GeneratedColumn<String>(
    'transcription',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _detectedLessonMeta = const VerificationMeta(
    'detectedLesson',
  );
  @override
  late final GeneratedColumn<int> detectedLesson = GeneratedColumn<int>(
    'detected_lesson',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _detectedPointMeta = const VerificationMeta(
    'detectedPoint',
  );
  @override
  late final GeneratedColumn<int> detectedPoint = GeneratedColumn<int>(
    'detected_point',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _extractedPendingDoubtMeta =
      const VerificationMeta('extractedPendingDoubt');
  @override
  late final GeneratedColumn<String> extractedPendingDoubt =
      GeneratedColumn<String>(
        'extracted_pending_doubt',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _extractedEmpathyNoteMeta =
      const VerificationMeta('extractedEmpathyNote');
  @override
  late final GeneratedColumn<String> extractedEmpathyNote =
      GeneratedColumn<String>(
        'extracted_empathy_note',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    personId,
    visitId,
    studyId,
    audioFilePath,
    audioDurationSeconds,
    transcription,
    detectedLesson,
    detectedPoint,
    extractedPendingDoubt,
    extractedEmpathyNote,
    createdAt,
    updatedAt,
    deletedAt,
    revision,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'voice_notes';
  @override
  VerificationContext validateIntegrity(
    Insertable<VoiceNoteEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('person_id')) {
      context.handle(
        _personIdMeta,
        personId.isAcceptableOrUnknown(data['person_id']!, _personIdMeta),
      );
    } else if (isInserting) {
      context.missing(_personIdMeta);
    }
    if (data.containsKey('visit_id')) {
      context.handle(
        _visitIdMeta,
        visitId.isAcceptableOrUnknown(data['visit_id']!, _visitIdMeta),
      );
    }
    if (data.containsKey('study_id')) {
      context.handle(
        _studyIdMeta,
        studyId.isAcceptableOrUnknown(data['study_id']!, _studyIdMeta),
      );
    }
    if (data.containsKey('audio_file_path')) {
      context.handle(
        _audioFilePathMeta,
        audioFilePath.isAcceptableOrUnknown(
          data['audio_file_path']!,
          _audioFilePathMeta,
        ),
      );
    }
    if (data.containsKey('audio_duration_seconds')) {
      context.handle(
        _audioDurationSecondsMeta,
        audioDurationSeconds.isAcceptableOrUnknown(
          data['audio_duration_seconds']!,
          _audioDurationSecondsMeta,
        ),
      );
    }
    if (data.containsKey('transcription')) {
      context.handle(
        _transcriptionMeta,
        transcription.isAcceptableOrUnknown(
          data['transcription']!,
          _transcriptionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_transcriptionMeta);
    }
    if (data.containsKey('detected_lesson')) {
      context.handle(
        _detectedLessonMeta,
        detectedLesson.isAcceptableOrUnknown(
          data['detected_lesson']!,
          _detectedLessonMeta,
        ),
      );
    }
    if (data.containsKey('detected_point')) {
      context.handle(
        _detectedPointMeta,
        detectedPoint.isAcceptableOrUnknown(
          data['detected_point']!,
          _detectedPointMeta,
        ),
      );
    }
    if (data.containsKey('extracted_pending_doubt')) {
      context.handle(
        _extractedPendingDoubtMeta,
        extractedPendingDoubt.isAcceptableOrUnknown(
          data['extracted_pending_doubt']!,
          _extractedPendingDoubtMeta,
        ),
      );
    }
    if (data.containsKey('extracted_empathy_note')) {
      context.handle(
        _extractedEmpathyNoteMeta,
        extractedEmpathyNote.isAcceptableOrUnknown(
          data['extracted_empathy_note']!,
          _extractedEmpathyNoteMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VoiceNoteEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VoiceNoteEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      personId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}person_id'],
      )!,
      visitId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}visit_id'],
      ),
      studyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}study_id'],
      ),
      audioFilePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_file_path'],
      ),
      audioDurationSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}audio_duration_seconds'],
      )!,
      transcription: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transcription'],
      )!,
      detectedLesson: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}detected_lesson'],
      ),
      detectedPoint: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}detected_point'],
      ),
      extractedPendingDoubt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}extracted_pending_doubt'],
      ),
      extractedEmpathyNote: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}extracted_empathy_note'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
    );
  }

  @override
  $VoiceNotesTable createAlias(String alias) {
    return $VoiceNotesTable(attachedDatabase, alias);
  }
}

class VoiceNoteEntry extends DataClass implements Insertable<VoiceNoteEntry> {
  final String id;
  final String personId;
  final String? visitId;
  final String? studyId;
  final String? audioFilePath;
  final int audioDurationSeconds;
  final String transcription;
  final int? detectedLesson;
  final int? detectedPoint;
  final String? extractedPendingDoubt;
  final String? extractedEmpathyNote;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int revision;
  const VoiceNoteEntry({
    required this.id,
    required this.personId,
    this.visitId,
    this.studyId,
    this.audioFilePath,
    required this.audioDurationSeconds,
    required this.transcription,
    this.detectedLesson,
    this.detectedPoint,
    this.extractedPendingDoubt,
    this.extractedEmpathyNote,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.revision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['person_id'] = Variable<String>(personId);
    if (!nullToAbsent || visitId != null) {
      map['visit_id'] = Variable<String>(visitId);
    }
    if (!nullToAbsent || studyId != null) {
      map['study_id'] = Variable<String>(studyId);
    }
    if (!nullToAbsent || audioFilePath != null) {
      map['audio_file_path'] = Variable<String>(audioFilePath);
    }
    map['audio_duration_seconds'] = Variable<int>(audioDurationSeconds);
    map['transcription'] = Variable<String>(transcription);
    if (!nullToAbsent || detectedLesson != null) {
      map['detected_lesson'] = Variable<int>(detectedLesson);
    }
    if (!nullToAbsent || detectedPoint != null) {
      map['detected_point'] = Variable<int>(detectedPoint);
    }
    if (!nullToAbsent || extractedPendingDoubt != null) {
      map['extracted_pending_doubt'] = Variable<String>(extractedPendingDoubt);
    }
    if (!nullToAbsent || extractedEmpathyNote != null) {
      map['extracted_empathy_note'] = Variable<String>(extractedEmpathyNote);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['revision'] = Variable<int>(revision);
    return map;
  }

  VoiceNotesCompanion toCompanion(bool nullToAbsent) {
    return VoiceNotesCompanion(
      id: Value(id),
      personId: Value(personId),
      visitId: visitId == null && nullToAbsent
          ? const Value.absent()
          : Value(visitId),
      studyId: studyId == null && nullToAbsent
          ? const Value.absent()
          : Value(studyId),
      audioFilePath: audioFilePath == null && nullToAbsent
          ? const Value.absent()
          : Value(audioFilePath),
      audioDurationSeconds: Value(audioDurationSeconds),
      transcription: Value(transcription),
      detectedLesson: detectedLesson == null && nullToAbsent
          ? const Value.absent()
          : Value(detectedLesson),
      detectedPoint: detectedPoint == null && nullToAbsent
          ? const Value.absent()
          : Value(detectedPoint),
      extractedPendingDoubt: extractedPendingDoubt == null && nullToAbsent
          ? const Value.absent()
          : Value(extractedPendingDoubt),
      extractedEmpathyNote: extractedEmpathyNote == null && nullToAbsent
          ? const Value.absent()
          : Value(extractedEmpathyNote),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      revision: Value(revision),
    );
  }

  factory VoiceNoteEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VoiceNoteEntry(
      id: serializer.fromJson<String>(json['id']),
      personId: serializer.fromJson<String>(json['personId']),
      visitId: serializer.fromJson<String?>(json['visitId']),
      studyId: serializer.fromJson<String?>(json['studyId']),
      audioFilePath: serializer.fromJson<String?>(json['audioFilePath']),
      audioDurationSeconds: serializer.fromJson<int>(
        json['audioDurationSeconds'],
      ),
      transcription: serializer.fromJson<String>(json['transcription']),
      detectedLesson: serializer.fromJson<int?>(json['detectedLesson']),
      detectedPoint: serializer.fromJson<int?>(json['detectedPoint']),
      extractedPendingDoubt: serializer.fromJson<String?>(
        json['extractedPendingDoubt'],
      ),
      extractedEmpathyNote: serializer.fromJson<String?>(
        json['extractedEmpathyNote'],
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      revision: serializer.fromJson<int>(json['revision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'personId': serializer.toJson<String>(personId),
      'visitId': serializer.toJson<String?>(visitId),
      'studyId': serializer.toJson<String?>(studyId),
      'audioFilePath': serializer.toJson<String?>(audioFilePath),
      'audioDurationSeconds': serializer.toJson<int>(audioDurationSeconds),
      'transcription': serializer.toJson<String>(transcription),
      'detectedLesson': serializer.toJson<int?>(detectedLesson),
      'detectedPoint': serializer.toJson<int?>(detectedPoint),
      'extractedPendingDoubt': serializer.toJson<String?>(
        extractedPendingDoubt,
      ),
      'extractedEmpathyNote': serializer.toJson<String?>(extractedEmpathyNote),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'revision': serializer.toJson<int>(revision),
    };
  }

  VoiceNoteEntry copyWith({
    String? id,
    String? personId,
    Value<String?> visitId = const Value.absent(),
    Value<String?> studyId = const Value.absent(),
    Value<String?> audioFilePath = const Value.absent(),
    int? audioDurationSeconds,
    String? transcription,
    Value<int?> detectedLesson = const Value.absent(),
    Value<int?> detectedPoint = const Value.absent(),
    Value<String?> extractedPendingDoubt = const Value.absent(),
    Value<String?> extractedEmpathyNote = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    int? revision,
  }) => VoiceNoteEntry(
    id: id ?? this.id,
    personId: personId ?? this.personId,
    visitId: visitId.present ? visitId.value : this.visitId,
    studyId: studyId.present ? studyId.value : this.studyId,
    audioFilePath: audioFilePath.present
        ? audioFilePath.value
        : this.audioFilePath,
    audioDurationSeconds: audioDurationSeconds ?? this.audioDurationSeconds,
    transcription: transcription ?? this.transcription,
    detectedLesson: detectedLesson.present
        ? detectedLesson.value
        : this.detectedLesson,
    detectedPoint: detectedPoint.present
        ? detectedPoint.value
        : this.detectedPoint,
    extractedPendingDoubt: extractedPendingDoubt.present
        ? extractedPendingDoubt.value
        : this.extractedPendingDoubt,
    extractedEmpathyNote: extractedEmpathyNote.present
        ? extractedEmpathyNote.value
        : this.extractedEmpathyNote,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    revision: revision ?? this.revision,
  );
  VoiceNoteEntry copyWithCompanion(VoiceNotesCompanion data) {
    return VoiceNoteEntry(
      id: data.id.present ? data.id.value : this.id,
      personId: data.personId.present ? data.personId.value : this.personId,
      visitId: data.visitId.present ? data.visitId.value : this.visitId,
      studyId: data.studyId.present ? data.studyId.value : this.studyId,
      audioFilePath: data.audioFilePath.present
          ? data.audioFilePath.value
          : this.audioFilePath,
      audioDurationSeconds: data.audioDurationSeconds.present
          ? data.audioDurationSeconds.value
          : this.audioDurationSeconds,
      transcription: data.transcription.present
          ? data.transcription.value
          : this.transcription,
      detectedLesson: data.detectedLesson.present
          ? data.detectedLesson.value
          : this.detectedLesson,
      detectedPoint: data.detectedPoint.present
          ? data.detectedPoint.value
          : this.detectedPoint,
      extractedPendingDoubt: data.extractedPendingDoubt.present
          ? data.extractedPendingDoubt.value
          : this.extractedPendingDoubt,
      extractedEmpathyNote: data.extractedEmpathyNote.present
          ? data.extractedEmpathyNote.value
          : this.extractedEmpathyNote,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      revision: data.revision.present ? data.revision.value : this.revision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VoiceNoteEntry(')
          ..write('id: $id, ')
          ..write('personId: $personId, ')
          ..write('visitId: $visitId, ')
          ..write('studyId: $studyId, ')
          ..write('audioFilePath: $audioFilePath, ')
          ..write('audioDurationSeconds: $audioDurationSeconds, ')
          ..write('transcription: $transcription, ')
          ..write('detectedLesson: $detectedLesson, ')
          ..write('detectedPoint: $detectedPoint, ')
          ..write('extractedPendingDoubt: $extractedPendingDoubt, ')
          ..write('extractedEmpathyNote: $extractedEmpathyNote, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    personId,
    visitId,
    studyId,
    audioFilePath,
    audioDurationSeconds,
    transcription,
    detectedLesson,
    detectedPoint,
    extractedPendingDoubt,
    extractedEmpathyNote,
    createdAt,
    updatedAt,
    deletedAt,
    revision,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VoiceNoteEntry &&
          other.id == this.id &&
          other.personId == this.personId &&
          other.visitId == this.visitId &&
          other.studyId == this.studyId &&
          other.audioFilePath == this.audioFilePath &&
          other.audioDurationSeconds == this.audioDurationSeconds &&
          other.transcription == this.transcription &&
          other.detectedLesson == this.detectedLesson &&
          other.detectedPoint == this.detectedPoint &&
          other.extractedPendingDoubt == this.extractedPendingDoubt &&
          other.extractedEmpathyNote == this.extractedEmpathyNote &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.revision == this.revision);
}

class VoiceNotesCompanion extends UpdateCompanion<VoiceNoteEntry> {
  final Value<String> id;
  final Value<String> personId;
  final Value<String?> visitId;
  final Value<String?> studyId;
  final Value<String?> audioFilePath;
  final Value<int> audioDurationSeconds;
  final Value<String> transcription;
  final Value<int?> detectedLesson;
  final Value<int?> detectedPoint;
  final Value<String?> extractedPendingDoubt;
  final Value<String?> extractedEmpathyNote;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> revision;
  final Value<int> rowid;
  const VoiceNotesCompanion({
    this.id = const Value.absent(),
    this.personId = const Value.absent(),
    this.visitId = const Value.absent(),
    this.studyId = const Value.absent(),
    this.audioFilePath = const Value.absent(),
    this.audioDurationSeconds = const Value.absent(),
    this.transcription = const Value.absent(),
    this.detectedLesson = const Value.absent(),
    this.detectedPoint = const Value.absent(),
    this.extractedPendingDoubt = const Value.absent(),
    this.extractedEmpathyNote = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VoiceNotesCompanion.insert({
    required String id,
    required String personId,
    this.visitId = const Value.absent(),
    this.studyId = const Value.absent(),
    this.audioFilePath = const Value.absent(),
    this.audioDurationSeconds = const Value.absent(),
    required String transcription,
    this.detectedLesson = const Value.absent(),
    this.detectedPoint = const Value.absent(),
    this.extractedPendingDoubt = const Value.absent(),
    this.extractedEmpathyNote = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       personId = Value(personId),
       transcription = Value(transcription),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<VoiceNoteEntry> custom({
    Expression<String>? id,
    Expression<String>? personId,
    Expression<String>? visitId,
    Expression<String>? studyId,
    Expression<String>? audioFilePath,
    Expression<int>? audioDurationSeconds,
    Expression<String>? transcription,
    Expression<int>? detectedLesson,
    Expression<int>? detectedPoint,
    Expression<String>? extractedPendingDoubt,
    Expression<String>? extractedEmpathyNote,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? revision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (personId != null) 'person_id': personId,
      if (visitId != null) 'visit_id': visitId,
      if (studyId != null) 'study_id': studyId,
      if (audioFilePath != null) 'audio_file_path': audioFilePath,
      if (audioDurationSeconds != null)
        'audio_duration_seconds': audioDurationSeconds,
      if (transcription != null) 'transcription': transcription,
      if (detectedLesson != null) 'detected_lesson': detectedLesson,
      if (detectedPoint != null) 'detected_point': detectedPoint,
      if (extractedPendingDoubt != null)
        'extracted_pending_doubt': extractedPendingDoubt,
      if (extractedEmpathyNote != null)
        'extracted_empathy_note': extractedEmpathyNote,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (revision != null) 'revision': revision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VoiceNotesCompanion copyWith({
    Value<String>? id,
    Value<String>? personId,
    Value<String?>? visitId,
    Value<String?>? studyId,
    Value<String?>? audioFilePath,
    Value<int>? audioDurationSeconds,
    Value<String>? transcription,
    Value<int?>? detectedLesson,
    Value<int?>? detectedPoint,
    Value<String?>? extractedPendingDoubt,
    Value<String?>? extractedEmpathyNote,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? revision,
    Value<int>? rowid,
  }) {
    return VoiceNotesCompanion(
      id: id ?? this.id,
      personId: personId ?? this.personId,
      visitId: visitId ?? this.visitId,
      studyId: studyId ?? this.studyId,
      audioFilePath: audioFilePath ?? this.audioFilePath,
      audioDurationSeconds: audioDurationSeconds ?? this.audioDurationSeconds,
      transcription: transcription ?? this.transcription,
      detectedLesson: detectedLesson ?? this.detectedLesson,
      detectedPoint: detectedPoint ?? this.detectedPoint,
      extractedPendingDoubt:
          extractedPendingDoubt ?? this.extractedPendingDoubt,
      extractedEmpathyNote: extractedEmpathyNote ?? this.extractedEmpathyNote,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      revision: revision ?? this.revision,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (personId.present) {
      map['person_id'] = Variable<String>(personId.value);
    }
    if (visitId.present) {
      map['visit_id'] = Variable<String>(visitId.value);
    }
    if (studyId.present) {
      map['study_id'] = Variable<String>(studyId.value);
    }
    if (audioFilePath.present) {
      map['audio_file_path'] = Variable<String>(audioFilePath.value);
    }
    if (audioDurationSeconds.present) {
      map['audio_duration_seconds'] = Variable<int>(audioDurationSeconds.value);
    }
    if (transcription.present) {
      map['transcription'] = Variable<String>(transcription.value);
    }
    if (detectedLesson.present) {
      map['detected_lesson'] = Variable<int>(detectedLesson.value);
    }
    if (detectedPoint.present) {
      map['detected_point'] = Variable<int>(detectedPoint.value);
    }
    if (extractedPendingDoubt.present) {
      map['extracted_pending_doubt'] = Variable<String>(
        extractedPendingDoubt.value,
      );
    }
    if (extractedEmpathyNote.present) {
      map['extracted_empathy_note'] = Variable<String>(
        extractedEmpathyNote.value,
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VoiceNotesCompanion(')
          ..write('id: $id, ')
          ..write('personId: $personId, ')
          ..write('visitId: $visitId, ')
          ..write('studyId: $studyId, ')
          ..write('audioFilePath: $audioFilePath, ')
          ..write('audioDurationSeconds: $audioDurationSeconds, ')
          ..write('transcription: $transcription, ')
          ..write('detectedLesson: $detectedLesson, ')
          ..write('detectedPoint: $detectedPoint, ')
          ..write('extractedPendingDoubt: $extractedPendingDoubt, ')
          ..write('extractedEmpathyNote: $extractedEmpathyNote, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PhoneContactsTable extends PhoneContacts
    with TableInfo<$PhoneContactsTable, PhoneContactEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PhoneContactsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _secondaryPhoneMeta = const VerificationMeta(
    'secondaryPhone',
  );
  @override
  late final GeneratedColumn<String> secondaryPhone = GeneratedColumn<String>(
    'secondary_phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hasWhatsappMeta = const VerificationMeta(
    'hasWhatsapp',
  );
  @override
  late final GeneratedColumn<bool> hasWhatsapp = GeneratedColumn<bool>(
    'has_whatsapp',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_whatsapp" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _whatsappInfoMeta = const VerificationMeta(
    'whatsappInfo',
  );
  @override
  late final GeneratedColumn<String> whatsappInfo = GeneratedColumn<String>(
    'whatsapp_info',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hasSocialMeta = const VerificationMeta(
    'hasSocial',
  );
  @override
  late final GeneratedColumn<bool> hasSocial = GeneratedColumn<bool>(
    'has_social',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_social" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _socialPlatformMeta = const VerificationMeta(
    'socialPlatform',
  );
  @override
  late final GeneratedColumn<String> socialPlatform = GeneratedColumn<String>(
    'social_platform',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _socialHandleMeta = const VerificationMeta(
    'socialHandle',
  );
  @override
  late final GeneratedColumn<String> socialHandle = GeneratedColumn<String>(
    'social_handle',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
    'tags',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _originMeta = const VerificationMeta('origin');
  @override
  late final GeneratedColumn<String> origin = GeneratedColumn<String>(
    'origin',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Informal'),
  );
  static const VerificationMeta _convertedPersonIdMeta = const VerificationMeta(
    'convertedPersonId',
  );
  @override
  late final GeneratedColumn<String> convertedPersonId =
      GeneratedColumn<String>(
        'converted_person_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES people (id)',
        ),
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    phone,
    secondaryPhone,
    hasWhatsapp,
    whatsappInfo,
    hasSocial,
    socialPlatform,
    socialHandle,
    notes,
    tags,
    origin,
    convertedPersonId,
    createdAt,
    updatedAt,
    deletedAt,
    revision,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'phone_contacts';
  @override
  VerificationContext validateIntegrity(
    Insertable<PhoneContactEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    } else if (isInserting) {
      context.missing(_phoneMeta);
    }
    if (data.containsKey('secondary_phone')) {
      context.handle(
        _secondaryPhoneMeta,
        secondaryPhone.isAcceptableOrUnknown(
          data['secondary_phone']!,
          _secondaryPhoneMeta,
        ),
      );
    }
    if (data.containsKey('has_whatsapp')) {
      context.handle(
        _hasWhatsappMeta,
        hasWhatsapp.isAcceptableOrUnknown(
          data['has_whatsapp']!,
          _hasWhatsappMeta,
        ),
      );
    }
    if (data.containsKey('whatsapp_info')) {
      context.handle(
        _whatsappInfoMeta,
        whatsappInfo.isAcceptableOrUnknown(
          data['whatsapp_info']!,
          _whatsappInfoMeta,
        ),
      );
    }
    if (data.containsKey('has_social')) {
      context.handle(
        _hasSocialMeta,
        hasSocial.isAcceptableOrUnknown(data['has_social']!, _hasSocialMeta),
      );
    }
    if (data.containsKey('social_platform')) {
      context.handle(
        _socialPlatformMeta,
        socialPlatform.isAcceptableOrUnknown(
          data['social_platform']!,
          _socialPlatformMeta,
        ),
      );
    }
    if (data.containsKey('social_handle')) {
      context.handle(
        _socialHandleMeta,
        socialHandle.isAcceptableOrUnknown(
          data['social_handle']!,
          _socialHandleMeta,
        ),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('tags')) {
      context.handle(
        _tagsMeta,
        tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta),
      );
    }
    if (data.containsKey('origin')) {
      context.handle(
        _originMeta,
        origin.isAcceptableOrUnknown(data['origin']!, _originMeta),
      );
    }
    if (data.containsKey('converted_person_id')) {
      context.handle(
        _convertedPersonIdMeta,
        convertedPersonId.isAcceptableOrUnknown(
          data['converted_person_id']!,
          _convertedPersonIdMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PhoneContactEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PhoneContactEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      )!,
      secondaryPhone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}secondary_phone'],
      ),
      hasWhatsapp: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_whatsapp'],
      )!,
      whatsappInfo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}whatsapp_info'],
      ),
      hasSocial: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_social'],
      )!,
      socialPlatform: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}social_platform'],
      ),
      socialHandle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}social_handle'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      tags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags'],
      )!,
      origin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin'],
      )!,
      convertedPersonId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}converted_person_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
    );
  }

  @override
  $PhoneContactsTable createAlias(String alias) {
    return $PhoneContactsTable(attachedDatabase, alias);
  }
}

class PhoneContactEntry extends DataClass
    implements Insertable<PhoneContactEntry> {
  final String id;
  final String name;
  final String phone;
  final String? secondaryPhone;
  final bool hasWhatsapp;
  final String? whatsappInfo;
  final bool hasSocial;
  final String? socialPlatform;
  final String? socialHandle;
  final String? notes;
  final String tags;
  final String origin;
  final String? convertedPersonId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int revision;
  const PhoneContactEntry({
    required this.id,
    required this.name,
    required this.phone,
    this.secondaryPhone,
    required this.hasWhatsapp,
    this.whatsappInfo,
    required this.hasSocial,
    this.socialPlatform,
    this.socialHandle,
    this.notes,
    required this.tags,
    required this.origin,
    this.convertedPersonId,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.revision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['phone'] = Variable<String>(phone);
    if (!nullToAbsent || secondaryPhone != null) {
      map['secondary_phone'] = Variable<String>(secondaryPhone);
    }
    map['has_whatsapp'] = Variable<bool>(hasWhatsapp);
    if (!nullToAbsent || whatsappInfo != null) {
      map['whatsapp_info'] = Variable<String>(whatsappInfo);
    }
    map['has_social'] = Variable<bool>(hasSocial);
    if (!nullToAbsent || socialPlatform != null) {
      map['social_platform'] = Variable<String>(socialPlatform);
    }
    if (!nullToAbsent || socialHandle != null) {
      map['social_handle'] = Variable<String>(socialHandle);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['tags'] = Variable<String>(tags);
    map['origin'] = Variable<String>(origin);
    if (!nullToAbsent || convertedPersonId != null) {
      map['converted_person_id'] = Variable<String>(convertedPersonId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['revision'] = Variable<int>(revision);
    return map;
  }

  PhoneContactsCompanion toCompanion(bool nullToAbsent) {
    return PhoneContactsCompanion(
      id: Value(id),
      name: Value(name),
      phone: Value(phone),
      secondaryPhone: secondaryPhone == null && nullToAbsent
          ? const Value.absent()
          : Value(secondaryPhone),
      hasWhatsapp: Value(hasWhatsapp),
      whatsappInfo: whatsappInfo == null && nullToAbsent
          ? const Value.absent()
          : Value(whatsappInfo),
      hasSocial: Value(hasSocial),
      socialPlatform: socialPlatform == null && nullToAbsent
          ? const Value.absent()
          : Value(socialPlatform),
      socialHandle: socialHandle == null && nullToAbsent
          ? const Value.absent()
          : Value(socialHandle),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      tags: Value(tags),
      origin: Value(origin),
      convertedPersonId: convertedPersonId == null && nullToAbsent
          ? const Value.absent()
          : Value(convertedPersonId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      revision: Value(revision),
    );
  }

  factory PhoneContactEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PhoneContactEntry(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      phone: serializer.fromJson<String>(json['phone']),
      secondaryPhone: serializer.fromJson<String?>(json['secondaryPhone']),
      hasWhatsapp: serializer.fromJson<bool>(json['hasWhatsapp']),
      whatsappInfo: serializer.fromJson<String?>(json['whatsappInfo']),
      hasSocial: serializer.fromJson<bool>(json['hasSocial']),
      socialPlatform: serializer.fromJson<String?>(json['socialPlatform']),
      socialHandle: serializer.fromJson<String?>(json['socialHandle']),
      notes: serializer.fromJson<String?>(json['notes']),
      tags: serializer.fromJson<String>(json['tags']),
      origin: serializer.fromJson<String>(json['origin']),
      convertedPersonId: serializer.fromJson<String?>(
        json['convertedPersonId'],
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      revision: serializer.fromJson<int>(json['revision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'phone': serializer.toJson<String>(phone),
      'secondaryPhone': serializer.toJson<String?>(secondaryPhone),
      'hasWhatsapp': serializer.toJson<bool>(hasWhatsapp),
      'whatsappInfo': serializer.toJson<String?>(whatsappInfo),
      'hasSocial': serializer.toJson<bool>(hasSocial),
      'socialPlatform': serializer.toJson<String?>(socialPlatform),
      'socialHandle': serializer.toJson<String?>(socialHandle),
      'notes': serializer.toJson<String?>(notes),
      'tags': serializer.toJson<String>(tags),
      'origin': serializer.toJson<String>(origin),
      'convertedPersonId': serializer.toJson<String?>(convertedPersonId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'revision': serializer.toJson<int>(revision),
    };
  }

  PhoneContactEntry copyWith({
    String? id,
    String? name,
    String? phone,
    Value<String?> secondaryPhone = const Value.absent(),
    bool? hasWhatsapp,
    Value<String?> whatsappInfo = const Value.absent(),
    bool? hasSocial,
    Value<String?> socialPlatform = const Value.absent(),
    Value<String?> socialHandle = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    String? tags,
    String? origin,
    Value<String?> convertedPersonId = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    int? revision,
  }) => PhoneContactEntry(
    id: id ?? this.id,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    secondaryPhone: secondaryPhone.present
        ? secondaryPhone.value
        : this.secondaryPhone,
    hasWhatsapp: hasWhatsapp ?? this.hasWhatsapp,
    whatsappInfo: whatsappInfo.present ? whatsappInfo.value : this.whatsappInfo,
    hasSocial: hasSocial ?? this.hasSocial,
    socialPlatform: socialPlatform.present
        ? socialPlatform.value
        : this.socialPlatform,
    socialHandle: socialHandle.present ? socialHandle.value : this.socialHandle,
    notes: notes.present ? notes.value : this.notes,
    tags: tags ?? this.tags,
    origin: origin ?? this.origin,
    convertedPersonId: convertedPersonId.present
        ? convertedPersonId.value
        : this.convertedPersonId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    revision: revision ?? this.revision,
  );
  PhoneContactEntry copyWithCompanion(PhoneContactsCompanion data) {
    return PhoneContactEntry(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      phone: data.phone.present ? data.phone.value : this.phone,
      secondaryPhone: data.secondaryPhone.present
          ? data.secondaryPhone.value
          : this.secondaryPhone,
      hasWhatsapp: data.hasWhatsapp.present
          ? data.hasWhatsapp.value
          : this.hasWhatsapp,
      whatsappInfo: data.whatsappInfo.present
          ? data.whatsappInfo.value
          : this.whatsappInfo,
      hasSocial: data.hasSocial.present ? data.hasSocial.value : this.hasSocial,
      socialPlatform: data.socialPlatform.present
          ? data.socialPlatform.value
          : this.socialPlatform,
      socialHandle: data.socialHandle.present
          ? data.socialHandle.value
          : this.socialHandle,
      notes: data.notes.present ? data.notes.value : this.notes,
      tags: data.tags.present ? data.tags.value : this.tags,
      origin: data.origin.present ? data.origin.value : this.origin,
      convertedPersonId: data.convertedPersonId.present
          ? data.convertedPersonId.value
          : this.convertedPersonId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      revision: data.revision.present ? data.revision.value : this.revision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PhoneContactEntry(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('phone: $phone, ')
          ..write('secondaryPhone: $secondaryPhone, ')
          ..write('hasWhatsapp: $hasWhatsapp, ')
          ..write('whatsappInfo: $whatsappInfo, ')
          ..write('hasSocial: $hasSocial, ')
          ..write('socialPlatform: $socialPlatform, ')
          ..write('socialHandle: $socialHandle, ')
          ..write('notes: $notes, ')
          ..write('tags: $tags, ')
          ..write('origin: $origin, ')
          ..write('convertedPersonId: $convertedPersonId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    phone,
    secondaryPhone,
    hasWhatsapp,
    whatsappInfo,
    hasSocial,
    socialPlatform,
    socialHandle,
    notes,
    tags,
    origin,
    convertedPersonId,
    createdAt,
    updatedAt,
    deletedAt,
    revision,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PhoneContactEntry &&
          other.id == this.id &&
          other.name == this.name &&
          other.phone == this.phone &&
          other.secondaryPhone == this.secondaryPhone &&
          other.hasWhatsapp == this.hasWhatsapp &&
          other.whatsappInfo == this.whatsappInfo &&
          other.hasSocial == this.hasSocial &&
          other.socialPlatform == this.socialPlatform &&
          other.socialHandle == this.socialHandle &&
          other.notes == this.notes &&
          other.tags == this.tags &&
          other.origin == this.origin &&
          other.convertedPersonId == this.convertedPersonId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.revision == this.revision);
}

class PhoneContactsCompanion extends UpdateCompanion<PhoneContactEntry> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> phone;
  final Value<String?> secondaryPhone;
  final Value<bool> hasWhatsapp;
  final Value<String?> whatsappInfo;
  final Value<bool> hasSocial;
  final Value<String?> socialPlatform;
  final Value<String?> socialHandle;
  final Value<String?> notes;
  final Value<String> tags;
  final Value<String> origin;
  final Value<String?> convertedPersonId;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> revision;
  final Value<int> rowid;
  const PhoneContactsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.phone = const Value.absent(),
    this.secondaryPhone = const Value.absent(),
    this.hasWhatsapp = const Value.absent(),
    this.whatsappInfo = const Value.absent(),
    this.hasSocial = const Value.absent(),
    this.socialPlatform = const Value.absent(),
    this.socialHandle = const Value.absent(),
    this.notes = const Value.absent(),
    this.tags = const Value.absent(),
    this.origin = const Value.absent(),
    this.convertedPersonId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PhoneContactsCompanion.insert({
    required String id,
    required String name,
    required String phone,
    this.secondaryPhone = const Value.absent(),
    this.hasWhatsapp = const Value.absent(),
    this.whatsappInfo = const Value.absent(),
    this.hasSocial = const Value.absent(),
    this.socialPlatform = const Value.absent(),
    this.socialHandle = const Value.absent(),
    this.notes = const Value.absent(),
    this.tags = const Value.absent(),
    this.origin = const Value.absent(),
    this.convertedPersonId = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       phone = Value(phone),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<PhoneContactEntry> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? phone,
    Expression<String>? secondaryPhone,
    Expression<bool>? hasWhatsapp,
    Expression<String>? whatsappInfo,
    Expression<bool>? hasSocial,
    Expression<String>? socialPlatform,
    Expression<String>? socialHandle,
    Expression<String>? notes,
    Expression<String>? tags,
    Expression<String>? origin,
    Expression<String>? convertedPersonId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? revision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (secondaryPhone != null) 'secondary_phone': secondaryPhone,
      if (hasWhatsapp != null) 'has_whatsapp': hasWhatsapp,
      if (whatsappInfo != null) 'whatsapp_info': whatsappInfo,
      if (hasSocial != null) 'has_social': hasSocial,
      if (socialPlatform != null) 'social_platform': socialPlatform,
      if (socialHandle != null) 'social_handle': socialHandle,
      if (notes != null) 'notes': notes,
      if (tags != null) 'tags': tags,
      if (origin != null) 'origin': origin,
      if (convertedPersonId != null) 'converted_person_id': convertedPersonId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (revision != null) 'revision': revision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PhoneContactsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? phone,
    Value<String?>? secondaryPhone,
    Value<bool>? hasWhatsapp,
    Value<String?>? whatsappInfo,
    Value<bool>? hasSocial,
    Value<String?>? socialPlatform,
    Value<String?>? socialHandle,
    Value<String?>? notes,
    Value<String>? tags,
    Value<String>? origin,
    Value<String?>? convertedPersonId,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? revision,
    Value<int>? rowid,
  }) {
    return PhoneContactsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      secondaryPhone: secondaryPhone ?? this.secondaryPhone,
      hasWhatsapp: hasWhatsapp ?? this.hasWhatsapp,
      whatsappInfo: whatsappInfo ?? this.whatsappInfo,
      hasSocial: hasSocial ?? this.hasSocial,
      socialPlatform: socialPlatform ?? this.socialPlatform,
      socialHandle: socialHandle ?? this.socialHandle,
      notes: notes ?? this.notes,
      tags: tags ?? this.tags,
      origin: origin ?? this.origin,
      convertedPersonId: convertedPersonId ?? this.convertedPersonId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      revision: revision ?? this.revision,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (secondaryPhone.present) {
      map['secondary_phone'] = Variable<String>(secondaryPhone.value);
    }
    if (hasWhatsapp.present) {
      map['has_whatsapp'] = Variable<bool>(hasWhatsapp.value);
    }
    if (whatsappInfo.present) {
      map['whatsapp_info'] = Variable<String>(whatsappInfo.value);
    }
    if (hasSocial.present) {
      map['has_social'] = Variable<bool>(hasSocial.value);
    }
    if (socialPlatform.present) {
      map['social_platform'] = Variable<String>(socialPlatform.value);
    }
    if (socialHandle.present) {
      map['social_handle'] = Variable<String>(socialHandle.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (origin.present) {
      map['origin'] = Variable<String>(origin.value);
    }
    if (convertedPersonId.present) {
      map['converted_person_id'] = Variable<String>(convertedPersonId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PhoneContactsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('phone: $phone, ')
          ..write('secondaryPhone: $secondaryPhone, ')
          ..write('hasWhatsapp: $hasWhatsapp, ')
          ..write('whatsappInfo: $whatsappInfo, ')
          ..write('hasSocial: $hasSocial, ')
          ..write('socialPlatform: $socialPlatform, ')
          ..write('socialHandle: $socialHandle, ')
          ..write('notes: $notes, ')
          ..write('tags: $tags, ')
          ..write('origin: $origin, ')
          ..write('convertedPersonId: $convertedPersonId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TerritoryLandmarksTable extends TerritoryLandmarks
    with TableInfo<$TerritoryLandmarksTable, TerritoryLandmarkEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TerritoryLandmarksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addressMeta = const VerificationMeta(
    'address',
  );
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
    'address',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _latitudeMeta = const VerificationMeta(
    'latitude',
  );
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
    'latitude',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _longitudeMeta = const VerificationMeta(
    'longitude',
  );
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
    'longitude',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    category,
    address,
    latitude,
    longitude,
    notes,
    createdAt,
    updatedAt,
    deletedAt,
    revision,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'territory_landmarks';
  @override
  VerificationContext validateIntegrity(
    Insertable<TerritoryLandmarkEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('address')) {
      context.handle(
        _addressMeta,
        address.isAcceptableOrUnknown(data['address']!, _addressMeta),
      );
    }
    if (data.containsKey('latitude')) {
      context.handle(
        _latitudeMeta,
        latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta),
      );
    }
    if (data.containsKey('longitude')) {
      context.handle(
        _longitudeMeta,
        longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TerritoryLandmarkEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TerritoryLandmarkEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      address: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address'],
      ),
      latitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}latitude'],
      ),
      longitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}longitude'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
    );
  }

  @override
  $TerritoryLandmarksTable createAlias(String alias) {
    return $TerritoryLandmarksTable(attachedDatabase, alias);
  }
}

class TerritoryLandmarkEntry extends DataClass
    implements Insertable<TerritoryLandmarkEntry> {
  final String id;
  final String name;
  final String category;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int revision;
  const TerritoryLandmarkEntry({
    required this.id,
    required this.name,
    required this.category,
    this.address,
    this.latitude,
    this.longitude,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.revision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['category'] = Variable<String>(category);
    if (!nullToAbsent || address != null) {
      map['address'] = Variable<String>(address);
    }
    if (!nullToAbsent || latitude != null) {
      map['latitude'] = Variable<double>(latitude);
    }
    if (!nullToAbsent || longitude != null) {
      map['longitude'] = Variable<double>(longitude);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['revision'] = Variable<int>(revision);
    return map;
  }

  TerritoryLandmarksCompanion toCompanion(bool nullToAbsent) {
    return TerritoryLandmarksCompanion(
      id: Value(id),
      name: Value(name),
      category: Value(category),
      address: address == null && nullToAbsent
          ? const Value.absent()
          : Value(address),
      latitude: latitude == null && nullToAbsent
          ? const Value.absent()
          : Value(latitude),
      longitude: longitude == null && nullToAbsent
          ? const Value.absent()
          : Value(longitude),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      revision: Value(revision),
    );
  }

  factory TerritoryLandmarkEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TerritoryLandmarkEntry(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      category: serializer.fromJson<String>(json['category']),
      address: serializer.fromJson<String?>(json['address']),
      latitude: serializer.fromJson<double?>(json['latitude']),
      longitude: serializer.fromJson<double?>(json['longitude']),
      notes: serializer.fromJson<String?>(json['notes']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      revision: serializer.fromJson<int>(json['revision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'category': serializer.toJson<String>(category),
      'address': serializer.toJson<String?>(address),
      'latitude': serializer.toJson<double?>(latitude),
      'longitude': serializer.toJson<double?>(longitude),
      'notes': serializer.toJson<String?>(notes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'revision': serializer.toJson<int>(revision),
    };
  }

  TerritoryLandmarkEntry copyWith({
    String? id,
    String? name,
    String? category,
    Value<String?> address = const Value.absent(),
    Value<double?> latitude = const Value.absent(),
    Value<double?> longitude = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    int? revision,
  }) => TerritoryLandmarkEntry(
    id: id ?? this.id,
    name: name ?? this.name,
    category: category ?? this.category,
    address: address.present ? address.value : this.address,
    latitude: latitude.present ? latitude.value : this.latitude,
    longitude: longitude.present ? longitude.value : this.longitude,
    notes: notes.present ? notes.value : this.notes,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    revision: revision ?? this.revision,
  );
  TerritoryLandmarkEntry copyWithCompanion(TerritoryLandmarksCompanion data) {
    return TerritoryLandmarkEntry(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      category: data.category.present ? data.category.value : this.category,
      address: data.address.present ? data.address.value : this.address,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      revision: data.revision.present ? data.revision.value : this.revision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TerritoryLandmarkEntry(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('category: $category, ')
          ..write('address: $address, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    category,
    address,
    latitude,
    longitude,
    notes,
    createdAt,
    updatedAt,
    deletedAt,
    revision,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TerritoryLandmarkEntry &&
          other.id == this.id &&
          other.name == this.name &&
          other.category == this.category &&
          other.address == this.address &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.revision == this.revision);
}

class TerritoryLandmarksCompanion
    extends UpdateCompanion<TerritoryLandmarkEntry> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> category;
  final Value<String?> address;
  final Value<double?> latitude;
  final Value<double?> longitude;
  final Value<String?> notes;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> revision;
  final Value<int> rowid;
  const TerritoryLandmarksCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.category = const Value.absent(),
    this.address = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TerritoryLandmarksCompanion.insert({
    required String id,
    required String name,
    required String category,
    this.address = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.notes = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       category = Value(category),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<TerritoryLandmarkEntry> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? category,
    Expression<String>? address,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<String>? notes,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? revision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (category != null) 'category': category,
      if (address != null) 'address': address,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (revision != null) 'revision': revision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TerritoryLandmarksCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? category,
    Value<String?>? address,
    Value<double?>? latitude,
    Value<double?>? longitude,
    Value<String?>? notes,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? revision,
    Value<int>? rowid,
  }) {
    return TerritoryLandmarksCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      revision: revision ?? this.revision,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TerritoryLandmarksCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('category: $category, ')
          ..write('address: $address, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppKvStoreTable extends AppKvStore
    with TableInfo<$AppKvStoreTable, AppKvEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppKvStoreTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_kv_store';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppKvEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppKvEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppKvEntry(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
    );
  }

  @override
  $AppKvStoreTable createAlias(String alias) {
    return $AppKvStoreTable(attachedDatabase, alias);
  }
}

class AppKvEntry extends DataClass implements Insertable<AppKvEntry> {
  final String key;
  final String value;
  final DateTime? updatedAt;
  const AppKvEntry({required this.key, required this.value, this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    return map;
  }

  AppKvStoreCompanion toCompanion(bool nullToAbsent) {
    return AppKvStoreCompanion(
      key: Value(key),
      value: Value(value),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory AppKvEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppKvEntry(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
    };
  }

  AppKvEntry copyWith({
    String? key,
    String? value,
    Value<DateTime?> updatedAt = const Value.absent(),
  }) => AppKvEntry(
    key: key ?? this.key,
    value: value ?? this.value,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
  );
  AppKvEntry copyWithCompanion(AppKvStoreCompanion data) {
    return AppKvEntry(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppKvEntry(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppKvEntry &&
          other.key == this.key &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class AppKvStoreCompanion extends UpdateCompanion<AppKvEntry> {
  final Value<String> key;
  final Value<String> value;
  final Value<DateTime?> updatedAt;
  final Value<int> rowid;
  const AppKvStoreCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppKvStoreCompanion.insert({
    required String key,
    required String value,
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<AppKvEntry> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppKvStoreCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<DateTime?>? updatedAt,
    Value<int>? rowid,
  }) {
    return AppKvStoreCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppKvStoreCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FamilyTiesTable extends FamilyTies
    with TableInfo<$FamilyTiesTable, FamilyTieEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FamilyTiesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _personIdMeta = const VerificationMeta(
    'personId',
  );
  @override
  late final GeneratedColumn<String> personId = GeneratedColumn<String>(
    'person_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _relatedPersonIdMeta = const VerificationMeta(
    'relatedPersonId',
  );
  @override
  late final GeneratedColumn<String> relatedPersonId = GeneratedColumn<String>(
    'related_person_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _relatedPersonNameMeta = const VerificationMeta(
    'relatedPersonName',
  );
  @override
  late final GeneratedColumn<String> relatedPersonName =
      GeneratedColumn<String>(
        'related_person_name',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _relationshipTypeMeta = const VerificationMeta(
    'relationshipType',
  );
  @override
  late final GeneratedColumn<String> relationshipType = GeneratedColumn<String>(
    'relationship_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    personId,
    relatedPersonId,
    relatedPersonName,
    relationshipType,
    createdAt,
    updatedAt,
    deletedAt,
    revision,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'family_ties';
  @override
  VerificationContext validateIntegrity(
    Insertable<FamilyTieEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('person_id')) {
      context.handle(
        _personIdMeta,
        personId.isAcceptableOrUnknown(data['person_id']!, _personIdMeta),
      );
    } else if (isInserting) {
      context.missing(_personIdMeta);
    }
    if (data.containsKey('related_person_id')) {
      context.handle(
        _relatedPersonIdMeta,
        relatedPersonId.isAcceptableOrUnknown(
          data['related_person_id']!,
          _relatedPersonIdMeta,
        ),
      );
    }
    if (data.containsKey('related_person_name')) {
      context.handle(
        _relatedPersonNameMeta,
        relatedPersonName.isAcceptableOrUnknown(
          data['related_person_name']!,
          _relatedPersonNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_relatedPersonNameMeta);
    }
    if (data.containsKey('relationship_type')) {
      context.handle(
        _relationshipTypeMeta,
        relationshipType.isAcceptableOrUnknown(
          data['relationship_type']!,
          _relationshipTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_relationshipTypeMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FamilyTieEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FamilyTieEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      personId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}person_id'],
      )!,
      relatedPersonId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}related_person_id'],
      ),
      relatedPersonName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}related_person_name'],
      )!,
      relationshipType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}relationship_type'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
    );
  }

  @override
  $FamilyTiesTable createAlias(String alias) {
    return $FamilyTiesTable(attachedDatabase, alias);
  }
}

class FamilyTieEntry extends DataClass implements Insertable<FamilyTieEntry> {
  final String id;
  final String personId;
  final String? relatedPersonId;
  final String relatedPersonName;
  final String relationshipType;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final int revision;
  const FamilyTieEntry({
    required this.id,
    required this.personId,
    this.relatedPersonId,
    required this.relatedPersonName,
    required this.relationshipType,
    required this.createdAt,
    this.updatedAt,
    this.deletedAt,
    required this.revision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['person_id'] = Variable<String>(personId);
    if (!nullToAbsent || relatedPersonId != null) {
      map['related_person_id'] = Variable<String>(relatedPersonId);
    }
    map['related_person_name'] = Variable<String>(relatedPersonName);
    map['relationship_type'] = Variable<String>(relationshipType);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['revision'] = Variable<int>(revision);
    return map;
  }

  FamilyTiesCompanion toCompanion(bool nullToAbsent) {
    return FamilyTiesCompanion(
      id: Value(id),
      personId: Value(personId),
      relatedPersonId: relatedPersonId == null && nullToAbsent
          ? const Value.absent()
          : Value(relatedPersonId),
      relatedPersonName: Value(relatedPersonName),
      relationshipType: Value(relationshipType),
      createdAt: Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      revision: Value(revision),
    );
  }

  factory FamilyTieEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FamilyTieEntry(
      id: serializer.fromJson<String>(json['id']),
      personId: serializer.fromJson<String>(json['personId']),
      relatedPersonId: serializer.fromJson<String?>(json['relatedPersonId']),
      relatedPersonName: serializer.fromJson<String>(json['relatedPersonName']),
      relationshipType: serializer.fromJson<String>(json['relationshipType']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      revision: serializer.fromJson<int>(json['revision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'personId': serializer.toJson<String>(personId),
      'relatedPersonId': serializer.toJson<String?>(relatedPersonId),
      'relatedPersonName': serializer.toJson<String>(relatedPersonName),
      'relationshipType': serializer.toJson<String>(relationshipType),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'revision': serializer.toJson<int>(revision),
    };
  }

  FamilyTieEntry copyWith({
    String? id,
    String? personId,
    Value<String?> relatedPersonId = const Value.absent(),
    String? relatedPersonName,
    String? relationshipType,
    DateTime? createdAt,
    Value<DateTime?> updatedAt = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
    int? revision,
  }) => FamilyTieEntry(
    id: id ?? this.id,
    personId: personId ?? this.personId,
    relatedPersonId: relatedPersonId.present
        ? relatedPersonId.value
        : this.relatedPersonId,
    relatedPersonName: relatedPersonName ?? this.relatedPersonName,
    relationshipType: relationshipType ?? this.relationshipType,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    revision: revision ?? this.revision,
  );
  FamilyTieEntry copyWithCompanion(FamilyTiesCompanion data) {
    return FamilyTieEntry(
      id: data.id.present ? data.id.value : this.id,
      personId: data.personId.present ? data.personId.value : this.personId,
      relatedPersonId: data.relatedPersonId.present
          ? data.relatedPersonId.value
          : this.relatedPersonId,
      relatedPersonName: data.relatedPersonName.present
          ? data.relatedPersonName.value
          : this.relatedPersonName,
      relationshipType: data.relationshipType.present
          ? data.relationshipType.value
          : this.relationshipType,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      revision: data.revision.present ? data.revision.value : this.revision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FamilyTieEntry(')
          ..write('id: $id, ')
          ..write('personId: $personId, ')
          ..write('relatedPersonId: $relatedPersonId, ')
          ..write('relatedPersonName: $relatedPersonName, ')
          ..write('relationshipType: $relationshipType, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    personId,
    relatedPersonId,
    relatedPersonName,
    relationshipType,
    createdAt,
    updatedAt,
    deletedAt,
    revision,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FamilyTieEntry &&
          other.id == this.id &&
          other.personId == this.personId &&
          other.relatedPersonId == this.relatedPersonId &&
          other.relatedPersonName == this.relatedPersonName &&
          other.relationshipType == this.relationshipType &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.revision == this.revision);
}

class FamilyTiesCompanion extends UpdateCompanion<FamilyTieEntry> {
  final Value<String> id;
  final Value<String> personId;
  final Value<String?> relatedPersonId;
  final Value<String> relatedPersonName;
  final Value<String> relationshipType;
  final Value<DateTime> createdAt;
  final Value<DateTime?> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> revision;
  final Value<int> rowid;
  const FamilyTiesCompanion({
    this.id = const Value.absent(),
    this.personId = const Value.absent(),
    this.relatedPersonId = const Value.absent(),
    this.relatedPersonName = const Value.absent(),
    this.relationshipType = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FamilyTiesCompanion.insert({
    required String id,
    required String personId,
    this.relatedPersonId = const Value.absent(),
    required String relatedPersonName,
    required String relationshipType,
    required DateTime createdAt,
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       personId = Value(personId),
       relatedPersonName = Value(relatedPersonName),
       relationshipType = Value(relationshipType),
       createdAt = Value(createdAt);
  static Insertable<FamilyTieEntry> custom({
    Expression<String>? id,
    Expression<String>? personId,
    Expression<String>? relatedPersonId,
    Expression<String>? relatedPersonName,
    Expression<String>? relationshipType,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? revision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (personId != null) 'person_id': personId,
      if (relatedPersonId != null) 'related_person_id': relatedPersonId,
      if (relatedPersonName != null) 'related_person_name': relatedPersonName,
      if (relationshipType != null) 'relationship_type': relationshipType,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (revision != null) 'revision': revision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FamilyTiesCompanion copyWith({
    Value<String>? id,
    Value<String>? personId,
    Value<String?>? relatedPersonId,
    Value<String>? relatedPersonName,
    Value<String>? relationshipType,
    Value<DateTime>? createdAt,
    Value<DateTime?>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? revision,
    Value<int>? rowid,
  }) {
    return FamilyTiesCompanion(
      id: id ?? this.id,
      personId: personId ?? this.personId,
      relatedPersonId: relatedPersonId ?? this.relatedPersonId,
      relatedPersonName: relatedPersonName ?? this.relatedPersonName,
      relationshipType: relationshipType ?? this.relationshipType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      revision: revision ?? this.revision,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (personId.present) {
      map['person_id'] = Variable<String>(personId.value);
    }
    if (relatedPersonId.present) {
      map['related_person_id'] = Variable<String>(relatedPersonId.value);
    }
    if (relatedPersonName.present) {
      map['related_person_name'] = Variable<String>(relatedPersonName.value);
    }
    if (relationshipType.present) {
      map['relationship_type'] = Variable<String>(relationshipType.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FamilyTiesCompanion(')
          ..write('id: $id, ')
          ..write('personId: $personId, ')
          ..write('relatedPersonId: $relatedPersonId, ')
          ..write('relatedPersonName: $relatedPersonName, ')
          ..write('relationshipType: $relationshipType, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MinistryExperiencesTable extends MinistryExperiences
    with TableInfo<$MinistryExperiencesTable, MinistryExperienceEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MinistryExperiencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mediaUrlsMeta = const VerificationMeta(
    'mediaUrls',
  );
  @override
  late final GeneratedColumn<String> mediaUrls = GeneratedColumn<String>(
    'media_urls',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
    'tags',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _dateTimeFieldMeta = const VerificationMeta(
    'dateTimeField',
  );
  @override
  late final GeneratedColumn<DateTime> dateTimeField =
      GeneratedColumn<DateTime>(
        'date_time',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _locationOrModalityMeta =
      const VerificationMeta('locationOrModality');
  @override
  late final GeneratedColumn<String> locationOrModality =
      GeneratedColumn<String>(
        'location_or_modality',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    content,
    mediaUrls,
    tags,
    dateTimeField,
    locationOrModality,
    createdAt,
    updatedAt,
    deletedAt,
    revision,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ministry_experiences';
  @override
  VerificationContext validateIntegrity(
    Insertable<MinistryExperienceEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('media_urls')) {
      context.handle(
        _mediaUrlsMeta,
        mediaUrls.isAcceptableOrUnknown(data['media_urls']!, _mediaUrlsMeta),
      );
    }
    if (data.containsKey('tags')) {
      context.handle(
        _tagsMeta,
        tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta),
      );
    }
    if (data.containsKey('date_time')) {
      context.handle(
        _dateTimeFieldMeta,
        dateTimeField.isAcceptableOrUnknown(
          data['date_time']!,
          _dateTimeFieldMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dateTimeFieldMeta);
    }
    if (data.containsKey('location_or_modality')) {
      context.handle(
        _locationOrModalityMeta,
        locationOrModality.isAcceptableOrUnknown(
          data['location_or_modality']!,
          _locationOrModalityMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MinistryExperienceEntry map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MinistryExperienceEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      mediaUrls: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_urls'],
      )!,
      tags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags'],
      )!,
      dateTimeField: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date_time'],
      )!,
      locationOrModality: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location_or_modality'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
    );
  }

  @override
  $MinistryExperiencesTable createAlias(String alias) {
    return $MinistryExperiencesTable(attachedDatabase, alias);
  }
}

class MinistryExperienceEntry extends DataClass
    implements Insertable<MinistryExperienceEntry> {
  final String id;
  final String title;
  final String content;
  final String mediaUrls;
  final String tags;
  final DateTime dateTimeField;
  final String? locationOrModality;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int revision;
  const MinistryExperienceEntry({
    required this.id,
    required this.title,
    required this.content,
    required this.mediaUrls,
    required this.tags,
    required this.dateTimeField,
    this.locationOrModality,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.revision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['content'] = Variable<String>(content);
    map['media_urls'] = Variable<String>(mediaUrls);
    map['tags'] = Variable<String>(tags);
    map['date_time'] = Variable<DateTime>(dateTimeField);
    if (!nullToAbsent || locationOrModality != null) {
      map['location_or_modality'] = Variable<String>(locationOrModality);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['revision'] = Variable<int>(revision);
    return map;
  }

  MinistryExperiencesCompanion toCompanion(bool nullToAbsent) {
    return MinistryExperiencesCompanion(
      id: Value(id),
      title: Value(title),
      content: Value(content),
      mediaUrls: Value(mediaUrls),
      tags: Value(tags),
      dateTimeField: Value(dateTimeField),
      locationOrModality: locationOrModality == null && nullToAbsent
          ? const Value.absent()
          : Value(locationOrModality),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      revision: Value(revision),
    );
  }

  factory MinistryExperienceEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MinistryExperienceEntry(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      content: serializer.fromJson<String>(json['content']),
      mediaUrls: serializer.fromJson<String>(json['mediaUrls']),
      tags: serializer.fromJson<String>(json['tags']),
      dateTimeField: serializer.fromJson<DateTime>(json['dateTimeField']),
      locationOrModality: serializer.fromJson<String?>(
        json['locationOrModality'],
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      revision: serializer.fromJson<int>(json['revision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'content': serializer.toJson<String>(content),
      'mediaUrls': serializer.toJson<String>(mediaUrls),
      'tags': serializer.toJson<String>(tags),
      'dateTimeField': serializer.toJson<DateTime>(dateTimeField),
      'locationOrModality': serializer.toJson<String?>(locationOrModality),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'revision': serializer.toJson<int>(revision),
    };
  }

  MinistryExperienceEntry copyWith({
    String? id,
    String? title,
    String? content,
    String? mediaUrls,
    String? tags,
    DateTime? dateTimeField,
    Value<String?> locationOrModality = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    int? revision,
  }) => MinistryExperienceEntry(
    id: id ?? this.id,
    title: title ?? this.title,
    content: content ?? this.content,
    mediaUrls: mediaUrls ?? this.mediaUrls,
    tags: tags ?? this.tags,
    dateTimeField: dateTimeField ?? this.dateTimeField,
    locationOrModality: locationOrModality.present
        ? locationOrModality.value
        : this.locationOrModality,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    revision: revision ?? this.revision,
  );
  MinistryExperienceEntry copyWithCompanion(MinistryExperiencesCompanion data) {
    return MinistryExperienceEntry(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      content: data.content.present ? data.content.value : this.content,
      mediaUrls: data.mediaUrls.present ? data.mediaUrls.value : this.mediaUrls,
      tags: data.tags.present ? data.tags.value : this.tags,
      dateTimeField: data.dateTimeField.present
          ? data.dateTimeField.value
          : this.dateTimeField,
      locationOrModality: data.locationOrModality.present
          ? data.locationOrModality.value
          : this.locationOrModality,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      revision: data.revision.present ? data.revision.value : this.revision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MinistryExperienceEntry(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('mediaUrls: $mediaUrls, ')
          ..write('tags: $tags, ')
          ..write('dateTimeField: $dateTimeField, ')
          ..write('locationOrModality: $locationOrModality, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    content,
    mediaUrls,
    tags,
    dateTimeField,
    locationOrModality,
    createdAt,
    updatedAt,
    deletedAt,
    revision,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MinistryExperienceEntry &&
          other.id == this.id &&
          other.title == this.title &&
          other.content == this.content &&
          other.mediaUrls == this.mediaUrls &&
          other.tags == this.tags &&
          other.dateTimeField == this.dateTimeField &&
          other.locationOrModality == this.locationOrModality &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.revision == this.revision);
}

class MinistryExperiencesCompanion
    extends UpdateCompanion<MinistryExperienceEntry> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> content;
  final Value<String> mediaUrls;
  final Value<String> tags;
  final Value<DateTime> dateTimeField;
  final Value<String?> locationOrModality;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> revision;
  final Value<int> rowid;
  const MinistryExperiencesCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.content = const Value.absent(),
    this.mediaUrls = const Value.absent(),
    this.tags = const Value.absent(),
    this.dateTimeField = const Value.absent(),
    this.locationOrModality = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MinistryExperiencesCompanion.insert({
    required String id,
    required String title,
    required String content,
    this.mediaUrls = const Value.absent(),
    this.tags = const Value.absent(),
    required DateTime dateTimeField,
    this.locationOrModality = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       content = Value(content),
       dateTimeField = Value(dateTimeField),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<MinistryExperienceEntry> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? content,
    Expression<String>? mediaUrls,
    Expression<String>? tags,
    Expression<DateTime>? dateTimeField,
    Expression<String>? locationOrModality,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? revision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (content != null) 'content': content,
      if (mediaUrls != null) 'media_urls': mediaUrls,
      if (tags != null) 'tags': tags,
      if (dateTimeField != null) 'date_time': dateTimeField,
      if (locationOrModality != null)
        'location_or_modality': locationOrModality,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (revision != null) 'revision': revision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MinistryExperiencesCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String>? content,
    Value<String>? mediaUrls,
    Value<String>? tags,
    Value<DateTime>? dateTimeField,
    Value<String?>? locationOrModality,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? revision,
    Value<int>? rowid,
  }) {
    return MinistryExperiencesCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      tags: tags ?? this.tags,
      dateTimeField: dateTimeField ?? this.dateTimeField,
      locationOrModality: locationOrModality ?? this.locationOrModality,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      revision: revision ?? this.revision,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (mediaUrls.present) {
      map['media_urls'] = Variable<String>(mediaUrls.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (dateTimeField.present) {
      map['date_time'] = Variable<DateTime>(dateTimeField.value);
    }
    if (locationOrModality.present) {
      map['location_or_modality'] = Variable<String>(locationOrModality.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MinistryExperiencesCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('mediaUrls: $mediaUrls, ')
          ..write('tags: $tags, ')
          ..write('dateTimeField: $dateTimeField, ')
          ..write('locationOrModality: $locationOrModality, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PersonPhotosTable extends PersonPhotos
    with TableInfo<$PersonPhotosTable, PersonPhotoEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PersonPhotosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _personIdMeta = const VerificationMeta(
    'personId',
  );
  @override
  late final GeneratedColumn<String> personId = GeneratedColumn<String>(
    'person_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _photoTypeMeta = const VerificationMeta(
    'photoType',
  );
  @override
  late final GeneratedColumn<String> photoType = GeneratedColumn<String>(
    'photo_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _imageDataMeta = const VerificationMeta(
    'imageData',
  );
  @override
  late final GeneratedColumn<String> imageData = GeneratedColumn<String>(
    'image_data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    personId,
    photoType,
    imageData,
    createdAt,
    updatedAt,
    deletedAt,
    revision,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'person_photos';
  @override
  VerificationContext validateIntegrity(
    Insertable<PersonPhotoEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('person_id')) {
      context.handle(
        _personIdMeta,
        personId.isAcceptableOrUnknown(data['person_id']!, _personIdMeta),
      );
    } else if (isInserting) {
      context.missing(_personIdMeta);
    }
    if (data.containsKey('photo_type')) {
      context.handle(
        _photoTypeMeta,
        photoType.isAcceptableOrUnknown(data['photo_type']!, _photoTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_photoTypeMeta);
    }
    if (data.containsKey('image_data')) {
      context.handle(
        _imageDataMeta,
        imageData.isAcceptableOrUnknown(data['image_data']!, _imageDataMeta),
      );
    } else if (isInserting) {
      context.missing(_imageDataMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PersonPhotoEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PersonPhotoEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      personId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}person_id'],
      )!,
      photoType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}photo_type'],
      )!,
      imageData: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_data'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
    );
  }

  @override
  $PersonPhotosTable createAlias(String alias) {
    return $PersonPhotosTable(attachedDatabase, alias);
  }
}

class PersonPhotoEntry extends DataClass
    implements Insertable<PersonPhotoEntry> {
  final String id;
  final String personId;
  final String photoType;
  final String imageData;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final int revision;
  const PersonPhotoEntry({
    required this.id,
    required this.personId,
    required this.photoType,
    required this.imageData,
    required this.createdAt,
    this.updatedAt,
    this.deletedAt,
    required this.revision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['person_id'] = Variable<String>(personId);
    map['photo_type'] = Variable<String>(photoType);
    map['image_data'] = Variable<String>(imageData);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['revision'] = Variable<int>(revision);
    return map;
  }

  PersonPhotosCompanion toCompanion(bool nullToAbsent) {
    return PersonPhotosCompanion(
      id: Value(id),
      personId: Value(personId),
      photoType: Value(photoType),
      imageData: Value(imageData),
      createdAt: Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      revision: Value(revision),
    );
  }

  factory PersonPhotoEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PersonPhotoEntry(
      id: serializer.fromJson<String>(json['id']),
      personId: serializer.fromJson<String>(json['personId']),
      photoType: serializer.fromJson<String>(json['photoType']),
      imageData: serializer.fromJson<String>(json['imageData']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      revision: serializer.fromJson<int>(json['revision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'personId': serializer.toJson<String>(personId),
      'photoType': serializer.toJson<String>(photoType),
      'imageData': serializer.toJson<String>(imageData),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'revision': serializer.toJson<int>(revision),
    };
  }

  PersonPhotoEntry copyWith({
    String? id,
    String? personId,
    String? photoType,
    String? imageData,
    DateTime? createdAt,
    Value<DateTime?> updatedAt = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
    int? revision,
  }) => PersonPhotoEntry(
    id: id ?? this.id,
    personId: personId ?? this.personId,
    photoType: photoType ?? this.photoType,
    imageData: imageData ?? this.imageData,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    revision: revision ?? this.revision,
  );
  PersonPhotoEntry copyWithCompanion(PersonPhotosCompanion data) {
    return PersonPhotoEntry(
      id: data.id.present ? data.id.value : this.id,
      personId: data.personId.present ? data.personId.value : this.personId,
      photoType: data.photoType.present ? data.photoType.value : this.photoType,
      imageData: data.imageData.present ? data.imageData.value : this.imageData,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      revision: data.revision.present ? data.revision.value : this.revision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PersonPhotoEntry(')
          ..write('id: $id, ')
          ..write('personId: $personId, ')
          ..write('photoType: $photoType, ')
          ..write('imageData: $imageData, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    personId,
    photoType,
    imageData,
    createdAt,
    updatedAt,
    deletedAt,
    revision,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PersonPhotoEntry &&
          other.id == this.id &&
          other.personId == this.personId &&
          other.photoType == this.photoType &&
          other.imageData == this.imageData &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.revision == this.revision);
}

class PersonPhotosCompanion extends UpdateCompanion<PersonPhotoEntry> {
  final Value<String> id;
  final Value<String> personId;
  final Value<String> photoType;
  final Value<String> imageData;
  final Value<DateTime> createdAt;
  final Value<DateTime?> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> revision;
  final Value<int> rowid;
  const PersonPhotosCompanion({
    this.id = const Value.absent(),
    this.personId = const Value.absent(),
    this.photoType = const Value.absent(),
    this.imageData = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PersonPhotosCompanion.insert({
    required String id,
    required String personId,
    required String photoType,
    required String imageData,
    required DateTime createdAt,
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       personId = Value(personId),
       photoType = Value(photoType),
       imageData = Value(imageData),
       createdAt = Value(createdAt);
  static Insertable<PersonPhotoEntry> custom({
    Expression<String>? id,
    Expression<String>? personId,
    Expression<String>? photoType,
    Expression<String>? imageData,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? revision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (personId != null) 'person_id': personId,
      if (photoType != null) 'photo_type': photoType,
      if (imageData != null) 'image_data': imageData,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (revision != null) 'revision': revision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PersonPhotosCompanion copyWith({
    Value<String>? id,
    Value<String>? personId,
    Value<String>? photoType,
    Value<String>? imageData,
    Value<DateTime>? createdAt,
    Value<DateTime?>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? revision,
    Value<int>? rowid,
  }) {
    return PersonPhotosCompanion(
      id: id ?? this.id,
      personId: personId ?? this.personId,
      photoType: photoType ?? this.photoType,
      imageData: imageData ?? this.imageData,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      revision: revision ?? this.revision,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (personId.present) {
      map['person_id'] = Variable<String>(personId.value);
    }
    if (photoType.present) {
      map['photo_type'] = Variable<String>(photoType.value);
    }
    if (imageData.present) {
      map['image_data'] = Variable<String>(imageData.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PersonPhotosCompanion(')
          ..write('id: $id, ')
          ..write('personId: $personId, ')
          ..write('photoType: $photoType, ')
          ..write('imageData: $imageData, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PersonPublicationsTable extends PersonPublications
    with TableInfo<$PersonPublicationsTable, PersonPublicationEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PersonPublicationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _personIdMeta = const VerificationMeta(
    'personId',
  );
  @override
  late final GeneratedColumn<String> personId = GeneratedColumn<String>(
    'person_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _publicationTitleMeta = const VerificationMeta(
    'publicationTitle',
  );
  @override
  late final GeneratedColumn<String> publicationTitle = GeneratedColumn<String>(
    'publication_title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemTypeMeta = const VerificationMeta(
    'itemType',
  );
  @override
  late final GeneratedColumn<String> itemType = GeneratedColumn<String>(
    'item_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    personId,
    publicationTitle,
    itemType,
    status,
    date,
    notes,
    createdAt,
    updatedAt,
    deletedAt,
    revision,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'person_publications';
  @override
  VerificationContext validateIntegrity(
    Insertable<PersonPublicationEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('person_id')) {
      context.handle(
        _personIdMeta,
        personId.isAcceptableOrUnknown(data['person_id']!, _personIdMeta),
      );
    } else if (isInserting) {
      context.missing(_personIdMeta);
    }
    if (data.containsKey('publication_title')) {
      context.handle(
        _publicationTitleMeta,
        publicationTitle.isAcceptableOrUnknown(
          data['publication_title']!,
          _publicationTitleMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_publicationTitleMeta);
    }
    if (data.containsKey('item_type')) {
      context.handle(
        _itemTypeMeta,
        itemType.isAcceptableOrUnknown(data['item_type']!, _itemTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_itemTypeMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PersonPublicationEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PersonPublicationEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      personId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}person_id'],
      )!,
      publicationTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}publication_title'],
      )!,
      itemType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_type'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
    );
  }

  @override
  $PersonPublicationsTable createAlias(String alias) {
    return $PersonPublicationsTable(attachedDatabase, alias);
  }
}

class PersonPublicationEntry extends DataClass
    implements Insertable<PersonPublicationEntry> {
  final String id;
  final String personId;
  final String publicationTitle;
  final String itemType;
  final String status;
  final String date;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final int revision;
  const PersonPublicationEntry({
    required this.id,
    required this.personId,
    required this.publicationTitle,
    required this.itemType,
    required this.status,
    required this.date,
    this.notes,
    required this.createdAt,
    this.updatedAt,
    this.deletedAt,
    required this.revision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['person_id'] = Variable<String>(personId);
    map['publication_title'] = Variable<String>(publicationTitle);
    map['item_type'] = Variable<String>(itemType);
    map['status'] = Variable<String>(status);
    map['date'] = Variable<String>(date);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['revision'] = Variable<int>(revision);
    return map;
  }

  PersonPublicationsCompanion toCompanion(bool nullToAbsent) {
    return PersonPublicationsCompanion(
      id: Value(id),
      personId: Value(personId),
      publicationTitle: Value(publicationTitle),
      itemType: Value(itemType),
      status: Value(status),
      date: Value(date),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      createdAt: Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      revision: Value(revision),
    );
  }

  factory PersonPublicationEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PersonPublicationEntry(
      id: serializer.fromJson<String>(json['id']),
      personId: serializer.fromJson<String>(json['personId']),
      publicationTitle: serializer.fromJson<String>(json['publicationTitle']),
      itemType: serializer.fromJson<String>(json['itemType']),
      status: serializer.fromJson<String>(json['status']),
      date: serializer.fromJson<String>(json['date']),
      notes: serializer.fromJson<String?>(json['notes']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      revision: serializer.fromJson<int>(json['revision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'personId': serializer.toJson<String>(personId),
      'publicationTitle': serializer.toJson<String>(publicationTitle),
      'itemType': serializer.toJson<String>(itemType),
      'status': serializer.toJson<String>(status),
      'date': serializer.toJson<String>(date),
      'notes': serializer.toJson<String?>(notes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'revision': serializer.toJson<int>(revision),
    };
  }

  PersonPublicationEntry copyWith({
    String? id,
    String? personId,
    String? publicationTitle,
    String? itemType,
    String? status,
    String? date,
    Value<String?> notes = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> updatedAt = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
    int? revision,
  }) => PersonPublicationEntry(
    id: id ?? this.id,
    personId: personId ?? this.personId,
    publicationTitle: publicationTitle ?? this.publicationTitle,
    itemType: itemType ?? this.itemType,
    status: status ?? this.status,
    date: date ?? this.date,
    notes: notes.present ? notes.value : this.notes,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    revision: revision ?? this.revision,
  );
  PersonPublicationEntry copyWithCompanion(PersonPublicationsCompanion data) {
    return PersonPublicationEntry(
      id: data.id.present ? data.id.value : this.id,
      personId: data.personId.present ? data.personId.value : this.personId,
      publicationTitle: data.publicationTitle.present
          ? data.publicationTitle.value
          : this.publicationTitle,
      itemType: data.itemType.present ? data.itemType.value : this.itemType,
      status: data.status.present ? data.status.value : this.status,
      date: data.date.present ? data.date.value : this.date,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      revision: data.revision.present ? data.revision.value : this.revision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PersonPublicationEntry(')
          ..write('id: $id, ')
          ..write('personId: $personId, ')
          ..write('publicationTitle: $publicationTitle, ')
          ..write('itemType: $itemType, ')
          ..write('status: $status, ')
          ..write('date: $date, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    personId,
    publicationTitle,
    itemType,
    status,
    date,
    notes,
    createdAt,
    updatedAt,
    deletedAt,
    revision,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PersonPublicationEntry &&
          other.id == this.id &&
          other.personId == this.personId &&
          other.publicationTitle == this.publicationTitle &&
          other.itemType == this.itemType &&
          other.status == this.status &&
          other.date == this.date &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.revision == this.revision);
}

class PersonPublicationsCompanion
    extends UpdateCompanion<PersonPublicationEntry> {
  final Value<String> id;
  final Value<String> personId;
  final Value<String> publicationTitle;
  final Value<String> itemType;
  final Value<String> status;
  final Value<String> date;
  final Value<String?> notes;
  final Value<DateTime> createdAt;
  final Value<DateTime?> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> revision;
  final Value<int> rowid;
  const PersonPublicationsCompanion({
    this.id = const Value.absent(),
    this.personId = const Value.absent(),
    this.publicationTitle = const Value.absent(),
    this.itemType = const Value.absent(),
    this.status = const Value.absent(),
    this.date = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PersonPublicationsCompanion.insert({
    required String id,
    required String personId,
    required String publicationTitle,
    required String itemType,
    required String status,
    required String date,
    this.notes = const Value.absent(),
    required DateTime createdAt,
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       personId = Value(personId),
       publicationTitle = Value(publicationTitle),
       itemType = Value(itemType),
       status = Value(status),
       date = Value(date),
       createdAt = Value(createdAt);
  static Insertable<PersonPublicationEntry> custom({
    Expression<String>? id,
    Expression<String>? personId,
    Expression<String>? publicationTitle,
    Expression<String>? itemType,
    Expression<String>? status,
    Expression<String>? date,
    Expression<String>? notes,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? revision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (personId != null) 'person_id': personId,
      if (publicationTitle != null) 'publication_title': publicationTitle,
      if (itemType != null) 'item_type': itemType,
      if (status != null) 'status': status,
      if (date != null) 'date': date,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (revision != null) 'revision': revision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PersonPublicationsCompanion copyWith({
    Value<String>? id,
    Value<String>? personId,
    Value<String>? publicationTitle,
    Value<String>? itemType,
    Value<String>? status,
    Value<String>? date,
    Value<String?>? notes,
    Value<DateTime>? createdAt,
    Value<DateTime?>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? revision,
    Value<int>? rowid,
  }) {
    return PersonPublicationsCompanion(
      id: id ?? this.id,
      personId: personId ?? this.personId,
      publicationTitle: publicationTitle ?? this.publicationTitle,
      itemType: itemType ?? this.itemType,
      status: status ?? this.status,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      revision: revision ?? this.revision,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (personId.present) {
      map['person_id'] = Variable<String>(personId.value);
    }
    if (publicationTitle.present) {
      map['publication_title'] = Variable<String>(publicationTitle.value);
    }
    if (itemType.present) {
      map['item_type'] = Variable<String>(itemType.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PersonPublicationsCompanion(')
          ..write('id: $id, ')
          ..write('personId: $personId, ')
          ..write('publicationTitle: $publicationTitle, ')
          ..write('itemType: $itemType, ')
          ..write('status: $status, ')
          ..write('date: $date, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ResearchArticlesTable extends ResearchArticles
    with TableInfo<$ResearchArticlesTable, ResearchArticleEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ResearchArticlesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _summaryMeta = const VerificationMeta(
    'summary',
  );
  @override
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
    'summary',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
    'tags',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _attachmentsMeta = const VerificationMeta(
    'attachments',
  );
  @override
  late final GeneratedColumn<String> attachments = GeneratedColumn<String>(
    'attachments',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    summary,
    content,
    tags,
    attachments,
    createdAt,
    updatedAt,
    deletedAt,
    revision,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'research_articles';
  @override
  VerificationContext validateIntegrity(
    Insertable<ResearchArticleEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('summary')) {
      context.handle(
        _summaryMeta,
        summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta),
      );
    } else if (isInserting) {
      context.missing(_summaryMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('tags')) {
      context.handle(
        _tagsMeta,
        tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta),
      );
    }
    if (data.containsKey('attachments')) {
      context.handle(
        _attachmentsMeta,
        attachments.isAcceptableOrUnknown(
          data['attachments']!,
          _attachmentsMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ResearchArticleEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ResearchArticleEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      summary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      tags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags'],
      )!,
      attachments: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attachments'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
    );
  }

  @override
  $ResearchArticlesTable createAlias(String alias) {
    return $ResearchArticlesTable(attachedDatabase, alias);
  }
}

class ResearchArticleEntry extends DataClass
    implements Insertable<ResearchArticleEntry> {
  final String id;
  final String title;
  final String summary;
  final String content;
  final String tags;
  final String attachments;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int revision;
  const ResearchArticleEntry({
    required this.id,
    required this.title,
    required this.summary,
    required this.content,
    required this.tags,
    required this.attachments,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.revision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['summary'] = Variable<String>(summary);
    map['content'] = Variable<String>(content);
    map['tags'] = Variable<String>(tags);
    map['attachments'] = Variable<String>(attachments);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['revision'] = Variable<int>(revision);
    return map;
  }

  ResearchArticlesCompanion toCompanion(bool nullToAbsent) {
    return ResearchArticlesCompanion(
      id: Value(id),
      title: Value(title),
      summary: Value(summary),
      content: Value(content),
      tags: Value(tags),
      attachments: Value(attachments),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      revision: Value(revision),
    );
  }

  factory ResearchArticleEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ResearchArticleEntry(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      summary: serializer.fromJson<String>(json['summary']),
      content: serializer.fromJson<String>(json['content']),
      tags: serializer.fromJson<String>(json['tags']),
      attachments: serializer.fromJson<String>(json['attachments']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      revision: serializer.fromJson<int>(json['revision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'summary': serializer.toJson<String>(summary),
      'content': serializer.toJson<String>(content),
      'tags': serializer.toJson<String>(tags),
      'attachments': serializer.toJson<String>(attachments),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'revision': serializer.toJson<int>(revision),
    };
  }

  ResearchArticleEntry copyWith({
    String? id,
    String? title,
    String? summary,
    String? content,
    String? tags,
    String? attachments,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    int? revision,
  }) => ResearchArticleEntry(
    id: id ?? this.id,
    title: title ?? this.title,
    summary: summary ?? this.summary,
    content: content ?? this.content,
    tags: tags ?? this.tags,
    attachments: attachments ?? this.attachments,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    revision: revision ?? this.revision,
  );
  ResearchArticleEntry copyWithCompanion(ResearchArticlesCompanion data) {
    return ResearchArticleEntry(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      summary: data.summary.present ? data.summary.value : this.summary,
      content: data.content.present ? data.content.value : this.content,
      tags: data.tags.present ? data.tags.value : this.tags,
      attachments: data.attachments.present
          ? data.attachments.value
          : this.attachments,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      revision: data.revision.present ? data.revision.value : this.revision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ResearchArticleEntry(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('summary: $summary, ')
          ..write('content: $content, ')
          ..write('tags: $tags, ')
          ..write('attachments: $attachments, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    summary,
    content,
    tags,
    attachments,
    createdAt,
    updatedAt,
    deletedAt,
    revision,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ResearchArticleEntry &&
          other.id == this.id &&
          other.title == this.title &&
          other.summary == this.summary &&
          other.content == this.content &&
          other.tags == this.tags &&
          other.attachments == this.attachments &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.revision == this.revision);
}

class ResearchArticlesCompanion extends UpdateCompanion<ResearchArticleEntry> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> summary;
  final Value<String> content;
  final Value<String> tags;
  final Value<String> attachments;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> revision;
  final Value<int> rowid;
  const ResearchArticlesCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.summary = const Value.absent(),
    this.content = const Value.absent(),
    this.tags = const Value.absent(),
    this.attachments = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ResearchArticlesCompanion.insert({
    required String id,
    required String title,
    required String summary,
    required String content,
    this.tags = const Value.absent(),
    this.attachments = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       summary = Value(summary),
       content = Value(content),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ResearchArticleEntry> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? summary,
    Expression<String>? content,
    Expression<String>? tags,
    Expression<String>? attachments,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? revision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (summary != null) 'summary': summary,
      if (content != null) 'content': content,
      if (tags != null) 'tags': tags,
      if (attachments != null) 'attachments': attachments,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (revision != null) 'revision': revision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ResearchArticlesCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String>? summary,
    Value<String>? content,
    Value<String>? tags,
    Value<String>? attachments,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? revision,
    Value<int>? rowid,
  }) {
    return ResearchArticlesCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      content: content ?? this.content,
      tags: tags ?? this.tags,
      attachments: attachments ?? this.attachments,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      revision: revision ?? this.revision,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (attachments.present) {
      map['attachments'] = Variable<String>(attachments.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ResearchArticlesCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('summary: $summary, ')
          ..write('content: $content, ')
          ..write('tags: $tags, ')
          ..write('attachments: $attachments, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ResearchTagsTable extends ResearchTags
    with TableInfo<$ResearchTagsTable, ResearchTagEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ResearchTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    createdAt,
    updatedAt,
    deletedAt,
    revision,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'research_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<ResearchTagEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ResearchTagEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ResearchTagEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
    );
  }

  @override
  $ResearchTagsTable createAlias(String alias) {
    return $ResearchTagsTable(attachedDatabase, alias);
  }
}

class ResearchTagEntry extends DataClass
    implements Insertable<ResearchTagEntry> {
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final int revision;
  const ResearchTagEntry({
    required this.id,
    required this.name,
    required this.createdAt,
    this.updatedAt,
    this.deletedAt,
    required this.revision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['revision'] = Variable<int>(revision);
    return map;
  }

  ResearchTagsCompanion toCompanion(bool nullToAbsent) {
    return ResearchTagsCompanion(
      id: Value(id),
      name: Value(name),
      createdAt: Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      revision: Value(revision),
    );
  }

  factory ResearchTagEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ResearchTagEntry(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      revision: serializer.fromJson<int>(json['revision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'revision': serializer.toJson<int>(revision),
    };
  }

  ResearchTagEntry copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    Value<DateTime?> updatedAt = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
    int? revision,
  }) => ResearchTagEntry(
    id: id ?? this.id,
    name: name ?? this.name,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    revision: revision ?? this.revision,
  );
  ResearchTagEntry copyWithCompanion(ResearchTagsCompanion data) {
    return ResearchTagEntry(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      revision: data.revision.present ? data.revision.value : this.revision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ResearchTagEntry(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, createdAt, updatedAt, deletedAt, revision);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ResearchTagEntry &&
          other.id == this.id &&
          other.name == this.name &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.revision == this.revision);
}

class ResearchTagsCompanion extends UpdateCompanion<ResearchTagEntry> {
  final Value<String> id;
  final Value<String> name;
  final Value<DateTime> createdAt;
  final Value<DateTime?> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> revision;
  final Value<int> rowid;
  const ResearchTagsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ResearchTagsCompanion.insert({
    required String id,
    required String name,
    required DateTime createdAt,
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<ResearchTagEntry> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? revision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (revision != null) 'revision': revision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ResearchTagsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<DateTime>? createdAt,
    Value<DateTime?>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? revision,
    Value<int>? rowid,
  }) {
    return ResearchTagsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      revision: revision ?? this.revision,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ResearchTagsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TerritorySectorsTable extends TerritorySectors
    with TableInfo<$TerritorySectorsTable, TerritorySectorEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TerritorySectorsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    description,
    createdAt,
    updatedAt,
    deletedAt,
    revision,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'territory_sectors';
  @override
  VerificationContext validateIntegrity(
    Insertable<TerritorySectorEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TerritorySectorEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TerritorySectorEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
    );
  }

  @override
  $TerritorySectorsTable createAlias(String alias) {
    return $TerritorySectorsTable(attachedDatabase, alias);
  }
}

class TerritorySectorEntry extends DataClass
    implements Insertable<TerritorySectorEntry> {
  final String id;
  final String name;
  final String? description;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final int revision;
  const TerritorySectorEntry({
    required this.id,
    required this.name,
    this.description,
    required this.createdAt,
    this.updatedAt,
    this.deletedAt,
    required this.revision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['revision'] = Variable<int>(revision);
    return map;
  }

  TerritorySectorsCompanion toCompanion(bool nullToAbsent) {
    return TerritorySectorsCompanion(
      id: Value(id),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      createdAt: Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      revision: Value(revision),
    );
  }

  factory TerritorySectorEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TerritorySectorEntry(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      revision: serializer.fromJson<int>(json['revision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'revision': serializer.toJson<int>(revision),
    };
  }

  TerritorySectorEntry copyWith({
    String? id,
    String? name,
    Value<String?> description = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> updatedAt = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
    int? revision,
  }) => TerritorySectorEntry(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description.present ? description.value : this.description,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    revision: revision ?? this.revision,
  );
  TerritorySectorEntry copyWithCompanion(TerritorySectorsCompanion data) {
    return TerritorySectorEntry(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      revision: data.revision.present ? data.revision.value : this.revision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TerritorySectorEntry(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    description,
    createdAt,
    updatedAt,
    deletedAt,
    revision,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TerritorySectorEntry &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.revision == this.revision);
}

class TerritorySectorsCompanion extends UpdateCompanion<TerritorySectorEntry> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> description;
  final Value<DateTime> createdAt;
  final Value<DateTime?> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> revision;
  final Value<int> rowid;
  const TerritorySectorsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TerritorySectorsCompanion.insert({
    required String id,
    required String name,
    this.description = const Value.absent(),
    required DateTime createdAt,
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<TerritorySectorEntry> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? revision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (revision != null) 'revision': revision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TerritorySectorsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? description,
    Value<DateTime>? createdAt,
    Value<DateTime?>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? revision,
    Value<int>? rowid,
  }) {
    return TerritorySectorsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      revision: revision ?? this.revision,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TerritorySectorsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StudentManualOrderTable extends StudentManualOrder
    with TableInfo<$StudentManualOrderTable, StudentManualOrderEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StudentManualOrderTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _studyIdMeta = const VerificationMeta(
    'studyId',
  );
  @override
  late final GeneratedColumn<String> studyId = GeneratedColumn<String>(
    'study_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _manualIndexMeta = const VerificationMeta(
    'manualIndex',
  );
  @override
  late final GeneratedColumn<int> manualIndex = GeneratedColumn<int>(
    'manual_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    studyId,
    manualIndex,
    updatedAt,
    deletedAt,
    revision,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'student_manual_order';
  @override
  VerificationContext validateIntegrity(
    Insertable<StudentManualOrderEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('study_id')) {
      context.handle(
        _studyIdMeta,
        studyId.isAcceptableOrUnknown(data['study_id']!, _studyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_studyIdMeta);
    }
    if (data.containsKey('manual_index')) {
      context.handle(
        _manualIndexMeta,
        manualIndex.isAcceptableOrUnknown(
          data['manual_index']!,
          _manualIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_manualIndexMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {studyId};
  @override
  StudentManualOrderEntry map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StudentManualOrderEntry(
      studyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}study_id'],
      )!,
      manualIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}manual_index'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
    );
  }

  @override
  $StudentManualOrderTable createAlias(String alias) {
    return $StudentManualOrderTable(attachedDatabase, alias);
  }
}

class StudentManualOrderEntry extends DataClass
    implements Insertable<StudentManualOrderEntry> {
  final String studyId;
  final int manualIndex;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final int revision;
  const StudentManualOrderEntry({
    required this.studyId,
    required this.manualIndex,
    this.updatedAt,
    this.deletedAt,
    required this.revision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['study_id'] = Variable<String>(studyId);
    map['manual_index'] = Variable<int>(manualIndex);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['revision'] = Variable<int>(revision);
    return map;
  }

  StudentManualOrderCompanion toCompanion(bool nullToAbsent) {
    return StudentManualOrderCompanion(
      studyId: Value(studyId),
      manualIndex: Value(manualIndex),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      revision: Value(revision),
    );
  }

  factory StudentManualOrderEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StudentManualOrderEntry(
      studyId: serializer.fromJson<String>(json['studyId']),
      manualIndex: serializer.fromJson<int>(json['manualIndex']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      revision: serializer.fromJson<int>(json['revision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'studyId': serializer.toJson<String>(studyId),
      'manualIndex': serializer.toJson<int>(manualIndex),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'revision': serializer.toJson<int>(revision),
    };
  }

  StudentManualOrderEntry copyWith({
    String? studyId,
    int? manualIndex,
    Value<DateTime?> updatedAt = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
    int? revision,
  }) => StudentManualOrderEntry(
    studyId: studyId ?? this.studyId,
    manualIndex: manualIndex ?? this.manualIndex,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    revision: revision ?? this.revision,
  );
  StudentManualOrderEntry copyWithCompanion(StudentManualOrderCompanion data) {
    return StudentManualOrderEntry(
      studyId: data.studyId.present ? data.studyId.value : this.studyId,
      manualIndex: data.manualIndex.present
          ? data.manualIndex.value
          : this.manualIndex,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      revision: data.revision.present ? data.revision.value : this.revision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StudentManualOrderEntry(')
          ..write('studyId: $studyId, ')
          ..write('manualIndex: $manualIndex, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(studyId, manualIndex, updatedAt, deletedAt, revision);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StudentManualOrderEntry &&
          other.studyId == this.studyId &&
          other.manualIndex == this.manualIndex &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.revision == this.revision);
}

class StudentManualOrderCompanion
    extends UpdateCompanion<StudentManualOrderEntry> {
  final Value<String> studyId;
  final Value<int> manualIndex;
  final Value<DateTime?> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> revision;
  final Value<int> rowid;
  const StudentManualOrderCompanion({
    this.studyId = const Value.absent(),
    this.manualIndex = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StudentManualOrderCompanion.insert({
    required String studyId,
    required int manualIndex,
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : studyId = Value(studyId),
       manualIndex = Value(manualIndex);
  static Insertable<StudentManualOrderEntry> custom({
    Expression<String>? studyId,
    Expression<int>? manualIndex,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? revision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (studyId != null) 'study_id': studyId,
      if (manualIndex != null) 'manual_index': manualIndex,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (revision != null) 'revision': revision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StudentManualOrderCompanion copyWith({
    Value<String>? studyId,
    Value<int>? manualIndex,
    Value<DateTime?>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? revision,
    Value<int>? rowid,
  }) {
    return StudentManualOrderCompanion(
      studyId: studyId ?? this.studyId,
      manualIndex: manualIndex ?? this.manualIndex,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      revision: revision ?? this.revision,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (studyId.present) {
      map['study_id'] = Variable<String>(studyId.value);
    }
    if (manualIndex.present) {
      map['manual_index'] = Variable<int>(manualIndex.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StudentManualOrderCompanion(')
          ..write('studyId: $studyId, ')
          ..write('manualIndex: $manualIndex, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ExternalCalendarEventsTable extends ExternalCalendarEvents
    with TableInfo<$ExternalCalendarEventsTable, ExternalCalendarEventEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExternalCalendarEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _providerMeta = const VerificationMeta(
    'provider',
  );
  @override
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
    'provider',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _externalAccountMeta = const VerificationMeta(
    'externalAccount',
  );
  @override
  late final GeneratedColumn<String> externalAccount = GeneratedColumn<String>(
    'external_account',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _calendarIdMeta = const VerificationMeta(
    'calendarId',
  );
  @override
  late final GeneratedColumn<String> calendarId = GeneratedColumn<String>(
    'calendar_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _externalEventIdMeta = const VerificationMeta(
    'externalEventId',
  );
  @override
  late final GeneratedColumn<String> externalEventId = GeneratedColumn<String>(
    'external_event_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iCalUidMeta = const VerificationMeta(
    'iCalUid',
  );
  @override
  late final GeneratedColumn<String> iCalUid = GeneratedColumn<String>(
    'ical_uid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _locationMeta = const VerificationMeta(
    'location',
  );
  @override
  late final GeneratedColumn<String> location = GeneratedColumn<String>(
    'location',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startTimeMeta = const VerificationMeta(
    'startTime',
  );
  @override
  late final GeneratedColumn<DateTime> startTime = GeneratedColumn<DateTime>(
    'start_time',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endTimeMeta = const VerificationMeta(
    'endTime',
  );
  @override
  late final GeneratedColumn<DateTime> endTime = GeneratedColumn<DateTime>(
    'end_time',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timeZoneMeta = const VerificationMeta(
    'timeZone',
  );
  @override
  late final GeneratedColumn<String> timeZone = GeneratedColumn<String>(
    'time_zone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isAllDayMeta = const VerificationMeta(
    'isAllDay',
  );
  @override
  late final GeneratedColumn<bool> isAllDay = GeneratedColumn<bool>(
    'is_all_day',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_all_day" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _externalStatusMeta = const VerificationMeta(
    'externalStatus',
  );
  @override
  late final GeneratedColumn<String> externalStatus = GeneratedColumn<String>(
    'external_status',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastModifiedExternalMeta =
      const VerificationMeta('lastModifiedExternal');
  @override
  late final GeneratedColumn<DateTime> lastModifiedExternal =
      GeneratedColumn<DateTime>(
        'last_modified_external',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastSyncedAtMeta = const VerificationMeta(
    'lastSyncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSyncedAt = GeneratedColumn<DateTime>(
    'last_synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isDeletedExternalMeta = const VerificationMeta(
    'isDeletedExternal',
  );
  @override
  late final GeneratedColumn<bool> isDeletedExternal = GeneratedColumn<bool>(
    'is_deleted_external',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted_external" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _metadataMeta = const VerificationMeta(
    'metadata',
  );
  @override
  late final GeneratedColumn<String> metadata = GeneratedColumn<String>(
    'metadata',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _etagMeta = const VerificationMeta('etag');
  @override
  late final GeneratedColumn<String> etag = GeneratedColumn<String>(
    'etag',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    provider,
    externalAccount,
    calendarId,
    externalEventId,
    iCalUid,
    title,
    location,
    description,
    startTime,
    endTime,
    timeZone,
    isAllDay,
    externalStatus,
    lastModifiedExternal,
    lastSyncedAt,
    isDeletedExternal,
    metadata,
    etag,
    createdAt,
    updatedAt,
    deletedAt,
    revision,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'external_calendar_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<ExternalCalendarEventEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('provider')) {
      context.handle(
        _providerMeta,
        provider.isAcceptableOrUnknown(data['provider']!, _providerMeta),
      );
    } else if (isInserting) {
      context.missing(_providerMeta);
    }
    if (data.containsKey('external_account')) {
      context.handle(
        _externalAccountMeta,
        externalAccount.isAcceptableOrUnknown(
          data['external_account']!,
          _externalAccountMeta,
        ),
      );
    }
    if (data.containsKey('calendar_id')) {
      context.handle(
        _calendarIdMeta,
        calendarId.isAcceptableOrUnknown(data['calendar_id']!, _calendarIdMeta),
      );
    } else if (isInserting) {
      context.missing(_calendarIdMeta);
    }
    if (data.containsKey('external_event_id')) {
      context.handle(
        _externalEventIdMeta,
        externalEventId.isAcceptableOrUnknown(
          data['external_event_id']!,
          _externalEventIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_externalEventIdMeta);
    }
    if (data.containsKey('ical_uid')) {
      context.handle(
        _iCalUidMeta,
        iCalUid.isAcceptableOrUnknown(data['ical_uid']!, _iCalUidMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('location')) {
      context.handle(
        _locationMeta,
        location.isAcceptableOrUnknown(data['location']!, _locationMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('start_time')) {
      context.handle(
        _startTimeMeta,
        startTime.isAcceptableOrUnknown(data['start_time']!, _startTimeMeta),
      );
    } else if (isInserting) {
      context.missing(_startTimeMeta);
    }
    if (data.containsKey('end_time')) {
      context.handle(
        _endTimeMeta,
        endTime.isAcceptableOrUnknown(data['end_time']!, _endTimeMeta),
      );
    } else if (isInserting) {
      context.missing(_endTimeMeta);
    }
    if (data.containsKey('time_zone')) {
      context.handle(
        _timeZoneMeta,
        timeZone.isAcceptableOrUnknown(data['time_zone']!, _timeZoneMeta),
      );
    }
    if (data.containsKey('is_all_day')) {
      context.handle(
        _isAllDayMeta,
        isAllDay.isAcceptableOrUnknown(data['is_all_day']!, _isAllDayMeta),
      );
    }
    if (data.containsKey('external_status')) {
      context.handle(
        _externalStatusMeta,
        externalStatus.isAcceptableOrUnknown(
          data['external_status']!,
          _externalStatusMeta,
        ),
      );
    }
    if (data.containsKey('last_modified_external')) {
      context.handle(
        _lastModifiedExternalMeta,
        lastModifiedExternal.isAcceptableOrUnknown(
          data['last_modified_external']!,
          _lastModifiedExternalMeta,
        ),
      );
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
        _lastSyncedAtMeta,
        lastSyncedAt.isAcceptableOrUnknown(
          data['last_synced_at']!,
          _lastSyncedAtMeta,
        ),
      );
    }
    if (data.containsKey('is_deleted_external')) {
      context.handle(
        _isDeletedExternalMeta,
        isDeletedExternal.isAcceptableOrUnknown(
          data['is_deleted_external']!,
          _isDeletedExternalMeta,
        ),
      );
    }
    if (data.containsKey('metadata')) {
      context.handle(
        _metadataMeta,
        metadata.isAcceptableOrUnknown(data['metadata']!, _metadataMeta),
      );
    }
    if (data.containsKey('etag')) {
      context.handle(
        _etagMeta,
        etag.isAcceptableOrUnknown(data['etag']!, _etagMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ExternalCalendarEventEntry map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExternalCalendarEventEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      provider: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider'],
      )!,
      externalAccount: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}external_account'],
      ),
      calendarId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}calendar_id'],
      )!,
      externalEventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}external_event_id'],
      )!,
      iCalUid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ical_uid'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      location: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      startTime: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_time'],
      )!,
      endTime: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}end_time'],
      )!,
      timeZone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}time_zone'],
      ),
      isAllDay: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_all_day'],
      )!,
      externalStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}external_status'],
      ),
      lastModifiedExternal: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_modified_external'],
      ),
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_synced_at'],
      ),
      isDeletedExternal: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted_external'],
      )!,
      metadata: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metadata'],
      ),
      etag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}etag'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
    );
  }

  @override
  $ExternalCalendarEventsTable createAlias(String alias) {
    return $ExternalCalendarEventsTable(attachedDatabase, alias);
  }
}

class ExternalCalendarEventEntry extends DataClass
    implements Insertable<ExternalCalendarEventEntry> {
  final String id;
  final String provider;
  final String? externalAccount;
  final String calendarId;
  final String externalEventId;
  final String? iCalUid;
  final String title;
  final String? location;
  final String? description;
  final DateTime startTime;
  final DateTime endTime;
  final String? timeZone;
  final bool isAllDay;
  final String? externalStatus;
  final DateTime? lastModifiedExternal;
  final DateTime? lastSyncedAt;
  final bool isDeletedExternal;
  final String? metadata;
  final String? etag;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int revision;
  const ExternalCalendarEventEntry({
    required this.id,
    required this.provider,
    this.externalAccount,
    required this.calendarId,
    required this.externalEventId,
    this.iCalUid,
    required this.title,
    this.location,
    this.description,
    required this.startTime,
    required this.endTime,
    this.timeZone,
    required this.isAllDay,
    this.externalStatus,
    this.lastModifiedExternal,
    this.lastSyncedAt,
    required this.isDeletedExternal,
    this.metadata,
    this.etag,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.revision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['provider'] = Variable<String>(provider);
    if (!nullToAbsent || externalAccount != null) {
      map['external_account'] = Variable<String>(externalAccount);
    }
    map['calendar_id'] = Variable<String>(calendarId);
    map['external_event_id'] = Variable<String>(externalEventId);
    if (!nullToAbsent || iCalUid != null) {
      map['ical_uid'] = Variable<String>(iCalUid);
    }
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || location != null) {
      map['location'] = Variable<String>(location);
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['start_time'] = Variable<DateTime>(startTime);
    map['end_time'] = Variable<DateTime>(endTime);
    if (!nullToAbsent || timeZone != null) {
      map['time_zone'] = Variable<String>(timeZone);
    }
    map['is_all_day'] = Variable<bool>(isAllDay);
    if (!nullToAbsent || externalStatus != null) {
      map['external_status'] = Variable<String>(externalStatus);
    }
    if (!nullToAbsent || lastModifiedExternal != null) {
      map['last_modified_external'] = Variable<DateTime>(lastModifiedExternal);
    }
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    }
    map['is_deleted_external'] = Variable<bool>(isDeletedExternal);
    if (!nullToAbsent || metadata != null) {
      map['metadata'] = Variable<String>(metadata);
    }
    if (!nullToAbsent || etag != null) {
      map['etag'] = Variable<String>(etag);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['revision'] = Variable<int>(revision);
    return map;
  }

  ExternalCalendarEventsCompanion toCompanion(bool nullToAbsent) {
    return ExternalCalendarEventsCompanion(
      id: Value(id),
      provider: Value(provider),
      externalAccount: externalAccount == null && nullToAbsent
          ? const Value.absent()
          : Value(externalAccount),
      calendarId: Value(calendarId),
      externalEventId: Value(externalEventId),
      iCalUid: iCalUid == null && nullToAbsent
          ? const Value.absent()
          : Value(iCalUid),
      title: Value(title),
      location: location == null && nullToAbsent
          ? const Value.absent()
          : Value(location),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      startTime: Value(startTime),
      endTime: Value(endTime),
      timeZone: timeZone == null && nullToAbsent
          ? const Value.absent()
          : Value(timeZone),
      isAllDay: Value(isAllDay),
      externalStatus: externalStatus == null && nullToAbsent
          ? const Value.absent()
          : Value(externalStatus),
      lastModifiedExternal: lastModifiedExternal == null && nullToAbsent
          ? const Value.absent()
          : Value(lastModifiedExternal),
      lastSyncedAt: lastSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAt),
      isDeletedExternal: Value(isDeletedExternal),
      metadata: metadata == null && nullToAbsent
          ? const Value.absent()
          : Value(metadata),
      etag: etag == null && nullToAbsent ? const Value.absent() : Value(etag),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      revision: Value(revision),
    );
  }

  factory ExternalCalendarEventEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExternalCalendarEventEntry(
      id: serializer.fromJson<String>(json['id']),
      provider: serializer.fromJson<String>(json['provider']),
      externalAccount: serializer.fromJson<String?>(json['externalAccount']),
      calendarId: serializer.fromJson<String>(json['calendarId']),
      externalEventId: serializer.fromJson<String>(json['externalEventId']),
      iCalUid: serializer.fromJson<String?>(json['iCalUid']),
      title: serializer.fromJson<String>(json['title']),
      location: serializer.fromJson<String?>(json['location']),
      description: serializer.fromJson<String?>(json['description']),
      startTime: serializer.fromJson<DateTime>(json['startTime']),
      endTime: serializer.fromJson<DateTime>(json['endTime']),
      timeZone: serializer.fromJson<String?>(json['timeZone']),
      isAllDay: serializer.fromJson<bool>(json['isAllDay']),
      externalStatus: serializer.fromJson<String?>(json['externalStatus']),
      lastModifiedExternal: serializer.fromJson<DateTime?>(
        json['lastModifiedExternal'],
      ),
      lastSyncedAt: serializer.fromJson<DateTime?>(json['lastSyncedAt']),
      isDeletedExternal: serializer.fromJson<bool>(json['isDeletedExternal']),
      metadata: serializer.fromJson<String?>(json['metadata']),
      etag: serializer.fromJson<String?>(json['etag']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      revision: serializer.fromJson<int>(json['revision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'provider': serializer.toJson<String>(provider),
      'externalAccount': serializer.toJson<String?>(externalAccount),
      'calendarId': serializer.toJson<String>(calendarId),
      'externalEventId': serializer.toJson<String>(externalEventId),
      'iCalUid': serializer.toJson<String?>(iCalUid),
      'title': serializer.toJson<String>(title),
      'location': serializer.toJson<String?>(location),
      'description': serializer.toJson<String?>(description),
      'startTime': serializer.toJson<DateTime>(startTime),
      'endTime': serializer.toJson<DateTime>(endTime),
      'timeZone': serializer.toJson<String?>(timeZone),
      'isAllDay': serializer.toJson<bool>(isAllDay),
      'externalStatus': serializer.toJson<String?>(externalStatus),
      'lastModifiedExternal': serializer.toJson<DateTime?>(
        lastModifiedExternal,
      ),
      'lastSyncedAt': serializer.toJson<DateTime?>(lastSyncedAt),
      'isDeletedExternal': serializer.toJson<bool>(isDeletedExternal),
      'metadata': serializer.toJson<String?>(metadata),
      'etag': serializer.toJson<String?>(etag),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'revision': serializer.toJson<int>(revision),
    };
  }

  ExternalCalendarEventEntry copyWith({
    String? id,
    String? provider,
    Value<String?> externalAccount = const Value.absent(),
    String? calendarId,
    String? externalEventId,
    Value<String?> iCalUid = const Value.absent(),
    String? title,
    Value<String?> location = const Value.absent(),
    Value<String?> description = const Value.absent(),
    DateTime? startTime,
    DateTime? endTime,
    Value<String?> timeZone = const Value.absent(),
    bool? isAllDay,
    Value<String?> externalStatus = const Value.absent(),
    Value<DateTime?> lastModifiedExternal = const Value.absent(),
    Value<DateTime?> lastSyncedAt = const Value.absent(),
    bool? isDeletedExternal,
    Value<String?> metadata = const Value.absent(),
    Value<String?> etag = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    int? revision,
  }) => ExternalCalendarEventEntry(
    id: id ?? this.id,
    provider: provider ?? this.provider,
    externalAccount: externalAccount.present
        ? externalAccount.value
        : this.externalAccount,
    calendarId: calendarId ?? this.calendarId,
    externalEventId: externalEventId ?? this.externalEventId,
    iCalUid: iCalUid.present ? iCalUid.value : this.iCalUid,
    title: title ?? this.title,
    location: location.present ? location.value : this.location,
    description: description.present ? description.value : this.description,
    startTime: startTime ?? this.startTime,
    endTime: endTime ?? this.endTime,
    timeZone: timeZone.present ? timeZone.value : this.timeZone,
    isAllDay: isAllDay ?? this.isAllDay,
    externalStatus: externalStatus.present
        ? externalStatus.value
        : this.externalStatus,
    lastModifiedExternal: lastModifiedExternal.present
        ? lastModifiedExternal.value
        : this.lastModifiedExternal,
    lastSyncedAt: lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
    isDeletedExternal: isDeletedExternal ?? this.isDeletedExternal,
    metadata: metadata.present ? metadata.value : this.metadata,
    etag: etag.present ? etag.value : this.etag,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    revision: revision ?? this.revision,
  );
  ExternalCalendarEventEntry copyWithCompanion(
    ExternalCalendarEventsCompanion data,
  ) {
    return ExternalCalendarEventEntry(
      id: data.id.present ? data.id.value : this.id,
      provider: data.provider.present ? data.provider.value : this.provider,
      externalAccount: data.externalAccount.present
          ? data.externalAccount.value
          : this.externalAccount,
      calendarId: data.calendarId.present
          ? data.calendarId.value
          : this.calendarId,
      externalEventId: data.externalEventId.present
          ? data.externalEventId.value
          : this.externalEventId,
      iCalUid: data.iCalUid.present ? data.iCalUid.value : this.iCalUid,
      title: data.title.present ? data.title.value : this.title,
      location: data.location.present ? data.location.value : this.location,
      description: data.description.present
          ? data.description.value
          : this.description,
      startTime: data.startTime.present ? data.startTime.value : this.startTime,
      endTime: data.endTime.present ? data.endTime.value : this.endTime,
      timeZone: data.timeZone.present ? data.timeZone.value : this.timeZone,
      isAllDay: data.isAllDay.present ? data.isAllDay.value : this.isAllDay,
      externalStatus: data.externalStatus.present
          ? data.externalStatus.value
          : this.externalStatus,
      lastModifiedExternal: data.lastModifiedExternal.present
          ? data.lastModifiedExternal.value
          : this.lastModifiedExternal,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
      isDeletedExternal: data.isDeletedExternal.present
          ? data.isDeletedExternal.value
          : this.isDeletedExternal,
      metadata: data.metadata.present ? data.metadata.value : this.metadata,
      etag: data.etag.present ? data.etag.value : this.etag,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      revision: data.revision.present ? data.revision.value : this.revision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExternalCalendarEventEntry(')
          ..write('id: $id, ')
          ..write('provider: $provider, ')
          ..write('externalAccount: $externalAccount, ')
          ..write('calendarId: $calendarId, ')
          ..write('externalEventId: $externalEventId, ')
          ..write('iCalUid: $iCalUid, ')
          ..write('title: $title, ')
          ..write('location: $location, ')
          ..write('description: $description, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('timeZone: $timeZone, ')
          ..write('isAllDay: $isAllDay, ')
          ..write('externalStatus: $externalStatus, ')
          ..write('lastModifiedExternal: $lastModifiedExternal, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('isDeletedExternal: $isDeletedExternal, ')
          ..write('metadata: $metadata, ')
          ..write('etag: $etag, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    provider,
    externalAccount,
    calendarId,
    externalEventId,
    iCalUid,
    title,
    location,
    description,
    startTime,
    endTime,
    timeZone,
    isAllDay,
    externalStatus,
    lastModifiedExternal,
    lastSyncedAt,
    isDeletedExternal,
    metadata,
    etag,
    createdAt,
    updatedAt,
    deletedAt,
    revision,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExternalCalendarEventEntry &&
          other.id == this.id &&
          other.provider == this.provider &&
          other.externalAccount == this.externalAccount &&
          other.calendarId == this.calendarId &&
          other.externalEventId == this.externalEventId &&
          other.iCalUid == this.iCalUid &&
          other.title == this.title &&
          other.location == this.location &&
          other.description == this.description &&
          other.startTime == this.startTime &&
          other.endTime == this.endTime &&
          other.timeZone == this.timeZone &&
          other.isAllDay == this.isAllDay &&
          other.externalStatus == this.externalStatus &&
          other.lastModifiedExternal == this.lastModifiedExternal &&
          other.lastSyncedAt == this.lastSyncedAt &&
          other.isDeletedExternal == this.isDeletedExternal &&
          other.metadata == this.metadata &&
          other.etag == this.etag &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.revision == this.revision);
}

class ExternalCalendarEventsCompanion
    extends UpdateCompanion<ExternalCalendarEventEntry> {
  final Value<String> id;
  final Value<String> provider;
  final Value<String?> externalAccount;
  final Value<String> calendarId;
  final Value<String> externalEventId;
  final Value<String?> iCalUid;
  final Value<String> title;
  final Value<String?> location;
  final Value<String?> description;
  final Value<DateTime> startTime;
  final Value<DateTime> endTime;
  final Value<String?> timeZone;
  final Value<bool> isAllDay;
  final Value<String?> externalStatus;
  final Value<DateTime?> lastModifiedExternal;
  final Value<DateTime?> lastSyncedAt;
  final Value<bool> isDeletedExternal;
  final Value<String?> metadata;
  final Value<String?> etag;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> revision;
  final Value<int> rowid;
  const ExternalCalendarEventsCompanion({
    this.id = const Value.absent(),
    this.provider = const Value.absent(),
    this.externalAccount = const Value.absent(),
    this.calendarId = const Value.absent(),
    this.externalEventId = const Value.absent(),
    this.iCalUid = const Value.absent(),
    this.title = const Value.absent(),
    this.location = const Value.absent(),
    this.description = const Value.absent(),
    this.startTime = const Value.absent(),
    this.endTime = const Value.absent(),
    this.timeZone = const Value.absent(),
    this.isAllDay = const Value.absent(),
    this.externalStatus = const Value.absent(),
    this.lastModifiedExternal = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.isDeletedExternal = const Value.absent(),
    this.metadata = const Value.absent(),
    this.etag = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExternalCalendarEventsCompanion.insert({
    required String id,
    required String provider,
    this.externalAccount = const Value.absent(),
    required String calendarId,
    required String externalEventId,
    this.iCalUid = const Value.absent(),
    required String title,
    this.location = const Value.absent(),
    this.description = const Value.absent(),
    required DateTime startTime,
    required DateTime endTime,
    this.timeZone = const Value.absent(),
    this.isAllDay = const Value.absent(),
    this.externalStatus = const Value.absent(),
    this.lastModifiedExternal = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.isDeletedExternal = const Value.absent(),
    this.metadata = const Value.absent(),
    this.etag = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       provider = Value(provider),
       calendarId = Value(calendarId),
       externalEventId = Value(externalEventId),
       title = Value(title),
       startTime = Value(startTime),
       endTime = Value(endTime),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ExternalCalendarEventEntry> custom({
    Expression<String>? id,
    Expression<String>? provider,
    Expression<String>? externalAccount,
    Expression<String>? calendarId,
    Expression<String>? externalEventId,
    Expression<String>? iCalUid,
    Expression<String>? title,
    Expression<String>? location,
    Expression<String>? description,
    Expression<DateTime>? startTime,
    Expression<DateTime>? endTime,
    Expression<String>? timeZone,
    Expression<bool>? isAllDay,
    Expression<String>? externalStatus,
    Expression<DateTime>? lastModifiedExternal,
    Expression<DateTime>? lastSyncedAt,
    Expression<bool>? isDeletedExternal,
    Expression<String>? metadata,
    Expression<String>? etag,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? revision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (provider != null) 'provider': provider,
      if (externalAccount != null) 'external_account': externalAccount,
      if (calendarId != null) 'calendar_id': calendarId,
      if (externalEventId != null) 'external_event_id': externalEventId,
      if (iCalUid != null) 'ical_uid': iCalUid,
      if (title != null) 'title': title,
      if (location != null) 'location': location,
      if (description != null) 'description': description,
      if (startTime != null) 'start_time': startTime,
      if (endTime != null) 'end_time': endTime,
      if (timeZone != null) 'time_zone': timeZone,
      if (isAllDay != null) 'is_all_day': isAllDay,
      if (externalStatus != null) 'external_status': externalStatus,
      if (lastModifiedExternal != null)
        'last_modified_external': lastModifiedExternal,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (isDeletedExternal != null) 'is_deleted_external': isDeletedExternal,
      if (metadata != null) 'metadata': metadata,
      if (etag != null) 'etag': etag,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (revision != null) 'revision': revision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExternalCalendarEventsCompanion copyWith({
    Value<String>? id,
    Value<String>? provider,
    Value<String?>? externalAccount,
    Value<String>? calendarId,
    Value<String>? externalEventId,
    Value<String?>? iCalUid,
    Value<String>? title,
    Value<String?>? location,
    Value<String?>? description,
    Value<DateTime>? startTime,
    Value<DateTime>? endTime,
    Value<String?>? timeZone,
    Value<bool>? isAllDay,
    Value<String?>? externalStatus,
    Value<DateTime?>? lastModifiedExternal,
    Value<DateTime?>? lastSyncedAt,
    Value<bool>? isDeletedExternal,
    Value<String?>? metadata,
    Value<String?>? etag,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? revision,
    Value<int>? rowid,
  }) {
    return ExternalCalendarEventsCompanion(
      id: id ?? this.id,
      provider: provider ?? this.provider,
      externalAccount: externalAccount ?? this.externalAccount,
      calendarId: calendarId ?? this.calendarId,
      externalEventId: externalEventId ?? this.externalEventId,
      iCalUid: iCalUid ?? this.iCalUid,
      title: title ?? this.title,
      location: location ?? this.location,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      timeZone: timeZone ?? this.timeZone,
      isAllDay: isAllDay ?? this.isAllDay,
      externalStatus: externalStatus ?? this.externalStatus,
      lastModifiedExternal: lastModifiedExternal ?? this.lastModifiedExternal,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      isDeletedExternal: isDeletedExternal ?? this.isDeletedExternal,
      metadata: metadata ?? this.metadata,
      etag: etag ?? this.etag,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      revision: revision ?? this.revision,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (externalAccount.present) {
      map['external_account'] = Variable<String>(externalAccount.value);
    }
    if (calendarId.present) {
      map['calendar_id'] = Variable<String>(calendarId.value);
    }
    if (externalEventId.present) {
      map['external_event_id'] = Variable<String>(externalEventId.value);
    }
    if (iCalUid.present) {
      map['ical_uid'] = Variable<String>(iCalUid.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (location.present) {
      map['location'] = Variable<String>(location.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (startTime.present) {
      map['start_time'] = Variable<DateTime>(startTime.value);
    }
    if (endTime.present) {
      map['end_time'] = Variable<DateTime>(endTime.value);
    }
    if (timeZone.present) {
      map['time_zone'] = Variable<String>(timeZone.value);
    }
    if (isAllDay.present) {
      map['is_all_day'] = Variable<bool>(isAllDay.value);
    }
    if (externalStatus.present) {
      map['external_status'] = Variable<String>(externalStatus.value);
    }
    if (lastModifiedExternal.present) {
      map['last_modified_external'] = Variable<DateTime>(
        lastModifiedExternal.value,
      );
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    if (isDeletedExternal.present) {
      map['is_deleted_external'] = Variable<bool>(isDeletedExternal.value);
    }
    if (metadata.present) {
      map['metadata'] = Variable<String>(metadata.value);
    }
    if (etag.present) {
      map['etag'] = Variable<String>(etag.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExternalCalendarEventsCompanion(')
          ..write('id: $id, ')
          ..write('provider: $provider, ')
          ..write('externalAccount: $externalAccount, ')
          ..write('calendarId: $calendarId, ')
          ..write('externalEventId: $externalEventId, ')
          ..write('iCalUid: $iCalUid, ')
          ..write('title: $title, ')
          ..write('location: $location, ')
          ..write('description: $description, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('timeZone: $timeZone, ')
          ..write('isAllDay: $isAllDay, ')
          ..write('externalStatus: $externalStatus, ')
          ..write('lastModifiedExternal: $lastModifiedExternal, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('isDeletedExternal: $isDeletedExternal, ')
          ..write('metadata: $metadata, ')
          ..write('etag: $etag, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CalendarEventLinksTable extends CalendarEventLinks
    with TableInfo<$CalendarEventLinksTable, CalendarEventLinkEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CalendarEventLinksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _appointmentIdMeta = const VerificationMeta(
    'appointmentId',
  );
  @override
  late final GeneratedColumn<String> appointmentId = GeneratedColumn<String>(
    'appointment_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _externalEventIdMeta = const VerificationMeta(
    'externalEventId',
  );
  @override
  late final GeneratedColumn<String> externalEventId = GeneratedColumn<String>(
    'external_event_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _providerMeta = const VerificationMeta(
    'provider',
  );
  @override
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
    'provider',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('synced'),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localRevisionAtSyncMeta =
      const VerificationMeta('localRevisionAtSync');
  @override
  late final GeneratedColumn<int> localRevisionAtSync = GeneratedColumn<int>(
    'local_revision_at_sync',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _externalETagAtSyncMeta =
      const VerificationMeta('externalETagAtSync');
  @override
  late final GeneratedColumn<String> externalETagAtSync =
      GeneratedColumn<String>(
        'external_etag_at_sync',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    appointmentId,
    externalEventId,
    provider,
    syncStatus,
    lastError,
    localRevisionAtSync,
    externalETagAtSync,
    createdAt,
    updatedAt,
    deletedAt,
    revision,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'calendar_event_links';
  @override
  VerificationContext validateIntegrity(
    Insertable<CalendarEventLinkEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('appointment_id')) {
      context.handle(
        _appointmentIdMeta,
        appointmentId.isAcceptableOrUnknown(
          data['appointment_id']!,
          _appointmentIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_appointmentIdMeta);
    }
    if (data.containsKey('external_event_id')) {
      context.handle(
        _externalEventIdMeta,
        externalEventId.isAcceptableOrUnknown(
          data['external_event_id']!,
          _externalEventIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_externalEventIdMeta);
    }
    if (data.containsKey('provider')) {
      context.handle(
        _providerMeta,
        provider.isAcceptableOrUnknown(data['provider']!, _providerMeta),
      );
    } else if (isInserting) {
      context.missing(_providerMeta);
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('local_revision_at_sync')) {
      context.handle(
        _localRevisionAtSyncMeta,
        localRevisionAtSync.isAcceptableOrUnknown(
          data['local_revision_at_sync']!,
          _localRevisionAtSyncMeta,
        ),
      );
    }
    if (data.containsKey('external_etag_at_sync')) {
      context.handle(
        _externalETagAtSyncMeta,
        externalETagAtSync.isAcceptableOrUnknown(
          data['external_etag_at_sync']!,
          _externalETagAtSyncMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CalendarEventLinkEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CalendarEventLinkEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      appointmentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}appointment_id'],
      )!,
      externalEventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}external_event_id'],
      )!,
      provider: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      localRevisionAtSync: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}local_revision_at_sync'],
      )!,
      externalETagAtSync: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}external_etag_at_sync'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
    );
  }

  @override
  $CalendarEventLinksTable createAlias(String alias) {
    return $CalendarEventLinksTable(attachedDatabase, alias);
  }
}

class CalendarEventLinkEntry extends DataClass
    implements Insertable<CalendarEventLinkEntry> {
  final String id;
  final String appointmentId;
  final String externalEventId;
  final String provider;
  final String syncStatus;
  final String? lastError;
  final int localRevisionAtSync;
  final String? externalETagAtSync;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int revision;
  const CalendarEventLinkEntry({
    required this.id,
    required this.appointmentId,
    required this.externalEventId,
    required this.provider,
    required this.syncStatus,
    this.lastError,
    required this.localRevisionAtSync,
    this.externalETagAtSync,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.revision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['appointment_id'] = Variable<String>(appointmentId);
    map['external_event_id'] = Variable<String>(externalEventId);
    map['provider'] = Variable<String>(provider);
    map['sync_status'] = Variable<String>(syncStatus);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['local_revision_at_sync'] = Variable<int>(localRevisionAtSync);
    if (!nullToAbsent || externalETagAtSync != null) {
      map['external_etag_at_sync'] = Variable<String>(externalETagAtSync);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['revision'] = Variable<int>(revision);
    return map;
  }

  CalendarEventLinksCompanion toCompanion(bool nullToAbsent) {
    return CalendarEventLinksCompanion(
      id: Value(id),
      appointmentId: Value(appointmentId),
      externalEventId: Value(externalEventId),
      provider: Value(provider),
      syncStatus: Value(syncStatus),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      localRevisionAtSync: Value(localRevisionAtSync),
      externalETagAtSync: externalETagAtSync == null && nullToAbsent
          ? const Value.absent()
          : Value(externalETagAtSync),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      revision: Value(revision),
    );
  }

  factory CalendarEventLinkEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CalendarEventLinkEntry(
      id: serializer.fromJson<String>(json['id']),
      appointmentId: serializer.fromJson<String>(json['appointmentId']),
      externalEventId: serializer.fromJson<String>(json['externalEventId']),
      provider: serializer.fromJson<String>(json['provider']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      localRevisionAtSync: serializer.fromJson<int>(
        json['localRevisionAtSync'],
      ),
      externalETagAtSync: serializer.fromJson<String?>(
        json['externalETagAtSync'],
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      revision: serializer.fromJson<int>(json['revision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'appointmentId': serializer.toJson<String>(appointmentId),
      'externalEventId': serializer.toJson<String>(externalEventId),
      'provider': serializer.toJson<String>(provider),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'lastError': serializer.toJson<String?>(lastError),
      'localRevisionAtSync': serializer.toJson<int>(localRevisionAtSync),
      'externalETagAtSync': serializer.toJson<String?>(externalETagAtSync),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'revision': serializer.toJson<int>(revision),
    };
  }

  CalendarEventLinkEntry copyWith({
    String? id,
    String? appointmentId,
    String? externalEventId,
    String? provider,
    String? syncStatus,
    Value<String?> lastError = const Value.absent(),
    int? localRevisionAtSync,
    Value<String?> externalETagAtSync = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    int? revision,
  }) => CalendarEventLinkEntry(
    id: id ?? this.id,
    appointmentId: appointmentId ?? this.appointmentId,
    externalEventId: externalEventId ?? this.externalEventId,
    provider: provider ?? this.provider,
    syncStatus: syncStatus ?? this.syncStatus,
    lastError: lastError.present ? lastError.value : this.lastError,
    localRevisionAtSync: localRevisionAtSync ?? this.localRevisionAtSync,
    externalETagAtSync: externalETagAtSync.present
        ? externalETagAtSync.value
        : this.externalETagAtSync,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    revision: revision ?? this.revision,
  );
  CalendarEventLinkEntry copyWithCompanion(CalendarEventLinksCompanion data) {
    return CalendarEventLinkEntry(
      id: data.id.present ? data.id.value : this.id,
      appointmentId: data.appointmentId.present
          ? data.appointmentId.value
          : this.appointmentId,
      externalEventId: data.externalEventId.present
          ? data.externalEventId.value
          : this.externalEventId,
      provider: data.provider.present ? data.provider.value : this.provider,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      localRevisionAtSync: data.localRevisionAtSync.present
          ? data.localRevisionAtSync.value
          : this.localRevisionAtSync,
      externalETagAtSync: data.externalETagAtSync.present
          ? data.externalETagAtSync.value
          : this.externalETagAtSync,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      revision: data.revision.present ? data.revision.value : this.revision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CalendarEventLinkEntry(')
          ..write('id: $id, ')
          ..write('appointmentId: $appointmentId, ')
          ..write('externalEventId: $externalEventId, ')
          ..write('provider: $provider, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('lastError: $lastError, ')
          ..write('localRevisionAtSync: $localRevisionAtSync, ')
          ..write('externalETagAtSync: $externalETagAtSync, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    appointmentId,
    externalEventId,
    provider,
    syncStatus,
    lastError,
    localRevisionAtSync,
    externalETagAtSync,
    createdAt,
    updatedAt,
    deletedAt,
    revision,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CalendarEventLinkEntry &&
          other.id == this.id &&
          other.appointmentId == this.appointmentId &&
          other.externalEventId == this.externalEventId &&
          other.provider == this.provider &&
          other.syncStatus == this.syncStatus &&
          other.lastError == this.lastError &&
          other.localRevisionAtSync == this.localRevisionAtSync &&
          other.externalETagAtSync == this.externalETagAtSync &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.revision == this.revision);
}

class CalendarEventLinksCompanion
    extends UpdateCompanion<CalendarEventLinkEntry> {
  final Value<String> id;
  final Value<String> appointmentId;
  final Value<String> externalEventId;
  final Value<String> provider;
  final Value<String> syncStatus;
  final Value<String?> lastError;
  final Value<int> localRevisionAtSync;
  final Value<String?> externalETagAtSync;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> revision;
  final Value<int> rowid;
  const CalendarEventLinksCompanion({
    this.id = const Value.absent(),
    this.appointmentId = const Value.absent(),
    this.externalEventId = const Value.absent(),
    this.provider = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.lastError = const Value.absent(),
    this.localRevisionAtSync = const Value.absent(),
    this.externalETagAtSync = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CalendarEventLinksCompanion.insert({
    required String id,
    required String appointmentId,
    required String externalEventId,
    required String provider,
    this.syncStatus = const Value.absent(),
    this.lastError = const Value.absent(),
    this.localRevisionAtSync = const Value.absent(),
    this.externalETagAtSync = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       appointmentId = Value(appointmentId),
       externalEventId = Value(externalEventId),
       provider = Value(provider),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<CalendarEventLinkEntry> custom({
    Expression<String>? id,
    Expression<String>? appointmentId,
    Expression<String>? externalEventId,
    Expression<String>? provider,
    Expression<String>? syncStatus,
    Expression<String>? lastError,
    Expression<int>? localRevisionAtSync,
    Expression<String>? externalETagAtSync,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? revision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (appointmentId != null) 'appointment_id': appointmentId,
      if (externalEventId != null) 'external_event_id': externalEventId,
      if (provider != null) 'provider': provider,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (lastError != null) 'last_error': lastError,
      if (localRevisionAtSync != null)
        'local_revision_at_sync': localRevisionAtSync,
      if (externalETagAtSync != null)
        'external_etag_at_sync': externalETagAtSync,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (revision != null) 'revision': revision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CalendarEventLinksCompanion copyWith({
    Value<String>? id,
    Value<String>? appointmentId,
    Value<String>? externalEventId,
    Value<String>? provider,
    Value<String>? syncStatus,
    Value<String?>? lastError,
    Value<int>? localRevisionAtSync,
    Value<String?>? externalETagAtSync,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? revision,
    Value<int>? rowid,
  }) {
    return CalendarEventLinksCompanion(
      id: id ?? this.id,
      appointmentId: appointmentId ?? this.appointmentId,
      externalEventId: externalEventId ?? this.externalEventId,
      provider: provider ?? this.provider,
      syncStatus: syncStatus ?? this.syncStatus,
      lastError: lastError ?? this.lastError,
      localRevisionAtSync: localRevisionAtSync ?? this.localRevisionAtSync,
      externalETagAtSync: externalETagAtSync ?? this.externalETagAtSync,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      revision: revision ?? this.revision,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (appointmentId.present) {
      map['appointment_id'] = Variable<String>(appointmentId.value);
    }
    if (externalEventId.present) {
      map['external_event_id'] = Variable<String>(externalEventId.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (localRevisionAtSync.present) {
      map['local_revision_at_sync'] = Variable<int>(localRevisionAtSync.value);
    }
    if (externalETagAtSync.present) {
      map['external_etag_at_sync'] = Variable<String>(externalETagAtSync.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CalendarEventLinksCompanion(')
          ..write('id: $id, ')
          ..write('appointmentId: $appointmentId, ')
          ..write('externalEventId: $externalEventId, ')
          ..write('provider: $provider, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('lastError: $lastError, ')
          ..write('localRevisionAtSync: $localRevisionAtSync, ')
          ..write('externalETagAtSync: $externalETagAtSync, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $PeopleTable people = $PeopleTable(this);
  late final $VisitsTable visits = $VisitsTable(this);
  late final $BibleStudiesTable bibleStudies = $BibleStudiesTable(this);
  late final $StudyParticipantsTable studyParticipants =
      $StudyParticipantsTable(this);
  late final $StudySessionsTable studySessions = $StudySessionsTable(this);
  late final $AppointmentsTable appointments = $AppointmentsTable(this);
  late final $ActivityRecordsTable activityRecords = $ActivityRecordsTable(
    this,
  );
  late final $SyncQueueTable syncQueue = $SyncQueueTable(this);
  late final $VoiceNotesTable voiceNotes = $VoiceNotesTable(this);
  late final $PhoneContactsTable phoneContacts = $PhoneContactsTable(this);
  late final $TerritoryLandmarksTable territoryLandmarks =
      $TerritoryLandmarksTable(this);
  late final $AppKvStoreTable appKvStore = $AppKvStoreTable(this);
  late final $FamilyTiesTable familyTies = $FamilyTiesTable(this);
  late final $MinistryExperiencesTable ministryExperiences =
      $MinistryExperiencesTable(this);
  late final $PersonPhotosTable personPhotos = $PersonPhotosTable(this);
  late final $PersonPublicationsTable personPublications =
      $PersonPublicationsTable(this);
  late final $ResearchArticlesTable researchArticles = $ResearchArticlesTable(
    this,
  );
  late final $ResearchTagsTable researchTags = $ResearchTagsTable(this);
  late final $TerritorySectorsTable territorySectors = $TerritorySectorsTable(
    this,
  );
  late final $StudentManualOrderTable studentManualOrder =
      $StudentManualOrderTable(this);
  late final $ExternalCalendarEventsTable externalCalendarEvents =
      $ExternalCalendarEventsTable(this);
  late final $CalendarEventLinksTable calendarEventLinks =
      $CalendarEventLinksTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    people,
    visits,
    bibleStudies,
    studyParticipants,
    studySessions,
    appointments,
    activityRecords,
    syncQueue,
    voiceNotes,
    phoneContacts,
    territoryLandmarks,
    appKvStore,
    familyTies,
    ministryExperiences,
    personPhotos,
    personPublications,
    researchArticles,
    researchTags,
    territorySectors,
    studentManualOrder,
    externalCalendarEvents,
    calendarEventLinks,
  ];
}

typedef $$PeopleTableCreateCompanionBuilder = PeopleCompanion Function({
  required String id,
  required String name,
  Value<String?> phone,
  Value<String?> address,
  Value<double?> latitude,
  Value<double?> longitude,
  required DateTime firstContactAt,
  Value<String> status,
  Value<String?> preferredSchedule,
  Value<String?> generalNotes,
  Value<String?> contactRestrictions,
  Value<String> tags,
  Value<DateTime?> lastContactAt,
  Value<DateTime?> nextActionAt,
  Value<String?> nextActionNote,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> revision,
  Value<int> rowid,
});
typedef $$PeopleTableUpdateCompanionBuilder = PeopleCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String?> phone,
  Value<String?> address,
  Value<double?> latitude,
  Value<double?> longitude,
  Value<DateTime> firstContactAt,
  Value<String> status,
  Value<String?> preferredSchedule,
  Value<String?> generalNotes,
  Value<String?> contactRestrictions,
  Value<String> tags,
  Value<DateTime?> lastContactAt,
  Value<DateTime?> nextActionAt,
  Value<String?> nextActionNote,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> revision,
  Value<int> rowid,
});

final class $$PeopleTableReferences
    extends BaseReferences<_$AppDatabase, $PeopleTable, PersonEntry> {
  $$PeopleTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$VisitsTable, List<VisitEntry>> _visitsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.visits,
    aliasName: 'people__id__visits__person_id',
  );

  $$VisitsTableProcessedTableManager get visitsRefs {
    final manager = $$VisitsTableTableManager(
      $_db,
      $_db.visits,
    ).filter((f) => f.personId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_visitsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $StudyParticipantsTable,
    List<StudyParticipantEntry>
  >
  _studyParticipantsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.studyParticipants,
        aliasName: 'people__id__study_participants__person_id',
      );

  $$StudyParticipantsTableProcessedTableManager get studyParticipantsRefs {
    final manager = $$StudyParticipantsTableTableManager(
      $_db,
      $_db.studyParticipants,
    ).filter((f) => f.personId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _studyParticipantsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$AppointmentsTable, List<AppointmentEntry>>
  _appointmentsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.appointments,
    aliasName: 'people__id__appointments__person_id',
  );

  $$AppointmentsTableProcessedTableManager get appointmentsRefs {
    final manager = $$AppointmentsTableTableManager(
      $_db,
      $_db.appointments,
    ).filter((f) => f.personId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_appointmentsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$VoiceNotesTable, List<VoiceNoteEntry>>
  _voiceNotesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.voiceNotes,
    aliasName: 'people__id__voice_notes__person_id',
  );

  $$VoiceNotesTableProcessedTableManager get voiceNotesRefs {
    final manager = $$VoiceNotesTableTableManager(
      $_db,
      $_db.voiceNotes,
    ).filter((f) => f.personId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_voiceNotesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PhoneContactsTable, List<PhoneContactEntry>>
  _phoneContactsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.phoneContacts,
    aliasName: 'people__id__phone_contacts__converted_person_id',
  );

  $$PhoneContactsTableProcessedTableManager get phoneContactsRefs {
    final manager = $$PhoneContactsTableTableManager($_db, $_db.phoneContacts)
        .filter(
          (f) => f.convertedPersonId.id.sqlEquals($_itemColumn<String>('id')!),
        );

    final cache = $_typedResult.readTableOrNull(_phoneContactsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PeopleTableFilterComposer
    extends Composer<_$AppDatabase, $PeopleTable> {
  $$PeopleTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get firstContactAt => $composableBuilder(
    column: $table.firstContactAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get preferredSchedule => $composableBuilder(
    column: $table.preferredSchedule,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get generalNotes => $composableBuilder(
    column: $table.generalNotes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contactRestrictions => $composableBuilder(
    column: $table.contactRestrictions,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastContactAt => $composableBuilder(
    column: $table.lastContactAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextActionAt => $composableBuilder(
    column: $table.nextActionAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nextActionNote => $composableBuilder(
    column: $table.nextActionNote,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> visitsRefs(
    Expression<bool> Function($$VisitsTableFilterComposer f) f,
  ) {
    final $$VisitsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.visits,
      getReferencedColumn: (t) => t.personId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VisitsTableFilterComposer(
            $db: $db,
            $table: $db.visits,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> studyParticipantsRefs(
    Expression<bool> Function($$StudyParticipantsTableFilterComposer f) f,
  ) {
    final $$StudyParticipantsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.studyParticipants,
      getReferencedColumn: (t) => t.personId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StudyParticipantsTableFilterComposer(
            $db: $db,
            $table: $db.studyParticipants,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> appointmentsRefs(
    Expression<bool> Function($$AppointmentsTableFilterComposer f) f,
  ) {
    final $$AppointmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.appointments,
      getReferencedColumn: (t) => t.personId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AppointmentsTableFilterComposer(
            $db: $db,
            $table: $db.appointments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> voiceNotesRefs(
    Expression<bool> Function($$VoiceNotesTableFilterComposer f) f,
  ) {
    final $$VoiceNotesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.voiceNotes,
      getReferencedColumn: (t) => t.personId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VoiceNotesTableFilterComposer(
            $db: $db,
            $table: $db.voiceNotes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> phoneContactsRefs(
    Expression<bool> Function($$PhoneContactsTableFilterComposer f) f,
  ) {
    final $$PhoneContactsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.phoneContacts,
      getReferencedColumn: (t) => t.convertedPersonId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PhoneContactsTableFilterComposer(
            $db: $db,
            $table: $db.phoneContacts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PeopleTableOrderingComposer
    extends Composer<_$AppDatabase, $PeopleTable> {
  $$PeopleTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get firstContactAt => $composableBuilder(
    column: $table.firstContactAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get preferredSchedule => $composableBuilder(
    column: $table.preferredSchedule,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get generalNotes => $composableBuilder(
    column: $table.generalNotes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contactRestrictions => $composableBuilder(
    column: $table.contactRestrictions,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastContactAt => $composableBuilder(
    column: $table.lastContactAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextActionAt => $composableBuilder(
    column: $table.nextActionAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nextActionNote => $composableBuilder(
    column: $table.nextActionNote,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PeopleTableAnnotationComposer
    extends Composer<_$AppDatabase, $PeopleTable> {
  $$PeopleTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<DateTime> get firstContactAt => $composableBuilder(
    column: $table.firstContactAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get preferredSchedule => $composableBuilder(
    column: $table.preferredSchedule,
    builder: (column) => column,
  );

  GeneratedColumn<String> get generalNotes => $composableBuilder(
    column: $table.generalNotes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contactRestrictions => $composableBuilder(
    column: $table.contactRestrictions,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<DateTime> get lastContactAt => $composableBuilder(
    column: $table.lastContactAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get nextActionAt => $composableBuilder(
    column: $table.nextActionAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get nextActionNote => $composableBuilder(
    column: $table.nextActionNote,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  Expression<T> visitsRefs<T extends Object>(
    Expression<T> Function($$VisitsTableAnnotationComposer a) f,
  ) {
    final $$VisitsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.visits,
      getReferencedColumn: (t) => t.personId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VisitsTableAnnotationComposer(
            $db: $db,
            $table: $db.visits,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> studyParticipantsRefs<T extends Object>(
    Expression<T> Function($$StudyParticipantsTableAnnotationComposer a) f,
  ) {
    final $$StudyParticipantsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.studyParticipants,
          getReferencedColumn: (t) => t.personId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$StudyParticipantsTableAnnotationComposer(
                $db: $db,
                $table: $db.studyParticipants,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> appointmentsRefs<T extends Object>(
    Expression<T> Function($$AppointmentsTableAnnotationComposer a) f,
  ) {
    final $$AppointmentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.appointments,
      getReferencedColumn: (t) => t.personId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AppointmentsTableAnnotationComposer(
            $db: $db,
            $table: $db.appointments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> voiceNotesRefs<T extends Object>(
    Expression<T> Function($$VoiceNotesTableAnnotationComposer a) f,
  ) {
    final $$VoiceNotesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.voiceNotes,
      getReferencedColumn: (t) => t.personId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VoiceNotesTableAnnotationComposer(
            $db: $db,
            $table: $db.voiceNotes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> phoneContactsRefs<T extends Object>(
    Expression<T> Function($$PhoneContactsTableAnnotationComposer a) f,
  ) {
    final $$PhoneContactsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.phoneContacts,
      getReferencedColumn: (t) => t.convertedPersonId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PhoneContactsTableAnnotationComposer(
            $db: $db,
            $table: $db.phoneContacts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PeopleTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PeopleTable,
          PersonEntry,
          $$PeopleTableFilterComposer,
          $$PeopleTableOrderingComposer,
          $$PeopleTableAnnotationComposer,
          $$PeopleTableCreateCompanionBuilder,
          $$PeopleTableUpdateCompanionBuilder,
          (PersonEntry, $$PeopleTableReferences),
          PersonEntry,
          PrefetchHooks Function({
            bool visitsRefs,
            bool studyParticipantsRefs,
            bool appointmentsRefs,
            bool voiceNotesRefs,
            bool phoneContactsRefs,
          })
        > {
  $$PeopleTableTableManager(_$AppDatabase db, $PeopleTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PeopleTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PeopleTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PeopleTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> address = const Value.absent(),
                Value<double?> latitude = const Value.absent(),
                Value<double?> longitude = const Value.absent(),
                Value<DateTime> firstContactAt = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> preferredSchedule = const Value.absent(),
                Value<String?> generalNotes = const Value.absent(),
                Value<String?> contactRestrictions = const Value.absent(),
                Value<String> tags = const Value.absent(),
                Value<DateTime?> lastContactAt = const Value.absent(),
                Value<DateTime?> nextActionAt = const Value.absent(),
                Value<String?> nextActionNote = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PeopleCompanion(
                id: id,
                name: name,
                phone: phone,
                address: address,
                latitude: latitude,
                longitude: longitude,
                firstContactAt: firstContactAt,
                status: status,
                preferredSchedule: preferredSchedule,
                generalNotes: generalNotes,
                contactRestrictions: contactRestrictions,
                tags: tags,
                lastContactAt: lastContactAt,
                nextActionAt: nextActionAt,
                nextActionNote: nextActionNote,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> phone = const Value.absent(),
                Value<String?> address = const Value.absent(),
                Value<double?> latitude = const Value.absent(),
                Value<double?> longitude = const Value.absent(),
                required DateTime firstContactAt,
                Value<String> status = const Value.absent(),
                Value<String?> preferredSchedule = const Value.absent(),
                Value<String?> generalNotes = const Value.absent(),
                Value<String?> contactRestrictions = const Value.absent(),
                Value<String> tags = const Value.absent(),
                Value<DateTime?> lastContactAt = const Value.absent(),
                Value<DateTime?> nextActionAt = const Value.absent(),
                Value<String?> nextActionNote = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PeopleCompanion.insert(
                id: id,
                name: name,
                phone: phone,
                address: address,
                latitude: latitude,
                longitude: longitude,
                firstContactAt: firstContactAt,
                status: status,
                preferredSchedule: preferredSchedule,
                generalNotes: generalNotes,
                contactRestrictions: contactRestrictions,
                tags: tags,
                lastContactAt: lastContactAt,
                nextActionAt: nextActionAt,
                nextActionNote: nextActionNote,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PeopleTable, PersonEntry>(table),
                  $$PeopleTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                visitsRefs = false,
                studyParticipantsRefs = false,
                appointmentsRefs = false,
                voiceNotesRefs = false,
                phoneContactsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (visitsRefs) db.visits,
                    if (studyParticipantsRefs) db.studyParticipants,
                    if (appointmentsRefs) db.appointments,
                    if (voiceNotesRefs) db.voiceNotes,
                    if (phoneContactsRefs) db.phoneContacts,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (visitsRefs)
                        await $_getPrefetchedDataByColumns<
                          PersonEntry,
                          $PeopleTable,
                          VisitEntry,
                          $VisitsTable
                        >(
                          currentTable: table,
                          referencedTable: $$PeopleTableReferences
                              ._visitsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PeopleTableReferences(db, table, p0).visitsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'person_id',
                          typedResults: items,
                        ),
                      if (studyParticipantsRefs)
                        await $_getPrefetchedDataByColumns<
                          PersonEntry,
                          $PeopleTable,
                          StudyParticipantEntry,
                          $StudyParticipantsTable
                        >(
                          currentTable: table,
                          referencedTable: $$PeopleTableReferences
                              ._studyParticipantsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PeopleTableReferences(
                                db,
                                table,
                                p0,
                              ).studyParticipantsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'person_id',
                          typedResults: items,
                        ),
                      if (appointmentsRefs)
                        await $_getPrefetchedDataByColumns<
                          PersonEntry,
                          $PeopleTable,
                          AppointmentEntry,
                          $AppointmentsTable
                        >(
                          currentTable: table,
                          referencedTable: $$PeopleTableReferences
                              ._appointmentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PeopleTableReferences(
                                db,
                                table,
                                p0,
                              ).appointmentsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'person_id',
                          typedResults: items,
                        ),
                      if (voiceNotesRefs)
                        await $_getPrefetchedDataByColumns<
                          PersonEntry,
                          $PeopleTable,
                          VoiceNoteEntry,
                          $VoiceNotesTable
                        >(
                          currentTable: table,
                          referencedTable: $$PeopleTableReferences
                              ._voiceNotesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PeopleTableReferences(
                                db,
                                table,
                                p0,
                              ).voiceNotesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'person_id',
                          typedResults: items,
                        ),
                      if (phoneContactsRefs)
                        await $_getPrefetchedDataByColumns<
                          PersonEntry,
                          $PeopleTable,
                          PhoneContactEntry,
                          $PhoneContactsTable
                        >(
                          currentTable: table,
                          referencedTable: $$PeopleTableReferences
                              ._phoneContactsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PeopleTableReferences(
                                db,
                                table,
                                p0,
                              ).phoneContactsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'converted_person_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$PeopleTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PeopleTable,
      PersonEntry,
      $$PeopleTableFilterComposer,
      $$PeopleTableOrderingComposer,
      $$PeopleTableAnnotationComposer,
      $$PeopleTableCreateCompanionBuilder,
      $$PeopleTableUpdateCompanionBuilder,
      (PersonEntry, $$PeopleTableReferences),
      PersonEntry,
      PrefetchHooks Function({
        bool visitsRefs,
        bool studyParticipantsRefs,
        bool appointmentsRefs,
        bool voiceNotesRefs,
        bool phoneContactsRefs,
      })
    >;
typedef $$VisitsTableCreateCompanionBuilder = VisitsCompanion Function({
  required String id,
  required String personId,
  required DateTime dateTimeField,
  required String contactType,
  required String result,
  Value<String?> notes,
  Value<String?> topicsDiscussed,
  Value<String?> scriptureOrPub,
  Value<String?> expressedQuestion,
  Value<String?> nextStep,
  Value<DateTime?> suggestedReturnDate,
  Value<String?> appointmentId,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> revision,
  Value<int> rowid,
});
typedef $$VisitsTableUpdateCompanionBuilder = VisitsCompanion Function({
  Value<String> id,
  Value<String> personId,
  Value<DateTime> dateTimeField,
  Value<String> contactType,
  Value<String> result,
  Value<String?> notes,
  Value<String?> topicsDiscussed,
  Value<String?> scriptureOrPub,
  Value<String?> expressedQuestion,
  Value<String?> nextStep,
  Value<DateTime?> suggestedReturnDate,
  Value<String?> appointmentId,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> revision,
  Value<int> rowid,
});

final class $$VisitsTableReferences
    extends BaseReferences<_$AppDatabase, $VisitsTable, VisitEntry> {
  $$VisitsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PeopleTable _personIdTable(_$AppDatabase db) =>
      db.people.createAlias('visits__person_id__people__id');

  $$PeopleTableProcessedTableManager get personId {
    final $_column = $_itemColumn<String>('person_id')!;

    final manager = $$PeopleTableTableManager(
      $_db,
      $_db.people,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_personIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$VoiceNotesTable, List<VoiceNoteEntry>>
  _voiceNotesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.voiceNotes,
    aliasName: 'visits__id__voice_notes__visit_id',
  );

  $$VoiceNotesTableProcessedTableManager get voiceNotesRefs {
    final manager = $$VoiceNotesTableTableManager(
      $_db,
      $_db.voiceNotes,
    ).filter((f) => f.visitId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_voiceNotesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$VisitsTableFilterComposer
    extends Composer<_$AppDatabase, $VisitsTable> {
  $$VisitsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dateTimeField => $composableBuilder(
    column: $table.dateTimeField,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contactType => $composableBuilder(
    column: $table.contactType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get result => $composableBuilder(
    column: $table.result,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get topicsDiscussed => $composableBuilder(
    column: $table.topicsDiscussed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scriptureOrPub => $composableBuilder(
    column: $table.scriptureOrPub,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get expressedQuestion => $composableBuilder(
    column: $table.expressedQuestion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nextStep => $composableBuilder(
    column: $table.nextStep,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get suggestedReturnDate => $composableBuilder(
    column: $table.suggestedReturnDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get appointmentId => $composableBuilder(
    column: $table.appointmentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  $$PeopleTableFilterComposer get personId {
    final $$PeopleTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.personId,
      referencedTable: $db.people,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeopleTableFilterComposer(
            $db: $db,
            $table: $db.people,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> voiceNotesRefs(
    Expression<bool> Function($$VoiceNotesTableFilterComposer f) f,
  ) {
    final $$VoiceNotesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.voiceNotes,
      getReferencedColumn: (t) => t.visitId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VoiceNotesTableFilterComposer(
            $db: $db,
            $table: $db.voiceNotes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$VisitsTableOrderingComposer
    extends Composer<_$AppDatabase, $VisitsTable> {
  $$VisitsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dateTimeField => $composableBuilder(
    column: $table.dateTimeField,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contactType => $composableBuilder(
    column: $table.contactType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get result => $composableBuilder(
    column: $table.result,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get topicsDiscussed => $composableBuilder(
    column: $table.topicsDiscussed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scriptureOrPub => $composableBuilder(
    column: $table.scriptureOrPub,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get expressedQuestion => $composableBuilder(
    column: $table.expressedQuestion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nextStep => $composableBuilder(
    column: $table.nextStep,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get suggestedReturnDate => $composableBuilder(
    column: $table.suggestedReturnDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get appointmentId => $composableBuilder(
    column: $table.appointmentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  $$PeopleTableOrderingComposer get personId {
    final $$PeopleTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.personId,
      referencedTable: $db.people,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeopleTableOrderingComposer(
            $db: $db,
            $table: $db.people,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$VisitsTableAnnotationComposer
    extends Composer<_$AppDatabase, $VisitsTable> {
  $$VisitsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get dateTimeField => $composableBuilder(
    column: $table.dateTimeField,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contactType => $composableBuilder(
    column: $table.contactType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get result =>
      $composableBuilder(column: $table.result, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get topicsDiscussed => $composableBuilder(
    column: $table.topicsDiscussed,
    builder: (column) => column,
  );

  GeneratedColumn<String> get scriptureOrPub => $composableBuilder(
    column: $table.scriptureOrPub,
    builder: (column) => column,
  );

  GeneratedColumn<String> get expressedQuestion => $composableBuilder(
    column: $table.expressedQuestion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get nextStep =>
      $composableBuilder(column: $table.nextStep, builder: (column) => column);

  GeneratedColumn<DateTime> get suggestedReturnDate => $composableBuilder(
    column: $table.suggestedReturnDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get appointmentId => $composableBuilder(
    column: $table.appointmentId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  $$PeopleTableAnnotationComposer get personId {
    final $$PeopleTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.personId,
      referencedTable: $db.people,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeopleTableAnnotationComposer(
            $db: $db,
            $table: $db.people,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> voiceNotesRefs<T extends Object>(
    Expression<T> Function($$VoiceNotesTableAnnotationComposer a) f,
  ) {
    final $$VoiceNotesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.voiceNotes,
      getReferencedColumn: (t) => t.visitId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VoiceNotesTableAnnotationComposer(
            $db: $db,
            $table: $db.voiceNotes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$VisitsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VisitsTable,
          VisitEntry,
          $$VisitsTableFilterComposer,
          $$VisitsTableOrderingComposer,
          $$VisitsTableAnnotationComposer,
          $$VisitsTableCreateCompanionBuilder,
          $$VisitsTableUpdateCompanionBuilder,
          (VisitEntry, $$VisitsTableReferences),
          VisitEntry,
          PrefetchHooks Function({bool personId, bool voiceNotesRefs})
        > {
  $$VisitsTableTableManager(_$AppDatabase db, $VisitsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VisitsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VisitsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VisitsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> personId = const Value.absent(),
                Value<DateTime> dateTimeField = const Value.absent(),
                Value<String> contactType = const Value.absent(),
                Value<String> result = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> topicsDiscussed = const Value.absent(),
                Value<String?> scriptureOrPub = const Value.absent(),
                Value<String?> expressedQuestion = const Value.absent(),
                Value<String?> nextStep = const Value.absent(),
                Value<DateTime?> suggestedReturnDate = const Value.absent(),
                Value<String?> appointmentId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VisitsCompanion(
                id: id,
                personId: personId,
                dateTimeField: dateTimeField,
                contactType: contactType,
                result: result,
                notes: notes,
                topicsDiscussed: topicsDiscussed,
                scriptureOrPub: scriptureOrPub,
                expressedQuestion: expressedQuestion,
                nextStep: nextStep,
                suggestedReturnDate: suggestedReturnDate,
                appointmentId: appointmentId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String personId,
                required DateTime dateTimeField,
                required String contactType,
                required String result,
                Value<String?> notes = const Value.absent(),
                Value<String?> topicsDiscussed = const Value.absent(),
                Value<String?> scriptureOrPub = const Value.absent(),
                Value<String?> expressedQuestion = const Value.absent(),
                Value<String?> nextStep = const Value.absent(),
                Value<DateTime?> suggestedReturnDate = const Value.absent(),
                Value<String?> appointmentId = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VisitsCompanion.insert(
                id: id,
                personId: personId,
                dateTimeField: dateTimeField,
                contactType: contactType,
                result: result,
                notes: notes,
                topicsDiscussed: topicsDiscussed,
                scriptureOrPub: scriptureOrPub,
                expressedQuestion: expressedQuestion,
                nextStep: nextStep,
                suggestedReturnDate: suggestedReturnDate,
                appointmentId: appointmentId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$VisitsTable, VisitEntry>(table),
                  $$VisitsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({personId = false, voiceNotesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (voiceNotesRefs) db.voiceNotes],
              addJoins:
                  <
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
                      dynamic
                    >
                  >(state) {
                    if (personId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.personId,
                        referencedTable: $$VisitsTableReferences._personIdTable(
                          db,
                        ),
                        referencedColumn: $$VisitsTableReferences
                            ._personIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (voiceNotesRefs)
                    await $_getPrefetchedDataByColumns<
                      VisitEntry,
                      $VisitsTable,
                      VoiceNoteEntry,
                      $VoiceNotesTable
                    >(
                      currentTable: table,
                      referencedTable: $$VisitsTableReferences
                          ._voiceNotesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$VisitsTableReferences(db, table, p0).voiceNotesRefs,
                      currentColumn: 'id',
                      referencedColumn: 'visit_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$VisitsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VisitsTable,
      VisitEntry,
      $$VisitsTableFilterComposer,
      $$VisitsTableOrderingComposer,
      $$VisitsTableAnnotationComposer,
      $$VisitsTableCreateCompanionBuilder,
      $$VisitsTableUpdateCompanionBuilder,
      (VisitEntry, $$VisitsTableReferences),
      VisitEntry,
      PrefetchHooks Function({bool personId, bool voiceNotesRefs})
    >;
typedef $$BibleStudiesTableCreateCompanionBuilder =
    BibleStudiesCompanion Function({
      required String id,
      required String title,
      Value<String> ownerId,
      required DateTime startedAt,
      Value<String> status,
      required String publicationId,
      Value<String> language,
      Value<int?> currentLesson,
      Value<int?> currentParagraph,
      Value<String?> manualReference,
      Value<String> frequency,
      Value<String?> learningGoals,
      Value<String?> pendingDoubts,
      Value<String?> nextTopic,
      Value<String?> pauseOrCloseReason,
      Value<DateTime?> lastSessionAt,
      Value<DateTime?> nextPlannedAt,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> revision,
      Value<int> rowid,
    });
typedef $$BibleStudiesTableUpdateCompanionBuilder =
    BibleStudiesCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String> ownerId,
      Value<DateTime> startedAt,
      Value<String> status,
      Value<String> publicationId,
      Value<String> language,
      Value<int?> currentLesson,
      Value<int?> currentParagraph,
      Value<String?> manualReference,
      Value<String> frequency,
      Value<String?> learningGoals,
      Value<String?> pendingDoubts,
      Value<String?> nextTopic,
      Value<String?> pauseOrCloseReason,
      Value<DateTime?> lastSessionAt,
      Value<DateTime?> nextPlannedAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> revision,
      Value<int> rowid,
    });

final class $$BibleStudiesTableReferences
    extends BaseReferences<_$AppDatabase, $BibleStudiesTable, BibleStudyEntry> {
  $$BibleStudiesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<
    $StudyParticipantsTable,
    List<StudyParticipantEntry>
  >
  _studyParticipantsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.studyParticipants,
        aliasName: 'bible_studies__id__study_participants__study_id',
      );

  $$StudyParticipantsTableProcessedTableManager get studyParticipantsRefs {
    final manager = $$StudyParticipantsTableTableManager(
      $_db,
      $_db.studyParticipants,
    ).filter((f) => f.studyId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _studyParticipantsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$StudySessionsTable, List<StudySessionEntry>>
  _studySessionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.studySessions,
    aliasName: 'bible_studies__id__study_sessions__study_id',
  );

  $$StudySessionsTableProcessedTableManager get studySessionsRefs {
    final manager = $$StudySessionsTableTableManager(
      $_db,
      $_db.studySessions,
    ).filter((f) => f.studyId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_studySessionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$AppointmentsTable, List<AppointmentEntry>>
  _appointmentsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.appointments,
    aliasName: 'bible_studies__id__appointments__study_id',
  );

  $$AppointmentsTableProcessedTableManager get appointmentsRefs {
    final manager = $$AppointmentsTableTableManager(
      $_db,
      $_db.appointments,
    ).filter((f) => f.studyId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_appointmentsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$VoiceNotesTable, List<VoiceNoteEntry>>
  _voiceNotesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.voiceNotes,
    aliasName: 'bible_studies__id__voice_notes__study_id',
  );

  $$VoiceNotesTableProcessedTableManager get voiceNotesRefs {
    final manager = $$VoiceNotesTableTableManager(
      $_db,
      $_db.voiceNotes,
    ).filter((f) => f.studyId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_voiceNotesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$BibleStudiesTableFilterComposer
    extends Composer<_$AppDatabase, $BibleStudiesTable> {
  $$BibleStudiesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get publicationId => $composableBuilder(
    column: $table.publicationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get currentLesson => $composableBuilder(
    column: $table.currentLesson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get currentParagraph => $composableBuilder(
    column: $table.currentParagraph,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get manualReference => $composableBuilder(
    column: $table.manualReference,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get frequency => $composableBuilder(
    column: $table.frequency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get learningGoals => $composableBuilder(
    column: $table.learningGoals,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pendingDoubts => $composableBuilder(
    column: $table.pendingDoubts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nextTopic => $composableBuilder(
    column: $table.nextTopic,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pauseOrCloseReason => $composableBuilder(
    column: $table.pauseOrCloseReason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSessionAt => $composableBuilder(
    column: $table.lastSessionAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextPlannedAt => $composableBuilder(
    column: $table.nextPlannedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> studyParticipantsRefs(
    Expression<bool> Function($$StudyParticipantsTableFilterComposer f) f,
  ) {
    final $$StudyParticipantsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.studyParticipants,
      getReferencedColumn: (t) => t.studyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StudyParticipantsTableFilterComposer(
            $db: $db,
            $table: $db.studyParticipants,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> studySessionsRefs(
    Expression<bool> Function($$StudySessionsTableFilterComposer f) f,
  ) {
    final $$StudySessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.studySessions,
      getReferencedColumn: (t) => t.studyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StudySessionsTableFilterComposer(
            $db: $db,
            $table: $db.studySessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> appointmentsRefs(
    Expression<bool> Function($$AppointmentsTableFilterComposer f) f,
  ) {
    final $$AppointmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.appointments,
      getReferencedColumn: (t) => t.studyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AppointmentsTableFilterComposer(
            $db: $db,
            $table: $db.appointments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> voiceNotesRefs(
    Expression<bool> Function($$VoiceNotesTableFilterComposer f) f,
  ) {
    final $$VoiceNotesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.voiceNotes,
      getReferencedColumn: (t) => t.studyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VoiceNotesTableFilterComposer(
            $db: $db,
            $table: $db.voiceNotes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BibleStudiesTableOrderingComposer
    extends Composer<_$AppDatabase, $BibleStudiesTable> {
  $$BibleStudiesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get publicationId => $composableBuilder(
    column: $table.publicationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get currentLesson => $composableBuilder(
    column: $table.currentLesson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get currentParagraph => $composableBuilder(
    column: $table.currentParagraph,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get manualReference => $composableBuilder(
    column: $table.manualReference,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get frequency => $composableBuilder(
    column: $table.frequency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get learningGoals => $composableBuilder(
    column: $table.learningGoals,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pendingDoubts => $composableBuilder(
    column: $table.pendingDoubts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nextTopic => $composableBuilder(
    column: $table.nextTopic,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pauseOrCloseReason => $composableBuilder(
    column: $table.pauseOrCloseReason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSessionAt => $composableBuilder(
    column: $table.lastSessionAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextPlannedAt => $composableBuilder(
    column: $table.nextPlannedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BibleStudiesTableAnnotationComposer
    extends Composer<_$AppDatabase, $BibleStudiesTable> {
  $$BibleStudiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get publicationId => $composableBuilder(
    column: $table.publicationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => column);

  GeneratedColumn<int> get currentLesson => $composableBuilder(
    column: $table.currentLesson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get currentParagraph => $composableBuilder(
    column: $table.currentParagraph,
    builder: (column) => column,
  );

  GeneratedColumn<String> get manualReference => $composableBuilder(
    column: $table.manualReference,
    builder: (column) => column,
  );

  GeneratedColumn<String> get frequency =>
      $composableBuilder(column: $table.frequency, builder: (column) => column);

  GeneratedColumn<String> get learningGoals => $composableBuilder(
    column: $table.learningGoals,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pendingDoubts => $composableBuilder(
    column: $table.pendingDoubts,
    builder: (column) => column,
  );

  GeneratedColumn<String> get nextTopic =>
      $composableBuilder(column: $table.nextTopic, builder: (column) => column);

  GeneratedColumn<String> get pauseOrCloseReason => $composableBuilder(
    column: $table.pauseOrCloseReason,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSessionAt => $composableBuilder(
    column: $table.lastSessionAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get nextPlannedAt => $composableBuilder(
    column: $table.nextPlannedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  Expression<T> studyParticipantsRefs<T extends Object>(
    Expression<T> Function($$StudyParticipantsTableAnnotationComposer a) f,
  ) {
    final $$StudyParticipantsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.studyParticipants,
          getReferencedColumn: (t) => t.studyId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$StudyParticipantsTableAnnotationComposer(
                $db: $db,
                $table: $db.studyParticipants,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> studySessionsRefs<T extends Object>(
    Expression<T> Function($$StudySessionsTableAnnotationComposer a) f,
  ) {
    final $$StudySessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.studySessions,
      getReferencedColumn: (t) => t.studyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StudySessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.studySessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> appointmentsRefs<T extends Object>(
    Expression<T> Function($$AppointmentsTableAnnotationComposer a) f,
  ) {
    final $$AppointmentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.appointments,
      getReferencedColumn: (t) => t.studyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AppointmentsTableAnnotationComposer(
            $db: $db,
            $table: $db.appointments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> voiceNotesRefs<T extends Object>(
    Expression<T> Function($$VoiceNotesTableAnnotationComposer a) f,
  ) {
    final $$VoiceNotesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.voiceNotes,
      getReferencedColumn: (t) => t.studyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VoiceNotesTableAnnotationComposer(
            $db: $db,
            $table: $db.voiceNotes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BibleStudiesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BibleStudiesTable,
          BibleStudyEntry,
          $$BibleStudiesTableFilterComposer,
          $$BibleStudiesTableOrderingComposer,
          $$BibleStudiesTableAnnotationComposer,
          $$BibleStudiesTableCreateCompanionBuilder,
          $$BibleStudiesTableUpdateCompanionBuilder,
          (BibleStudyEntry, $$BibleStudiesTableReferences),
          BibleStudyEntry,
          PrefetchHooks Function({
            bool studyParticipantsRefs,
            bool studySessionsRefs,
            bool appointmentsRefs,
            bool voiceNotesRefs,
          })
        > {
  $$BibleStudiesTableTableManager(_$AppDatabase db, $BibleStudiesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BibleStudiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BibleStudiesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BibleStudiesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> ownerId = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> publicationId = const Value.absent(),
                Value<String> language = const Value.absent(),
                Value<int?> currentLesson = const Value.absent(),
                Value<int?> currentParagraph = const Value.absent(),
                Value<String?> manualReference = const Value.absent(),
                Value<String> frequency = const Value.absent(),
                Value<String?> learningGoals = const Value.absent(),
                Value<String?> pendingDoubts = const Value.absent(),
                Value<String?> nextTopic = const Value.absent(),
                Value<String?> pauseOrCloseReason = const Value.absent(),
                Value<DateTime?> lastSessionAt = const Value.absent(),
                Value<DateTime?> nextPlannedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BibleStudiesCompanion(
                id: id,
                title: title,
                ownerId: ownerId,
                startedAt: startedAt,
                status: status,
                publicationId: publicationId,
                language: language,
                currentLesson: currentLesson,
                currentParagraph: currentParagraph,
                manualReference: manualReference,
                frequency: frequency,
                learningGoals: learningGoals,
                pendingDoubts: pendingDoubts,
                nextTopic: nextTopic,
                pauseOrCloseReason: pauseOrCloseReason,
                lastSessionAt: lastSessionAt,
                nextPlannedAt: nextPlannedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                Value<String> ownerId = const Value.absent(),
                required DateTime startedAt,
                Value<String> status = const Value.absent(),
                required String publicationId,
                Value<String> language = const Value.absent(),
                Value<int?> currentLesson = const Value.absent(),
                Value<int?> currentParagraph = const Value.absent(),
                Value<String?> manualReference = const Value.absent(),
                Value<String> frequency = const Value.absent(),
                Value<String?> learningGoals = const Value.absent(),
                Value<String?> pendingDoubts = const Value.absent(),
                Value<String?> nextTopic = const Value.absent(),
                Value<String?> pauseOrCloseReason = const Value.absent(),
                Value<DateTime?> lastSessionAt = const Value.absent(),
                Value<DateTime?> nextPlannedAt = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BibleStudiesCompanion.insert(
                id: id,
                title: title,
                ownerId: ownerId,
                startedAt: startedAt,
                status: status,
                publicationId: publicationId,
                language: language,
                currentLesson: currentLesson,
                currentParagraph: currentParagraph,
                manualReference: manualReference,
                frequency: frequency,
                learningGoals: learningGoals,
                pendingDoubts: pendingDoubts,
                nextTopic: nextTopic,
                pauseOrCloseReason: pauseOrCloseReason,
                lastSessionAt: lastSessionAt,
                nextPlannedAt: nextPlannedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BibleStudiesTable, BibleStudyEntry>(table),
                  $$BibleStudiesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                studyParticipantsRefs = false,
                studySessionsRefs = false,
                appointmentsRefs = false,
                voiceNotesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (studyParticipantsRefs) db.studyParticipants,
                    if (studySessionsRefs) db.studySessions,
                    if (appointmentsRefs) db.appointments,
                    if (voiceNotesRefs) db.voiceNotes,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (studyParticipantsRefs)
                        await $_getPrefetchedDataByColumns<
                          BibleStudyEntry,
                          $BibleStudiesTable,
                          StudyParticipantEntry,
                          $StudyParticipantsTable
                        >(
                          currentTable: table,
                          referencedTable: $$BibleStudiesTableReferences
                              ._studyParticipantsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$BibleStudiesTableReferences(
                                db,
                                table,
                                p0,
                              ).studyParticipantsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'study_id',
                          typedResults: items,
                        ),
                      if (studySessionsRefs)
                        await $_getPrefetchedDataByColumns<
                          BibleStudyEntry,
                          $BibleStudiesTable,
                          StudySessionEntry,
                          $StudySessionsTable
                        >(
                          currentTable: table,
                          referencedTable: $$BibleStudiesTableReferences
                              ._studySessionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$BibleStudiesTableReferences(
                                db,
                                table,
                                p0,
                              ).studySessionsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'study_id',
                          typedResults: items,
                        ),
                      if (appointmentsRefs)
                        await $_getPrefetchedDataByColumns<
                          BibleStudyEntry,
                          $BibleStudiesTable,
                          AppointmentEntry,
                          $AppointmentsTable
                        >(
                          currentTable: table,
                          referencedTable: $$BibleStudiesTableReferences
                              ._appointmentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$BibleStudiesTableReferences(
                                db,
                                table,
                                p0,
                              ).appointmentsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'study_id',
                          typedResults: items,
                        ),
                      if (voiceNotesRefs)
                        await $_getPrefetchedDataByColumns<
                          BibleStudyEntry,
                          $BibleStudiesTable,
                          VoiceNoteEntry,
                          $VoiceNotesTable
                        >(
                          currentTable: table,
                          referencedTable: $$BibleStudiesTableReferences
                              ._voiceNotesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$BibleStudiesTableReferences(
                                db,
                                table,
                                p0,
                              ).voiceNotesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'study_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$BibleStudiesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BibleStudiesTable,
      BibleStudyEntry,
      $$BibleStudiesTableFilterComposer,
      $$BibleStudiesTableOrderingComposer,
      $$BibleStudiesTableAnnotationComposer,
      $$BibleStudiesTableCreateCompanionBuilder,
      $$BibleStudiesTableUpdateCompanionBuilder,
      (BibleStudyEntry, $$BibleStudiesTableReferences),
      BibleStudyEntry,
      PrefetchHooks Function({
        bool studyParticipantsRefs,
        bool studySessionsRefs,
        bool appointmentsRefs,
        bool voiceNotesRefs,
      })
    >;
typedef $$StudyParticipantsTableCreateCompanionBuilder =
    StudyParticipantsCompanion Function({
      required String id,
      required String studyId,
      required String personId,
      Value<bool> isPrimary,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> revision,
      Value<int> rowid,
    });
typedef $$StudyParticipantsTableUpdateCompanionBuilder =
    StudyParticipantsCompanion Function({
      Value<String> id,
      Value<String> studyId,
      Value<String> personId,
      Value<bool> isPrimary,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> revision,
      Value<int> rowid,
    });

final class $$StudyParticipantsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $StudyParticipantsTable,
          StudyParticipantEntry
        > {
  $$StudyParticipantsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $BibleStudiesTable _studyIdTable(_$AppDatabase db) => db.bibleStudies
      .createAlias('study_participants__study_id__bible_studies__id');

  $$BibleStudiesTableProcessedTableManager get studyId {
    final $_column = $_itemColumn<String>('study_id')!;

    final manager = $$BibleStudiesTableTableManager(
      $_db,
      $_db.bibleStudies,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_studyIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $PeopleTable _personIdTable(_$AppDatabase db) =>
      db.people.createAlias('study_participants__person_id__people__id');

  $$PeopleTableProcessedTableManager get personId {
    final $_column = $_itemColumn<String>('person_id')!;

    final manager = $$PeopleTableTableManager(
      $_db,
      $_db.people,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_personIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$StudyParticipantsTableFilterComposer
    extends Composer<_$AppDatabase, $StudyParticipantsTable> {
  $$StudyParticipantsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPrimary => $composableBuilder(
    column: $table.isPrimary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  $$BibleStudiesTableFilterComposer get studyId {
    final $$BibleStudiesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.studyId,
      referencedTable: $db.bibleStudies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BibleStudiesTableFilterComposer(
            $db: $db,
            $table: $db.bibleStudies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PeopleTableFilterComposer get personId {
    final $$PeopleTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.personId,
      referencedTable: $db.people,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeopleTableFilterComposer(
            $db: $db,
            $table: $db.people,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StudyParticipantsTableOrderingComposer
    extends Composer<_$AppDatabase, $StudyParticipantsTable> {
  $$StudyParticipantsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPrimary => $composableBuilder(
    column: $table.isPrimary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  $$BibleStudiesTableOrderingComposer get studyId {
    final $$BibleStudiesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.studyId,
      referencedTable: $db.bibleStudies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BibleStudiesTableOrderingComposer(
            $db: $db,
            $table: $db.bibleStudies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PeopleTableOrderingComposer get personId {
    final $$PeopleTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.personId,
      referencedTable: $db.people,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeopleTableOrderingComposer(
            $db: $db,
            $table: $db.people,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StudyParticipantsTableAnnotationComposer
    extends Composer<_$AppDatabase, $StudyParticipantsTable> {
  $$StudyParticipantsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<bool> get isPrimary =>
      $composableBuilder(column: $table.isPrimary, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  $$BibleStudiesTableAnnotationComposer get studyId {
    final $$BibleStudiesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.studyId,
      referencedTable: $db.bibleStudies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BibleStudiesTableAnnotationComposer(
            $db: $db,
            $table: $db.bibleStudies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PeopleTableAnnotationComposer get personId {
    final $$PeopleTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.personId,
      referencedTable: $db.people,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeopleTableAnnotationComposer(
            $db: $db,
            $table: $db.people,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StudyParticipantsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StudyParticipantsTable,
          StudyParticipantEntry,
          $$StudyParticipantsTableFilterComposer,
          $$StudyParticipantsTableOrderingComposer,
          $$StudyParticipantsTableAnnotationComposer,
          $$StudyParticipantsTableCreateCompanionBuilder,
          $$StudyParticipantsTableUpdateCompanionBuilder,
          (StudyParticipantEntry, $$StudyParticipantsTableReferences),
          StudyParticipantEntry,
          PrefetchHooks Function({bool studyId, bool personId})
        > {
  $$StudyParticipantsTableTableManager(
    _$AppDatabase db,
    $StudyParticipantsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StudyParticipantsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StudyParticipantsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StudyParticipantsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> studyId = const Value.absent(),
                Value<String> personId = const Value.absent(),
                Value<bool> isPrimary = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StudyParticipantsCompanion(
                id: id,
                studyId: studyId,
                personId: personId,
                isPrimary: isPrimary,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String studyId,
                required String personId,
                Value<bool> isPrimary = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StudyParticipantsCompanion.insert(
                id: id,
                studyId: studyId,
                personId: personId,
                isPrimary: isPrimary,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$StudyParticipantsTable, StudyParticipantEntry>(
                    table,
                  ),
                  $$StudyParticipantsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({studyId = false, personId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
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
                      dynamic
                    >
                  >(state) {
                    if (studyId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.studyId,
                        referencedTable: $$StudyParticipantsTableReferences
                            ._studyIdTable(db),
                        referencedColumn: $$StudyParticipantsTableReferences
                            ._studyIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (personId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.personId,
                        referencedTable: $$StudyParticipantsTableReferences
                            ._personIdTable(db),
                        referencedColumn: $$StudyParticipantsTableReferences
                            ._personIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$StudyParticipantsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StudyParticipantsTable,
      StudyParticipantEntry,
      $$StudyParticipantsTableFilterComposer,
      $$StudyParticipantsTableOrderingComposer,
      $$StudyParticipantsTableAnnotationComposer,
      $$StudyParticipantsTableCreateCompanionBuilder,
      $$StudyParticipantsTableUpdateCompanionBuilder,
      (StudyParticipantEntry, $$StudyParticipantsTableReferences),
      StudyParticipantEntry,
      PrefetchHooks Function({bool studyId, bool personId})
    >;
typedef $$StudySessionsTableCreateCompanionBuilder =
    StudySessionsCompanion Function({
      required String id,
      required String studyId,
      required DateTime dateTimeField,
      Value<String?> publicationCode,
      Value<int?> lessonCovered,
      Value<String?> paragraphsCovered,
      Value<String?> sessionNotes,
      Value<String?> pendingQuestions,
      Value<String?> nextStep,
      Value<String> status,
      Value<String> participantIds,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> revision,
      Value<int> rowid,
    });
typedef $$StudySessionsTableUpdateCompanionBuilder =
    StudySessionsCompanion Function({
      Value<String> id,
      Value<String> studyId,
      Value<DateTime> dateTimeField,
      Value<String?> publicationCode,
      Value<int?> lessonCovered,
      Value<String?> paragraphsCovered,
      Value<String?> sessionNotes,
      Value<String?> pendingQuestions,
      Value<String?> nextStep,
      Value<String> status,
      Value<String> participantIds,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> revision,
      Value<int> rowid,
    });

final class $$StudySessionsTableReferences
    extends
        BaseReferences<_$AppDatabase, $StudySessionsTable, StudySessionEntry> {
  $$StudySessionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $BibleStudiesTable _studyIdTable(_$AppDatabase db) => db.bibleStudies
      .createAlias('study_sessions__study_id__bible_studies__id');

  $$BibleStudiesTableProcessedTableManager get studyId {
    final $_column = $_itemColumn<String>('study_id')!;

    final manager = $$BibleStudiesTableTableManager(
      $_db,
      $_db.bibleStudies,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_studyIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$StudySessionsTableFilterComposer
    extends Composer<_$AppDatabase, $StudySessionsTable> {
  $$StudySessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dateTimeField => $composableBuilder(
    column: $table.dateTimeField,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get publicationCode => $composableBuilder(
    column: $table.publicationCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lessonCovered => $composableBuilder(
    column: $table.lessonCovered,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get paragraphsCovered => $composableBuilder(
    column: $table.paragraphsCovered,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sessionNotes => $composableBuilder(
    column: $table.sessionNotes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pendingQuestions => $composableBuilder(
    column: $table.pendingQuestions,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nextStep => $composableBuilder(
    column: $table.nextStep,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get participantIds => $composableBuilder(
    column: $table.participantIds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  $$BibleStudiesTableFilterComposer get studyId {
    final $$BibleStudiesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.studyId,
      referencedTable: $db.bibleStudies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BibleStudiesTableFilterComposer(
            $db: $db,
            $table: $db.bibleStudies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StudySessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $StudySessionsTable> {
  $$StudySessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dateTimeField => $composableBuilder(
    column: $table.dateTimeField,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get publicationCode => $composableBuilder(
    column: $table.publicationCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lessonCovered => $composableBuilder(
    column: $table.lessonCovered,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paragraphsCovered => $composableBuilder(
    column: $table.paragraphsCovered,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sessionNotes => $composableBuilder(
    column: $table.sessionNotes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pendingQuestions => $composableBuilder(
    column: $table.pendingQuestions,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nextStep => $composableBuilder(
    column: $table.nextStep,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get participantIds => $composableBuilder(
    column: $table.participantIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  $$BibleStudiesTableOrderingComposer get studyId {
    final $$BibleStudiesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.studyId,
      referencedTable: $db.bibleStudies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BibleStudiesTableOrderingComposer(
            $db: $db,
            $table: $db.bibleStudies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StudySessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $StudySessionsTable> {
  $$StudySessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get dateTimeField => $composableBuilder(
    column: $table.dateTimeField,
    builder: (column) => column,
  );

  GeneratedColumn<String> get publicationCode => $composableBuilder(
    column: $table.publicationCode,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lessonCovered => $composableBuilder(
    column: $table.lessonCovered,
    builder: (column) => column,
  );

  GeneratedColumn<String> get paragraphsCovered => $composableBuilder(
    column: $table.paragraphsCovered,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sessionNotes => $composableBuilder(
    column: $table.sessionNotes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pendingQuestions => $composableBuilder(
    column: $table.pendingQuestions,
    builder: (column) => column,
  );

  GeneratedColumn<String> get nextStep =>
      $composableBuilder(column: $table.nextStep, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get participantIds => $composableBuilder(
    column: $table.participantIds,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  $$BibleStudiesTableAnnotationComposer get studyId {
    final $$BibleStudiesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.studyId,
      referencedTable: $db.bibleStudies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BibleStudiesTableAnnotationComposer(
            $db: $db,
            $table: $db.bibleStudies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StudySessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StudySessionsTable,
          StudySessionEntry,
          $$StudySessionsTableFilterComposer,
          $$StudySessionsTableOrderingComposer,
          $$StudySessionsTableAnnotationComposer,
          $$StudySessionsTableCreateCompanionBuilder,
          $$StudySessionsTableUpdateCompanionBuilder,
          (StudySessionEntry, $$StudySessionsTableReferences),
          StudySessionEntry,
          PrefetchHooks Function({bool studyId})
        > {
  $$StudySessionsTableTableManager(_$AppDatabase db, $StudySessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StudySessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StudySessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StudySessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> studyId = const Value.absent(),
                Value<DateTime> dateTimeField = const Value.absent(),
                Value<String?> publicationCode = const Value.absent(),
                Value<int?> lessonCovered = const Value.absent(),
                Value<String?> paragraphsCovered = const Value.absent(),
                Value<String?> sessionNotes = const Value.absent(),
                Value<String?> pendingQuestions = const Value.absent(),
                Value<String?> nextStep = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> participantIds = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StudySessionsCompanion(
                id: id,
                studyId: studyId,
                dateTimeField: dateTimeField,
                publicationCode: publicationCode,
                lessonCovered: lessonCovered,
                paragraphsCovered: paragraphsCovered,
                sessionNotes: sessionNotes,
                pendingQuestions: pendingQuestions,
                nextStep: nextStep,
                status: status,
                participantIds: participantIds,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String studyId,
                required DateTime dateTimeField,
                Value<String?> publicationCode = const Value.absent(),
                Value<int?> lessonCovered = const Value.absent(),
                Value<String?> paragraphsCovered = const Value.absent(),
                Value<String?> sessionNotes = const Value.absent(),
                Value<String?> pendingQuestions = const Value.absent(),
                Value<String?> nextStep = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> participantIds = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StudySessionsCompanion.insert(
                id: id,
                studyId: studyId,
                dateTimeField: dateTimeField,
                publicationCode: publicationCode,
                lessonCovered: lessonCovered,
                paragraphsCovered: paragraphsCovered,
                sessionNotes: sessionNotes,
                pendingQuestions: pendingQuestions,
                nextStep: nextStep,
                status: status,
                participantIds: participantIds,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$StudySessionsTable, StudySessionEntry>(table),
                  $$StudySessionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({studyId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
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
                      dynamic
                    >
                  >(state) {
                    if (studyId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.studyId,
                        referencedTable: $$StudySessionsTableReferences
                            ._studyIdTable(db),
                        referencedColumn: $$StudySessionsTableReferences
                            ._studyIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$StudySessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StudySessionsTable,
      StudySessionEntry,
      $$StudySessionsTableFilterComposer,
      $$StudySessionsTableOrderingComposer,
      $$StudySessionsTableAnnotationComposer,
      $$StudySessionsTableCreateCompanionBuilder,
      $$StudySessionsTableUpdateCompanionBuilder,
      (StudySessionEntry, $$StudySessionsTableReferences),
      StudySessionEntry,
      PrefetchHooks Function({bool studyId})
    >;
typedef $$AppointmentsTableCreateCompanionBuilder =
    AppointmentsCompanion Function({
      required String id,
      Value<String?> personId,
      Value<String?> studyId,
      required String title,
      required DateTime startTime,
      required DateTime endTime,
      Value<int> durationMinutes,
      Value<String> status,
      Value<String?> previousAppointmentId,
      Value<String?> locationNotes,
      Value<int?> reminderMinutesBefore,
      Value<int?> secondReminderMinutesBefore,
      Value<bool> isProvisional,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> revision,
      Value<int> rowid,
    });
typedef $$AppointmentsTableUpdateCompanionBuilder =
    AppointmentsCompanion Function({
      Value<String> id,
      Value<String?> personId,
      Value<String?> studyId,
      Value<String> title,
      Value<DateTime> startTime,
      Value<DateTime> endTime,
      Value<int> durationMinutes,
      Value<String> status,
      Value<String?> previousAppointmentId,
      Value<String?> locationNotes,
      Value<int?> reminderMinutesBefore,
      Value<int?> secondReminderMinutesBefore,
      Value<bool> isProvisional,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> revision,
      Value<int> rowid,
    });

final class $$AppointmentsTableReferences
    extends
        BaseReferences<_$AppDatabase, $AppointmentsTable, AppointmentEntry> {
  $$AppointmentsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PeopleTable _personIdTable(_$AppDatabase db) =>
      db.people.createAlias('appointments__person_id__people__id');

  $$PeopleTableProcessedTableManager? get personId {
    final $_column = $_itemColumn<String>('person_id');
    if ($_column == null) return null;
    final manager = $$PeopleTableTableManager(
      $_db,
      $_db.people,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_personIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $BibleStudiesTable _studyIdTable(_$AppDatabase db) =>
      db.bibleStudies.createAlias('appointments__study_id__bible_studies__id');

  $$BibleStudiesTableProcessedTableManager? get studyId {
    final $_column = $_itemColumn<String>('study_id');
    if ($_column == null) return null;
    final manager = $$BibleStudiesTableTableManager(
      $_db,
      $_db.bibleStudies,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_studyIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AppointmentsTableFilterComposer
    extends Composer<_$AppDatabase, $AppointmentsTable> {
  $$AppointmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startTime => $composableBuilder(
    column: $table.startTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endTime => $composableBuilder(
    column: $table.endTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMinutes => $composableBuilder(
    column: $table.durationMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get previousAppointmentId => $composableBuilder(
    column: $table.previousAppointmentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get locationNotes => $composableBuilder(
    column: $table.locationNotes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reminderMinutesBefore => $composableBuilder(
    column: $table.reminderMinutesBefore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get secondReminderMinutesBefore => $composableBuilder(
    column: $table.secondReminderMinutesBefore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isProvisional => $composableBuilder(
    column: $table.isProvisional,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  $$PeopleTableFilterComposer get personId {
    final $$PeopleTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.personId,
      referencedTable: $db.people,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeopleTableFilterComposer(
            $db: $db,
            $table: $db.people,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$BibleStudiesTableFilterComposer get studyId {
    final $$BibleStudiesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.studyId,
      referencedTable: $db.bibleStudies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BibleStudiesTableFilterComposer(
            $db: $db,
            $table: $db.bibleStudies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AppointmentsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppointmentsTable> {
  $$AppointmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startTime => $composableBuilder(
    column: $table.startTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endTime => $composableBuilder(
    column: $table.endTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMinutes => $composableBuilder(
    column: $table.durationMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get previousAppointmentId => $composableBuilder(
    column: $table.previousAppointmentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get locationNotes => $composableBuilder(
    column: $table.locationNotes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reminderMinutesBefore => $composableBuilder(
    column: $table.reminderMinutesBefore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get secondReminderMinutesBefore => $composableBuilder(
    column: $table.secondReminderMinutesBefore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isProvisional => $composableBuilder(
    column: $table.isProvisional,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  $$PeopleTableOrderingComposer get personId {
    final $$PeopleTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.personId,
      referencedTable: $db.people,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeopleTableOrderingComposer(
            $db: $db,
            $table: $db.people,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$BibleStudiesTableOrderingComposer get studyId {
    final $$BibleStudiesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.studyId,
      referencedTable: $db.bibleStudies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BibleStudiesTableOrderingComposer(
            $db: $db,
            $table: $db.bibleStudies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AppointmentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppointmentsTable> {
  $$AppointmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<DateTime> get startTime =>
      $composableBuilder(column: $table.startTime, builder: (column) => column);

  GeneratedColumn<DateTime> get endTime =>
      $composableBuilder(column: $table.endTime, builder: (column) => column);

  GeneratedColumn<int> get durationMinutes => $composableBuilder(
    column: $table.durationMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get previousAppointmentId => $composableBuilder(
    column: $table.previousAppointmentId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get locationNotes => $composableBuilder(
    column: $table.locationNotes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get reminderMinutesBefore => $composableBuilder(
    column: $table.reminderMinutesBefore,
    builder: (column) => column,
  );

  GeneratedColumn<int> get secondReminderMinutesBefore => $composableBuilder(
    column: $table.secondReminderMinutesBefore,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isProvisional => $composableBuilder(
    column: $table.isProvisional,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  $$PeopleTableAnnotationComposer get personId {
    final $$PeopleTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.personId,
      referencedTable: $db.people,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeopleTableAnnotationComposer(
            $db: $db,
            $table: $db.people,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$BibleStudiesTableAnnotationComposer get studyId {
    final $$BibleStudiesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.studyId,
      referencedTable: $db.bibleStudies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BibleStudiesTableAnnotationComposer(
            $db: $db,
            $table: $db.bibleStudies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AppointmentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppointmentsTable,
          AppointmentEntry,
          $$AppointmentsTableFilterComposer,
          $$AppointmentsTableOrderingComposer,
          $$AppointmentsTableAnnotationComposer,
          $$AppointmentsTableCreateCompanionBuilder,
          $$AppointmentsTableUpdateCompanionBuilder,
          (AppointmentEntry, $$AppointmentsTableReferences),
          AppointmentEntry,
          PrefetchHooks Function({bool personId, bool studyId})
        > {
  $$AppointmentsTableTableManager(_$AppDatabase db, $AppointmentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppointmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppointmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppointmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> personId = const Value.absent(),
                Value<String?> studyId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<DateTime> startTime = const Value.absent(),
                Value<DateTime> endTime = const Value.absent(),
                Value<int> durationMinutes = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> previousAppointmentId = const Value.absent(),
                Value<String?> locationNotes = const Value.absent(),
                Value<int?> reminderMinutesBefore = const Value.absent(),
                Value<int?> secondReminderMinutesBefore = const Value.absent(),
                Value<bool> isProvisional = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppointmentsCompanion(
                id: id,
                personId: personId,
                studyId: studyId,
                title: title,
                startTime: startTime,
                endTime: endTime,
                durationMinutes: durationMinutes,
                status: status,
                previousAppointmentId: previousAppointmentId,
                locationNotes: locationNotes,
                reminderMinutesBefore: reminderMinutesBefore,
                secondReminderMinutesBefore: secondReminderMinutesBefore,
                isProvisional: isProvisional,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> personId = const Value.absent(),
                Value<String?> studyId = const Value.absent(),
                required String title,
                required DateTime startTime,
                required DateTime endTime,
                Value<int> durationMinutes = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> previousAppointmentId = const Value.absent(),
                Value<String?> locationNotes = const Value.absent(),
                Value<int?> reminderMinutesBefore = const Value.absent(),
                Value<int?> secondReminderMinutesBefore = const Value.absent(),
                Value<bool> isProvisional = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppointmentsCompanion.insert(
                id: id,
                personId: personId,
                studyId: studyId,
                title: title,
                startTime: startTime,
                endTime: endTime,
                durationMinutes: durationMinutes,
                status: status,
                previousAppointmentId: previousAppointmentId,
                locationNotes: locationNotes,
                reminderMinutesBefore: reminderMinutesBefore,
                secondReminderMinutesBefore: secondReminderMinutesBefore,
                isProvisional: isProvisional,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AppointmentsTable, AppointmentEntry>(table),
                  $$AppointmentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({personId = false, studyId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
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
                      dynamic
                    >
                  >(state) {
                    if (personId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.personId,
                        referencedTable: $$AppointmentsTableReferences
                            ._personIdTable(db),
                        referencedColumn: $$AppointmentsTableReferences
                            ._personIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (studyId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.studyId,
                        referencedTable: $$AppointmentsTableReferences
                            ._studyIdTable(db),
                        referencedColumn: $$AppointmentsTableReferences
                            ._studyIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AppointmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppointmentsTable,
      AppointmentEntry,
      $$AppointmentsTableFilterComposer,
      $$AppointmentsTableOrderingComposer,
      $$AppointmentsTableAnnotationComposer,
      $$AppointmentsTableCreateCompanionBuilder,
      $$AppointmentsTableUpdateCompanionBuilder,
      (AppointmentEntry, $$AppointmentsTableReferences),
      AppointmentEntry,
      PrefetchHooks Function({bool personId, bool studyId})
    >;
typedef $$ActivityRecordsTableCreateCompanionBuilder =
    ActivityRecordsCompanion Function({
      required String id,
      required DateTime date,
      required int durationSeconds,
      required String modality,
      Value<String?> notes,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> revision,
      Value<int> rowid,
    });
typedef $$ActivityRecordsTableUpdateCompanionBuilder =
    ActivityRecordsCompanion Function({
      Value<String> id,
      Value<DateTime> date,
      Value<int> durationSeconds,
      Value<String> modality,
      Value<String?> notes,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> revision,
      Value<int> rowid,
    });

class $$ActivityRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $ActivityRecordsTable> {
  $$ActivityRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get modality => $composableBuilder(
    column: $table.modality,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ActivityRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $ActivityRecordsTable> {
  $$ActivityRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get modality => $composableBuilder(
    column: $table.modality,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ActivityRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ActivityRecordsTable> {
  $$ActivityRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get modality =>
      $composableBuilder(column: $table.modality, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);
}

class $$ActivityRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ActivityRecordsTable,
          ActivityRecordEntry,
          $$ActivityRecordsTableFilterComposer,
          $$ActivityRecordsTableOrderingComposer,
          $$ActivityRecordsTableAnnotationComposer,
          $$ActivityRecordsTableCreateCompanionBuilder,
          $$ActivityRecordsTableUpdateCompanionBuilder,
          (
            ActivityRecordEntry,
            BaseReferences<
              _$AppDatabase,
              $ActivityRecordsTable,
              ActivityRecordEntry
            >,
          ),
          ActivityRecordEntry,
          PrefetchHooks Function()
        > {
  $$ActivityRecordsTableTableManager(
    _$AppDatabase db,
    $ActivityRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ActivityRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ActivityRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ActivityRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<int> durationSeconds = const Value.absent(),
                Value<String> modality = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ActivityRecordsCompanion(
                id: id,
                date: date,
                durationSeconds: durationSeconds,
                modality: modality,
                notes: notes,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required DateTime date,
                required int durationSeconds,
                required String modality,
                Value<String?> notes = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ActivityRecordsCompanion.insert(
                id: id,
                date: date,
                durationSeconds: durationSeconds,
                modality: modality,
                notes: notes,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ActivityRecordsTable, ActivityRecordEntry>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $ActivityRecordsTable,
                    ActivityRecordEntry
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ActivityRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ActivityRecordsTable,
      ActivityRecordEntry,
      $$ActivityRecordsTableFilterComposer,
      $$ActivityRecordsTableOrderingComposer,
      $$ActivityRecordsTableAnnotationComposer,
      $$ActivityRecordsTableCreateCompanionBuilder,
      $$ActivityRecordsTableUpdateCompanionBuilder,
      (
        ActivityRecordEntry,
        BaseReferences<
          _$AppDatabase,
          $ActivityRecordsTable,
          ActivityRecordEntry
        >,
      ),
      ActivityRecordEntry,
      PrefetchHooks Function()
    >;
typedef $$SyncQueueTableCreateCompanionBuilder = SyncQueueCompanion Function({
  required String id,
  required String entityType,
  required String entityId,
  required String operation,
  required String payload,
  required DateTime createdAt,
  Value<int> attempts,
  Value<String?> lastError,
  Value<String> status,
  Value<int> rowid,
});
typedef $$SyncQueueTableUpdateCompanionBuilder = SyncQueueCompanion Function({
  Value<String> id,
  Value<String> entityType,
  Value<String> entityId,
  Value<String> operation,
  Value<String> payload,
  Value<DateTime> createdAt,
  Value<int> attempts,
  Value<String?> lastError,
  Value<String> status,
  Value<int> rowid,
});

class $$SyncQueueTableFilterComposer
    extends Composer<_$AppDatabase, $SyncQueueTable> {
  $$SyncQueueTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncQueueTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncQueueTable> {
  $$SyncQueueTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncQueueTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncQueueTable> {
  $$SyncQueueTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get operation =>
      $composableBuilder(column: $table.operation, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);
}

class $$SyncQueueTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncQueueTable,
          SyncQueueEntry,
          $$SyncQueueTableFilterComposer,
          $$SyncQueueTableOrderingComposer,
          $$SyncQueueTableAnnotationComposer,
          $$SyncQueueTableCreateCompanionBuilder,
          $$SyncQueueTableUpdateCompanionBuilder,
          (
            SyncQueueEntry,
            BaseReferences<_$AppDatabase, $SyncQueueTable, SyncQueueEntry>,
          ),
          SyncQueueEntry,
          PrefetchHooks Function()
        > {
  $$SyncQueueTableTableManager(_$AppDatabase db, $SyncQueueTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncQueueTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncQueueTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncQueueTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> operation = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncQueueCompanion(
                id: id,
                entityType: entityType,
                entityId: entityId,
                operation: operation,
                payload: payload,
                createdAt: createdAt,
                attempts: attempts,
                lastError: lastError,
                status: status,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String entityType,
                required String entityId,
                required String operation,
                required String payload,
                required DateTime createdAt,
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncQueueCompanion.insert(
                id: id,
                entityType: entityType,
                entityId: entityId,
                operation: operation,
                payload: payload,
                createdAt: createdAt,
                attempts: attempts,
                lastError: lastError,
                status: status,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncQueueTable, SyncQueueEntry>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $SyncQueueTable,
                    SyncQueueEntry
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncQueueTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncQueueTable,
      SyncQueueEntry,
      $$SyncQueueTableFilterComposer,
      $$SyncQueueTableOrderingComposer,
      $$SyncQueueTableAnnotationComposer,
      $$SyncQueueTableCreateCompanionBuilder,
      $$SyncQueueTableUpdateCompanionBuilder,
      (
        SyncQueueEntry,
        BaseReferences<_$AppDatabase, $SyncQueueTable, SyncQueueEntry>,
      ),
      SyncQueueEntry,
      PrefetchHooks Function()
    >;
typedef $$VoiceNotesTableCreateCompanionBuilder = VoiceNotesCompanion Function({
  required String id,
  required String personId,
  Value<String?> visitId,
  Value<String?> studyId,
  Value<String?> audioFilePath,
  Value<int> audioDurationSeconds,
  required String transcription,
  Value<int?> detectedLesson,
  Value<int?> detectedPoint,
  Value<String?> extractedPendingDoubt,
  Value<String?> extractedEmpathyNote,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> revision,
  Value<int> rowid,
});
typedef $$VoiceNotesTableUpdateCompanionBuilder = VoiceNotesCompanion Function({
  Value<String> id,
  Value<String> personId,
  Value<String?> visitId,
  Value<String?> studyId,
  Value<String?> audioFilePath,
  Value<int> audioDurationSeconds,
  Value<String> transcription,
  Value<int?> detectedLesson,
  Value<int?> detectedPoint,
  Value<String?> extractedPendingDoubt,
  Value<String?> extractedEmpathyNote,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> revision,
  Value<int> rowid,
});

final class $$VoiceNotesTableReferences
    extends BaseReferences<_$AppDatabase, $VoiceNotesTable, VoiceNoteEntry> {
  $$VoiceNotesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PeopleTable _personIdTable(_$AppDatabase db) =>
      db.people.createAlias('voice_notes__person_id__people__id');

  $$PeopleTableProcessedTableManager get personId {
    final $_column = $_itemColumn<String>('person_id')!;

    final manager = $$PeopleTableTableManager(
      $_db,
      $_db.people,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_personIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $VisitsTable _visitIdTable(_$AppDatabase db) =>
      db.visits.createAlias('voice_notes__visit_id__visits__id');

  $$VisitsTableProcessedTableManager? get visitId {
    final $_column = $_itemColumn<String>('visit_id');
    if ($_column == null) return null;
    final manager = $$VisitsTableTableManager(
      $_db,
      $_db.visits,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_visitIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $BibleStudiesTable _studyIdTable(_$AppDatabase db) =>
      db.bibleStudies.createAlias('voice_notes__study_id__bible_studies__id');

  $$BibleStudiesTableProcessedTableManager? get studyId {
    final $_column = $_itemColumn<String>('study_id');
    if ($_column == null) return null;
    final manager = $$BibleStudiesTableTableManager(
      $_db,
      $_db.bibleStudies,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_studyIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$VoiceNotesTableFilterComposer
    extends Composer<_$AppDatabase, $VoiceNotesTable> {
  $$VoiceNotesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get audioFilePath => $composableBuilder(
    column: $table.audioFilePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get audioDurationSeconds => $composableBuilder(
    column: $table.audioDurationSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transcription => $composableBuilder(
    column: $table.transcription,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get detectedLesson => $composableBuilder(
    column: $table.detectedLesson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get detectedPoint => $composableBuilder(
    column: $table.detectedPoint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get extractedPendingDoubt => $composableBuilder(
    column: $table.extractedPendingDoubt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get extractedEmpathyNote => $composableBuilder(
    column: $table.extractedEmpathyNote,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  $$PeopleTableFilterComposer get personId {
    final $$PeopleTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.personId,
      referencedTable: $db.people,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeopleTableFilterComposer(
            $db: $db,
            $table: $db.people,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$VisitsTableFilterComposer get visitId {
    final $$VisitsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.visitId,
      referencedTable: $db.visits,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VisitsTableFilterComposer(
            $db: $db,
            $table: $db.visits,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$BibleStudiesTableFilterComposer get studyId {
    final $$BibleStudiesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.studyId,
      referencedTable: $db.bibleStudies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BibleStudiesTableFilterComposer(
            $db: $db,
            $table: $db.bibleStudies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$VoiceNotesTableOrderingComposer
    extends Composer<_$AppDatabase, $VoiceNotesTable> {
  $$VoiceNotesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get audioFilePath => $composableBuilder(
    column: $table.audioFilePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get audioDurationSeconds => $composableBuilder(
    column: $table.audioDurationSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transcription => $composableBuilder(
    column: $table.transcription,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get detectedLesson => $composableBuilder(
    column: $table.detectedLesson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get detectedPoint => $composableBuilder(
    column: $table.detectedPoint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get extractedPendingDoubt => $composableBuilder(
    column: $table.extractedPendingDoubt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get extractedEmpathyNote => $composableBuilder(
    column: $table.extractedEmpathyNote,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  $$PeopleTableOrderingComposer get personId {
    final $$PeopleTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.personId,
      referencedTable: $db.people,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeopleTableOrderingComposer(
            $db: $db,
            $table: $db.people,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$VisitsTableOrderingComposer get visitId {
    final $$VisitsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.visitId,
      referencedTable: $db.visits,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VisitsTableOrderingComposer(
            $db: $db,
            $table: $db.visits,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$BibleStudiesTableOrderingComposer get studyId {
    final $$BibleStudiesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.studyId,
      referencedTable: $db.bibleStudies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BibleStudiesTableOrderingComposer(
            $db: $db,
            $table: $db.bibleStudies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$VoiceNotesTableAnnotationComposer
    extends Composer<_$AppDatabase, $VoiceNotesTable> {
  $$VoiceNotesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get audioFilePath => $composableBuilder(
    column: $table.audioFilePath,
    builder: (column) => column,
  );

  GeneratedColumn<int> get audioDurationSeconds => $composableBuilder(
    column: $table.audioDurationSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get transcription => $composableBuilder(
    column: $table.transcription,
    builder: (column) => column,
  );

  GeneratedColumn<int> get detectedLesson => $composableBuilder(
    column: $table.detectedLesson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get detectedPoint => $composableBuilder(
    column: $table.detectedPoint,
    builder: (column) => column,
  );

  GeneratedColumn<String> get extractedPendingDoubt => $composableBuilder(
    column: $table.extractedPendingDoubt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get extractedEmpathyNote => $composableBuilder(
    column: $table.extractedEmpathyNote,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  $$PeopleTableAnnotationComposer get personId {
    final $$PeopleTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.personId,
      referencedTable: $db.people,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeopleTableAnnotationComposer(
            $db: $db,
            $table: $db.people,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$VisitsTableAnnotationComposer get visitId {
    final $$VisitsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.visitId,
      referencedTable: $db.visits,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VisitsTableAnnotationComposer(
            $db: $db,
            $table: $db.visits,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$BibleStudiesTableAnnotationComposer get studyId {
    final $$BibleStudiesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.studyId,
      referencedTable: $db.bibleStudies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BibleStudiesTableAnnotationComposer(
            $db: $db,
            $table: $db.bibleStudies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$VoiceNotesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VoiceNotesTable,
          VoiceNoteEntry,
          $$VoiceNotesTableFilterComposer,
          $$VoiceNotesTableOrderingComposer,
          $$VoiceNotesTableAnnotationComposer,
          $$VoiceNotesTableCreateCompanionBuilder,
          $$VoiceNotesTableUpdateCompanionBuilder,
          (VoiceNoteEntry, $$VoiceNotesTableReferences),
          VoiceNoteEntry,
          PrefetchHooks Function({bool personId, bool visitId, bool studyId})
        > {
  $$VoiceNotesTableTableManager(_$AppDatabase db, $VoiceNotesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VoiceNotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VoiceNotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VoiceNotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> personId = const Value.absent(),
                Value<String?> visitId = const Value.absent(),
                Value<String?> studyId = const Value.absent(),
                Value<String?> audioFilePath = const Value.absent(),
                Value<int> audioDurationSeconds = const Value.absent(),
                Value<String> transcription = const Value.absent(),
                Value<int?> detectedLesson = const Value.absent(),
                Value<int?> detectedPoint = const Value.absent(),
                Value<String?> extractedPendingDoubt = const Value.absent(),
                Value<String?> extractedEmpathyNote = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VoiceNotesCompanion(
                id: id,
                personId: personId,
                visitId: visitId,
                studyId: studyId,
                audioFilePath: audioFilePath,
                audioDurationSeconds: audioDurationSeconds,
                transcription: transcription,
                detectedLesson: detectedLesson,
                detectedPoint: detectedPoint,
                extractedPendingDoubt: extractedPendingDoubt,
                extractedEmpathyNote: extractedEmpathyNote,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String personId,
                Value<String?> visitId = const Value.absent(),
                Value<String?> studyId = const Value.absent(),
                Value<String?> audioFilePath = const Value.absent(),
                Value<int> audioDurationSeconds = const Value.absent(),
                required String transcription,
                Value<int?> detectedLesson = const Value.absent(),
                Value<int?> detectedPoint = const Value.absent(),
                Value<String?> extractedPendingDoubt = const Value.absent(),
                Value<String?> extractedEmpathyNote = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VoiceNotesCompanion.insert(
                id: id,
                personId: personId,
                visitId: visitId,
                studyId: studyId,
                audioFilePath: audioFilePath,
                audioDurationSeconds: audioDurationSeconds,
                transcription: transcription,
                detectedLesson: detectedLesson,
                detectedPoint: detectedPoint,
                extractedPendingDoubt: extractedPendingDoubt,
                extractedEmpathyNote: extractedEmpathyNote,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$VoiceNotesTable, VoiceNoteEntry>(table),
                  $$VoiceNotesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({personId = false, visitId = false, studyId = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [],
                  addJoins:
                      <
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
                          dynamic
                        >
                      >(state) {
                        if (personId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.personId,
                            referencedTable: $$VoiceNotesTableReferences
                                ._personIdTable(db),
                            referencedColumn: $$VoiceNotesTableReferences
                                ._personIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (visitId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.visitId,
                            referencedTable: $$VoiceNotesTableReferences
                                ._visitIdTable(db),
                            referencedColumn: $$VoiceNotesTableReferences
                                ._visitIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (studyId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.studyId,
                            referencedTable: $$VoiceNotesTableReferences
                                ._studyIdTable(db),
                            referencedColumn: $$VoiceNotesTableReferences
                                ._studyIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [];
                  },
                );
              },
        ),
      );
}

typedef $$VoiceNotesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VoiceNotesTable,
      VoiceNoteEntry,
      $$VoiceNotesTableFilterComposer,
      $$VoiceNotesTableOrderingComposer,
      $$VoiceNotesTableAnnotationComposer,
      $$VoiceNotesTableCreateCompanionBuilder,
      $$VoiceNotesTableUpdateCompanionBuilder,
      (VoiceNoteEntry, $$VoiceNotesTableReferences),
      VoiceNoteEntry,
      PrefetchHooks Function({bool personId, bool visitId, bool studyId})
    >;
typedef $$PhoneContactsTableCreateCompanionBuilder =
    PhoneContactsCompanion Function({
      required String id,
      required String name,
      required String phone,
      Value<String?> secondaryPhone,
      Value<bool> hasWhatsapp,
      Value<String?> whatsappInfo,
      Value<bool> hasSocial,
      Value<String?> socialPlatform,
      Value<String?> socialHandle,
      Value<String?> notes,
      Value<String> tags,
      Value<String> origin,
      Value<String?> convertedPersonId,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> revision,
      Value<int> rowid,
    });
typedef $$PhoneContactsTableUpdateCompanionBuilder =
    PhoneContactsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> phone,
      Value<String?> secondaryPhone,
      Value<bool> hasWhatsapp,
      Value<String?> whatsappInfo,
      Value<bool> hasSocial,
      Value<String?> socialPlatform,
      Value<String?> socialHandle,
      Value<String?> notes,
      Value<String> tags,
      Value<String> origin,
      Value<String?> convertedPersonId,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> revision,
      Value<int> rowid,
    });

final class $$PhoneContactsTableReferences
    extends
        BaseReferences<_$AppDatabase, $PhoneContactsTable, PhoneContactEntry> {
  $$PhoneContactsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PeopleTable _convertedPersonIdTable(_$AppDatabase db) =>
      db.people.createAlias('phone_contacts__converted_person_id__people__id');

  $$PeopleTableProcessedTableManager? get convertedPersonId {
    final $_column = $_itemColumn<String>('converted_person_id');
    if ($_column == null) return null;
    final manager = $$PeopleTableTableManager(
      $_db,
      $_db.people,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_convertedPersonIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PhoneContactsTableFilterComposer
    extends Composer<_$AppDatabase, $PhoneContactsTable> {
  $$PhoneContactsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get secondaryPhone => $composableBuilder(
    column: $table.secondaryPhone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasWhatsapp => $composableBuilder(
    column: $table.hasWhatsapp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get whatsappInfo => $composableBuilder(
    column: $table.whatsappInfo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasSocial => $composableBuilder(
    column: $table.hasSocial,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get socialPlatform => $composableBuilder(
    column: $table.socialPlatform,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get socialHandle => $composableBuilder(
    column: $table.socialHandle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  $$PeopleTableFilterComposer get convertedPersonId {
    final $$PeopleTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.convertedPersonId,
      referencedTable: $db.people,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeopleTableFilterComposer(
            $db: $db,
            $table: $db.people,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PhoneContactsTableOrderingComposer
    extends Composer<_$AppDatabase, $PhoneContactsTable> {
  $$PhoneContactsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get secondaryPhone => $composableBuilder(
    column: $table.secondaryPhone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasWhatsapp => $composableBuilder(
    column: $table.hasWhatsapp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get whatsappInfo => $composableBuilder(
    column: $table.whatsappInfo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasSocial => $composableBuilder(
    column: $table.hasSocial,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get socialPlatform => $composableBuilder(
    column: $table.socialPlatform,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get socialHandle => $composableBuilder(
    column: $table.socialHandle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  $$PeopleTableOrderingComposer get convertedPersonId {
    final $$PeopleTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.convertedPersonId,
      referencedTable: $db.people,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeopleTableOrderingComposer(
            $db: $db,
            $table: $db.people,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PhoneContactsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PhoneContactsTable> {
  $$PhoneContactsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get secondaryPhone => $composableBuilder(
    column: $table.secondaryPhone,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get hasWhatsapp => $composableBuilder(
    column: $table.hasWhatsapp,
    builder: (column) => column,
  );

  GeneratedColumn<String> get whatsappInfo => $composableBuilder(
    column: $table.whatsappInfo,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get hasSocial =>
      $composableBuilder(column: $table.hasSocial, builder: (column) => column);

  GeneratedColumn<String> get socialPlatform => $composableBuilder(
    column: $table.socialPlatform,
    builder: (column) => column,
  );

  GeneratedColumn<String> get socialHandle => $composableBuilder(
    column: $table.socialHandle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<String> get origin =>
      $composableBuilder(column: $table.origin, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  $$PeopleTableAnnotationComposer get convertedPersonId {
    final $$PeopleTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.convertedPersonId,
      referencedTable: $db.people,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeopleTableAnnotationComposer(
            $db: $db,
            $table: $db.people,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PhoneContactsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PhoneContactsTable,
          PhoneContactEntry,
          $$PhoneContactsTableFilterComposer,
          $$PhoneContactsTableOrderingComposer,
          $$PhoneContactsTableAnnotationComposer,
          $$PhoneContactsTableCreateCompanionBuilder,
          $$PhoneContactsTableUpdateCompanionBuilder,
          (PhoneContactEntry, $$PhoneContactsTableReferences),
          PhoneContactEntry,
          PrefetchHooks Function({bool convertedPersonId})
        > {
  $$PhoneContactsTableTableManager(_$AppDatabase db, $PhoneContactsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PhoneContactsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PhoneContactsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PhoneContactsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> phone = const Value.absent(),
                Value<String?> secondaryPhone = const Value.absent(),
                Value<bool> hasWhatsapp = const Value.absent(),
                Value<String?> whatsappInfo = const Value.absent(),
                Value<bool> hasSocial = const Value.absent(),
                Value<String?> socialPlatform = const Value.absent(),
                Value<String?> socialHandle = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String> tags = const Value.absent(),
                Value<String> origin = const Value.absent(),
                Value<String?> convertedPersonId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PhoneContactsCompanion(
                id: id,
                name: name,
                phone: phone,
                secondaryPhone: secondaryPhone,
                hasWhatsapp: hasWhatsapp,
                whatsappInfo: whatsappInfo,
                hasSocial: hasSocial,
                socialPlatform: socialPlatform,
                socialHandle: socialHandle,
                notes: notes,
                tags: tags,
                origin: origin,
                convertedPersonId: convertedPersonId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String phone,
                Value<String?> secondaryPhone = const Value.absent(),
                Value<bool> hasWhatsapp = const Value.absent(),
                Value<String?> whatsappInfo = const Value.absent(),
                Value<bool> hasSocial = const Value.absent(),
                Value<String?> socialPlatform = const Value.absent(),
                Value<String?> socialHandle = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String> tags = const Value.absent(),
                Value<String> origin = const Value.absent(),
                Value<String?> convertedPersonId = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PhoneContactsCompanion.insert(
                id: id,
                name: name,
                phone: phone,
                secondaryPhone: secondaryPhone,
                hasWhatsapp: hasWhatsapp,
                whatsappInfo: whatsappInfo,
                hasSocial: hasSocial,
                socialPlatform: socialPlatform,
                socialHandle: socialHandle,
                notes: notes,
                tags: tags,
                origin: origin,
                convertedPersonId: convertedPersonId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PhoneContactsTable, PhoneContactEntry>(table),
                  $$PhoneContactsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({convertedPersonId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
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
                      dynamic
                    >
                  >(state) {
                    if (convertedPersonId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.convertedPersonId,
                        referencedTable: $$PhoneContactsTableReferences
                            ._convertedPersonIdTable(db),
                        referencedColumn: $$PhoneContactsTableReferences
                            ._convertedPersonIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PhoneContactsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PhoneContactsTable,
      PhoneContactEntry,
      $$PhoneContactsTableFilterComposer,
      $$PhoneContactsTableOrderingComposer,
      $$PhoneContactsTableAnnotationComposer,
      $$PhoneContactsTableCreateCompanionBuilder,
      $$PhoneContactsTableUpdateCompanionBuilder,
      (PhoneContactEntry, $$PhoneContactsTableReferences),
      PhoneContactEntry,
      PrefetchHooks Function({bool convertedPersonId})
    >;
typedef $$TerritoryLandmarksTableCreateCompanionBuilder =
    TerritoryLandmarksCompanion Function({
      required String id,
      required String name,
      required String category,
      Value<String?> address,
      Value<double?> latitude,
      Value<double?> longitude,
      Value<String?> notes,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> revision,
      Value<int> rowid,
    });
typedef $$TerritoryLandmarksTableUpdateCompanionBuilder =
    TerritoryLandmarksCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> category,
      Value<String?> address,
      Value<double?> latitude,
      Value<double?> longitude,
      Value<String?> notes,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> revision,
      Value<int> rowid,
    });

class $$TerritoryLandmarksTableFilterComposer
    extends Composer<_$AppDatabase, $TerritoryLandmarksTable> {
  $$TerritoryLandmarksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TerritoryLandmarksTableOrderingComposer
    extends Composer<_$AppDatabase, $TerritoryLandmarksTable> {
  $$TerritoryLandmarksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TerritoryLandmarksTableAnnotationComposer
    extends Composer<_$AppDatabase, $TerritoryLandmarksTable> {
  $$TerritoryLandmarksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);
}

class $$TerritoryLandmarksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TerritoryLandmarksTable,
          TerritoryLandmarkEntry,
          $$TerritoryLandmarksTableFilterComposer,
          $$TerritoryLandmarksTableOrderingComposer,
          $$TerritoryLandmarksTableAnnotationComposer,
          $$TerritoryLandmarksTableCreateCompanionBuilder,
          $$TerritoryLandmarksTableUpdateCompanionBuilder,
          (
            TerritoryLandmarkEntry,
            BaseReferences<
              _$AppDatabase,
              $TerritoryLandmarksTable,
              TerritoryLandmarkEntry
            >,
          ),
          TerritoryLandmarkEntry,
          PrefetchHooks Function()
        > {
  $$TerritoryLandmarksTableTableManager(
    _$AppDatabase db,
    $TerritoryLandmarksTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TerritoryLandmarksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TerritoryLandmarksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TerritoryLandmarksTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String?> address = const Value.absent(),
                Value<double?> latitude = const Value.absent(),
                Value<double?> longitude = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TerritoryLandmarksCompanion(
                id: id,
                name: name,
                category: category,
                address: address,
                latitude: latitude,
                longitude: longitude,
                notes: notes,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String category,
                Value<String?> address = const Value.absent(),
                Value<double?> latitude = const Value.absent(),
                Value<double?> longitude = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TerritoryLandmarksCompanion.insert(
                id: id,
                name: name,
                category: category,
                address: address,
                latitude: latitude,
                longitude: longitude,
                notes: notes,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TerritoryLandmarksTable, TerritoryLandmarkEntry>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $TerritoryLandmarksTable,
                    TerritoryLandmarkEntry
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TerritoryLandmarksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TerritoryLandmarksTable,
      TerritoryLandmarkEntry,
      $$TerritoryLandmarksTableFilterComposer,
      $$TerritoryLandmarksTableOrderingComposer,
      $$TerritoryLandmarksTableAnnotationComposer,
      $$TerritoryLandmarksTableCreateCompanionBuilder,
      $$TerritoryLandmarksTableUpdateCompanionBuilder,
      (
        TerritoryLandmarkEntry,
        BaseReferences<
          _$AppDatabase,
          $TerritoryLandmarksTable,
          TerritoryLandmarkEntry
        >,
      ),
      TerritoryLandmarkEntry,
      PrefetchHooks Function()
    >;
typedef $$AppKvStoreTableCreateCompanionBuilder = AppKvStoreCompanion Function({
  required String key,
  required String value,
  Value<DateTime?> updatedAt,
  Value<int> rowid,
});
typedef $$AppKvStoreTableUpdateCompanionBuilder = AppKvStoreCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<DateTime?> updatedAt,
  Value<int> rowid,
});

class $$AppKvStoreTableFilterComposer
    extends Composer<_$AppDatabase, $AppKvStoreTable> {
  $$AppKvStoreTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppKvStoreTableOrderingComposer
    extends Composer<_$AppDatabase, $AppKvStoreTable> {
  $$AppKvStoreTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppKvStoreTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppKvStoreTable> {
  $$AppKvStoreTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AppKvStoreTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppKvStoreTable,
          AppKvEntry,
          $$AppKvStoreTableFilterComposer,
          $$AppKvStoreTableOrderingComposer,
          $$AppKvStoreTableAnnotationComposer,
          $$AppKvStoreTableCreateCompanionBuilder,
          $$AppKvStoreTableUpdateCompanionBuilder,
          (
            AppKvEntry,
            BaseReferences<_$AppDatabase, $AppKvStoreTable, AppKvEntry>,
          ),
          AppKvEntry,
          PrefetchHooks Function()
        > {
  $$AppKvStoreTableTableManager(_$AppDatabase db, $AppKvStoreTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppKvStoreTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppKvStoreTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppKvStoreTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppKvStoreCompanion(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppKvStoreCompanion.insert(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AppKvStoreTable, AppKvEntry>(table),
                  BaseReferences<_$AppDatabase, $AppKvStoreTable, AppKvEntry>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppKvStoreTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppKvStoreTable,
      AppKvEntry,
      $$AppKvStoreTableFilterComposer,
      $$AppKvStoreTableOrderingComposer,
      $$AppKvStoreTableAnnotationComposer,
      $$AppKvStoreTableCreateCompanionBuilder,
      $$AppKvStoreTableUpdateCompanionBuilder,
      (AppKvEntry, BaseReferences<_$AppDatabase, $AppKvStoreTable, AppKvEntry>),
      AppKvEntry,
      PrefetchHooks Function()
    >;
typedef $$FamilyTiesTableCreateCompanionBuilder = FamilyTiesCompanion Function({
  required String id,
  required String personId,
  Value<String?> relatedPersonId,
  required String relatedPersonName,
  required String relationshipType,
  required DateTime createdAt,
  Value<DateTime?> updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> revision,
  Value<int> rowid,
});
typedef $$FamilyTiesTableUpdateCompanionBuilder = FamilyTiesCompanion Function({
  Value<String> id,
  Value<String> personId,
  Value<String?> relatedPersonId,
  Value<String> relatedPersonName,
  Value<String> relationshipType,
  Value<DateTime> createdAt,
  Value<DateTime?> updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> revision,
  Value<int> rowid,
});

class $$FamilyTiesTableFilterComposer
    extends Composer<_$AppDatabase, $FamilyTiesTable> {
  $$FamilyTiesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get personId => $composableBuilder(
    column: $table.personId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relatedPersonId => $composableBuilder(
    column: $table.relatedPersonId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relatedPersonName => $composableBuilder(
    column: $table.relatedPersonName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relationshipType => $composableBuilder(
    column: $table.relationshipType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FamilyTiesTableOrderingComposer
    extends Composer<_$AppDatabase, $FamilyTiesTable> {
  $$FamilyTiesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get personId => $composableBuilder(
    column: $table.personId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relatedPersonId => $composableBuilder(
    column: $table.relatedPersonId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relatedPersonName => $composableBuilder(
    column: $table.relatedPersonName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relationshipType => $composableBuilder(
    column: $table.relationshipType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FamilyTiesTableAnnotationComposer
    extends Composer<_$AppDatabase, $FamilyTiesTable> {
  $$FamilyTiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get personId =>
      $composableBuilder(column: $table.personId, builder: (column) => column);

  GeneratedColumn<String> get relatedPersonId => $composableBuilder(
    column: $table.relatedPersonId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get relatedPersonName => $composableBuilder(
    column: $table.relatedPersonName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get relationshipType => $composableBuilder(
    column: $table.relationshipType,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);
}

class $$FamilyTiesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FamilyTiesTable,
          FamilyTieEntry,
          $$FamilyTiesTableFilterComposer,
          $$FamilyTiesTableOrderingComposer,
          $$FamilyTiesTableAnnotationComposer,
          $$FamilyTiesTableCreateCompanionBuilder,
          $$FamilyTiesTableUpdateCompanionBuilder,
          (
            FamilyTieEntry,
            BaseReferences<_$AppDatabase, $FamilyTiesTable, FamilyTieEntry>,
          ),
          FamilyTieEntry,
          PrefetchHooks Function()
        > {
  $$FamilyTiesTableTableManager(_$AppDatabase db, $FamilyTiesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FamilyTiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FamilyTiesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FamilyTiesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> personId = const Value.absent(),
                Value<String?> relatedPersonId = const Value.absent(),
                Value<String> relatedPersonName = const Value.absent(),
                Value<String> relationshipType = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FamilyTiesCompanion(
                id: id,
                personId: personId,
                relatedPersonId: relatedPersonId,
                relatedPersonName: relatedPersonName,
                relationshipType: relationshipType,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String personId,
                Value<String?> relatedPersonId = const Value.absent(),
                required String relatedPersonName,
                required String relationshipType,
                required DateTime createdAt,
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FamilyTiesCompanion.insert(
                id: id,
                personId: personId,
                relatedPersonId: relatedPersonId,
                relatedPersonName: relatedPersonName,
                relationshipType: relationshipType,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FamilyTiesTable, FamilyTieEntry>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $FamilyTiesTable,
                    FamilyTieEntry
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FamilyTiesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FamilyTiesTable,
      FamilyTieEntry,
      $$FamilyTiesTableFilterComposer,
      $$FamilyTiesTableOrderingComposer,
      $$FamilyTiesTableAnnotationComposer,
      $$FamilyTiesTableCreateCompanionBuilder,
      $$FamilyTiesTableUpdateCompanionBuilder,
      (
        FamilyTieEntry,
        BaseReferences<_$AppDatabase, $FamilyTiesTable, FamilyTieEntry>,
      ),
      FamilyTieEntry,
      PrefetchHooks Function()
    >;
typedef $$MinistryExperiencesTableCreateCompanionBuilder =
    MinistryExperiencesCompanion Function({
      required String id,
      required String title,
      required String content,
      Value<String> mediaUrls,
      Value<String> tags,
      required DateTime dateTimeField,
      Value<String?> locationOrModality,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> revision,
      Value<int> rowid,
    });
typedef $$MinistryExperiencesTableUpdateCompanionBuilder =
    MinistryExperiencesCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String> content,
      Value<String> mediaUrls,
      Value<String> tags,
      Value<DateTime> dateTimeField,
      Value<String?> locationOrModality,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> revision,
      Value<int> rowid,
    });

class $$MinistryExperiencesTableFilterComposer
    extends Composer<_$AppDatabase, $MinistryExperiencesTable> {
  $$MinistryExperiencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaUrls => $composableBuilder(
    column: $table.mediaUrls,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dateTimeField => $composableBuilder(
    column: $table.dateTimeField,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get locationOrModality => $composableBuilder(
    column: $table.locationOrModality,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MinistryExperiencesTableOrderingComposer
    extends Composer<_$AppDatabase, $MinistryExperiencesTable> {
  $$MinistryExperiencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaUrls => $composableBuilder(
    column: $table.mediaUrls,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dateTimeField => $composableBuilder(
    column: $table.dateTimeField,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get locationOrModality => $composableBuilder(
    column: $table.locationOrModality,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MinistryExperiencesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MinistryExperiencesTable> {
  $$MinistryExperiencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get mediaUrls =>
      $composableBuilder(column: $table.mediaUrls, builder: (column) => column);

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<DateTime> get dateTimeField => $composableBuilder(
    column: $table.dateTimeField,
    builder: (column) => column,
  );

  GeneratedColumn<String> get locationOrModality => $composableBuilder(
    column: $table.locationOrModality,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);
}

class $$MinistryExperiencesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MinistryExperiencesTable,
          MinistryExperienceEntry,
          $$MinistryExperiencesTableFilterComposer,
          $$MinistryExperiencesTableOrderingComposer,
          $$MinistryExperiencesTableAnnotationComposer,
          $$MinistryExperiencesTableCreateCompanionBuilder,
          $$MinistryExperiencesTableUpdateCompanionBuilder,
          (
            MinistryExperienceEntry,
            BaseReferences<
              _$AppDatabase,
              $MinistryExperiencesTable,
              MinistryExperienceEntry
            >,
          ),
          MinistryExperienceEntry,
          PrefetchHooks Function()
        > {
  $$MinistryExperiencesTableTableManager(
    _$AppDatabase db,
    $MinistryExperiencesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MinistryExperiencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MinistryExperiencesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$MinistryExperiencesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String> mediaUrls = const Value.absent(),
                Value<String> tags = const Value.absent(),
                Value<DateTime> dateTimeField = const Value.absent(),
                Value<String?> locationOrModality = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MinistryExperiencesCompanion(
                id: id,
                title: title,
                content: content,
                mediaUrls: mediaUrls,
                tags: tags,
                dateTimeField: dateTimeField,
                locationOrModality: locationOrModality,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                required String content,
                Value<String> mediaUrls = const Value.absent(),
                Value<String> tags = const Value.absent(),
                required DateTime dateTimeField,
                Value<String?> locationOrModality = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MinistryExperiencesCompanion.insert(
                id: id,
                title: title,
                content: content,
                mediaUrls: mediaUrls,
                tags: tags,
                dateTimeField: dateTimeField,
                locationOrModality: locationOrModality,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $MinistryExperiencesTable,
                    MinistryExperienceEntry
                  >(table),
                  BaseReferences<
                    _$AppDatabase,
                    $MinistryExperiencesTable,
                    MinistryExperienceEntry
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MinistryExperiencesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MinistryExperiencesTable,
      MinistryExperienceEntry,
      $$MinistryExperiencesTableFilterComposer,
      $$MinistryExperiencesTableOrderingComposer,
      $$MinistryExperiencesTableAnnotationComposer,
      $$MinistryExperiencesTableCreateCompanionBuilder,
      $$MinistryExperiencesTableUpdateCompanionBuilder,
      (
        MinistryExperienceEntry,
        BaseReferences<
          _$AppDatabase,
          $MinistryExperiencesTable,
          MinistryExperienceEntry
        >,
      ),
      MinistryExperienceEntry,
      PrefetchHooks Function()
    >;
typedef $$PersonPhotosTableCreateCompanionBuilder =
    PersonPhotosCompanion Function({
      required String id,
      required String personId,
      required String photoType,
      required String imageData,
      required DateTime createdAt,
      Value<DateTime?> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> revision,
      Value<int> rowid,
    });
typedef $$PersonPhotosTableUpdateCompanionBuilder =
    PersonPhotosCompanion Function({
      Value<String> id,
      Value<String> personId,
      Value<String> photoType,
      Value<String> imageData,
      Value<DateTime> createdAt,
      Value<DateTime?> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> revision,
      Value<int> rowid,
    });

class $$PersonPhotosTableFilterComposer
    extends Composer<_$AppDatabase, $PersonPhotosTable> {
  $$PersonPhotosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get personId => $composableBuilder(
    column: $table.personId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get photoType => $composableBuilder(
    column: $table.photoType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageData => $composableBuilder(
    column: $table.imageData,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PersonPhotosTableOrderingComposer
    extends Composer<_$AppDatabase, $PersonPhotosTable> {
  $$PersonPhotosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get personId => $composableBuilder(
    column: $table.personId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get photoType => $composableBuilder(
    column: $table.photoType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageData => $composableBuilder(
    column: $table.imageData,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PersonPhotosTableAnnotationComposer
    extends Composer<_$AppDatabase, $PersonPhotosTable> {
  $$PersonPhotosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get personId =>
      $composableBuilder(column: $table.personId, builder: (column) => column);

  GeneratedColumn<String> get photoType =>
      $composableBuilder(column: $table.photoType, builder: (column) => column);

  GeneratedColumn<String> get imageData =>
      $composableBuilder(column: $table.imageData, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);
}

class $$PersonPhotosTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PersonPhotosTable,
          PersonPhotoEntry,
          $$PersonPhotosTableFilterComposer,
          $$PersonPhotosTableOrderingComposer,
          $$PersonPhotosTableAnnotationComposer,
          $$PersonPhotosTableCreateCompanionBuilder,
          $$PersonPhotosTableUpdateCompanionBuilder,
          (
            PersonPhotoEntry,
            BaseReferences<_$AppDatabase, $PersonPhotosTable, PersonPhotoEntry>,
          ),
          PersonPhotoEntry,
          PrefetchHooks Function()
        > {
  $$PersonPhotosTableTableManager(_$AppDatabase db, $PersonPhotosTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PersonPhotosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PersonPhotosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PersonPhotosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> personId = const Value.absent(),
                Value<String> photoType = const Value.absent(),
                Value<String> imageData = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PersonPhotosCompanion(
                id: id,
                personId: personId,
                photoType: photoType,
                imageData: imageData,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String personId,
                required String photoType,
                required String imageData,
                required DateTime createdAt,
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PersonPhotosCompanion.insert(
                id: id,
                personId: personId,
                photoType: photoType,
                imageData: imageData,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PersonPhotosTable, PersonPhotoEntry>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $PersonPhotosTable,
                    PersonPhotoEntry
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PersonPhotosTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PersonPhotosTable,
      PersonPhotoEntry,
      $$PersonPhotosTableFilterComposer,
      $$PersonPhotosTableOrderingComposer,
      $$PersonPhotosTableAnnotationComposer,
      $$PersonPhotosTableCreateCompanionBuilder,
      $$PersonPhotosTableUpdateCompanionBuilder,
      (
        PersonPhotoEntry,
        BaseReferences<_$AppDatabase, $PersonPhotosTable, PersonPhotoEntry>,
      ),
      PersonPhotoEntry,
      PrefetchHooks Function()
    >;
typedef $$PersonPublicationsTableCreateCompanionBuilder =
    PersonPublicationsCompanion Function({
      required String id,
      required String personId,
      required String publicationTitle,
      required String itemType,
      required String status,
      required String date,
      Value<String?> notes,
      required DateTime createdAt,
      Value<DateTime?> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> revision,
      Value<int> rowid,
    });
typedef $$PersonPublicationsTableUpdateCompanionBuilder =
    PersonPublicationsCompanion Function({
      Value<String> id,
      Value<String> personId,
      Value<String> publicationTitle,
      Value<String> itemType,
      Value<String> status,
      Value<String> date,
      Value<String?> notes,
      Value<DateTime> createdAt,
      Value<DateTime?> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> revision,
      Value<int> rowid,
    });

class $$PersonPublicationsTableFilterComposer
    extends Composer<_$AppDatabase, $PersonPublicationsTable> {
  $$PersonPublicationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get personId => $composableBuilder(
    column: $table.personId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get publicationTitle => $composableBuilder(
    column: $table.publicationTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemType => $composableBuilder(
    column: $table.itemType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PersonPublicationsTableOrderingComposer
    extends Composer<_$AppDatabase, $PersonPublicationsTable> {
  $$PersonPublicationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get personId => $composableBuilder(
    column: $table.personId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get publicationTitle => $composableBuilder(
    column: $table.publicationTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemType => $composableBuilder(
    column: $table.itemType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PersonPublicationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PersonPublicationsTable> {
  $$PersonPublicationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get personId =>
      $composableBuilder(column: $table.personId, builder: (column) => column);

  GeneratedColumn<String> get publicationTitle => $composableBuilder(
    column: $table.publicationTitle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get itemType =>
      $composableBuilder(column: $table.itemType, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);
}

class $$PersonPublicationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PersonPublicationsTable,
          PersonPublicationEntry,
          $$PersonPublicationsTableFilterComposer,
          $$PersonPublicationsTableOrderingComposer,
          $$PersonPublicationsTableAnnotationComposer,
          $$PersonPublicationsTableCreateCompanionBuilder,
          $$PersonPublicationsTableUpdateCompanionBuilder,
          (
            PersonPublicationEntry,
            BaseReferences<
              _$AppDatabase,
              $PersonPublicationsTable,
              PersonPublicationEntry
            >,
          ),
          PersonPublicationEntry,
          PrefetchHooks Function()
        > {
  $$PersonPublicationsTableTableManager(
    _$AppDatabase db,
    $PersonPublicationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PersonPublicationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PersonPublicationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PersonPublicationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> personId = const Value.absent(),
                Value<String> publicationTitle = const Value.absent(),
                Value<String> itemType = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> date = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PersonPublicationsCompanion(
                id: id,
                personId: personId,
                publicationTitle: publicationTitle,
                itemType: itemType,
                status: status,
                date: date,
                notes: notes,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String personId,
                required String publicationTitle,
                required String itemType,
                required String status,
                required String date,
                Value<String?> notes = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PersonPublicationsCompanion.insert(
                id: id,
                personId: personId,
                publicationTitle: publicationTitle,
                itemType: itemType,
                status: status,
                date: date,
                notes: notes,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PersonPublicationsTable, PersonPublicationEntry>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $PersonPublicationsTable,
                    PersonPublicationEntry
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PersonPublicationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PersonPublicationsTable,
      PersonPublicationEntry,
      $$PersonPublicationsTableFilterComposer,
      $$PersonPublicationsTableOrderingComposer,
      $$PersonPublicationsTableAnnotationComposer,
      $$PersonPublicationsTableCreateCompanionBuilder,
      $$PersonPublicationsTableUpdateCompanionBuilder,
      (
        PersonPublicationEntry,
        BaseReferences<
          _$AppDatabase,
          $PersonPublicationsTable,
          PersonPublicationEntry
        >,
      ),
      PersonPublicationEntry,
      PrefetchHooks Function()
    >;
typedef $$ResearchArticlesTableCreateCompanionBuilder =
    ResearchArticlesCompanion Function({
      required String id,
      required String title,
      required String summary,
      required String content,
      Value<String> tags,
      Value<String> attachments,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> revision,
      Value<int> rowid,
    });
typedef $$ResearchArticlesTableUpdateCompanionBuilder =
    ResearchArticlesCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String> summary,
      Value<String> content,
      Value<String> tags,
      Value<String> attachments,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> revision,
      Value<int> rowid,
    });

class $$ResearchArticlesTableFilterComposer
    extends Composer<_$AppDatabase, $ResearchArticlesTable> {
  $$ResearchArticlesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get attachments => $composableBuilder(
    column: $table.attachments,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ResearchArticlesTableOrderingComposer
    extends Composer<_$AppDatabase, $ResearchArticlesTable> {
  $$ResearchArticlesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get attachments => $composableBuilder(
    column: $table.attachments,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ResearchArticlesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ResearchArticlesTable> {
  $$ResearchArticlesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<String> get attachments => $composableBuilder(
    column: $table.attachments,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);
}

class $$ResearchArticlesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ResearchArticlesTable,
          ResearchArticleEntry,
          $$ResearchArticlesTableFilterComposer,
          $$ResearchArticlesTableOrderingComposer,
          $$ResearchArticlesTableAnnotationComposer,
          $$ResearchArticlesTableCreateCompanionBuilder,
          $$ResearchArticlesTableUpdateCompanionBuilder,
          (
            ResearchArticleEntry,
            BaseReferences<
              _$AppDatabase,
              $ResearchArticlesTable,
              ResearchArticleEntry
            >,
          ),
          ResearchArticleEntry,
          PrefetchHooks Function()
        > {
  $$ResearchArticlesTableTableManager(
    _$AppDatabase db,
    $ResearchArticlesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ResearchArticlesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ResearchArticlesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ResearchArticlesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> summary = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String> tags = const Value.absent(),
                Value<String> attachments = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ResearchArticlesCompanion(
                id: id,
                title: title,
                summary: summary,
                content: content,
                tags: tags,
                attachments: attachments,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                required String summary,
                required String content,
                Value<String> tags = const Value.absent(),
                Value<String> attachments = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ResearchArticlesCompanion.insert(
                id: id,
                title: title,
                summary: summary,
                content: content,
                tags: tags,
                attachments: attachments,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ResearchArticlesTable, ResearchArticleEntry>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $ResearchArticlesTable,
                    ResearchArticleEntry
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ResearchArticlesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ResearchArticlesTable,
      ResearchArticleEntry,
      $$ResearchArticlesTableFilterComposer,
      $$ResearchArticlesTableOrderingComposer,
      $$ResearchArticlesTableAnnotationComposer,
      $$ResearchArticlesTableCreateCompanionBuilder,
      $$ResearchArticlesTableUpdateCompanionBuilder,
      (
        ResearchArticleEntry,
        BaseReferences<
          _$AppDatabase,
          $ResearchArticlesTable,
          ResearchArticleEntry
        >,
      ),
      ResearchArticleEntry,
      PrefetchHooks Function()
    >;
typedef $$ResearchTagsTableCreateCompanionBuilder =
    ResearchTagsCompanion Function({
      required String id,
      required String name,
      required DateTime createdAt,
      Value<DateTime?> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> revision,
      Value<int> rowid,
    });
typedef $$ResearchTagsTableUpdateCompanionBuilder =
    ResearchTagsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<DateTime> createdAt,
      Value<DateTime?> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> revision,
      Value<int> rowid,
    });

class $$ResearchTagsTableFilterComposer
    extends Composer<_$AppDatabase, $ResearchTagsTable> {
  $$ResearchTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ResearchTagsTableOrderingComposer
    extends Composer<_$AppDatabase, $ResearchTagsTable> {
  $$ResearchTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ResearchTagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ResearchTagsTable> {
  $$ResearchTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);
}

class $$ResearchTagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ResearchTagsTable,
          ResearchTagEntry,
          $$ResearchTagsTableFilterComposer,
          $$ResearchTagsTableOrderingComposer,
          $$ResearchTagsTableAnnotationComposer,
          $$ResearchTagsTableCreateCompanionBuilder,
          $$ResearchTagsTableUpdateCompanionBuilder,
          (
            ResearchTagEntry,
            BaseReferences<_$AppDatabase, $ResearchTagsTable, ResearchTagEntry>,
          ),
          ResearchTagEntry,
          PrefetchHooks Function()
        > {
  $$ResearchTagsTableTableManager(_$AppDatabase db, $ResearchTagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ResearchTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ResearchTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ResearchTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ResearchTagsCompanion(
                id: id,
                name: name,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required DateTime createdAt,
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ResearchTagsCompanion.insert(
                id: id,
                name: name,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ResearchTagsTable, ResearchTagEntry>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ResearchTagsTable,
                    ResearchTagEntry
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ResearchTagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ResearchTagsTable,
      ResearchTagEntry,
      $$ResearchTagsTableFilterComposer,
      $$ResearchTagsTableOrderingComposer,
      $$ResearchTagsTableAnnotationComposer,
      $$ResearchTagsTableCreateCompanionBuilder,
      $$ResearchTagsTableUpdateCompanionBuilder,
      (
        ResearchTagEntry,
        BaseReferences<_$AppDatabase, $ResearchTagsTable, ResearchTagEntry>,
      ),
      ResearchTagEntry,
      PrefetchHooks Function()
    >;
typedef $$TerritorySectorsTableCreateCompanionBuilder =
    TerritorySectorsCompanion Function({
      required String id,
      required String name,
      Value<String?> description,
      required DateTime createdAt,
      Value<DateTime?> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> revision,
      Value<int> rowid,
    });
typedef $$TerritorySectorsTableUpdateCompanionBuilder =
    TerritorySectorsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> description,
      Value<DateTime> createdAt,
      Value<DateTime?> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> revision,
      Value<int> rowid,
    });

class $$TerritorySectorsTableFilterComposer
    extends Composer<_$AppDatabase, $TerritorySectorsTable> {
  $$TerritorySectorsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TerritorySectorsTableOrderingComposer
    extends Composer<_$AppDatabase, $TerritorySectorsTable> {
  $$TerritorySectorsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TerritorySectorsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TerritorySectorsTable> {
  $$TerritorySectorsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);
}

class $$TerritorySectorsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TerritorySectorsTable,
          TerritorySectorEntry,
          $$TerritorySectorsTableFilterComposer,
          $$TerritorySectorsTableOrderingComposer,
          $$TerritorySectorsTableAnnotationComposer,
          $$TerritorySectorsTableCreateCompanionBuilder,
          $$TerritorySectorsTableUpdateCompanionBuilder,
          (
            TerritorySectorEntry,
            BaseReferences<
              _$AppDatabase,
              $TerritorySectorsTable,
              TerritorySectorEntry
            >,
          ),
          TerritorySectorEntry,
          PrefetchHooks Function()
        > {
  $$TerritorySectorsTableTableManager(
    _$AppDatabase db,
    $TerritorySectorsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TerritorySectorsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TerritorySectorsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TerritorySectorsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TerritorySectorsCompanion(
                id: id,
                name: name,
                description: description,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> description = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TerritorySectorsCompanion.insert(
                id: id,
                name: name,
                description: description,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TerritorySectorsTable, TerritorySectorEntry>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $TerritorySectorsTable,
                    TerritorySectorEntry
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TerritorySectorsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TerritorySectorsTable,
      TerritorySectorEntry,
      $$TerritorySectorsTableFilterComposer,
      $$TerritorySectorsTableOrderingComposer,
      $$TerritorySectorsTableAnnotationComposer,
      $$TerritorySectorsTableCreateCompanionBuilder,
      $$TerritorySectorsTableUpdateCompanionBuilder,
      (
        TerritorySectorEntry,
        BaseReferences<
          _$AppDatabase,
          $TerritorySectorsTable,
          TerritorySectorEntry
        >,
      ),
      TerritorySectorEntry,
      PrefetchHooks Function()
    >;
typedef $$StudentManualOrderTableCreateCompanionBuilder =
    StudentManualOrderCompanion Function({
      required String studyId,
      required int manualIndex,
      Value<DateTime?> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> revision,
      Value<int> rowid,
    });
typedef $$StudentManualOrderTableUpdateCompanionBuilder =
    StudentManualOrderCompanion Function({
      Value<String> studyId,
      Value<int> manualIndex,
      Value<DateTime?> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> revision,
      Value<int> rowid,
    });

class $$StudentManualOrderTableFilterComposer
    extends Composer<_$AppDatabase, $StudentManualOrderTable> {
  $$StudentManualOrderTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get studyId => $composableBuilder(
    column: $table.studyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get manualIndex => $composableBuilder(
    column: $table.manualIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StudentManualOrderTableOrderingComposer
    extends Composer<_$AppDatabase, $StudentManualOrderTable> {
  $$StudentManualOrderTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get studyId => $composableBuilder(
    column: $table.studyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get manualIndex => $composableBuilder(
    column: $table.manualIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StudentManualOrderTableAnnotationComposer
    extends Composer<_$AppDatabase, $StudentManualOrderTable> {
  $$StudentManualOrderTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get studyId =>
      $composableBuilder(column: $table.studyId, builder: (column) => column);

  GeneratedColumn<int> get manualIndex => $composableBuilder(
    column: $table.manualIndex,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);
}

class $$StudentManualOrderTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StudentManualOrderTable,
          StudentManualOrderEntry,
          $$StudentManualOrderTableFilterComposer,
          $$StudentManualOrderTableOrderingComposer,
          $$StudentManualOrderTableAnnotationComposer,
          $$StudentManualOrderTableCreateCompanionBuilder,
          $$StudentManualOrderTableUpdateCompanionBuilder,
          (
            StudentManualOrderEntry,
            BaseReferences<
              _$AppDatabase,
              $StudentManualOrderTable,
              StudentManualOrderEntry
            >,
          ),
          StudentManualOrderEntry,
          PrefetchHooks Function()
        > {
  $$StudentManualOrderTableTableManager(
    _$AppDatabase db,
    $StudentManualOrderTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StudentManualOrderTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StudentManualOrderTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StudentManualOrderTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> studyId = const Value.absent(),
                Value<int> manualIndex = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StudentManualOrderCompanion(
                studyId: studyId,
                manualIndex: manualIndex,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String studyId,
                required int manualIndex,
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StudentManualOrderCompanion.insert(
                studyId: studyId,
                manualIndex: manualIndex,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $StudentManualOrderTable,
                    StudentManualOrderEntry
                  >(table),
                  BaseReferences<
                    _$AppDatabase,
                    $StudentManualOrderTable,
                    StudentManualOrderEntry
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StudentManualOrderTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StudentManualOrderTable,
      StudentManualOrderEntry,
      $$StudentManualOrderTableFilterComposer,
      $$StudentManualOrderTableOrderingComposer,
      $$StudentManualOrderTableAnnotationComposer,
      $$StudentManualOrderTableCreateCompanionBuilder,
      $$StudentManualOrderTableUpdateCompanionBuilder,
      (
        StudentManualOrderEntry,
        BaseReferences<
          _$AppDatabase,
          $StudentManualOrderTable,
          StudentManualOrderEntry
        >,
      ),
      StudentManualOrderEntry,
      PrefetchHooks Function()
    >;
typedef $$ExternalCalendarEventsTableCreateCompanionBuilder =
    ExternalCalendarEventsCompanion Function({
      required String id,
      required String provider,
      Value<String?> externalAccount,
      required String calendarId,
      required String externalEventId,
      Value<String?> iCalUid,
      required String title,
      Value<String?> location,
      Value<String?> description,
      required DateTime startTime,
      required DateTime endTime,
      Value<String?> timeZone,
      Value<bool> isAllDay,
      Value<String?> externalStatus,
      Value<DateTime?> lastModifiedExternal,
      Value<DateTime?> lastSyncedAt,
      Value<bool> isDeletedExternal,
      Value<String?> metadata,
      Value<String?> etag,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> revision,
      Value<int> rowid,
    });
typedef $$ExternalCalendarEventsTableUpdateCompanionBuilder =
    ExternalCalendarEventsCompanion Function({
      Value<String> id,
      Value<String> provider,
      Value<String?> externalAccount,
      Value<String> calendarId,
      Value<String> externalEventId,
      Value<String?> iCalUid,
      Value<String> title,
      Value<String?> location,
      Value<String?> description,
      Value<DateTime> startTime,
      Value<DateTime> endTime,
      Value<String?> timeZone,
      Value<bool> isAllDay,
      Value<String?> externalStatus,
      Value<DateTime?> lastModifiedExternal,
      Value<DateTime?> lastSyncedAt,
      Value<bool> isDeletedExternal,
      Value<String?> metadata,
      Value<String?> etag,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> revision,
      Value<int> rowid,
    });

class $$ExternalCalendarEventsTableFilterComposer
    extends Composer<_$AppDatabase, $ExternalCalendarEventsTable> {
  $$ExternalCalendarEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get externalAccount => $composableBuilder(
    column: $table.externalAccount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get calendarId => $composableBuilder(
    column: $table.calendarId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get externalEventId => $composableBuilder(
    column: $table.externalEventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get iCalUid => $composableBuilder(
    column: $table.iCalUid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startTime => $composableBuilder(
    column: $table.startTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endTime => $composableBuilder(
    column: $table.endTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timeZone => $composableBuilder(
    column: $table.timeZone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isAllDay => $composableBuilder(
    column: $table.isAllDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get externalStatus => $composableBuilder(
    column: $table.externalStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastModifiedExternal => $composableBuilder(
    column: $table.lastModifiedExternal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeletedExternal => $composableBuilder(
    column: $table.isDeletedExternal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metadata => $composableBuilder(
    column: $table.metadata,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ExternalCalendarEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $ExternalCalendarEventsTable> {
  $$ExternalCalendarEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get externalAccount => $composableBuilder(
    column: $table.externalAccount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get calendarId => $composableBuilder(
    column: $table.calendarId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get externalEventId => $composableBuilder(
    column: $table.externalEventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get iCalUid => $composableBuilder(
    column: $table.iCalUid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startTime => $composableBuilder(
    column: $table.startTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endTime => $composableBuilder(
    column: $table.endTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timeZone => $composableBuilder(
    column: $table.timeZone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isAllDay => $composableBuilder(
    column: $table.isAllDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get externalStatus => $composableBuilder(
    column: $table.externalStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastModifiedExternal => $composableBuilder(
    column: $table.lastModifiedExternal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeletedExternal => $composableBuilder(
    column: $table.isDeletedExternal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metadata => $composableBuilder(
    column: $table.metadata,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ExternalCalendarEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExternalCalendarEventsTable> {
  $$ExternalCalendarEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<String> get externalAccount => $composableBuilder(
    column: $table.externalAccount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get calendarId => $composableBuilder(
    column: $table.calendarId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get externalEventId => $composableBuilder(
    column: $table.externalEventId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get iCalUid =>
      $composableBuilder(column: $table.iCalUid, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get startTime =>
      $composableBuilder(column: $table.startTime, builder: (column) => column);

  GeneratedColumn<DateTime> get endTime =>
      $composableBuilder(column: $table.endTime, builder: (column) => column);

  GeneratedColumn<String> get timeZone =>
      $composableBuilder(column: $table.timeZone, builder: (column) => column);

  GeneratedColumn<bool> get isAllDay =>
      $composableBuilder(column: $table.isAllDay, builder: (column) => column);

  GeneratedColumn<String> get externalStatus => $composableBuilder(
    column: $table.externalStatus,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastModifiedExternal => $composableBuilder(
    column: $table.lastModifiedExternal,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDeletedExternal => $composableBuilder(
    column: $table.isDeletedExternal,
    builder: (column) => column,
  );

  GeneratedColumn<String> get metadata =>
      $composableBuilder(column: $table.metadata, builder: (column) => column);

  GeneratedColumn<String> get etag =>
      $composableBuilder(column: $table.etag, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);
}

class $$ExternalCalendarEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ExternalCalendarEventsTable,
          ExternalCalendarEventEntry,
          $$ExternalCalendarEventsTableFilterComposer,
          $$ExternalCalendarEventsTableOrderingComposer,
          $$ExternalCalendarEventsTableAnnotationComposer,
          $$ExternalCalendarEventsTableCreateCompanionBuilder,
          $$ExternalCalendarEventsTableUpdateCompanionBuilder,
          (
            ExternalCalendarEventEntry,
            BaseReferences<
              _$AppDatabase,
              $ExternalCalendarEventsTable,
              ExternalCalendarEventEntry
            >,
          ),
          ExternalCalendarEventEntry,
          PrefetchHooks Function()
        > {
  $$ExternalCalendarEventsTableTableManager(
    _$AppDatabase db,
    $ExternalCalendarEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExternalCalendarEventsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$ExternalCalendarEventsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ExternalCalendarEventsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> provider = const Value.absent(),
                Value<String?> externalAccount = const Value.absent(),
                Value<String> calendarId = const Value.absent(),
                Value<String> externalEventId = const Value.absent(),
                Value<String?> iCalUid = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> location = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<DateTime> startTime = const Value.absent(),
                Value<DateTime> endTime = const Value.absent(),
                Value<String?> timeZone = const Value.absent(),
                Value<bool> isAllDay = const Value.absent(),
                Value<String?> externalStatus = const Value.absent(),
                Value<DateTime?> lastModifiedExternal = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<bool> isDeletedExternal = const Value.absent(),
                Value<String?> metadata = const Value.absent(),
                Value<String?> etag = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExternalCalendarEventsCompanion(
                id: id,
                provider: provider,
                externalAccount: externalAccount,
                calendarId: calendarId,
                externalEventId: externalEventId,
                iCalUid: iCalUid,
                title: title,
                location: location,
                description: description,
                startTime: startTime,
                endTime: endTime,
                timeZone: timeZone,
                isAllDay: isAllDay,
                externalStatus: externalStatus,
                lastModifiedExternal: lastModifiedExternal,
                lastSyncedAt: lastSyncedAt,
                isDeletedExternal: isDeletedExternal,
                metadata: metadata,
                etag: etag,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String provider,
                Value<String?> externalAccount = const Value.absent(),
                required String calendarId,
                required String externalEventId,
                Value<String?> iCalUid = const Value.absent(),
                required String title,
                Value<String?> location = const Value.absent(),
                Value<String?> description = const Value.absent(),
                required DateTime startTime,
                required DateTime endTime,
                Value<String?> timeZone = const Value.absent(),
                Value<bool> isAllDay = const Value.absent(),
                Value<String?> externalStatus = const Value.absent(),
                Value<DateTime?> lastModifiedExternal = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<bool> isDeletedExternal = const Value.absent(),
                Value<String?> metadata = const Value.absent(),
                Value<String?> etag = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExternalCalendarEventsCompanion.insert(
                id: id,
                provider: provider,
                externalAccount: externalAccount,
                calendarId: calendarId,
                externalEventId: externalEventId,
                iCalUid: iCalUid,
                title: title,
                location: location,
                description: description,
                startTime: startTime,
                endTime: endTime,
                timeZone: timeZone,
                isAllDay: isAllDay,
                externalStatus: externalStatus,
                lastModifiedExternal: lastModifiedExternal,
                lastSyncedAt: lastSyncedAt,
                isDeletedExternal: isDeletedExternal,
                metadata: metadata,
                etag: etag,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $ExternalCalendarEventsTable,
                    ExternalCalendarEventEntry
                  >(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ExternalCalendarEventsTable,
                    ExternalCalendarEventEntry
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ExternalCalendarEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ExternalCalendarEventsTable,
      ExternalCalendarEventEntry,
      $$ExternalCalendarEventsTableFilterComposer,
      $$ExternalCalendarEventsTableOrderingComposer,
      $$ExternalCalendarEventsTableAnnotationComposer,
      $$ExternalCalendarEventsTableCreateCompanionBuilder,
      $$ExternalCalendarEventsTableUpdateCompanionBuilder,
      (
        ExternalCalendarEventEntry,
        BaseReferences<
          _$AppDatabase,
          $ExternalCalendarEventsTable,
          ExternalCalendarEventEntry
        >,
      ),
      ExternalCalendarEventEntry,
      PrefetchHooks Function()
    >;
typedef $$CalendarEventLinksTableCreateCompanionBuilder =
    CalendarEventLinksCompanion Function({
      required String id,
      required String appointmentId,
      required String externalEventId,
      required String provider,
      Value<String> syncStatus,
      Value<String?> lastError,
      Value<int> localRevisionAtSync,
      Value<String?> externalETagAtSync,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> revision,
      Value<int> rowid,
    });
typedef $$CalendarEventLinksTableUpdateCompanionBuilder =
    CalendarEventLinksCompanion Function({
      Value<String> id,
      Value<String> appointmentId,
      Value<String> externalEventId,
      Value<String> provider,
      Value<String> syncStatus,
      Value<String?> lastError,
      Value<int> localRevisionAtSync,
      Value<String?> externalETagAtSync,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> revision,
      Value<int> rowid,
    });

class $$CalendarEventLinksTableFilterComposer
    extends Composer<_$AppDatabase, $CalendarEventLinksTable> {
  $$CalendarEventLinksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get appointmentId => $composableBuilder(
    column: $table.appointmentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get externalEventId => $composableBuilder(
    column: $table.externalEventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get localRevisionAtSync => $composableBuilder(
    column: $table.localRevisionAtSync,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get externalETagAtSync => $composableBuilder(
    column: $table.externalETagAtSync,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CalendarEventLinksTableOrderingComposer
    extends Composer<_$AppDatabase, $CalendarEventLinksTable> {
  $$CalendarEventLinksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get appointmentId => $composableBuilder(
    column: $table.appointmentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get externalEventId => $composableBuilder(
    column: $table.externalEventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get localRevisionAtSync => $composableBuilder(
    column: $table.localRevisionAtSync,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get externalETagAtSync => $composableBuilder(
    column: $table.externalETagAtSync,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CalendarEventLinksTableAnnotationComposer
    extends Composer<_$AppDatabase, $CalendarEventLinksTable> {
  $$CalendarEventLinksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get appointmentId => $composableBuilder(
    column: $table.appointmentId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get externalEventId => $composableBuilder(
    column: $table.externalEventId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<int> get localRevisionAtSync => $composableBuilder(
    column: $table.localRevisionAtSync,
    builder: (column) => column,
  );

  GeneratedColumn<String> get externalETagAtSync => $composableBuilder(
    column: $table.externalETagAtSync,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);
}

class $$CalendarEventLinksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CalendarEventLinksTable,
          CalendarEventLinkEntry,
          $$CalendarEventLinksTableFilterComposer,
          $$CalendarEventLinksTableOrderingComposer,
          $$CalendarEventLinksTableAnnotationComposer,
          $$CalendarEventLinksTableCreateCompanionBuilder,
          $$CalendarEventLinksTableUpdateCompanionBuilder,
          (
            CalendarEventLinkEntry,
            BaseReferences<
              _$AppDatabase,
              $CalendarEventLinksTable,
              CalendarEventLinkEntry
            >,
          ),
          CalendarEventLinkEntry,
          PrefetchHooks Function()
        > {
  $$CalendarEventLinksTableTableManager(
    _$AppDatabase db,
    $CalendarEventLinksTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CalendarEventLinksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CalendarEventLinksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CalendarEventLinksTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> appointmentId = const Value.absent(),
                Value<String> externalEventId = const Value.absent(),
                Value<String> provider = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> localRevisionAtSync = const Value.absent(),
                Value<String?> externalETagAtSync = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CalendarEventLinksCompanion(
                id: id,
                appointmentId: appointmentId,
                externalEventId: externalEventId,
                provider: provider,
                syncStatus: syncStatus,
                lastError: lastError,
                localRevisionAtSync: localRevisionAtSync,
                externalETagAtSync: externalETagAtSync,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String appointmentId,
                required String externalEventId,
                required String provider,
                Value<String> syncStatus = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> localRevisionAtSync = const Value.absent(),
                Value<String?> externalETagAtSync = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CalendarEventLinksCompanion.insert(
                id: id,
                appointmentId: appointmentId,
                externalEventId: externalEventId,
                provider: provider,
                syncStatus: syncStatus,
                lastError: lastError,
                localRevisionAtSync: localRevisionAtSync,
                externalETagAtSync: externalETagAtSync,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CalendarEventLinksTable, CalendarEventLinkEntry>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $CalendarEventLinksTable,
                    CalendarEventLinkEntry
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CalendarEventLinksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CalendarEventLinksTable,
      CalendarEventLinkEntry,
      $$CalendarEventLinksTableFilterComposer,
      $$CalendarEventLinksTableOrderingComposer,
      $$CalendarEventLinksTableAnnotationComposer,
      $$CalendarEventLinksTableCreateCompanionBuilder,
      $$CalendarEventLinksTableUpdateCompanionBuilder,
      (
        CalendarEventLinkEntry,
        BaseReferences<
          _$AppDatabase,
          $CalendarEventLinksTable,
          CalendarEventLinkEntry
        >,
      ),
      CalendarEventLinkEntry,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$PeopleTableTableManager get people =>
      $$PeopleTableTableManager(_db, _db.people);
  $$VisitsTableTableManager get visits =>
      $$VisitsTableTableManager(_db, _db.visits);
  $$BibleStudiesTableTableManager get bibleStudies =>
      $$BibleStudiesTableTableManager(_db, _db.bibleStudies);
  $$StudyParticipantsTableTableManager get studyParticipants =>
      $$StudyParticipantsTableTableManager(_db, _db.studyParticipants);
  $$StudySessionsTableTableManager get studySessions =>
      $$StudySessionsTableTableManager(_db, _db.studySessions);
  $$AppointmentsTableTableManager get appointments =>
      $$AppointmentsTableTableManager(_db, _db.appointments);
  $$ActivityRecordsTableTableManager get activityRecords =>
      $$ActivityRecordsTableTableManager(_db, _db.activityRecords);
  $$SyncQueueTableTableManager get syncQueue =>
      $$SyncQueueTableTableManager(_db, _db.syncQueue);
  $$VoiceNotesTableTableManager get voiceNotes =>
      $$VoiceNotesTableTableManager(_db, _db.voiceNotes);
  $$PhoneContactsTableTableManager get phoneContacts =>
      $$PhoneContactsTableTableManager(_db, _db.phoneContacts);
  $$TerritoryLandmarksTableTableManager get territoryLandmarks =>
      $$TerritoryLandmarksTableTableManager(_db, _db.territoryLandmarks);
  $$AppKvStoreTableTableManager get appKvStore =>
      $$AppKvStoreTableTableManager(_db, _db.appKvStore);
  $$FamilyTiesTableTableManager get familyTies =>
      $$FamilyTiesTableTableManager(_db, _db.familyTies);
  $$MinistryExperiencesTableTableManager get ministryExperiences =>
      $$MinistryExperiencesTableTableManager(_db, _db.ministryExperiences);
  $$PersonPhotosTableTableManager get personPhotos =>
      $$PersonPhotosTableTableManager(_db, _db.personPhotos);
  $$PersonPublicationsTableTableManager get personPublications =>
      $$PersonPublicationsTableTableManager(_db, _db.personPublications);
  $$ResearchArticlesTableTableManager get researchArticles =>
      $$ResearchArticlesTableTableManager(_db, _db.researchArticles);
  $$ResearchTagsTableTableManager get researchTags =>
      $$ResearchTagsTableTableManager(_db, _db.researchTags);
  $$TerritorySectorsTableTableManager get territorySectors =>
      $$TerritorySectorsTableTableManager(_db, _db.territorySectors);
  $$StudentManualOrderTableTableManager get studentManualOrder =>
      $$StudentManualOrderTableTableManager(_db, _db.studentManualOrder);
  $$ExternalCalendarEventsTableTableManager get externalCalendarEvents =>
      $$ExternalCalendarEventsTableTableManager(
        _db,
        _db.externalCalendarEvents,
      );
  $$CalendarEventLinksTableTableManager get calendarEventLinks =>
      $$CalendarEventLinksTableTableManager(_db, _db.calendarEventLinks);
}
