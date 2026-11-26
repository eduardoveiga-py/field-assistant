import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_logger.dart';
import '../../database/app_database.dart';
import '../../experiences/experience_manager.dart';
import '../../inbox/inbox_manager.dart';
import '../../knowledge/knowledge_manager.dart';
import '../../picture_bank/picture_entry_model.dart';
import '../../projects/project_manager.dart';
import '../../references/app_reference.dart';
import '../../research/research_manager.dart';
import '../../tasks/task_manager.dart';
import '../providers.dart';
import '../screens/picture_bank_screen.dart';
import 'bible_verse_popup_dialog.dart';
import 'knowledge_item_reader_dialog.dart';
import 'publication_reader_dialog.dart';

/// Despachante universal de referências cruzadas (`app://ref/...`) e links web (`https?://`).
/// Abre o leitor/visualizador popup correspondente por cima da tela atual e oferece
/// botão opcional "Ir para a aba" para saltar diretamente ao módulo de origem.
class AppReferenceViewer {
  AppReferenceViewer._();

  /// Tenta abrir uma URL a partir de qualquer contexto na árvore de widgets.
  /// Obtém `AppDatabase` e `AppNavigationNotifier` automaticamente quando há `ProviderScope`.
  static Future<void> openUrl(BuildContext context, String rawUrl) async {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return;

    if (AppReferenceHelper.isAppReferenceUrl(trimmed)) {
      ProviderContainer? container;
      try {
        container = ProviderScope.containerOf(context, listen: false);
      } catch (_) {
        container = null;
      }
      if (container == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Abra esta referência dentro do aplicativo para navegar até o item.',
              ),
            ),
          );
        }
        return;
      }
      final db = container.read(databaseProvider);
      await openAppReference(
        context,
        db: db,
        url: trimmed,
        container: container,
      );
      return;
    }

    try {
      final uri = Uri.parse(trimmed);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível abrir o link: $trimmed')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao abrir link: $e')));
      }
    }
  }

  /// Resolve e abre o popup Leitor / Visualizador correspondente a [url].
  static Future<void> openAppReference(
    BuildContext context, {
    required AppDatabase db,
    required String url,
    ProviderContainer? container,
  }) async {
    final parsed = AppReferenceHelper.parseUri(url);
    if (parsed == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Referência interna inválida: $url')),
        );
      }
      return;
    }

    VoidCallback? buildJumpCallback({String? focusId}) {
      if (container == null) return null;
      return () {
        Navigator.of(
          context,
          rootNavigator: false,
        ).popUntil((route) => route.isFirst);
        container
            .read(appNavigationProvider.notifier)
            .navigateTo(
              parsed.category.targetFeature,
              subTabIndex: parsed.category.subTabIndex,
              focusItemId: focusId ?? parsed.itemId,
            );
      };
    }

    switch (parsed.category) {
      case AppRefCategory.bible:
        await showBibleVersePopup(
          context,
          db: db,
          bookNumber: parsed.bookNumber ?? 1,
          chapter: parsed.chapter ?? 1,
          verseSpec: parsed.verseSpec,
        );
        return;

      case AppRefCategory.publication:
        await showPublicationReaderDialog(
          context,
          db: db,
          publicationId: parsed.itemId,
          initialChapterIndex: parsed.publicationChapterIndex,
        );
        return;

      case AppRefCategory.picture:
        final pics = await PictureBankManager.loadPictures(db);
        final found = pics.where((p) => p.id == parsed.itemId).firstOrNull;
        if (!context.mounted) return;
        if (found == null) {
          _showMissingNotice(context, 'Gravura');
          return;
        }
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PictureDetailViewerScreen(
              picture: found,
              onJumpToTab: buildJumpCallback(),
            ),
          ),
        );
        return;

      case AppRefCategory.note:
        final note =
            await (db.select(db.knowledgeNotes)..where(
                  (t) => t.id.equals(parsed.itemId) & t.deletedAt.isNull(),
                ))
                .getSingleOrNull();
        if (!context.mounted) return;
        if (note == null) {
          _showMissingNotice(context, 'Nota');
          return;
        }
        List<String> tags = [];
        try {
          tags = (jsonDecode(note.tags) as List)
              .map((e) => e.toString())
              .where((t) => !t.startsWith('research:'))
              .toList();
        } catch (e, st) {
          AppLogger.debug('Falha ao ler tags da nota referenciada: $e', st);
        }
        await showKnowledgeItemReader(
          context,
          title: note.title,
          content: note.content,
          category: note.category,
          itemType: 'Nota',
          updatedAt: note.updatedAt,
          tags: tags,
          allowHighlights: true,
          onContentUpdated: (newContent) async {
            await KnowledgeManager(db: db)
                .updateNote(note.id, content: newContent);
          },
          onJumpToTab: buildJumpCallback(),
        );
        return;

      case AppRefCategory.question:
        final q =
            await (db.select(db.knowledgeQuestions)..where(
                  (t) => t.id.equals(parsed.itemId) & t.deletedAt.isNull(),
                ))
                .getSingleOrNull();
        if (!context.mounted) return;
        if (q == null) {
          _showMissingNotice(context, 'Pergunta / Dúvida');
          return;
        }
        final hasAnswer = q.answer != null && q.answer!.trim().isNotEmpty;
        final displayContent = hasAnswer
            ? q.answer!
            : (q.context ?? 'Dúvida ainda sem resposta bíblica cadastrada.');
        await showKnowledgeItemReader(
          context,
          title: q.question,
          content: displayContent,
          category: q.category,
          itemType: 'Dúvida',
          subtitle: q.status == 'answered' ? 'Respondida' : 'Em Aberto',
          updatedAt: q.updatedAt,
          allowHighlights: true,
          onContentUpdated: (newContent) async {
            final km = KnowledgeManager(db: db);
            if (hasAnswer) {
              await km.updateQuestion(q.id, answer: newContent);
            } else {
              await km.updateQuestion(q.id, context: newContent);
            }
          },
          onJumpToTab: buildJumpCallback(),
        );
        return;

      case AppRefCategory.document:
        final doc =
            await (db.select(db.knowledgeDocuments)..where(
                  (t) => t.id.equals(parsed.itemId) & t.deletedAt.isNull(),
                ))
                .getSingleOrNull();
        if (!context.mounted) return;
        if (doc == null) {
          _showMissingNotice(context, 'Documento');
          return;
        }
        await showKnowledgeItemReader(
          context,
          title: doc.title,
          content: doc.description?.trim().isNotEmpty == true
              ? doc.description!
              : 'Arquivo: ${doc.fileName} (${doc.fileType})',
          category: doc.category,
          itemType: 'Documento',
          subtitle: doc.fileName,
          updatedAt: doc.updatedAt,
          allowHighlights: doc.description?.trim().isNotEmpty == true,
          onContentUpdated: doc.description?.trim().isNotEmpty == true
              ? (newDesc) async {
                  await KnowledgeManager(db: db)
                      .updateDocument(doc.id, description: newDesc);
                }
              : null,
          onJumpToTab: buildJumpCallback(),
        );
        return;

      case AppRefCategory.resource:
        final res =
            await (db.select(db.knowledgeResources)..where(
                  (t) => t.id.equals(parsed.itemId) & t.deletedAt.isNull(),
                ))
                .getSingleOrNull();
        if (!context.mounted) return;
        if (res == null) {
          _showMissingNotice(context, 'Recurso');
          return;
        }
        await showKnowledgeItemReader(
          context,
          title: res.title,
          content: res.description?.trim().isNotEmpty == true
              ? res.description!
              : (res.url ?? 'Recurso salvo na Base de Conhecimento.'),
          category: res.category,
          itemType: 'Recurso',
          url: res.url,
          updatedAt: res.updatedAt,
          allowHighlights: res.description?.trim().isNotEmpty == true,
          onContentUpdated: res.description?.trim().isNotEmpty == true
              ? (newDesc) async {
                  await KnowledgeManager(db: db)
                      .updateResource(res.id, description: newDesc);
                }
              : null,
          onJumpToTab: buildJumpCallback(),
        );
        return;

      case AppRefCategory.task:
        final task =
            await (db.select(db.tasks)..where(
                  (t) => t.id.equals(parsed.itemId) & t.deletedAt.isNull(),
                ))
                .getSingleOrNull();
        if (!context.mounted) return;
        if (task == null) {
          _showMissingNotice(context, 'Tarefa');
          return;
        }
        await showKnowledgeItemReader(
          context,
          title: task.title,
          content: task.description ?? '',
          category: task.category,
          itemType: 'Tarefa',
          subtitle: 'Prioridade: ${task.priority}',
          updatedAt: task.updatedAt,
          allowHighlights: true,
          onContentUpdated: (newDesc) async {
            await TaskManager(db: db).updateTask(task.id, description: newDesc);
          },
          onJumpToTab: buildJumpCallback(),
        );
        return;

      case AppRefCategory.project:
        final proj =
            await (db.select(db.projects)..where(
                  (t) => t.id.equals(parsed.itemId) & t.deletedAt.isNull(),
                ))
                .getSingleOrNull();
        if (!context.mounted) return;
        if (proj == null) {
          _showMissingNotice(context, 'Projeto');
          return;
        }
        final hasDesc = proj.description?.trim().isNotEmpty == true;
        final textBody = hasDesc
            ? proj.description!
            : (proj.objective ?? 'Sem descrição registrada.');
        await showKnowledgeItemReader(
          context,
          title: proj.name,
          content: textBody,
          category: proj.category,
          itemType: 'Projeto',
          subtitle: proj.objective,
          updatedAt: proj.updatedAt,
          allowHighlights: true,
          onContentUpdated: (newText) async {
            final pm = ProjectManager(db: db);
            if (hasDesc) {
              await pm.updateProject(proj.id, description: newText);
            } else {
              await pm.updateProject(proj.id, objective: newText);
            }
          },
          onJumpToTab: buildJumpCallback(),
        );
        return;

      case AppRefCategory.inbox:
        final entry =
            await (db.select(db.inboxEntries)..where(
                  (t) => t.id.equals(parsed.itemId) & t.deletedAt.isNull(),
                ))
                .getSingleOrNull();
        if (!context.mounted) return;
        if (entry == null) {
          _showMissingNotice(context, 'Captura do Inbox');
          return;
        }
        await showKnowledgeItemReader(
          context,
          title: entry.suggestedCategory ?? 'Captura Rápida',
          content: entry.content,
          category: entry.sourceType,
          itemType: 'Captura',
          updatedAt: entry.updatedAt,
          allowHighlights: true,
          onContentUpdated: (newText) async {
            await InboxManager(db: db).updateEntry(entry.id, content: newText);
          },
          onJumpToTab: buildJumpCallback(),
        );
        return;

      case AppRefCategory.email:
        final mailEntry =
            await (db.select(db.inboxEntries)..where(
                  (t) => t.id.equals(parsed.itemId) & t.deletedAt.isNull(),
                ))
                .getSingleOrNull();
        if (!context.mounted) return;
        if (mailEntry == null) {
          _showMissingNotice(context, 'E-mail');
          return;
        }
        var subject = 'Mensagem do JW Mail';
        var from = '';
        var body = mailEntry.content;
        try {
          final meta = jsonDecode(mailEntry.metadata);
          if (meta is Map && meta['email'] is Map) {
            final em = meta['email'] as Map;
            subject = em['subject']?.toString().trim().isNotEmpty == true
                ? em['subject'].toString()
                : subject;
            from = em['from']?.toString() ?? '';
            body = em['bodyText']?.toString() ?? body;
          }
        } catch (_) {}
        // E-mails ficam explicitamente excluídos de sublinhados JW (allowHighlights: false).
        await showKnowledgeItemReader(
          context,
          title: subject,
          content: body,
          category: 'JW Mail',
          itemType: 'E-mail',
          subtitle: from.isNotEmpty ? 'De: $from' : null,
          updatedAt: mailEntry.updatedAt,
          allowHighlights: false,
          onJumpToTab: buildJumpCallback(),
        );
        return;

      case AppRefCategory.research:
        final art =
            await (db.select(db.researchArticles)..where(
                  (t) => t.id.equals(parsed.itemId) & t.deletedAt.isNull(),
                ))
                .getSingleOrNull();
        if (!context.mounted) return;
        if (art == null) {
          _showMissingNotice(context, 'Pesquisa');
          return;
        }
        final item = ResearchArticleItem.fromEntry(art);
        await showKnowledgeItemReader(
          context,
          title: item.title,
          content: item.content,
          category: 'Pesquisa',
          itemType: 'Pesquisa',
          subtitle: item.summary,
          tags: item.tags,
          updatedAt: item.updatedAt,
          allowHighlights: true,
          onContentUpdated: (newText) async {
            final mgr = ResearchManager(db);
            await mgr.updateArticle(
              ResearchArticleItem(
                id: item.id,
                title: item.title,
                summary: item.summary,
                content: newText,
                tags: item.tags,
                attachments: item.attachments,
                createdAt: item.createdAt,
                updatedAt: DateTime.now(),
              ),
            );
          },
          onJumpToTab: buildJumpCallback(),
        );
        return;

      case AppRefCategory.experience:
        final expRow =
            await (db.select(db.ministryExperiences)..where(
                  (t) => t.id.equals(parsed.itemId) & t.deletedAt.isNull(),
                ))
                .getSingleOrNull();
        if (!context.mounted) return;
        if (expRow == null) {
          _showMissingNotice(context, 'Experiência');
          return;
        }
        final exp = MinistryExperienceItem.fromEntry(expRow);
        await showKnowledgeItemReader(
          context,
          title: exp.title,
          content: exp.content,
          category: exp.locationOrModality ?? 'Ministério',
          itemType: 'Experiência',
          tags: exp.tags,
          updatedAt: exp.dateTime,
          allowHighlights: true,
          onContentUpdated: (newText) async {
            final mgr = ExperienceManager(db);
            await mgr.updateExperience(
              MinistryExperienceItem(
                id: exp.id,
                title: exp.title,
                content: newText,
                mediaUrls: exp.mediaUrls,
                tags: exp.tags,
                dateTime: exp.dateTime,
                locationOrModality: exp.locationOrModality,
                createdAt: exp.createdAt,
                updatedAt: DateTime.now(),
              ),
            );
          },
          onJumpToTab: buildJumpCallback(),
        );
        return;

      case AppRefCategory.person:
        final person =
            await (db.select(db.people)..where(
                  (t) => t.id.equals(parsed.itemId) & t.deletedAt.isNull(),
                ))
                .getSingleOrNull();
        if (!context.mounted) return;
        if (person == null) {
          _showMissingNotice(context, 'Pessoa / Contato');
          return;
        }
        // Estudos/revisitas/pessoas ficam explicitamente excluídos de sublinhados JW.
        await showKnowledgeItemReader(
          context,
          title: person.name,
          content: person.generalNotes?.trim().isNotEmpty == true
              ? person.generalNotes!
              : 'Status: ${person.status}${person.address != null ? '\nEndereço: ${person.address}' : ''}',
          category: person.status,
          itemType: 'Pessoa',
          subtitle: person.phone ?? person.address,
          updatedAt: person.updatedAt,
          allowHighlights: false,
          onJumpToTab: buildJumpCallback(),
        );
        return;

      case AppRefCategory.study:
        final study =
            await (db.select(db.bibleStudies)..where(
                  (t) => t.id.equals(parsed.itemId) & t.deletedAt.isNull(),
                ))
                .getSingleOrNull();
        if (!context.mounted) return;
        if (study == null) {
          _showMissingNotice(context, 'Estudo Bíblico');
          return;
        }
        final buf = StringBuffer()
          ..writeln('Status: ${study.status}')
          ..writeln('Publicação: ${study.publicationId}')
          ..writeln(
            'Lição atual: ${study.currentLesson ?? '-'} • Ponto: ${study.currentParagraph ?? '-'}',
          );
        if (study.nextTopic?.isNotEmpty == true) {
          buf.writeln('Próximo assunto: ${study.nextTopic}');
        }
        if (study.learningGoals?.isNotEmpty == true) {
          buf.writeln('Alvos: ${study.learningGoals}');
        }
        // Gerenciamento de estudos fica explicitamente excluído de sublinhados JW.
        await showKnowledgeItemReader(
          context,
          title: study.title,
          content: buf.toString().trim(),
          category: study.frequency,
          itemType: 'Estudo',
          updatedAt: study.updatedAt,
          allowHighlights: false,
          onJumpToTab: buildJumpCallback(),
        );
        return;
    }
  }

  static void _showMissingNotice(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$label referenciado não foi encontrado ou foi excluído.',
        ),
      ),
    );
  }
}
