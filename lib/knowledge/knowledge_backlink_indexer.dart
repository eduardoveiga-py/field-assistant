import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';

import '../core/app_logger.dart';
import '../core/sync_timestamp.dart';
import '../database/app_database.dart';
import '../references/app_reference.dart';
import 'knowledge_search_common.dart';

/// Vínculo bidirecional resolvido ("Mencionado em...") para exibição na UI.
class ResolvedBacklink {
  final String linkId;
  final String
  sourceType; // note, question, project, task, research, document, resource
  final String sourceId;
  final String sourceTitle;
  final String sourceSubtitle;
  final String anchorText;
  final DateTime updatedAt;

  const ResolvedBacklink({
    required this.linkId,
    required this.sourceType,
    required this.sourceId,
    required this.sourceTitle,
    required this.sourceSubtitle,
    required this.anchorText,
    required this.updatedAt,
  });
}

class _DesiredLinkTarget {
  final String targetType;
  final String targetId;
  final String targetUri;
  final String anchorText;

  const _DesiredLinkTarget({
    required this.targetType,
    required this.targetId,
    required this.targetUri,
    required this.anchorText,
  });
}

/// Extrai referências internas (`[Label](app://ref/<tipo>/<id>)` e `[[Título]]`)
/// e mantém o grafo sincronizável `knowledge_links` atualizado.
class KnowledgeBacklinkIndexer {
  static const String _backfillKvKey = 'kb_backlinks_backfill_v1';
  static const Uuid _uuid = Uuid();

  static final RegExp _mdAppRefPattern = RegExp(
    r'\[([^\]\n]*)\]\((app://ref/[^\s)]+)\)',
  );
  static final RegExp _rawAppRefPattern = RegExp(
    r'''(app://ref/[^\s)>\]"']+)''',
  );
  static final RegExp _wikiLinkPattern = RegExp(r'\[\[([^\]\n]+)\]\]');

  static String buildDeterministicId({
    required String sourceType,
    required String sourceId,
    required String targetType,
    required String targetId,
  }) {
    final digest = sha256
        .convert(
          utf8.encode('fa-klink|$sourceType|$sourceId|$targetType|$targetId'),
        )
        .toString();
    return '${digest.substring(0, 8)}-'
        '${digest.substring(8, 12)}-'
        '${digest.substring(12, 16)}-'
        '${digest.substring(16, 20)}-'
        '${digest.substring(20, 32)}';
  }

  /// Extrai pares `(label, uri)` de referências `app://ref/...` presentes nos textos.
  static List<({String uri, String anchorText})> extractAppReferenceUris(
    List<String> textFields,
  ) {
    final seenUris = <String>{};
    final out = <({String uri, String anchorText})>[];
    final combined = textFields.where((s) => s.trim().isNotEmpty).join('\n');
    if (combined.isEmpty) return out;

    for (final m in _mdAppRefPattern.allMatches(combined)) {
      final label = (m.group(1) ?? '').trim();
      final uri = (m.group(2) ?? '').trim();
      if (uri.isNotEmpty && seenUris.add(uri)) {
        out.add((uri: uri, anchorText: label));
      }
    }

    for (final m in _rawAppRefPattern.allMatches(combined)) {
      final uri = (m.group(1) ?? '').trim();
      if (uri.isNotEmpty && seenUris.add(uri)) {
        out.add((uri: uri, anchorText: ''));
      }
    }
    return out;
  }

  /// Extrai títulos `[[Título]]` ou `[[Título|Apelido]]` presentes nos textos.
  static List<({String rawTitle, String displayLabel})> extractWikiLinks(
    List<String> textFields,
  ) {
    final out = <({String rawTitle, String displayLabel})>[];
    final seen = <String>{};
    final combined = textFields.where((s) => s.trim().isNotEmpty).join('\n');
    if (combined.isEmpty) return out;

    for (final m in _wikiLinkPattern.allMatches(combined)) {
      final inside = (m.group(1) ?? '').trim();
      if (inside.isEmpty) continue;
      final pipeIdx = inside.indexOf('|');
      final rawTitle = (pipeIdx == -1 ? inside : inside.substring(0, pipeIdx))
          .trim();
      final displayLabel =
          (pipeIdx == -1 ? rawTitle : inside.substring(pipeIdx + 1)).trim();
      if (rawTitle.isEmpty) continue;
      final key = rawTitle.toLowerCase();
      if (seen.add(key)) {
        out.add((
          rawTitle: rawTitle,
          displayLabel: displayLabel.isEmpty ? rawTitle : displayLabel,
        ));
      }
    }
    return out;
  }

