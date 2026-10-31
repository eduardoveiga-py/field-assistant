import 'dart:math' as math;
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/publications/publication_link_resolver.dart';
import 'package:ministerio_pessoal/territory/geolocation_helper.dart';

// ============================================================================
// Requirement R1: Briefing na Porta (Interface Contract & Logic)
// ============================================================================

class DoorstepBriefingData {
  final String? lessonAndPoint; // ex: "Lição 04, Ponto 3"
  final Uri? jwLibraryUri; // URL oficial jw.org / JW Library
  final String? pendingDoubt; // Dúvida ou próximo passo da última visita
  final String? spiritualGoal; // Alvo espiritual ativo
  final String? empathyNote; // Observação ou necessidade pessoal recente

  const DoorstepBriefingData({
    this.lessonAndPoint,
    this.jwLibraryUri,
    this.pendingDoubt,
    this.spiritualGoal,
    this.empathyNote,
  });
}

class DoorstepBriefingHelper {
  static DoorstepBriefingData build({
    required PersonEntry person,
    BibleStudyEntry? linkedStudy,
    VisitEntry? latestVisit,
  }) {
    // 1. Onde parou (Lição e Ponto / Parágrafo)
    String? lessonAndPoint;
    Uri? jwLibraryUri;

    if (linkedStudy != null) {
      if (linkedStudy.currentLesson != null) {
        if (linkedStudy.currentParagraph != null) {
          lessonAndPoint = 'Lição ${linkedStudy.currentLesson.toString().padLeft(2, '0')}, Ponto ${linkedStudy.currentParagraph}';
        } else {
          lessonAndPoint = 'Lição ${linkedStudy.currentLesson.toString().padLeft(2, '0')}';
        }
      } else if (linkedStudy.manualReference != null && linkedStudy.manualReference!.isNotEmpty) {
        lessonAndPoint = linkedStudy.manualReference;
      }

      // Link JW Library
      final resolved = PublicationLinkResolver.resolve(
        publicationId: linkedStudy.publicationId,
        languageCode: linkedStudy.language,
        lesson: linkedStudy.currentLesson,
        paragraph: linkedStudy.currentParagraph,
        manualReference: linkedStudy.manualReference,
      );

      final url = resolved.url ?? resolved.fallbackUrl;
      if (url != null) {
        jwLibraryUri = Uri.tryParse(url);
      }
    }

    // 2. Pendência deixada da última visita
    final pendingDoubt = latestVisit?.expressedQuestion ??
        latestVisit?.nextStep ??
        linkedStudy?.pendingDoubts;

    // 3. Alvo espiritual ativo
    final spiritualGoal = linkedStudy?.learningGoals ?? person.nextActionNote;

    // 4. Toque de empatia (última observação ou necessidade pessoal)
    final empathyNote = latestVisit?.notes ??
        person.generalNotes ??
        person.contactRestrictions;

    return DoorstepBriefingData(
      lessonAndPoint: lessonAndPoint,
      jwLibraryUri: jwLibraryUri,
      pendingDoubt: pendingDoubt,
      spiritualGoal: spiritualGoal,
      empathyNote: empathyNote,
    );
  }
}

// ============================================================================
// Requirement R2: Calculadora de Ritmo Real de Campo
// ============================================================================

class PioneerPaceResult {
  final double goalHours;
  final double completedHours;
  final double remainingHours;
  final int remainingOutings;
  final Duration idealPacePerOuting;
  final bool isGoalReached;
  final String formattedPaceText;

  const PioneerPaceResult({
    required this.goalHours,
    required this.completedHours,
    required this.remainingHours,
    required this.remainingOutings,
    required this.idealPacePerOuting,
    required this.isGoalReached,
    required this.formattedPaceText,
  });
}

