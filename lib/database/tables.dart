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
  TextColumn get status => text().withDefault(
    const Constant('interessado'),
  )(); // interessado, revisita, estudo, outro
  TextColumn get preferredSchedule => text().nullable()();
  TextColumn get generalNotes => text().nullable()();
  TextColumn get contactRestrictions => text().nullable()();
  TextColumn get tags =>
      text().withDefault(const Constant('[]'))(); // JSON array
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
  TextColumn get status => text().withDefault(
    const Constant('ativo'),
  )(); // ativo, pausado, concluido, encerrado
  TextColumn get publicationId => text()(); // lff-book, lff-brochure
  TextColumn get language =>
      text().withDefault(const Constant('pt'))(); // pt, tca, bzs
  IntColumn get currentLesson => integer().nullable()();
  IntColumn get currentParagraph => integer().nullable()();
  TextColumn get manualReference => text().nullable()();
  TextColumn get frequency => text().withDefault(
    const Constant('semanal'),
  )(); // semanal, quinzenal, mensal, personalizada
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
  TextColumn get status => text().withDefault(
    const Constant('realizada'),
  )(); // realizada, cancelada, nao_realizada
  TextColumn get participantIds =>
      text().withDefault(const Constant('[]'))(); // JSON array

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
  BoolColumn get isProvisional =>
      boolean().withDefault(const Constant(false))();
  TextColumn get taskId => text().nullable().named('task_id')();

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
  TextColumn get modality =>
      text()(); // campo, testemunho_publico, informal, carta_telefone, outro
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
  DateTimeColumn get lastAttemptAt =>
      dateTime().nullable().named('last_attempt_at')();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  TextColumn get status => text().withDefault(
    const Constant('pending'),
  )(); // pending, in_progress, synced, conflict, failed

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('VoiceNoteEntry')
class VoiceNotes extends Table {
  TextColumn get id => text()(); // UUID v4
  TextColumn get personId => text().references(People, #id)();
  TextColumn get visitId => text().nullable().references(Visits, #id)();
  TextColumn get studyId => text().nullable().references(BibleStudies, #id)();
  TextColumn get audioFilePath => text().nullable()();
  IntColumn get audioDurationSeconds =>
      integer().withDefault(const Constant(0))();
  TextColumn get transcription => text()();
  IntColumn get detectedLesson => integer().nullable()();
  IntColumn get detectedPoint => integer().nullable()();
  TextColumn get extractedPendingDoubt => text().nullable()();
  TextColumn get extractedEmpathyNote => text().nullable()();

  // Auditoria e sincronização
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get revision => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PhoneContactEntry')
class PhoneContacts extends Table {
  TextColumn get id => text()(); // UUID v4
  TextColumn get name => text()();
  TextColumn get phone => text()();
  TextColumn get secondaryPhone => text().nullable()();
  BoolColumn get hasWhatsapp => boolean().withDefault(const Constant(false))();
  TextColumn get whatsappInfo => text().nullable()();
  BoolColumn get hasSocial => boolean().withDefault(const Constant(false))();
  TextColumn get socialPlatform => text().nullable()();
  TextColumn get socialHandle => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get tags => text().withDefault(const Constant('[]'))();
  TextColumn get origin => text().withDefault(const Constant('Informal'))();
  TextColumn get convertedPersonId =>
      text().nullable().references(People, #id)();

  // Auditoria e sincronização
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get revision => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('TerritoryLandmarkEntry')
class TerritoryLandmarks extends Table {
  TextColumn get id => text()(); // UUID v4
  TextColumn get name => text()();
  TextColumn get category => text()();
  TextColumn get address => text().nullable()();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  TextColumn get notes => text().nullable()();

  // Auditoria e sincronização
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get revision => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('AppKvEntry')
class AppKvStore extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {key};
}

@DataClassName('FamilyTieEntry')
class FamilyTies extends Table {
  TextColumn get id => text()(); // UUID v4
  TextColumn get personId => text().named('person_id')();
  TextColumn get relatedPersonId =>
      text().nullable().named('related_person_id')();
  TextColumn get relatedPersonName => text().named('related_person_name')();
  TextColumn get relationshipType => text().named('relationship_type')();

  // Auditoria e sincronização
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().nullable().named('updated_at')();
  DateTimeColumn get deletedAt => dateTime().nullable().named('deleted_at')();
  IntColumn get revision => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('MinistryExperienceEntry')
class MinistryExperiences extends Table {
  TextColumn get id => text()(); // UUID v4
  TextColumn get title => text()();
  TextColumn get content => text()();
  TextColumn get mediaUrls =>
      text().withDefault(const Constant('[]')).named('media_urls')();
  TextColumn get tags => text().withDefault(const Constant('[]'))();
  DateTimeColumn get dateTimeField => dateTime().named('date_time')();
  TextColumn get locationOrModality =>
      text().nullable().named('location_or_modality')();

  // Auditoria e sincronização
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();
  DateTimeColumn get deletedAt => dateTime().nullable().named('deleted_at')();
  IntColumn get revision => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PersonPhotoEntry')
class PersonPhotos extends Table {
  TextColumn get id => text()(); // UUID v4
  TextColumn get personId => text().named('person_id')();
  TextColumn get photoType => text().named('photo_type')();
  TextColumn get imageData => text().named('image_data')();

  // Auditoria e sincronização
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().nullable().named('updated_at')();
  DateTimeColumn get deletedAt => dateTime().nullable().named('deleted_at')();
  IntColumn get revision => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PersonPublicationEntry')
class PersonPublications extends Table {
  TextColumn get id => text()(); // UUID v4
  TextColumn get personId => text().named('person_id')();
  TextColumn get publicationTitle => text().named('publication_title')();
  TextColumn get itemType => text().named('item_type')();
  TextColumn get status => text()();
  TextColumn get date => text()();
  TextColumn get notes => text().nullable()();

  // Auditoria e sincronização
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().nullable().named('updated_at')();
  DateTimeColumn get deletedAt => dateTime().nullable().named('deleted_at')();
  IntColumn get revision => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ResearchArticleEntry')
class ResearchArticles extends Table {
  TextColumn get id => text()(); // UUID v4
  TextColumn get title => text()();
  TextColumn get summary => text()();
  TextColumn get content => text()();
  TextColumn get tags => text().withDefault(const Constant('[]'))();
  TextColumn get attachments => text().withDefault(const Constant('[]'))();
  TextColumn get objective => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('active'))();
  TextColumn get conclusion => text().nullable()();
  TextColumn get projectId => text().nullable().named('project_id')();
  TextColumn get mainQuestionId => text().nullable().named('main_question_id')();

  // Auditoria e sincronização
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();
  DateTimeColumn get deletedAt => dateTime().nullable().named('deleted_at')();
  IntColumn get revision => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ResearchTagEntry')
class ResearchTags extends Table {
  TextColumn get id => text()(); // UUID v4
  TextColumn get name => text()();

  // Auditoria e sincronização
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().nullable().named('updated_at')();
  DateTimeColumn get deletedAt => dateTime().nullable().named('deleted_at')();
  IntColumn get revision => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('TerritorySectorEntry')
class TerritorySectors extends Table {
  TextColumn get id => text()(); // UUID v4
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();

  // Auditoria e sincronização
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().nullable().named('updated_at')();
  DateTimeColumn get deletedAt => dateTime().nullable().named('deleted_at')();
  IntColumn get revision => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('StudentManualOrderEntry')
class StudentManualOrder extends Table {
  TextColumn get studyId => text().named('study_id')();
  IntColumn get manualIndex => integer().named('manual_index')();

  // Auditoria e sincronização
  DateTimeColumn get updatedAt => dateTime().nullable().named('updated_at')();
  DateTimeColumn get deletedAt => dateTime().nullable().named('deleted_at')();
  IntColumn get revision => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {studyId};
}

@DataClassName('ExternalCalendarEventEntry')
class ExternalCalendarEvents extends Table {
  TextColumn get id => text()(); // UUID v4
  TextColumn get provider => text()(); // google, apple_eventkit, ical_url
  TextColumn get externalAccount =>
      text().nullable().named('external_account')();
  TextColumn get calendarId => text().named('calendar_id')();
  TextColumn get externalEventId => text().named('external_event_id')();
  TextColumn get iCalUid => text().nullable().named('ical_uid')();
  TextColumn get title => text()();
  TextColumn get location => text().nullable()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get startTime => dateTime().named('start_time')();
  DateTimeColumn get endTime => dateTime().named('end_time')();
  TextColumn get timeZone => text().nullable().named('time_zone')();
  BoolColumn get isAllDay =>
      boolean().withDefault(const Constant(false)).named('is_all_day')();
  TextColumn get externalStatus => text().nullable().named('external_status')();
  DateTimeColumn get lastModifiedExternal =>
      dateTime().nullable().named('last_modified_external')();
  DateTimeColumn get lastSyncedAt =>
      dateTime().nullable().named('last_synced_at')();
  BoolColumn get isDeletedExternal => boolean()
      .withDefault(const Constant(false))
      .named('is_deleted_external')();
  TextColumn get metadata => text().nullable()(); // JSON
  TextColumn get etag => text().nullable()();

  // Auditoria e sincronização
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();
  DateTimeColumn get deletedAt => dateTime().nullable().named('deleted_at')();
  IntColumn get revision => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('CalendarEventLinkEntry')
class CalendarEventLinks extends Table {
  TextColumn get id => text()(); // UUID v4
  TextColumn get appointmentId => text().named('appointment_id')();
  TextColumn get externalEventId => text().named('external_event_id')();
  TextColumn get provider => text()(); // google, apple_eventkit
  TextColumn get syncStatus => text()
      .withDefault(const Constant('synced'))
      .named(
        'sync_status',
      )(); // synced, pending_upload, pending_download, conflict, failed
  TextColumn get lastError => text().nullable().named('last_error')();
  IntColumn get localRevisionAtSync => integer()
      .withDefault(const Constant(1))
      .named('local_revision_at_sync')();
  TextColumn get externalETagAtSync =>
      text().nullable().named('external_etag_at_sync')();
  TextColumn get pendingResolution =>
      text().nullable().named('pending_resolution')();

  // Auditoria e sincronização
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();
  DateTimeColumn get deletedAt => dateTime().nullable().named('deleted_at')();
  IntColumn get revision => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('AppLanguageEntry')
class AppLanguages extends Table {
  TextColumn get id => text()(); // UUID v4 ou code (ex: 'tca', 'gub', 'yan')
  TextColumn get name => text()(); // ex: 'Ticuna (Magüta)', 'Guajajara (Tenetehara)'
  TextColumn get code => text()(); // ISO 639-3 (ex: 'tca')
  TextColumn get symbol => text()(); // Emoji/ícone (ex: '🏹', '🌿')
  TextColumn get diacritics =>
      text().withDefault(const Constant('[]'))(); // JSON array com caracteres especiais
  BoolColumn get isDefault =>
      boolean().withDefault(const Constant(false)).named('is_default')();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  @override
  Set<Column> get primaryKey => {id};
}

// ==========================================
// MÓDULO A — INBOX UNIVERSAL
// ==========================================
@DataClassName('InboxEntry')
class InboxEntries extends Table {
  TextColumn get id => text()(); // UUID v4
  TextColumn get content => text()();
  TextColumn get sourceType =>
      text().withDefault(const Constant('text')).named('source_type')(); // text, audio, image, file, link, share
  TextColumn get mediaPath => text().nullable().named('media_path')();
  IntColumn get mediaDurationSeconds =>
      integer().nullable().named('media_duration_seconds')();
  TextColumn get attachments =>
      text().withDefault(const Constant('[]'))(); // JSON array
  TextColumn get status =>
      text().withDefault(const Constant('unprocessed'))(); // unprocessed, in_review, converted, archived
  TextColumn get suggestedCategory =>
      text().nullable().named('suggested_category')();
  TextColumn get convertedEntityType =>
      text().nullable().named('converted_entity_type')(); // task, project, note, question, research, document, resource, person
  TextColumn get convertedEntityId =>
      text().nullable().named('converted_entity_id')();
  DateTimeColumn get capturedAt => dateTime().named('captured_at')();
  DateTimeColumn get processedAt =>
      dateTime().nullable().named('processed_at')();
  TextColumn get metadata =>
      text().withDefault(const Constant('{}'))(); // JSON

  // Auditoria e sincronização
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();
  DateTimeColumn get deletedAt => dateTime().nullable().named('deleted_at')();
  IntColumn get revision => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

// ==========================================
// MÓDULO B — TAREFAS E PROJETOS
// ==========================================
@DataClassName('ProjectEntry')
class Projects extends Table {
  TextColumn get id => text()(); // UUID v4
  TextColumn get name => text()();
  TextColumn get objective => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get category =>
      text().withDefault(const Constant('ministry'))(); // ministry, tech, personal, research, linguistic
  TextColumn get status =>
      text().withDefault(const Constant('active'))(); // planning, active, paused, completed, archived
  TextColumn get colorHex => text().nullable().named('color_hex')();
  TextColumn get iconName => text().nullable().named('icon_name')();
  DateTimeColumn get startDate => dateTime().nullable().named('start_date')();
  DateTimeColumn get targetDate => dateTime().nullable().named('target_date')();
  DateTimeColumn get completedAt => dateTime().nullable().named('completed_at')();
  TextColumn get originInboxId => text().nullable().named('origin_inbox_id')();
  TextColumn get metadata =>
      text().withDefault(const Constant('{}'))(); // JSON

  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();
  DateTimeColumn get deletedAt => dateTime().nullable().named('deleted_at')();
  IntColumn get revision => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('TaskEntry')
class Tasks extends Table {
  TextColumn get id => text()(); // UUID v4
  TextColumn get projectId => text().nullable().named('project_id')();
  TextColumn get personId => text().nullable().named('person_id')();
  TextColumn get studyId => text().nullable().named('study_id')();
  TextColumn get sectorId => text().nullable().named('sector_id')();
  TextColumn get originInboxId => text().nullable().named('origin_inbox_id')();
  TextColumn get parentTaskId =>
      text().nullable().named('parent_task_id')(); // Subtarefa hierárquica

  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get status =>
      text().withDefault(const Constant('todo'))(); // todo, in_progress, waiting, completed, cancelled, archived
  TextColumn get priority =>
      text().withDefault(const Constant('normal'))(); // low, normal, high, urgent
  TextColumn get category =>
      text().withDefault(const Constant('ministry'))(); // ministry, tech, personal, research, linguistic

  DateTimeColumn get startDate => dateTime().nullable().named('start_date')();
  DateTimeColumn get dueDate => dateTime().nullable().named('due_date')();
  DateTimeColumn get scheduledAt => dateTime().nullable().named('scheduled_at')();
  IntColumn get durationMinutes =>
      integer().nullable().named('duration_minutes').withDefault(const Constant(30))();
  DateTimeColumn get completedAt => dateTime().nullable().named('completed_at')();

  BoolColumn get isRecurring =>
      boolean().named('is_recurring').withDefault(const Constant(false))();
  TextColumn get recurrenceRule =>
      text().nullable().named('recurrence_rule')(); // daily, weekly, monthly, custom RRULE
  TextColumn get appointmentId =>
      text().nullable().named('appointment_id')();
  TextColumn get attachments =>
      text().withDefault(const Constant('[]'))(); // JSON array
  TextColumn get metadata =>
      text().withDefault(const Constant('{}'))(); // JSON

  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();
  DateTimeColumn get deletedAt => dateTime().nullable().named('deleted_at')();
  IntColumn get revision => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

// ==========================================
// MÓDULO C — BASE DE CONHECIMENTO
// ==========================================
@DataClassName('KnowledgeNoteEntry')
class KnowledgeNotes extends Table {
  TextColumn get id => text()(); // UUID v4
  TextColumn get projectId => text().nullable().named('project_id')();
  TextColumn get personId => text().nullable().named('person_id')();
  TextColumn get studyId => text().nullable().named('study_id')();
  TextColumn get originInboxId => text().nullable().named('origin_inbox_id')();

  TextColumn get title => text()();
  TextColumn get content => text()(); // Markdown format
  TextColumn get category =>
      text().withDefault(const Constant('general'))(); // biblical, ministry, ticuna, tech, personal, general
  TextColumn get tags => text().withDefault(const Constant('[]'))(); // JSON array
  TextColumn get attachments =>
      text().withDefault(const Constant('[]'))(); // JSON array
  TextColumn get sources =>
      text().withDefault(const Constant('[]'))(); // JSON array
  BoolColumn get isPinned =>
      boolean().named('is_pinned').withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();
  DateTimeColumn get deletedAt => dateTime().nullable().named('deleted_at')();
  IntColumn get revision => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('KnowledgeQuestionEntry')
class KnowledgeQuestions extends Table {
  TextColumn get id => text()(); // UUID v4
  TextColumn get projectId => text().nullable().named('project_id')();
  TextColumn get personId => text().nullable().named('person_id')();
  TextColumn get studyId => text().nullable().named('study_id')();
  TextColumn get originInboxId => text().nullable().named('origin_inbox_id')();
  TextColumn get researchArticleId =>
      text().nullable().named('research_article_id')();

  TextColumn get question => text()();
  TextColumn get context => text().nullable()();
  TextColumn get category =>
      text().withDefault(const Constant('biblical'))(); // biblical, ministry, ticuna, tech, personal
  TextColumn get status =>
      text().withDefault(const Constant('unanswered'))(); // unanswered, researching, answered, archived
  TextColumn get answer => text().nullable()();
  DateTimeColumn get answeredAt => dateTime().nullable().named('answered_at')();

  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();
  DateTimeColumn get deletedAt => dateTime().nullable().named('deleted_at')();
  IntColumn get revision => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('KnowledgeDocumentEntry')
class KnowledgeDocuments extends Table {
  TextColumn get id => text()(); // UUID v4
  TextColumn get projectId => text().nullable().named('project_id')();
  TextColumn get researchArticleId =>
      text().nullable().named('research_article_id')();
  TextColumn get personId => text().nullable().named('person_id')();
  TextColumn get sectorId => text().nullable().named('sector_id')();
  TextColumn get originInboxId => text().nullable().named('origin_inbox_id')();

  TextColumn get title => text()();
  TextColumn get fileName => text().named('file_name')();
  TextColumn get fileType =>
      text().named('file_type')(); // pdf, docx, xlsx, image, audio, other
  IntColumn get fileSize => integer().named('file_size')();
  TextColumn get filePath =>
      text().named('file_path')(); // Caminho local relativo seguro
  TextColumn get remoteStoragePath =>
      text().nullable().named('remote_storage_path')(); // Supabase storage
  TextColumn get sha256Checksum =>
      text().nullable().named('sha256_checksum')();
  TextColumn get description => text().nullable()();
  TextColumn get tags => text().withDefault(const Constant('[]'))();
  TextColumn get category => text().withDefault(const Constant('general'))();

  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();
  DateTimeColumn get deletedAt => dateTime().nullable().named('deleted_at')();
  IntColumn get revision => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('KnowledgeResourceEntry')
class KnowledgeResources extends Table {
  TextColumn get id => text()(); // UUID v4
  TextColumn get projectId => text().nullable().named('project_id')();
  TextColumn get researchArticleId =>
      text().nullable().named('research_article_id')();
  TextColumn get personId => text().nullable().named('person_id')();
  TextColumn get originInboxId => text().nullable().named('origin_inbox_id')();

  TextColumn get title => text()();
  TextColumn get resourceType =>
      text().named('resource_type')(); // link, video, jw_publication, tool, reference, template, tutorial, other
  TextColumn get description => text().nullable()();
  TextColumn get url => text().nullable()();
  TextColumn get localAssetPath =>
      text().nullable().named('local_asset_path')();
  TextColumn get tags => text().withDefault(const Constant('[]'))();
  TextColumn get category => text().withDefault(const Constant('general'))();

  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();
  DateTimeColumn get deletedAt => dateTime().nullable().named('deleted_at')();
  IntColumn get revision => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}
