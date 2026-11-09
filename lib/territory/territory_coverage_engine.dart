import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../database/app_database.dart';

/// Classificação de camadas e status visual para alfinetes do mapa territorial
enum TerritoryPinLayer {
  activeStudy('Estudo Bíblico Ativo', Color(0xFF7C3AED), Icons.school),
  needsRevisit('Revisita Agendada / Pendente', Color(0xFFD97706), Icons.repeat),
  recentlyVisited('Visitado Recentemente (<30 dias)', Color(0xFF16A34A), Icons.check_circle),
  interested('Pessoa Interessada', Color(0xFF06B6D4), Icons.eco),
  notAtHome('Ausente / Não Atendeu', Color(0xFFEA580C), Icons.door_front_door_outlined),
  forgottenZone('Zona Esquecida (>90 dias)', Color(0xFFDC2626), Icons.warning_amber_rounded),
  landmark('Ponto de Referência / Marco', Color(0xFF1E3A8A), Icons.place);

  final String label;
  final Color color;
  final IconData icon;

  const TerritoryPinLayer(this.label, this.color, this.icon);
}

/// Resultado do cálculo do Índice de Cobertura (IC) de um setor ou território
class TerritoryCoverageReport {
  final int totalAddresses;
  final int workedRecentlyCount; // < 30 dias
  final int workedStandardCount; // 30 a 90 dias
  final int forgottenCount; // > 90 dias
  final int neverVisitedCount;
  final double coverageIndexPercent; // 0.0 a 100.0%
  final List<PersonEntry> forgottenAddresses;

  // 1. Cobertura de Residências (endereços físicos únicos trabalhados vs total conhecido)
  final int totalUniqueAddresses;
  final int workedUniqueAddresses;
  final double addressCoveragePercent;

  // 2. Cobertura de Contatos Cadastrados (pessoas registradas que receberam visita)
  final int totalPeople;
  final int visitedPeopleCount;
  final double peopleCoveragePercent;

  // 3. Cobertura de Conversas Efetivas (excluindo tentativas sem contato)
  final int effectiveConversationCount;
  final int attemptWithoutContactCount;
  final int peopleWithEffectiveConversation;
  final double conversationCoveragePercent;

  const TerritoryCoverageReport({
    required this.totalAddresses,
    required this.workedRecentlyCount,
    required this.workedStandardCount,
    required this.forgottenCount,
    required this.neverVisitedCount,
    required this.coverageIndexPercent,
    required this.forgottenAddresses,
    this.totalUniqueAddresses = 0,
    this.workedUniqueAddresses = 0,
    this.addressCoveragePercent = 0.0,
    this.totalPeople = 0,
    this.visitedPeopleCount = 0,
    this.peopleCoveragePercent = 0.0,
    this.effectiveConversationCount = 0,
    this.attemptWithoutContactCount = 0,
    this.peopleWithEffectiveConversation = 0,
    this.conversationCoveragePercent = 0.0,
  });

  String get ratingLabel {
    if (coverageIndexPercent >= 80.0) return 'Excelente Cobertura';
    if (coverageIndexPercent >= 50.0) return 'Boa Cobertura';
    if (coverageIndexPercent >= 30.0) return 'Cobertura Regular';
    return 'Atenção Necessária (Território Parado)';
  }

  Color get ratingColor {
    if (coverageIndexPercent >= 80.0) return const Color(0xFF16A34A);
    if (coverageIndexPercent >= 50.0) return const Color(0xFF2563EB);
    if (coverageIndexPercent >= 30.0) return const Color(0xFFD97706);
    return const Color(0xFFDC2626);
  }
}

/// Registro de potencial duplicidade encontrada no território
class DuplicateAddressMatch {
  final PersonEntry personA;
  final PersonEntry personB;
  final double distanceMeters;
  final double nameSimilarity;
  final double addressSimilarity;

  const DuplicateAddressMatch({
    required this.personA,
    required this.personB,
    required this.distanceMeters,
    required this.nameSimilarity,
    required this.addressSimilarity,
  });

