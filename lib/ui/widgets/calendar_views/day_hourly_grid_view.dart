import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../core/date_utils.dart';
import '../../../database/app_database.dart';
import 'calendar_view_helper.dart';

class DayHourlyGridView extends StatelessWidget {
  final DateTime selectedDate;
  final List<AppointmentEntry> allAppointments;
  final ScrollController timeScrollController;
  final ValueChanged<AppointmentEntry> onAppointmentTap;
  final ValueChanged<DateTime> onNewAppointmentAtTime;
  final bool isDark;

  const DayHourlyGridView({
    super.key,
    required this.selectedDate,
    required this.allAppointments,
    required this.timeScrollController,
    required this.onAppointmentTap,
    required this.onNewAppointmentAtTime,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final dayAppts = allAppointments
        .where(
          (a) =>
              a.deletedAt == null &&
              a.startTime.year == selectedDate.year &&
              a.startTime.month == selectedDate.month &&
              a.startTime.day == selectedDate.day,
        )
        .toList();

    return SingleChildScrollView(
      controller: timeScrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            children: List.generate(16, (i) {
              final hour = 7 + i; // 07:00 às 22:00
              final hourStart = DateTime(
                selectedDate.year,
                selectedDate.month,
                selectedDate.day,
                hour,
                0,
              );
              final hourEnd = hourStart.add(const Duration(hours: 1));

              final inThisHour = dayAppts
                  .where(
                    (a) =>
                        a.startTime.isBefore(hourEnd) &&
                        a.endTime.isAfter(hourStart),
                  )
                  .toList();

              return Container(
                height: 60,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 50,
                      child: Text(
                        '${hour.toString().padLeft(2, '0')}:00',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : AppTheme.textMuted,
                        ),
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: inThisHour.isEmpty
                          ? InkWell(
                              onTap: () => onNewAppointmentAtTime(hourStart),
                              child: const SizedBox.expand(),
                            )
                          : ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: inThisHour.length,
                              itemBuilder: (ctx, idx) {
                                final appt = inThisHour[idx];
                                final color =
                                    CalendarViewHelper.getAppointmentActivityColor(
                                      appt,
                                    );
                                return InkWell(
                                  onTap: () => onAppointmentTap(appt),
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 4,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: color.withValues(
                                        alpha: isDark ? 0.35 : 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: color.withValues(alpha: 0.6),
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${AppDateUtils.formatTime(appt.startTime)} ${appt.title}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white : color,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
