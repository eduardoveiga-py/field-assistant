import 'dart:convert';

import 'package:drift/drift.dart' as drift;

import '../bible/nwt_bible_books.dart';
import '../core/app_logger.dart';
import '../core/feature_registry.dart';
import '../database/app_database.dart';
import '../inbox/email_html_sanitizer.dart';
import '../picture_bank/picture_entry_model.dart';

/// Categorias suportadas pelas referências cruzadas em todo o aplicativo.
enum AppRefCategory {
  bible(
    typeId: 'bible',
    label: 'Bíblia (Tradução do Novo Mundo)',
    shortLabel: 'TNM',
    emoji: '📖',
    targetFeature: AppFeature.knowledge,
  ),
  note(
    typeId: 'note',
    label: 'Base de Conhecimento — Notas',
    shortLabel: 'Nota',
    emoji: '📝',
    targetFeature: AppFeature.knowledge,
    subTabIndex: 0,
  ),
  question(
    typeId: 'question',
    label: 'Base de Conhecimento — Perguntas & Dúvidas',
    shortLabel: 'Dúvida',
    emoji: '❓',
    targetFeature: AppFeature.knowledge,
    subTabIndex: 1,
  ),
  document(
    typeId: 'document',
    label: 'Base de Conhecimento — Documentos',
    shortLabel: 'Documento',
    emoji: '📄',
    targetFeature: AppFeature.knowledge,
    subTabIndex: 2,
  ),
  resource(
    typeId: 'resource',
    label: 'Base de Conhecimento — Recursos',
    shortLabel: 'Recurso',
    emoji: '🔗',
    targetFeature: AppFeature.knowledge,
    subTabIndex: 3,
  ),
  picture(
    typeId: 'picture',
    label: 'Banco de Gravuras / Imagens',
    shortLabel: 'Gravura',
    emoji: '🖼️',
    targetFeature: AppFeature.pictureBank,
  ),
  task(
    typeId: 'task',
    label: 'Tarefas',
    shortLabel: 'Tarefa',
    emoji: '☑️',
    targetFeature: AppFeature.tasksProjects,
    subTabIndex: 0,
  ),
  project(
    typeId: 'project',
    label: 'Projetos',
    shortLabel: 'Projeto',
    emoji: '📁',
    targetFeature: AppFeature.tasksProjects,
    subTabIndex: 4,
  ),
  inbox(
    typeId: 'inbox',
    label: 'Inbox — Capturas',
    shortLabel: 'Captura',
    emoji: '📥',
    targetFeature: AppFeature.inbox,
    subTabIndex: 0,
  ),
  email(
    typeId: 'email',
    label: 'JW Mail — E-mails',
    shortLabel: 'E-mail',
    emoji: '✉️',
    targetFeature: AppFeature.inbox,
    subTabIndex: 1,
  ),
  research(
    typeId: 'research',
    label: 'Pesquisas',
    shortLabel: 'Pesquisa',
    emoji: '🔎',
    targetFeature: AppFeature.notesResearch,
  ),
  experience(
    typeId: 'experience',
    label: 'Experiências de Campo',
    shortLabel: 'Experiência',
    emoji: '✨',
    targetFeature: AppFeature.experiences,
  ),
  person(
    typeId: 'person',
    label: 'Pessoas & Contatos',
    shortLabel: 'Pessoa',
    emoji: '👤',
    targetFeature: AppFeature.people,
  ),
  study(
    typeId: 'study',
    label: 'Estudos Bíblicos',
    shortLabel: 'Estudo',
    emoji: '🎓',
    targetFeature: AppFeature.studies,
  );

  final String typeId;
  final String label;
  final String shortLabel;
  final String emoji;
  final AppFeature targetFeature;
  final int? subTabIndex;

  const AppRefCategory({
    required this.typeId,
    required this.label,
    required this.shortLabel,
    required this.emoji,
    required this.targetFeature,
    this.subTabIndex,
  });

