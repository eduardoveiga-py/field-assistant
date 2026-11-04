import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../core/date_utils.dart';
import '../../../database/app_database.dart';
import 'calendar_view_helper.dart';

class MonthCalendarView extends StatelessWidget {
  final DateTime selectedDate;
  final List<AppointmentEntry> allAppointments;
  final ValueChanged<DateTime> onSelectDate;
  final ValueChanged<AppointmentEntry> onAppointmentTap;
  final ValueChanged<DateTime> onNewAppointment;
  final bool isDark;

  const MonthCalendarView({
    super.key,
    required this.selectedDate,
    required this.allAppointments,
    required this.onSelectDate,
    required this.onAppointmentTap,
    required this.onNewAppointment,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final year = selectedDate.year;
    final month = selectedDate.month;
    final firstDayOfMonth = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final startingWeekday = firstDayOfMonth.weekday % 7; // 0 = Domingo, 1 = Segunda...

    final Map<int, List<AppointmentEntry>> apptsByDay = {};
    for (final a in allAppointments) {
      if (a.deletedAt == null &&
          a.startTime.year == year &&
          a.startTime.month == month) {
        apptsByDay.putIfAbsent(a.startTime.day, () => []).add(a);
      }
    }

    final selectedDayAppts = apptsByDay[selectedDate.day] ?? [];

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabeçalho dos dias da semana
              Container(
                color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    const Expanded(
                      child: Center(
                        child: Text(
                          'DOM',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: AppTheme.alertRed,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          'SEG',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: isDark
                                ? const Color(0xFFCBD5E1)
                                : AppTheme.textMuted,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          'TER',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: isDark
                                ? const Color(0xFFCBD5E1)
                                : AppTheme.textMuted,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          'QUA',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: isDark
                                ? const Color(0xFFCBD5E1)
                                : AppTheme.textMuted,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          'QUI',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: isDark
                                ? const Color(0xFFCBD5E1)
                                : AppTheme.textMuted,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          'SEX',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: isDark
                                ? const Color(0xFFCBD5E1)
                                : AppTheme.textMuted,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          'SÁB',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: isDark
                                ? const Color(0xFF93C5FD)
                                : AppTheme.primaryBlue,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Grade 7 colunas Google Calendar Style
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisExtent: 72,
                  crossAxisSpacing: 3,
                  mainAxisSpacing: 3,
                ),
                itemCount: 42,
                itemBuilder: (context, index) {
                  final dayNumber = index - startingWeekday + 1;
                  final isCurrentMonth =
                      dayNumber >= 1 && dayNumber <= daysInMonth;

                  if (!isCurrentMonth) {
                    return const SizedBox.shrink();
                  }

                  final cellDate = DateTime(year, month, dayNumber);
                  final isSelected =
                      cellDate.day == selectedDate.day &&
                      cellDate.month == selectedDate.month &&
                      cellDate.year == selectedDate.year;
                  final isToday =
                      cellDate.day == DateTime.now().day &&
                      cellDate.month == DateTime.now().month &&
                      cellDate.year == DateTime.now().year;
                  final dayAppts = apptsByDay[dayNumber] ?? [];

                  return InkWell(
                    onTap: () => onSelectDate(cellDate),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 3,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDark
                                  ? const Color(0xFF3B82F6).withValues(
                                      alpha: 0.25,
                                    )
                                  : AppTheme.primaryBlue.withValues(
                                      alpha: 0.12,
                                    ))
                            : (isDark ? const Color(0xFF1E293B) : Colors.white),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSelected
                              ? (isDark
                                    ? const Color(0xFF60A5FA)
                                    : AppTheme.primaryBlue)
                              : isToday
                              ? AppTheme.accentTeal
                              : (isDark
                                    ? const Color(0xFF334155)
                                    : Colors.grey.shade200),
                          width: isSelected || isToday ? 2.0 : 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1,
                                ),
                                decoration: isToday
                                    ? BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF3B82F6)
                                            : AppTheme.primaryBlue,
                                        borderRadius: BorderRadius.circular(8),
                                      )
                                    : null,
                                child: Text(
                                  '$dayNumber',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSelected || isToday
                                        ? FontWeight.bold
                                        : FontWeight.w600,
                                    color: isToday
                                        ? Colors.white
                                        : (index % 7 == 0
                                              ? AppTheme.alertRed
                                              : (isDark
                                                    ? Colors.white
                                                    : AppTheme.textDark)),
                                  ),
                                ),
                              ),
                              if (dayAppts.length > 2)
                                Text(
                                  '+${dayAppts.length - 2}',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          for (final a in dayAppts.take(2)) ...[
                            Builder(
                              builder: (context) {
                                final color =
                                    CalendarViewHelper.getAppointmentActivityColor(
                                      a,
                                    );
                                final timeStr = AppDateUtils.formatTime(
                                  a.startTime,
                                );
                                return Container(
                                  margin: const EdgeInsets.only(top: 2),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color.withValues(
                                      alpha: isDark ? 0.35 : 0.15,
                                    ),
                                    borderRadius: BorderRadius.circular(3),
                                    border: Border.all(
                                      color: color.withValues(alpha: 0.6),
                                      width: 0.6,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        timeStr,
                                        style: TextStyle(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? color.withValues(alpha: 0.95)
                                              : color,
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      Expanded(
                                        child: Text(
                                          a.title,
                                          style: TextStyle(
                                            fontSize: 8.5,
                                            fontWeight: FontWeight.w600,
                                            color: isDark
                                                ? Colors.white
                                                : AppTheme.textDark,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),

              const Divider(height: 1),

              // Painel Inferior: Lista de compromissos do dia selecionado
              Container(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Compromissos em ${AppDateUtils.formatDate(selectedDate)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: isDark ? Colors.white : AppTheme.textDark,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text(
                            'Novo',
                            style: TextStyle(fontSize: 12),
                          ),
                          onPressed: () => onNewAppointment(selectedDate),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (selectedDayAppts.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E293B)
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF334155)
                                : Colors.grey.shade200,
                          ),
                        ),
                        child: const Center(
                          child: Text(
                            'Nenhum compromisso agendado para esta data.',
                            style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      )
                    else
                      ...selectedDayAppts.map((appt) {
                        final isDone = appt.status == 'realizado';
                        final color =
                            CalendarViewHelper.getAppointmentActivityColor(
                              appt,
                            );

                        return Card(
                          elevation: 1,
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: isDark
                                  ? const Color(0xFF334155)
                                  : Colors.grey.shade200,
                            ),
                          ),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: color.withValues(
                                  alpha: isDark ? 0.25 : 0.12,
                                ),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: color.withValues(alpha: 0.5),
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    AppDateUtils.formatTime(appt.startTime),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: color,
                                    ),
                                  ),
                                  Text(
                                    '${appt.durationMinutes}m',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: isDark
                                          ? const Color(0xFFCBD5E1)
                                          : AppTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    appt.title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      decoration: isDone
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                ),
                                if (appt.status == 'conflito' ||
                                    appt.isProvisional)
                                  Container(
                                    margin: const EdgeInsets.only(left: 6),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          (appt.status == 'conflito'
                                                  ? AppTheme.alertRed
                                                  : AppTheme.alertAmber)
                                              .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: appt.status == 'conflito'
                                            ? AppTheme.alertRed
                                            : AppTheme.alertAmber,
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      appt.status == 'conflito'
                                          ? 'CONFLITO'
                                          : 'PROVISÓRIO',
                                      style: TextStyle(
                                        color: appt.status == 'conflito'
                                            ? AppTheme.alertRed
                                            : AppTheme.alertAmber,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Text(
                              appt.status == 'conflito'
                                  ? '⚠️ Conflito de horário detectado pós-sincronização'
                                  : (appt.locationNotes ??
                                        'Status: ${appt.status}'),
                              style: TextStyle(
                                fontSize: 12,
                                color: appt.status == 'conflito'
                                    ? AppTheme.alertRed
                                    : (isDark
                                          ? const Color(0xFF94A3B8)
                                          : AppTheme.textMuted),
                                fontWeight: appt.status == 'conflito'
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.more_vert, size: 20),
                              onPressed: () => onAppointmentTap(appt),
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
