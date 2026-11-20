import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';

/// Modelo de gravura/foto teocrática do Banco de Gravuras
class PictureEntry {
  final String id;
  final String caption;
  final List<String> tags;
  final String
  imageData; // Caminho de arquivo local, URL ou Base64 (data:image/...)
  final String? category;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PictureEntry({
    required this.id,
    required this.caption,
    required this.tags,
    required this.imageData,
    this.category,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'caption': caption,
    'tags': tags,
    'imageData': imageData,
    'category': category,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory PictureEntry.fromJson(Map<String, dynamic> json) => PictureEntry(
    id: json['id'] as String? ?? const Uuid().v4(),
    caption: json['caption'] as String? ?? '(Sem legenda)',
    tags:
        (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
        const [],
    imageData: json['imageData'] as String? ?? '',
    category: json['category'] as String?,
    createdAt: json['createdAt'] != null
        ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
        : DateTime.now(),
    updatedAt: json['updatedAt'] != null
        ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
        : DateTime.now(),
  );

  PictureEntry copyWith({
    String? id,
    String? caption,
    List<String>? tags,
    String? imageData,
    String? category,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PictureEntry(
      id: id ?? this.id,
      caption: caption ?? this.caption,
      tags: tags ?? this.tags,
      imageData: imageData ?? this.imageData,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Gerenciador com persistência local de gravuras no Drift (AppKvStore)
class PictureBankManager {
  static const String _kvKey = 'picture_bank_entries_v1';

  /// Carrega todas as gravuras armazenadas
  static Future<List<PictureEntry>> loadPictures(AppDatabase db) async {
    final row = await (db.select(
      db.appKvStore,
    )..where((t) => t.key.equals(_kvKey))).getSingleOrNull();

    if (row == null || row.value.isEmpty) {
      // Se vazio, insere itens de demonstração bíblica teocrática
      final seed = _defaultSeedPictures();
      await saveAll(db, seed);
      return seed;
    }

    try {
      final decoded = jsonDecode(row.value);
      if (decoded is List) {
        final list = decoded
            .map(
              (e) => PictureEntry.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      }
    } catch (_) {}
    return [];
  }

  /// Salva todas as gravuras em lote
  static Future<void> saveAll(AppDatabase db, List<PictureEntry> list) async {
    final encoded = jsonEncode(list.map((p) => p.toJson()).toList());
    await db
        .into(db.appKvStore)
        .insertOnConflictUpdate(
          AppKvStoreCompanion.insert(
            key: _kvKey,
            value: encoded,
            updatedAt: drift.Value(DateTime.now()),
          ),
        );
  }

  /// Adiciona ou edita uma gravura
  static Future<void> savePicture(AppDatabase db, PictureEntry entry) async {
    final existing = await loadPictures(db);
    final map = {for (final p in existing) p.id: p};
    map[entry.id] = entry;

    final list = map.values.toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await saveAll(db, list);
  }

  /// Remove uma gravura do banco
  static Future<void> deletePicture(AppDatabase db, String id) async {
    final existing = await loadPictures(db);
    final filtered = existing.where((p) => p.id != id).toList();
    await saveAll(db, filtered);
  }

  /// Sementes teocráticas padrão com ilustrações públicas
  static List<PictureEntry> _defaultSeedPictures() {
    final now = DateTime.now();
    return [
      PictureEntry(
        id: 'seed_pic_1',
        caption: 'Ministério Fluvial no Rio Solimões — Santo Antônio do Içá',
        tags: const ['campo', 'fluvial', 'solimoes', 'pregacao'],
        imageData: 'assets/images/placeholder_solimoes.png',
        category: 'Ministério',
        createdAt: now.subtract(const Duration(days: 3)),
        updatedAt: now.subtract(const Duration(days: 3)),
      ),
      PictureEntry(
        id: 'seed_pic_2',
        caption: 'Comunidade Indígena Ticuna de Betânia — Rio Jandiatuba',
        tags: const ['ticuna', 'betania', 'aldeia', 'estudo'],
        imageData: 'assets/images/placeholder_betania.png',
        category: 'Território',
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now.subtract(const Duration(days: 2)),
      ),
      PictureEntry(
        id: 'seed_pic_3',
        caption: 'Estudo Bíblico Familiar — Seja Feliz Para Sempre!',
        tags: const ['estudo', 'familia', 'biblia', 'ensino'],
        imageData: 'assets/images/placeholder_estudo.png',
        category: 'Estudos',
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
    ];
  }
}
