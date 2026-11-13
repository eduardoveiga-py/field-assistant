import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/territory/sector_manager.dart';
import 'package:ministerio_pessoal/territory/landmark_manager.dart';
import 'package:ministerio_pessoal/dashboard/counting_rules.dart';

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('Gerenciamento de Bairros / Setores do Território (SectorManager)', () {
    late AppDatabase db;
    late AppRepository repository;
    late SectorManager sectorManager;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repository = AppRepository(db);
      sectorManager = SectorManager(db);
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'Tabela inicia completamente vazia sem setores fictícios',
      () async {
        final sectors = await sectorManager.getSectors();
        expect(sectors, isEmpty);
      },
    );

    test('Adiciona novo setor personalizado com sucesso', () async {
      final sec = await sectorManager.addSector(
        'Vila Nova',
        description: 'Próximo à rodovia',
      );
      expect(sec.name, equals('Vila Nova'));
      expect(sec.description, equals('Próximo à rodovia'));

      final sectors = await sectorManager.getSectors();
      expect(sectors.length, equals(1));
      expect(sectors.first.name, equals('Vila Nova'));
    });

    test('Atualização de setor renomeia e atualiza contatos associados no repositório', () async {
      final sec = await sectorManager.addSector(
        'Betânia',
        description: 'Setor residencial',
      );
      final p1 = await repository.createPerson(
        name: 'Carlos Oliveira',
        address: 'Rua 1, Bairro: Betânia',
      );

      await sectorManager.updateSector(
        sec.id,
        'Betânia Alto',
        description: 'Setor elevado',
        repo: repository,
      );

      final updatedSectors = await sectorManager.getSectors();
      expect(updatedSectors.any((s) => s.name == 'Betânia Alto'), isTrue);
      expect(updatedSectors.any((s) => s.name == 'Betânia'), isFalse);

      final updatedPerson = await repository.getPersonById(p1.id);
      expect(updatedPerson?.address, contains('Betânia Alto'));
    });

    test('Exclusão de setor remove registro da tabela', () async {
      final sec = await sectorManager.addSector('Setor Temporário');
      var list = await sectorManager.getSectors();
      expect(list.any((s) => s.id == sec.id), isTrue);

      await sectorManager.deleteSector(sec.id);
      list = await sectorManager.getSectors();
      expect(list.any((s) => s.id == sec.id), isFalse);
    });

    test('watchSectors() emite os setores existentes imediatamente na inscrição sem perder eventos', () async {
      final initialSectors = await sectorManager.watchSectors().first;
      expect(initialSectors, isEmpty);
    });

    test(
      'Após exclusão de setores, a tabela permanece vazia sem auto-injeção de sementes',
      () async {
        final sec = await sectorManager.addSector('Setor Único');
        await sectorManager.deleteSector(sec.id);

        final afterDelete = await sectorManager.getSectors();
        expect(afterDelete, isEmpty);

        final secondCheck = await sectorManager.getSectors();
        expect(secondCheck, isEmpty);
      },
    );
  });

  group('Gerenciamento de Pontos de Referência / Marcos do Território (LandmarkManager)', () {
    late AppDatabase db;
    late LandmarkManager landmarkManager;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      landmarkManager = LandmarkManager(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('Tabela de marcos inicia vazia sem sementes fictícias', () async {
      final landmarks = await landmarkManager.getLandmarks();
      expect(landmarks, isEmpty);
    });

    test(
      'Adiciona ponto de referência com coordenadas do território e categoria válidas',
      () async {
        final landmark = await landmarkManager.addLandmark(
          name: 'Padaria Estrela',
          category: 'padaria',
          address: 'Av. Principal, 500',
          latitude: -3.1030,
          longitude: -67.9400,
          notes: 'Ponto de encontro da saída de campo',
        );

        expect(landmark.id, isNotEmpty);
        expect(landmark.name, equals('Padaria Estrela'));
        expect(landmark.category, equals('padaria'));
        expect(landmark.categoryLabel, equals('Padaria / Comércio'));
        expect(landmark.latitude, equals(-3.1030));
        expect(landmark.longitude, equals(-67.9400));

        final all = await landmarkManager.getLandmarks();
        expect(all.length, equals(1));
        expect(all.any((l) => l.name == 'Padaria Estrela'), isTrue);
      },
    );

    test('Atualização e exclusão de ponto de referência', () async {
      final lm = await landmarkManager.addLandmark(
        name: 'Escola Municipal Nova',
        category: 'escola',
        latitude: -3.1022,
        longitude: -67.9397,
      );

      final updated = TerritoryLandmark(
        id: lm.id,
        name: 'Escola Municipal Central',
        category: 'escola',
        address: 'Rua da Educação, 10',
        latitude: -3.1050,
        longitude: -67.9420,
        createdAt: lm.createdAt,
      );

      await landmarkManager.updateLandmark(updated);
      var all = await landmarkManager.getLandmarks();
      expect(
        all.any(
          (l) =>
              l.name == 'Escola Municipal Central' &&
              l.address == 'Rua da Educação, 10',
        ),
        isTrue,
      );

      await landmarkManager.deleteLandmark(lm.id);
      all = await landmarkManager.getLandmarks();
      expect(all, isEmpty);
    });

    test(
      'watchLandmarks() emite estado inicial vazio e atualiza com novos marcos',
      () async {
        final initialLandmarks = await landmarkManager.watchLandmarks().first;
        expect(initialLandmarks, isEmpty);

        await landmarkManager.addLandmark(
          name: 'Escola Municipal Teste',
          category: 'escola',
          latitude: -3.1022,
          longitude: -67.9397,
        );
        final landmarks = await landmarkManager.watchLandmarks().first;
        expect(
          landmarks.any((l) => l.name == 'Escola Municipal Teste'),
          isTrue,
        );
      },
    );

    test(
      'Após exclusão de todos os marcos, a tabela permanece vazia sem recriar sementes',
      () async {
        final lm = await landmarkManager.addLandmark(
          name: 'Posto de Saúde Local',
          category: 'saude',
          latitude: -3.1022,
          longitude: -67.9397,
        );
        await landmarkManager.deleteLandmark(lm.id);

        final afterDelete = await landmarkManager.getLandmarks();
        expect(afterDelete, isEmpty);

        // Chamada subsequente a getLandmarks() não deve re-popular
        final secondCheck = await landmarkManager.getLandmarks();
        expect(secondCheck, isEmpty);
      },
    );
  });

  group('Contagem de Assistência e Presentes (DashboardCalculator)', () {
    test('Formata e extrai contagem de assistência em visitas', () {
      final notesWithAttendance =
          DashboardCalculator.formatVisitNotesWithAttendance(
            'Conversa bíblica agradável',
            3,
          );
      expect(notesWithAttendance, contains('[Assistência: 3]'));
      expect(notesWithAttendance, contains('Conversa bíblica agradável'));

      final parsedAttendance = DashboardCalculator.parseVisitAttendance(
        VisitEntry(
          id: 'v1',
          personId: 'p1',
          dateTimeField: DateTime.now(),
          contactType: 'revisita',
          topicsDiscussed: notesWithAttendance,
          result: 'Conversa realizada',
          revision: 1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      expect(parsedAttendance, equals(3));

      // Fallback padrão quando não especificado
      final defaultAttendance = DashboardCalculator.parseVisitAttendance(
        VisitEntry(
          id: 'v2',
          personId: 'p1',
          dateTimeField: DateTime.now(),
          contactType: 'revisita',
          topicsDiscussed: 'Visita sem tag de assistência',
          result: 'Conversa realizada',
          revision: 1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      expect(defaultAttendance, equals(1));
    });
  });
}
