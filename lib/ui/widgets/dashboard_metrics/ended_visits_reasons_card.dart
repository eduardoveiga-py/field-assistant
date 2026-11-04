import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../dashboard/counting_rules.dart';

/// Card exibindo o relatório e motivos de encerramento de revisitas.
class EndedVisitsReasonsCard extends StatelessWidget {
  final DashboardMetrics metrics;
  final Color headingColor;
  final Color bodyColor;
  final Color mutedColor;
  final bool isDark;

  const EndedVisitsReasonsCard({
    super.key,
    required this.metrics,
    required this.headingColor,
    required this.bodyColor,
    required this.mutedColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final reasons = metrics.endedVisitsByReason;
    final totalEnded = metrics.endedVisitsCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Encerramento de Revisitas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: headingColor,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: totalEnded > 0
                    ? const Color(0xFFD97706).withValues(alpha: 0.1)
                    : AppTheme.successGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                totalEnded > 0
                    ? '$totalEnded encerrada(s)'
                    : 'Nenhuma encerrada',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: totalEnded > 0
                      ? const Color(0xFFD97706)
                      : AppTheme.successGreen,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: totalEnded == 0
                ? Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        color: AppTheme.successGreen,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Todas as suas revisitas continuam ativas no território.',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? const Color(0xFFCBD5E1)
                                : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Distribuição dos Motivos de Encerramento:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isDark ? Colors.white : AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...reasons.entries.map((entry) {
                        final count = entry.value;
                        final percent = totalEnded > 0
                            ? (count / totalEnded) * 100
                            : 0.0;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    entry.key,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '$count (${percent.toStringAsFixed(0)}%)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: mutedColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: percent / 100.0,
                                  minHeight: 6,
                                  backgroundColor: isDark
                                      ? Colors.white10
                                      : Colors.grey.shade200,
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                        Color(0xFFD97706),
                                      ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
