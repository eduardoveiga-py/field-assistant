import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';

/// Card para acompanhamento da Meta Pessoal de Horas & Progresso Diário (estilo Witness Work).
/// Preserva o finder de teste: 'Meta Pessoal de Horas'.
class PersonalHourGoalCard extends StatelessWidget {
  final double progressPercent;
  final double totalHoursDone;
  final double effectiveHourGoal;
  final double remainingHours;
  final double dailyHoursNeeded;
  final int daysRemaining;
  final bool isYearMode;
  final int personalHourGoal;
  final ValueChanged<int> onGoalChanged;
  final Color headingColor;
  final Color bodyColor;
  final Color mutedColor;
  final Color dividerColor;
  final bool isDark;

  const PersonalHourGoalCard({
    super.key,
    required this.progressPercent,
    required this.totalHoursDone,
    required this.effectiveHourGoal,
    required this.remainingHours,
    required this.dailyHoursNeeded,
    required this.daysRemaining,
    required this.isYearMode,
    required this.personalHourGoal,
    required this.onGoalChanged,
    required this.headingColor,
    required this.bodyColor,
    required this.mutedColor,
    required this.dividerColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Meta Pessoal de Horas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: headingColor,
              ),
            ),
            DropdownButton<int>(
              value: [15, 30, 50, 100].contains(personalHourGoal)
                  ? personalHourGoal
                  : 50,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(
                  value: 15,
                  child: Text('Auxiliar (15h)'),
                ),
                DropdownMenuItem(
                  value: 30,
                  child: Text('Auxiliar (30h)'),
                ),
                DropdownMenuItem(
                  value: 50,
                  child: Text('Regular (50h)'),
                ),
                DropdownMenuItem(
                  value: 100,
                  child: Text('Especial (100h)'),
                ),
              ],
              onChanged: (val) {
                if (val != null) {
                  onGoalChanged(val);
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${totalHoursDone.toStringAsFixed(1)}h de $effectiveHourGoal h${isYearMode ? " (Ano)" : ""}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${(progressPercent * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progressPercent,
                    minHeight: 12,
                    backgroundColor: isDark
                        ? Colors.white12
                        : Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progressPercent >= 1.0
                          ? AppTheme.successGreen
                          : AppTheme.primaryBlue,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Restam para a meta',
                            style: TextStyle(
                              fontSize: 12,
                              color: mutedColor,
                            ),
                          ),
                          Text(
                            '${remainingHours.toStringAsFixed(1)}h',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: bodyColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 35,
                      color: dividerColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Média diária necessária',
                            style: TextStyle(
                              fontSize: 12,
                              color: mutedColor,
                            ),
                          ),
                          Text(
                            '${(dailyHoursNeeded * 60).round()} min/dia',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.accentTeal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 35,
                      color: dividerColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dias restantes',
                            style: TextStyle(
                              fontSize: 12,
                              color: mutedColor,
                            ),
                          ),
                          Text(
                            '$daysRemaining dias',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: bodyColor,
                            ),
                          ),
                        ],
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
