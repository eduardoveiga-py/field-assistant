import 'dart:convert';
import '../database/app_database.dart';

class DashboardMetrics {
  final int activeStudiesCount;
  final int pausedStudiesCount;
  final int heldSessionsCount;
  final int uniqueParticipantsCount;
  final int heldVisitsCount;
  final int scheduledVisitsCount;
  final int overdueVisitsCount;
  final int completedAppointmentsCount;
  final int cancelledAppointmentsCount;
  final int notHeldAppointmentsCount;
  final int totalActivitySeconds;

  DashboardMetrics({
    required this.activeStudiesCount,
    required this.pausedStudiesCount,
    required this.heldSessionsCount,
    required this.uniqueParticipantsCount,
    required this.heldVisitsCount,
    required this.scheduledVisitsCount,
    required this.overdueVisitsCount,
    required this.completedAppointmentsCount,
    required this.cancelledAppointmentsCount,
    required this.notHeldAppointmentsCount,
    required this.totalActivitySeconds,
  });
}

class AttentionItem {
  final String personId;
  final String personName;
  final String reason;
  final DateTime? actionDate;
  final String category; // 'overdue_action', 'inactive_study', 'no_next_action', 'unresolved_appointment'

  AttentionItem({
    required this.personId,
    required this.personName,
    required this.reason,
    this.actionDate,
    required this.category,
  });
}

class DashboardCalculator {
  /// Calcula métricas oficiais do dashboard respeitando as regras estritas de integridade.
  static DashboardMetrics calculate({
    required List<BibleStudyEntry> studies,
    required List<StudySessionEntry> sessions,
    required List<VisitEntry> visits,
    required List<AppointmentEntry> appointments,
    required List<ActivityRecordEntry> activities,
    required DateTime periodStart,
    required DateTime periodEnd,
    DateTime? nowOverride,
  }) {
    final now = nowOverride ?? DateTime.now();

    // 1. Estudos Ativos e Pausados (Contagem distinta de estudos, não de pessoas)
    final activeStudies = studies.where((s) => s.status.toLowerCase() == 'ativo' && s.deletedAt == null).toList();
    final pausedStudies = studies.where((s) => s.status.toLowerCase() == 'pausado' && s.deletedAt == null).toList();

    // 2. Sessões Realizadas no Período
    // Regra: Uma sessão conta como 1 sessão independente do número de pessoas.
    // Sessões canceladas ou não realizadas NÃO contam.
    final heldSessions = sessions.where((s) {
      if (s.deletedAt != null) return false;
      final status = s.status.toLowerCase();
      if (status != 'realizada') return false;
      return s.dateTimeField.isAfter(periodStart.subtract(const Duration(seconds: 1))) &&
          s.dateTimeField.isBefore(periodEnd.add(const Duration(seconds: 1)));
    }).toList();

    // 3. Participantes únicos presentes nas sessões realizadas
    final Set<String> uniqueParticipants = {};
    for (final session in heldSessions) {
      try {
        final List<dynamic> ids = jsonDecode(session.participantIds);
        for (final id in ids) {
          if (id is String && id.isNotEmpty) {
            uniqueParticipants.add(id);
          }
        }
      } catch (_) {}
    }

    // 4. Revisitas Realizadas no Período
    // Regra: Uma tentativa sem contato NÃO conta como conversa realizada.
    final heldVisits = visits.where((v) {
      if (v.deletedAt != null) return false;
      final type = v.contactType.toLowerCase();
      if (type == 'tentativa_sem_contato') return false;
      return v.dateTimeField.isAfter(periodStart.subtract(const Duration(seconds: 1))) &&
          v.dateTimeField.isBefore(periodEnd.add(const Duration(seconds: 1)));
    }).toList();

    // 5. Compromissos Futuros Agendados
    final scheduledAppts = appointments.where((a) {
      if (a.deletedAt != null) return false;
      final status = a.status.toLowerCase();
      return (status == 'planejado' || status == 'confirmado') && a.startTime.isAfter(now);
    }).toList();

    // 6. Revisitas e Compromissos Vencidos
    final overdueAppts = appointments.where((a) {
      if (a.deletedAt != null) return false;
      final status = a.status.toLowerCase();
      return (status == 'planejado' || status == 'confirmado') && a.startTime.isBefore(now);
    }).toList();

    // 7. Contagem de estados de compromissos no período
    int completedAppts = 0;
    int cancelledAppts = 0;
    int notHeldAppts = 0;

    for (final a in appointments) {
      if (a.deletedAt != null) continue;
      if (a.startTime.isAfter(periodStart.subtract(const Duration(seconds: 1))) &&
          a.startTime.isBefore(periodEnd.add(const Duration(seconds: 1)))) {
        final status = a.status.toLowerCase();
        if (status == 'realizado') completedAppts++;
        if (status == 'cancelado') cancelledAppts++;
        if (status == 'nao_realizado') notHeldAppts++;
      }
    }

    // 8. Total de atividade do período em segundos
    int totalSecs = 0;
    for (final act in activities) {
      if (act.deletedAt != null) continue;
      if (act.date.isAfter(periodStart.subtract(const Duration(seconds: 1))) &&
          act.date.isBefore(periodEnd.add(const Duration(seconds: 1)))) {
        totalSecs += act.durationSeconds;
      }
    }

    return DashboardMetrics(
      activeStudiesCount: activeStudies.length,
      pausedStudiesCount: pausedStudies.length,
      heldSessionsCount: heldSessions.length,
      uniqueParticipantsCount: uniqueParticipants.length,
      heldVisitsCount: heldVisits.length,
      scheduledVisitsCount: scheduledAppts.length,
      overdueVisitsCount: overdueAppts.length,
      completedAppointmentsCount: completedAppts,
      cancelledAppointmentsCount: cancelledAppts,
      notHeldAppointmentsCount: notHeldAppts,
      totalActivitySeconds: totalSecs,
    );
  }

