import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../database/app_database.dart';
import '../providers.dart';

/// Diálogo para configuração do dia e horário habitual do contato (ex: "Sábado às 09:00").
class PersonPreferredScheduleDialog extends ConsumerStatefulWidget {
  final PersonEntry person;
  final Future<void> Function(String newSchedule)? onSave;

  const PersonPreferredScheduleDialog({
    super.key,
    required this.person,
    this.onSave,
  });

  static Future<void> show(
    BuildContext context, [
    dynamic arg1,
    PersonEntry? arg2,
  ]) {
    final PersonEntry p = (arg1 is PersonEntry)
        ? arg1
        : (arg2 ?? (throw ArgumentError('person is required')));
    return showDialog(
      context: context,
      builder: (ctx) => PersonPreferredScheduleDialog(
        person: p,
      ),
    );
  }

  @override
  ConsumerState<PersonPreferredScheduleDialog> createState() =>
      _PersonPreferredScheduleDialogState();
}

class _PersonPreferredScheduleDialogState
    extends ConsumerState<PersonPreferredScheduleDialog> {
  final List<String> _daysOfWeek = const [
    'Segunda-feira',
    'Terça-feira',
    'Quarta-feira',
    'Quinta-feira',
    'Sexta-feira',
    'Sábado',
    'Domingo',
    'Personalizado',
  ];

  late String _selectedDay;
  late TimeOfDay _selectedTime;
  late final TextEditingController _customController;
  bool _isCustom = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = 'Sábado';
    _selectedTime = const TimeOfDay(hour: 9, minute: 0);
    _customController = TextEditingController(
      text: widget.person.preferredSchedule ?? 'Sábado às 09:00',
    );

    final pref = widget.person.preferredSchedule;
    if (pref != null && pref.contains(' às ')) {
      final parts = pref.split(' às ');
      final dayCandidate = parts[0].trim();
      final timeCandidate = parts[1].trim();
      if (_daysOfWeek.contains(dayCandidate) && dayCandidate != 'Personalizado') {
        _selectedDay = dayCandidate;
      } else {
        _isCustom = true;
      }
      final timeParts = timeCandidate.split(':');
      if (timeParts.length == 2) {
        final h = int.tryParse(timeParts[0]);
        final m = int.tryParse(timeParts[1]);
        if (h != null && m != null) {
          _selectedTime = TimeOfDay(hour: h, minute: m);
        }
      }
    } else if (pref != null && pref.isNotEmpty) {
      _isCustom = true;
    }
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formattedTime =
        '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';
    final previewText = _isCustom
        ? _customController.text
        : '$_selectedDay às $formattedTime';

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.alarm, color: Color(0xFF7C3AED)),
          SizedBox(width: 8),
          Text('Dia e Horário Habitual'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Defina o dia e horário habitual do estudo bíblico (ex: "Sábado às 09:00").',
              style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 14),
            if (!_isCustom) ...[
              DropdownButtonFormField<String>(
                initialValue: _selectedDay,
                decoration: const InputDecoration(labelText: 'Dia da Semana'),
                items: _daysOfWeek
                    .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    if (val == 'Personalizado') {
                      setState(() => _isCustom = true);
                    } else {
                      setState(() => _selectedDay = val);
                    }
                  }
                },
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Horário Específico',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      Text(
                        formattedTime,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF7C3AED),
                        ),
                      ),
                    ],
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.access_time, size: 18),
                    label: const Text('Selecionar Hora'),
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _selectedTime,
                      );
                      if (picked != null) {
                        setState(() => _selectedTime = picked);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => setState(() => _isCustom = true),
                child: const Text('Escrever texto livre personalizado...'),
              ),
            ] else ...[
              TextField(
                controller: _customController,
                decoration: const InputDecoration(
                  labelText: 'Horário habitual personalizado',
                  hintText: 'Ex: Sábado às 09:00 ou Domingos após reunião',
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => setState(() => _isCustom = false),
                child: const Text('Voltar para seleção de dia e hora padrão'),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Color(0xFF7C3AED),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Será salvo como: "$previewText"',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF7C3AED),
                      ),
                    ),
                  ),
                ],
              ),
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
            final textToSave = _isCustom
                ? _customController.text.trim()
                : '$_selectedDay às $formattedTime';

            if (widget.onSave != null) {
              await widget.onSave!(textToSave);
            } else {
              final repo = ref.read(repositoryProvider);
              await repo.updatePerson(
                widget.person.copyWith(preferredSchedule: Value(textToSave)),
              );
            }

            if (context.mounted) Navigator.pop(context);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Horário habitual atualizado para "$textToSave"'),
                ),
              );
            }
          },
          child: const Text('Salvar Horário'),
        ),
      ],
    );
  }
}
