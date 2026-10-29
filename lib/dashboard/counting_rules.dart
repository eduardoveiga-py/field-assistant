import 'dart:convert';
import '../database/app_database.dart';

class DashboardMetrics {
  final int activeStudiesCount;
  final int pausedStudiesCount;
  final int endedStudiesCount;
  final Map<String, int> endedStudiesByReason;
  final int heldSessionsCount;
  final int uniqueParticipantsCount;
  final int heldVisitsCount;
  final int scheduledVisitsCount;
  final int overdueVisitsCount;
  final int completedAppointmentsCount;
  final int cancelledAppointmentsCount;
  final int notHeldAppointmentsCount;
  final int totalActivitySeconds;
  final int pendingNextActionCount;
  final int noRecentContactCount;
  final int totalStudyAttendance;
  final double averageAttendancePerStudy;
  final int totalPlacements;
  final int totalVideos;
  final int notAtHomeCount;
  final double scheduleRegularityPercentage;

  // Funil de Conversão do Ministério
  final int funnelInterestedCount;
  final int funnelFirstReturnVisitCount;
  final int funnelStartedStudyCount;
  final int funnelReachedPart3Count;
  final int funnelDroppedOutCount;
  final int endedVisitsCount;
  final Map<String, int> endedVisitsByReason;

  DashboardMetrics({
    required this.activeStudiesCount,
    required this.pausedStudiesCount,
    this.endedStudiesCount = 0,
    this.endedStudiesByReason = const {},
    this.endedVisitsCount = 0,
    this.endedVisitsByReason = const {},
    required this.heldSessionsCount,
    required this.uniqueParticipantsCount,
    required this.heldVisitsCount,
    required this.scheduledVisitsCount,
    required this.overdueVisitsCount,
    required this.completedAppointmentsCount,
    required this.cancelledAppointmentsCount,
    required this.notHeldAppointmentsCount,
    required this.totalActivitySeconds,
    this.pendingNextActionCount = 0,
    this.noRecentContactCount = 0,
    this.totalStudyAttendance = 0,
    this.averageAttendancePerStudy = 0.0,
    this.totalPlacements = 0,
    this.totalVideos = 0,
    this.notAtHomeCount = 0,
    this.scheduleRegularityPercentage = 100.0,
    this.funnelInterestedCount = 0,
    this.funnelFirstReturnVisitCount = 0,
    this.funnelStartedStudyCount = 0,
    this.funnelReachedPart3Count = 0,
    this.funnelDroppedOutCount = 0,
  });

  Map<String, int> get endedByReason => endedStudiesByReason;
}

class StudentProgressMetrics {
  final int totalVisits;
  final int notAtHomeCount;
  final double regularityPercentage;
  final double averageAttendance;
  final int currentLesson;
  final bool reachedPart3;
  final bool isContinuing;
  final String? endReason;
  final String? milestoneDescription;

  StudentProgressMetrics({
    required this.totalVisits,
    required this.notAtHomeCount,
    required this.regularityPercentage,
    required this.averageAttendance,
    required this.currentLesson,
    required this.reachedPart3,
    required this.isContinuing,
    this.endReason,
    this.milestoneDescription,
  });

