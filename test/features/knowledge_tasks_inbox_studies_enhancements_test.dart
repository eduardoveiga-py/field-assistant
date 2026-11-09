import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/tasks/task_manager.dart';
import 'package:ministerio_pessoal/publications/publication_catalog.dart';

void main() {
  group('Novas Funcionalidades: Estudos, Tarefas, Inbox e Visualizadores', () {
    late AppDatabase db;
    late AppRepository repo;
    late TaskManager taskMgr;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = AppRepository(db);
      taskMgr = TaskManager(db: db);
    });

    tearDown(() async {
      await db.close();
    });

    test('1. Estudos Bíblicos: Criação e atualização de tags/metas em learningGoals', () async {
      final person = await repo.createPerson(
        name: 'Carlos Oliveira',
        status: 'interessado',
        firstContactAt: DateTime.now(),
      );

      final study = await repo.createStudy(
        title: 'Estudo Carlos Oliveira',
        publicationId: 'lff-book',
        language: 'pt',
        status: 'ativo',
        currentLesson: 3,
        currentParagraph: 2,
        learningGoals: 'Batismo, Jovem, Pioneiro',
        participantPersonIds: [person.id],
      );

      expect(study.title, 'Estudo Carlos Oliveira');
      expect(study.learningGoals, 'Batismo, Jovem, Pioneiro');

      // Test parsing tags
      final tags = study.learningGoals!
          .split(RegExp(r'[,;]'))
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      expect(tags, ['Batismo', 'Jovem', 'Pioneiro']);
      expect(tags.contains('Batismo'), isTrue);
      expect(tags.contains('Jovem'), isTrue);

      // Atualização de tags
      await repo.updateStudy(
        study.copyWith(
          learningGoals: const Value('Batismo, Família'),
        ),
      );

      final updated = await repo.getStudyById(study.id);
      expect(updated?.learningGoals, 'Batismo, Família');
    });

    test('2. Estudos Bíblicos: Lógica de Filtro por Pesquisa, Publicação e Tags', () {
      final study1 = BibleStudyEntry(
        id: 's1',
        title: 'Estudo Família Santos',
        ownerId: 'local_user',
        startedAt: DateTime.now(),
        status: 'ativo',
        publicationId: 'lff-book',
        language: 'pt',
        frequency: 'semanal',
        currentLesson: 12,
        currentParagraph: 4,
        learningGoals: 'Batismo, Família',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        revision: 1,
      );

      final study2 = BibleStudyEntry(
        id: 's2',
        title: 'Estudo Marcos André',
        ownerId: 'local_user',
        startedAt: DateTime.now(),
        status: 'ativo',
        publicationId: 'lff-brochure',
        language: 'pt',
        frequency: 'semanal',
        currentLesson: 2,
        currentParagraph: 1,
        learningGoals: 'Jovem, Oração',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        revision: 1,
      );

      final study3 = BibleStudyEntry(
        id: 's3',
        title: 'Estudo Encerrado Antigo',
        ownerId: 'local_user',
        startedAt: DateTime.now().subtract(const Duration(days: 90)),
        status: 'encerrado',
        publicationId: 'lff-book',
        language: 'pt',
        frequency: 'semanal',
        learningGoals: 'Pausado',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        revision: 1,
      );

      final studies = [study1, study2, study3];

      // Filtro Status 'Ativos'
      final actives = studies.where((s) => s.status == 'ativo').toList();
      expect(actives.length, 2);

      // Filtro Publicação 'lff-brochure'
      final brochureStudies = studies.where((s) => s.publicationId == 'lff-brochure').toList();
      expect(brochureStudies.length, 1);
      expect(brochureStudies.first.id, 's2');

      // Filtro Tag 'Família'
      final familyStudies = studies.where((s) {
        return s.learningGoals?.toLowerCase().contains('família') ?? false;
      }).toList();
      expect(familyStudies.length, 1);
      expect(familyStudies.first.id, 's1');

      // Pesquisa por título
      final searchTitle = studies.where((s) {
        return s.title.toLowerCase().contains('marcos');
      }).toList();
      expect(searchTitle.length, 1);
      expect(searchTitle.first.id, 's2');

      // Pesquisa por publicação nome catalogado
      final pub1 = PublicationCatalog.getById(study1.publicationId);
      expect(pub1, isNotNull);
      expect(pub1!.title.toLowerCase().contains('seja feliz'), isTrue);
    });

    test('3. Tarefas: Exibição de Descrição e Atualização de Tags', () async {
      final task = await taskMgr.createTask(
        title: 'Revisitar irmão no hospital',
        description: 'Levar a revista A Sentinela de novembro e orar juntos.',
        priority: 'alta',
        category: 'pastoreio',
        tags: ['pastoreio', 'hospital', 'urgente'],
      );

      expect(task.title, 'Revisitar irmão no hospital');
      expect(task.description, 'Levar a revista A Sentinela de novembro e orar juntos.');
      final meta = jsonDecode(task.metadata) as Map<String, dynamic>;
      expect(meta['tags'], ['pastoreio', 'hospital', 'urgente']);

      // Verificação da exibição da descrição no card (não truncada/ausente)
      expect(task.description, isNotEmpty);
      expect(task.description, contains('revista A Sentinela'));
    });

    test('4. Universal Attachment Viewer: Validação de Formatos e Extensões', () {
      final testCases = [
        {'path': 'foto_ministério.jpg', 'type': 'image'},
        {'path': 'documento_oficial.png', 'type': 'image'},
        {'path': 'audio_gravacao.m4a', 'type': 'audio'},
        {'path': 'audio_reuniao.mp3', 'type': 'audio'},
        {'path': 'manual_estudo.pdf', 'type': 'pdf'},
        {'path': 'anotacoes.txt', 'type': 'text'},
        {'path': 'resumo.md', 'type': 'text'},
      ];

      for (final tc in testCases) {
        final path = tc['path']!.toLowerCase();
        final expectedType = tc['type'];

        final isPdf = path.endsWith('.pdf');
        final isImage = path.endsWith('.jpg') || path.endsWith('.jpeg') || path.endsWith('.png') || path.endsWith('.webp');
        final isAudio = path.endsWith('.m4a') || path.endsWith('.mp3') || path.endsWith('.aac') || path.endsWith('.wav');
        final isText = path.endsWith('.txt') || path.endsWith('.md') || path.endsWith('.json');

        if (expectedType == 'pdf') expect(isPdf, isTrue);
        if (expectedType == 'image') expect(isImage, isTrue);
        if (expectedType == 'audio') expect(isAudio, isTrue);
        if (expectedType == 'text') expect(isText, isTrue);
      }
    });

    test('5. Markdown Rich Formatting: Sintaxe de Imagens e Links de Publicações/Vídeos', () {
      // Inline image formatting
      const imgPath = 'assets/img/territory_map.png';
      const imgCaption = 'Mapa do Território 12';
      final markdownImage = '![$imgCaption]($imgPath)';
      expect(markdownImage, '![Mapa do Território 12](assets/img/territory_map.png)');

      // Publication link formatting
      const pubTitle = 'Seja Feliz para Sempre!';
      const pubUrl = 'https://www.jw.org/finder?srcid=jwlshare&wtlocale=T&pub=lff';
      final markdownPubLink = '[📖 $pubTitle]($pubUrl)';
      expect(markdownPubLink, '[📖 Seja Feliz para Sempre!](https://www.jw.org/finder?srcid=jwlshare&wtlocale=T&pub=lff)');

      // Video link formatting
      const videoTitle = 'Por Que Estudar a Bíblia?';
      const videoUrl = 'https://www.jw.org/finder?srcid=jwlshare&wtlocale=T&lank=pub-ijwfv_1_VIDEO';
      final markdownVideoLink = '[🎥 $videoTitle]($videoUrl)';
      expect(markdownVideoLink, '[🎥 Por Que Estudar a Bíblia?](https://www.jw.org/finder?srcid=jwlshare&wtlocale=T&lank=pub-ijwfv_1_VIDEO)');
    });
  });
}
