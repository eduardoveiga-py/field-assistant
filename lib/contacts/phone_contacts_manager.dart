import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../database/repository.dart';
import '../ui/providers.dart';

class PhoneContactItem {
  final String id;
  final String name;
  final String phone;
  final String? secondaryPhone;
  final bool hasWhatsApp;
  final String? whatsAppInfo;
  final bool hasSocial;
  final String? socialPlatform;
  final String? socialHandle;
  final String? notes;
  final List<String> tags;
  final String origin; // 'Rua', 'TPL / Carrinho', 'Informal', 'Telefone', 'Outro'
  final String? convertedPersonId;
  final DateTime createdAt;
  final DateTime updatedAt;

  PhoneContactItem({
    required this.id,
    required this.name,
    required this.phone,
    this.secondaryPhone,
    required this.hasWhatsApp,
    this.whatsAppInfo,
    required this.hasSocial,
    this.socialPlatform,
    this.socialHandle,
    this.notes,
    required this.tags,
    required this.origin,
    this.convertedPersonId,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'secondary_phone': secondaryPhone,
        'has_whatsapp': hasWhatsApp ? 1 : 0,
        'whatsapp_info': whatsAppInfo,
        'has_social': hasSocial ? 1 : 0,
        'social_platform': socialPlatform,
        'social_handle': socialHandle,
        'notes': notes,
        'tags': jsonEncode(tags),
        'origin': origin,
        'converted_person_id': convertedPersonId,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory PhoneContactItem.fromMap(Map<String, dynamic> map) {
    List<String> parsedTags = [];
    try {
      final raw = map['tags'];
      if (raw != null) {
        final decoded = jsonDecode(raw as String);
        if (decoded is List) {
          parsedTags = decoded.map((e) => e.toString()).toList();
        }
      }
    } catch (_) {}

    return PhoneContactItem(
      id: map['id'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String,
      secondaryPhone: map['secondary_phone'] as String?,
      hasWhatsApp: (map['has_whatsapp'] as int? ?? 0) == 1,
      whatsAppInfo: map['whatsapp_info'] as String?,
      hasSocial: (map['has_social'] as int? ?? 0) == 1,
      socialPlatform: map['social_platform'] as String?,
      socialHandle: map['social_handle'] as String?,
      notes: map['notes'] as String?,
      tags: parsedTags,
      origin: (map['origin'] as String?) ?? 'Informal',
      convertedPersonId: map['converted_person_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}

class PhoneContactsManager {
  final AppDatabase db;
  final Uuid _uuid = const Uuid();
  final StreamController<List<PhoneContactItem>> _controller = StreamController<List<PhoneContactItem>>.broadcast();
  Future<void>? _initFuture;

  PhoneContactsManager(this.db) {
    _initTable();
  }

  Future<void> _initTable() {
    _initFuture ??= _doInitTable();
    return _initFuture!;
  }

  Future<void> _doInitTable() async {
    try {
      await db.customStatement('''
        CREATE TABLE IF NOT EXISTS phone_contacts (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          phone TEXT NOT NULL,
          secondary_phone TEXT,
          has_whatsapp INTEGER NOT NULL DEFAULT 0,
          whatsapp_info TEXT,
          has_social INTEGER NOT NULL DEFAULT 0,
          social_platform TEXT,
          social_handle TEXT,
          notes TEXT,
          tags TEXT NOT NULL DEFAULT '[]',
          origin TEXT NOT NULL DEFAULT 'Informal',
          converted_person_id TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        );
      ''');
      _refresh();
    } catch (_) {}
  }

  Future<void> _refresh() async {
    try {
      final list = await getAllPhoneContacts();
      if (!_controller.isClosed) {
        _controller.add(list);
      }
    } catch (_) {}
  }

  Future<List<PhoneContactItem>> getAllPhoneContacts() async {
    await _initTable();
    try {
      final rows = await db.customSelect('SELECT * FROM phone_contacts ORDER BY name ASC').get();
      return rows.map((r) => PhoneContactItem.fromMap(r.data)).toList();
    } catch (_) {
      return [];
    }
  }

  Stream<List<PhoneContactItem>> watchPhoneContacts() async* {
    yield await getAllPhoneContacts();
    yield* _controller.stream;
  }

  Future<PhoneContactItem> addPhoneContact({
    required String name,
    required String phone,
    String? secondaryPhone,
    bool hasWhatsApp = false,
    String? whatsAppInfo,
    bool hasSocial = false,
    String? socialPlatform,
    String? socialHandle,
    String? notes,
    List<String> tags = const [],
    String origin = 'Informal',
  }) async {
    await _initTable();
    final now = DateTime.now();
    final id = _uuid.v4();

    await db.customInsert(
      'INSERT INTO phone_contacts (id, name, phone, secondary_phone, has_whatsapp, whatsapp_info, has_social, social_platform, social_handle, notes, tags, origin, converted_person_id, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      variables: [
        Variable.withString(id),
        Variable.withString(name.trim()),
        Variable.withString(phone.trim()),
        Variable.withString(secondaryPhone?.trim() ?? ''),
        Variable.withInt(hasWhatsApp ? 1 : 0),
        Variable.withString(whatsAppInfo?.trim() ?? ''),
        Variable.withInt(hasSocial ? 1 : 0),
        Variable.withString(socialPlatform?.trim() ?? ''),
        Variable.withString(socialHandle?.trim() ?? ''),
        Variable.withString(notes?.trim() ?? ''),
        Variable.withString(jsonEncode(tags)),
        Variable.withString(origin),
        Variable.withString(''),
        Variable.withString(now.toIso8601String()),
        Variable.withString(now.toIso8601String()),
      ],
    );

    final item = PhoneContactItem(
      id: id,
      name: name.trim(),
      phone: phone.trim(),
      secondaryPhone: secondaryPhone?.trim(),
      hasWhatsApp: hasWhatsApp,
      whatsAppInfo: whatsAppInfo?.trim(),
      hasSocial: hasSocial,
      socialPlatform: socialPlatform?.trim(),
      socialHandle: socialHandle?.trim(),
      notes: notes?.trim(),
      tags: tags,
      origin: origin,
      convertedPersonId: null,
      createdAt: now,
      updatedAt: now,
    );

    await _refresh();
    return item;
  }

  Future<void> updatePhoneContact(PhoneContactItem contact) async {
    await _initTable();
    final now = DateTime.now();
    await db.customUpdate(
      'UPDATE phone_contacts SET name = ?, phone = ?, secondary_phone = ?, has_whatsapp = ?, whatsapp_info = ?, has_social = ?, social_platform = ?, social_handle = ?, notes = ?, tags = ?, origin = ?, converted_person_id = ?, updated_at = ? WHERE id = ?',
      variables: [
        Variable.withString(contact.name.trim()),
        Variable.withString(contact.phone.trim()),
        Variable.withString(contact.secondaryPhone?.trim() ?? ''),
        Variable.withInt(contact.hasWhatsApp ? 1 : 0),
        Variable.withString(contact.whatsAppInfo?.trim() ?? ''),
        Variable.withInt(contact.hasSocial ? 1 : 0),
        Variable.withString(contact.socialPlatform?.trim() ?? ''),
        Variable.withString(contact.socialHandle?.trim() ?? ''),
        Variable.withString(contact.notes?.trim() ?? ''),
        Variable.withString(jsonEncode(contact.tags)),
        Variable.withString(contact.origin),
        Variable.withString(contact.convertedPersonId ?? ''),
        Variable.withString(now.toIso8601String()),
        Variable.withString(contact.id),
      ],
    );
    await _refresh();
  }

  Future<void> deletePhoneContact(String id) async {
    await _initTable();
    await db.customUpdate(
      'DELETE FROM phone_contacts WHERE id = ?',
      variables: [Variable.withString(id)],
    );
    await _refresh();
  }

  /// Converte/Exporta um contato telefônico para o cadastro completo de Pessoas
  Future<PersonEntry> convertToPerson({
    required PhoneContactItem contact,
    required AppRepository repo,
    required String address,
    double? latitude,
    double? longitude,
    String status = 'interessado',
  }) async {
    final person = await repo.createPerson(
      name: contact.name,
      phone: contact.phone,
      address: address.trim(),
      latitude: latitude,
      longitude: longitude,
      status: status,
      generalNotes: contact.notes,
      tags: contact.tags,
    );

    // Marca o contato telefônico com o personId vinculado
    await db.customUpdate(
      'UPDATE phone_contacts SET converted_person_id = ? WHERE id = ?',
      variables: [Variable.withString(person.id), Variable.withString(contact.id)],
    );

    await _refresh();
    return person;
  }
}

final phoneContactsManagerProvider = Provider<PhoneContactsManager>((ref) {
  final repo = ref.watch(repositoryProvider);
  return PhoneContactsManager(repo.db);
});

final phoneContactsStreamProvider = StreamProvider<List<PhoneContactItem>>((ref) {
  final mgr = ref.watch(phoneContactsManagerProvider);
  return mgr.watchPhoneContacts();
});