  /// Gera a lista "Precisam de Atenção" com critérios transparentes e explicáveis.
  static List<AttentionItem> getAttentionItems({
    required List<PersonEntry> people,
    required List<BibleStudyEntry> studies,
    required List<StudyParticipantEntry> participants,
    required List<AppointmentEntry> appointments,
    int studyInactivityThresholdDays = 14,
    DateTime? nowOverride,
  }) {
    final now = nowOverride ?? DateTime.now();
    final items = <AttentionItem>[];

    // Mapeamento de Pessoa -> Estudo Ativo
    final personToStudy = <String, BibleStudyEntry>{};
    for (final part in participants) {
      final study = studies.firstWhere(
        (s) => s.id == part.studyId && s.status == 'ativo' && s.deletedAt == null,
        orElse: () => BibleStudyEntry(
          id: '',
          title: '',
          ownerId: '',
          startedAt: now,
          status: '',
          publicationId: '',
          language: '',
          frequency: '',
          createdAt: now,
          updatedAt: now,
          revision: 1,
        ),
      );
      if (study.id.isNotEmpty) {
        personToStudy[part.personId] = study;
      }
    }

    for (final person in people) {
      if (person.deletedAt != null) continue;

      // 1. Próxima ação vencida
      if (person.nextActionAt != null && person.nextActionAt!.isBefore(now)) {
        items.add(AttentionItem(
          personId: person.id,
          personName: person.name,
          reason: 'Ação planejada está vencida desde ${person.nextActionAt!.day}/${person.nextActionAt!.month}/${person.nextActionAt!.year}',
          actionDate: person.nextActionAt,
          category: 'overdue_action',
        ));
        continue;
      }

      // 2. Estudo ativo sem sessão registrada há mais tempo que o limiar configurado
      final study = personToStudy[person.id];
      if (study != null) {
        final lastSession = study.lastSessionAt ?? study.startedAt;
        final daysSinceLast = now.difference(lastSession).inDays;
        if (daysSinceLast >= studyInactivityThresholdDays) {
          items.add(AttentionItem(
            personId: person.id,
            personName: person.name,
            reason: 'Estudo "${study.title}" sem sessão registrada há $daysSinceLast dias (limiar: $studyInactivityThresholdDays dias)',
            actionDate: lastSession,
            category: 'inactive_study',
          ));
          continue;
        }
      }

      // 3. Pessoa sem próxima ação planejada
      if (person.nextActionAt == null && person.status != 'outro') {
        items.add(AttentionItem(
          personId: person.id,
          personName: person.name,
          reason: 'Nenhum retorno ou próxima ação cadastrada para este contato',
          actionDate: null,
          category: 'no_next_action',
        ));
        continue;
      }

      // 4. Compromisso vencido que precisa de resolução
      final pastUnresolved = appointments.where((a) =>
          a.personId == person.id &&
          a.deletedAt == null &&
          (a.status == 'planejado' || a.status == 'confirmado') &&
          a.startTime.isBefore(now));
      if (pastUnresolved.isNotEmpty) {
        items.add(AttentionItem(
          personId: person.id,
          personName: person.name,
          reason: 'Compromisso agendado passou e precisa ser marcado como realizado ou reagendado',
          actionDate: pastUnresolved.first.startTime,
          category: 'unresolved_appointment',
        ));
      }
    }

    return items;
  }
}
