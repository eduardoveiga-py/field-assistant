import 'package:collection/collection.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../appointments/availability_engine.dart';
import '../../core/app_theme.dart';
import '../../core/date_utils.dart';
import '../../dashboard/counting_rules.dart';
import '../../database/app_database.dart';
import '../../database/repository.dart';
import '../../publications/lff_book_catalog.dart';
import '../providers.dart';
import 'global_appointment_scheduling_section.dart';

/// Diálogo unificado para registrar sessão de estudo bíblico, com catálogo LFF,
/// contagem de assistência, agendamento e toggle para registro retroativo (Requisito 4).
class RecordStudySessionDialog extends ConsumerStatefulWidget {
  final BibleStudyEntry study;
  final PersonEntry? primaryPerson;
  final VoidCallback? onRecorded;

  const RecordStudySessionDialog({
    super.key,
    required this.study,
    this.primaryPerson,
    this.onRecorded,
  });

  static Future<void> show(
    BuildContext context, {
    required BibleStudyEntry study,
    PersonEntry? person,
    PersonEntry? primaryPerson,
    AppRepository? repo,
    VoidCallback? onRecorded,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => RecordStudySessionDialog(
        study: study,
        primaryPerson: person ?? primaryPerson,
        onRecorded: onRecorded,
      ),
    );
  }

  @override
  ConsumerState<RecordStudySessionDialog> createState() => _RecordStudySessionDialogState();
}

class _RecordStudySessionDialogState extends ConsumerState<RecordStudySessionDialog> {
  late final bool _isLff;
  late int _selectedLesson;
  late int _selectedStartPoint;
  late int _selectedEndPoint;
  String _sessionOutcome = 'realizada'; // 'realizada' ou 'cancelada'
  String _failureMotive = 'Cancelado pelo estudante';
  late String _selectedUnitId;
  late List<({String id, String title, String category, int totalPoints})> _allUnits;

  late final TextEditingController _lessonController;
  late final TextEditingController _paragraphsController;
  late final TextEditingController _notesController;
  late final TextEditingController _nextStepController;

  int _attendanceCount = 1;
  bool _scheduleNextStudy = true;

  // Requisito 4: Toggle de data retroativa
  bool _isRetroactive = false;
  DateTime _retroactiveDateTime = DateTime.now();

  late DateTime _nextStudyDateTime;
  int _nextStudyDuration = 60;

  @override
  void initState() {
    super.initState();
    _isLff = widget.study.publicationId == 'lff-book';
    _selectedLesson = (widget.study.currentLesson ?? 1).clamp(1, 60);
    _selectedStartPoint = (widget.study.currentParagraph ?? 1).clamp(1, 6);
    _selectedEndPoint = _selectedStartPoint;
    _selectedUnitId = 'lesson_$_selectedLesson';
    _allUnits = _isLff ? LffBookCatalog.getAllStudyUnits() : const [];

    final initialNext = _isLff
        ? LffBookCatalog.getNextProgression(
            currentLesson: _selectedLesson,
            currentPoint: _selectedEndPoint,
          )
        : null;

    _lessonController = TextEditingController(text: _selectedLesson.toString());
    _paragraphsController = TextEditingController(
      text: _isLff
          ? (_selectedStartPoint == _selectedEndPoint
              ? '$_selectedStartPoint'
              : '$_selectedStartPoint-$_selectedEndPoint')
          : (widget.study.currentParagraph?.toString() ?? ''),
    );
    _notesController = TextEditingController();
    _nextStepController = TextEditingController(
      text: widget.study.nextTopic ?? (initialNext?.label ?? ''),
    );

    // Frequência do estudo
    final freq = widget.study.frequency.toLowerCase();
    int daysToAdd = 7;
    if (freq.contains('2x') || freq.contains('duas')) {
      daysToAdd = 3;
    } else if (freq.contains('quinzenal')) {
      daysToAdd = 14;
    } else if (freq.contains('mensal')) {
      daysToAdd = 28;
    }

    final target = DateTime.now().add(Duration(days: daysToAdd));
    _nextStudyDateTime = DateTime(target.year, target.month, target.day, 10, 0);

    _initPrimaryPersonAndUpcoming();
  }

