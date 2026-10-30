import 'package:flutter/material.dart';
import '../../appointments/availability_engine.dart';
import '../../core/app_theme.dart';
import '../../core/date_utils.dart';
import '../../database/app_database.dart';

/// Seção visual reutilizável de agendamento global com verificação de disponibilidade,
/// visualização clara dos compromissos já agendados na data selecionada e sugestões de horários livres.
class GlobalAppointmentSchedulingSection extends StatelessWidget {
  final String title;
  final bool isEnabled;
  final ValueChanged<bool> onToggle;
  final DateTime selectedDateTime;
  final ValueChanged<DateTime> onDateTimeChanged;
  final int durationMinutes;
  final ValueChanged<int> onDurationChanged;
  final List<AppointmentEntry> existingAppointments;
  final String? excludeAppointmentId;
  final bool showHeaderToggle;
  final AppointmentEntry? existingPersonAppointment;
  final String? frequencyText;

  const GlobalAppointmentSchedulingSection({
    super.key,
    required this.title,
    required this.isEnabled,
    required this.onToggle,
    required this.selectedDateTime,
    required this.onDateTimeChanged,
    required this.durationMinutes,
    required this.onDurationChanged,
    required this.existingAppointments,
    this.excludeAppointmentId,
    this.showHeaderToggle = true,
    this.existingPersonAppointment,
    this.frequencyText,
  });