  static String _resolvedTargetId(ParsedAppReference parsed) {
    if (parsed.category == AppRefCategory.bible) {
      final book = parsed.bookNumber ?? 0;
      final ch = parsed.chapter ?? 0;
      final vs = parsed.verseSpec?.trim() ?? '';
      return vs.isEmpty ? '$book:$ch' : '$book:$ch:$vs';
    }
    if (parsed.category == AppRefCategory.publication &&
        parsed.publicationChapterIndex != null) {
      return '${parsed.itemId}#${parsed.publicationChapterIndex}';
    }
    return parsed.itemId;
  }

  static Future<Map<String, ({String type, String id, String uri})>>
  _loadTitleResolutionIndex(AppDatabase db) async {
    final index = <String, ({String type, String id, String uri})>{};

    void register(String type, String id, String title, AppRefCategory cat) {
      final key = KnowledgeSearchCommon.normalizeSearchText(title);
      if (key.isEmpty) return;
      index.putIfAbsent(
        key,
        () => (type: type, id: id, uri: AppReferenceHelper.buildUri(cat, id)),
      );
      final rawLower = title.trim().toLowerCase();
      if (rawLower.isNotEmpty) {
        index.putIfAbsent(
          rawLower,
          () => (type: type, id: id, uri: AppReferenceHelper.buildUri(cat, id)),
        );
      }
    }

    final notes = await (db.select(
      db.knowledgeNotes,
    )..where((t) => t.deletedAt.isNull())).get();
    for (final n in notes) {
      if (n.category == 'official_profile_bundle' ||
          n.category == 'official_template') {
        continue;
      }
      register('note', n.id, n.title, AppRefCategory.note);
    }

    final questions = await (db.select(
      db.knowledgeQuestions,
    )..where((t) => t.deletedAt.isNull())).get();
    for (final q in questions) {
      register('question', q.id, q.question, AppRefCategory.question);
    }

    final docs = await (db.select(
      db.knowledgeDocuments,
    )..where((t) => t.deletedAt.isNull())).get();
    for (final d in docs) {
      register('document', d.id, d.title, AppRefCategory.document);
    }

    final resources = await (db.select(
      db.knowledgeResources,
    )..where((t) => t.deletedAt.isNull())).get();
    for (final r in resources) {
      register('resource', r.id, r.title, AppRefCategory.resource);
    }

    final projects = await (db.select(
      db.projects,
    )..where((t) => t.deletedAt.isNull())).get();
    for (final p in projects) {
      register('project', p.id, p.name, AppRefCategory.project);
    }

    final articles = await (db.select(
      db.researchArticles,
    )..where((t) => t.deletedAt.isNull())).get();
    for (final a in articles) {
      register('research', a.id, a.title, AppRefCategory.research);
    }

    return index;
  }

