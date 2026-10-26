import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_theme.dart';
import '../../database/app_database.dart';
import '../../publications/publication_catalog.dart';
import '../../publications/publication_link_resolver.dart';
import '../providers.dart';

class StudiesScreen extends ConsumerStatefulWidget {
  const StudiesScreen({super.key});

  @override
  ConsumerState<StudiesScreen> createState() => _StudiesScreenState();
}

class _StudiesScreenState extends ConsumerState<StudiesScreen> {
  // Modal para abrir publicação via PublicationLinkResolver
  void _openPublicationLink(BuildContext context, BibleStudyEntry study) {
    final resolved = PublicationLinkResolver.resolve(
      publicationId: study.publicationId,
      languageCode: study.language,
      lesson: study.currentLesson,
      paragraph: study.currentParagraph,
      manualReference: study.manualReference,
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.menu_book, color: AppTheme.primaryBlue),
            const SizedBox(width: 8),
            const Expanded(child: Text('Acesso à Publicação')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              resolved.displayText,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 10),
            if (resolved.note != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  resolved.note!,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF1E3A8A)),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (resolved.url != null) ...[
              Text(
                'Link Oficial Verificado:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 4),
              SelectableText(
                resolved.url!,
                style: const TextStyle(fontSize: 12, color: AppTheme.accentTeal),
              ),
            ],
          ],
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copiar'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: resolved.url ?? resolved.displayText));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Referência copiada para a área de transferência!')),
              );
            },
          ),
          if (resolved.url != null)
            ElevatedButton.icon(
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Abrir'),
              onPressed: () async {
                final uri = Uri.parse(resolved.url!);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else if (resolved.fallbackUrl != null) {
                  await launchUrl(Uri.parse(resolved.fallbackUrl!), mode: LaunchMode.externalApplication);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
        ],
      ),
    );
  }

  // Modal para registrar ocorrência de sessão de estudo
  void _showRecordSessionDialog(BuildContext context, BibleStudyEntry study) {
    final lessonController = TextEditingController(text: study.currentLesson?.toString() ?? '');
    final paragraphsController = TextEditingController(text: study.currentParagraph?.toString() ?? '');
    final notesController = TextEditingController();
    final nextStepController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Registrar Sessão: ${study.title}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: lessonController,
                      decoration: const InputDecoration(labelText: 'Lição estudada'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: paragraphsController,
                      decoration: const InputDecoration(labelText: 'Parágrafos'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Observações da sessão',
                  hintText: 'Dúvidas esclarecidas, pontos de interesse...',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nextStepController,
                decoration: const InputDecoration(
                  labelText: 'Próximo assunto',
                  hintText: 'Ex: Parágrafo 5 em diante',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final lesson = int.tryParse(lessonController.text.trim());
              final repo = ref.read(repositoryProvider);

              await repo.createStudySession(
                studyId: study.id,
                dateTime: DateTime.now(),
                lessonCovered: lesson,
                paragraphsCovered: paragraphsController.text.trim().isEmpty ? null : paragraphsController.text.trim(),
                sessionNotes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                nextStep: nextStepController.text.trim().isEmpty ? null : nextStepController.text.trim(),
                status: 'realizada',
              );

              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sessão registrada com sucesso! Progresso atualizado.')),
                );
              }
            },
            child: const Text('Salvar Sessão'),
          ),
        ],
      ),
    );
  }

  // Modal para criar novo estudo bíblico
  void _showNewStudyDialog(BuildContext context) {
    final titleController = TextEditingController();
    String selectedPublicationId = 'lff-book';
    String selectedLanguage = 'pt';
    final List<String> selectedPeopleIds = [];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final people = ref.read(peopleStreamProvider).value ?? [];

          return AlertDialog(
            title: const Text('Novo Estudo Bíblico'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Identificação / Título do estudo *',
                      hintText: 'Ex: Estudo da Família Lima',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedPublicationId,
                    decoration: const InputDecoration(labelText: 'Publicação'),
                    items: PublicationCatalog.allPublications.map((p) {
                      return DropdownMenuItem(value: p.id, child: Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedPublicationId = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedLanguage,
                    decoration: const InputDecoration(labelText: 'Idioma do estudo'),
                    items: const [
                      DropdownMenuItem(value: 'pt', child: Text('Português')),
                      DropdownMenuItem(value: 'bzs', child: Text('Libras (Língua de Sinais)')),
                      DropdownMenuItem(value: 'tca', child: Text('Ticuna')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedLanguage = val);
                    },
                  ),
                  const SizedBox(height: 14),
                  const Text('Participantes:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  if (people.isEmpty)
                    const Text('Cadastre pessoas na aba Contatos para vinculá-las ao estudo.')
                  else
                    Wrap(
                      spacing: 8,
                      children: people.map((p) {
                        final isSelected = selectedPeopleIds.contains(p.id);
                        return FilterChip(
                          label: Text(p.name),
                          selected: isSelected,
                          onSelected: (selected) {
                            setDialogState(() {
                              if (selected) {
                                selectedPeopleIds.add(p.id);
                                if (titleController.text.isEmpty) {
                                  titleController.text = 'Estudo de ${p.name}';
                                }
                              } else {
                                selectedPeopleIds.remove(p.id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () async {
                  final title = titleController.text.trim();
                  if (title.isEmpty || selectedPeopleIds.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Informe o título e selecione pelo menos um participante.')),
                    );
                    return;
                  }

                  final repo = ref.read(repositoryProvider);
                  await repo.createStudy(
                    title: title,
                    publicationId: selectedPublicationId,
                    language: selectedLanguage,
                    currentLesson: 1,
                    participantPersonIds: selectedPeopleIds,
                  );

                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Cadastrar Estudo'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final studiesAsync = ref.watch(studiesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estudos Bíblicos'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Novo Estudo'),
        onPressed: () => _showNewStudyDialog(context),
      ),
      body: studiesAsync.when(
        data: (studies) {
          if (studies.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.menu_book, size: 56, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    const Text(
                      'Nenhum estudo bíblico cadastrado ainda.\nToque em "+ Novo Estudo" para registrar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 15),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: studies.length,
            itemBuilder: (context, index) {
              final study = studies[index];
              final pub = PublicationCatalog.getById(study.publicationId);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              study.title,
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: study.status == 'ativo'
                                  ? AppTheme.successGreen.withValues(alpha: 0.1)
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              study.status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: study.status == 'ativo' ? AppTheme.successGreen : Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        pub?.title ?? study.publicationId,
                        style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                const Text('Lição Atual', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                Text(
                                  study.currentLesson != null ? 'Lição ${study.currentLesson}' : 'Não iniciada',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                const Text('Parágrafo', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                Text(
                                  study.currentParagraph != null ? '§ ${study.currentParagraph}' : '—',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                const Text('Idioma', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                Text(
                                  study.language.toUpperCase(),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.open_in_new, size: 16),
                              label: const Text('Abrir JW.org'),
                              onPressed: () => _openPublicationLink(context, study),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.playlist_add_check, size: 16),
                              label: const Text('Sessão'),
                              onPressed: () => _showRecordSessionDialog(context, study),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erro: $err')),
      ),
    );
  }
}
