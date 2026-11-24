import 'dart:convert';

import 'package:drift/drift.dart' as drift;

import '../database/app_database.dart';

/// Modelo de contato salvo para e-mails teocráticos e externos (JWPUB, Exchange, Google, Hotmail)
class EmailContact {
  final String email;
  final String name;
  final String source; // 'auto_sender', 'manual', 'field_contact'
  final DateTime updatedAt;
  final List<String> tags;

  const EmailContact({
    required this.email,
    required this.name,
    this.source = 'auto_sender',
    required this.updatedAt,
    this.tags = const [],
  });

  Map<String, dynamic> toJson() => {
    'email': email,
    'name': name,
    'source': source,
    'updatedAt': updatedAt.toIso8601String(),
    'tags': tags,
  };

  factory EmailContact.fromJson(Map<String, dynamic> json) => EmailContact(
    email: json['email'] as String? ?? '',
    name: json['name'] as String? ?? '',
    source: json['source'] as String? ?? 'auto_sender',
    updatedAt: json['updatedAt'] != null
        ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
        : DateTime.now(),
    tags:
        (json['tags'] as List?)
            ?.map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList() ??
            const [],
  );

  String get displayName => name.trim().isNotEmpty ? '$name <$email>' : email;
}

/// Gerenciador de Contatos de E-mail com autossalvamento de remetentes,
/// sugestões no autocomplete e seleção múltipla com pesquisa.
class EmailContactsManager {
  static const String _kvStoreKey = 'email_contacts_registry';

