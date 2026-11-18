import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../../../core/date_utils.dart';

class AppointmentsControlsBar extends StatelessWidget {
  const AppointmentsControlsBar({
    super.key,
    required this.viewMode,
    required this.selectedDate,
    required this.isDark,
    required this.onViewModeChanged,
    required this.onPreviousDate,
    required this.onNextDate,
    required this.onTodayPressed,
  });

  final String viewMode;
  final DateTime selectedDate;
  final bool isDark;
  final ValueChanged<String> onViewModeChanged;
  final VoidCallback onPreviousDate;
  final VoidCallback onNextDate;
  final VoidCallback onTodayPressed;

  static String getMonthName(int month) {
    const months = [
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro',
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isDark ? const Color(0xFF0F172A) : Colors.white,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 700;
              final navRow = Row(
                mainAxisSize: isNarrow ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment:
                    isNarrow ? MainAxisAlignment.center : MainAxisAlignment.start,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    visualDensity: VisualDensity.compact,
                    onPressed: onPreviousDate,
                  ),
                  if (isNarrow)
                    Expanded(
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            viewMode == 'Mês'
                                ? '${getMonthName(selectedDate.month)} ${selectedDate.year}'
                                : AppDateUtils.formatDate(selectedDate),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: isDark ? Colors.white : AppTheme.textDark,
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        viewMode == 'Mês'
                            ? '${getMonthName(selectedDate.month)} ${selectedDate.year}'
                            : AppDateUtils.formatDate(selectedDate),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isDark ? Colors.white : AppTheme.textDark,
                        ),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    visualDensity: VisualDensity.compact,
                    onPressed: onNextDate,
                  ),
                ],
              );

              final segButton = SegmentedButton<String>(
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                segments: const [
                  ButtonSegment(
                    value: 'Mês',
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Mês', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  ButtonSegment(
                    value: 'Semana',
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Semana', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  ButtonSegment(
                    value: 'Dia',
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Dia', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  ButtonSegment(
                    value: 'Lista',
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Lista', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
                selected: {viewMode},
                onSelectionChanged: (val) => onViewModeChanged(val.first),
              );

              if (isNarrow) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: navRow),
                        IconButton(
                          icon: const Icon(Icons.today, size: 20),
                          tooltip: 'Hoje',
                          visualDensity: VisualDensity.compact,
                          onPressed: onTodayPressed,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SizedBox(width: double.infinity, child: segButton),
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [navRow, segButton],
              );
            },
          ),
        ),
      ),
    );
  }
}
