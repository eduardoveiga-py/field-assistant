import 'package:drift/drift.dart';

// Tabelas do Banco de Dados Local Drift

@DataClassName('PersonEntry')
class People extends Table {
  TextColumn get id => text()(); // UUID v4
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get address => text().nullable()();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  DateTimeColumn get firstContactAt => dateTime()();
  TextColumn get status => text().withDefault(const Constant('interessado'))(); // interessado, revisita, estudo, outro
  TextColumn get preferredSchedule => text().nullable()();
  TextColumn get generalNotes => text().nullable()();
  TextColumn get contactRestrictions => text().nullable()();
  TextColumn get tags => text().withDefault(const Constant('[]'))(); // JSON array
  DateTimeColumn get lastContactAt => dateTime().nullable()();
  DateTimeColumn get nextActionAt => dateTime().nullable()();
  TextColumn get nextActionNote => text().nullable()();

  // Auditoria e sincronização
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get revision => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('VisitEntry')
class Visits extends Table {
  TextColumn get id => text()(); // UUID v4
  TextColumn get personId => text().references(People, #id)();
  DateTimeColumn get dateTimeField => dateTime()();
  TextColumn get contactType => text()(); // conversa_inicial, revisita, estudo, tentativa_sem_contato, contato_telefonico, outro
  TextColumn get result => text()();
  TextColumn get notes => text().nullable()();
  TextColumn get topicsDiscussed => text().nullable()();
  TextColumn get scriptureOrPub => text().nullable()();
  TextColumn get expressedQuestion => text().nullable()();
  TextColumn get nextStep => text().nullable()();
  DateTimeColumn get suggestedReturnDate => dateTime().nullable()();
  TextColumn get appointmentId => text().nullable()();

  // Auditoria e sincronização
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get revision => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('BibleStudyEntry')
class BibleStudies extends Table {
  TextColumn get id => text()(); // UUID v4
  TextColumn get title => text()();
  TextColumn get ownerId => text().withDefault(const Constant('local_user'))();
  DateTimeColumn get startedAt => dateTime()();
  TextColumn get status => text().withDefault(const Constant('ativo'))(); // ativo, pausado, concluido, encerrado
  TextColumn get publicationId => text()(); // lff-book, lff-brochure
  TextColumn get language => text().withDefault(const Constant('pt'))(); // pt, tca, bzs
  IntColumn get currentLesson => integer().nullable()();
  IntColumn get currentParagraph => integer().nullable()();
  TextColumn get manualReference => text().nullable()();
  TextColumn get frequency => text().withDefault(const Constant('semanal'))(); // semanal, quinzenal, mensal, personalizada
  TextColumn get learningGoals => text().nullable()();
  TextColumn get pendingDoubts => text().nullable()();
  TextColumn get nextTopic => text().nullable()();
  TextColumn get pauseOrCloseReason => text().nullable()();
  DateTimeColumn get lastSessionAt => dateTime().nullable()();
  DateTimeColumn get nextPlannedAt => dateTime().nullable()();

  // Auditoria e sincronização
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get revision => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('StudyParticipantEntry')
class StudyParticipants extends Table {
  TextColumn get id => text()(); // UUID v4
  TextColumn get studyId => text().references(BibleStudies, #id)();
  TextColumn get personId => text().references(People, #id)();
  BoolColumn get isPrimary => boolean().withDefault(const Constant(false))();

  // Auditoria e sincronização
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get revision => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('StudySessionEntry')
class StudySessions extends Table {
  TextColumn get id => text()(); // UUID v4
  TextColumn get studyId => text().references(BibleStudies, #id)();
  DateTimeColumn get dateTimeField => dateTime()();
  TextColumn get publicationCode => text().nullable()();
  IntColumn get lessonCovered => integer().nullable()();
  TextColumn get paragraphsCovered => text().nullable()();
  TextColumn get sessionNotes => text().nullable()();
  TextColumn get pendingQuestions => text().nullable()();
  TextColumn get nextStep => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('realizada'))(); // realizada, cancelada, nao_realizada
  TextColumn get participantIds => text().withDefault(const Constant('[]'))(); // JSON array

  // Auditoria e sincronização
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get revision => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('AppointmentEntry')
class Appointments extends Table {
  TextColumn get id => text()(); // UUID v4
  TextColumn get personId => text().nullable().references(People, #id)();
  TextColumn get studyId => text().nullable().references(BibleStudies, #id)();
  TextColumn get title => text()();
  DateTimeColumn get startTime => dateTime()();
  DateTimeColumn get endTime => dateTime()();
  IntColumn get durationMinutes => integer().withDefault(const Constant(30))();
  TextColumn get status => text().withDefault(const Constant('planejado'))(); // planejado, confirmado, realizado, cancelado, nao_realizado, reagendado, provisorio
  TextColumn get previousAppointmentId => text().nullable()();
  TextColumn get locationNotes => text().nullable()();
  IntColumn get reminderMinutesBefore => integer().nullable()();
  IntColumn get secondReminderMinutesBefore => integer().nullable()();
  BoolColumn get isProvisional => boolean().withDefault(const Constant(false))();

  // Auditoria e sincronização
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get revision => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ActivityRecordEntry')
class ActivityRecords extends Table {
  TextColumn get id => text()(); // UUID v4
  DateTimeColumn get date => dateTime()();
  IntColumn get durationSeconds => integer()();
  TextColumn get modality => text()(); // campo, testemunho_publico, informal, carta_telefone, outro
  TextColumn get notes => text().nullable()();

  // Auditoria e sincronização
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get revision => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SyncQueueEntry')
class SyncQueue extends Table {
  TextColumn get id => text()(); // UUID v4
  TextColumn get entityType => text()(); // people, visits, bible_studies, study_participants, study_sessions, appointments, activity_records
  TextColumn get entityId => text()();
  TextColumn get operation => text()(); // INSERT, UPDATE, DELETE
  TextColumn get payload => text()(); // JSON string
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('pending'))(); // pending, in_progress, synced, conflict, failed

  @override
  Set<Column> get primaryKey => {id};
}
