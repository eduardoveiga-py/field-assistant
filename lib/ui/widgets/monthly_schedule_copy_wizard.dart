import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../database/app_database.dart';
import '../../appointments/calendar_sync_coordinator.dart';
import '../providers.dart';

class CopyWizardRoutine {
  final String id;
  String title;
  int weekday;
  int hour;
  int minute;
  int durationMinutes;
  String frequency;
  int secondWeekday;
  bool isEnabled;
  bool isExpanded;
  final String? personId;
  final String? notes;

  CopyWizardRoutine({
    required this.id,
    required this.title,
    required this.weekday,
    required this.hour,
    required this.minute,
    required this.durationMinutes,
    required this.frequency,
    required this.secondWeekday,
    required this.isEnabled,
    required this.isExpanded,
    this.personId,
    this.notes,
  });
}

class MonthlyScheduleCopyWizardDialog extends ConsumerStatefulWidget {
  final DateTime selectedDate;
  final List<AppointmentEntry> allAppointments;
  final VoidCallback? onCompleted;

  const MonthlyScheduleCopyWizardDialog({
    super.key,
    required this.selectedDate,
    required this.allAppointments,
    this.onCompleted,
  });

  static Future<void> show(
    BuildContext context, {
    required DateTime selectedDate,
    required List<AppointmentEntry> allAppointments,
    VoidCallback? onCompleted,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => MonthlyScheduleCopyWizardDialog(
        selectedDate: selectedDate,
        allAppointments: allAppointments,
        onCompleted: onCompleted,
      ),
    );
  }

  @override
  ConsumerState<MonthlyScheduleCopyWizardDialog> createState() =>
      _MonthlyScheduleCopyWizardDialogState();
}

