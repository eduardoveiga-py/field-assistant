import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/contacts/phone_contacts_manager.dart';
import 'package:ministerio_pessoal/family/family_ties_manager.dart';
import 'package:ministerio_pessoal/research/research_manager.dart';
import 'package:ministerio_pessoal/experiences/experience_manager.dart';
import 'package:ministerio_pessoal/publications/person_publications_manager.dart';
import 'package:ministerio_pessoal/dashboard/counting_rules.dart';
import 'package:ministerio_pessoal/appointments/availability_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late AppRepository repo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = AppRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('1. Telefones (PhoneContactsManager) e Conversão para Pessoas', () {
    test('Adiciona contato de telefone, filtra e promove para Pessoas', () async {
      final phoneMgr = PhoneContactsManager(db);

      // Adiciona contato telefônico de testemunho público/carrinho
      final item = await phoneMgr.addPhoneContact(
        name: 'Carlos Oliveira',
        phone: '11988887777',
        secondaryPhone: '11977776666',
        hasWhatsApp: true,
        whatsAppInfo: 'Prefere mensagens à tarde',
        hasSocial: true,
        socialPlatform: 'Instagram',
        socialHandle: '@carlos_oli',
        notes: 'Contato feito no carrinho da feira. Mostrou interesse na brochura Seja Feliz.',
        tags: ['Carrinho', 'Feira', 'Jovem'],
        origin: 'TPL / Carrinho',
      );

      expect(item.name, 'Carlos Oliveira');
      expect(item.hasWhatsApp, isTrue);
      expect(item.origin, 'TPL / Carrinho');
      expect(item.tags, contains('Carrinho'));

      // Pesquisa por texto
      final allContacts = await phoneMgr.getAllPhoneContacts();
      final searchResults = allContacts.where((c) => c.name.toLowerCase().contains('carlos')).toList();
      expect(searchResults.length, 1);
      expect(searchResults.first.id, item.id);

      // Promoção para a tabela People via convertToPerson
      final promotedPerson = await phoneMgr.convertToPerson(
        contact: item,
        repo: repo,
        address: 'Rua das Flores, 123 - Centro',
        latitude: -23.55052,
        longitude: -46.633308,
      );

      expect(promotedPerson.name, 'Carlos Oliveira');
      expect(promotedPerson.phone, '11988887777');
      expect(promotedPerson.address, 'Rua das Flores, 123 - Centro');
      expect(promotedPerson.status, 'interessado');

      // Verifica que o contato de telefone agora registra a conversão
      final updatedPhoneContacts = await phoneMgr.getAllPhoneContacts();
      final updatedPhoneItem = updatedPhoneContacts.firstWhere((c) => c.id == item.id);
      expect(updatedPhoneItem.convertedPersonId, promotedPerson.id);
    });
  });

  group('2. Laços Familiares Recíprocos (FamilyTiesManager)', () {
    test('Criação de vínculo familiar gera automaticamente vínculo recíproco simétrico', () async {
      final familyMgr = FamilyTiesManager(db);

      final pai = await repo.createPerson(name: 'José Ferreira');
      final filho = await repo.createPerson(name: 'Lucas Ferreira');

      // Pai adiciona Lucas indicando que Lucas é seu 'Filho'
      await familyMgr.addFamilyTie(
        personId: pai.id,
        personName: pai.name,
        relatedPersonId: filho.id,
        relatedPersonName: filho.name,
        relationshipType: 'Filho',
      );

      // Vínculos do Pai (o pai tem Lucas com parentesco 'Filho')
      final tiesPai = await familyMgr.getTiesForPerson(pai.id);
      expect(tiesPai.length, 1);
      expect(tiesPai.first.relatedPersonId, filho.id);
      expect(tiesPai.first.relationshipType, 'Filho');

      // Vínculos do Filho (o filho tem automaticamente José com parentesco 'Pai/Mãe')
      final tiesFilho = await familyMgr.getTiesForPerson(filho.id);
      expect(tiesFilho.length, 1);
      expect(tiesFilho.first.relatedPersonId, pai.id);
      expect(tiesFilho.first.relationshipType, 'Pai/Mãe');

      // Vínculo manual para familiar não cadastrado
      await familyMgr.addFamilyTie(
        personId: pai.id,
        personName: pai.name,
        relatedPersonName: 'Maria Ferreira (Avó)',
        relationshipType: 'Avó',
      );

      final tiesPaiAtualizado = await familyMgr.getTiesForPerson(pai.id);
      expect(tiesPaiAtualizado.length, 2);
      expect(tiesPaiAtualizado.any((t) => t.relatedPersonName == 'Maria Ferreira (Avó)'), isTrue);
    });
  });

  group('3. Pesquisas para o Ministério (ResearchManager)', () {
    test('Adiciona tópicos de pesquisa e realiza busca textual em título, resumo e conteúdo', () async {
      final researchMgr = ResearchManager(db);

      final tag = await researchMgr.addTag('Profecias');
      expect(tag.name, 'Profecias');

      await researchMgr.addArticle(
        title: 'Por que Deus permite o sofrimento?',
        summary: 'Explicação bíblica clara baseada em Jó e Romanos 8:28.',
        content: 'Texto completo de pesquisa com passagens bíblicas sobre a questão da soberania e do tempo para demonstrar que o governo humano é falho.',
        tags: ['Profecias', 'Dúvidas Bíblicas'],
      );

      await researchMgr.addArticle(
        title: 'Como iniciar conversas no carrinho',
        summary: 'Frases práticas de apresentação com a brochura Seja Feliz.',
        content: 'Cumprimente com simpatia e aponte para uma pergunta da capa do tratado ou da revista atual.',
        tags: ['TPL', 'Apresentações'],
      );

      final allArticles = await researchMgr.getAllArticles();

      // Busca por palavra no conteúdo
      final searchContent = allArticles.where((a) => a.content.toLowerCase().contains('soberania')).toList();
      expect(searchContent.length, 1);
      expect(searchContent.first.title, contains('sofrimento'));

      // Busca por palavra no resumo
      final searchSummary = allArticles.where((a) => a.summary.toLowerCase().contains('apresentação')).toList();
      expect(searchSummary.length, 1);
      expect(searchSummary.first.title, contains('carrinho'));
    });
  });

  group('4. Experiências no Ministério (ExperienceManager)', () {
    test('Cria experiência com mídia e tags', () async {
      final expMgr = ExperienceManager(db);

      final exp = await expMgr.addExperience(
        title: 'Conversa marcante na praça',
        content: 'Encontrei um jovem que havia perdido o pai recentemente e buscava consolo bíblico.',
        locationOrModality: 'Praça Central - TPL',
        dateTime: DateTime(2026, 10, 20, 10, 30),
        tags: ['Consolo', 'TPL'],
        mediaUrls: ['data:image/jpeg;base64,/9j/4AAQSkZJRg=='],
      );

      expect(exp.title, 'Conversa marcante na praça');
      expect(exp.mediaUrls.length, 1);
      expect(exp.tags, contains('Consolo'));

      final allExps = await expMgr.getAllExperiences();
      expect(allExps.any((e) => e.id == exp.id), isTrue);
    });
  });

  group('5. Métricas de Progresso do Estudante, Funil e Encerramento de Estudos', () {
    test('Calcula progresso do estudante, regularidade, marco Parte 3 e motivos de encerramento', () async {
      final student = await repo.createPerson(name: 'Beatriz Santos', status: 'estudo');
      final study = await repo.createStudy(
        title: 'Estudo com Beatriz',
        publicationId: 'lff-book',
        participantPersonIds: [student.id],
        status: 'ativo',
      );

      // Atualiza para Lição 35 (Parte 3 do Livro Seja Feliz)
      await repo.updateStudy(study.copyWith(
        currentLesson: const Value(35),
      ));

      final updatedStudy = (await repo.getStudyById(study.id))!;

      // Registra visitas e sessões
      final v1 = await repo.createVisit(
        personId: student.id,
        dateTime: DateTime.now().subtract(const Duration(days: 7)),
        contactType: 'presencial',
        result: 'revisita_realizada',
      );
      final v2 = await repo.createVisit(
        personId: student.id,
        dateTime: DateTime.now().subtract(const Duration(days: 14)),
        contactType: 'presencial',
        result: 'nao_em_casa',
        notes: 'Estudante não estava em casa',
      );

      final s1 = await repo.createStudySession(
        studyId: study.id,
        dateTime: DateTime.now().subtract(const Duration(days: 7)),
        lessonCovered: 35,
        sessionNotes: 'Assistência: 2 pessoas',
      );

      final progress = DashboardCalculator.calculateStudentProgress(
        person: student,
        study: updatedStudy,
        sessions: [s1],
        visits: [v1, v2],
      );

      expect(progress.totalVisits, 2);
      expect(progress.notAtHomeVisits, 1);
      expect(progress.isPart3Reached, isTrue);
      expect(progress.currentLesson, 35);
      expect(progress.averageAttendees, 2.0);

      // Verifica cálculo do funil de conversão geral
      final p1 = await repo.createPerson(name: 'Interessado 1', status: 'interessado');
      final p2 = await repo.createPerson(name: 'Revisita 1', status: 'revisita');
      final p3 = await repo.createPerson(name: 'Revisita Passada', status: 'revisita_passada');

      final metrics = DashboardCalculator.calculate(
        studies: [updatedStudy],
        sessions: [s1],
        visits: [v1, v2],
        appointments: [],
        activities: [],
        people: [student, p1, p2, p3],
        periodStart: DateTime(2026, 1, 1),
        periodEnd: DateTime(2026, 12, 31),
      );

      expect(metrics.funnelInterestedCount >= 1, isTrue);
      expect(metrics.funnelStartedStudyCount >= 1, isTrue);
      expect(metrics.funnelReachedPart3Count >= 1, isTrue);
      // Revisita passada não polui estudos ativos
      expect(metrics.activeStudiesCount, 1);
    });

    test('Calcula regularidade percentual precisa com base no dia habitual do estudante', () async {
      final student = await repo.createPerson(
        name: 'Marcos Souza',
        status: 'estudo',
        preferredSchedule: 'Segunda-feira às 15:00',
      );
      final study = await repo.createStudy(
        title: 'Estudo Marcos',
        publicationId: 'lff-book',
        participantPersonIds: [student.id],
        status: 'ativo',
      );

      // Sessão 1: Segunda-feira (05/10/2026)
      final s1 = await repo.createStudySession(
        studyId: study.id,
        dateTime: DateTime(2026, 10, 5, 15, 0),
        lessonCovered: 10,
        sessionNotes: 'Assistência: 1 pessoa',
      );

      // Sessão 2: Quarta-feira (07/10/2026) - Fora do dia habitual
      final s2 = await repo.createStudySession(
        studyId: study.id,
        dateTime: DateTime(2026, 10, 7, 15, 0),
        lessonCovered: 11,
        sessionNotes: 'Assistência: 3 pessoas',
      );

      final progress = DashboardCalculator.calculateStudentProgress(
        person: student,
        study: study,
        sessions: [s1, s2],
        visits: [],
      );

      // 1 de 2 sessões no dia habitual -> exatamente 50.0%
      expect(progress.regularityPercent, 50.0);
      // Média de presença: (1 + 3) / 2 = 2.0
      expect(progress.averageAttendees, 2.0);
    });

    test('DashboardCalculator decodifica motivo de encerramento em JSON e suporta estudos concluídos e repassados', () async {
      final pPassed = await repo.createPerson(name: 'Ana Repassada', status: 'revisita_passada');
      final pActive = await repo.createPerson(name: 'Carlos Ativo', status: 'estudo');

      // Estudo 1: Encerrado com JSON estruturado
      final s1 = await repo.createStudy(
        title: 'Estudo Encerrado JSON',
        publicationId: 'lff-book',
        participantPersonIds: [pActive.id],
        status: 'encerrado',
        pauseOrCloseReason: jsonEncode({
          'endReason': 'Mudou-se de território',
          'notes': 'Mudou de cidade por motivo de trabalho',
          'closedAt': '2026-10-15T10:00:00',
        }),
      );

      // Estudo 2: Concluído / Batizado
      final s2 = await repo.createStudy(
        title: 'Estudo Concluído',
        publicationId: 'lff-book',
        participantPersonIds: [pActive.id],
        status: 'concluido',
      );

      // Estudo 3: Encerrado com motivo em texto simples
      final s3 = await repo.createStudy(
        title: 'Estudo Texto Legado',
        publicationId: 'lff-book',
        participantPersonIds: [pActive.id],
        status: 'encerrado',
        pauseOrCloseReason: 'Falta de interesse/tempo',
      );

      // Estudo 4: Ativo, mas cujo participante é 'revisita_passada' (não deve contar em estudos ativos)
      final s4 = await repo.createStudy(
        title: 'Estudo com Participante Repassado',
        publicationId: 'lff-book',
        participantPersonIds: [pPassed.id],
        status: 'ativo',
      );

      final metrics = DashboardCalculator.calculate(
        studies: [s1, s2, s3, s4],
        sessions: [],
        visits: [],
        appointments: [],
        activities: [],
        people: [pPassed, pActive],
        participants: await db.select(db.studyParticipants).get(),
        periodStart: DateTime(2026, 1, 1),
        periodEnd: DateTime(2026, 12, 31),
      );

      // 3 estudos encerrados/concluídos
      expect(metrics.endedStudiesCount, 3);
      expect(metrics.endedByReason['Mudou-se de território'], 1);
      expect(metrics.endedByReason['Estudo concluído / Batizado'], 1);
      expect(metrics.endedByReason['Falta de interesse/tempo'], 1);

      // O estudo s4 de participante repassado não polui os ativos
      expect(metrics.activeStudiesCount, 0);
    });
  });

  group('7. Gestão de Publicações Entregues e Pedidos (PersonPublicationsManager)', () {
    test('Registra publicações entregues, pedidos e preserva observações ao atualizar status', () async {
      final pubMgr = PersonPublicationsManager(db);
      final person = await repo.createPerson(name: 'Mariana Lima');

      // Registra publicação entregue
      final delivered = await pubMgr.addDeliveredPublication(
        personId: person.id,
        title: 'Livro Seja Feliz para Sempre!',
        notes: 'Entregue no primeiro dia de estudo',
      );

      expect(delivered.publicationTitle, 'Livro Seja Feliz para Sempre!');
      expect(delivered.status, 'entregue');
      expect(delivered.itemType, 'entregue');
      expect(delivered.notes, 'Entregue no primeiro dia de estudo');

      // Registra pedido do estudante
      final request = await pubMgr.addStudentRequest(
        personId: person.id,
        title: 'Tradução do Novo Mundo (Bíblia com referências)',
        notes: 'Edição de capa preta',
        targetDate: DateTime(2026, 11, 1),
      );

      expect(request.publicationTitle, contains('Bíblia'));
      expect(request.status, 'a_pedir');
      expect(request.itemType, 'pedido');
      expect(request.notes, 'Edição de capa preta');

      // Atualiza status do pedido para 'conseguido' SEM passar novas anotações
      // Deve preservar 'Edição de capa preta' intacta
      await pubMgr.updatePublicationStatus(
        id: request.id,
        newStatus: 'conseguido',
      );

      var personPubs = await pubMgr.getPublicationsForPerson(person.id);
      var updatedRequest = personPubs.firstWhere((p) => p.id == request.id);
      expect(updatedRequest.status, 'conseguido');
      expect(updatedRequest.notes, 'Edição de capa preta');

      // Atualiza status e anotações
      await pubMgr.updatePublicationStatus(
        id: request.id,
        newStatus: 'entregue',
        notes: 'Entregue no domingo após a reunião',
      );

      personPubs = await pubMgr.getPublicationsForPerson(person.id);
      updatedRequest = personPubs.firstWhere((p) => p.id == request.id);
      expect(updatedRequest.status, 'entregue');
      expect(updatedRequest.notes, 'Entregue no domingo após a reunião');

      // Exclusão
      await pubMgr.deletePublication(delivered.id);
      personPubs = await pubMgr.getPublicationsForPerson(person.id);
      expect(personPubs.length, 1);
      expect(personPubs.first.id, request.id);
    });
  });

  group('6. Agendamento Recorrente com Contato e AvailabilityEngine', () {
    test('Cria compromissos recorrentes e respeita horários ocupados', () async {
      final person = await repo.createPerson(name: 'Daniel Rocha');

      final baseTime = DateTime(2026, 11, 2, 14, 0); // Segunda-feira às 14:00

      // Compromisso já existente no dia 9/11 às 14:00 (semana 2)
      final existingAppt = await repo.createAppointment(
        title: 'Reunião com superintendente',
        startTime: baseTime.add(const Duration(days: 7)),
        endTime: baseTime.add(const Duration(days: 7, minutes: 45)),
        durationMinutes: 45,
        status: 'confirmado',
      );

      final currentAppts = [existingAppt];

      // Simulando geração de 4 ocorrências semanais com respeito a AvailabilityEngine
      final createdAppts = <AppointmentEntry>[];
      int skippedConflicts = 0;

      for (int i = 0; i < 4; i++) {
        final occStart = baseTime.add(Duration(days: i * 7));
        final occEnd = occStart.add(const Duration(minutes: 30));

        final hasCollision = AvailabilityEngine.hasCollision(
          start: occStart,
          end: occEnd,
          existingAppointments: [...currentAppts, ...createdAppts],
        );

        if (hasCollision) {
          skippedConflicts++;
        } else {
          final newAppt = await repo.createAppointment(
            personId: person.id,
            title: 'Estudo Bíblico: ${person.name}',
            startTime: occStart,
            endTime: occEnd,
            durationMinutes: 30,
            status: 'confirmado',
          );
          createdAppts.add(newAppt);
        }
      }

      // Deve ter criado 3 compromissos e pulado 1 por colisão com a reunião existente
      expect(createdAppts.length, 3);
      expect(skippedConflicts, 1);
      for (final a in createdAppts) {
        expect(a.personId, person.id);
        expect(a.title, contains('Daniel Rocha'));
      }
    });
  });
}
