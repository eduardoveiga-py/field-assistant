import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../database/app_database.dart';

/// Gráfico de pizza / rosca representando o tempo dedicado por modalidade de pregação.
class ModalityDistributionChart extends StatelessWidget {
  final List<ActivityRecordEntry> activities;
  final DateTime periodStart;
  final DateTime periodEnd;

  const ModalityDistributionChart({
    super.key,
    required this.activities,
    required this.periodStart,
    required this.periodEnd,
  });

  @override
  Widget build(BuildContext context) {
    final periodActivities = activities
        .where(
          (a) =>
              a.deletedAt == null &&
              a.date.isAfter(periodStart.subtract(const Duration(seconds: 1))) &&
              a.date.isBefore(periodEnd.add(const Duration(seconds: 1))),
        )
        .toList();

    const modalityLabels = {
      'campo': 'Casa em Casa',
      'testemunho_publico': 'Público / Carrinho',
      'informal': 'Informal',
      'carta_telefone': 'Cartas & Telefone',
      'outro': 'Outras Modalidades',
    };

    const modalityColors = {
      'campo': Color(0xFF2563EB),
      'testemunho_publico': Color(0xFF7C3AED),
      'informal': Color(0xFFF59E0B),
      'carta_telefone': Color(0xFF0D9488),
      'outro': Color(0xFF64748B),
    };

    final Map<String, int> durationByModality = {};
    int totalPeriodSeconds = 0;

    for (final act in periodActivities) {
      final mod = act.modality.trim().toLowerCase();
      durationByModality[mod] =
          (durationByModality[mod] ?? 0) + act.durationSeconds;
      totalPeriodSeconds += act.durationSeconds;
    }

    if (totalPeriodSeconds <= 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.pie_chart_outline,
                size: 48,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 8),
              const Text(
                'Nenhuma atividade registrada no período selecionado.',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    final sections = <PieChartSectionData>[];
    durationByModality.forEach((mod, seconds) {
      final double pct = (seconds / totalPeriodSeconds) * 100.0;
      final color = modalityColors[mod] ?? const Color(0xFF6366F1);
      sections.add(
        PieChartSectionData(
          value: seconds.toDouble(),
          color: color,
          radius: 44,
          title: '${pct.toStringAsFixed(0)}%',
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    });

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 36,
              sectionsSpace: 2,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: durationByModality.entries.map((entry) {
            final mod = entry.key;
            final secs = entry.value;
            final color = modalityColors[mod] ?? const Color(0xFF6366F1);
            final label = modalityLabels[mod] ?? mod;
            final hours = (secs / 3600).toStringAsFixed(1);
            final pct = ((secs / totalPeriodSeconds) * 100).toStringAsFixed(0);

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$label: ',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '${hours}h ($pct%)',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
