import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../core/date_utils.dart';
import '../../../database/app_database.dart';
import 'calendar_view_helper.dart';

class WeekCalendarView extends StatelessWidget {
  final DateTime selectedDate;
  final List<AppointmentEntry> allAppointments;
  final ValueChanged<DateTime> onSelectDate;
  final ValueChanged<AppointmentEntry> onAppointmentTap;
  final bool isDark;

  const WeekCalendarView({
    super.key,
    required this.selectedDate,
    required this.allAppointments,
    required this.onSelectDate,
    required this.onAppointmentTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final monday = selectedDate.subtract(
      Duration(days: (selectedDate.weekday - 1) % 7),
    );
    final weekDays = List.generate(7, (i) => monday.add(Duration(days: i)));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
      itemCount: 7,
      itemBuilder: (context, index) {
        final day = weekDays[index];
        final isToday =
            day.day == DateTime.now().day &&
            day.month == DateTime.now().month &&
            day.year == DateTime.now().year;
        final dayAppts =
            allAppointments
                .where(
                  (a) =>
                      a.deletedAt == null &&
                      a.startTime.year == day.year &&
                      a.startTime.month == day.month &&
                      a.startTime.day == day.day,
                )
                .toList()
              ..sort((a, b) => a.startTime.compareTo(b.startTime));

        const weekdayNames = [
          'Segunda',
          'Terça',
          'Quarta',
          'Quinta',
          'Sexta',
          'Sábado',
          'Domingo',
        ];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isToday
                  ? AppTheme.accentTeal
                  : (isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0)),
              width: isToday ? 2.0 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isToday
                      ? (isDark
                            ? const Color(0xFF3B82F6).withValues(alpha: 0.25)
                            : AppTheme.primaryBlue.withValues(alpha: 0.1))
                      : (isDark
                            ? const Color(0xFF0F172A)
                            : const Color(0xFFF8FAFC)),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(9),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${weekdayNames[index]} • ${AppDateUtils.formatDate(day)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isToday
                            ? AppTheme.primaryBlue
                            : (isDark ? Colors.white : AppTheme.textDark),
                      ),
                    ),
                    Text(
                      '${dayAppts.length} compromisso(s)',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (dayAppts.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Nenhum compromisso',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                )
              else
                ...dayAppts.map((appt) {
                  final color =
                      CalendarViewHelper.getAppointmentActivityColor(appt);
                  return ListTile(
                    dense: true,
                    leading: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: isDark ? 0.3 : 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        AppDateUtils.formatTime(appt.startTime),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: color,
                        ),
                      ),
                    ),
                    title: Text(
                      appt.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: appt.locationNotes != null
                        ? Text(
                            appt.locationNotes!,
                            style: const TextStyle(fontSize: 11),
                          )
                        : null,
                    trailing: IconButton(
                      icon: const Icon(Icons.more_vert, size: 18),
                      onPressed: () => onAppointmentTap(appt),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}