class PioneerPaceCalculator {
  static PioneerPaceResult calculate({
    required double goalHours,
    required List<int> designatedWeekdays, // 1=Segunda .. 7=Domingo
    required double completedHours,
    required DateTime currentDate,
  }) {
    final bool isGoalReached = completedHours >= goalHours;
    final double remainingHours = isGoalReached ? 0.0 : math.max(0.0, goalHours - completedHours);

    // Contagem de saídas programadas restantes no mês (do dia atual até o último dia do mês)
    final int lastDayOfMonth = DateTime(currentDate.year, currentDate.month + 1, 0).day;
    int remainingOutings = 0;

    if (designatedWeekdays.isNotEmpty) {
      for (int day = currentDate.day; day <= lastDayOfMonth; day++) {
        final d = DateTime(currentDate.year, currentDate.month, day);
        if (designatedWeekdays.contains(d.weekday)) {
          remainingOutings++;
        }
      }
    }

    Duration idealPacePerOuting = Duration.zero;
    String formattedPaceText;

    if (isGoalReached) {
      formattedPaceText = 'Meta atingida! Parabéns pelo empenho no ministério.';
    } else if (remainingOutings == 0) {
      final totalMin = (remainingHours * 60).round();
      idealPacePerOuting = Duration(minutes: totalMin);
      final hoursPart = totalMin ~/ 60;
      final minPart = totalMin % 60;
      final hoursStr = remainingHours.truncateToDouble() == remainingHours
          ? remainingHours.toStringAsFixed(0)
          : remainingHours.toStringAsFixed(1);
      formattedPaceText = 'Faltam ${hoursStr}h em 0 saídas. Seu ritmo ideal é de ${hoursPart}h${minPart.toString().padLeft(2, '0')}m por saída';
    } else {
      final totalMin = ((remainingHours / remainingOutings) * 60).round();
      idealPacePerOuting = Duration(minutes: totalMin);
      final hoursPart = totalMin ~/ 60;
      final minPart = totalMin % 60;
      final hoursStr = remainingHours.truncateToDouble() == remainingHours
          ? remainingHours.toStringAsFixed(0)
          : remainingHours.toStringAsFixed(1);
      formattedPaceText = 'Faltam ${hoursStr}h em $remainingOutings saídas. Seu ritmo ideal é de ${hoursPart}h${minPart.toString().padLeft(2, '0')}m por saída';
    }

    return PioneerPaceResult(
      goalHours: goalHours,
      completedHours: completedHours,
      remainingHours: remainingHours,
      remainingOutings: remainingOutings,
      idealPacePerOuting: idealPacePerOuting,
      isGoalReached: isGoalReached,
      formattedPaceText: formattedPaceText,
    );
  }
}

// ============================================================================
// Requirement R3: Destaque de Sementes Recentes (Alerta de Esfriamento)
// ============================================================================

class RecentSeedsHelper {
  static const int seedThresholdDays = 7;

  static bool isRecentSeed({
    required PersonEntry person,
    required List<VisitEntry> visits,
    DateTime? nowOverride,
  }) {
    if (person.deletedAt != null) return false;

    final now = nowOverride ?? DateTime.now();
    final diff = now.difference(person.firstContactAt);

    // Se a data de primeiro contato for no futuro ou tiver mais de 7 dias (limite estrito de 7 dias)
    if (diff.isNegative) return false;
    if (diff.inSeconds > seedThresholdDays * 86400) return false;

    // Semente recente: ainda NÃO recebeu a primeira revisita ou estudo bíblico
    // (visitas do tipo 'revisita' ou 'estudo')
    final hasCompletedRevisit = visits.any((v) =>
        v.personId == person.id &&
        v.deletedAt == null &&
        (v.contactType == 'revisita' || v.contactType == 'estudo'));

    return !hasCompletedRevisit;
  }

  static String getElapsedText({
    required DateTime firstContactAt,
    DateTime? nowOverride,
  }) {
    final now = nowOverride ?? DateTime.now();
    final diff = now.difference(firstContactAt);

    if (diff.inDays <= 0) {
      return 'Hoje';
    } else if (diff.inDays == 1) {
      return 'há 1 dia';
    } else {
      return 'há ${diff.inDays} dias';
    }
  }
}

// ============================================================================
// Requirement R4: Botão "Estudante Desmarcou Agora" (Plano B Imediato)
// ============================================================================

class PlanBSuggestion {
  final PersonEntry person;
  final double? distanceKm;
  final String reason;
  final String? pendingStep;

  const PlanBSuggestion({
    required this.person,
    this.distanceKm,
    required this.reason,
    this.pendingStep,
  });
}

