import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../core/date_utils.dart';
import '../../../database/app_database.dart';

/// Painel lateral de detalhes de um compromisso exibido no modo iPad Split-View (>= 900px).
class AppointmentDetailPane extends StatelessWidget {
  final AppointmentEntry appt;
  final PersonEntry? person;
  final VoidCallback onReschedule;
  final VoidCallback onMarkDone;
  final VoidCallback onCancelPlanB;
  final VoidCallback? onOpenPersonProfile;
  final VoidCallback onAddToGoogleCalendar;
  final VoidCallback onDelete;

  const AppointmentDetailPane({
    super.key,
    required this.appt,
    this.person,
    required this.onReschedule,
    required this.onMarkDone,
    required this.onCancelPlanB,
    this.onOpenPersonProfile,
    required this.onAddToGoogleCalendar,
    required this.onDelete,
  });

  static Color _getStatusColor(String status) {
    switch (status) {
      case 'confirmado':
        return AppTheme.primaryBlue;
      case 'realizado':
        return AppTheme.successGreen;
      case 'cancelado':
        return AppTheme.alertRed;
      default:
        return AppTheme.alertAmber;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = _getStatusColor(appt.status);
    final isDone = appt.status == 'realizado';
    final isCancelled = appt.status == 'cancelado';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header com ícone, título e chip de status
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: statusColor.withValues(alpha: 0.15),
                child: Icon(Icons.event, color: statusColor, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        appt.title,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          decoration: isDone
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${AppDateUtils.formatDateTime(appt.startTime)} – ${AppDateUtils.formatTime(appt.endTime)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Chip(
                label: Text(
                  appt.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
                backgroundColor: statusColor.withValues(alpha: 0.12),
                side: BorderSide(color: statusColor.withValues(alpha: 0.3)),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Informações do Agendamento
          Card(
            clipBehavior: Clip.antiAlias,
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      'Detalhes da Agenda',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  const Divider(height: 20),
                  _buildDetailRow(
                    icon: Icons.access_time_rounded,
                    label: 'Duração',
                    value: '${appt.durationMinutes} minutos',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  _buildDetailRow(
                    icon: Icons.calendar_today_rounded,
                    label: 'Data',
                    value: AppDateUtils.formatDate(appt.startTime),
                    isDark: isDark,
                  ),
                  if (appt.locationNotes != null &&
                      appt.locationNotes!.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _buildDetailRow(
                      icon: Icons.notes_rounded,
                      label: 'Observações / Local',
                      value: appt.locationNotes!,
                      isDark: isDark,
                    ),
                  ],
                  if (person != null) ...[
                    const SizedBox(height: 10),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final textScale = MediaQuery.textScalerOf(context)
                            .scale(1);
                        final isStacked =
                            constraints.maxWidth < 420 || textScale > 1.2;

                        final semanticsButton = onOpenPersonProfile != null
                            ? Semantics(
                                container: true,
                                excludeSemantics: true,
                                button: true,
                                label: 'Ver perfil de ${person!.name}',
                                hint: 'Abre a ficha completa do contato',
                                child: TextButton.icon(
                                  style: TextButton.styleFrom(
                                    minimumSize: const Size(48, 48),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                  ),
                                  onPressed: onOpenPersonProfile,
                                  icon: const Icon(Icons.open_in_new, size: 16),
                                  label: const Text('Ver Perfil'),
                                ),
                              )
                            : null;

                        if (isStacked) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.person_rounded,
                                size: 18,
                                color: AppTheme.primaryBlue,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Contato: ${person!.name}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    if (semanticsButton != null) ...[
                                      const SizedBox(height: 4),
                                      semanticsButton,
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          );
                        }

                        return Row(
                          children: [
                            const Icon(
                              Icons.person_rounded,
                              size: 18,
                              color: AppTheme.primaryBlue,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Contato: ${person!.name}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            ?semanticsButton,
                          ],
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Ações Rápidas
          Semantics(
            header: true,
            child: Text(
              'Ações Rápidas',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (!isDone)
                Semantics(
                  container: true,
                  excludeSemantics: true,
                  button: true,
                  label: 'Marcar compromisso como realizado',
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successGreen,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(140, 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onPressed: onMarkDone,
                    icon: const Icon(Icons.check_circle_outline, size: 20),
                    label: const Text('Marcar Realizado'),
                  ),
                ),
              Semantics(
                container: true,
                excludeSemantics: true,
                button: true,
                label: 'Reagendar compromisso mantendo histórico',
                hint: 'Altera a data ou horário do compromisso',
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(130, 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onPressed: onReschedule,
                  icon: const Icon(Icons.sync_alt, size: 20),
                  label: const Text('Reagendar'),
                ),
              ),
              if (!isCancelled)
                Semantics(
                  container: true,
                  excludeSemantics: true,
                  button: true,
                  label: 'Estudante desmarcou, abrir recomendações do Plano B',
                  hint: 'Encontra visitas alternativas para o horário vago',
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.alertAmber,
                      minimumSize: const Size(130, 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onPressed: onCancelPlanB,
                    icon: const Icon(Icons.alt_route, size: 20),
                    label: const Text('Plano B (Desmarcou)'),
                  ),
                ),
              Semantics(
                container: true,
                excludeSemantics: true,
                button: true,
                label: 'Adicionar compromisso ao Google Agenda',
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(130, 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onPressed: onAddToGoogleCalendar,
                  icon: const Icon(Icons.calendar_month, size: 20),
                  label: const Text('Google Agenda'),
                ),
              ),
              Semantics(
                container: true,
                excludeSemantics: true,
                button: true,
                label: 'Excluir compromisso',
                hint: 'Remove o agendamento da agenda',
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.alertRed,
                    minimumSize: const Size(110, 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 20),
                  label: const Text('Excluir'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: isDark ? const Color(0xFF94A3B8) : AppTheme.textMuted,
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? const Color(0xFF94A3B8) : AppTheme.textMuted,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class AppointmentPlaceholderPane extends StatelessWidget {
  const AppointmentPlaceholderPane({super.key, required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        label: 'Selecione um compromisso para visualizar detalhes',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_month_outlined,
              size: 52,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              'Selecione um compromisso para visualizar detalhes',
              style: TextStyle(
                color: isDark ? const Color(0xFF94A3B8) : AppTheme.textMuted,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