  /// Atualiza todos os vínculos originados em `(sourceType, sourceId)`.
  static Future<void> reindexLinksForSource(
    AppDatabase db, {
    required String sourceType,
    required String sourceId,
    required List<String> textFields,
    bool enqueueSync = true,
  }) async {
    final desired = <String, _DesiredLinkTarget>{};

    for (final item in extractAppReferenceUris(textFields)) {
      final parsed = AppReferenceHelper.parseUri(item.uri);
      if (parsed == null) continue;
      final tType = parsed.category.typeId;
      final tId = _resolvedTargetId(parsed);
      if (tId.isEmpty) continue;
      if (tType == sourceType && tId == sourceId) continue;
      desired['$tType|$tId'] = _DesiredLinkTarget(
        targetType: tType,
        targetId: tId,
        targetUri: item.uri,
        anchorText: item.anchorText,
      );
    }

    final wikiItems = extractWikiLinks(textFields);
    if (wikiItems.isNotEmpty) {
      final index = await _loadTitleResolutionIndex(db);
      for (final w in wikiItems) {
        final norm = KnowledgeSearchCommon.normalizeSearchText(w.rawTitle);
        final resolved = index[norm] ?? index[w.rawTitle.toLowerCase()];
        if (resolved == null) continue;
        if (resolved.type == sourceType && resolved.id == sourceId) continue;
        final key = '${resolved.type}|${resolved.id}';
        desired.putIfAbsent(
          key,
          () => _DesiredLinkTarget(
            targetType: resolved.type,
            targetId: resolved.id,
            targetUri: resolved.uri,
            anchorText: w.displayLabel,
          ),
        );
      }
    }

    final existingPrecheck =
        await (db.select(db.knowledgeLinks)..where(
              (t) =>
                  t.sourceType.equals(sourceType) &
                  t.sourceId.equals(sourceId) &
                  t.deletedAt.isNull(),
            ))
            .get();
    if (desired.isEmpty && existingPrecheck.isEmpty) {
      return;
    }

    await db.transaction(() async {
      final now = DateTime.now().toUtc();
      final existingRows =
          await (db.select(db.knowledgeLinks)..where(
                (t) =>
                    t.sourceType.equals(sourceType) &
                    t.sourceId.equals(sourceId),
              ))
              .get();

      final existingByTarget = <String, KnowledgeLinkEntry>{
        for (final row in existingRows)
          '${row.targetType}|${row.targetId}': row,
      };

      // 1. Soft-delete vínculos removidos do texto
      for (final existing in existingRows) {
        final k = '${existing.targetType}|${existing.targetId}';
        if (!desired.containsKey(k) && existing.deletedAt == null) {
          final nextRev = existing.revision + 1;
          await (db.update(
            db.knowledgeLinks,
          )..where((t) => t.id.equals(existing.id))).write(
            KnowledgeLinksCompanion(
              deletedAt: drift.Value(now),
              updatedAt: drift.Value(now),
              revision: drift.Value(nextRev),
            ),
          );
          if (enqueueSync) {
            final row = await (db.select(
              db.knowledgeLinks,
            )..where((t) => t.id.equals(existing.id))).getSingle();
            await _enqueueSync(db, row, 'DELETE', baseData: existing.toJson());
          }
        }
      }

      // 2. Inserir novos ou reativar/atualizar existentes
      for (final entry in desired.entries) {
        final target = entry.value;
        final prev = existingByTarget[entry.key];
        if (prev == null) {
          final id = buildDeterministicId(
            sourceType: sourceType,
            sourceId: sourceId,
            targetType: target.targetType,
            targetId: target.targetId,
          );
          await db
              .into(db.knowledgeLinks)
              .insertOnConflictUpdate(
                KnowledgeLinksCompanion.insert(
                  id: id,
                  sourceType: sourceType,
                  sourceId: sourceId,
                  targetType: target.targetType,
                  targetId: target.targetId,
                  targetUri: target.targetUri,
                  anchorText: drift.Value(target.anchorText),
                  createdAt: now,
                  updatedAt: now,
                ),
              );
          if (enqueueSync) {
            final inserted = await (db.select(
              db.knowledgeLinks,
            )..where((t) => t.id.equals(id))).getSingle();
            await _enqueueSync(db, inserted, 'INSERT');
          }
        } else if (prev.deletedAt != null ||
            prev.targetUri != target.targetUri ||
            prev.anchorText != target.anchorText) {
          final nextRev = prev.revision + 1;
          await (db.update(
            db.knowledgeLinks,
          )..where((t) => t.id.equals(prev.id))).write(
            KnowledgeLinksCompanion(
              targetUri: drift.Value(target.targetUri),
              anchorText: drift.Value(target.anchorText),
              deletedAt: const drift.Value(null),
              updatedAt: drift.Value(now),
              revision: drift.Value(nextRev),
            ),
          );
          if (enqueueSync) {
            final updated = await (db.select(
              db.knowledgeLinks,
            )..where((t) => t.id.equals(prev.id))).getSingle();
            await _enqueueSync(db, updated, 'UPDATE', baseData: prev.toJson());
          }
        }
      }
    });
  }

  /// Remove (soft-delete) todos os vínculos originados por uma entidade apagada.
  static Future<void> softDeleteLinksForSource(
    AppDatabase db, {
    required String sourceType,
    required String sourceId,
    bool enqueueSync = true,
  }) {
    return reindexLinksForSource(
      db,
      sourceType: sourceType,
      sourceId: sourceId,
      textFields: const [],
      enqueueSync: enqueueSync,
    );
  }

