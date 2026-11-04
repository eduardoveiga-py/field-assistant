import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../core/date_utils.dart';
import '../../../dashboard/counting_rules.dart';

/// Célula de métrica individual no cartão de relatório oficial.
class ReportCell extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const ReportCell({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayColor =
        isDark &&
            (color == const Color(0xFF0F172A) || color == AppTheme.textDark)
        ? Colors.white
        : color;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Column(
          children: [
            Icon(icon, color: displayColor, size: 22),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: displayColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isDark ? AppTheme.darkTextMuted : AppTheme.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Cartão estilo ficha oficial de relatório de campo com alto contraste.
/// Preserva estritamente os finders: 'Relatório Mensal de Campo', 'HORAS', 'ESTUDOS', 'REVISITAS'.
class OfficialReportCard extends StatelessWidget {
  final DashboardMetrics metrics;
  final Color headingColor;
  final Color dividerColor;
  final VoidCallback onExportPdf;
  final VoidCallback onShare;
  final VoidCallback onShowHoursRecords;
  final VoidCallback onShowStudiesRecords;
  final VoidCallback onShowVisitsRecords;

  const OfficialReportCard({
    super.key,
    required this.metrics,
    required this.headingColor,
    required this.dividerColor,
    required this.onExportPdf,
    required this.onShare,
    required this.onShowHoursRecords,
    required this.onShowStudiesRecords,
    required this.onShowVisitsRecords,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 950;
            final title = Text(
              'Relatório Mensal de Campo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: headingColor,
              ),
            );
            final buttons = Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    minimumSize: const Size(36, 36),
                  ),
                  icon: const Icon(
                    Icons.picture_as_pdf,
                    size: 16,
                    color: Colors.red,
                  ),
                  label: const Text(
                    'Exportar Relatório PDF',
                    style: TextStyle(fontSize: 12),
                  ),
                  onPressed: onExportPdf,
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    minimumSize: const Size(36, 36),
                  ),
                  icon: const Icon(Icons.share, size: 16),
                  label: const Text(
                    'Enviar Relatório',
                    style: TextStyle(fontSize: 12),
                  ),
                  onPressed: onShare,
                ),
              ],
            );

            if (isNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [title, const SizedBox(height: 8), buttons],
              );
            }

            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [title, Flexible(child: buttons)],
            );
          },
        ),
        const SizedBox(height: 10),
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ReportCell(
                        label: 'HORAS',
                        value: AppDateUtils.formatDuration(
                          metrics.totalActivitySeconds,
                        ),
                        icon: Icons.access_time_filled,
                        color: const Color(0xFF0F172A),
                        onTap: onShowHoursRecords,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 60,
                      color: dividerColor,
                    ),
                    Expanded(
                      child: ReportCell(
                        label: 'ESTUDOS',
                        value: '${metrics.activeStudiesCount}',
                        icon: Icons.menu_book,
                        color: const Color(0xFF7C3AED),
                        onTap: onShowStudiesRecords,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 60,
                      color: dividerColor,
                    ),
                    Expanded(
                      child: ReportCell(
                        label: 'REVISITAS',
                        value: '${metrics.heldVisitsCount}',
                        icon: Icons.repeat,
                        color: AppTheme.accentTeal,
                        onTap: onShowVisitsRecords,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ReportCell(
                        label: 'PUBLICAÇÕES',
                        value: '${metrics.totalPlacements}',
                        icon: Icons.auto_stories,
                        color: const Color(0xFF0284C7),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 60,
                      color: dividerColor,
                    ),
                    Expanded(
                      child: ReportCell(
                        label: 'VÍDEOS',
                        value: '${metrics.totalVideos}',
                        icon: Icons.play_circle_fill,
                        color: const Color(0xFFDC2626),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 60,
                      color: dividerColor,
                    ),
                    Expanded(
                      child: ReportCell(
                        label: 'SESSÕES DADAS',
                        value: '${metrics.heldSessionsCount}',
                        icon: Icons.school,
                        color: AppTheme.primaryBlue,
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
