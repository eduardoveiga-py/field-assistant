import 'package:drift/drift.dart';

import '../core/app_logger.dart';
import '../database/app_database.dart';
import '../territory/map_engine_adapter.dart';

/// Unified offline geographic and entity search index using SQLite FTS5.
///
/// Provides accent-tolerant full-text search across contacts, territories,
/// and geographic features. Uses `unicode61 remove_diacritics 2` tokenizer
/// to support Portuguese diacritics and Ticuna stacked vowels.
///
/// The index is built from local Drift tables and can be rebuilt at any time
/// without data loss (the FTS table is a secondary index, not primary data).
class OfflineSearchIndex {
  final AppDatabase db;

  OfflineSearchIndex(this.db);

  /// FTS5 table name for unified geographic and entity search.
  static const String ftsTable = 'unified_search_fts';

  /// Create the FTS5 virtual table if it doesn't exist.
  /// Uses unicode61 tokenizer with remove_diacritics=2 for accent-tolerant
  /// matching of Portuguese (â, ã, é, ê, í, ó, ô, ú, ü, ç) and Ticuna
  /// (ũ, ü̃, ẽ, ĩ, etc.) characters.
  Future<void> ensureIndex() async {
    await db.customStatement('''
      CREATE VIRTUAL TABLE IF NOT EXISTS $ftsTable USING fts5(
        entity_id UNINDEXED,
        entity_type UNINDEXED,
        name,
        address,
        category,
        notes,
        latitude UNINDEXED,
        longitude UNINDEXED,
        tokenize = 'unicode61 remove_diacritics 2'
      );
    ''');
  }

  /// Completely rebuild the search index from current data.
  /// This is safe to call at any time — it clears the FTS table and
  /// repopulates from primary tables (people, territories, landmarks).
  Future<int> rebuildIndex() async {
    await ensureIndex();

    // Clear existing index
    await db.customStatement('DELETE FROM $ftsTable;');

    var count = 0;

    // Index people/contacts
    count += await _indexPeople();

    // Index territory landmarks (POIs)
    count += await _indexLandmarks();

    // Index territory sectors
    count += await _indexSectors();

    AppLogger.info('OfflineSearchIndex rebuilt with $count entries');

    return count;
  }

  Future<int> _indexPeople() async {
    final people = await db.select(db.people).get();
    for (final person in people) {
      await db.customStatement(
        'INSERT INTO $ftsTable(entity_id, entity_type, name, address, category, notes, latitude, longitude) '
        "VALUES (?, 'person', ?, ?, 'contact', ?, ?, ?);",
        [
          person.id,
          person.name,
          person.address ?? '',
          person.generalNotes ?? '',
          person.latitude?.toString() ?? '',
          person.longitude?.toString() ?? '',
        ],
      );
    }
    return people.length;
  }

  Future<int> _indexLandmarks() async {
    final landmarks = await db.select(db.territoryLandmarks).get();
    for (final lm in landmarks) {
      await db.customStatement(
        'INSERT INTO $ftsTable(entity_id, entity_type, name, address, category, notes, latitude, longitude) '
        "VALUES (?, 'landmark', ?, ?, ?, ?, ?, ?);",
        [
          lm.id,
          lm.name,
          lm.address ?? '',
          lm.category,
          lm.notes ?? '',
          lm.latitude?.toString() ?? '',
          lm.longitude?.toString() ?? '',
        ],
      );
    }
    return landmarks.length;
  }

  Future<int> _indexSectors() async {
    final sectors = await db.select(db.territorySectors).get();
    for (final sec in sectors) {
      await db.customStatement(
        'INSERT INTO $ftsTable(entity_id, entity_type, name, address, category, notes, latitude, longitude) '
        "VALUES (?, 'sector', ?, ?, 'territory', ?, ?, ?);",
        [sec.id, sec.name, '', sec.description ?? '', '', ''],
      );
    }
    return sectors.length;
  }

  /// Search the unified index with accent-tolerant FTS5 matching.
  ///
  /// Returns results ordered by FTS5 BM25 rank score. The [query] is
  /// automatically sanitized and tokenized for safe FTS5 usage.
  ///
  /// Optional [entityTypes] filter restricts results to specific types
  /// (e.g., `['person', 'landmark']`).
  ///
  /// Optional [boundingBox] restricts results to a geographic region.
  Future<List<SearchResult>> search(
    String query, {
    List<String>? entityTypes,
    GeoBoundingBox? boundingBox,
    int limit = 50,
  }) async {
    final sanitized = _sanitizeFtsQuery(query);
    if (sanitized.isEmpty) return [];

    try {
      await ensureIndex();
      final rows = await db
          .customSelect(
            'SELECT entity_id, entity_type, name, address, category, notes, '
            'latitude, longitude, rank '
            'FROM $ftsTable '
            'WHERE $ftsTable MATCH ? '
            'ORDER BY rank '
            'LIMIT ?;',
            variables: [
              Variable.withString(sanitized),
              Variable.withInt(limit),
            ],
          )
          .get();

      var results = rows.map((row) {
        final latStr = row.read<String>('latitude');
        final lonStr = row.read<String>('longitude');
        return SearchResult(
          entityId: row.read<String>('entity_id'),
          entityType: row.read<String>('entity_type'),
          name: row.read<String>('name'),
          address: row.read<String>('address'),
          category: row.read<String>('category'),
          notes: row.read<String>('notes'),
          latitude: latStr.isNotEmpty ? double.tryParse(latStr) : null,
          longitude: lonStr.isNotEmpty ? double.tryParse(lonStr) : null,
          rank: row.read<double>('rank'),
        );
      }).toList();

      // Apply entity type filter
      if (entityTypes != null && entityTypes.isNotEmpty) {
        results = results
            .where((r) => entityTypes.contains(r.entityType))
            .toList();
      }

      // Apply bounding box filter
      if (boundingBox != null) {
        results = results.where((r) {
          if (r.latitude == null || r.longitude == null) return false;
          return boundingBox.contains(r.latitude!, r.longitude!);
        }).toList();
      }

      return results;
    } catch (e) {
      AppLogger.error('OfflineSearchIndex.search failed: $e');
      return [];
    }
  }

  /// Sanitize user input for safe FTS5 query syntax.
  /// Escapes special characters and converts to prefix matching.
  String _sanitizeFtsQuery(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return '';

    // Split into words, escape each, add prefix matching with *
    final words = trimmed.split(RegExp(r'\s+'));
    final escaped = words
        .where((w) => w.isNotEmpty)
        .map((w) {
          // Remove FTS5 special characters
          final clean = w.replaceAll(RegExp(r'["\(\)\*\+\-\^:]'), '');
          if (clean.isEmpty) return null;
          // Add prefix matching for partial queries
          return '"$clean"*';
        })
        .whereType<String>()
        .toList();

    if (escaped.isEmpty) return '';
    return escaped.join(' ');
  }

  /// Drop the FTS index (useful for testing or storage reclamation).
  Future<void> dropIndex() async {
    try {
      await db.customStatement('DROP TABLE IF EXISTS $ftsTable;');
    } catch (e) {
      AppLogger.error('OfflineSearchIndex.dropIndex failed: $e');
    }
  }
}

/// A single search result from the unified offline index.
class SearchResult {
  final String entityId;
  final String entityType;
  final String name;
  final String address;
  final String category;
  final String notes;
  final double? latitude;
  final double? longitude;
  final double rank;

  const SearchResult({
    required this.entityId,
    required this.entityType,
    required this.name,
    required this.address,
    required this.category,
    required this.notes,
    this.latitude,
    this.longitude,
    required this.rank,
  });
}