  /// Diálogo auxiliar para alertar sobre conflitos antes de salvar
  static Future<bool> confirmConflictIfNeeded({
    required BuildContext context,
    required AvailabilityResult? availability,
  }) async {
    if (availability == null || availability.isAvailable) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.alertAmber),
            SizedBox(width: 8),
            Text('Atenção: Horário Ocupado'),
          ],
        ),
        content: Text(
          'Já existe outro compromisso agendado no mesmo intervalo (${availability.message}).\n\nDeseja mesmo confirmar e gerar sobreposição de horários?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Ajustar Horário'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.alertAmber),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sim, Confirmar Sobreposição'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final availability = AvailabilityEngine.checkAvailability(
      startTime: selectedDateTime,
      durationMinutes: durationMinutes,
      existingAppointments: existingAppointments,
      excludeAppointmentId: excludeAppointmentId,
    );

    // Filtra os compromissos agendados no mesmo dia civil para o usuário "enxergar" a agenda
    final sameDayAppointments = existingAppointments.where((a) {
      if (a.deletedAt != null) return false;
      if (excludeAppointmentId != null && a.id == excludeAppointmentId) return false;
      final status = a.status.toLowerCase();
      if (status == 'cancelado' || status == 'reagendado') return false;

      return a.startTime.year == selectedDateTime.year &&
          a.startTime.month == selectedDateTime.month &&
          a.startTime.day == selectedDateTime.day;
    }).toList()..sort((a, b) => a.startTime.compareTo(b.startTime));

    final endTime = selectedDateTime.add(Duration(minutes: durationMinutes));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho com Switch de ativação (se habilitado)
          if (showHeaderToggle)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.event_available, color: AppTheme.primaryBlue, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                Switch(
                  value: isEnabled,
                  activeThumbColor: AppTheme.primaryBlue,
                  onChanged: onToggle,
                ),
              ],
            )
          else
            Row(
              children: [
                const Icon(Icons.event_available, color: AppTheme.primaryBlue, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),

          if (isEnabled) ...[
            if (frequencyText != null || existingPersonAppointment != null) ...[
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: existingPersonAppointment != null
                      ? AppTheme.accentTeal.withValues(alpha: 0.1)
                      : AppTheme.primaryBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: existingPersonAppointment != null
                        ? AppTheme.accentTeal.withValues(alpha: 0.4)
                        : AppTheme.primaryBlue.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      existingPersonAppointment != null ? Icons.event_repeat : Icons.info_outline,
                      size: 16,
                      color: existingPersonAppointment != null ? AppTheme.accentTeal : AppTheme.primaryBlue,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (frequencyText != null)
                            Text(
                              'Frequência do estudo: $frequencyText',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: existingPersonAppointment != null ? AppTheme.accentTeal : AppTheme.primaryBlue,
                              ),
                            ),
                          if (existingPersonAppointment != null) ...[
                            if (frequencyText != null) const SizedBox(height: 2),
                            Text(
                              'Compromisso já agendado para ${AppDateUtils.formatDate(existingPersonAppointment!.startTime)} às ${AppDateUtils.formatTime(existingPersonAppointment!.startTime)}. Ao confirmar, este compromisso será sincronizado/atualizado com segurança sem duplicar.',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),

            // Seletores de Data e Horário
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(
                      AppDateUtils.formatDate(selectedDateTime),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    onPressed: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDateTime,
                        firstDate: DateTime(now.year - 1, 1, 1),
                        lastDate: DateTime(now.year + 2, 12, 31),
                      );
                      if (picked != null) {
                        onDateTimeChanged(DateTime(
                          picked.year,
                          picked.month,
                          picked.day,
                          selectedDateTime.hour,
                          selectedDateTime.minute,
                        ));
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.access_time, size: 16),
                    label: Text(
                      AppDateUtils.formatTime(selectedDateTime),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    onPressed: () async {
                      final pickedTime = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(selectedDateTime),
                      );
                      if (pickedTime != null) {
                        onDateTimeChanged(DateTime(
                          selectedDateTime.year,
                          selectedDateTime.month,
                          selectedDateTime.day,
                          pickedTime.hour,
                          pickedTime.minute,
                        ));
                      }
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Seletor de Duração Prevista
            DropdownButtonFormField<int>(
              initialValue: durationMinutes,
              decoration: const InputDecoration(
                labelText: 'Duração prevista',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: const [
                DropdownMenuItem(value: 15, child: Text('15 minutos (Rápida)')),
                DropdownMenuItem(value: 30, child: Text('30 minutos (Padrão Revisita)')),
                DropdownMenuItem(value: 45, child: Text('45 minutos')),
                DropdownMenuItem(value: 60, child: Text('1 hora (Padrão Estudo Bíblico)')),
                DropdownMenuItem(value: 90, child: Text('1h 30m (Estudo Aprofundado)')),
              ],
              onChanged: (val) {
                if (val != null) onDurationChanged(val);
              },
            ),

            const SizedBox(height: 12),

            // SEÇÃO "ENXERGAR COMPROMISSOS NESTA DATA"
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_month_outlined, size: 16, color: AppTheme.primaryBlue),
                      const SizedBox(width: 6),
                      Text(
                        'Compromissos nesta data (${AppDateUtils.formatDate(selectedDateTime)}):',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (sameDayAppointments.isEmpty)
                    Text(
                      'Nenhum compromisso agendado para este dia. O dia está livre.',
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: isDark ? const Color(0xFFCBD5E1) : AppTheme.textMuted,
                      ),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: sameDayAppointments.map((a) {
                        final isColliding = availability.conflictingAppointments.any((c) => c.id == a.id);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Icon(
                                isColliding ? Icons.error_outline : Icons.circle,
                                size: isColliding ? 14 : 7,
                                color: isColliding ? AppTheme.alertAmber : AppTheme.primaryBlue,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '${AppDateUtils.formatTime(a.startTime)} - ${AppDateUtils.formatTime(a.endTime)}: ${a.title}${a.locationNotes != null ? " (${a.locationNotes})" : ""}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isColliding ? FontWeight.bold : FontWeight.normal,
                                    color: isColliding ? const Color(0xFFB45309) : (isDark ? Colors.white : AppTheme.textDark),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // BANNER LIVE DE DISPONIBILIDADE NO HORÁRIO ESCOLHIDO
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: availability.isAvailable
                    ? AppTheme.successGreen.withValues(alpha: 0.12)
                    : AppTheme.alertAmber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: availability.isAvailable ? AppTheme.successGreen : AppTheme.alertAmber,
                  width: 1.2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        availability.isAvailable ? Icons.check_circle : Icons.warning_amber_rounded,
                        size: 18,
                        color: availability.isAvailable ? AppTheme.successGreen : const Color(0xFFB45309),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          availability.isAvailable
                              ? 'Horário Livre: ${AppDateUtils.formatTime(selectedDateTime)} às ${AppDateUtils.formatTime(endTime)}'
                              : 'Conflito de Horário! ${availability.message}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: availability.isAvailable ? AppTheme.successGreen : const Color(0xFF92400E),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Sugestões de Horários Livres Alternativos com 1 clique
                  if (!availability.isAvailable && availability.suggestedAlternativeSlots.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Sugestões de horários livres no Território:',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: availability.suggestedAlternativeSlots.map((slot) {
                        return ActionChip(
                          visualDensity: VisualDensity.compact,
                          backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                          label: Text(
                            '${AppDateUtils.formatDate(slot)} ${AppDateUtils.formatTime(slot)}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primaryBlue),
                          ),
                          onPressed: () => onDateTimeChanged(slot),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
