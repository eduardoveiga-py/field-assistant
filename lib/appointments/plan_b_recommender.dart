import '../database/app_database.dart';
import '../territory/geolocation_helper.dart';
import '../contacts/recent_seeds_helper.dart';

/// Sugestão de contato alternativo para o Plano B
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

  String get distanceFormatted {
    if (distanceKm == null) return 'Localização a confirmar';
    if (distanceKm! < 1.0) {
      final meters = (distanceKm! * 1000).round();
      return '$meters m';
    }
    return '${distanceKm!.toStringAsFixed(1)} km';
  }
}

/// Motor de recomendação geográfico e de disponibilidade para o Plano B (R4)
class PlanBRecommender {
  static const Map<int, String> _weekdayNames = {
    1: 'segunda',
    2: 'terça',
    3: 'quarta',
    4: 'quinta',
    5: 'sexta',
    6: 'sábado',
    7: 'domingo',
  };

  /// Retorna as 2 ou 3 melhores alternativas para preencher o horário desmarcado
  static List<PlanBSuggestion> getSuggestions({
    required PersonEntry cancelledPerson,
    required List<PersonEntry> allPeople,
    required List<VisitEntry> allVisits,
    double? currentLat,
    double? currentLng,
    DateTime? targetDateTime,
  }) {
    final target = targetDateTime ?? DateTime.now();
    final targetWeekdayName = _weekdayNames[target.weekday] ?? '';

    // Filtra pessoas válidas (excluindo a própria pessoa cancelada, deletadas e arquivadas)
    final candidates = allPeople.where((p) {
      if (p.id == cancelledPerson.id) return false;
      if (p.deletedAt != null) return false;
      final st = p.status.toLowerCase();
      if (st == 'arquivado' || st == 'encerrado' || st == 'revisita_passada') {
        return false;
      }
      return true;
    }).toList();

    if (candidates.isEmpty) return [];

    final hasGps = currentLat != null && currentLng != null;
    final List<({PersonEntry person, double? dist, double score, String reason, String? pending})> scored = [];

    for (final person in candidates) {
      double score = 0.0;
      double? dist;
      final reasons = <String>[];

      // 1. Proximidade Geográfica
      if (hasGps && person.latitude != null && person.longitude != null) {
        dist = GeolocationHelper.calculateHaversineDistanceKm(
          currentLat,
          currentLng,
          person.latitude!,
          person.longitude!,
        );

        if (dist <= 0.5) {
          score += 100.0;
          final meters = (dist * 1000).round();
          reasons.add('A $meters m de você');
        } else if (dist <= 1.5) {
          score += 70.0;
          reasons.add('A ${dist.toStringAsFixed(1)} km');
        } else if (dist <= 3.0) {
          score += 40.0;
          reasons.add('A ${dist.toStringAsFixed(1)} km');
        } else {
          score += 10.0;
        }
      }

      // 2. Disponibilidade por Dia Habitual
      final schedule = (person.preferredSchedule ?? '').toLowerCase();
      if (schedule.contains(targetWeekdayName)) {
        score += 50.0;
        reasons.add('Costuma atender aos ${targetWeekdayName}s');
      }

      // 3. Semente Recente (urgência de retorno nos primeiros 7 dias)
      final isSeed = RecentSeedsHelper.isRecentSeed(person: person, visits: allVisits, nowOverride: target);
      if (isSeed) {
        score += 45.0;
        reasons.add('Semente Recente aguardando 1ª revisita');
      }

      // 4. Última pendência ou próximo passo registrado
      final personVisits = allVisits
          .where((v) => v.personId == person.id && v.deletedAt == null)
          .toList()
        ..sort((a, b) => b.dateTimeField.compareTo(a.dateTimeField));

      final latestVisit = personVisits.firstOrNull;
      final pending = latestVisit?.nextStep ??
          latestVisit?.expressedQuestion ??
          person.nextActionNote ??
          latestVisit?.topicsDiscussed;

      if (pending != null && pending.isNotEmpty) {
        score += 15.0;
      }

      // Fallback sem GPS: valoriza dia habitual e sementes recentes
      if (!hasGps) {
        if (person.address != null && person.address!.isNotEmpty) {
          score += 20.0;
        }
        if (reasons.isEmpty) {
          reasons.add('Disponível no território');
        }
      }

      scored.add((
        person: person,
        dist: dist,
        score: score,
        reason: reasons.join(' • '),
        pending: pending,
      ));
    }

    // Ordena pelo maior score e desempata pela menor distância
    scored.sort((a, b) {
      final comp = b.score.compareTo(a.score);
      if (comp != 0) return comp;
      if (a.dist != null && b.dist != null) {
        return a.dist!.compareTo(b.dist!);
      }
      return 0;
    });

    // Retorna as top 3 alternativas
    return scored.take(3).map((s) {
      return PlanBSuggestion(
        person: s.person,
        distanceKm: s.dist,
        reason: s.reason,
        pendingStep: s.pending,
      );
    }).toList();
  }
}
