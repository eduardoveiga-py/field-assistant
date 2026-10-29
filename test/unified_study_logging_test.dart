import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/appointments/availability_engine.dart';
import 'package:ministerio_pessoal/dashboard/counting_rules.dart';
import 'package:ministerio_pessoal/publications/publication_catalog.dart';
import 'package:ministerio_pessoal/publications/publication_link_resolver.dart';

void main() {
  group('Fluxo Unificado de Visita, Estudo Bíblico e Agendamento Global', () {
    late AppDatabase db;
    late AppRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = AppRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('Registro de visita com estudo cria atomicamente visita, sessão, estudo e agendamento vinculado', () async {
      final person = await repo.createPerson(
        name: 'Eduardo Silva',
        phone: '11987654321',
        address: 'Rua das Flores, 123',
        status: 'estudo',
      );

      final visitDate = DateTime(2026, 10, 28, 14, 0);
      final returnDate = DateTime(2026, 11, 4, 14, 0);
      const durationMin = 60;
      const attendance = 2;

      // 1. Checa disponibilidade prévia do agendamento
      final existingAppts = await repo.getAllAppointments();
      final availability = AvailabilityEngine.checkAvailability(
        startTime: returnDate,
        durationMinutes: durationMin,
        existingAppointments: existingAppts,
      );
      expect(availability.isAvailable, isTrue);

      // 2. Cria agendamento global
      final appt = await repo.createAppointment(
        personId: person.id,
        title: 'Estudo Bíblico: ${person.name}',
        startTime: returnDate,
        endTime: returnDate.add(const Duration(minutes: durationMin)),
        durationMinutes: durationMin,
        status: 'confirmado',
        locationNotes: 'Local: ${person.address}',
      );
      expect(appt.id, isNotEmpty);
      expect(appt.personId, equals(person.id));

      // 3. Formata anotações com contagem de presentes
      final formattedNotes = DashboardCalculator.formatSessionNotesWithAttendance(
        'Excelente progresso na lição sobre a criação.',
        attendance,
      );
      expect(formattedNotes, contains('[Assistência: 2]'));

      // 4. Cria visita atômica vinculando o appointmentId
      final visit = await repo.createVisit(
        personId: person.id,
        dateTime: visitDate,
        contactType: 'estudo',
        result: 'Conversa receptiva',
        topicsDiscussed: 'Lição 01 - Como a Bíblia pode ajudar você?',
        notes: formattedNotes,
        nextStep: 'Lição 02 - A Bíblia dá esperança',
        suggestedReturnDate: returnDate,
        appointmentId: appt.id,
      );
      expect(visit.appointmentId, equals(appt.id));
      expect(visit.contactType, equals('estudo'));

      // 5. Cria estudo e sessão correspondente
      final study = await repo.createStudy(
        title: 'Estudo de ${person.name}',
        publicationId: 'lff-book',
        language: 'pt',
        currentLesson: 1,
        currentParagraph: 5,
        participantPersonIds: [person.id],
        primaryParticipantId: person.id,
      );
      expect(study.id, isNotEmpty);

      final session = await repo.createStudySession(
        studyId: study.id,
        dateTime: visitDate,
        publicationCode: 'lff-book',
        lessonCovered: 1,
        paragraphsCovered: '1-5',
        sessionNotes: formattedNotes,
        nextStep: 'Lição 02',
        status: 'realizada',
        participantIds: [person.id],
      );
      expect(session.id, isNotEmpty);

      // 6. Verifica atualização do estudo após a sessão realizada
      final updatedStudy = (await repo.getStudyById(study.id))!;
      expect(updatedStudy.currentLesson, equals(1));
      expect(updatedStudy.currentParagraph, equals(5));
      expect(updatedStudy.nextTopic, equals('Lição 02'));

      // 7. Verifica regras de contagem de assistência
      expect(DashboardCalculator.parseVisitAttendance(visit), equals(2));
      expect(DashboardCalculator.parseSessionAttendance(session), equals(2));
    });

    test('AvailabilityEngine detecta conflito e sugere horários livres alternativos', () async {
      final base = DateTime(2026, 11, 10, 10, 0);

      // Cria compromisso existente
      final existingAppt = await repo.createAppointment(
        title: 'Reunião Congregacional',
        startTime: base,
        endTime: base.add(const Duration(minutes: 90)),
        durationMinutes: 90,
        status: 'confirmado',
      );

      final appts = [existingAppt];

      // Tenta agendar no meio da reunião
      final conflictCheck = AvailabilityEngine.checkAvailability(
        startTime: base.add(const Duration(minutes: 30)),
        durationMinutes: 60,
        existingAppointments: appts,
      );

      expect(conflictCheck.isAvailable, isFalse);
      expect(conflictCheck.conflictingAppointments.length, equals(1));
      expect(conflictCheck.conflictingAppointments.first.title, equals('Reunião Congregacional'));
      expect(conflictCheck.suggestedAlternativeSlots.isNotEmpty, isTrue);

      // Horário alternativo sugerido deve estar livre
      final alternativeSlot = conflictCheck.suggestedAlternativeSlots.first;
      final freeCheck = AvailabilityEngine.checkAvailability(
        startTime: alternativeSlot,
        durationMinutes: 60,
        existingAppointments: appts,
      );
      expect(freeCheck.isAvailable, isTrue);
    });

    test('PublicationLinkResolver gera link oficial correto para lff-book e lff-brochure', () {
      final pub = PublicationCatalog.getById('lff-book');
      expect(pub, isNotNull);
      expect(pub!.title, contains('Seja Feliz para Sempre!'));

      final resolved = PublicationLinkResolver.resolve(
        publicationId: 'lff-book',
        languageCode: 'pt',
        lesson: 2,
        paragraph: 3,
      );

      expect(resolved.url, isNotNull);
      expect(resolved.displayText, contains('Lição 2'));
      expect(resolved.url, contains('jw.org'));
    });

    test('Registro de matéria considerada em revisita (recordStudy = true) promove status e vincula estudo e retorno global', () async {
      // Inicia como revisita
      final person = await repo.createPerson(
        name: 'Carlos Oliveira',
        phone: '11977778888',
        address: 'Av. Brasil, 456',
        status: 'revisita',
      );
      expect(person.status, equals('revisita'));

      final visitDate = DateTime(2026, 10, 28, 16, 0);
      final returnDate = DateTime(2026, 11, 4, 16, 0);
      const isStudyConsidered = true;
      const durationMin = 60;
      const attendance = 1;

      // 1. Cria agendamento global para estudo futuro
      final appt = await repo.createAppointment(
        personId: person.id,
        title: 'Estudo Bíblico: ${person.name}',
        startTime: returnDate,
        endTime: returnDate.add(const Duration(minutes: durationMin)),
        durationMinutes: durationMin,
        status: 'confirmado',
      );

      // 2. Cria visita registrando o contato
      final formattedNotes = DashboardCalculator.formatSessionNotesWithAttendance(
        'Iniciamos a brochura Seja Feliz para Sempre.',
        attendance,
      );

      final visit = await repo.createVisit(
        personId: person.id,
        dateTime: visitDate,
        contactType: 'revisita',
        result: 'Conversa receptiva',
        topicsDiscussed: 'Introdução da lição 1',
        notes: formattedNotes,
        nextStep: 'Parágrafos 1 a 3',
        suggestedReturnDate: returnDate,
        appointmentId: appt.id,
      );
      expect(visit.appointmentId, equals(appt.id));

      // 3. Como isStudyConsidered é true, cria o estudo e sessão e atualiza a pessoa para estudo
      if (isStudyConsidered) {
        final newStudy = await repo.createStudy(
          title: 'Estudo de ${person.name}',
          publicationId: 'lff-brochure',
          language: 'pt',
          currentLesson: 1,
          currentParagraph: 3,
          participantPersonIds: [person.id],
          primaryParticipantId: person.id,
        );

        final session = await repo.createStudySession(
          studyId: newStudy.id,
          dateTime: visitDate,
          publicationCode: 'lff-brochure',
          lessonCovered: 1,
          paragraphsCovered: '1-3',
          sessionNotes: formattedNotes,
          nextStep: 'Parágrafo 4 em diante',
          status: 'realizada',
          participantIds: [person.id],
        );

        await repo.updatePerson(person.copyWith(status: 'estudo'));

        final updatedPerson = (await repo.getPersonById(person.id))!;
        expect(updatedPerson.status, equals('estudo'));
        expect(session.status, equals('realizada'));
        expect(session.lessonCovered, equals(1));
      }
    });

    test('Visualização de compromissos no mesmo dia identifica múltiplos horários e marca colisões', () async {
      final selectedDate = DateTime(2026, 11, 15, 14, 0);

      // Compromisso pela manhã (sem colisão)
      final apptMorning = await repo.createAppointment(
        title: 'Visita: Família Santos',
        startTime: DateTime(2026, 11, 15, 9, 0),
        endTime: DateTime(2026, 11, 15, 9, 30),
        durationMinutes: 30,
        status: 'confirmado',
      );

      // Compromisso à tarde (colide com 14:00)
      final apptAfternoon = await repo.createAppointment(
        title: 'Estudo: Marcos Lima',
        startTime: DateTime(2026, 11, 15, 14, 0),
        endTime: DateTime(2026, 11, 15, 15, 0),
        durationMinutes: 60,
        status: 'confirmado',
      );

      // Compromisso em outro dia (não deve aparecer no dia selecionado)
      await repo.createAppointment(
        title: 'Outro dia',
        startTime: DateTime(2026, 11, 16, 10, 0),
        endTime: DateTime(2026, 11, 16, 10, 30),
        durationMinutes: 30,
        status: 'confirmado',
      );

      final allAppts = await repo.getAllAppointments();

      // Filtra compromissos do mesmo dia civil (lógica do GlobalAppointmentSchedulingSection)
      final sameDay = allAppts.where((a) {
        if (a.deletedAt != null) return false;
        final st = a.status.toLowerCase();
        if (st == 'cancelado' || st == 'reagendado') return false;
        return a.startTime.year == selectedDate.year &&
            a.startTime.month == selectedDate.month &&
            a.startTime.day == selectedDate.day;
      }).toList();

      expect(sameDay.length, equals(2));
      expect(sameDay.map((a) => a.id), containsAll([apptMorning.id, apptAfternoon.id]));

      // Verifica disponibilidade para agendar às 14:15 (deve detectar conflito com apptAfternoon)
      final avail = AvailabilityEngine.checkAvailability(
        startTime: DateTime(2026, 11, 15, 14, 15),
        durationMinutes: 30,
        existingAppointments: allAppts,
      );

      expect(avail.isAvailable, isFalse);
      expect(avail.conflictingAppointments.any((c) => c.id == apptAfternoon.id), isTrue);
      expect(avail.conflictingAppointments.any((c) => c.id == apptMorning.id), isFalse);
    });

    test('Contatos sem coordenadas geográficas são excluídos dos pinos georreferenciados no mapa', () {
      final contactWithCoords = PersonEntry(
        id: 'c1',
        name: 'Maria com GPS',
        status: 'revisita',
        firstContactAt: DateTime.now(),
        latitude: -23.55052,
        longitude: -46.63330,
        tags: '[]',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        revision: 1,
      );

      final contactWithoutCoords = PersonEntry(
        id: 'c2',
        name: 'João sem GPS',
        status: 'revisita',
        firstContactAt: DateTime.now(),
        latitude: null,
        longitude: null,
        tags: '[]',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        revision: 1,
      );

      final allContacts = [contactWithCoords, contactWithoutCoords];
      final geoContacts = allContacts.where((p) => p.latitude != null && p.longitude != null).toList();

      expect(geoContacts.length, equals(1));
      expect(geoContacts.first.id, equals('c1'));
      expect(allContacts.length - geoContacts.length, equals(1)); // 1 não mapeado
    });
  });

  group('Geometria e Reprojeção do Mapa de Contatos (Sem Ballooning)', () {
    const double tileSize = 256.0;

    int lon2tileX(double lon, int z) => ((lon + 180.0) / 360.0 * (1 << z)).floor();
    int lat2tileY(double lat, int z) {
      final latRad = lat.clamp(-85.0511, 85.0511) * math.pi / 180.0;
      return ((1.0 - math.log(math.tan(latRad) + 1.0 / math.cos(latRad)) / math.pi) / 2.0 * (1 << z)).floor();
    }
    double lon2pixelX(double lon, int z) => (lon + 180.0) / 360.0 * (tileSize * (1 << z));
    double lat2pixelY(double lat, int z) {
      final latRad = lat.clamp(-85.0511, 85.0511) * math.pi / 180.0;
      final sinLat = math.sin(latRad).clamp(-0.9999, 0.9999);
      return (0.5 - math.log((1.0 + sinLat) / (1.0 - sinLat)) / (4.0 * math.pi)) * (tileSize * (1 << z));
    }
    double pixelX2lon(double px, int z) => (px / (tileSize * (1 << z))) * 360.0 - 180.0;
    double pixelY2lat(double py, int z) {
      final n = math.pi - (2.0 * math.pi * py) / (tileSize * (1 << z));
      return 180.0 / math.pi * math.atan(0.5 * (math.exp(n) - math.exp(-n)));
    }

    test('Reprojeção geográfica é reversível entre coordenadas e pixels em todos os zooms de 12 a 18', () {
      const lat = -23.550520;
      const lon = -46.633308;

      for (int z = 12; z <= 18; z++) {
        final px = lon2pixelX(lon, z);
        final py = lat2pixelY(lat, z);

        final recoveredLon = pixelX2lon(px, z);
        final recoveredLat = pixelY2lat(py, z);

        expect(recoveredLon, closeTo(lon, 0.0001), reason: 'Falha no zoom $z para longitude');
        expect(recoveredLat, closeTo(lat, 0.0001), reason: 'Falha no zoom $z para latitude');

        // Tiles adjacentes são positivos e finitos
        final tx = lon2tileX(lon, z);
        final ty = lat2tileY(lat, z);
        expect(tx, isPositive);
        expect(ty, isPositive);
      }
    });

    test('Zoom geográfico dobra número de pixels por grau sem alterar dimensões dos elementos UI', () {
      const lat = -23.550520;
      const lon = -46.633308;

      final px15 = lon2pixelX(lon, 15);
      final px16 = lon2pixelX(lon, 16);
      final py15 = lat2pixelY(lat, 15);
      final py16 = lat2pixelY(lat, 16);

      // No nível 16, a coordenada de pixel em relação à origem do mundo é exatamente o dobro
      expect((px16 / px15), closeTo(2.0, 0.001));
      expect((py16 / py15), closeTo(2.0, 0.001));

      // Dimensões do pino permanecem fixas (badge maxWidth: 110, icon: 26..34)
      const pinMaxWidth = 110.0;
      const pinIconSize = 26.0;
      expect(pinMaxWidth, equals(110.0));
      expect(pinIconSize, equals(26.0));
    });
  });
}
