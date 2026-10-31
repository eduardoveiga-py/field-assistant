import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/appointments/plan_b_recommender.dart';
import 'package:ministerio_pessoal/database/app_database.dart';

void main() {
  group('PlanBRecommender (R4 - Botão Plano B Imediato)', () {
    final baseNow = DateTime(2026, 10, 24, 14, 0); // Sábado às 14h

    PersonEntry makePerson({
      required String id,
      required String name,
      required String status,
      double? latitude,
      double? longitude,
      String? preferredSchedule,
      DateTime? firstContactAt,
      DateTime? deletedAt,
    }) {
      return PersonEntry(
        id: id,
        name: name,
        status: status,
        tags: '[]',
        latitude: latitude,
        longitude: longitude,
        preferredSchedule: preferredSchedule,
        firstContactAt: firstContactAt ?? baseNow,
        createdAt: baseNow,
        updatedAt: baseNow,
        deletedAt: deletedAt,
        revision: 1,
      );
    }

    test('Sugere contatos mais próximos geograficamente com GPS ativo', () {
      final cancelled = makePerson(id: 'c1', name: 'Estudante Cancelou', status: 'estudo');

      // Ponto de referência atual: -23.5505, -46.6333 (São Paulo Marco Zero)
      // p1: 300m de distância
      final p1 = makePerson(
        id: 'p1',
        name: 'Vizinho Próximo',
        status: 'revisita',
        latitude: -23.5530,
        longitude: -46.6333,
      );

      // p2: 1.2km de distância
      final p2 = makePerson(
        id: 'p2',
        name: 'Contato Médio',
        status: 'revisita',
        latitude: -23.5610,
        longitude: -46.6333,
      );

      // p3: 15km de distância
      final p3 = makePerson(
        id: 'p3',
        name: 'Contato Longe',
        status: 'revisita',
        latitude: -23.6800,
        longitude: -46.6333,
      );

      final suggestions = PlanBRecommender.getSuggestions(
        cancelledPerson: cancelled,
        allPeople: [p1, p2, p3],
        allVisits: [],
        currentLat: -23.5505,
        currentLng: -46.6333,
        targetDateTime: baseNow,
      );

      expect(suggestions.length, equals(3));
      // O mais próximo (p1) deve ser o primeiro
      expect(suggestions.first.person.id, equals('p1'));
      expect(suggestions.first.distanceKm, isNotNull);
      expect(suggestions.first.distanceKm!, lessThan(0.5));
      expect(suggestions.first.reason, contains('de você'));
    });

    test('Exclui a própria pessoa cancelada, contatos excluídos ou arquivados', () {
      final cancelled = makePerson(id: 'c1', name: 'Estudante Cancelou', status: 'estudo');
      final deleted = makePerson(id: 'd1', name: 'Excluído', status: 'revisita', deletedAt: baseNow);
      final archived = makePerson(id: 'a1', name: 'Arquivado', status: 'arquivado');
      final valid = makePerson(id: 'v1', name: 'Válido', status: 'revisita');

      final suggestions = PlanBRecommender.getSuggestions(
        cancelledPerson: cancelled,
        allPeople: [cancelled, deleted, archived, valid],
        allVisits: [],
        targetDateTime: baseNow,
      );

      expect(suggestions.length, equals(1));
      expect(suggestions.first.person.id, equals('v1'));
      expect(suggestions.first.person.name, equals('Válido'));
    });

    test('Fallback sem GPS prioriza dia habitual e sementes recentes', () {
      final cancelled = makePerson(id: 'c1', name: 'Estudante Cancelou', status: 'estudo');

      // Sábado às 14h: pSaturday costuma atender aos sábados
      final pSaturday = makePerson(
        id: 'pSat',
        name: 'Maria Sábado',
        status: 'revisita',
        preferredSchedule: 'Sábado às 14:00',
      );

      // pMonday costuma atender às segundas
      final pMonday = makePerson(
        id: 'pMon',
        name: 'José Segunda',
        status: 'revisita',
        preferredSchedule: 'Segunda às 09:00',
      );

      final suggestions = PlanBRecommender.getSuggestions(
        cancelledPerson: cancelled,
        allPeople: [pMonday, pSaturday],
        allVisits: [],
        currentLat: null,
        currentLng: null,
        targetDateTime: baseNow, // Sábado
      );

      expect(suggestions.first.person.id, equals('pSat'));
      expect(suggestions.first.reason, contains('sábados'));
    });

    test('Limita o número de sugestões a no máximo 3 alternativas', () {
      final cancelled = makePerson(id: 'c1', name: 'Estudante Cancelou', status: 'estudo');
      final list = List.generate(
        10,
        (i) => makePerson(id: 'p_$i', name: 'Contato $i', status: 'revisita'),
      );

      final suggestions = PlanBRecommender.getSuggestions(
        cancelledPerson: cancelled,
        allPeople: list,
        allVisits: [],
      );

      expect(suggestions.length, equals(3));
    });
  });
}
