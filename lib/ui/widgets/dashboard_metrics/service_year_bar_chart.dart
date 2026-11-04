import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../database/app_database.dart';

/// Gráfico de barras comparando as horas mês a mês ao longo do ano de serviço.
class ServiceYearBarChart extends StatelessWidget {
  final List<ActivityRecordEntry> activities;
  final DateTime referenceDate;

  const ServiceYearBarChart({
    super.key,
    required this.activities,
    required this.referenceDate,
  });

  static int getServiceYear(DateTime date) {
    return date.month >= 9 ? date.year + 1 : date.year;
  }

  static String getMonthAbbr(int month) {
    const abbr = [
      'Jan',
      'Fev',
      'Mar',
      'Abr',
      'Mai',
      'Jun',
      'Jul',
      'Ago',
      'Set',
      'Out',
      'Nov',
      'Dez',
    ];
    return abbr[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final serviceYear = getServiceYear(referenceDate);
    final startYear = serviceYear - 1;

    final List<Map<String, dynamic>> monthsData = [];
    final monthOrder = [9, 10, 11, 12, 1, 2, 3, 4, 5, 6, 7, 8];

    for (int i = 0; i < monthOrder.length; i++) {
      final m = monthOrder[i];
      final y = m >= 9 ? startYear : serviceYear;
      final mStart = DateTime(y, m, 1);
      final mEnd = DateTime(y, m + 1, 0, 23, 59, 59);

      int secs = 0;
      for (final a in activities) {
        if (a.deletedAt == null &&
            a.date.isAfter(mStart.subtract(const Duration(seconds: 1))) &&
            a.date.isBefore(mEnd.add(const Duration(seconds: 1)))) {
          secs += a.durationSeconds;
        }
      }

      monthsData.add({
        'month': m,
        'year': y,
        'label': getMonthAbbr(m),
        'hours': secs / 3600.0,
      });
    }

    final maxHours = monthsData
        .map((d) => d['hours'] as double)
        .fold<double>(0.0, (prev, val) => val > prev ? val : prev);
    final maxY = maxHours > 50 ? (maxHours * 1.2).ceilToDouble() : 60.0;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final d = monthsData[group.x.toInt()];
              return BarTooltipItem(
                '${d["label"]}: ${(d["hours"] as double).toStringAsFixed(1)}h',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, meta) {
                final idx = val.toInt();
                if (idx < 0 || idx >= monthsData.length) {
                  return const SizedBox.shrink();
                }
                return Text(
                  monthsData[idx]['label'] as String,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? AppTheme.darkTextMuted : AppTheme.textMuted,
                  ),
                );
              },
            ),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(monthsData.length, (idx) {
          final h = monthsData[idx]['hours'] as double;
          final isCurrent =
              monthsData[idx]['month'] == referenceDate.month &&
              monthsData[idx]['year'] == referenceDate.year;

          return BarChartGroupData(
            x: idx,
            barRods: [
              BarChartRodData(
                toY: h,
                color: isCurrent ? AppTheme.accentTeal : AppTheme.primaryBlue,
                width: 14,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}
