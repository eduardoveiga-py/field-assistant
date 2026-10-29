import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/settings/backup_service.dart';

void main() {
  group('Serviço de Backup Criptografado e Restauração', () {
    late AppDatabase db;
    late AppRepository repository;
    late BackupService backupService;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repository = AppRepository(db);
      backupService = BackupService(repository);
    });

    tearDown(() async {
      await db.close();
    });

    test('TC-BAK-01: Exporta backup criptografado AES e restaura com sucesso', () async {
      // 1. Cadastra dados no banco original
      final p1 = await repository.createPerson(
        name: 'Maria Teste',
        phone: '123456',
        address: 'Rua do Teste, 10',
      );
      await repository.createVisit(
        personId: p1.id,
        dateTime: DateTime.now(),
        contactType: 'revisita',
        result: 'Ótima conversa',
      );

      // 2. Exporta backup criptografado com senha
      const password = 'MinhaSenhaSegura#123';
      final encryptedBackup = await backupService.exportEncryptedBackup(password);

      expect(encryptedBackup, isNotEmpty);
      expect(encryptedBackup, contains('ciphertext'));
      expect(encryptedBackup, contains('iv'));

      // 3. Pré-visualização com a senha correta
      final preview = await backupService.previewBackup(
        encryptedDataString: encryptedBackup,
        password: password,
      );

      expect(preview.peopleToAdd + preview.peopleUnchanged, equals(1));
      expect(preview.visitsToAdd + preview.visitsToUpdate, equals(1));

      // 4. Cria segundo banco vazio e restaura
      final db2 = AppDatabase.forTesting(NativeDatabase.memory());
      final repo2 = AppRepository(db2);
      final service2 = BackupService(repo2);

      await service2.commitRestore(preview);

      final restoredPeople = await repo2.getAllPeople();
      expect(restoredPeople.length, equals(1));
      expect(restoredPeople.first.name, equals('Maria Teste'));
      expect(restoredPeople.first.id, equals(p1.id));

      final restoredVisits = await repo2.getAllVisits();
      expect(restoredVisits.length, equals(1));
      expect(restoredVisits.first.result, equals('Ótima conversa'));

      await db2.close();
    });

    test('TC-BAK-02: Rejeita tentativa de restauração com senha incorreta', () async {
      await repository.createPerson(name: 'Carlos');
      final encryptedBackup = await backupService.exportEncryptedBackup('SenhaCorreta');

      expect(
        () async => await backupService.previewBackup(
          encryptedDataString: encryptedBackup,
          password: 'SenhaErrada',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('TC-BAK-03: Reimportar o mesmo backup é idempotente e NÃO duplica registros', () async {
      await repository.createPerson(name: 'Ana');
      final encryptedBackup = await backupService.exportEncryptedBackup('123456');

      final preview = await backupService.previewBackup(
        encryptedDataString: encryptedBackup,
        password: '123456',
      );

      // Executa duas vezes a restauração no mesmo banco
      await backupService.commitRestore(preview);
      await backupService.commitRestore(preview);

      final allPeople = await repository.getAllPeople();
      expect(allPeople.length, equals(1));
    });

    test('TC-BAK-04: Prévia de restauração detecta com precisão registros existentes vs novos em todas as entidades', () async {
      // Cria registros em banco 1
      final p1 = await repository.createPerson(name: 'Existente');
      await repository.createVisit(
        personId: p1.id,
        dateTime: DateTime.now(),
        contactType: 'revisita',
        result: 'Conversa inicial',
      );
      await repository.createStudy(
        title: 'Estudo Teste',
        publicationId: 'lff-book',
        language: 'pt',
        participantPersonIds: [p1.id],
      );
      await repository.createAppointment(
        personId: p1.id,
        title: 'Compromisso Teste',
        startTime: DateTime.now().add(const Duration(days: 1)),
        endTime: DateTime.now().add(const Duration(days: 1, minutes: 30)),
      );
      await repository.createActivityRecord(
        date: DateTime.now(),
        durationSeconds: 3600,
        modality: 'campo',
      );

      // Exporta backup contendo esses dados
      final encryptedBackup = await backupService.exportEncryptedBackup('senha123');

      // Ao pré-visualizar contra o MESMO banco onde já existem:
      final previewSameDb = await backupService.previewBackup(
        encryptedDataString: encryptedBackup,
        password: 'senha123',
      );

      // Nenhuma entidade deve ser contada como 'ToAdd' pois todos os IDs já existem
      expect(previewSameDb.peopleToAdd, equals(0));
      expect(previewSameDb.peopleUnchanged, equals(1));
      expect(previewSameDb.visitsToAdd, equals(0));
      expect(previewSameDb.studiesToAdd, equals(0));
      expect(previewSameDb.appointmentsToAdd, equals(0));
      expect(previewSameDb.activitiesToAdd, equals(0));

      // Em um banco novo e vazio:
      final dbNew = AppDatabase.forTesting(NativeDatabase.memory());
      final repoNew = AppRepository(dbNew);
      final serviceNew = BackupService(repoNew);

      final previewNewDb = await serviceNew.previewBackup(
        encryptedDataString: encryptedBackup,
        password: 'senha123',
      );

      expect(previewNewDb.peopleToAdd, equals(1));
      expect(previewNewDb.visitsToAdd, equals(1));
      expect(previewNewDb.studiesToAdd, equals(1));
      expect(previewNewDb.appointmentsToAdd, equals(1));
      expect(previewNewDb.activitiesToAdd, equals(1));

      await dbNew.close();
    });
  });
}
