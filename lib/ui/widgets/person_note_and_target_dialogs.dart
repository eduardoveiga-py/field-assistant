import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../contacts/doorstep_briefing_helper.dart';
import '../../core/app_theme.dart';
import '../../core/date_utils.dart';
import '../../database/app_database.dart';
import '../../database/repository.dart';

/// Helper de persistência e parsing de Notas/Necessidades e Alvos/Metas espirituais.
class PersonNotesAndTargetsHelper {
  static List<Map<String, dynamic>> parseNotes(String? raw) {
    return DoorstepBriefingHelper.parseNotes(raw);
  }

  static Future<void> saveNotes(
    AppRepository repo,
    PersonEntry person,
    List<Map<String, dynamic>> notes,
  ) async {
    final jsonStr = notes.isEmpty ? null : jsonEncode(notes);
    await repo.updatePerson(person.copyWith(generalNotes: Value(jsonStr)));
  }

  static List<Map<String, dynamic>> parseTargets(String? raw) {
    return DoorstepBriefingHelper.parseTargets(raw);
  }

  static Future<void> saveTargets(
    AppRepository repo,
    PersonEntry person,
    List<Map<String, dynamic>> targets,
  ) async {
    final jsonStr = targets.isEmpty ? null : jsonEncode(targets);
    await repo.updatePerson(
      person.copyWith(contactRestrictions: Value(jsonStr)),
    );
  }
}

/// Diálogo para adicionar ou editar Necessidade / Observação estruturada com timestamp.
class PersonNoteDialog extends StatefulWidget {
  final AppRepository repo;
  final PersonEntry person;
  final Map<String, dynamic>? noteToEdit;
  final VoidCallback? onSaved;

  const PersonNoteDialog({
    super.key,
    required this.repo,
    required this.person,
    this.noteToEdit,
    this.onSaved,
  });

  static Future<void> show({
    required BuildContext context,
    required AppRepository repo,
    required PersonEntry person,
    Map<String, dynamic>? noteToEdit,
    VoidCallback? onSaved,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => PersonNoteDialog(
        repo: repo,
        person: person,
        noteToEdit: noteToEdit,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<PersonNoteDialog> createState() => _PersonNoteDialogState();
}

class _PersonNoteDialogState extends State<PersonNoteDialog> {
  late final TextEditingController _textController;
  bool get _isEditing => widget.noteToEdit != null;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(
      text: widget.noteToEdit?['text'] ?? '',
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.note_alt_outlined, color: AppTheme.accentTeal),
          const SizedBox(width: 8),
          Text(
            _isEditing
                ? 'Editar Necessidade / Obs.'
                : 'Nova Necessidade / Obs.',
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Registre circunstâncias familiares, dúvidas levantadas, assuntos de interesse ou necessidades de ${widget.person.name}.',
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _textController,
              decoration: const InputDecoration(
                labelText: 'Descrição da necessidade ou observação *',
                hintText:
                    'Ex: Perdeu um familiar, tem dúvidas sobre a oração, etc.',
              ),
              maxLines: 4,
              autofocus: true,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.access_time,
                  size: 14,
                  color: AppTheme.textMuted,
                ),
                const SizedBox(width: 6),
                Text(
                  _isEditing
                      ? 'Criado em: ${AppDateUtils.formatDateTimeWithAt(DateTime.tryParse(widget.noteToEdit!['createdAt'] ?? ''))}'
                      : 'Registro de data e hora automático.',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
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
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accentTeal,
            foregroundColor: Colors.white,
          ),
          onPressed: () async {
            final text = _textController.text.trim();
            if (text.isEmpty) return;

            final currentNotes = PersonNotesAndTargetsHelper.parseNotes(
              widget.person.generalNotes,
            );
            if (_isEditing) {
              final idx = currentNotes.indexWhere(
                (n) => n['id'] == widget.noteToEdit!['id'],
              );
              if (idx != -1) {
                currentNotes[idx] = {
                  ...currentNotes[idx],
                  'text': text,
                  'updatedAt': DateTime.now().toIso8601String(),
                };
              }
            } else {
              currentNotes.insert(0, {
                'id': const Uuid().v4(),
                'text': text,
                'createdAt': DateTime.now().toIso8601String(),
              });
            }

            await PersonNotesAndTargetsHelper.saveNotes(
              widget.repo,
              widget.person,
              currentNotes,
            );
            widget.onSaved?.call();

            if (context.mounted) Navigator.pop(context);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _isEditing
                        ? 'Anotação atualizada!'
                        : 'Necessidade/observação registrada com data e hora!',
                  ),
                ),
              );
            }
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

/// Diálogo para adicionar ou editar Alvo ou Tarefa Espiritual.
class PersonTargetDialog extends StatefulWidget {
  final AppRepository repo;
  final PersonEntry person;
  final Map<String, dynamic>? targetToEdit;
  final VoidCallback? onSaved;

