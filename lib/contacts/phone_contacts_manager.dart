import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../database/repository.dart';
import '../ui/providers.dart';
import '../core/app_logger.dart';

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
  final String
  origin; // 'Rua', 'TPL / Carrinho', 'Informal', 'Telefone', 'Outro'
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
  final StreamController<List<PhoneContactItem>> _controller =
      StreamController<List<PhoneContactItem>>.broadcast();

  PhoneContactsManager(this.db);

  static List<String> _parseTags(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded.cast<String>();
    } catch (e) {
      AppLogger.warning('Erro ao processar tags de contato telefônico', e);
    }
    return [];
  }

  Future<void> _refresh() async {
    try {
      final list = await getAllPhoneContacts();
      if (!_controller.isClosed) {
        _controller.add(list);
      }
    } catch (e) {
      AppLogger.error('Erro ao atualizar stream de contatos telefônicos', e);
    }
  }

  Future<List<PhoneContactItem>> getAllPhoneContacts() async {
    try {
      final rows =
          await (db.select(db.phoneContacts)
                ..where((t) => t.deletedAt.isNull())
                ..orderBy([
                  (t) =>
                      OrderingTerm(expression: t.name, mode: OrderingMode.asc),
                ]))
              .get();
      return rows
          .map(
            (r) => PhoneContactItem(
              id: r.id,
              name: r.name,
              phone: r.phone,
              secondaryPhone: r.secondaryPhone,
              hasWhatsApp: r.hasWhatsapp,
              whatsAppInfo: r.whatsappInfo,
              hasSocial: r.hasSocial,
              socialPlatform: r.socialPlatform,
              socialHandle: r.socialHandle,
              notes: r.notes,
              tags: _parseTags(r.tags),
              origin: r.origin,
              convertedPersonId: r.convertedPersonId,
              createdAt: r.createdAt,
              updatedAt: r.updatedAt,
            ),
          )
          .toList();
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
    final now = DateTime.now();
    final id = _uuid.v4();

    await db
        .into(db.phoneContacts)
        .insert(
          PhoneContactsCompanion.insert(
            id: id,
            name: name.trim(),
            phone: phone.trim(),
            secondaryPhone: Value(secondaryPhone?.trim()),
            hasWhatsapp: Value(hasWhatsApp),
            whatsappInfo: Value(whatsAppInfo?.trim()),
            hasSocial: Value(hasSocial),
            socialPlatform: Value(socialPlatform?.trim()),
            socialHandle: Value(socialHandle?.trim()),
            notes: Value(notes?.trim()),
            tags: Value(jsonEncode(tags)),
            origin: Value(origin),
            convertedPersonId: const Value.absent(),
            createdAt: now,
            updatedAt: now,
          ),
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

    try {
      await db
          .into(db.syncQueue)
          .insert(
            SyncQueueCompanion.insert(
              id: _uuid.v4(),
              entityType: 'phone_contacts',
              entityId: id,
              operation: 'INSERT',
              payload: jsonEncode(item.toMap()),
              createdAt: now,
              status: const Value('pending'),
            ),
          );
    } catch (_) {}

    await _refresh();
    return item;
  }

  Future<void> updatePhoneContact(PhoneContactItem contact) async {
    final now = DateTime.now();
    await (db.update(
      db.phoneContacts,
    )..where((t) => t.id.equals(contact.id))).write(
      PhoneContactsCompanion(
        name: Value(contact.name.trim()),
        phone: Value(contact.phone.trim()),
        secondaryPhone: Value(contact.secondaryPhone?.trim()),
        hasWhatsapp: Value(contact.hasWhatsApp),
        whatsappInfo: Value(contact.whatsAppInfo?.trim()),
        hasSocial: Value(contact.hasSocial),
        socialPlatform: Value(contact.socialPlatform?.trim()),
        socialHandle: Value(contact.socialHandle?.trim()),
        notes: Value(contact.notes?.trim()),
        tags: Value(jsonEncode(contact.tags)),
        origin: Value(contact.origin),
        convertedPersonId: Value(contact.convertedPersonId),
        updatedAt: Value(now),
      ),
    );

    try {
      await db
          .into(db.syncQueue)
          .insert(
            SyncQueueCompanion.insert(
              id: _uuid.v4(),
              entityType: 'phone_contacts',
              entityId: contact.id,
              operation: 'UPDATE',
              payload: jsonEncode(contact.toMap()),
              createdAt: now,
              status: const Value('pending'),
            ),
          );
    } catch (_) {}

    await _refresh();
  }

  Future<void> deletePhoneContact(String id) async {
    final now = DateTime.now();
    await (db.update(db.phoneContacts)..where((t) => t.id.equals(id))).write(
      PhoneContactsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );

    try {
      await db
          .into(db.syncQueue)
          .insert(
            SyncQueueCompanion.insert(
              id: _uuid.v4(),
              entityType: 'phone_contacts',
              entityId: id,
              operation: 'DELETE',
              payload: jsonEncode({
                'id': id,
                'deleted_at': now.toIso8601String(),
              }),
              createdAt: now,
              status: const Value('pending'),
            ),
          );
    } catch (_) {}

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
    await (db.update(
      db.phoneContacts,
    )..where((t) => t.id.equals(contact.id))).write(
      PhoneContactsCompanion(
        convertedPersonId: Value(person.id),
        updatedAt: Value(DateTime.now()),
      ),
    );

    await _refresh();
    return person;
  }
}

final phoneContactsManagerProvider = Provider<PhoneContactsManager>((ref) {
  final repo = ref.watch(repositoryProvider);
  return PhoneContactsManager(repo.db);
});

final phoneContactsStreamProvider = StreamProvider<List<PhoneContactItem>>((
  ref,
) {
  final mgr = ref.watch(phoneContactsManagerProvider);
  return mgr.watchPhoneContacts();
});
