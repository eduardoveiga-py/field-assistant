import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../core/date_utils.dart';
import '../../../database/app_database.dart';
import 'calendar_view_helper.dart';

class AppointmentListView extends StatelessWidget {
  final List<AppointmentEntry> allAppointments;
  final ValueChanged<AppointmentEntry> onAppointmentTap;
  final bool isDark;

  const AppointmentListView({
    super.key,
    required this.allAppointments,
    required this.onAppointmentTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final activeAppts =
        allAppointments
            .where((a) => a.deletedAt == null && a.status != 'cancelado')
            .toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));

    if (activeAppts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.event_note, size: 56, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              const Text(
                'Nenhum compromisso cadastrado na agenda.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textMuted, fontSize: 15),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
      itemCount: activeAppts.length,
      itemBuilder: (context, index) {
        final appt = activeAppts[index];
        final isDone = appt.status == 'realizado';
        final color = CalendarViewHelper.getAppointmentActivityColor(appt);

        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.3 : 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: color.withValues(alpha: 0.5)),
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
                      fontSize: 10,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            title: Text(
              appt.title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                decoration: isDone ? TextDecoration.lineThrough : null,
              ),
            ),
            subtitle: Text(
              '${AppDateUtils.formatDate(appt.startTime)} • ${appt.locationNotes ?? appt.status}',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? const Color(0xFF94A3B8) : AppTheme.textMuted,
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.more_vert, size: 20),
              onPressed: () => onAppointmentTap(appt),
            ),
          ),
        );
      },
    );
  }
}