  bool get isHighConfidence =>
      distanceMeters <= 25.0 || (addressSimilarity >= 0.85 && distanceMeters <= 50.0);
}

/// Motor de inteligência territorial: Cobertura, Zonas Esquecidas e Detecção de Duplicidades
class TerritoryCoverageEngine {
  TerritoryCoverageEngine._();

  /// Verifica se uma visita foi apenas uma tentativa sem contato efetivo
  static bool isAttemptWithoutContact(VisitEntry v) {
    final type = v.contactType.toLowerCase();
    final res = v.result.toLowerCase();
    return type == 'tentativa_sem_contato' ||
        type.contains('tentativa') ||
        type.contains('ausente') ||
        type.contains('nao_atendido') ||
        res.contains('não estava') ||
        res.contains('nao estava') ||
        res.contains('ausente') ||
        res.contains('não atendeu') ||
        res.contains('nao atendeu');
  }

  /// Normaliza chave de residência para agrupar pessoas no mesmo endereço ou coordenadas
  static String getResidenceKey(PersonEntry p) {
    final addr = p.address?.trim().toLowerCase() ?? '';
    if (addr.isNotEmpty) {
      return 'addr_$addr';
    }
    if (p.latitude != null && p.longitude != null) {
      return 'geo_${p.latitude!.toStringAsFixed(4)}_${p.longitude!.toStringAsFixed(4)}';
    }
    return 'person_${p.id}';
  }

  /// Calcula a distância Haversine em metros entre duas coordenadas geográficas
  static double haversineDistanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadiusMeters = 6371000.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  static double _deg2rad(double deg) => deg * (math.pi / 180.0);

