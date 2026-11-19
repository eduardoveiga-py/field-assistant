import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';

class AppointmentsHoursSummaryBanner extends StatelessWidget {
  const AppointmentsHoursSummaryBanner({
    super.key,
    required this.scheduledHours,
    required this.actualHours,
    required this.isDark,
    required this.onCopySchedule,
    required this.onScheduleFieldMinistry,
  });

  final double scheduledHours;
  final double actualHours;
  final bool isDark;
  final VoidCallback onCopySchedule;
  final VoidCallback onScheduleFieldMinistry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: LayoutBuilder(
            builder: (context, boxConstraints) {
              final textScale = MediaQuery.textScalerOf(context).scale(1.0);
              final isNarrowBanner =
                  boxConstraints.maxWidth < (620 * textScale.clamp(1.0, 2.5));
              final hoursText = Text(
                'Programado: ${scheduledHours.toStringAsFixed(1)}h  •  Efetivo: ${actualHours.toStringAsFixed(1)}h${scheduledHours > 0 ? " (${((actualHours / scheduledHours) * 100).toStringAsFixed(0)}% realizado)" : ""}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? const Color(0xFF93C5FD)
                      : const Color(0xFF1E40AF),
                ),
                overflow: TextOverflow.ellipsis,
              );
              final actionButtons = SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.copy_all_outlined, size: 15),
                      label: const Text(
                        'Copiar Programação',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: onCopySchedule,
                    ),
                    const SizedBox(width: 6),
                    TextButton.icon(
                      icon: const Icon(Icons.alarm_add, size: 15),
                      label: const Text(
                        'Programar Campo',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: onScheduleFieldMinistry,
                    ),
                  ],
                ),
              );

              if (isNarrowBanner) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.av_timer,
                          size: 18,
                          color: AppTheme.primaryBlue,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: hoursText),
                      ],
                    ),
                    actionButtons,
                  ],
                );
              }

              return Row(
                children: [
                  const Icon(
                    Icons.av_timer,
                    size: 18,
                    color: AppTheme.primaryBlue,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: hoursText),
                  const SizedBox(width: 8),
                  Flexible(child: actionButtons),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