  static AppRefCategory? fromTypeId(String? typeId) {
    if (typeId == null) return null;
    for (final c in AppRefCategory.values) {
      if (c.typeId == typeId) return c;
    }
    return null;
  }
}

/// Referência interna parsed de uma URI `app://ref/...`.
class ParsedAppReference {
  final AppRefCategory category;
  final String itemId;
  final int? bookNumber;
  final int? chapter;
  final String? verseSpec;

  const ParsedAppReference({
    required this.category,
    required this.itemId,
    this.bookNumber,
    this.chapter,
    this.verseSpec,
  });
}

/// Item selecionável exibido no menu suspenso/seletor de referências.
class AppReferenceCandidate {
  final AppRefCategory category;
  final String id;
  final String title;
  final String subtitle;
  final String? previewImageData;

  const AppReferenceCandidate({
    required this.category,
    required this.id,
    required this.title,
    this.subtitle = '',
    this.previewImageData,
  });

  String buildUri() => AppReferenceHelper.buildUri(category, id);

  String buildMarkdownLink() =>
      AppReferenceHelper.buildMarkdownLink(category, id, title);
}

/// Utilitário puro para construção, parsing e carregamento de catálogo de referências.
class AppReferenceHelper {
  AppReferenceHelper._();

  static const String schemePrefix = 'app://ref/';

  static bool isAppReferenceUrl(String url) =>
      url.trim().startsWith(schemePrefix);

  static String buildUri(AppRefCategory category, String id) {
    final encodedId = Uri.encodeComponent(id);
    return '$schemePrefix${category.typeId}/$encodedId';
  }

  static String buildBibleUri({
    required int bookNumber,
    required int chapter,
    String? verseSpec,
  }) {
    final cleanSpec = verseSpec?.trim() ?? '';
    if (cleanSpec.isEmpty) {
      return '${schemePrefix}bible/$bookNumber/$chapter';
    }
    return '${schemePrefix}bible/$bookNumber/$chapter/${Uri.encodeComponent(cleanSpec)}';
  }

