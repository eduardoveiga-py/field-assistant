import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/sync/sync_engine.dart';

void main() {
  test('compara coleções JSON por conteúdo, não por identidade', () {
    final result = SyncEngine.mergeEntities(
      entityType: 'people', entityId: '1',
      baseData: {'tags': [{'a': 1}, 'casa']},
      localData: {'tags': [{'a': 1}, 'casa']},
      remoteData: {'tags': [{'a': 1}, 'aldeia']},
    );
    expect(result.hasConflict, isFalse);
    expect(result.mergedData['tags'], [{'a': 1}, 'aldeia']);
  });

  test('alterações iguais não são conflito; divergências são preservadas', () {
    final same = SyncEngine.mergeEntities(
      entityType: 'people', entityId: '1',
      baseData: {'address': {'city': 'antiga'}},
      localData: {'address': {'city': 'Içá'}},
      remoteData: {'address': {'city': 'Içá'}},
    );
    expect(same.hasConflict, isFalse);
    expect(same.mergedData['address'], {'city': 'Içá'});
    final different = SyncEngine.mergeEntities(
      entityType: 'people', entityId: '1',
      baseData: {'address': {'city': 'antiga'}},
      localData: {'address': {'city': 'Içá'}},
      remoteData: {'address': {'city': 'Tabatinga'}},
    );
    expect(different.hasConflict, isTrue);
    expect(different.mergedData['address'], {'city': 'Içá'});
    expect(different.conflicts.single.remoteValue, {'city': 'Tabatinga'});
  });
}