  /// Extrai nome e e-mail de um cabeçalho bruto como `"João Silva <joao@exemplo.com>"` ou `"joao@exemplo.com"`
  static ({String name, String email}) parseAddress(String raw) {
    final trimmed = raw.trim();
    final match = RegExp(
      r'^(.*?)\s*<([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})>$',
    ).firstMatch(trimmed);
    if (match != null) {
      final name = match.group(1)!.replaceAll('"', '').trim();
      final email = match.group(2)!.trim().toLowerCase();
      return (name: name, email: email);
    }
    final emailMatch = RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}')
        .firstMatch(trimmed);
    if (emailMatch != null) {
      final email = emailMatch.group(0)!.trim().toLowerCase();
      final name = trimmed
          .replaceAll(email, '')
          .replaceAll(RegExp(r'[<>"()]'), '')
          .trim();
      return (name: name, email: email);
    }
    return (name: '', email: trimmed.toLowerCase());
  }

  /// Salva ou atualiza um contato no registro local
  static Future<void> saveContact(
    AppDatabase db, {
    required String email,
    String? name,
    String source = 'manual',
    List<String>? tags,
  }) async {
    final parsed = parseAddress(
      name != null && name.isNotEmpty ? '$name <$email>' : email,
    );
    if (parsed.email.isEmpty || !parsed.email.contains('@')) return;

    final existingList = await loadSavedContacts(db);
    final map = {for (final c in existingList) c.email.toLowerCase(): c};

    final effectiveName = parsed.name.isNotEmpty
        ? parsed.name
        : (map[parsed.email]?.name ?? '');
    final effectiveTags = tags != null
        ? tags.map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
        : (map[parsed.email]?.tags ?? const []);

    map[parsed.email] = EmailContact(
      email: parsed.email,
      name: effectiveName,
      source: source,
      updatedAt: DateTime.now(),
      tags: effectiveTags,
    );

    final encoded = jsonEncode(map.values.map((c) => c.toJson()).toList());
    await db
        .into(db.appKvStore)
        .insertOnConflictUpdate(
          AppKvStoreCompanion.insert(
            key: _kvStoreKey,
            value: encoded,
            updatedAt: drift.Value(DateTime.now()),
          ),
        );
  }

  /// Registra automaticamente o remetente de uma nova mensagem recebida
  static Future<void> recordSender(AppDatabase db, String fromRaw) async {
    final parsed = parseAddress(fromRaw);
    if (parsed.email.isNotEmpty && parsed.email.contains('@')) {
      await saveContact(
        db,
        email: parsed.email,
        name: parsed.name,
        source: 'auto_sender',
      );
    }
  }

  /// Carrega os contatos salvos no AppKvStore
  static Future<List<EmailContact>> loadSavedContacts(AppDatabase db) async {
    final row = await (db.select(
      db.appKvStore,
    )..where((t) => t.key.equals(_kvStoreKey))).getSingleOrNull();
    if (row == null || row.value.isEmpty) return [];
    try {
      final decoded = jsonDecode(row.value);
      if (decoded is List) {
        return decoded
            .map(
              (e) => EmailContact.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .where((c) => c.email.isNotEmpty && c.email.contains('@'))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// Exclui um contato do registro
  static Future<void> deleteContact(AppDatabase db, String email) async {
    final existingList = await loadSavedContacts(db);
    final filtered = existingList
        .where((c) => c.email.toLowerCase() != email.trim().toLowerCase())
        .toList();
    final encoded = jsonEncode(filtered.map((c) => c.toJson()).toList());
    await db
        .into(db.appKvStore)
        .insertOnConflictUpdate(
          AppKvStoreCompanion.insert(
            key: _kvStoreKey,
            value: encoded,
            updatedAt: drift.Value(DateTime.now()),
          ),
        );
  }

  /// Atualiza os dados de um contato existente (permitindo alteração de nome e e-mail)
  static Future<void> updateContact(
    AppDatabase db, {
    required String oldEmail,
    required String newEmail,
    required String name,
    List<String>? tags,
  }) async {
    final oldNorm = oldEmail.trim().toLowerCase();
    final newNorm = newEmail.trim().toLowerCase();
    if (newNorm.isEmpty || !newNorm.contains('@')) return;

    List<String>? preservedTags = tags;
    if (preservedTags == null && oldNorm.isNotEmpty && oldNorm != newNorm) {
      final existingList = await loadSavedContacts(db);
      for (final c in existingList) {
        if (c.email.toLowerCase() == oldNorm) {
          preservedTags = c.tags;
          break;
        }
      }
    }

    if (oldNorm.isNotEmpty && oldNorm != newNorm) {
      await deleteContact(db, oldNorm);
    }
    await saveContact(
      db, 
      email: newNorm, 
      name: name.trim(), 
      source: 'manual',
      tags: preservedTags,
    );
  }

  /// Obtém sugestões unificadas combinando o registro de e-mails com as pessoas cadastradas no Field Assistant
  static Future<List<EmailContact>> getAllSuggestions(
    AppDatabase db, {
    String query = '',
  }) async {
    final saved = await loadSavedContacts(db);
    final contactsMap = <String, EmailContact>{};

    for (final c in saved) {
      contactsMap[c.email.toLowerCase()] = c;
    }

    // Busca também nas pessoas cadastradas do ministério que possuam e-mail nas anotações ou no perfil
    final people = await db.select(db.people).get();
    for (final p in people) {
      final text = '${p.generalNotes ?? ''} ${p.contactRestrictions ?? ''}';
      final matches = RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}')
          .allMatches(text);
      for (final m in matches) {
        final em = m.group(0)!.toLowerCase();
        if (!contactsMap.containsKey(em)) {
          contactsMap[em] = EmailContact(
            email: em,
            name: p.name,
            source: 'field_contact',
            updatedAt: p.updatedAt,
          );
        }
      }
    }

    var list = contactsMap.values.toList();
    final q = query.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((c) {
        return c.name.toLowerCase().contains(q) ||
            c.email.toLowerCase().contains(q);
      }).toList();
    }

    list.sort((a, b) {
      final nameCompare = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      if (nameCompare != 0) return nameCompare;
      return a.email.compareTo(b.email);
    });

    return list;
  }

  /// Extrai todas as etiquetas únicas ordenadas alfabeticamente
  static List<String> extractAllTags(List<EmailContact> contacts) {
    final unique = <String>{};
    for (final contact in contacts) {
      for (final tag in contact.tags) {
        final trimmed = tag.trim();
        if (trimmed.isNotEmpty) {
          unique.add(trimmed);
        }
      }
    }
    return unique.toList()..sort();
  }
}