class PlanBRecommender {
  static Future<List<PlanBSuggestion>> getSuggestions({
    required PersonEntry cancelledPerson,
    required List<PersonEntry> allPeople,
    required List<VisitEntry> allVisits,
    double? currentLat,
    double? currentLng,
    DateTime? targetDateTime,
  }) async {
    final target = targetDateTime ?? DateTime.now();
    const weekdayNames = ['', 'segunda', 'terça', 'quarta', 'quinta', 'sexta', 'sábado', 'domingo'];
    final currentDayName = weekdayNames[target.weekday];

    // 1. Filtra candidatos válidos (exclui a pessoa cancelada e contatos deletados)
    final candidates = allPeople.where((p) =>
        p.id != cancelledPerson.id &&
        p.deletedAt == null).toList();

    if (candidates.isEmpty) return [];

    final hasUserGps = currentLat != null && currentLng != null;

    // 2. Mapeia para sugestões com cálculo de distância e justificativa
    final suggestions = <PlanBSuggestion>[];

    for (final person in candidates) {
      double? distKm;
      if (hasUserGps && person.latitude != null && person.longitude != null) {
        distKm = GeolocationHelper.calculateHaversineDistanceKm(
          currentLat,
          currentLng,
          person.latitude!,
          person.longitude!,
        );
      }

      // Encontra a última visita ou pendência registrada
      final personVisits = allVisits
          .where((v) => v.personId == person.id && v.deletedAt == null)
          .toList()
        ..sort((a, b) => b.dateTimeField.compareTo(a.dateTimeField));

      final latestVisit = personVisits.isNotEmpty ? personVisits.first : null;
      final pendingStep = latestVisit?.nextStep ??
          latestVisit?.expressedQuestion ??
          person.nextActionNote;

      // Monta texto de motivo amigável
      final reasonParts = <String>[];
      if (distKm != null) {
        final meters = (distKm * 1000).round();
        if (meters < 1000) {
          reasonParts.add('A ${meters}m de distância');
        } else {
          reasonParts.add('A ${distKm.toStringAsFixed(1)}km de distância');
        }
      } else {
        reasonParts.add('Contato flexível sugerido');
      }

      if (person.preferredSchedule != null && person.preferredSchedule!.isNotEmpty) {
        final schedLower = person.preferredSchedule!.toLowerCase();
        if (schedLower.contains(currentDayName)) {
          reasonParts.add('Costuma atender aos ${currentDayName}s');
        } else {
          reasonParts.add(person.preferredSchedule!);
        }
      } else if (person.status == 'revisita') {
        reasonParts.add('Aguardando revisita');
      }

      suggestions.add(PlanBSuggestion(
        person: person,
        distanceKm: distKm,
        reason: reasonParts.join(' • '),
        pendingStep: pendingStep,
      ));
    }

    // 3. Ordenação inteligente:
    // Se temos GPS, prioriza os mais próximos geograficamente.
    // Se GPS for null (fallback), ordena por prioridade de revisita / urgência de próximo passo.
    suggestions.sort((a, b) {
      if (hasUserGps) {
        if (a.distanceKm != null && b.distanceKm != null) {
          return a.distanceKm!.compareTo(b.distanceKm!);
        } else if (a.distanceKm != null) {
          return -1;
        } else if (b.distanceKm != null) {
          return 1;
        }
      }

      // Fallback: contatos com pendências ou revisitas ativas primeiro
      final aHasPending = a.pendingStep != null;
      final bHasPending = b.pendingStep != null;
      if (aHasPending != bHasPending) {
        return aHasPending ? -1 : 1;
      }
      return a.person.name.compareTo(b.person.name);
    });

    // Retorna as 2 a 3 melhores sugestões
    return suggestions.take(3).toList();
  }
}

// ============================================================================
// Requirement R5: Cronômetro Auto-Corretivo
// ============================================================================

class AutoCorrectiveTimerState {
  final bool shouldShowWarning;
  final Duration elapsedDuration;
  final String warningReason; // "long_running" (>4h) ou "reopened_inactive"
  final Duration suggestedAdjustment;

  const AutoCorrectiveTimerState({
    required this.shouldShowWarning,
    required this.elapsedDuration,
    required this.warningReason,
    required this.suggestedAdjustment,
  });
}

class AutoCorrectiveTimerLogic {
  static const Duration longRunningThreshold = Duration(hours: 4);
  static const Duration inactiveGapThreshold = Duration(hours: 2);

  static AutoCorrectiveTimerState evaluate({
    required bool isRunning,
    required DateTime startedAt,
    required Duration accumulatedDuration,
    DateTime? lastHeartbeat,
    DateTime? nowOverride,
  }) {
    final now = nowOverride ?? DateTime.now();

    if (!isRunning) {
      return AutoCorrectiveTimerState(
        shouldShowWarning: false,
        elapsedDuration: accumulatedDuration,
        warningReason: '',
        suggestedAdjustment: accumulatedDuration,
      );
    }

    final diffSinceStart = now.difference(startedAt);
    final totalElapsed = accumulatedDuration + (diffSinceStart.isNegative ? Duration.zero : diffSinceStart);

    // 1. Detecção de reabertura inativa (reopened_inactive)
    if (lastHeartbeat != null) {
      final inactivity = now.difference(lastHeartbeat);
      if (inactivity > inactiveGapThreshold) {
        final activePortion = accumulatedDuration + lastHeartbeat.difference(startedAt);
        return AutoCorrectiveTimerState(
          shouldShowWarning: true,
          elapsedDuration: totalElapsed,
          warningReason: 'reopened_inactive',
          suggestedAdjustment: activePortion > Duration.zero ? activePortion : const Duration(hours: 2),
        );
      }
    }

    // 2. Detecção de longa duração contínua (> 4 horas)
    if (totalElapsed > longRunningThreshold) {
      Duration suggested = const Duration(hours: 2);
      if (lastHeartbeat != null) {
        final activePortion = accumulatedDuration + lastHeartbeat.difference(startedAt);
        if (activePortion > Duration.zero && activePortion <= longRunningThreshold) {
          suggested = activePortion;
        }
      }

      return AutoCorrectiveTimerState(
        shouldShowWarning: true,
        elapsedDuration: totalElapsed,
        warningReason: 'long_running',
        suggestedAdjustment: suggested,
      );
    }

    return AutoCorrectiveTimerState(
      shouldShowWarning: false,
      elapsedDuration: totalElapsed,
      warningReason: '',
      suggestedAdjustment: totalElapsed,
    );
  }
}