  bool get isPart3Reached => reachedPart3;
  bool get isBookCompleted => currentLesson >= 60;
  double get averageAttendees => averageAttendance;
  double get regularityPercent => regularityPercentage;
  int get notAtHomeVisits => notAtHomeCount;
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
    List<PersonEntry> people = const [],
    List<StudyParticipantEntry> participants = const [],
    required DateTime periodStart,
    required DateTime periodEnd,
    DateTime? nowOverride,
  }) {
    final now = nowOverride ?? DateTime.now();

    // Mapeamento de Participantes por Estudo
    final studyParticipantMap = <String, Set<String>>{};
    for (final part in participants) {
      if (part.deletedAt == null) {
        studyParticipantMap.putIfAbsent(part.studyId, () => {}).add(part.personId);
      }
    }

    // 1. Filtragem de Contatos Ativos (Exclui pessoas com status 'revisita_passada')
    final passedPersonIds = people
        .where((p) => p.status.toLowerCase() == 'revisita_passada' && p.deletedAt == null)
        .map((p) => p.id)
        .toSet();

    final activePeople = people
        .where((p) => p.deletedAt == null && !passedPersonIds.contains(p.id))
        .toList();

    // 3. Sessões Realizadas no Período (Nada é perdido mesmo se o estudo ou contato foi excluído ou repassado)
    final heldSessions = sessions.where((s) {
      if (s.deletedAt != null) return false;
      final status = s.status.toLowerCase();
      if (status != 'realizada') return false;
      return s.dateTimeField.isAfter(periodStart.subtract(const Duration(seconds: 1))) &&
          s.dateTimeField.isBefore(periodEnd.add(const Duration(seconds: 1)));
    }).toList();

    // 2. Estudos Ativos no período (inclui estudos ativos ou que tiveram sessão realizada no período)
    final activeStudies = studies.where((s) {
      final hasSessionInPeriod = heldSessions.any((sess) => sess.studyId == s.id);
      if (hasSessionInPeriod) return true; // Se teve sessão no mês, conta nas estatísticas do mês!

      if (s.status.toLowerCase() != 'ativo' || s.deletedAt != null) return false;
      final partIds = studyParticipantMap[s.id];
      if (partIds != null && partIds.isNotEmpty && partIds.every((id) => passedPersonIds.contains(id))) {
        return false;
      }
      return true;
    }).toList();

    final pausedStudies = studies
        .where((s) => s.status.toLowerCase() == 'pausado' && s.deletedAt == null)
        .toList();
    final endedStudies = studies
        .where((s) => (s.status.toLowerCase() == 'encerrado' || s.status.toLowerCase() == 'concluido') && s.deletedAt == null)
        .toList();

    final Map<String, int> endedByReason = {};
    for (final s in endedStudies) {
      String reason = 'Outro';
      if (s.pauseOrCloseReason != null && s.pauseOrCloseReason!.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(s.pauseOrCloseReason!);
          if (decoded is Map && decoded.containsKey('endReason') && decoded['endReason'].toString().trim().isNotEmpty) {
            reason = decoded['endReason'].toString().trim();
          } else {
            reason = s.pauseOrCloseReason!.trim();
          }
        } catch (_) {
          reason = s.pauseOrCloseReason!.trim();
        }
      } else if (s.status.toLowerCase() == 'concluido') {
        reason = 'Estudo concluído / Batizado';
      }
      endedByReason[reason] = (endedByReason[reason] ?? 0) + 1;
    }

    // Contagem de Revisitas Encerradas (com motivo)
    final endedVisitsPeople = people.where((p) {
      if (p.deletedAt != null) return false;
      return p.status.toLowerCase() == 'revisita_encerrada';
    }).toList();

    final Map<String, int> endedVisitsByReason = {};
    for (final p in endedVisitsPeople) {
      String reason = 'Outro';
      if (p.contactRestrictions != null && p.contactRestrictions!.isNotEmpty) {
        try {
          final decoded = jsonDecode(p.contactRestrictions!);
          if (decoded is Map && decoded.containsKey('endReason') && decoded['endReason'].toString().trim().isNotEmpty) {
            reason = decoded['endReason'].toString().trim();
          }
        } catch (_) {}
      } else if (p.nextActionNote != null && p.nextActionNote!.contains('Revisita encerrada:')) {
        reason = p.nextActionNote!.replaceAll('Revisita encerrada:', '').split('-').first.trim();
      }
      endedVisitsByReason[reason] = (endedVisitsByReason[reason] ?? 0) + 1;
    }

    // 4. Participantes únicos presentes nas sessões realizadas
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

    // 5. Revisitas Realizadas no Período (Nada é perdido mesmo se contato foi repassado ou excluído depois)
    final heldVisits = visits.where((v) {
      if (v.deletedAt != null) return false;
      final type = v.contactType.toLowerCase();
      if (type == 'tentativa_sem_contato') return false;
      return v.dateTimeField.isAfter(periodStart.subtract(const Duration(seconds: 1))) &&
          v.dateTimeField.isBefore(periodEnd.add(const Duration(seconds: 1)));
    }).toList();

    // 6. Não Estavam em Casa (Tentativas sem contato e ausências)
    final notAtHomeVisits = visits.where((v) {
      if (v.deletedAt != null) return false;
      final type = v.contactType.toLowerCase();
      final res = v.result.toLowerCase();
      final isAbsent = type == 'tentativa_sem_contato' ||
          res.contains('não estava') ||
          res.contains('nao estava') ||
          res.contains('ausente') ||
          res.contains('não atendeu') ||
          res.contains('nao atendeu');
      return isAbsent &&
          v.dateTimeField.isAfter(periodStart.subtract(const Duration(seconds: 1))) &&
          v.dateTimeField.isBefore(periodEnd.add(const Duration(seconds: 1)));
    }).toList();

    // 7. Compromissos Futuros Agendados (Exclui revisitas passadas)
    final scheduledAppts = appointments.where((a) {
      if (a.deletedAt != null) return false;
      if (a.personId != null && passedPersonIds.contains(a.personId)) return false;
      final status = a.status.toLowerCase();
      return (status == 'planejado' || status == 'confirmado') && a.startTime.isAfter(now);
    }).toList();

    // 8. Revisitas e Compromissos Vencidos
    final overdueAppts = appointments.where((a) {
      if (a.deletedAt != null) return false;
      if (a.personId != null && passedPersonIds.contains(a.personId)) return false;
      final status = a.status.toLowerCase();
      return (status == 'planejado' || status == 'confirmado') && a.startTime.isBefore(now);
    }).toList();

    // 9. Contagem de estados de compromissos no período
    int completedAppts = 0;
    int cancelledAppts = 0;
    int notHeldAppts = 0;

    for (final a in appointments) {
      if (a.deletedAt != null) continue;
      if (a.personId != null && passedPersonIds.contains(a.personId)) continue;
      if (a.startTime.isAfter(periodStart.subtract(const Duration(seconds: 1))) &&
          a.startTime.isBefore(periodEnd.add(const Duration(seconds: 1)))) {
        final status = a.status.toLowerCase();
        if (status == 'realizado') completedAppts++;
        if (status == 'cancelado') cancelledAppts++;
        if (status == 'nao_realizado') notHeldAppts++;
      }
    }

    // 10. Total de atividade do período em segundos
    int totalSecs = 0;
    for (final act in activities) {
      if (act.deletedAt != null) continue;
      if (act.date.isAfter(periodStart.subtract(const Duration(seconds: 1))) &&
          act.date.isBefore(periodEnd.add(const Duration(seconds: 1)))) {
        totalSecs += act.durationSeconds;
      }
    }

    // 11. Pessoas com próximo passo pendente / vencido
    final pendingNextActions = activePeople.where((p) =>
        p.nextActionAt != null && p.nextActionAt!.isBefore(now)).length;

    // 12. Pessoas sem contato recente (> 30 dias ou nunca contatadas)
    final noRecentContact = activePeople.where((p) =>
        p.status != 'outro' &&
        (p.lastContactAt == null || now.difference(p.lastContactAt!).inDays >= 30)).length;

    // 13. Assistência Total e Média por Estudo Bíblico no Período
    int totalAttendance = 0;
    for (final session in heldSessions) {
      totalAttendance += parseSessionAttendance(session);
    }
    final double avgAttendance = heldSessions.isNotEmpty
        ? (totalAttendance / heldSessions.length)
        : 0.0;

    // 14. Publicações e Vídeos
    int placements = 0;
    int videos = 0;
    for (final act in activities) {
      if (act.deletedAt != null) continue;
      if (act.date.isAfter(periodStart.subtract(const Duration(seconds: 1))) &&
          act.date.isBefore(periodEnd.add(const Duration(seconds: 1)))) {
        if (act.notes != null) {
          placements += parsePlacementsFromNotes(act.notes);
          videos += parseVideosFromNotes(act.notes);
        }
      }
    }
    for (final v in visits) {
      if (v.deletedAt != null) continue;
      if (passedPersonIds.contains(v.personId)) continue;
      if (v.dateTimeField.isAfter(periodStart.subtract(const Duration(seconds: 1))) &&
          v.dateTimeField.isBefore(periodEnd.add(const Duration(seconds: 1)))) {
        if (v.scriptureOrPub != null && v.scriptureOrPub!.trim().isNotEmpty) {
          placements += 1;
        }
      }
    }

    // 15. FUNIL DE CONVERSÃO DO MINISTÉRIO
    // - Interessados (total primeiro contato)
    final funnelInterested = activePeople.length;

    // - Quantas deram certo a 1ª Revisita (com >= 1 revisita realizada ou status revisita/estudo)
    final peopleWithHeldVisit = visits
        .where((v) => v.deletedAt == null && v.contactType != 'tentativa_sem_contato')
        .map((v) => v.personId)
        .toSet();
    final funnelFirstReturn = activePeople.where((p) =>
        p.status == 'revisita' || p.status == 'estudo' || peopleWithHeldVisit.contains(p.id)).length;

    // - Quantas iniciaram um estudo (status estudo ou estudo bíblico vinculado)
    final funnelStartedStudy = studies.where((s) => s.deletedAt == null).length;

    // - Quantas estudam até a parte 3 e continuam com o livro
    // Seção 3 do livro Seja Feliz Para Sempre! inicia na Lição 34
    final funnelReachedPart3 = studies.where((s) =>
        s.deletedAt == null &&
        s.status == 'ativo' &&
        (s.currentLesson ?? 1) >= 34).length;

    // - Quantas não seguem (estudos encerrados ou pausados)
    final funnelDroppedOut = endedStudies.length + pausedStudies.length;

    // 16. Regularidade Geral no Dia e Horário Oficial
    int regularSessionsCount = 0;
    final weekdaysMap = {
      'seg': DateTime.monday,
      'ter': DateTime.tuesday,
      'qua': DateTime.wednesday,
      'qui': DateTime.thursday,
      'sex': DateTime.friday,
      'sáb': DateTime.saturday,
      'sab': DateTime.saturday,
      'dom': DateTime.sunday,
    };
    for (final s in heldSessions) {
      final study = studies.where((st) => st.id == s.studyId).firstOrNull;
      if (study != null) {
        PersonEntry? participant;
        try {
          final List<dynamic> partIds = jsonDecode(s.participantIds);
          if (partIds.isNotEmpty) {
            participant = people.where((p) => p.id == partIds.first).firstOrNull;
          }
        } catch (_) {}
        if (participant == null) {
          final partIds = studyParticipantMap[study.id];
          if (partIds != null && partIds.isNotEmpty) {
            participant = people.where((p) => p.id == partIds.first).firstOrNull;
          }
        }

        final sched = (participant?.preferredSchedule ?? '').toLowerCase();
        int? officialWeekday;
        for (final entry in weekdaysMap.entries) {
          if (sched.contains(entry.key)) {
            officialWeekday = entry.value;
            break;
          }
        }

        if (officialWeekday != null) {
          if (s.dateTimeField.weekday == officialWeekday) {
            regularSessionsCount++;
          }
        } else {
          regularSessionsCount++;
        }
      }
    }
    final regularityPct = heldSessions.isNotEmpty
        ? (regularSessionsCount / heldSessions.length) * 100.0
        : 100.0;

    return DashboardMetrics(
      activeStudiesCount: activeStudies.length,
      pausedStudiesCount: pausedStudies.length,
      endedStudiesCount: endedStudies.length,
      endedStudiesByReason: endedByReason,
      endedVisitsCount: endedVisitsPeople.length,
      endedVisitsByReason: endedVisitsByReason,
      heldSessionsCount: heldSessions.length,
      uniqueParticipantsCount: uniqueParticipants.length,
      heldVisitsCount: heldVisits.length,
      scheduledVisitsCount: scheduledAppts.length,
      overdueVisitsCount: overdueAppts.length,
      completedAppointmentsCount: completedAppts,
      cancelledAppointmentsCount: cancelledAppts,
      notHeldAppointmentsCount: notHeldAppts,
      totalActivitySeconds: totalSecs,
      pendingNextActionCount: pendingNextActions,
      noRecentContactCount: noRecentContact,
      totalStudyAttendance: totalAttendance,
      averageAttendancePerStudy: double.parse(avgAttendance.toStringAsFixed(1)),
      totalPlacements: placements,
      totalVideos: videos,
      notAtHomeCount: notAtHomeVisits.length,
      scheduleRegularityPercentage: double.parse(regularityPct.toStringAsFixed(1)),
      funnelInterestedCount: funnelInterested,
      funnelFirstReturnVisitCount: funnelFirstReturn,
      funnelStartedStudyCount: funnelStartedStudy,
      funnelReachedPart3Count: funnelReachedPart3,
      funnelDroppedOutCount: funnelDroppedOut,
    );
  }

  /// Calcula métricas individuais de progresso para um estudante específico
  static StudentProgressMetrics calculateStudentMetrics({
    required PersonEntry person,
    required BibleStudyEntry? study,
    required List<VisitEntry> visits,
    required List<StudySessionEntry> sessions,
  }) {
    final personVisits = visits.where((v) => v.personId == person.id && v.deletedAt == null).toList();
    final personSessions = study != null
        ? sessions.where((s) => s.studyId == study.id && s.deletedAt == null).toList()
        : <StudySessionEntry>[];

    final totalVisits = personVisits.length + personSessions.length;

    // Contagem de vezes que não estava em casa
    final notAtHomeCount = personVisits.where((v) {
      final type = v.contactType.toLowerCase();
      final res = v.result.toLowerCase();
      return type == 'tentativa_sem_contato' ||
          res.contains('não estava') ||
          res.contains('nao estava') ||
          res.contains('ausente') ||
          res.contains('não atendeu') ||
          res.contains('nao atendeu');
    }).length;

    // Média de pessoas que acompanham o estudo
    int totalAttendance = 0;
    int sessionsWithCount = 0;
    for (final s in personSessions) {
      if (s.status == 'realizada') {
        totalAttendance += parseSessionAttendance(s);
        sessionsWithCount++;
      }
    }
    for (final v in personVisits) {
      if (v.contactType != 'tentativa_sem_contato') {
        totalAttendance += parseVisitAttendance(v);
        sessionsWithCount++;
      }
    }
    final avgAttendance = sessionsWithCount > 0
        ? double.parse((totalAttendance / sessionsWithCount).toStringAsFixed(1))
        : 1.0;

    // Regularidade no dia e horário oficial
    double regularity = 100.0;
    final sched = (person.preferredSchedule ?? '').toLowerCase();
    if (sched.isNotEmpty && sessionsWithCount > 0) {
      int onScheduleCount = 0;
      final weekdaysMap = {
        'seg': DateTime.monday,
        'ter': DateTime.tuesday,
        'qua': DateTime.wednesday,
        'qui': DateTime.thursday,
        'sex': DateTime.friday,
        'sáb': DateTime.saturday,
        'sab': DateTime.saturday,
        'dom': DateTime.sunday,
      };
      int? targetWeekday;
      for (final entry in weekdaysMap.entries) {
        if (sched.contains(entry.key)) {
          targetWeekday = entry.value;
          break;
        }
      }

      if (targetWeekday != null) {
        for (final s in personSessions) {
          if (s.dateTimeField.weekday == targetWeekday) onScheduleCount++;
        }
        for (final v in personVisits) {
          if (v.dateTimeField.weekday == targetWeekday) onScheduleCount++;
        }
        regularity = double.parse(((onScheduleCount / sessionsWithCount) * 100.0).clamp(0.0, 100.0).toStringAsFixed(1));
      }
    }

    final currentLesson = study?.currentLesson ?? 1;
    final reachedPart3 = currentLesson >= 34; // Seção 3 do livro Seja Feliz Para Sempre
    final isContinuing = study?.status == 'ativo';

    return StudentProgressMetrics(
      totalVisits: totalVisits,
      notAtHomeCount: notAtHomeCount,
      regularityPercentage: regularity,
      averageAttendance: avgAttendance,
      currentLesson: currentLesson,
      reachedPart3: reachedPart3,
      isContinuing: isContinuing,
    );
  }

  /// Extrai a quantidade de presentes/assistência de uma sessão de estudo bíblico.
  static int parseSessionAttendance(StudySessionEntry session) {
    if (session.sessionNotes != null) {
      final match = RegExp(r'\[?(?:assistência|assistencia|presentes|attendance):\s*(\d+)\]?', caseSensitive: false)
          .firstMatch(session.sessionNotes!);
      if (match != null) {
        final val = int.tryParse(match.group(1)!);
        if (val != null && val > 0) return val;
      }
    }
    try {
      final List<dynamic> ids = jsonDecode(session.participantIds);
      if (ids.isNotEmpty) return ids.length;
    } catch (_) {}
    return 1;
  }

  /// Formata as notas da sessão embasando a contagem de assistência.
  static String formatSessionNotesWithAttendance(String? notes, int attendance) {
    final clean = cleanSessionNotes(notes);
    final count = attendance > 0 ? attendance : 1;
    if (clean.isEmpty) {
      return '[Assistência: $count]';
    }
    return '[Assistência: $count]\n$clean';
  }

  /// Extrai a contagem de pessoas atendidas / presentes em uma visita ou conversa inicial
  static int parseVisitAttendance(VisitEntry visit) {
    final text = '${visit.notes ?? ""} ${visit.topicsDiscussed ?? ""} ${visit.result}';
    final match = RegExp(r'\[(?:assistência|assistencia|presentes|attendance):\s*(\d+)\]', caseSensitive: false)
        .firstMatch(text);
    if (match != null) {
      final val = int.tryParse(match.group(1)!);
      if (val != null && val > 0) return val;
    }
    return 1;
  }

  /// Formata as notas da visita com a contagem de ouvintes / assistência
  static String formatVisitNotesWithAttendance(String? notes, int attendance) {
    final clean = (notes ?? '').replaceAll(RegExp(r'\[(?:assistência|assistencia|presentes|attendance):\s*\d+\]\s*', caseSensitive: false), '').trim();
    final count = attendance > 0 ? attendance : 1;
    if (clean.isEmpty) {
      return '[Assistência: $count]';
    }
    return '[Assistência: $count]\n$clean';
  }

  /// Remove marcadores técnicos da observação da sessão para exibição limpa.
  static String cleanSessionNotes(String? notes) {
    if (notes == null) return '';
    return notes
        .replaceAll(RegExp(r'\[(?:assistência|assistencia|presentes|attendance):\s*\d+\]\s*', caseSensitive: false), '')
        .trim();
  }

  /// Extrai contagem de publicações das notas de atividade
  static int parsePlacementsFromNotes(String? notes) {
    if (notes == null) return 0;
    final match = RegExp(r'\[(?:publicações|publicacoes|placements):\s*(\d+)\]', caseSensitive: false)
        .firstMatch(notes);
    if (match != null) {
      return int.tryParse(match.group(1)!) ?? 0;
    }
    return 0;
  }

  /// Extrai contagem de vídeos das notas de atividade
  static int parseVideosFromNotes(String? notes) {
    if (notes == null) return 0;
    final match = RegExp(r'\[(?:vídeos|videos):\s*(\d+)\]', caseSensitive: false)
        .firstMatch(notes);
    if (match != null) {
      return int.tryParse(match.group(1)!) ?? 0;
    }
    return 0;
  }

  /// Formata notas de atividade com publicações e vídeos
  static String formatActivityNotes({String? userNotes, int placements = 0, int videos = 0}) {
    final clean = cleanActivityNotes(userNotes);
    final parts = <String>[];
    if (placements > 0) parts.add('[Publicações: $placements]');
    if (videos > 0) parts.add('[Vídeos: $videos]');
    if (parts.isEmpty) return clean;
    if (clean.isEmpty) return parts.join(' ');
    return '${parts.join(" ")}\n$clean';
  }

  /// Remove tags de publicações/vídeos das notas
  static String cleanActivityNotes(String? notes) {
    if (notes == null) return '';
    return notes
        .replaceAll(RegExp(r'\[(?:publicações|publicacoes|placements):\s*\d+\]\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[(?:vídeos|videos):\s*\d+\]\s*', caseSensitive: false), '')
        .trim();
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
      // Exclui pessoas com status 'revisita_passada'
      if (person.status.toLowerCase() == 'revisita_passada') continue;

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

  /// Calcula métricas de acompanhamento de um estudante específico
  static StudentProgressMetrics calculateStudentProgress({
    required PersonEntry person,
    required BibleStudyEntry study,
    required List<StudySessionEntry> sessions,
    required List<VisitEntry> visits,
  }) {
    final validVisits = visits.where((v) => v.deletedAt == null).toList();
    final totalVisits = validVisits.length;
    final notAtHomeVisits = validVisits.where((v) {
      final res = v.result.toLowerCase();
      final notes = (v.notes ?? '').toLowerCase();
      return res.contains('ausente') ||
          res.contains('nao_em_casa') ||
          res.contains('não estava') ||
          notes.contains('não estava em casa') ||
          notes.contains('ausente');
    }).length;

    final validSessions = sessions.where((s) => s.deletedAt == null).toList();
    final sched = (person.preferredSchedule ?? '').toLowerCase();
    final weekdaysMap = {
      'seg': DateTime.monday,
      'ter': DateTime.tuesday,
      'qua': DateTime.wednesday,
      'qui': DateTime.thursday,
      'sex': DateTime.friday,
      'sáb': DateTime.saturday,
      'sab': DateTime.saturday,
      'dom': DateTime.sunday,
    };
    int? officialWeekday;
    for (final entry in weekdaysMap.entries) {
      if (sched.contains(entry.key)) {
        officialWeekday = entry.value;
        break;
      }
    }

    if (officialWeekday == null && validSessions.isNotEmpty) {
      final counts = <int, int>{};
      for (final s in validSessions) {
        counts[s.dateTimeField.weekday] = (counts[s.dateTimeField.weekday] ?? 0) + 1;
      }
      var maxCount = 0;
      counts.forEach((day, count) {
        if (count > maxCount) {
          maxCount = count;
          officialWeekday = day;
        }
      });
    }

    double regularityPercent = 100.0;
    if (validSessions.isNotEmpty && officialWeekday != null) {
      int onScheduleCount = 0;
      for (final s in validSessions) {
        if (s.dateTimeField.weekday == officialWeekday) {
          onScheduleCount++;
        }
      }
      regularityPercent = double.parse(((onScheduleCount / validSessions.length) * 100.0).toStringAsFixed(1));
    }

    int totalAttendees = 0;
    for (final s in validSessions) {
      totalAttendees += parseSessionAttendance(s);
    }
    final avgAttendees = validSessions.isNotEmpty
        ? totalAttendees / validSessions.length
        : 1.0;

    final lesson = study.currentLesson ?? 1;
    final isPart3 = lesson >= 34;
    final isContinuing = study.status.toLowerCase() == 'ativo';
    String? endReason;
    if (study.pauseOrCloseReason != null && study.pauseOrCloseReason!.isNotEmpty) {
      try {
        final d = jsonDecode(study.pauseOrCloseReason!);
        if (d is Map && d.containsKey('endReason')) endReason = d['endReason'];
      } catch (_) {
        endReason = study.pauseOrCloseReason;
      }
    }
    final milestoneDesc = isPart3
        ? 'Alcançou a Parte 3 (Lição $lesson de 60) - Rumo ao Batismo!'
        : 'Na Lição $lesson de 60 (Lição 34 inicia a Parte 3)';

    return StudentProgressMetrics(
      totalVisits: totalVisits,
      notAtHomeCount: notAtHomeVisits,
      regularityPercentage: regularityPercent,
      averageAttendance: avgAttendees,
      currentLesson: lesson,
      reachedPart3: isPart3,
      isContinuing: isContinuing,
      endReason: endReason,
      milestoneDescription: milestoneDesc,
    );
  }
}
