import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/sync/sync_engine.dart';

void main() {
  group('Sincronização Offline-First e Resolução de Conflitos', () {
    test('TC-SYNC-01: Mesclagem automática em nível de campos distintos sem perda de dados', () {
      final baseData = {
        'id': 'person-1',
        'name': 'João Carlos',
        'phone': '1111-1111',
        'address': 'Rua Antiga, 10',
      };

      // Dispositivo A (offline no campo) atualizou o telefone
      final localData = {
        'id': 'person-1',
        'name': 'João Carlos',
        'phone': '9999-9999', // alterado
        'address': 'Rua Antiga, 10',
      };

      // Dispositivo B (em casa) atualizou o endereço
      final remoteData = {
        'id': 'person-1',
        'name': 'João Carlos',
        'phone': '1111-1111',
        'address': 'Rua Nova, 50', // alterado
      };

      final result = SyncEngine.mergeEntities(
        entityType: 'people',
        entityId: 'person-1',
        localData: localData,
        remoteData: remoteData,
        baseData: baseData,
      );

      expect(result.hasConflict, isFalse);
      expect(result.mergedData['phone'], equals('9999-9999'));
      expect(result.mergedData['address'], equals('Rua Nova, 50'));
      expect(result.conflicts, isEmpty);
    });

    test('TC-SYNC-02: Conflito no mesmo campo NÃO sobrescreve silenciosamente e sinaliza divergência', () {
      final baseData = {
        'id': 'person-1',
        'name': 'Maria Silva',
        'notes': 'Primeira conversa sobre a Bíblia',
      };

      final localData = {
        'id': 'person-1',
        'name': 'Maria Silva',
        'notes': 'Anotação feita no campo: Gostou da revista Sentinela',
      };

      final remoteData = {
        'id': 'person-1',
        'name': 'Maria Silva',
        'notes': 'Anotação feita no iPad: Pediu para retornar na sexta às 16h',
      };

      final result = SyncEngine.mergeEntities(
        entityType: 'people',
        entityId: 'person-1',
        localData: localData,
        remoteData: remoteData,
        baseData: baseData,
      );

      expect(result.hasConflict, isTrue);
      expect(result.conflicts.length, equals(1));
      expect(result.conflicts.first.fieldName, equals('notes'));
      expect(result.conflicts.first.localValue, contains('Sentinela'));
      expect(result.conflicts.first.remoteValue, contains('sexta às 16h'));
    });

    test('TC-SYNC-03: Alterações idênticas em ambos os dispositivos mesclam sem conflito', () {
      final baseData = {
        'id': 'study-1',
        'currentLesson': 3,
      };

      final localData = {
        'id': 'study-1',
        'currentLesson': 4,
      };

      final remoteData = {
        'id': 'study-1',
        'currentLesson': 4,
      };

      final result = SyncEngine.mergeEntities(
        entityType: 'bible_studies',
        entityId: 'study-1',
        localData: localData,
        remoteData: remoteData,
        baseData: baseData,
      );

      expect(result.hasConflict, isFalse);
      expect(result.mergedData['currentLesson'], equals(4));
    });
  });
}
