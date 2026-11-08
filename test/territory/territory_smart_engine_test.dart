import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';

import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/territory/territory_coverage_engine.dart';
import 'package:ministerio_pessoal/territory/territory_data_port_service.dart';
import 'package:ministerio_pessoal/appointments/doorstep_proximity_engine.dart';
import 'package:ministerio_pessoal/ticuna/models/multilingual_models.dart';
import 'package:ministerio_pessoal/ticuna/services/multilingual_assistant_service.dart';

void main() {
  final baseDate = DateTime(2026, 11, 8, 10, 0);

  group('TerritoryCoverageEngine & Duplicates Detection', () {
    test('1. calculateCoverage calcula Índice de Cobertura e Zonas Esquecidas', () {
      final p1 = PersonEntry(
        id: 'p1', name: 'Ana Souza', firstContactAt: baseDate,
        status: 'interessado', tags: '[]', createdAt: baseDate,
        updatedAt: baseDate, revision: 1, latitude: -3.421, longitude: -65.850,
      );
      final p2 = PersonEntry(
        id: 'p2', name: 'Bruno Lima', firstContactAt: baseDate,
        status: 'revisita', tags: '[]', createdAt: baseDate,
        updatedAt: baseDate, revision: 1, latitude: -3.422, longitude: -65.851,
      );
      final p3 = PersonEntry(
        id: 'p3', name: 'Carla Dias', firstContactAt: baseDate,
        status: 'estudo', tags: '[]', createdAt: baseDate,
        updatedAt: baseDate, revision: 1, latitude: -3.423, longitude: -65.852,
      );
      final p4 = PersonEntry(
        id: 'p4', name: 'Daniel Silva', firstContactAt: baseDate,
        status: 'interessado', tags: '[]', createdAt: baseDate,
        updatedAt: baseDate, revision: 1, latitude: -3.424, longitude: -65.853,
      );

      final visits = [
        // p1 visitado há 10 dias (recente <30 dias)
        VisitEntry(
          id: 'v1', personId: 'p1', dateTimeField: baseDate.subtract(const Duration(days: 10)),
          contactType: 'presencial', result: 'conversa', createdAt: baseDate, updatedAt: baseDate, revision: 1,
        ),
        // p2 visitado há 40 dias (padrão 30 a 90 dias)
        VisitEntry(
          id: 'v2', personId: 'p2', dateTimeField: baseDate.subtract(const Duration(days: 40)),
          contactType: 'presencial', result: 'revisita', createdAt: baseDate, updatedAt: baseDate, revision: 1,
        ),
        // p3 visitado há 120 dias (zona esquecida >90 dias)
        VisitEntry(
          id: 'v3', personId: 'p3', dateTimeField: baseDate.subtract(const Duration(days: 120)),
          contactType: 'presencial', result: 'estudo', createdAt: baseDate, updatedAt: baseDate, revision: 1,
        ),
        // p4 nunca foi visitado (zona esquecida)
      ];

      final report = TerritoryCoverageEngine.calculateCoverage(
        people: [p1, p2, p3, p4],
        visits: visits,
        referenceDate: baseDate,
      );

      expect(report.totalAddresses, equals(4));
      expect(report.workedRecentlyCount, equals(1));
      expect(report.workedStandardCount, equals(1));
      expect(report.coverageIndexPercent, equals(50.0));
      expect(report.forgottenAddresses.length, equals(2));
      expect(report.forgottenAddresses.map((p) => p.id), containsAll(['p3', 'p4']));
    });

    test('2. calculateCoverage lida graciosamente com lista vazia de pessoas', () {
      final report = TerritoryCoverageEngine.calculateCoverage(
        people: [],
        visits: [],
        referenceDate: baseDate,
      );

      expect(report.totalAddresses, equals(0));
      expect(report.coverageIndexPercent, equals(0.0));
      expect(report.forgottenAddresses, isEmpty);
    });

    test('3. haversineDistanceMeters calcula com fidelidade geodésica', () {
      // Mesma coordenada -> 0 metros
      expect(
        TerritoryCoverageEngine.haversineDistanceMeters(-3.421, -65.850, -3.421, -65.850),
        equals(0.0),
      );

      // Deslocamento pequeno de latitude (~0.0001 graus ~= 11.1m)
      final dist = TerritoryCoverageEngine.haversineDistanceMeters(
        -3.421000, -65.850000,
        -3.421100, -65.850000,
      );
      expect(dist, greaterThan(10.0));
      expect(dist, lessThan(12.5));
    });

    test('4. findDuplicates detecta contatos próximos (<25m) com nomes similares', () {
      final pA = PersonEntry(
        id: 'pa', name: 'Maria Souza', firstContactAt: baseDate,
        status: 'interessado', tags: '[]', createdAt: baseDate,
        updatedAt: baseDate, revision: 1, latitude: -3.42100, longitude: -65.85000,
      );
      final pB = PersonEntry(
        id: 'pb', name: 'Maria Sousa', firstContactAt: baseDate,
        status: 'revisita', tags: '[]', createdAt: baseDate,
        updatedAt: baseDate, revision: 1, latitude: -3.42108, longitude: -65.85005, // ~10m
      );
      final pC = PersonEntry(
        id: 'pc', name: 'Carlos Ferreira', firstContactAt: baseDate,
        status: 'interessado', tags: '[]', createdAt: baseDate,
        updatedAt: baseDate, revision: 1, latitude: -3.42100, longitude: -65.85000, // mesmo local, nome diferente
      );
      final pD = PersonEntry(
        id: 'pd', name: 'Maria Souza', firstContactAt: baseDate,
        status: 'interessado', tags: '[]', createdAt: baseDate,
        updatedAt: baseDate, revision: 1, latitude: -3.45000, longitude: -65.85000, // longe (>3km)
      );

      final duplicates = TerritoryCoverageEngine.findDuplicates([pA, pB, pC, pD]);

      expect(duplicates.length, equals(1));
      final match = duplicates.first;
      expect(match.personA.id, equals('pa'));
      expect(match.personB.id, equals('pb'));
      expect(match.distanceMeters, lessThan(25.0));
      expect(match.nameSimilarity, greaterThan(0.7));
    });
  });

  group('TerritoryDataPortService (KML, GeoJSON, CSV)', () {
    final peopleToExport = [
      PersonEntry(
        id: 'p1', name: 'Pedro Santos', phone: '97991234567',
        address: 'Rua das Flores, 123', firstContactAt: baseDate,
        status: 'revisita', tags: '["família"]', createdAt: baseDate,
        updatedAt: baseDate, revision: 1, latitude: -3.4215, longitude: -65.8520,
        generalNotes: 'Gosta de conversar aos domingos',
      ),
      PersonEntry(
        id: 'p2', name: 'Beatriz Costa', phone: null,
        address: 'Av. Brasil, 456', firstContactAt: baseDate,
        status: 'estudo', tags: '[]', createdAt: baseDate,
        updatedAt: baseDate, revision: 1, latitude: -3.4250, longitude: -65.8580,
      ),
    ];

    test('1. KML roundtrip de exportação e importação', () {
      final kmlString = TerritoryDataPortService.exportToKml(
        people: peopleToExport,
        territoryName: 'Setor 01',
      );

      expect(kmlString, contains('<?xml version="1.0" encoding="UTF-8"?>'));
      expect(kmlString, contains('<Document>'));
      expect(kmlString, contains('<name>Setor 01</name>'));
      expect(kmlString, contains('<Placemark>'));
      expect(kmlString, contains('Pedro Santos'));
      expect(kmlString, contains('-65.852,-3.4215'));

      final imported = TerritoryDataPortService.importFromKml(kmlString);
      expect(imported.length, equals(2));
      expect(imported.first.name, equals('Pedro Santos'));
      expect(imported.first.latitude, closeTo(-3.4215, 0.0001));
      expect(imported.first.longitude, closeTo(-65.8520, 0.0001));
      expect(imported.first.phone, equals('97991234567'));
    });

    test('2. GeoJSON roundtrip de exportação e importação (RFC 7946)', () {
      final geoJsonString = TerritoryDataPortService.exportToGeoJson(
        people: peopleToExport,
        territoryName: 'Setor 01 GeoJSON',
      );

      final dynamic decoded = jsonDecode(geoJsonString);
      expect(decoded['type'], equals('FeatureCollection'));
      expect(decoded['features'], hasLength(2));

      final imported = TerritoryDataPortService.importFromGeoJson(geoJsonString);
      expect(imported.length, equals(2));
      expect(imported.first.name, equals('Pedro Santos'));
      expect(imported.first.phone, equals('97991234567'));
      expect(imported.first.address, equals('Rua das Flores, 123'));
      expect(imported.first.latitude, closeTo(-3.4215, 0.0001));
      expect(imported.first.longitude, closeTo(-65.8520, 0.0001));
    });

    test('3. CSV roundtrip de exportação e importação', () {
      final csvString = TerritoryDataPortService.exportToCsv(peopleToExport);

      expect(csvString, contains('Nome,Telefone,Endereço'));
      expect(csvString, contains('Pedro Santos'));

      final imported = TerritoryDataPortService.importFromCsv(csvString);
      expect(imported.length, equals(2));
      expect(imported.first.name, equals('Pedro Santos'));
      expect(imported.first.phone, equals('97991234567'));
      expect(imported.first.address, equals('Rua das Flores, 123'));
      expect(imported.first.latitude, closeTo(-3.4215, 0.0001));
    });
  });

  group('DoorstepProximityEngine Scheduling Suggestions', () {
    test('1. suggestSlots recomenda horários sem conflito', () {
      final target = PersonEntry(
        id: 'target-1', name: 'Gabriel Torres', firstContactAt: baseDate,
        status: 'revisita', tags: '[]', createdAt: baseDate,
        updatedAt: baseDate, revision: 1, latitude: -3.4215, longitude: -65.8520,
        preferredSchedule: 'Sábado 10:00',
      );

      final neighbor = PersonEntry(
        id: 'neighbor-1', name: 'Laura Rocha', firstContactAt: baseDate,
        status: 'estudo', tags: '[]', createdAt: baseDate,
        updatedAt: baseDate, revision: 1, latitude: -3.4216, longitude: -65.8521,
      );

      final nextSaturday = DateTime(2026, 11, 14, 10, 0);
      final existingAppt = AppointmentEntry(
        id: 'appt-1', personId: 'neighbor-1', title: 'Estudo com Laura',
        startTime: nextSaturday, endTime: nextSaturday.add(const Duration(minutes: 60)),
        durationMinutes: 60, status: 'agendado', isProvisional: false,
        createdAt: baseDate, updatedAt: baseDate, revision: 0,
      );

      final recommendations = DoorstepProximityEngine.suggestSlots(
        targetPerson: target,
        allPeople: [target, neighbor],
        existingAppointments: [existingAppt],
        externalEvents: [],
        referenceNow: baseDate,
      );

      expect(recommendations, isNotEmpty);
      expect(recommendations.first.title, contains('Gabriel Torres'));
      expect(recommendations.first.hasConflict, isFalse);
    });
  });

  group('MultilingualAssistantService & SM-2 Spaced Repetition', () {
    test('1. calculateSm2 calcula intervalos e fator de facilidade', () {
      // 1ª revisão com qualidade máxima (5)
      final step1 = MultilingualAssistantService.calculateSm2(
        quality: 5,
        repetitions: 0,
        previousIntervalDays: 1,
        previousEasinessFactor: 2.5,
      );
      expect(step1.newRepetitions, equals(1));
      expect(step1.nextIntervalDays, equals(1));
      expect(step1.newEasinessFactor, greaterThan(2.5));

      // 2ª revisão com qualidade 4
      final step2 = MultilingualAssistantService.calculateSm2(
        quality: 4,
        repetitions: step1.newRepetitions,
        previousIntervalDays: step1.nextIntervalDays,
        previousEasinessFactor: step1.newEasinessFactor,
      );
      expect(step2.newRepetitions, equals(2));
      expect(step2.nextIntervalDays, equals(6));

      // 3ª revisão com falha (qualidade 1)
      final stepFail = MultilingualAssistantService.calculateSm2(
        quality: 1,
        repetitions: step2.newRepetitions,
        previousIntervalDays: step2.nextIntervalDays,
        previousEasinessFactor: step2.newEasinessFactor,
      );
      expect(stepFail.newRepetitions, equals(0));
      expect(stepFail.nextIntervalDays, equals(1));

      // Fator de facilidade não cai abaixo do mínimo 1.3
      final lowEase = MultilingualAssistantService.calculateSm2(
        quality: 0,
        repetitions: 5,
        previousIntervalDays: 30,
        previousEasinessFactor: 1.3,
      );
      expect(lowEase.newEasinessFactor, equals(1.3));
    });

    test('2. Catálogo de Frases Situacionais cobre os 6 momentos ministeriais', () {
      final phrases = MinistryPhrasesCatalog.phrases;
      expect(phrases, isNotEmpty);

      final moments = phrases.map((p) => p.moment).toSet();
      expect(moments, containsAll(MinistryMoment.values));

      // Verifica presença de tradução em Ticuna como flagship
      for (final p in phrases) {
        expect(p.ticuna, isNotEmpty);
        expect(p.portuguese, isNotEmpty);
        expect(p.spanish, isNotEmpty);
        expect(p.phonetics, isNotEmpty);
      }
    });

    test('3. LanguageRegistry possui metadados corretos', () {
      expect(LanguageRegistry.ticuna.code, equals('tca'));
      expect(LanguageRegistry.ticuna.isIndigenousFlagship, isTrue);
      expect(LanguageRegistry.allSupportedLanguages.length, greaterThanOrEqualTo(5));
      expect(LanguageRegistry.findByCode('tca')?.name, equals('Ticuna'));
      expect(LanguageRegistry.findByCode('inexistente'), isNull);
    });
  });
}
