import 'package:flutter/material.dart';
import '../../../database/app_database.dart';

class CalendarViewHelper {
  static Color getAppointmentActivityColor(AppointmentEntry appt) {
    final titleLower = appt.title.toLowerCase();
    if (titleLower.contains('viagem')) return const Color(0xFF0D9488);
    if (titleLower.contains('ausência') || titleLower.contains('ausencia')) {
      return const Color(0xFFD97706);
    }
    if (titleLower.contains('folga')) return const Color(0xFF64748B);
    if (titleLower.contains('pessoal')) {
      return const Color(0xFF9333EA);
    }
    if (titleLower.contains('outro')) {
      return const Color(0xFF475569);
    }
    if (titleLower.contains('estudo') || appt.studyId != null) {
      return const Color(0xFF059669);
    }
    if (titleLower.contains('revisita')) {
      return const Color(0xFFEA580C);
    }
    return const Color(0xFF2563EB);
  }
}