  const PersonTargetDialog({
    super.key,
    required this.repo,
    required this.person,
    this.targetToEdit,
    this.onSaved,
  });

  static Future<void> show({
    required BuildContext context,
    required AppRepository repo,
    required PersonEntry person,
    Map<String, dynamic>? targetToEdit,
    VoidCallback? onSaved,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => PersonTargetDialog(
        repo: repo,
        person: person,
        targetToEdit: targetToEdit,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<PersonTargetDialog> createState() => _PersonTargetDialogState();
}

class _PersonTargetDialogState extends State<PersonTargetDialog> {
  late final TextEditingController _titleController;
  bool get _isEditing => widget.targetToEdit != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.targetToEdit?['title'] ?? '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.track_changes, color: Color(0xFF7C3AED)),
          const SizedBox(width: 8),
          Text(
            _isEditing
                ? 'Editar Alvo / Tarefa'
                : 'Novo Alvo ou Tarefa Espiritual',
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Defina um alvo espiritual ou tarefa deixada para ${widget.person.name} até a próxima visita.',
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Descrição do alvo ou tarefa *',
                hintText:
                    'Ex: Ler o Salmo 37, baixar o JW Library, ver vídeo da Lição 01...',
              ),
              maxLines: 3,
              autofocus: true,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.access_time,
                  size: 14,
                  color: AppTheme.textMuted,
                ),
                const SizedBox(width: 6),
                Text(
                  _isEditing
                      ? 'Criado em: ${AppDateUtils.formatDateTimeWithAt(DateTime.tryParse(widget.targetToEdit!['createdAt'] ?? ''))}'
                      : 'Data e hora da criação gravadas automaticamente.',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
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
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7C3AED),
            foregroundColor: Colors.white,
          ),
          onPressed: () async {
            final title = _titleController.text.trim();
            if (title.isEmpty) return;

            final currentTargets = PersonNotesAndTargetsHelper.parseTargets(
              widget.person.contactRestrictions,
            );
            if (_isEditing) {
              final idx = currentTargets.indexWhere(
                (t) => t['id'] == widget.targetToEdit!['id'],
              );
              if (idx != -1) {
                currentTargets[idx] = {
                  ...currentTargets[idx],
                  'title': title,
                };
              }
            } else {
              currentTargets.insert(0, {
                'id': const Uuid().v4(),
                'title': title,
                'isCompleted': false,
                'createdAt': DateTime.now().toIso8601String(),
                'completedAt': null,
              });
            }

            await PersonNotesAndTargetsHelper.saveTargets(
              widget.repo,
              widget.person,
              currentTargets,
            );
            widget.onSaved?.call();

            if (context.mounted) Navigator.pop(context);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _isEditing
                        ? 'Alvo atualizado!'
                        : 'Novo alvo cadastrado com sucesso!',
                  ),
                ),
              );
            }
          },
          child: const Text('Salvar Alvo'),
        ),
      ],
    );
  }
}
