import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../dashboard/counting_rules.dart';

/// Card exibindo o relatório e motivos de encerramento de estudos bíblicos.
class EndedStudiesReasonsCard extends StatelessWidget {
  final DashboardMetrics metrics;
  final Color headingColor;
  final Color bodyColor;
  final Color mutedColor;
  final bool isDark;

  const EndedStudiesReasonsCard({
    super.key,
    required this.metrics,
    required this.headingColor,
    required this.bodyColor,
    required this.mutedColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final reasons = metrics.endedStudiesByReason;
    final totalEnded = metrics.endedStudiesCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Encerramento de Estudos Bíblicos',
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
                    ? const Color(0xFFDC2626).withValues(alpha: 0.1)
                    : AppTheme.successGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                totalEnded > 0
                    ? '$totalEnded encerrado(s)'
                    : 'Nenhum encerrado',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: totalEnded > 0
                      ? const Color(0xFFDC2626)
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
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Nenhum estudo bíblico foi descontinuado ou encerrado até o momento.',
                          style: TextStyle(fontSize: 12, color: mutedColor),
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Distribuição dos motivos de encerramento:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: bodyColor,
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
                                        Color(0xFFE11D48),
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