  /// Escapa colchetes, marcações HTML/Markdown e quebras de linha no rótulo
  /// para não quebrar sintaxe `[Label](url)` nem vazar tags cruas.
  static String sanitizeLabel(String raw) {
    final cleaned = EmailHtmlSanitizer.stripMarkdown(raw);
    return cleaned
        .replaceAll('\r', ' ')
        .replaceAll('\n', ' ')
        .replaceAll('[', '(')
        .replaceAll(']', ')')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String buildMarkdownLink(
    AppRefCategory category,
    String id,
    String title,
  ) {
    final safeTitle = sanitizeLabel(
      title.isEmpty ? category.shortLabel : title,
    );
    return '[${category.emoji} $safeTitle](${buildUri(category, id)})';
  }

  static String buildBibleMarkdownLink({
    required int bookNumber,
    required int chapter,
    String? verseSpec,
  }) {
    final label = NwtBibleBooks.formatReferenceLabel(
      bookNumber: bookNumber,
      chapter: chapter,
      verseSpec: verseSpec,
    );
    final uri = buildBibleUri(
      bookNumber: bookNumber,
      chapter: chapter,
      verseSpec: verseSpec,
    );
    return '[📖 $label (TNM)]($uri)';
  }

  /// Interpreta `app://ref/<type>/<id>` ou `app://ref/bible/<book>/<chapter>/<verses>`.
  static ParsedAppReference? parseUri(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (!trimmed.startsWith(schemePrefix)) return null;
    final rest = trimmed.substring(schemePrefix.length);
    final parts = rest.split('/');
    if (parts.isEmpty) return null;

    final cat = AppRefCategory.fromTypeId(parts[0]);
    if (cat == null) return null;

    if (cat == AppRefCategory.bible) {
      if (parts.length < 3) return null;
      final bookNum = int.tryParse(parts[1]);
      final chapter = int.tryParse(parts[2]);
      if (bookNum == null || chapter == null) return null;
      final verseSpec = parts.length >= 4 && parts[3].isNotEmpty
          ? Uri.decodeComponent(parts.sublist(3).join('/'))
          : null;
      return ParsedAppReference(
        category: cat,
        itemId: '$bookNum:$chapter${verseSpec != null ? ':$verseSpec' : ''}',
        bookNumber: bookNum,
        chapter: chapter,
        verseSpec: verseSpec,
      );
    }

    if (parts.length < 2 || parts[1].isEmpty) return null;
    final id = Uri.decodeComponent(parts.sublist(1).join('/'));
    return ParsedAppReference(category: cat, itemId: id);
  }

  /// Carrega os itens disponíveis de uma [category] no banco Drift para o menu seletor.
  static Future<List<AppReferenceCandidate>> loadCandidates(
    AppDatabase db,
    AppRefCategory category,
  ) async {
    switch (category) {
      case AppRefCategory.bible:
        return const [];
      case AppRefCategory.note:
        final rows =
            await (db.select(db.knowledgeNotes)
                  ..where((t) => t.deletedAt.isNull())
                  ..orderBy([(t) => drift.OrderingTerm.desc(t.updatedAt)]))
                .get();
        return rows
            .map(
              (r) => AppReferenceCandidate(
                category: category,
                id: r.id,
                title: r.title,
                subtitle: 'Nota • ${r.category}',
              ),
            )
            .toList();
      case AppRefCategory.question:
        final rows =
            await (db.select(db.knowledgeQuestions)
                  ..where((t) => t.deletedAt.isNull())
                  ..orderBy([(t) => drift.OrderingTerm.desc(t.updatedAt)]))
                .get();
        return rows
            .map(
              (r) => AppReferenceCandidate(
                category: category,
                id: r.id,
                title: r.question,
                subtitle: r.status == 'answered' ? 'Respondida' : 'Em aberto',
              ),
            )
            .toList();
      case AppRefCategory.document:
        final rows =
            await (db.select(db.knowledgeDocuments)
                  ..where((t) => t.deletedAt.isNull())
                  ..orderBy([(t) => drift.OrderingTerm.desc(t.createdAt)]))
                .get();
        return rows
            .map(
              (r) => AppReferenceCandidate(
                category: category,
                id: r.id,
                title: r.title,
                subtitle: '${r.fileName} (${r.fileType})',
              ),
            )
            .toList();
      case AppRefCategory.resource:
        final rows =
            await (db.select(db.knowledgeResources)
                  ..where((t) => t.deletedAt.isNull())
                  ..orderBy([(t) => drift.OrderingTerm.desc(t.updatedAt)]))
                .get();
        return rows
            .map(
              (r) => AppReferenceCandidate(
                category: category,
                id: r.id,
                title: r.title,
                subtitle: r.url ?? r.resourceType,
              ),
            )
            .toList();
      case AppRefCategory.picture:
        final pics = await PictureBankManager.loadPictures(db);
        return pics
            .map(
              (p) => AppReferenceCandidate(
                category: category,
                id: p.id,
                title: p.caption,
                subtitle: p.tags.isNotEmpty
                    ? p.tags.map((t) => '#$t').join(' ')
                    : (p.category ?? 'Gravura'),
                previewImageData: p.imageData,
              ),
            )
            .toList();
      case AppRefCategory.task:
        final rows =
            await (db.select(db.tasks)
                  ..where((t) => t.deletedAt.isNull())
                  ..orderBy([(t) => drift.OrderingTerm.desc(t.updatedAt)]))
                .get();
        return rows
            .map(
              (r) => AppReferenceCandidate(
                category: category,
                id: r.id,
                title: r.title,
                subtitle: r.status == 'completed' ? 'Concluída' : 'Tarefa',
              ),
            )
            .toList();
      case AppRefCategory.project:
        final rows =
            await (db.select(db.projects)
                  ..where((t) => t.deletedAt.isNull())
                  ..orderBy([(t) => drift.OrderingTerm.desc(t.updatedAt)]))
                .get();
        return rows
            .map(
              (r) => AppReferenceCandidate(
                category: category,
                id: r.id,
                title: r.name,
                subtitle: r.objective ?? r.category,
              ),
            )
            .toList();
      case AppRefCategory.inbox:
        final rows =
            await (db.select(db.inboxEntries)
                  ..where(
                    (t) =>
                        t.deletedAt.isNull() &
                        t.sourceType.equals('email').not(),
                  )
                  ..orderBy([(t) => drift.OrderingTerm.desc(t.capturedAt)]))
                .get();
        return rows.map((r) {
          final firstLine = r.content
              .split('\n')
              .firstWhere((l) => l.trim().isNotEmpty, orElse: () => 'Captura');
          return AppReferenceCandidate(
            category: category,
            id: r.id,
            title: firstLine.trim(),
            subtitle: r.suggestedCategory ?? r.sourceType,
          );
        }).toList();
      case AppRefCategory.email:
        final rows =
            await (db.select(db.inboxEntries)
                  ..where(
                    (t) => t.deletedAt.isNull() & t.sourceType.equals('email'),
                  )
                  ..orderBy([(t) => drift.OrderingTerm.desc(t.capturedAt)]))
                .get();
        return rows.map((r) {
          String subject = 'E-mail';
          String from = '';
          try {
            final meta = jsonDecode(r.metadata);
            if (meta is Map && meta['email'] is Map) {
              subject =
                  meta['email']['subject']?.toString().trim().isNotEmpty == true
                  ? meta['email']['subject'].toString().trim()
                  : subject;
              from = meta['email']['from']?.toString() ?? '';
            }
          } catch (e, st) {
            AppLogger.debug(
              'Metadados de e-mail inválidos ao listar referências (${r.id}): $e',
              st,
            );
          }
          return AppReferenceCandidate(
            category: category,
            id: r.id,
            title: subject,
            subtitle: from,
          );
        }).toList();
      case AppRefCategory.research:
        final rows =
            await (db.select(db.researchArticles)
                  ..where((t) => t.deletedAt.isNull())
                  ..orderBy([(t) => drift.OrderingTerm.desc(t.updatedAt)]))
                .get();
        return rows
            .map(
              (r) => AppReferenceCandidate(
                category: category,
                id: r.id,
                title: r.title,
                subtitle: r.summary,
              ),
            )
            .toList();
      case AppRefCategory.experience:
        final rows =
            await (db.select(db.ministryExperiences)
                  ..where((t) => t.deletedAt.isNull())
                  ..orderBy([(t) => drift.OrderingTerm.desc(t.dateTimeField)]))
                .get();
        return rows
            .map(
              (r) => AppReferenceCandidate(
                category: category,
                id: r.id,
                title: r.title,
                subtitle: r.locationOrModality ?? 'Experiência',
              ),
            )
            .toList();
      case AppRefCategory.person:
        final rows =
            await (db.select(db.people)
                  ..where((t) => t.deletedAt.isNull())
                  ..orderBy([(t) => drift.OrderingTerm.asc(t.name)]))
                .get();
        return rows
            .map(
              (r) => AppReferenceCandidate(
                category: category,
                id: r.id,
                title: r.name,
                subtitle: r.address ?? r.status,
              ),
            )
            .toList();
      case AppRefCategory.study:
        final rows =
            await (db.select(db.bibleStudies)
                  ..where((t) => t.deletedAt.isNull())
                  ..orderBy([(t) => drift.OrderingTerm.desc(t.updatedAt)]))
                .get();
        return rows
            .map(
              (r) => AppReferenceCandidate(
                category: category,
                id: r.id,
                title: r.title,
                subtitle: r.currentLesson != null
                    ? 'Lição ${r.currentLesson}'
                    : r.status,
              ),
            )
            .toList();
    }
  }
}