class _MonthlyScheduleCopyWizardDialogState
    extends ConsumerState<MonthlyScheduleCopyWizardDialog> {
  late int sourceYear;
  late int sourceMonth;
  late int targetYear;
  late int targetMonth;
  late List<CopyWizardRoutine> wizardRoutines;

  static String getMonthName(int month) {
    const months = [
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro',
    ];
    if (month >= 1 && month <= 12) return months[month - 1];
    return '';
  }

  @override
  void initState() {
    super.initState();
    sourceYear = widget.selectedDate.year;
    sourceMonth = widget.selectedDate.month;
    targetYear = sourceMonth == 12 ? sourceYear + 1 : sourceYear;
    targetMonth = sourceMonth == 12 ? 1 : sourceMonth + 1;

    final sourceAppts = widget.allAppointments
        .where(
          (a) =>
              a.deletedAt == null &&
              a.status != 'cancelado' &&
              a.startTime.year == sourceYear &&
              a.startTime.month == sourceMonth,
        )
        .toList();

    wizardRoutines = [];
    final seen = <String>{};
    for (final a in sourceAppts) {
      final key =
          '${a.title}_${a.startTime.weekday}_${a.startTime.hour}_${a.startTime.minute}';
      if (!seen.contains(key)) {
        seen.add(key);
        wizardRoutines.add(
          CopyWizardRoutine(
            id: key,
            title: a.title,
            weekday: a.startTime.weekday,
            hour: a.startTime.hour,
            minute: a.startTime.minute,
            durationMinutes: a.durationMinutes,
            frequency: 'semanal',
            secondWeekday: (a.startTime.weekday + 3) % 7 == 0
                ? 7
                : (a.startTime.weekday + 3) % 7,
            isEnabled: true,
            isExpanded: false,
            personId: a.personId,
            notes: a.locationNotes,
          ),
        );
      }
    }
  }

  void _triggerBackgroundCalendarSync() {
    ref.read(calendarSyncCoordinatorProvider).syncAll().ignore();
  }

  List<DateTime> _calculateRoutineDates(
    CopyWizardRoutine r,
    int daysInTargetMonth,
  ) {
    final primaryMatches = <DateTime>[];
    final secondMatches = <DateTime>[];

    for (int day = 1; day <= daysInTargetMonth; day++) {
      final candidate = DateTime(
        targetYear,
        targetMonth,
        day,
        r.hour,
        r.minute,
      );
      if (candidate.weekday == r.weekday) {
        primaryMatches.add(candidate);
      } else if (r.frequency == '2x_semana' &&
          candidate.weekday == r.secondWeekday) {
        secondMatches.add(candidate);
      }
    }

    if (r.frequency == 'semanal') {
      return primaryMatches;
    } else if (r.frequency == 'quinzenal_1_3') {
      final res = <DateTime>[];
      for (int i = 0; i < primaryMatches.length; i++) {
        if (i % 2 == 0) res.add(primaryMatches[i]);
      }
      return res;
    } else if (r.frequency == 'quinzenal_2_4') {
      final res = <DateTime>[];
      for (int i = 0; i < primaryMatches.length; i++) {
        if (i % 2 == 1) res.add(primaryMatches[i]);
      }
      return res;
    } else if (r.frequency == 'mensal') {
      return primaryMatches.isNotEmpty ? [primaryMatches.first] : [];
    } else if (r.frequency == '2x_semana') {
      final combined = [...primaryMatches, ...secondMatches]..sort();
      return combined;
    }
    return primaryMatches;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final targetExistingAppts = widget.allAppointments
        .where(
          (a) =>
              a.deletedAt == null &&
              a.status != 'cancelado' &&
              a.startTime.year == targetYear &&
              a.startTime.month == targetMonth,
        )
        .toList();

    final daysInTargetMonth = DateTime(targetYear, targetMonth + 1, 0).day;

    int totalPendingToCreate = 0;
    for (final r in wizardRoutines.where((r) => r.isEnabled)) {
      final dates = _calculateRoutineDates(r, daysInTargetMonth);
      for (final dt in dates) {
        final hasDuplicate = targetExistingAppts.any((existing) {
          final sameTitle =
              existing.title.trim().toLowerCase() ==
              r.title.trim().toLowerCase();
          final timeDiff = existing.startTime.difference(dt).inMinutes.abs();
          return sameTitle && timeDiff < 15;
        });
        if (!hasDuplicate) totalPendingToCreate++;
      }
    }

    const weekdayLabels = [
      'Segunda',
      'Terça',
      'Quarta',
      'Quinta',
      'Sexta',
      'Sábado',
      'Domingo',
    ];

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.copy_all_rounded, color: AppTheme.primaryBlue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Assistente: Replicar Programação',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppTheme.textDark,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Replica com segurança as rotinas do ministério, revisitas e estudos de um mês para o outro. '
                'Você pode confirmar, editar frequência, dia, hora ou remover cada atividade antes de agendar.',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF94A3B8) : AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Origem:',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                          Text(
                            '${getMonthName(sourceMonth)} $sourceYear',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      Icons.arrow_forward,
                      size: 18,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Destino:',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.accentTeal,
                            ),
                          ),
                          Text(
                            '${getMonthName(targetMonth)} $targetYear',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Rotinas Identificadas no Mês (${wizardRoutines.length}):',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    '${wizardRoutines.where((r) => r.isEnabled).length} ativa(s)',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (wizardRoutines.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text(
                      'Nenhuma rotina ou compromisso ativo encontrado no mês de origem.',
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ),
                )
              else
                ...wizardRoutines.map((r) {
                  final targetDates = _calculateRoutineDates(
                    r,
                    daysInTargetMonth,
                  );
                  int alreadyExistsCount = 0;
                  int freeCount = 0;
                  for (final dt in targetDates) {
                    final hasDuplicate = targetExistingAppts.any((existing) {
                      final sameTitle =
                          existing.title.trim().toLowerCase() ==
                          r.title.trim().toLowerCase();
                      final timeDiff = existing.startTime
                          .difference(dt)
                          .inMinutes
                          .abs();
                      return sameTitle && timeDiff < 15;
                    });
                    if (hasDuplicate) {
                      alreadyExistsCount++;
                    } else {
                      freeCount++;
                    }
                  }

                  final weekdayName = weekdayLabels[r.weekday - 1];
                  final timeStr =
                      '${r.hour.toString().padLeft(2, '0')}:${r.minute.toString().padLeft(2, '0')}';
                  final freqLabel = r.frequency == 'semanal'
                      ? 'Semanal'
                      : r.frequency == 'quinzenal_1_3'
                      ? 'Quinzenal (1ª e 3ª semana)'
                      : r.frequency == 'quinzenal_2_4'
                      ? 'Quinzenal (2ª e 4ª semana)'
                      : r.frequency == 'mensal'
                      ? 'Mensal (1x)'
                      : '2x por semana ($weekdayName e ${weekdayLabels[r.secondWeekday - 1]})';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: !r.isEnabled
                            ? Colors.grey.withValues(alpha: 0.3)
                            : r.isExpanded
                            ? AppTheme.primaryBlue
                            : (freeCount > 0
                                  ? (isDark
                                        ? const Color(0xFF334155)
                                        : const Color(0xFFCBD5E1))
                                  : AppTheme.alertAmber.withValues(alpha: 0.5)),
                        width: r.isExpanded ? 1.5 : 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              Checkbox(
                                value: r.isEnabled,
                                activeColor: AppTheme.primaryBlue,
                                onChanged: (val) {
                                  setState(() {
                                    r.isEnabled = val ?? false;
                                  });
                                },
                              ),
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryBlue.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  r.title.toLowerCase().contains('estudo')
                                      ? Icons.menu_book
                                      : r.title.toLowerCase().contains(
                                          'revisita',
                                        )
                                      ? Icons.repeat
                                      : Icons.directions_walk,
                                  size: 18,
                                  color: r.isEnabled
                                      ? AppTheme.primaryBlue
                                      : Colors.grey,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      r.title,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        decoration: r.isEnabled
                                            ? null
                                            : TextDecoration.lineThrough,
                                        color: r.isEnabled ? null : Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$weekdayName às $timeStr (${r.durationMinutes} min) • $freqLabel',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark
                                            ? const Color(0xFF94A3B8)
                                            : AppTheme.textMuted,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 6,
                                      children: [
                                        if (freeCount > 0 && r.isEnabled)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppTheme.successGreen
                                                  .withValues(alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '✅ $freeCount data(s) a criar',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.successGreen,
                                              ),
                                            ),
                                          ),
                                        if (alreadyExistsCount > 0 &&
                                            r.isEnabled)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppTheme.alertAmber
                                                  .withValues(alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '⚠️ $alreadyExistsCount data(s) já existente(s)',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.alertAmber,
                                              ),
                                            ),
                                          ),
                                        if (!r.isEnabled)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.withValues(
                                                alpha: 0.15,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'Desmarcado para este mês',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  r.isExpanded
                                      ? Icons.expand_less
                                      : Icons.tune,
                                  size: 18,
                                ),
                                tooltip: r.isExpanded
                                    ? 'Fechar detalhes'
                                    : 'Alterar dia, hora, frequência...',
                                color: r.isExpanded
                                    ? AppTheme.primaryBlue
                                    : AppTheme.textMuted,
                                onPressed: () {
                                  setState(() {
                                    r.isExpanded = !r.isExpanded;
                                  });
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: AppTheme.alertRed,
                                ),
                                tooltip: 'Excluir esta rotina',
                                onPressed: () {
                                  setState(() {
                                    wizardRoutines.remove(r);
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        if (r.isExpanded) ...[
                          const Divider(height: 1),
                          Container(
                            padding: const EdgeInsets.all(12),
                            color: isDark
                                ? const Color(0xFF0F172A)
                                : const Color(0xFFF8FAFC),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Personalizar Programação para o Mês de Destino:',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryBlue,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: DropdownButtonFormField<int>(
                                        initialValue: r.weekday,
                                        decoration: const InputDecoration(
                                          labelText: 'Dia da Semana',
                                          isDense: true,
                                        ),
                                        items: List.generate(7, (i) {
                                          return DropdownMenuItem(
                                            value: i + 1,
                                            child: Text(
                                              weekdayLabels[i],
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                          );
                                        }),
                                        onChanged: (val) {
                                          if (val != null) {
                                            setState(() => r.weekday = val);
                                          }
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: InkWell(
                                        onTap: () async {
                                          final picked = await showTimePicker(
                                            context: context,
                                            initialTime: TimeOfDay(
                                              hour: r.hour,
                                              minute: r.minute,
                                            ),
                                          );
                                          if (picked != null) {
                                            setState(() {
                                              r.hour = picked.hour;
                                              r.minute = picked.minute;
                                            });
                                          }
                                        },
                                        child: InputDecorator(
                                          decoration: const InputDecoration(
                                            labelText: 'Horário',
                                            isDense: true,
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                timeStr,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const Icon(
                                                Icons.access_time,
                                                size: 16,
                                                color: AppTheme.primaryBlue,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: DropdownButtonFormField<String>(
                                        initialValue: r.frequency,
                                        decoration: const InputDecoration(
                                          labelText:
                                              'Frequência do Estudo/Revisita',
                                          isDense: true,
                                        ),
                                        items: const [
                                          DropdownMenuItem(
                                            value: 'semanal',
                                            child: Text(
                                              'Semanal (Toda semana)',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          ),
                                          DropdownMenuItem(
                                            value: 'quinzenal_1_3',
                                            child: Text(
                                              'Quinzenal (1ª e 3ª semana)',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          ),
                                          DropdownMenuItem(
                                            value: 'quinzenal_2_4',
                                            child: Text(
                                              'Quinzenal (2ª e 4ª semana)',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          ),
                                          DropdownMenuItem(
                                            value: 'mensal',
                                            child: Text(
                                              'Mensal (1ª ocorrência)',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          ),
                                          DropdownMenuItem(
                                            value: '2x_semana',
                                            child: Text(
                                              '2x por semana',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          ),
                                        ],
                                        onChanged: (val) {
                                          if (val != null) {
                                            setState(() => r.frequency = val);
                                          }
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 2,
                                      child: DropdownButtonFormField<int>(
                                        initialValue: r.durationMinutes,
                                        decoration: const InputDecoration(
                                          labelText: 'Duração',
                                          isDense: true,
                                        ),
                                        items: const [
                                          DropdownMenuItem(
                                            value: 15,
                                            child: Text(
                                              '15 min',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          ),
                                          DropdownMenuItem(
                                            value: 20,
                                            child: Text(
                                              '20 min',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          ),
                                          DropdownMenuItem(
                                            value: 30,
                                            child: Text(
                                              '30 min',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          ),
                                          DropdownMenuItem(
                                            value: 45,
                                            child: Text(
                                              '45 min',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          ),
                                          DropdownMenuItem(
                                            value: 60,
                                            child: Text(
                                              '60 min',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          ),
                                          DropdownMenuItem(
                                            value: 90,
                                            child: Text(
                                              '90 min',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          ),
                                          DropdownMenuItem(
                                            value: 120,
                                            child: Text(
                                              '120 min',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          ),
                                        ],
                                        onChanged: (val) {
                                          if (val != null) {
                                            setState(
                                              () => r.durationMinutes = val,
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                if (r.frequency == '2x_semana') ...[
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<int>(
                                    initialValue: r.secondWeekday,
                                    decoration: const InputDecoration(
                                      labelText:
                                          'Segundo Dia da Semana (para 2x/semana)',
                                      isDense: true,
                                    ),
                                    items: List.generate(7, (i) {
                                      return DropdownMenuItem(
                                        value: i + 1,
                                        child: Text(
                                          weekdayLabels[i],
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      );
                                    }),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() => r.secondWeekday = val);
                                      }
                                    },
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Text(
                                  'Datas calculadas para ${getMonthName(targetMonth)}: '
                                  '${targetDates.map((d) => "${d.day.toString().padLeft(2, "0")}/${d.month.toString().padLeft(2, "0")}").join(", ")}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? const Color(0xFFCBD5E1)
                                        : const Color(0xFF475569),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue,
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.check, size: 16),
          label: Text('Replicar e Agendar ($totalPendingToCreate novos)'),
          onPressed:
              totalPendingToCreate == 0 &&
                  wizardRoutines.every((r) => !r.isEnabled)
              ? null
              : () async {
                  final repo = ref.read(repositoryProvider);
                  int totalCreated = 0;
                  int totalSkipped = 0;

                  for (final r in wizardRoutines.where((r) => r.isEnabled)) {
                    final dates = _calculateRoutineDates(r, daysInTargetMonth);
                    for (final targetDt in dates) {
                      final hasDuplicate = targetExistingAppts.any((existing) {
                        final sameTitle =
                            existing.title.trim().toLowerCase() ==
                            r.title.trim().toLowerCase();
                        final timeDiff = existing.startTime
                            .difference(targetDt)
                            .inMinutes
                            .abs();
                        return sameTitle && timeDiff < 15;
                      });

                      if (hasDuplicate) {
                        totalSkipped++;
                        continue;
                      }

                      await repo.createAppointment(
                        personId: r.personId,
                        title: r.title,
                        startTime: targetDt,
                        endTime: targetDt.add(
                          Duration(minutes: r.durationMinutes),
                        ),
                        durationMinutes: r.durationMinutes,
                        status: 'confirmado',
                        locationNotes: r.notes,
                      );
                      totalCreated++;
                    }
                  }

                  if (totalCreated > 0) {
                    _triggerBackgroundCalendarSync();
                  }

                  widget.onCompleted?.call();

                  if (context.mounted) Navigator.pop(context);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          totalCreated > 0
                              ? 'Programação replicada com sucesso! $totalCreated compromisso(s) criado(s) em ${getMonthName(targetMonth)}.'
                              : 'Nenhum novo compromisso criado ($totalSkipped já agendados).',
                        ),
                      ),
                    );
                  }
                },
        ),
      ],
    );
  }
}
