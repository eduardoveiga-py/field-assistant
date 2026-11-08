import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../core/date_utils.dart';
import '../../database/app_database.dart';
import '../../appointments/doorstep_proximity_engine.dart';
import '../../appointments/calendar_sync_coordinator.dart';
import '../providers.dart';

/// Diálogo de Agendamento Rápido de Retorno na Porta por Proximidade Geográfica
class DoorstepReturnBookingDialog extends ConsumerStatefulWidget {
  final PersonEntry person;

  const DoorstepReturnBookingDialog({super.key, required this.person});

  static Future<void> show(BuildContext context, PersonEntry person) {
    return showDialog(
      context: context,
      builder: (_) => DoorstepReturnBookingDialog(person: person),
    );
  }

  @override
  ConsumerState<DoorstepReturnBookingDialog> createState() =>
      _DoorstepReturnBookingDialogState();
}

class _DoorstepReturnBookingDialogState
    extends ConsumerState<DoorstepReturnBookingDialog> {
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allPeople = ref.watch(peopleStreamProvider).value ?? [];
    final allAppts = ref.watch(appointmentsStreamProvider).value ?? [];
    final externalEvents =
        ref.watch(externalCalendarEventsProvider).value ?? [];

    final recommendations = DoorstepProximityEngine.suggestSlots(
      targetPerson: widget.person,
      allPeople: allPeople,
      existingAppointments: allAppts,
      externalEvents: externalEvents,
    );

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFD97706).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.bolt, color: Color(0xFFD97706), size: 22),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Agendar Retorno na Porta',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Sugestões por proximidade e rota',
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.grey.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.person.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    if (widget.person.address != null)
                      Text(
                        '📍 ${widget.person.address}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                    if (widget.person.preferredSchedule != null)
                      Text(
                        '🕒 Preferência: ${widget.person.preferredSchedule}',
                        style: const TextStyle(fontSize: 11, color: AppTheme.accentTeal),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Horários Recomendados:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              if (recommendations.isEmpty)
                const Text('Nenhuma recomendação disponível no momento.')
              else
                ...recommendations.map((rec) => _buildSlotCard(context, rec, isDark)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }

  Widget _buildSlotCard(
    BuildContext context,
    DoorstepSlotRecommendation rec,
    bool isDark,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: rec.hasConflict
              ? Colors.red.shade300
              : (isDark ? Colors.white12 : Colors.grey.shade300),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFFD97706)),
                const SizedBox(width: 6),
                Text(
                  '${AppDateUtils.formatDate(rec.startTime)} às ${AppDateUtils.formatTime(rec.startTime)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const Spacer(),
                if (rec.distanceMeters != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      rec.formattedDistance,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              rec.reasonLabel,
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
            if (rec.hasConflict) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, size: 14, color: Colors.red),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        rec.conflictDetails ?? 'Conflito detectado na agenda.',
                        style: const TextStyle(fontSize: 11, color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Confirmar Este Horário', style: TextStyle(fontSize: 12)),
                onPressed: _isSaving ? null : () => _confirmBooking(rec),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmBooking(DoorstepSlotRecommendation rec) async {
    setState(() => _isSaving = true);
    try {
      final repo = ref.read(repositoryProvider);
      await repo.createAppointment(
        title: rec.title,
        personId: widget.person.id,
        startTime: rec.startTime,
        endTime: rec.endTime,
        durationMinutes: 30,
        status: 'agendado',
        locationNotes: widget.person.address,
      );

      // Dispara sincronização em segundo plano com calendários externos
      ref.read(calendarSyncCoordinatorProvider).syncAll();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Retorno com ${widget.person.name} agendado para ${AppDateUtils.formatDate(rec.startTime)} às ${AppDateUtils.formatTime(rec.startTime)}!',
            ),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao agendar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
