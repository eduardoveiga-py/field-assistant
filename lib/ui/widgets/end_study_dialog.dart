import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../database/app_database.dart';
import '../../database/repository.dart';
import '../providers.dart';

/// Diálogo unificado para encerramento de estudo bíblico com motivo estruturado e tombstones.
class EndStudyDialog extends ConsumerStatefulWidget {
  final BibleStudyEntry study;
  final PersonEntry? person;
  final VoidCallback? onEnded;

  const EndStudyDialog({
    super.key,
    required this.study,
    this.person,
    this.onEnded,
  });

  static Future<void> show(
    BuildContext context, {
    required BibleStudyEntry study,
    PersonEntry? person,
    AppRepository? repo,
    VoidCallback? onEnded,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => EndStudyDialog(
        study: study,
        person: person,
        onEnded: onEnded,
      ),
    );
  }

  static Future<void> reactivate(
    BuildContext context,
    dynamic refOrRepo,
    BibleStudyEntry study, {
    PersonEntry? person,
  }) async {
    final AppRepository repo = (refOrRepo is WidgetRef)
        ? refOrRepo.read(repositoryProvider)
        : (refOrRepo as AppRepository);
    await repo.updateStudy(
      study.copyWith(status: 'ativo', pauseOrCloseReason: const Value(null)),
    );

    if (person != null) {
      await repo.updatePerson(person.copyWith(status: 'estudo'));
    } else {
      final parts = await repo.getParticipantsForStudy(study.id);
      for (final part in parts) {
        final p = await repo.getPersonById(part.personId);
        if (p != null) {
          await repo.updatePerson(p.copyWith(status: 'estudo'));
        }
      }
    }

    if (context.mounted) {
      final nameOrTitle = person != null ? person.name : study.title;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Estudo "$nameOrTitle" reativado com sucesso!'),
        ),
      );
    }
  }

  @override
  ConsumerState<EndStudyDialog> createState() => _EndStudyDialogState();
}

class _EndStudyDialogState extends ConsumerState<EndStudyDialog> {
  String _selectedReason = 'Falta de interesse / tempo';
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.person?.name ?? widget.study.title;

    return AlertDialog(
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
              'Você está encerrando o estudo bíblico com "$displayName". O contato NÃO será excluído e continuará preservado no seu histórico.',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _selectedReason,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Motivo do Encerramento *',
              ),
              items: const [
                DropdownMenuItem(
                  value: 'Falta de interesse / tempo',
                  child: Text('Falta de interesse / tempo'),
                ),
                DropdownMenuItem(
                  value: 'Mudou-se de território',
                  child: Text('Mudou-se de território'),
                ),
                DropdownMenuItem(
                  value: 'Oposição familiar',
                  child: Text('Oposição familiar'),
                ),
                DropdownMenuItem(
                  value: 'Estudo concluído / Batizado',
                  child: Text('Estudo concluído / Batizado'),
                ),
                DropdownMenuItem(
                  value: 'Problemas de saúde',
                  child: Text('Problemas de saúde'),
                ),
                DropdownMenuItem(
                  value: 'Outro',
                  child: Text('Outro motivo'),
                ),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedReason = val);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Observação complementar (opcional)',
                hintText: 'Ex: Portas abertas para contato futuro...',
              ),
              maxLines: 2,
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
            backgroundColor: AppTheme.alertAmber,
            foregroundColor: Colors.black,
          ),
          onPressed: () async {
            final repo = ref.read(repositoryProvider);
            final reasonPayload = jsonEncode({
              'endReason': _selectedReason,
              'notes': _notesController.text.trim(),
              'endedAt': DateTime.now().toIso8601String(),
            });

            await repo.updateStudy(
              widget.study.copyWith(
                status: _selectedReason == 'Estudo concluído / Batizado'
                    ? 'concluido'
                    : 'encerrado',
                pauseOrCloseReason: Value(reasonPayload),
              ),
            );

            if (widget.person != null) {
              await repo.updatePerson(
                widget.person!.copyWith(status: 'revisita'),
              );
            } else {
              final parts = await repo.getParticipantsForStudy(widget.study.id);
              for (final part in parts) {
                final p = await repo.getPersonById(part.personId);
                if (p != null) {
                  await repo.updatePerson(p.copyWith(status: 'revisita'));
                }
              }
            }

            widget.onEnded?.call();

            if (context.mounted) Navigator.pop(context);

            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Estudo encerrado ($_selectedReason). Contatos mantidos como revisita!',
                  ),
                ),
              );
            }
          },
          child: const Text('Confirmar Encerramento'),
        ),
      ],
    );
  }
}
