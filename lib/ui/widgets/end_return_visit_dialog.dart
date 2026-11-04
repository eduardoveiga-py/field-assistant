import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../database/app_database.dart';
import '../../database/repository.dart';

/// Diálogo unificado para encerramento estruturado de acompanhamento de revisita.
class EndReturnVisitDialog extends StatefulWidget {
  final AppRepository repo;
  final PersonEntry person;

  const EndReturnVisitDialog({
    super.key,
    required this.repo,
    required this.person,
  });

  static Future<void> show(
    BuildContext context,
    AppRepository repo,
    PersonEntry person,
  ) {
    return showDialog(
      context: context,
      builder: (ctx) => EndReturnVisitDialog(repo: repo, person: person),
    );
  }

  static Future<void> reactivate(
    BuildContext context,
    AppRepository repo,
    PersonEntry person,
  ) async {
    await repo.updatePerson(
      person.copyWith(
        status: 'revisita',
        nextActionNote: const Value(null),
      ),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Revisita com "${person.name}" reativada com sucesso!'),
        ),
      );
    }
  }

  @override
  State<EndReturnVisitDialog> createState() => _EndReturnVisitDialogState();
}

class _EndReturnVisitDialogState extends State<EndReturnVisitDialog> {
  String _selectedReason = 'Falta de interesse / tempo';
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.person_off_outlined, color: AppTheme.alertAmber),
          SizedBox(width: 8),
          Expanded(child: Text('Encerrar Revisita')),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Você está encerrando o acompanhamento de revisitas com ${widget.person.name}. O contato NÃO será excluído e todas as visitas anteriores continuam preservadas no seu relatório e histórico.',
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
                  value: 'Pediu para não ser visitado',
                  child: Text('Pediu para não ser visitado'),
                ),
                DropdownMenuItem(
                  value: 'Oposição familiar',
                  child: Text('Oposição familiar'),
                ),
                DropdownMenuItem(
                  value: 'Problemas de saúde / Falecido',
                  child: Text('Problemas de saúde / Falecido'),
                ),
                DropdownMenuItem(
                  value: 'Repassada para outro publicador',
                  child: Text('Repassada para outro publicador'),
                ),
                DropdownMenuItem(
                  value: 'Outro',
                  child: Text('Outro motivo'),
                ),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedReason = val);
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Observação complementar (opcional)',
                hintText:
                    'Ex: Deixou portas abertas para uma ocasião futura...',
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
            final reasonPayload = jsonEncode({
              'endReason': _selectedReason,
              'notes': _notesController.text.trim(),
              'endedAt': DateTime.now().toIso8601String(),
            });
            await widget.repo.updatePerson(
              widget.person.copyWith(
                status: 'revisita_encerrada',
                nextActionNote: Value(
                  'Revisita encerrada: $_selectedReason${_notesController.text.trim().isNotEmpty ? " - ${_notesController.text.trim()}" : ""}',
                ),
                contactRestrictions: Value(
                  widget.person.contactRestrictions == null ||
                          widget.person.contactRestrictions!.isEmpty
                      ? reasonPayload
                      : widget.person.contactRestrictions,
                ),
              ),
            );
            if (context.mounted) Navigator.pop(context);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Revisita encerrada ($_selectedReason). Registro mantido no histórico!',
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
