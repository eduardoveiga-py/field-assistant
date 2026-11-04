import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../appointments/availability_engine.dart';
import '../../core/app_theme.dart';
import '../../core/date_utils.dart';
import '../../database/app_database.dart';
import '../../publications/publication_catalog.dart';
import '../providers.dart';
import 'global_appointment_scheduling_section.dart';

/// Diálogo unificado para criação e edição de estudos bíblicos.
class StudyFormDialog extends ConsumerStatefulWidget {
  final BibleStudyEntry? study; // null = Criação; non-null = Edição
  final String? initialPersonId;
  final VoidCallback? onSaved;

  const StudyFormDialog({
    super.key,
    this.study,
    this.initialPersonId,
    this.onSaved,
  });

  static Future<void> show(
    BuildContext context, {
    BibleStudyEntry? study,
    String? initialPersonId,
    VoidCallback? onSaved,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => StudyFormDialog(
        study: study,
        initialPersonId: initialPersonId,
        onSaved: onSaved,
      ),
    );
  }

  @override
  ConsumerState<StudyFormDialog> createState() => _StudyFormDialogState();
}

class _StudyFormDialogState extends ConsumerState<StudyFormDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _lessonController;
  late final TextEditingController _paragraphController;

  late String _selectedPublicationId;
  late String _selectedLanguage;
  late String _selectedFrequency;
  late String _selectedStatus;
  late DateTime _selectedStartedAt;
  DateTime? _selectedLastSessionAt;

  final List<String> _selectedPeopleIds = [];

  // Agendamento do primeiro estudo (apenas na criação com estudante específico)
  bool _scheduleFirstStudy = true;
  DateTime _firstStudyDateTime = DateTime.now().add(const Duration(days: 7));
  int _firstStudyDuration = 60;

  bool get _isEditing => widget.study != null;

  @override
  void initState() {
    super.initState();
    final study = widget.study;
    if (study != null) {
      _titleController = TextEditingController(text: study.title);
      _lessonController = TextEditingController(
        text: (study.currentLesson ?? 1).toString(),
      );
      _paragraphController = TextEditingController(
        text: (study.currentParagraph ?? 1).toString(),
      );
      _selectedPublicationId = study.publicationId;
      _selectedLanguage = study.language;
      _selectedFrequency = study.frequency;
      _selectedStatus = study.status;
      _selectedStartedAt = study.startedAt;
      _selectedLastSessionAt = study.lastSessionAt;
    } else {
      _titleController = TextEditingController();
      _lessonController = TextEditingController(text: '1');
      _paragraphController = TextEditingController(text: '1');
      _selectedPublicationId = 'lff-book';
      _selectedLanguage = 'pt';
      _selectedFrequency = 'semanal';
      _selectedStatus = 'ativo';
      _selectedStartedAt = DateTime.now();
      _selectedLastSessionAt = null;

      if (widget.initialPersonId != null) {
        _selectedPeopleIds.add(widget.initialPersonId!);
      }

      _firstStudyDateTime = DateTime(
        _firstStudyDateTime.year,
        _firstStudyDateTime.month,
        _firstStudyDateTime.day,
        10,
        0,
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _lessonController.dispose();
    _paragraphController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final people = ref.watch(peopleStreamProvider).value ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    PersonEntry? initialPerson;
    if (widget.initialPersonId != null) {
      initialPerson = people.where((p) => p.id == widget.initialPersonId).firstOrNull;
      if (_titleController.text.isEmpty && initialPerson != null) {
        _titleController.text = 'Estudo de ${initialPerson.name}';
      }
    }

    final dialogTitle = _isEditing
        ? 'Editar Dados do Estudo'
        : (initialPerson != null
            ? 'Iniciar Estudo: ${initialPerson.name}'
            : 'Novo Estudo Bíblico');

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            _isEditing ? Icons.edit_note : Icons.school,
            color: AppTheme.primaryBlue,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(dialogTitle)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_isEditing) ...[
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                  ),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Color(0xFF0284C7)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Estudo já em andamento? Defina a data real de início e a lição atual para que as estatísticas reflitam a realidade com precisão sem necessidade de sessões passadas fictícias.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF0369A1)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: _isEditing ? 'Título do estudo *' : 'Identificação / Título do estudo *',
                hintText: 'Ex: Estudo da Família Lima',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedStatus,
              decoration: InputDecoration(
                labelText: _isEditing ? 'Situação do Estudo' : 'Situação Inicial *',
              ),
              items: [
                const DropdownMenuItem(value: 'ativo', child: Text('Ativo (Em andamento)')),
                const DropdownMenuItem(value: 'pausado', child: Text('Pausado')),
                if (_isEditing) ...[
                  const DropdownMenuItem(value: 'concluido', child: Text('Concluído')),
                  const DropdownMenuItem(value: 'encerrado', child: Text('Encerrado')),
                ],
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedStatus = val);
              },
            ),
            const SizedBox(height: 12),
            // Data de Início Real
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(
                      'Início: ${AppDateUtils.formatDate(_selectedStartedAt)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedStartedAt,
                        firstDate: DateTime(2010),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() => _selectedStartedAt = picked);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Lição Atual e Ponto Atual
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _lessonController,
                    decoration: InputDecoration(
                      labelText: _isEditing ? 'Lição Atual' : 'Lição Atual *',
                      hintText: 'Ex: 15',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _paragraphController,
                    decoration: const InputDecoration(
                      labelText: 'Ponto / §',
                      hintText: 'Ex: 1',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Data da última sessão realizada (opcional)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.history, size: 16),
                    label: Text(
                      _selectedLastSessionAt != null
                          ? 'Última Sessão: ${AppDateUtils.formatDate(_selectedLastSessionAt!)}'
                          : 'Última Sessão (opcional)',
                      style: const TextStyle(fontSize: 12),
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedLastSessionAt ?? _selectedStartedAt,
                        firstDate: DateTime(2010),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() => _selectedLastSessionAt = picked);
                      }
                    },
                  ),
                ),
                if (_selectedLastSessionAt != null)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    tooltip: 'Remover data',
                    onPressed: () => setState(() => _selectedLastSessionAt = null),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedPublicationId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Publicação'),
              items: PublicationCatalog.allPublications.map((p) {
                return DropdownMenuItem(
                  value: p.id,
                  child: Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedPublicationId = val);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedLanguage,
              decoration: const InputDecoration(labelText: 'Idioma do estudo'),
              items: const [
                DropdownMenuItem(value: 'pt', child: Text('Português')),
                DropdownMenuItem(value: 'bzs', child: Text('Libras (Língua de Sinais)')),
                DropdownMenuItem(value: 'tca', child: Text('Ticuna')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedLanguage = val);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedFrequency,
              decoration: const InputDecoration(labelText: 'Frequência do estudo'),
              items: const [
                DropdownMenuItem(value: 'semanal', child: Text('Semanal (1x por semana)')),
                DropdownMenuItem(value: 'duas_vezes_semana', child: Text('Intensivo (2x por semana)')),
                DropdownMenuItem(value: 'quinzenal', child: Text('Quinzenal (A cada 15 dias)')),
                DropdownMenuItem(value: 'variavel', child: Text('Variável / Flexível')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedFrequency = val);
              },
            ),
            if (!_isEditing && widget.initialPersonId == null) ...[
              const SizedBox(height: 14),
              const Text(
                'Quem participa ou acompanha o estudo:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Text(
                'Selecione o estudante principal e os acompanhantes (ex: casal ou familiares):',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFFCBD5E1) : AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 6),
              if (people.isEmpty)
                const Text('Cadastre pessoas na aba Contatos para vinculá-las ao estudo.')
              else
                Wrap(
                  spacing: 8,
                  children: people.map((p) {
                    final isSelected = _selectedPeopleIds.contains(p.id);
                    return FilterChip(
                      label: Text(p.name),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedPeopleIds.add(p.id);
                            if (_titleController.text.isEmpty) {
                              _titleController.text = 'Estudo de ${p.name}';
                            }
                          } else {
                            _selectedPeopleIds.remove(p.id);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
            ],
            if (!_isEditing && initialPerson != null) ...[
              const SizedBox(height: 14),
              GlobalAppointmentSchedulingSection(
                title: 'Agendar Primeiro Estudo na Agenda',
                isEnabled: _scheduleFirstStudy,
                onToggle: (v) => setState(() => _scheduleFirstStudy = v),
                selectedDateTime: _firstStudyDateTime,
                onDateTimeChanged: (dt) => setState(() => _firstStudyDateTime = dt),
                durationMinutes: _firstStudyDuration,
                onDurationChanged: (d) => setState(() => _firstStudyDuration = d),
                existingAppointments: ref.watch(appointmentsStreamProvider).value ?? [],
              ),
            ],
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
            final title = _titleController.text.trim();
            if (title.isEmpty) return;

            final lesson = int.tryParse(_lessonController.text.trim()) ?? 1;
            final paragraph = int.tryParse(_paragraphController.text.trim()) ?? 1;
            final repo = ref.read(repositoryProvider);

            if (_isEditing) {
              await repo.updateStudy(
                widget.study!.copyWith(
                  title: title,
                  status: _selectedStatus,
                  startedAt: _selectedStartedAt,
                  lastSessionAt: Value(_selectedLastSessionAt),
                  publicationId: _selectedPublicationId,
                  language: _selectedLanguage,
                  currentLesson: Value(lesson),
                  currentParagraph: Value(paragraph),
                  frequency: _selectedFrequency,
                ),
              );

              widget.onSaved?.call();
              if (context.mounted) Navigator.pop(context);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Dados do estudo atualizados com sucesso!'),
                  ),
                );
              }
            } else {
              if (_selectedPeopleIds.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Informe o título e selecione pelo menos um participante.'),
                  ),
                );
                return;
              }

              if (initialPerson != null && _scheduleFirstStudy) {
                final allAppts = ref.read(appointmentsStreamProvider).value ?? [];
                final avail = AvailabilityEngine.checkAvailability(
                  startTime: _firstStudyDateTime,
                  durationMinutes: _firstStudyDuration,
                  existingAppointments: allAppts,
                );
                final canProceed = await GlobalAppointmentSchedulingSection.confirmConflictIfNeeded(
                  context: context,
                  availability: avail,
                );
                if (!canProceed) return;
              }

              await repo.createStudy(
                title: title,
                publicationId: _selectedPublicationId,
                language: _selectedLanguage,
                status: _selectedStatus,
                startedAt: _selectedStartedAt,
                lastSessionAt: _selectedLastSessionAt,
                currentLesson: lesson,
                currentParagraph: paragraph,
                frequency: _selectedFrequency,
                participantPersonIds: _selectedPeopleIds,
                primaryParticipantId: widget.initialPersonId,
              );

              for (final pId in _selectedPeopleIds) {
                final p = await repo.getPersonById(pId);
                if (p != null) {
                  final shouldUpdateContact = _selectedLastSessionAt != null &&
                      (p.lastContactAt == null || _selectedLastSessionAt!.isAfter(p.lastContactAt!));
                  if (p.status != 'estudo' || shouldUpdateContact) {
                    await repo.updatePerson(
                      p.copyWith(
                        status: 'estudo',
                        lastContactAt: shouldUpdateContact
                            ? Value(_selectedLastSessionAt)
                            : Value(p.lastContactAt),
                      ),
                    );
                  }
                }
              }

              if (initialPerson != null && _scheduleFirstStudy) {
                await repo.createAppointment(
                  personId: initialPerson.id,
                  title: 'Estudo Bíblico: ${initialPerson.name}',
                  startTime: _firstStudyDateTime,
                  endTime: _firstStudyDateTime.add(Duration(minutes: _firstStudyDuration)),
                  durationMinutes: _firstStudyDuration,
                  status: 'confirmado',
                  locationNotes: initialPerson.address != null ? 'Local: ${initialPerson.address}' : null,
                );
              }

              widget.onSaved?.call();
              if (context.mounted) Navigator.pop(context);
              if (context.mounted) {
                final msg = initialPerson != null
                    ? 'Estudo Bíblico iniciado com sucesso com ${initialPerson.name}!'
                    : 'Estudo cadastrado com sucesso!';
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
              }
            }
          },
          child: Text(_isEditing ? 'Salvar Alterações' : (initialPerson != null ? 'Iniciar Estudo' : 'Cadastrar Estudo')),
        ),
      ],
    );
  }
}