  /// Observa em tempo real todos os itens que apontam PARA `(targetType, targetId)`.
  static Stream<List<ResolvedBacklink>> watchBacklinksFor(
    AppDatabase db, {
    required String targetType,
    required String targetId,
  }) {
    return (db.select(db.knowledgeLinks)
          ..where(
            (t) =>
                t.targetType.equals(targetType) &
                t.targetId.equals(targetId) &
                t.deletedAt.isNull(),
          )
          ..orderBy([
            (t) => drift.OrderingTerm(
              expression: t.updatedAt,
              mode: drift.OrderingMode.desc,
            ),
          ]))
        .watch()
        .asyncMap((links) => _resolveBacklinks(db, links));
  }

  /// Consulta única dos backlinks ativos que apontam PARA `(targetType, targetId)`.
  static Future<List<ResolvedBacklink>> getBacklinksFor(
    AppDatabase db, {
    required String targetType,
    required String targetId,
  }) async {
    final links =
        await (db.select(db.knowledgeLinks)
              ..where(
                (t) =>
                    t.targetType.equals(targetType) &
                    t.targetId.equals(targetId) &
                    t.deletedAt.isNull(),
              )
              ..orderBy([
                (t) => drift.OrderingTerm(
                  expression: t.updatedAt,
                  mode: drift.OrderingMode.desc,
                ),
              ]))
            .get();
    return _resolveBacklinks(db, links);
  }

  static Future<List<ResolvedBacklink>> _resolveBacklinks(
    AppDatabase db,
    List<KnowledgeLinkEntry> links,
  ) async {
    final resolved = <ResolvedBacklink>[];
    for (final link in links) {
      final info = await _lookupSourceMeta(db, link.sourceType, link.sourceId);
      if (info == null) continue; // origem inexistente ou deletada
      resolved.add(
        ResolvedBacklink(
          linkId: link.id,
          sourceType: link.sourceType,
          sourceId: link.sourceId,
          sourceTitle: info.title,
          sourceSubtitle: info.subtitle,
          anchorText: link.anchorText,
          updatedAt: link.updatedAt,
        ),
      );
    }
    return resolved;
  }

  static Future<({String title, String subtitle})?> _lookupSourceMeta(
    AppDatabase db,
    String sourceType,
    String sourceId,
  ) async {
    switch (sourceType) {
      case 'note':
        final n =
            await (db.select(db.knowledgeNotes)
                  ..where((t) => t.id.equals(sourceId) & t.deletedAt.isNull()))
                .getSingleOrNull();
        if (n == null) return null;
        return (title: n.title, subtitle: 'Nota • ${n.category}');
      case 'question':
        final q =
            await (db.select(db.knowledgeQuestions)
                  ..where((t) => t.id.equals(sourceId) & t.deletedAt.isNull()))
                .getSingleOrNull();
        if (q == null) return null;
        return (title: q.question, subtitle: 'Dúvida • ${q.category}');
      case 'document':
        final d =
            await (db.select(db.knowledgeDocuments)
                  ..where((t) => t.id.equals(sourceId) & t.deletedAt.isNull()))
                .getSingleOrNull();
        if (d == null) return null;
        return (title: d.title, subtitle: 'Documento • ${d.fileName}');
      case 'resource':
        final r =
            await (db.select(db.knowledgeResources)
                  ..where((t) => t.id.equals(sourceId) & t.deletedAt.isNull()))
                .getSingleOrNull();
        if (r == null) return null;
        return (title: r.title, subtitle: 'Recurso • ${r.resourceType}');
      case 'project':
        final p =
            await (db.select(db.projects)
                  ..where((t) => t.id.equals(sourceId) & t.deletedAt.isNull()))
                .getSingleOrNull();
        if (p == null) return null;
        return (title: p.name, subtitle: 'Projeto • ${p.status}');
      case 'task':
        final t =
            await (db.select(db.tasks)..where(
                  (row) => row.id.equals(sourceId) & row.deletedAt.isNull(),
                ))
                .getSingleOrNull();
        if (t == null) return null;
        return (title: t.title, subtitle: 'Tarefa • ${t.status}');
      case 'research':
        final a =
            await (db.select(db.researchArticles)..where(
                  (row) => row.id.equals(sourceId) & row.deletedAt.isNull(),
                ))
                .getSingleOrNull();
        if (a == null) return null;
        return (title: a.title, subtitle: 'Pesquisa');
      default:
        return null;
    }
  }

