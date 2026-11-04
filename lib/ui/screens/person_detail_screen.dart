import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../core/date_utils.dart';
import '../../core/feature_registry.dart';
import '../../database/app_database.dart';
import '../../database/repository.dart';
import '../providers.dart';
import '../widgets/person_edit_dialog.dart';
import '../widgets/person_family_ties_tab.dart';
import '../widgets/person_note_and_target_dialogs.dart';
import '../widgets/person_photos_tab.dart';
import '../widgets/person_publications_tab.dart';
import '../widgets/person_study_tab.dart';
import '../widgets/person_visits_tab.dart';

class PersonDetailScreen extends ConsumerStatefulWidget {
  final String personId;

  const PersonDetailScreen({super.key, required this.personId});

  @override
  ConsumerState<PersonDetailScreen> createState() => _PersonDetailScreenState();
}

class _PersonDetailScreenState extends ConsumerState<PersonDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repositoryProvider);
    final people = ref.watch(peopleStreamProvider).value ?? [];
    final studies = ref.watch(studiesStreamProvider).value ?? [];
    final participants = ref.watch(studyParticipantsStreamProvider).value ?? [];

    final person = people.where((p) => p.id == widget.personId).firstOrNull;

    if (person == null) {
      return FutureBuilder<PersonEntry?>(
        future: repo.getPersonById(widget.personId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final fallbackPerson = snapshot.data!;
          return _buildMainScaffold(
            context,
            repo,
            fallbackPerson,
            studies,
            participants,
          );
        },
      );
    }

    return _buildMainScaffold(context, repo, person, studies, participants);
  }

  Widget _buildMainScaffold(
    BuildContext context,
    AppRepository repo,
    PersonEntry person,
    List<BibleStudyEntry> studies,
    List<StudyParticipantEntry> participants,
  ) {
    // Localiza estudo bíblico vinculado a esta pessoa
    final linkedParticipant = participants
        .where((p) => p.personId == person.id && p.deletedAt == null)
        .firstOrNull;
    final linkedStudy = linkedParticipant != null
        ? studies
              .where(
                (s) => s.id == linkedParticipant.studyId && s.deletedAt == null,
              )
              .firstOrNull
        : null;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isStudiesEnabled = ref.watch(
      isFeatureEnabledProvider(AppFeature.studies),
    );
    final isAgendaEnabled = ref.watch(
      isFeatureEnabledProvider(AppFeature.agenda),
    );

    final tabs = <Widget>[
      const Tab(
        icon: Icon(Icons.history_edu),
        text: 'Visitas & Linha do Tempo',
      ),
      if (isStudiesEnabled)
        const Tab(icon: Icon(Icons.school), text: 'Estudo Bíblico'),
      const Tab(icon: Icon(Icons.photo_library), text: 'Fotos'),
      const Tab(icon: Icon(Icons.auto_stories), text: 'Publicações & Pedidos'),
      const Tab(icon: Icon(Icons.family_restroom), text: 'Família & Vínculos'),
      const Tab(
        icon: Icon(Icons.note_alt_outlined),
        text: 'Necessidades & Obs.',
      ),
      const Tab(icon: Icon(Icons.track_changes), text: 'Alvos & Tarefas'),
    ];

    final tabViews = <Widget>[
      // TAB 1: VISITAS & CONTATO
      PersonVisitsTab(
        person: person,
        linkedStudy: isStudiesEnabled ? linkedStudy : null,
        isDark: isDark,
        isStudiesEnabled: isStudiesEnabled,
        isAgendaEnabled: isAgendaEnabled,
      ),

      // TAB 2: ESTUDO BÍBLICO (Progresso, Publicações, JW Library e Sessões)
      if (isStudiesEnabled)
        PersonStudyTab(
          person: person,
          linkedStudy: linkedStudy,
          isDark: isDark,
        ),

      // TAB 3: FOTOS DA PESSOA / RESIDÊNCIA / ESTUDO
      PersonPhotosTab(person: person),

      // TAB 4: PUBLICAÇÕES & PEDIDOS (Checklist e Pedidos)
      PersonPublicationsTab(person: person),

      // TAB 5: FAMÍLIA & VÍNCULOS (Relacionamentos bidirecionais automáticos)
      PersonFamilyTiesTab(person: person),

      // TAB 6: NECESSIDADES & OBSERVAÇÕES
      _buildNeedsAndNotesTab(context, repo, person, isDark),

      // TAB 7: ALVOS & TAREFAS
      _buildTargetsAndTasksTab(context, repo, person, isDark),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(person.name),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Editar Dados do Contato',
              onPressed: () => PersonEditDialog.show(
                context,
                person: person,
              ),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: AppTheme.primaryBlue,
            tabs: tabs,
          ),
        ),
        body: TabBarView(children: tabViews),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ABA 3: NECESSIDADES & OBSERVAÇÕES
  // ---------------------------------------------------------------------------

  Widget _buildNeedsAndNotesTab(
    BuildContext context,
    AppRepository repo,
    PersonEntry person,
    bool isDark,
  ) {
    final notes = PersonNotesAndTargetsHelper.parseNotes(person.generalNotes);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Necessidades & Observações',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${notes.length} ${notes.length == 1 ? "registro com data e hora" : "registros com data e hora"}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentTeal,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('+ Nova Observação'),
                onPressed: () => PersonNoteDialog.show(
                  context: context,
                  repo: repo,
                  person: person,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (notes.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.note_alt_outlined,
                        size: 56,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Nenhuma necessidade ou observação registrada para ${person.name}.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Toque no botão "+ Nova Observação" para registrar circunstâncias familiares, pontos de interesse ou dúvidas bíblicas.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentTeal,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('+ Registrar Primeira Observação'),
                        onPressed: () => PersonNoteDialog.show(
                          context: context,
                          repo: repo,
                          person: person,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Column(
              children: notes.map((note) {
                final createdAt = DateTime.tryParse(note['createdAt'] ?? '');
                final updatedAt = note['updatedAt'] != null
                    ? DateTime.tryParse(note['updatedAt'])
                    : null;
                final text = note['text'] ?? '';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today,
                                  size: 14,
                                  color: AppTheme.accentTeal,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  AppDateUtils.formatDateTimeWithAt(createdAt),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: AppTheme.accentTeal,
                                  ),
                                ),
                                if (updatedAt != null) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    '(editado)',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade500,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                  ),
                                  tooltip: 'Editar',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => PersonNoteDialog.show(
                                    context: context,
                                    repo: repo,
                                    person: person,
                                    noteToEdit: note,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: AppTheme.alertRed,
                                  ),
                                  tooltip: 'Excluir',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (c) => AlertDialog(
                                        title: const Text('Excluir Observação'),
                                        content: const Text(
                                          'Tem certeza que deseja excluir esta anotação?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(c, false),
                                            child: const Text('Cancelar'),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  AppTheme.alertRed,
                                              foregroundColor: Colors.white,
                                            ),
                                            onPressed: () =>
                                                Navigator.pop(c, true),
                                            child: const Text('Excluir'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      final updated = notes
                                          .where((n) => n['id'] != note['id'])
                                          .toList();
                                      await PersonNotesAndTargetsHelper.saveNotes(
                                        repo,
                                        person,
                                        updated,
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Divider(height: 12),
                        SelectableText(
                          text,
                          style: const TextStyle(fontSize: 14, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ABA 4: ALVOS & TAREFAS ESPIRITUAIS
  // ---------------------------------------------------------------------------

  Widget _buildTargetsAndTasksTab(
    BuildContext context,
    AppRepository repo,
    PersonEntry person,
    bool isDark,
  ) {
    final targets = PersonNotesAndTargetsHelper.parseTargets(
      person.contactRestrictions,
    );
    final completedCount = targets
        .where((t) => t['isCompleted'] == true)
        .length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Alvos & Tarefas Espirituais',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$completedCount de ${targets.length} concluído(s)',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.add_task, size: 18),
                label: const Text('+ Novo Alvo'),
                onPressed: () => PersonTargetDialog.show(
                  context: context,
                  repo: repo,
                  person: person,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (targets.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.track_changes,
                        size: 56,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Nenhum alvo ou tarefa espiritual definido para ${person.name}.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Defina alvos espirituais para a pessoa cumprir até a próxima visita (ex: ler um capítulo da Bíblia, baixar o JW Library, assistir ao vídeo da lição).',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7C3AED),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('+ Cadastrar Primeiro Alvo'),
                        onPressed: () => PersonTargetDialog.show(
                          context: context,
                          repo: repo,
                          person: person,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Column(
              children: targets.asMap().entries.map((entry) {
                final idx = entry.key;
                final target = entry.value;
                final isCompleted = target['isCompleted'] == true;
                final title = target['title'] ?? '';
                final createdAt = DateTime.tryParse(target['createdAt'] ?? '');
                final completedAt = target['completedAt'] != null
                    ? DateTime.tryParse(target['completedAt'])
                    : null;

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      final updated = List<Map<String, dynamic>>.from(targets);
                      final nextCompleted = !isCompleted;
                      updated[idx] = {
                        ...target,
                        'isCompleted': nextCompleted,
                        'completedAt': nextCompleted
                            ? DateTime.now().toIso8601String()
                            : null,
                      };
                      await PersonNotesAndTargetsHelper.saveTargets(
                        repo,
                        person,
                        updated,
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: isCompleted,
                            activeColor: const Color(0xFF059669),
                            onChanged: (val) async {
                              final updated = List<Map<String, dynamic>>.from(
                                targets,
                              );
                              final nextCompleted = val ?? false;
                              updated[idx] = {
                                ...target,
                                'isCompleted': nextCompleted,
                                'completedAt': nextCompleted
                                    ? DateTime.now().toIso8601String()
                                    : null,
                              };
                              await PersonNotesAndTargetsHelper.saveTargets(
                                repo,
                                person,
                                updated,
                              );
                            },
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      decoration: isCompleted
                                          ? TextDecoration.lineThrough
                                          : null,
                                      color: isCompleted
                                          ? (isDark
                                                ? const Color(0xFF94A3B8)
                                                : Colors.grey.shade600)
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.schedule,
                                        size: 12,
                                        color: Colors.grey.shade500,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        createdAt != null
                                            ? 'Criado em: ${AppDateUtils.formatDateTimeWithAt(createdAt)}'
                                            : 'Criado em: data não disponível',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (isCompleted) ...[
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.check_circle,
                                          size: 12,
                                          color: Color(0xFF059669),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          completedAt != null
                                              ? 'Concluído em: ${AppDateUtils.formatDateTimeWithAt(completedAt)}'
                                              : 'Concluído (data não informada)',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF059669),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            tooltip: 'Editar',
                            visualDensity: VisualDensity.compact,
                            onPressed: () => PersonTargetDialog.show(
                              context: context,
                              repo: repo,
                              person: person,
                              targetToEdit: target,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: AppTheme.alertRed,
                            ),
                            tooltip: 'Excluir',
                            visualDensity: VisualDensity.compact,
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (c) => AlertDialog(
                                  title: const Text('Excluir Alvo'),
                                  content: const Text(
                                    'Tem certeza que deseja excluir este alvo espiritual?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(c, false),
                                      child: const Text('Cancelar'),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.alertRed,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () => Navigator.pop(c, true),
                                      child: const Text('Excluir'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                final updated = targets
                                    .where((t) => t['id'] != target['id'])
                                    .toList();
                                await PersonNotesAndTargetsHelper.saveTargets(
                                  repo,
                                  person,
                                  updated,
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
