import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../dashboard/student_priority_engine.dart';
import '../../database/app_database.dart';
import '../../publications/publication_catalog.dart';
import '../providers.dart';
import '../widgets/end_study_dialog.dart';
import '../widgets/publication_link_dialog.dart';
import '../widgets/record_study_session_dialog.dart';
import '../widgets/studies_priority_progress_view.dart';
import '../widgets/study_form_dialog.dart';
import 'person_detail_screen.dart';

class StudiesScreen extends ConsumerStatefulWidget {
  const StudiesScreen({super.key});

  @override
  ConsumerState<StudiesScreen> createState() => _StudiesScreenState();
}

class _StudiesScreenState extends ConsumerState<StudiesScreen> {
  String _selectedStatusFilter =
      'Ativos'; // 'Ativos', 'Prioridade & Progresso', 'Encerrados'
  final Map<String, int> _manualOrderMap = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final db = ref.read(repositoryProvider).db;
      final loaded = await StudentPriorityEngine.loadManualOrder(db);
      if (mounted && loaded.isNotEmpty) {
        setState(() {
          _manualOrderMap.addAll(loaded);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final studiesAsync = ref.watch(studiesStreamProvider);
    final participants = ref.watch(studyParticipantsStreamProvider).value ?? [];
    final people = ref.watch(peopleStreamProvider).value ?? [];
    final sessions = ref.watch(studySessionsStreamProvider).value ?? [];
    final appointments = ref.watch(appointmentsStreamProvider).value ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Estudos Bíblicos')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Novo Estudo'),
        onPressed: () => StudyFormDialog.show(context),
      ),
      body: studiesAsync.when(
        data: (studies) {
          final activeStudies = studies
              .where((s) => s.status == 'ativo')
              .toList();
          final closedStudies = studies
              .where((s) => s.status != 'ativo')
              .toList();

          final filtered = studies.where((s) {
            if (_selectedStatusFilter == 'Ativos') {
              return s.status == 'ativo';
            } else if (_selectedStatusFilter == 'Encerrados') {
              return s.status != 'ativo';
            }
            return false;
          }).toList();

          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: Text('Ativos (${activeStudies.length})'),
                        selected: _selectedStatusFilter == 'Ativos',
                        onSelected: (val) {
                          if (val) {
                            setState(() => _selectedStatusFilter = 'Ativos');
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text(
                          'Prioridade & Progresso (${activeStudies.length})',
                        ),
                        selected:
                            _selectedStatusFilter == 'Prioridade & Progresso',
                        onSelected: (val) {
                          if (val) {
                            setState(
                              () => _selectedStatusFilter =
                                  'Prioridade & Progresso',
                            );
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text(
                          'Encerrados / Concluídos (${closedStudies.length})',
                        ),
                        selected: _selectedStatusFilter == 'Encerrados',
                        onSelected: (val) {
                          if (val) {
                            setState(
                              () => _selectedStatusFilter = 'Encerrados',
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _selectedStatusFilter == 'Prioridade & Progresso'
                    ? StudiesPriorityProgressView(
                        activeStudies: activeStudies,
                        participants: participants,
                        people: people,
                        sessions: sessions,
                        appointments: appointments,
                        manualOrderMap: _manualOrderMap,
                        isDark: isDark,
                        onReorder: (oldIndex, newIndex) {
                          final priorityItems = StudentPriorityEngine.calculatePriorities(
                            activeStudies: activeStudies,
                            participants: participants,
                            people: people,
                            sessions: sessions,
                            appointments: appointments,
                            manualOrder: _manualOrderMap,
                          );
                          setState(() {
                            StudentPriorityEngine.applyManualReorderItem(
                              items: priorityItems,
                              oldIndex: oldIndex,
                              newIndex: newIndex,
                              manualOrderMap: _manualOrderMap,
                              db: ref.read(repositoryProvider).db,
                            );
                          });
                        },
                        onRecordSession: (study) =>
                            RecordStudySessionDialog.show(context, study: study),
                        onOpenContact: (personId) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PersonDetailScreen(
                                personId: personId,
                              ),
                            ),
                          );
                        },
                      )
                    : filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.menu_book,
                                size: 56,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _selectedStatusFilter == 'Ativos'
                                    ? 'Nenhum estudo bíblico ativo no momento.\nToque em "+ Novo Estudo" para registrar.'
                                    : 'Nenhum estudo encerrado ou concluído.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isDark
                                      ? const Color(0xFFCBD5E1)
                                      : AppTheme.textMuted,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final study = filtered[index];
                          final pub = PublicationCatalog.getById(
                            study.publicationId,
                          );

                          String? endReason;
                          if (study.pauseOrCloseReason != null &&
                              study.pauseOrCloseReason!.isNotEmpty) {
                            try {
                              final d = jsonDecode(study.pauseOrCloseReason!);
                              if (d is Map && d.containsKey('endReason')) {
                                endReason = d['endReason'];
                              }
                            } catch (_) {
                              endReason = study.pauseOrCloseReason;
                            }
                          }

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          study.title,
                                          style: const TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit_outlined,
                                          color: AppTheme.primaryBlue,
                                          size: 20,
                                        ),
                                        tooltip: 'Editar Dados do Estudo',
                                        onPressed: () => StudyFormDialog.show(
                                          context,
                                          study: study,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.account_box_outlined,
                                          color: AppTheme.primaryBlue,
                                          size: 22,
                                        ),
                                        tooltip:
                                            'Ver Cadastro e Opções da Pessoa',
                                        onPressed: () async {
                                          final parts = await ref
                                              .read(repositoryProvider)
                                              .getParticipantsForStudy(
                                                study.id,
                                              );
                                          if (parts.isNotEmpty &&
                                              context.mounted) {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    PersonDetailScreen(
                                                      personId:
                                                          parts.first.personId,
                                                    ),
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: study.status == 'ativo'
                                              ? AppTheme.successGreen
                                                    .withValues(alpha: 0.1)
                                              : (isDark
                                                    ? const Color(0xFF334155)
                                                    : Colors.grey.shade200),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          study.status.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: study.status == 'ativo'
                                              ? AppTheme.successGreen
                                              : (isDark
                                                    ? const Color(0xFFCBD5E1)
                                                    : Colors.grey.shade700),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    pub?.title ?? study.publicationId,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark
                                          ? const Color(0xFFCBD5E1)
                                          : AppTheme.textMuted,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  FutureBuilder<List<StudyParticipantEntry>>(
                                    future: ref
                                        .read(repositoryProvider)
                                        .getParticipantsForStudy(study.id),
                                    builder: (context, partSnap) {
                                      final parts = partSnap.data ?? [];
                                      if (parts.isEmpty) {
                                        return const SizedBox.shrink();
                                      }
                                      final people =
                                          ref
                                              .watch(peopleStreamProvider)
                                              .value ??
                                          [];
                                      final peopleMap = {
                                        for (var p in people) p.id: p.name,
                                      };
                                      final names = parts
                                          .map(
                                            (p) =>
                                                peopleMap[p.personId] ??
                                                'Participante',
                                          )
                                          .join(', ');
                                      return InkWell(
                                        onTap: () {
                                          if (parts.isNotEmpty) {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    PersonDetailScreen(
                                                      personId:
                                                          parts.first.personId,
                                                    ),
                                              ),
                                            );
                                          }
                                        },
                                        borderRadius: BorderRadius.circular(6),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 5,
                                          ),
                                          margin: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryBlue
                                                .withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            border: Border.all(
                                              color: AppTheme.primaryBlue
                                                  .withValues(alpha: 0.2),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.people_alt_outlined,
                                                size: 16,
                                                color: AppTheme.primaryBlue,
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  'Participam: $names',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppTheme.primaryBlue,
                                                  ),
                                                ),
                                              ),
                                              const Icon(
                                                Icons.arrow_forward_ios,
                                                size: 11,
                                                color: AppTheme.primaryBlue,
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF1E293B)
                                          : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceAround,
                                      children: [
                                        Column(
                                          children: [
                                            Text(
                                              'Lição Atual',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isDark
                                                    ? const Color(0xFFCBD5E1)
                                                    : AppTheme.textMuted,
                                              ),
                                            ),
                                            Text(
                                              study.currentLesson != null
                                                  ? 'Lição ${study.currentLesson}'
                                                  : 'Não iniciada',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Column(
                                          children: [
                                            Text(
                                              study.publicationId ==
                                                          'lff-book' ||
                                                      study.publicationId ==
                                                          'lff-brochure'
                                                  ? 'Ponto Atual'
                                                  : 'Parágrafo',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isDark
                                                    ? const Color(0xFFCBD5E1)
                                                    : AppTheme.textMuted,
                                              ),
                                            ),
                                            Text(
                                              study.currentParagraph != null
                                                  ? (study.publicationId ==
                                                                'lff-book' ||
                                                            study.publicationId ==
                                                                'lff-brochure'
                                                        ? 'Ponto ${study.currentParagraph}'
                                                        : '§ ${study.currentParagraph}')
                                                  : '—',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Column(
                                          children: [
                                            Text(
                                              'Idioma',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isDark
                                                    ? const Color(0xFFCBD5E1)
                                                    : AppTheme.textMuted,
                                              ),
                                            ),
                                            Text(
                                              study.language.toUpperCase(),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (endReason != null) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF3C7),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.info_outline,
                                            color: Color(0xFFB45309),
                                            size: 16,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              'Motivo do Encerramento: $endReason',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF92400E),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor:
                                                AppTheme.primaryBlue,
                                            side: const BorderSide(
                                              color: AppTheme.primaryBlue,
                                            ),
                                          ),
                                          icon: const Icon(
                                            Icons.person_outline,
                                            size: 16,
                                          ),
                                          label: const Text(
                                            'Ver Cadastro & Opções',
                                          ),
                                          onPressed: () async {
                                            final parts = await ref
                                                .read(repositoryProvider)
                                                .getParticipantsForStudy(
                                                  study.id,
                                                );
                                            if (parts.isNotEmpty &&
                                                context.mounted) {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      PersonDetailScreen(
                                                        personId: parts
                                                            .first
                                                            .personId,
                                                      ),
                                                ),
                                              );
                                            } else if (context.mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Nenhum contato vinculado diretamente a este estudo.',
                                                      ),
                                                    ),
                                                  );
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          icon: const Icon(
                                            Icons.menu_book,
                                            size: 16,
                                          ),
                                          label: const Text(
                                            'Abrir no JW Library',
                                          ),
                                          onPressed: () =>
                                              PublicationLinkDialog.show(
                                                context,
                                                study,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          icon: const Icon(
                                            Icons.playlist_add_check,
                                            size: 16,
                                          ),
                                          label: const Text('Sessão'),
                                          onPressed: study.status == 'ativo'
                                              ? () =>
                                                  RecordStudySessionDialog.show(
                                                    context,
                                                    study: study,
                                                  )
                                              : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  if (study.status == 'ativo')
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppTheme.alertRed,
                                          side: const BorderSide(
                                            color: AppTheme.alertRed,
                                          ),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        icon: const Icon(
                                          Icons.stop_circle_outlined,
                                          size: 16,
                                        ),
                                        label: const Text(
                                          'Encerrar Estudo (com motivo)',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                        onPressed: () =>
                                            EndStudyDialog.show(
                                              context,
                                              study: study,
                                            ),
                                      ),
                                    )
                                  else
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              AppTheme.successGreen,
                                          foregroundColor: Colors.white,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        icon: const Icon(
                                          Icons.refresh,
                                          size: 16,
                                        ),
                                        label: const Text(
                                          'Reativar Estudo Bíblico',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                        onPressed: () =>
                                            EndStudyDialog.reactivate(
                                              context,
                                              ref,
                                              study,
                                            ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erro: $err')),
      ),
    );
  }
}