  /// Calcula o Índice de Cobertura (IC) separando em 3 indicadores objetivos:
  /// 1. Cobertura de Residências: endereços físicos únicos trabalhados vs total conhecido
  /// 2. Cobertura de Contatos Cadastrados: pessoas registradas que receberam visita nos últimos 90 dias
  /// 3. Cobertura de Conversas Efetivas: pessoas com contato real no período (excluindo ausentes)
  static TerritoryCoverageReport calculateCoverage({
    required List<PersonEntry> people,
    required List<VisitEntry> visits,
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();
    final validPeople = people.where((p) => p.deletedAt == null).toList();

    if (validPeople.isEmpty) {
      return const TerritoryCoverageReport(
        totalAddresses: 0,
        workedRecentlyCount: 0,
        workedStandardCount: 0,
        forgottenCount: 0,
        neverVisitedCount: 0,
        coverageIndexPercent: 0.0,
        forgottenAddresses: [],
        totalUniqueAddresses: 0,
        workedUniqueAddresses: 0,
        addressCoveragePercent: 0.0,
        totalPeople: 0,
        visitedPeopleCount: 0,
        peopleCoveragePercent: 0.0,
        effectiveConversationCount: 0,
        attemptWithoutContactCount: 0,
        peopleWithEffectiveConversation: 0,
        conversationCoveragePercent: 0.0,
      );
    }

    // 1. Mapeia última visita por pessoa e identifica se houve conversa efetiva
    final Map<String, DateTime> lastVisitMap = {};
    final Map<String, DateTime> lastEffectiveConversationMap = {};
    int totalEffectiveCount = 0;
    int totalAttemptCount = 0;

    for (final v in visits) {
      if (v.deletedAt != null) continue;
      final existing = lastVisitMap[v.personId];
      if (existing == null || v.dateTimeField.isAfter(existing)) {
        lastVisitMap[v.personId] = v.dateTimeField;
      }

      final diffDays = now.difference(v.dateTimeField).inDays;
      final isRecentPeriod = diffDays >= 0 && diffDays <= 90;

      if (isAttemptWithoutContact(v)) {
        if (isRecentPeriod) totalAttemptCount++;
      } else {
        if (isRecentPeriod) totalEffectiveCount++;
        final effExisting = lastEffectiveConversationMap[v.personId];
        if (effExisting == null || v.dateTimeField.isAfter(effExisting)) {
          lastEffectiveConversationMap[v.personId] = v.dateTimeField;
        }
      }
    }

    int workedRecently = 0; // < 30 dias
    int workedStandard = 0; // 30 a 90 dias
    int forgotten = 0; // > 90 dias
    int neverVisited = 0;
    final List<PersonEntry> forgottenList = [];

    // Mapeamento de residências físicas únicas
    final Set<String> allResidenceKeys = {};
    final Set<String> workedResidenceKeys = {};
    final Set<String> peopleWithEffectiveInPeriod = {};

    for (final p in validPeople) {
      final resKey = getResidenceKey(p);
      allResidenceKeys.add(resKey);

      final last = lastVisitMap[p.id];
      if (last == null) {
        neverVisited++;
        forgotten++;
        forgottenList.add(p);
      } else {
        final diffDays = now.difference(last).inDays;
        if (diffDays <= 30) {
          workedRecently++;
          workedResidenceKeys.add(resKey);
        } else if (diffDays <= 90) {
          workedStandard++;
          workedResidenceKeys.add(resKey);
        } else {
          forgotten++;
          forgottenList.add(p);
        }
      }

      final lastEff = lastEffectiveConversationMap[p.id];
      if (lastEff != null && now.difference(lastEff).inDays <= 90) {
        peopleWithEffectiveInPeriod.add(p.id);
      }
    }

    // 1. Cobertura de Residências (únicas)
    final totalUniqueAddresses = allResidenceKeys.length;
    final workedUniqueAddresses = workedResidenceKeys.length;
    final double addressCoveragePercent = totalUniqueAddresses > 0
        ? double.parse(((workedUniqueAddresses / totalUniqueAddresses) * 100.0).toStringAsFixed(1))
        : 0.0;

    // 2. Cobertura de Contatos Cadastrados
    final totalPeople = validPeople.length;
    final visitedPeopleCount = workedRecently + workedStandard;
    final double peopleCoveragePercent = totalPeople > 0
        ? double.parse(((visitedPeopleCount / totalPeople) * 100.0).toStringAsFixed(1))
        : 0.0;

    // 3. Cobertura de Conversas Efetivas
    final peopleWithEff = peopleWithEffectiveInPeriod.length;
    final double conversationCoveragePercent = totalPeople > 0
        ? double.parse(((peopleWithEff / totalPeople) * 100.0).toStringAsFixed(1))
        : 0.0;

    // IC canônico ponderado
    final double ic = ((workedRecently + workedStandard) / validPeople.length) * 100.0;

    return TerritoryCoverageReport(
      totalAddresses: validPeople.length,
      workedRecentlyCount: workedRecently,
      workedStandardCount: workedStandard,
      forgottenCount: forgotten,
      neverVisitedCount: neverVisited,
      coverageIndexPercent: double.parse(ic.toStringAsFixed(1)),
      forgottenAddresses: forgottenList,
      totalUniqueAddresses: totalUniqueAddresses,
      workedUniqueAddresses: workedUniqueAddresses,
      addressCoveragePercent: addressCoveragePercent,
      totalPeople: totalPeople,
      visitedPeopleCount: visitedPeopleCount,
      peopleCoveragePercent: peopleCoveragePercent,
      effectiveConversationCount: totalEffectiveCount,
      attemptWithoutContactCount: totalAttemptCount,
      peopleWithEffectiveConversation: peopleWithEff,
      conversationCoveragePercent: conversationCoveragePercent,
    );
  }

  /// Detecta duplicidades no território por proximidade física (<25m) e similaridade textual
  static List<DuplicateAddressMatch> findDuplicates(List<PersonEntry> people) {
    final results = <DuplicateAddressMatch>[];
    final active = people.where((p) => p.deletedAt == null).toList();

    for (int i = 0; i < active.length; i++) {
      for (int j = i + 1; j < active.length; j++) {
        final p1 = active[i];
        final p2 = active[j];

        // 1. Verificação por proximidade geográfica GPS
        double distance = double.infinity;
        if (p1.latitude != null &&
            p1.longitude != null &&
            p2.latitude != null &&
            p2.longitude != null) {
          distance = haversineDistanceMeters(
            p1.latitude!,
            p1.longitude!,
            p2.latitude!,
            p2.longitude!,
          );
        }

        // 2. Similaridade de endereço e nome
        final nameSim = stringSimilarity(p1.name, p2.name);
        final addr1 = p1.address ?? '';
        final addr2 = p2.address ?? '';
        final addrSim = (addr1.isNotEmpty && addr2.isNotEmpty)
            ? stringSimilarity(addr1, addr2)
            : 0.0;

        // Critérios de alerta de duplicidade:
        // A) Raio de 25 metros COM similaridade de nome >= 0.60 ou endereço equivalente
        // B) Mesmo endereço textual (addrSim >= 0.85) e raio de até 50 metros
        // C) Nomes muito semelhantes (nameSim >= 0.85) e proximidade < 100 metros
        final isCloseDuplicate = (distance <= 25.0 && (nameSim >= 0.60 || (addrSim >= 0.80 && addr1.isNotEmpty)));
        final isAddressDuplicate = (distance <= 50.0 && addrSim >= 0.85 && addr1.isNotEmpty);
        final isNameDuplicate = (distance <= 100.0 && nameSim >= 0.85 && addrSim >= 0.60 && addr1.isNotEmpty);

        if (isCloseDuplicate || isAddressDuplicate || isNameDuplicate) {
          results.add(
            DuplicateAddressMatch(
              personA: p1,
              personB: p2,
              distanceMeters: double.parse(distance.toStringAsFixed(1)),
              nameSimilarity: double.parse(nameSim.toStringAsFixed(2)),
              addressSimilarity: double.parse(addrSim.toStringAsFixed(2)),
            ),
          );
        }
      }
    }

    return results;
  }

  /// Classifica o alfinete de uma pessoa para estilização cromática no mapa
  static TerritoryPinLayer classifyPin(
    PersonEntry person, {
    bool hasActiveStudy = false,
    DateTime? lastVisitDate,
    DateTime? nextAppointmentDate,
    DateTime? referenceNow,
  }) {
    final now = referenceNow ?? DateTime.now();

    if (hasActiveStudy) {
      return TerritoryPinLayer.activeStudy;
    }

    final status = person.status.toLowerCase();
    if (status == 'estudo') {
      return TerritoryPinLayer.activeStudy;
    }

    if (status == 'revisita' || nextAppointmentDate != null) {
      return TerritoryPinLayer.needsRevisit;
    }

    if (status == 'ausente' || status == 'nao_atendeu') {
      return TerritoryPinLayer.notAtHome;
    }

    if (lastVisitDate != null) {
      final days = now.difference(lastVisitDate).inDays;
      if (days <= 30) {
        return TerritoryPinLayer.recentlyVisited;
      }
      if (days > 90) {
        return TerritoryPinLayer.forgottenZone;
      }
    }

    return TerritoryPinLayer.interested;
  }

  /// Calcula a similaridade entre duas strings usando coeficiente de Sorensen-Dice / Bigramas
  static double stringSimilarity(String s1, String s2) {
    final str1 = _normalizeString(s1);
    final str2 = _normalizeString(s2);

    if (str1 == str2) return 1.0;
    if (str1.length < 2 || str2.length < 2) return 0.0;

    final pairs1 = <String, int>{};
    for (int i = 0; i < str1.length - 1; i++) {
      final pair = str1.substring(i, i + 2);
      pairs1[pair] = (pairs1[pair] ?? 0) + 1;
    }

    int intersection = 0;
    for (int i = 0; i < str2.length - 1; i++) {
      final pair = str2.substring(i, i + 2);
      final count = pairs1[pair] ?? 0;
      if (count > 0) {
        intersection++;
        pairs1[pair] = count - 1;
      }
    }

    return (2.0 * intersection) / (str1.length - 1 + str2.length - 1);
  }

  static String _normalizeString(String s) {
    return s
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[áàãâä]'), 'a')
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[íìîï]'), 'i')
        .replaceAll(RegExp(r'[óòõôö]'), 'o')
        .replaceAll(RegExp(r'[úùûü]'), 'u')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }
}