  /// Backfill preguiçoso único das bases pré-existentes para popular `knowledge_links`.
  static Future<int> ensureInitialBackfill(AppDatabase db) async {
    final existingFlag = await (db.select(
      db.appKvStore,
    )..where((t) => t.key.equals(_backfillKvKey))).getSingleOrNull();
    if (existingFlag != null && existingFlag.value == '1') {
      return 0;
    }
    final count = await reindexAllSources(db, enqueueSync: false);
    await db
        .into(db.appKvStore)
        .insertOnConflictUpdate(
          AppKvStoreCompanion.insert(
            key: _backfillKvKey,
            value: '1',
            updatedAt: drift.Value(DateTime.now().toUtc()),
          ),
        );
    return count;
  }

  static Future<int> reindexAllSources(
    AppDatabase db, {
    bool enqueueSync = true,
  }) async {
    var processed = 0;

    final notes = await (db.select(
      db.knowledgeNotes,
    )..where((t) => t.deletedAt.isNull())).get();
    for (final n in notes) {
      if (n.content.contains('app://ref/') || n.content.contains('[[')) {
        await reindexLinksForSource(
          db,
          sourceType: 'note',
          sourceId: n.id,
          textFields: [n.content],
          enqueueSync: enqueueSync,
        );
        processed++;
      }
    }

    final questions = await (db.select(
      db.knowledgeQuestions,
    )..where((t) => t.deletedAt.isNull())).get();
    for (final q in questions) {
      final combined = '${q.context ?? ''} ${q.answer ?? ''}';
      if (combined.contains('app://ref/') || combined.contains('[[')) {
        await reindexLinksForSource(
          db,
          sourceType: 'question',
          sourceId: q.id,
          textFields: [q.context ?? '', q.answer ?? ''],
          enqueueSync: enqueueSync,
        );
        processed++;
      }
    }

    final resources = await (db.select(
      db.knowledgeResources,
    )..where((t) => t.deletedAt.isNull())).get();
    for (final r in resources) {
      final desc = r.description ?? '';
      if (desc.contains('app://ref/') || desc.contains('[[')) {
        await reindexLinksForSource(
          db,
          sourceType: 'resource',
          sourceId: r.id,
          textFields: [desc],
          enqueueSync: enqueueSync,
        );
        processed++;
      }
    }

    final projects = await (db.select(
      db.projects,
    )..where((t) => t.deletedAt.isNull())).get();
    for (final p in projects) {
      final combined = '${p.objective ?? ''} ${p.description ?? ''}';
      if (combined.contains('app://ref/') || combined.contains('[[')) {
        await reindexLinksForSource(
          db,
          sourceType: 'project',
          sourceId: p.id,
          textFields: [p.objective ?? '', p.description ?? ''],
          enqueueSync: enqueueSync,
        );
        processed++;
      }
    }

    final tasks = await (db.select(
      db.tasks,
    )..where((t) => t.deletedAt.isNull())).get();
    for (final t in tasks) {
      final desc = t.description ?? '';
      if (desc.contains('app://ref/') || desc.contains('[[')) {
        await reindexLinksForSource(
          db,
          sourceType: 'task',
          sourceId: t.id,
          textFields: [desc],
          enqueueSync: enqueueSync,
        );
        processed++;
      }
    }

    return processed;
  }

  static Future<void> _enqueueSync(
    AppDatabase db,
    KnowledgeLinkEntry row,
    String operation, {
    Map<String, dynamic>? baseData,
  }) async {
    try {
      final now = DateTime.now().toUtc();
      final payloadMap = SyncTimestamp.normalizeMapDates(row.toJson());
      if (baseData != null) {
        payloadMap['_base'] = SyncTimestamp.normalizeMapDates(baseData);
      }
      await db
          .into(db.syncQueue)
          .insert(
            SyncQueueCompanion.insert(
              id: _uuid.v4(),
              entityType: 'knowledge_links',
              entityId: row.id,
              operation: operation,
              payload: jsonEncode(payloadMap),
              createdAt: now,
            ),
          );
    } catch (e, st) {
      AppLogger.error(
        'Erro ao enfileirar mutação de Backlink (${row.id})',
        e,
        st,
      );
    }
  }
}