  Future<void> _initPrimaryPersonAndUpcoming() async {
    final repo = ref.read(repositoryProvider);
    final participants = await repo.getParticipantsForStudy(widget.study.id);
    if (!mounted) return;

    final pId = widget.primaryPerson?.id ??
        (participants.isNotEmpty ? participants.first.personId : null);

    if (pId != null) {
      final allAppts = ref.read(appointmentsStreamProvider).value ?? [];
      final upcoming = allAppts
          .where((a) =>
              a.personId == pId &&
              a.startTime.isAfter(DateTime.now().subtract(const Duration(hours: 1))) &&
              a.status != 'cancelado' &&
              a.deletedAt == null)
          .toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));

      if (upcoming.isNotEmpty && mounted) {
        setState(() {
          _nextStudyDateTime = upcoming.first.startTime;
          _nextStudyDuration = upcoming.first.durationMinutes;
        });
      }
    }
  }

  @override
  void dispose() {
    _lessonController.dispose();
    _paragraphsController.dispose();
    _notesController.dispose();
    _nextStepController.dispose();
    super.dispose();
  }

  void _updatePoints(int startP, int endP) {
    setState(() {
      _selectedStartPoint = startP;
      _selectedEndPoint = endP;
      _paragraphsController.text = startP == endP ? '$startP' : '$startP-$endP';
      final next = LffBookCatalog.getNextProgression(
        currentLesson: _selectedLesson,
        currentPoint: _selectedEndPoint,
      );
      _nextStepController.text = next.label;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dialogIsDark = Theme.of(context).brightness == Brightness.dark;
    final allAppts = ref.watch(appointmentsStreamProvider).value ?? [];
    final lessonInfo = _isLff ? LffBookCatalog.getLesson(_selectedLesson) : null;
    final progressPercent = _isLff
        ? LffBookCatalog.calculateProgressPercentage(
            lesson: _selectedLesson,
            point: _selectedEndPoint,
          )
        : null;

    int currentUnitMaxPoints = 6;
    if (_isLff) {
      final foundUnit = _allUnits.where((u) => u.id == _selectedUnitId).firstOrNull;
      currentUnitMaxPoints = foundUnit?.totalPoints ?? (lessonInfo?.totalPoints ?? 6);
    }

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: AppTheme.primaryBlue),
          const SizedBox(width: 8),
          Expanded(child: Text('Registrar Sessão: ${widget.study.title}')),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status da sessão (Realizada vs Cancelada)
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Sessão Realizada')),
                    selected: _sessionOutcome == 'realizada',
                    selectedColor: AppTheme.primaryBlue.withValues(alpha: 0.2),
                    onSelected: (val) {
                      if (val) setState(() => _sessionOutcome = 'realizada');
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Cancelada')),
                    selected: _sessionOutcome == 'cancelada',
                    selectedColor: Colors.orange.shade100,
                    onSelected: (val) {
                      if (val) setState(() => _sessionOutcome = 'cancelada');
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Requisito 4: Switch de data retroativa
            SwitchListTile.adaptive(
              key: const ValueKey('retroactive_date_toggle'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Registrar com data retroativa', style: TextStyle(fontSize: 14)),
              subtitle: Text(
                _isRetroactive
                    ? 'Data selecionada: ${AppDateUtils.formatDateTime(_retroactiveDateTime)}'
                    : 'Padrão: Registrando agora (${AppDateUtils.formatDateTime(DateTime.now())})',
                style: const TextStyle(fontSize: 12),
              ),
              value: _isRetroactive,
              onChanged: (val) {
                setState(() {
                  _isRetroactive = val;
                  if (!val) _retroactiveDateTime = DateTime.now();
                });
              },
            ),
            if (_isRetroactive) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('retroactive_date_picker_button'),
                      icon: const Icon(Icons.event, size: 16),
                      label: Text(AppDateUtils.formatDate(_retroactiveDateTime)),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _retroactiveDateTime,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() {
                            _retroactiveDateTime = DateTime(
                              picked.year,
                              picked.month,
                              picked.day,
                              _retroactiveDateTime.hour,
                              _retroactiveDateTime.minute,
                            );
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.access_time, size: 16),
                      label: Text(
                        AppDateUtils.formatTimeOfDay(
                          TimeOfDay.fromDateTime(_retroactiveDateTime),
                        ),
                      ),
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(_retroactiveDateTime),
                        );
                        if (picked != null) {
                          setState(() {
                            _retroactiveDateTime = DateTime(
                              _retroactiveDateTime.year,
                              _retroactiveDateTime.month,
                              _retroactiveDateTime.day,
                              picked.hour,
                              picked.minute,
                            );
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            if (_sessionOutcome == 'cancelada') ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Motivo do cancelamento / imprevisto:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _failureMotive,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(
                          value: 'Cancelado pelo estudante',
                          child: Text('Cancelado pelo estudante'),
                        ),
                        DropdownMenuItem(
                          value: 'Estudante não estava em casa',
                          child: Text('Estudante não estava em casa'),
                        ),
                        DropdownMenuItem(
                          value: 'Imprevisto do publicador',
                          child: Text('Imprevisto do publicador'),
                        ),
                        DropdownMenuItem(
                          value: 'Problema de saúde',
                          child: Text('Problema de saúde'),
                        ),
                        DropdownMenuItem(
                          value: 'Outro',
                          child: Text('Outro motivo'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _failureMotive = val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ] else ...[
              // Seção da publicação LFF ou genérica
              if (_isLff) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: dialogIsDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: dialogIsDark ? const Color(0xFF334155) : const Color(0xFFBFDBFE),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.menu_book, size: 16, color: AppTheme.primaryBlue),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Seja Feliz Para Sempre! — Progresso: ${progressPercent?.toStringAsFixed(1)}%',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedUnitId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Unidade / Lição / Seção'),
                        items: _allUnits.map((u) {
                          return DropdownMenuItem<String>(
                            value: u.id,
                            child: Text(u.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedUnitId = val;
                              if (val.startsWith('lesson_')) {
                                _selectedLesson = int.tryParse(val.replaceFirst('lesson_', '')) ?? 1;
                                _lessonController.text = _selectedLesson.toString();
                              }
                              _updatePoints(1, 1);
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pontos considerados nesta sessão (1 a $currentUnitMaxPoints):',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: List.generate(currentUnitMaxPoints, (idx) {
                          final point = idx + 1;
                          final isCovered = point >= _selectedStartPoint && point <= _selectedEndPoint;
                          return FilterChip(
                            label: Text('§ $point'),
                            selected: isCovered,
                            onSelected: (_) {
                              if (point < _selectedStartPoint) {
                                _updatePoints(point, _selectedEndPoint);
                              } else if (point > _selectedEndPoint) {
                                _updatePoints(_selectedStartPoint, point);
                              } else {
                                _updatePoints(point, point);
                              }
                            },
                          );
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _lessonController,
                        decoration: const InputDecoration(
                          labelText: 'Lição / Capítulo',
                          hintText: 'Ex: 15',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _paragraphsController,
                        decoration: const InputDecoration(
                          labelText: 'Parágrafos / Pontos',
                          hintText: 'Ex: 1-3',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // Assistência aos Estudos (Attendance)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: dialogIsDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.people_outline, size: 20, color: AppTheme.primaryBlue),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Assistência / Ouvintes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text('Estudante + ouvintes presentes', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, size: 20),
                      onPressed: _attendanceCount > 1
                          ? () => setState(() => _attendanceCount--)
                          : null,
                    ),
                    Text(
                      '$_attendanceCount',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, size: 20),
                      onPressed: () => setState(() => _attendanceCount++),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Observações da sessão (opcional)',
                hintText: 'Ex: Demonstrou bom entendimento...',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nextStepController,
              decoration: const InputDecoration(
                labelText: 'Próximo passo / Onde parou',
                hintText: 'Ex: Lição 02, Ponto 1',
              ),
            ),
            const SizedBox(height: 14),

            // Agendamento do próximo estudo
            GlobalAppointmentSchedulingSection(
              title: 'Agendar Próximo Estudo',
              isEnabled: _scheduleNextStudy,
              onToggle: (v) => setState(() => _scheduleNextStudy = v),
              selectedDateTime: _nextStudyDateTime,
              onDateTimeChanged: (dt) => setState(() => _nextStudyDateTime = dt),
              durationMinutes: _nextStudyDuration,
              onDurationChanged: (d) => setState(() => _nextStudyDuration = d),
              existingAppointments: allAppts,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_scheduleNextStudy) {
              final avail = AvailabilityEngine.checkAvailability(
                startTime: _nextStudyDateTime,
                durationMinutes: _nextStudyDuration,
                existingAppointments: allAppts,
              );
              final canProceed = await GlobalAppointmentSchedulingSection.confirmConflictIfNeeded(
                context: context,
                availability: avail,
              );
              if (!canProceed) return;
            }

            final repo = ref.read(repositoryProvider);
            final participants = await repo.getParticipantsForStudy(widget.study.id);
            final primaryPId = widget.primaryPerson?.id ??
                (participants.isNotEmpty ? participants.first.personId : null);

            final sessionTimestamp = _isRetroactive ? _retroactiveDateTime : DateTime.now();

            if (_sessionOutcome == 'cancelada') {
              final formattedNotes = _notesController.text.trim().isEmpty
                  ? '[Sessão Cancelada: $_failureMotive]'
                  : '[Sessão Cancelada: $_failureMotive] ${_notesController.text.trim()}';

              await repo.createStudySession(
                studyId: widget.study.id,
                dateTime: sessionTimestamp,
                lessonCovered: widget.study.currentLesson,
                paragraphsCovered: null,
                sessionNotes: formattedNotes,
                nextStep: _nextStepController.text.trim().isEmpty ? null : _nextStepController.text.trim(),
                status: 'cancelada',
                participantIds: participants.map((p) => p.personId).toList(),
              );

              if (_nextStepController.text.trim().isNotEmpty) {
                await repo.updateStudy(
                  widget.study.copyWith(
                    nextTopic: Value(_nextStepController.text.trim()),
                  ),
                );
              }
            } else {
              final lesson = _isLff ? _selectedLesson : int.tryParse(_lessonController.text.trim());
              final formattedNotes = DashboardCalculator.formatSessionNotesWithAttendance(
                _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
                _attendanceCount,
              );

              await repo.createStudySession(
                studyId: widget.study.id,
                dateTime: sessionTimestamp,
                lessonCovered: lesson,
                paragraphsCovered: _paragraphsController.text.trim().isEmpty
                    ? null
                    : _paragraphsController.text.trim(),
                sessionNotes: formattedNotes,
                nextStep: _nextStepController.text.trim().isEmpty ? null : _nextStepController.text.trim(),
                status: 'realizada',
                participantIds: participants.map((p) => p.personId).toList(),
              );

              // Atualiza o estudo
              await repo.updateStudy(
                widget.study.copyWith(
                  currentLesson: Value(lesson),
                  currentParagraph: Value(
                    int.tryParse(_paragraphsController.text.trim()) ??
                        (_isLff ? _selectedEndPoint : null),
                  ),
                  nextTopic: Value(
                    _nextStepController.text.trim().isEmpty ? null : _nextStepController.text.trim(),
                  ),
                  lastSessionAt: Value(sessionTimestamp),
                ),
              );

              // Atualiza último contato das pessoas participantes
              for (final part in participants) {
                final p = await repo.getPersonById(part.personId);
                if (p != null) {
                  final shouldUpdate = p.lastContactAt == null || sessionTimestamp.isAfter(p.lastContactAt!);
                  if (shouldUpdate) {
                    await repo.updatePerson(
                      p.copyWith(lastContactAt: Value(sessionTimestamp)),
                    );
                  }
                }
              }
            }

            if (_scheduleNextStudy) {
              final existingAppts = ref.read(appointmentsStreamProvider).value ?? [];
              final existingOnDate = existingAppts.firstWhereOrNull(
                (a) =>
                    a.deletedAt == null &&
                    a.status != 'cancelado' &&
                    ((primaryPId != null && a.personId == primaryPId) ||
                        (a.studyId != null && a.studyId == widget.study.id)) &&
                    a.startTime.year == _nextStudyDateTime.year &&
                    a.startTime.month == _nextStudyDateTime.month &&
                    a.startTime.day == _nextStudyDateTime.day,
              );

              if (existingOnDate != null) {
                await repo.updateAppointment(
                  existingOnDate.copyWith(
                    studyId: Value(widget.study.id),
                    personId: Value(primaryPId),
                    startTime: _nextStudyDateTime,
                    endTime: _nextStudyDateTime.add(Duration(minutes: _nextStudyDuration)),
                    durationMinutes: _nextStudyDuration,
                    status: 'confirmado',
                  ),
                );
              } else {
                await repo.createAppointment(
                  personId: primaryPId,
                  studyId: widget.study.id,
                  title: 'Estudo Bíblico: ${widget.study.title}',
                  startTime: _nextStudyDateTime,
                  endTime: _nextStudyDateTime.add(Duration(minutes: _nextStudyDuration)),
                  durationMinutes: _nextStudyDuration,
                  status: 'confirmado',
                );
              }
            }

            widget.onRecorded?.call();
            if (context.mounted) Navigator.pop(context);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Sessão registrada com sucesso! ($_attendanceCount presentes computados)',
                  ),
                ),
              );
            }
          },
          child: const Text('Salvar Sessão'),
        ),
      ],
    );
  }
}
