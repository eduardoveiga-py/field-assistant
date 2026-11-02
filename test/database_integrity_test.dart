import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';

void main() {
  group('Integridade de Banco de Dados, Pragmas e Foreign Keys', () {
    late AppDatabase db;
    late AppRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(
        NativeDatabase.memory(
          setup: (rawDb) {
            rawDb.execute('PRAGMA foreign_keys = ON;');
          },
        ),
      );
      repo = AppRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('TC-DB-ADV-01: PRAGMA foreign_keys = ON impede registros órfãos ao rejeitar chaves estrangeiras inexistentes', () async {
      final now = DateTime.now();

      // Tentativa de inserir uma visita com personId inexistente
      expect(
        () async {
          await db
              .into(db.visits)
              .insert(
                VisitEntry(
                  id: 'visit_orphan_attempt',
                  personId: 'uuid_pessoa_inexistente_123',
                  dateTimeField: now,
                  contactType: 'revisita',
                  result: 'conversa',
                  createdAt: now,
                  updatedAt: now,
                  revision: 1,
                ),
              );
        },
        throwsA(
          isA<sqlite.SqliteException>().having(
            (e) => e.message,
            'message',
            contains('FOREIGN KEY constraint failed'),
          ),
        ),
      );

      // Inserção legítima com pessoa existente deve funcionar normalmente
      final person = await repo.createPerson(name: 'Pessoa Legítima');
      final validVisit = await repo.createVisit(
        personId: person.id,
        dateTime: now,
        contactType: 'revisita',
        result: 'conversou',
      );
      expect(validVisit.id, isNotEmpty);
    });

    test(
      'TC-DB-ADV-02: Verificação do pragma foreign_keys ativado na conexão',
      () async {
        final result = await db
            .customSelect('PRAGMA foreign_keys;')
            .getSingle();
        final isFkEnabled = result.data['foreign_keys'] == 1;
        expect(
          isFkEnabled,
          isTrue,
          reason: 'PRAGMA foreign_keys deve estar ativo (=1)',
        );
      },
    );
  });
}
