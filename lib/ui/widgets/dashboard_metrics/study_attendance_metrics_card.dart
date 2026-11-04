import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../dashboard/counting_rules.dart';

/// Card exibindo o total e a média de assistência aos estudos bíblicos.
/// Preserva o finder de teste: 'Total Assistência'.
class StudyAttendanceMetricsCard extends StatelessWidget {
  final DashboardMetrics metrics;
  final Color headingColor;
  final Color bodyColor;
  final Color mutedColor;
  final bool isDark;

  const StudyAttendanceMetricsCard({
    super.key,
    required this.metrics,
    required this.headingColor,
    required this.bodyColor,
    required this.mutedColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Assistência aos Estudos Bíblicos',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: headingColor,
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.people_alt,
                                  size: 18,
                                  color: Color(0xFF7C3AED),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Total Assistência',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF7C3AED),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${metrics.totalStudyAttendance} pessoas',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF7C3AED),
                              ),
                            ),
                            Text(
                              'Presentes somados no mês',
                              style: TextStyle(
                                fontSize: 11,
                                color: mutedColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.accentTeal.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.accentTeal.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.pie_chart,
                                  size: 18,
                                  color: AppTheme.accentTeal,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Assistência média/sessão',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.accentTeal,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${metrics.averageAttendancePerStudy} pessoas',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.accentTeal,
                              ),
                            ),
                            Text(
                              'Média por estudo bíblico',
                              style: TextStyle(
                                fontSize: 11,
                                color: mutedColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
