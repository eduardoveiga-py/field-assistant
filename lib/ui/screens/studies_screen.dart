import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../appointments/availability_engine.dart';
import '../../core/app_theme.dart';
import '../../database/app_database.dart';
import '../../publications/publication_catalog.dart';
import '../../publications/publication_link_resolver.dart';
import '../../dashboard/counting_rules.dart';
import '../providers.dart';
import '../widgets/global_appointment_scheduling_section.dart';
import '../../publications/lff_book_catalog.dart';
import '../../dashboard/student_priority_engine.dart';
import 'person_detail_screen.dart';

class StudiesScreen extends ConsumerStatefulWidget {
  const StudiesScreen({super.key});

  @override
  ConsumerState<StudiesScreen> createState() => _StudiesScreenState();
}

class _StudiesScreenState extends ConsumerState<StudiesScreen> {
  String _selectedStatusFilter = 'Ativos'; // 'Ativos', 'Prioridade & Progresso', 'Encerrados'
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

  void _showEndStudyDialog(BuildContext context, BibleStudyEntry study) {

    String selectedReason = 'Falta de interesse / tempo';
    final notesController = TextEditingController();

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.stop_circle_outlined, color: AppTheme.alertAmber),
              SizedBox(width: 8),
              Expanded(child: Text('Encerrar Estudo Bíblico')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Você está encerrando o estudo "${study.title}". O contato NÃO será excluído e continuará preservado no seu histórico.',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: selectedReason,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Motivo do Encerramento *'),
                  items: const [
                    DropdownMenuItem(value: 'Falta de interesse / tempo', child: Text('Falta de interesse / tempo')),
                    DropdownMenuItem(value: 'Mudou-se de território', child: Text('Mudou-se de território')),
                    DropdownMenuItem(value: 'Oposição familiar', child: Text('Oposição familiar')),
                    DropdownMenuItem(value: 'Estudo concluído / Batizado', child: Text('Estudo concluído / Batizado')),
                    DropdownMenuItem(value: 'Problemas de saúde', child: Text('Problemas de saúde')),
                    DropdownMenuItem(value: 'Outro', child: Text('Outro motivo')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedReason = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Observação complementar (opcional)',
                    hintText: 'Ex: Contato mantido com a família...',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.alertAmber, foregroundColor: Colors.black),
              onPressed: () async {
                final repo = ref.read(repositoryProvider);
                final reasonPayload = jsonEncode({
                  'endReason': selectedReason,
                  'notes': notesController.text.trim(),
                  'endedAt': DateTime.now().toIso8601String(),
                });
                await repo.updateStudy(
                  study.copyWith(
                    status: selectedReason == 'Estudo concluído / Batizado' ? 'concluido' : 'encerrado',
                    pauseOrCloseReason: Value(reasonPayload),
                  ),
                );
                final parts = await repo.getParticipantsForStudy(study.id);
                for (final part in parts) {
                  final p = await repo.getPersonById(part.personId);
                  if (p != null) {
                    await repo.updatePerson(p.copyWith(status: 'revisita'));
                  }
                }
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Estudo encerrado ($selectedReason). Contatos mantidos como revisita!')),
                  );
                }
              },
              child: const Text('Confirmar Encerramento'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reactivateStudy(BuildContext context, BibleStudyEntry study) async {
    final repo = ref.read(repositoryProvider);
    await repo.updateStudy(
      study.copyWith(
        status: 'ativo',
        pauseOrCloseReason: const Value(null),
      ),
    );
    final parts = await repo.getParticipantsForStudy(study.id);
    for (final part in parts) {
      final p = await repo.getPersonById(part.personId);
      if (p != null) {
        await repo.updatePerson(p.copyWith(status: 'estudo'));
      }
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Estudo "${study.title}" reativado com sucesso!')),
      );
    }
  }
  // Modal para abrir publicação via PublicationLinkResolver
  void _openPublicationLink(BuildContext context, BibleStudyEntry study) {
    final resolved = PublicationLinkResolver.resolve(
      publicationId: study.publicationId,
      languageCode: study.language,
      lesson: study.currentLesson,
      paragraph: study.currentParagraph,
      manualReference: study.manualReference,
    );

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.menu_book, color: AppTheme.primaryBlue),
            const SizedBox(width: 8),
            const Expanded(child: Text('Abrir no JW Library')),
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

  // Modal para registrar ocorrência de sessão de estudo com contagem de assistência e agendamento
  void _showRecordSessionDialog(BuildContext context, BibleStudyEntry study) async {
    final participants = await ref.read(repositoryProvider).getParticipantsForStudy(study.id);
    final primaryPersonId = participants.isNotEmpty ? participants.first.personId : null;
    final allAppts = ref.read(appointmentsStreamProvider).value ?? [];

    // Busca agendamento futuro existente para este estudante para evitar duplicatas
    AppointmentEntry? existingUpcomingAppt;
    if (primaryPersonId != null) {
      final upcoming = allAppts
          .where((a) =>
              a.personId == primaryPersonId &&
              a.startTime.isAfter(DateTime.now().subtract(const Duration(hours: 1))) &&
              a.status != 'cancelado' &&
              a.deletedAt == null)
          .toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));
      if (upcoming.isNotEmpty) {
        existingUpcomingAppt = upcoming.first;
      }
    }

    final isLff = study.publicationId == 'lff-book';
    int selectedLesson = (study.currentLesson ?? 1).clamp(1, 60);
    int selectedStartPoint = (study.currentParagraph ?? 1).clamp(1, 6);
    int selectedEndPoint = selectedStartPoint;
    String sessionOutcome = 'realizada'; // 'realizada' ou 'cancelada'
    String failureMotive = 'Cancelado pelo estudante';
    String selectedUnitId = 'lesson_$selectedLesson';
    final allUnits = isLff ? LffBookCatalog.getAllStudyUnits() : const [];

    final initialNext = isLff
        ? LffBookCatalog.getNextProgression(currentLesson: selectedLesson, currentPoint: selectedEndPoint)
        : null;

    final lessonController = TextEditingController(text: selectedLesson.toString());
    final paragraphsController = TextEditingController(
      text: isLff
          ? (selectedStartPoint == selectedEndPoint ? '$selectedStartPoint' : '$selectedStartPoint-$selectedEndPoint')
          : (study.currentParagraph?.toString() ?? ''),
    );
    final notesController = TextEditingController();
    final nextStepController = TextEditingController(text: study.nextTopic ?? (initialNext?.label ?? ''));
    int attendanceCount = 1;
    bool scheduleNextStudy = true;

    // Frequência do estudo
    final freq = study.frequency.toLowerCase();
    String freqLabel = 'Semanal';
    int daysToAdd = 7;
    if (freq.contains('2x') || freq.contains('duas')) {
      freqLabel = '2x por semana';
      daysToAdd = 3;
    } else if (freq.contains('quinzenal')) {
      freqLabel = 'Quinzenal';
      daysToAdd = 14;
    } else if (freq.contains('mensal')) {
      freqLabel = 'Mensal';
      daysToAdd = 28;
    }

    DateTime nextStudyDateTime;
    int nextStudyDuration = existingUpcomingAppt?.durationMinutes ?? 60;

    if (existingUpcomingAppt != null) {
      nextStudyDateTime = existingUpcomingAppt.startTime;
    } else {
      final target = DateTime.now().add(Duration(days: daysToAdd));
      nextStudyDateTime = DateTime(
        target.year,
        target.month,
        target.day,
        10,
        0,
      );
    }

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final dialogIsDark = Theme.of(ctx).brightness == Brightness.dark;
          final allAppts = ref.read(appointmentsStreamProvider).value ?? [];
          final lessonInfo = isLff ? LffBookCatalog.getLesson(selectedLesson) : null;
          final progressPercent = isLff
              ? LffBookCatalog.calculateProgressPercentage(lesson: selectedLesson, point: selectedEndPoint)
              : null;

          int currentUnitMaxPoints = 6;
          if (isLff) {
            final foundUnit = allUnits.where((u) => u.id == selectedUnitId).firstOrNull;
            currentUnitMaxPoints = foundUnit?.totalPoints ?? (lessonInfo?.totalPoints ?? 6);
          }

          void updatePoints(int startP, int endP) {
            setDialogState(() {
              selectedStartPoint = startP;
              selectedEndPoint = endP;
              paragraphsController.text = startP == endP ? '$startP' : '$startP-$endP';
              final nextProg = LffBookCatalog.getNextProgression(currentLesson: selectedLesson, currentPoint: endP);
              nextStepController.text = nextProg.label;
            });
          }

          return AlertDialog(
            title: Text('Registrar Sessão: ${study.title}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Seletor de Desfecho da Sessão: Realizada com Sucesso vs Falhou/Cancelada
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setDialogState(() => sessionOutcome = 'realizada'),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                              decoration: BoxDecoration(
                                color: sessionOutcome == 'realizada'
                                    ? AppTheme.successGreen.withValues(alpha: 0.15)
                                    : (dialogIsDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: sessionOutcome == 'realizada' ? AppTheme.successGreen : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    size: 16,
                                    color: sessionOutcome == 'realizada' ? AppTheme.successGreen : Colors.grey,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Realizada',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: sessionOutcome == 'realizada' ? AppTheme.successGreen : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () => setDialogState(() => sessionOutcome = 'cancelada'),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                              decoration: BoxDecoration(
                                color: sessionOutcome == 'cancelada'
                                    ? AppTheme.alertRed.withValues(alpha: 0.15)
                                    : (dialogIsDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: sessionOutcome == 'cancelada' ? AppTheme.alertRed : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.cancel,
                                    size: 16,
                                    color: sessionOutcome == 'cancelada' ? AppTheme.alertRed : Colors.grey,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Falhou / Cancelada',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: sessionOutcome == 'cancelada' ? AppTheme.alertRed : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (sessionOutcome == 'cancelada') ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFF87171)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 18),
                              SizedBox(width: 6),
                              Text('Registrar Falha / Não Realização', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF991B1B), fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'O apontamento da falha é contabilizado internamente para atualizar a prioridade do estudante.',
                            style: TextStyle(fontSize: 11, color: Color(0xFF7F1D1D)),
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            initialValue: failureMotive,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Motivo da Falha / Não Realização *',
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            items: const [
                              DropdownMenuItem(value: 'Cancelado pelo estudante', child: Text('Cancelado pelo estudante')),
                              DropdownMenuItem(value: 'Estudante ausente / Não atendeu', child: Text('Estudante ausente / Não atendeu')),
                              DropdownMenuItem(value: 'Imprevisto pessoal do publicador', child: Text('Imprevisto pessoal do publicador')),
                              DropdownMenuItem(value: 'Desmarcado com antecedência', child: Text('Desmarcado com antecedência')),
                              DropdownMenuItem(value: 'Outro motivo', child: Text('Outro motivo')),
                            ],
                            onChanged: (val) {
                              if (val != null) setDialogState(() => failureMotive = val);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ] else ...[
                    if (isLff && progressPercent != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.25)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Progresso no Livro (lff):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED))),
                                Text('${progressPercent.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED))),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progressPercent / 100.0,
                                minHeight: 8,
                                backgroundColor: Colors.purple.shade100,
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7C3AED)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: selectedUnitId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Unidade / Lição Estudada (lff) *'),
                        items: allUnits.map((u) {
                          return DropdownMenuItem<String>(
                            value: u.id,
                            child: Text(
                              u.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedUnitId = val;
                              if (val.startsWith('lesson_')) {
                                selectedLesson = int.parse(val.replaceFirst('lesson_', ''));
                                lessonController.text = selectedLesson.toString();
                                final nextProg = LffBookCatalog.getNextProgression(currentLesson: selectedLesson, currentPoint: selectedEndPoint);
                                nextStepController.text = nextProg.label;
                              } else {
                                nextStepController.text = val;
                              }
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Pontos Cobertos:',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: List.generate(currentUnitMaxPoints, (idx) {
                          final pNum = idx + 1;
                          final isSelected = pNum >= selectedStartPoint && pNum <= selectedEndPoint;
                          return FilterChip(
                            label: Text('Ponto $pNum'),
                            selected: isSelected,
                            selectedColor: const Color(0xFF7C3AED).withValues(alpha: 0.25),
                            checkmarkColor: const Color(0xFF7C3AED),
                            onSelected: (val) {
                              if (val) {
                                if (pNum < selectedStartPoint) {
                                  updatePoints(pNum, selectedEndPoint);
                                } else {
                                  updatePoints(selectedStartPoint, pNum);
                                }
                              } else {
                                if (selectedStartPoint == selectedEndPoint) {
                                  // Mínimo 1 selecionado
                                } else if (pNum == selectedEndPoint) {
                                  updatePoints(selectedStartPoint, selectedEndPoint - 1);
                                } else if (pNum == selectedStartPoint) {
                                  updatePoints(selectedStartPoint + 1, selectedEndPoint);
                                }
                              }
                            },
                          );
                        }),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: paragraphsController,
                        decoration: const InputDecoration(
                          labelText: 'Pontos Estudados (livre para editar)',
                          hintText: 'Ex: 1, 2-3, 1-6 ou anotação personalizada',
                        ),
                        onChanged: (text) {
                          final parsed = int.tryParse(text.trim());
                          if (parsed != null && parsed >= 1 && parsed <= currentUnitMaxPoints) {
                            setDialogState(() {
                              selectedStartPoint = parsed;
                              selectedEndPoint = parsed;
                              final nextProg = LffBookCatalog.getNextProgression(currentLesson: selectedLesson, currentPoint: parsed);
                              nextStepController.text = nextProg.label;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                    ] else ...[
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
                      const SizedBox(height: 14),
                    ],

                    // Seletor de Contagem de Presentes / Assistência
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Número de Presentes',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF7C3AED)),
                                ),
                                Text('Estudante e acompanhantes', style: TextStyle(fontSize: 11, color: dialogIsDark ? const Color(0xFFCBD5E1) : AppTheme.textMuted)),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: Color(0xFF7C3AED)),
                                onPressed: () {
                                  if (attendanceCount > 1) {
                                    setDialogState(() => attendanceCount--);
                                  }
                                },
                              ),
                              Text(
                                '$attendanceCount',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline, color: Color(0xFF7C3AED)),
                                onPressed: () {
                                  setDialogState(() => attendanceCount++);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  TextField(
                    controller: notesController,
                    decoration: InputDecoration(
                      labelText: sessionOutcome == 'cancelada' ? 'Observações da falha' : 'Observações da sessão',
                      hintText: sessionOutcome == 'cancelada'
                          ? 'Descreva o que houve ou motivo de contato...'
                          : 'Dúvidas esclarecidas, pontos de interesse...',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nextStepController,
                    decoration: const InputDecoration(
                      labelText: 'Próximo assunto',
                      hintText: 'Ex: Lição 2, Ponto 1 em diante',
                    ),
                  ),
                  const SizedBox(height: 14),

                  GlobalAppointmentSchedulingSection(
                    title: 'Agendar Próximo Estudo',
                    isEnabled: scheduleNextStudy,
                    onToggle: (v) => setDialogState(() => scheduleNextStudy = v),
                    selectedDateTime: nextStudyDateTime,
                    onDateTimeChanged: (dt) => setDialogState(() => nextStudyDateTime = dt),
                    durationMinutes: nextStudyDuration,
                    onDurationChanged: (d) => setDialogState(() => nextStudyDuration = d),
                    existingAppointments: allAppts,
                    existingPersonAppointment: existingUpcomingAppt,
                    frequencyText: freqLabel,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: sessionOutcome == 'cancelada' ? AppTheme.alertRed : const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  if (scheduleNextStudy) {
                    final avail = AvailabilityEngine.checkAvailability(
                      startTime: nextStudyDateTime,
                      durationMinutes: nextStudyDuration,
                      existingAppointments: allAppts,
                    );
                    final canProceed = await GlobalAppointmentSchedulingSection.confirmConflictIfNeeded(
                      context: context,
                      availability: avail,
                    );
                    if (!canProceed) return;
                  }

                  final repo = ref.read(repositoryProvider);
                  final participants = await repo.getParticipantsForStudy(study.id);
                  final primaryPersonId = participants.isNotEmpty ? participants.first.personId : null;

                  if (sessionOutcome == 'cancelada') {
                    final formattedNotes = notesController.text.trim().isEmpty
                        ? '[Sessão Cancelada: $failureMotive]'
                        : '[Sessão Cancelada: $failureMotive] ${notesController.text.trim()}';

                    await repo.createStudySession(
                      studyId: study.id,
                      dateTime: DateTime.now(),
                      lessonCovered: study.currentLesson,
                      paragraphsCovered: null,
                      sessionNotes: formattedNotes,
                      nextStep: nextStepController.text.trim().isEmpty ? null : nextStepController.text.trim(),
                      status: 'cancelada',
                      participantIds: participants.map((p) => p.personId).toList(),
                    );

                    if (nextStepController.text.trim().isNotEmpty) {
                      await repo.updateStudy(
                        study.copyWith(
                          nextTopic: Value(nextStepController.text.trim()),
                        ),
                      );
                    }
                  } else {
                    final lesson = isLff ? selectedLesson : int.tryParse(lessonController.text.trim());
                    final formattedNotes = DashboardCalculator.formatSessionNotesWithAttendance(
                      notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                      attendanceCount,
                    );

                    await repo.createStudySession(
                      studyId: study.id,
                      dateTime: DateTime.now(),
                      lessonCovered: lesson,
                      paragraphsCovered: paragraphsController.text.trim().isEmpty ? null : paragraphsController.text.trim(),
                      sessionNotes: formattedNotes,
                      nextStep: nextStepController.text.trim().isEmpty ? null : nextStepController.text.trim(),
                      status: 'realizada',
                      participantIds: participants.map((p) => p.personId).toList(),
                    );

                    // Atualiza a lição e ponto atual no registro do estudo
                    await repo.updateStudy(
                      study.copyWith(
                        currentLesson: Value(lesson),
                        currentParagraph: Value(int.tryParse(paragraphsController.text.trim()) ?? (isLff ? selectedEndPoint : null)),
                        nextTopic: Value(nextStepController.text.trim().isEmpty ? null : nextStepController.text.trim()),
                        lastSessionAt: Value(DateTime.now()),
                      ),
                    );
                  }

                  if (scheduleNextStudy) {
                    // Prevenção de duplicidade: atualiza compromisso existente na mesma data ou cria novo
                    final existingAppts = ref.read(appointmentsStreamProvider).value ?? [];
                    final existingOnDate = existingAppts.firstWhereOrNull((a) =>
                        a.deletedAt == null &&
                        a.status != 'cancelado' &&
                        ((primaryPersonId != null && a.personId == primaryPersonId) || (a.studyId != null && a.studyId == study.id)) &&
                        a.startTime.year == nextStudyDateTime.year &&
                        a.startTime.month == nextStudyDateTime.month &&
                        a.startTime.day == nextStudyDateTime.day);

                    if (existingOnDate != null) {
                      await repo.updateAppointment(
                        existingOnDate.copyWith(
                          studyId: Value(study.id),
                          personId: Value(primaryPersonId),
                          startTime: nextStudyDateTime,
                          endTime: nextStudyDateTime.add(Duration(minutes: nextStudyDuration)),
                          durationMinutes: nextStudyDuration,
                          status: 'confirmado',
                        ),
                      );
                    } else {
                      await repo.createAppointment(
                        personId: primaryPersonId,
                        studyId: study.id,
                        title: 'Estudo Bíblico: ${study.title}',
                        startTime: nextStudyDateTime,
                        endTime: nextStudyDateTime.add(Duration(minutes: nextStudyDuration)),
                        durationMinutes: nextStudyDuration,
                        status: 'confirmado',
                      );
                    }
                  }

                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Sessão registrada com sucesso! ($attendanceCount presentes computados)')),
                    );
                  }
                },
                child: const Text('Salvar Sessão'),
              ),
            ],
          );
        },
      ),
    );
  }

  // Modal para criar novo estudo bíblico
  void _showNewStudyDialog(BuildContext context) {
    final titleController = TextEditingController();
    String selectedPublicationId = 'lff-book';
    String selectedLanguage = 'pt';
    String selectedFrequency = 'semanal';
    final List<String> selectedPeopleIds = [];

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final people = ref.read(peopleStreamProvider).value ?? [];
          final isDarkDialog = Theme.of(ctx).brightness == Brightness.dark;

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
                    isExpanded: true,
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
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedFrequency,
                    decoration: const InputDecoration(labelText: 'Frequência do estudo'),
                    items: const [
                      DropdownMenuItem(value: 'semanal', child: Text('Semanal (1x por semana)')),
                      DropdownMenuItem(value: 'duas_vezes_semana', child: Text('Intensivo (2x por semana)')),
                      DropdownMenuItem(value: 'quinzenal', child: Text('Quinzenal (A cada 15 dias)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedFrequency = val);
                    },
                  ),
                  const SizedBox(height: 14),
                  const Text('Quem participa ou acompanha o estudo:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('Selecione o estudante principal e os acompanhantes (ex: casal ou familiares):', style: TextStyle(fontSize: 12, color: isDarkDialog ? const Color(0xFFCBD5E1) : AppTheme.textMuted)),
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
                    frequency: selectedFrequency,
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

  Widget _buildPriorityAndProgressView({
    required List<BibleStudyEntry> activeStudies,
    required List<StudyParticipantEntry> participants,
    required List<PersonEntry> people,
    required List<StudySessionEntry> sessions,
    required List<AppointmentEntry> appointments,
    required bool isDark,
  }) {
    if (activeStudies.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.star_outline, size: 56, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                'Nenhum estudo bíblico ativo para calcular prioridade.\nAdicione ou ative um estudo para ver a lista inteligente.',
                textAlign: TextAlign.center,
                style: TextStyle(color: isDark ? const Color(0xFFCBD5E1) : AppTheme.textMuted, fontSize: 15),
              ),
            ],
          ),
        ),
      );
    }

    final priorityItems = StudentPriorityEngine.calculatePriorities(
      activeStudies: activeStudies,
      participants: participants,
      people: people,
      sessions: sessions,
      appointments: appointments,
      manualOrder: _manualOrderMap,
    );

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: AppTheme.primaryBlue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Prioridade calculada por frequência (2x/sem), ritmo e assiduidade. Arraste para reordenar.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: priorityItems.length,
            onReorderItem: (oldIndex, newIndex) {
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

            itemBuilder: (context, index) {
              final item = priorityItems[index];
              final study = item.study;
              final lffLesson = study.publicationId == 'lff-book' && study.currentLesson != null
                  ? LffBookCatalog.getLesson(study.currentLesson!)
                  : null;

              Color priorityColor;
              IconData priorityIcon;
              switch (item.priorityTier) {
                case 'Muito Alta':
                  priorityColor = const Color(0xFFDC2626);
                  priorityIcon = Icons.local_fire_department;
                  break;
                case 'Alta':
                  priorityColor = const Color(0xFF2563EB);
                  priorityIcon = Icons.trending_up;
                  break;
                case 'Média':
                  priorityColor = const Color(0xFF0D9488);
                  priorityIcon = Icons.check_circle_outline;
                  break;
                default:
                  priorityColor = const Color(0xFFD97706);
                  priorityIcon = Icons.warning_amber_rounded;
              }

              return Card(
                key: ValueKey(study.id),
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '#${item.manualRank}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              study.title,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: priorityColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: priorityColor.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(priorityIcon, size: 14, color: priorityColor),
                                const SizedBox(width: 4),
                                Text(
                                  item.priorityTier,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: priorityColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.drag_indicator, color: Colors.grey),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Estudante: ${item.primaryPerson.name}',
                        style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFCBD5E1) : AppTheme.textMuted),
                      ),
                      const SizedBox(height: 8),
                      // Progresso LFF
                      if (study.publicationId == 'lff-book') ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                study.currentLesson != null
                                    ? 'Lição ${study.currentLesson}: ${lffLesson?.title ?? "Seja Feliz Para Sempre!"}'
                                    : 'Livro Seja Feliz Para Sempre!',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${item.progressPercent.toStringAsFixed(1)}%',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.accentTeal),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: item.progressPercent / 100.0,
                            minHeight: 6,
                            backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accentTeal),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      // Chips de métricas de prioridade
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (item.frequency == 'duas_vezes_semana')
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('🔥 2x / semana', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(item.velocityLabel, style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFFCBD5E1) : AppTheme.textMuted)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.daysSinceLastSession != null
                                  ? 'Última: ${item.daysSinceLastSession}d atrás'
                                  : 'Sem sessões ainda',
                              style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFFCBD5E1) : AppTheme.textMuted),
                            ),
                          ),
                          if (item.spiritualGoalsMetCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '🎯 ${item.spiritualGoalsMetCount} meta(s)',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.person, size: 16),
                              label: const Text('Contato', style: TextStyle(fontSize: 12)),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PersonDetailScreen(personId: item.primaryPerson.id),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF7C3AED),
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.playlist_add_check, size: 16),
                              label: const Text('Registrar Sessão', style: TextStyle(fontSize: 12)),
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
          ),
        ),
      ],
    );
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
          final activeStudies = studies.where((s) => s.status == 'ativo').toList();
          final closedStudies = studies.where((s) => s.status != 'ativo').toList();

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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: Text('Ativos (${activeStudies.length})'),
                        selected: _selectedStatusFilter == 'Ativos',
                        onSelected: (val) {
                          if (val) setState(() => _selectedStatusFilter = 'Ativos');
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text('Prioridade & Progresso (${activeStudies.length})'),
                        selected: _selectedStatusFilter == 'Prioridade & Progresso',
                        onSelected: (val) {
                          if (val) setState(() => _selectedStatusFilter = 'Prioridade & Progresso');
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text('Encerrados / Concluídos (${closedStudies.length})'),
                        selected: _selectedStatusFilter == 'Encerrados',
                        onSelected: (val) {
                          if (val) setState(() => _selectedStatusFilter = 'Encerrados');
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _selectedStatusFilter == 'Prioridade & Progresso'
                    ? _buildPriorityAndProgressView(
                        activeStudies: activeStudies,
                        participants: participants,
                        people: people,
                        sessions: sessions,
                        appointments: appointments,
                        isDark: isDark,
                      )
                    : filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.menu_book, size: 56, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text(
                                _selectedStatusFilter == 'Ativos'
                                    ? 'Nenhum estudo bíblico ativo no momento.\nToque em "+ Novo Estudo" para registrar.'
                                    : 'Nenhum estudo encerrado ou concluído.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: isDark ? const Color(0xFFCBD5E1) : AppTheme.textMuted, fontSize: 15),
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
                          final pub = PublicationCatalog.getById(study.publicationId);

                          String? endReason;
                          if (study.pauseOrCloseReason != null && study.pauseOrCloseReason!.isNotEmpty) {
                            try {
                              final d = jsonDecode(study.pauseOrCloseReason!);
                              if (d is Map && d.containsKey('endReason')) endReason = d['endReason'];
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
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          study.title,
                                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.account_box_outlined, color: AppTheme.primaryBlue, size: 22),
                                        tooltip: 'Ver Cadastro e Opções da Pessoa',
                                        onPressed: () async {
                                          final parts = await ref.read(repositoryProvider).getParticipantsForStudy(study.id);
                                          if (parts.isNotEmpty && context.mounted) {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => PersonDetailScreen(personId: parts.first.personId),
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: study.status == 'ativo'
                                              ? AppTheme.successGreen.withValues(alpha: 0.1)
                                              : (isDark ? const Color(0xFF334155) : Colors.grey.shade200),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          study.status.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: study.status == 'ativo'
                                                ? AppTheme.successGreen
                                                : (isDark ? const Color(0xFFCBD5E1) : Colors.grey.shade700),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    pub?.title ?? study.publicationId,
                                    style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFFCBD5E1) : AppTheme.textMuted),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  FutureBuilder<List<StudyParticipantEntry>>(
                                    future: ref.read(repositoryProvider).getParticipantsForStudy(study.id),
                                    builder: (context, partSnap) {
                                      final parts = partSnap.data ?? [];
                                      if (parts.isEmpty) return const SizedBox.shrink();
                                      final people = ref.watch(peopleStreamProvider).value ?? [];
                                      final peopleMap = {for (var p in people) p.id: p.name};
                                      final names = parts.map((p) => peopleMap[p.personId] ?? 'Participante').join(', ');
                                      return InkWell(
                                        onTap: () {
                                          if (parts.isNotEmpty) {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => PersonDetailScreen(personId: parts.first.personId),
                                              ),
                                            );
                                          }
                                        },
                                        borderRadius: BorderRadius.circular(6),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                          margin: const EdgeInsets.only(bottom: 8),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryBlue.withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.2)),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.people_alt_outlined, size: 16, color: AppTheme.primaryBlue),
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
                                              const Icon(Icons.arrow_forward_ios, size: 11, color: AppTheme.primaryBlue),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                                      children: [
                                        Column(
                                          children: [
                                            Text('Lição Atual', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFFCBD5E1) : AppTheme.textMuted)),
                                            Text(
                                              study.currentLesson != null ? 'Lição ${study.currentLesson}' : 'Não iniciada',
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                        Column(
                                          children: [
                                            Text(
                                              study.publicationId == 'lff-book' || study.publicationId == 'lff-brochure' ? 'Ponto Atual' : 'Parágrafo',
                                              style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFFCBD5E1) : AppTheme.textMuted),
                                            ),
                                            Text(
                                              study.currentParagraph != null
                                                  ? (study.publicationId == 'lff-book' || study.publicationId == 'lff-brochure'
                                                      ? 'Ponto ${study.currentParagraph}'
                                                      : '§ ${study.currentParagraph}')
                                                  : '—',
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                        Column(
                                          children: [
                                            Text('Idioma', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFFCBD5E1) : AppTheme.textMuted)),
                                            Text(
                                              study.language.toUpperCase(),
                                              style: const TextStyle(fontWeight: FontWeight.bold),
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
                                          const Icon(Icons.info_outline, color: Color(0xFFB45309), size: 16),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              'Motivo do Encerramento: $endReason',
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
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
                                            foregroundColor: AppTheme.primaryBlue,
                                            side: const BorderSide(color: AppTheme.primaryBlue),
                                          ),
                                          icon: const Icon(Icons.person_outline, size: 16),
                                          label: const Text('Ver Cadastro & Opções'),
                                          onPressed: () async {
                                            final parts = await ref.read(repositoryProvider).getParticipantsForStudy(study.id);
                                            if (parts.isNotEmpty && context.mounted) {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => PersonDetailScreen(personId: parts.first.personId),
                                                ),
                                              );
                                            } else if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Nenhum contato vinculado diretamente a este estudo.')),
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
                                          icon: const Icon(Icons.menu_book, size: 16),
                                          label: const Text('Abrir no JW Library'),
                                          onPressed: () => _openPublicationLink(context, study),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          icon: const Icon(Icons.playlist_add_check, size: 16),
                                          label: const Text('Sessão'),
                                          onPressed: study.status == 'ativo' ? () => _showRecordSessionDialog(context, study) : null,
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
                                          side: const BorderSide(color: AppTheme.alertRed),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        icon: const Icon(Icons.stop_circle_outlined, size: 16),
                                        label: const Text('Encerrar Estudo (com motivo)', style: TextStyle(fontSize: 12)),
                                        onPressed: () => _showEndStudyDialog(context, study),
                                      ),
                                    )
                                  else
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.successGreen,
                                          foregroundColor: Colors.white,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        icon: const Icon(Icons.refresh, size: 16),
                                        label: const Text('Reativar Estudo Bíblico', style: TextStyle(fontSize: 12)),
                                        onPressed: () => _reactivateStudy(context, study),
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
