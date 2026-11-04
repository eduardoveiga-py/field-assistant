import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';

/// Card comparativo entre Horas Programadas (na Agenda) e Horas Efetivas Realizadas.
class ScheduledVsActualHoursCard extends StatelessWidget {
  final double scheduledHours;
  final double actualHours;
  final Color headingColor;
  final Color bodyColor;
  final Color mutedColor;
  final bool isDark;

  const ScheduledVsActualHoursCard({
    super.key,
    required this.scheduledHours,
    required this.actualHours,
    required this.headingColor,
    required this.bodyColor,
    required this.mutedColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final double completionPercent = scheduledHours > 0
        ? (actualHours / scheduledHours).clamp(0.0, 2.0)
        : 0.0;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.av_timer,
                      size: 20,
                      color: AppTheme.primaryBlue,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Programação de Campo (Agenda)',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: scheduledHours > 0
                        ? (actualHours >= scheduledHours
                            ? AppTheme.successGreen.withValues(alpha: 0.1)
                            : AppTheme.primaryBlue.withValues(alpha: 0.1))
                        : (isDark ? Colors.white10 : Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    scheduledHours > 0
                        ? '${(completionPercent * 100).toStringAsFixed(0)}% realizado'
                        : 'Sem agendamentos',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: scheduledHours > 0
                          ? (actualHours >= scheduledHours
                              ? AppTheme.successGreen
                              : AppTheme.primaryBlue)
                          : mutedColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Horas Programadas',
                        style: TextStyle(fontSize: 12, color: mutedColor),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${scheduledHours.toStringAsFixed(1)}h',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                      Text(
                        'Compromissos do mês',
                        style: TextStyle(fontSize: 11, color: mutedColor),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 48,
                  color: isDark ? Colors.white12 : Colors.grey.shade300,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Horas Efetivas Realizadas',
                        style: TextStyle(fontSize: 12, color: mutedColor),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${actualHours.toStringAsFixed(1)}h',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: actualHours >= scheduledHours && scheduledHours > 0
                              ? AppTheme.successGreen
                              : bodyColor,
                        ),
                      ),
                      Text(
                        'Relatadas até agora',
                        style: TextStyle(fontSize: 11, color: mutedColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (scheduledHours > 0) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (actualHours / scheduledHours).clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: isDark ? Colors.white10 : Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    actualHours >= scheduledHours
                        ? AppTheme.successGreen
                        : AppTheme.primaryBlue,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
