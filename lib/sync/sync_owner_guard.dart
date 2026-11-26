import 'package:drift/drift.dart' as drift;

import '../database/app_database.dart';

enum SyncOwnerGuardStatus {
  allowed,
  unauthenticated,
  demoModeActive,
  ownerMismatch,
}

enum AccountWorkspacePreparationStatus {
  ready,
  switchedCleanly,
  requiresConfirmationDueToUnsyncedData,
}

class AccountWorkspacePreparationResult {
  final AccountWorkspacePreparationStatus status;
  final String? previousOwnerId;
  final int pendingUnsyncedCount;

  const AccountWorkspacePreparationResult({
    required this.status,
    this.previousOwnerId,
    this.pendingUnsyncedCount = 0,
  });

  bool get isReady =>
      status == AccountWorkspacePreparationStatus.ready ||
      status == AccountWorkspacePreparationStatus.switchedCleanly;
}

class SyncOwnerGuardDecision {
  final SyncOwnerGuardStatus status;
  final String? activeUserId;
  final String? boundOwnerId;
  final String message;

  const SyncOwnerGuardDecision({
    required this.status,
    required this.message,
    this.activeUserId,
    this.boundOwnerId,
  });

  bool get isAllowed => status == SyncOwnerGuardStatus.allowed;
}

/// Guarda centralizado de propriedade de conta e isolamento local (FA-SEC-04).
/// Deve ser consultado antes de qualquer operação de leitura/escrita remota.
class SyncOwnerGuard {
  SyncOwnerGuard._();

  static const String ownerKvKey = 'automatic_sync_owner_id';
  static const String demoModeKvKey = 'demo_mode';
  static const String offlineModeKvKey = 'offline_mode_enabled';

  static const List<String> _legacyDemoPersonNames = [
    'Maria Oliveira (Demo)',
    'Carlos Pereira (Demo)',
    'Luciana Martins (Demo)',
    'Beatriz Martins (Demo)',
    'Beatriz Martins (Demo - Filha)',
  ];

  static const List<String> _legacyDemoAppointmentTitles = [
    'Estudo Bíblico - Maria',
    'Revisita - Carlos',
  ];

  /// Lê o `owner_id` atualmente vinculado ao banco SQLite local.
  static Future<String?> getBoundOwnerId(AppDatabase db) async {
    final row = await (db.select(
      db.appKvStore,
    )..where((t) => t.key.equals(ownerKvKey))).getSingleOrNull();
    final value = row?.value.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  /// Vincula explicitamente o banco local a um `ownerId` quando ainda não há dono.
  /// Falha fechada caso já exista vínculo com outra conta.
  static Future<void> bindOwnerId(AppDatabase db, String ownerId) async {
    final clean = ownerId.trim();
    if (clean.isEmpty) {
      throw ArgumentError.value(ownerId, 'ownerId', 'ownerId vazio.');
    }
    await db.transaction(() async {
      final existing = await getBoundOwnerId(db);
      if (existing != null && existing != clean) {
        throw StateError(
          'Banco local já pertence a outra conta ($existing). '
          'Execute troca explícita de conta antes de vincular $clean.',
        );
      }
      if (existing == null) {
        await db
            .into(db.appKvStore)
            .insertOnConflictUpdate(
              AppKvStoreCompanion.insert(
                key: ownerKvKey,
                value: clean,
                updatedAt: drift.Value(DateTime.now()),
              ),
            );
      }
    });
  }

  static Future<bool> _hasDemoDataMarkers(AppDatabase db) async {
    final demoKv = await (db.select(
      db.appKvStore,
    )..where((t) => t.key.equals(demoModeKvKey))).getSingleOrNull();
    if (demoKv?.value == 'true') return true;

    final peoplePlaceholders = List.filled(
      _legacyDemoPersonNames.length,
      '?',
    ).join(', ');
    final demoPeople = await db
        .customSelect(
          'SELECT 1 FROM people WHERE name IN ($peoplePlaceholders) LIMIT 1',
          variables: [
            for (final name in _legacyDemoPersonNames)
              drift.Variable.withString(name),
          ],
        )
        .get();
    if (demoPeople.isNotEmpty) return true;

    final apptPlaceholders = List.filled(
      _legacyDemoAppointmentTitles.length,
      '?',
    ).join(', ');
    final demoAppts = await db
        .customSelect(
          'SELECT 1 FROM appointments WHERE title IN ($apptPlaceholders) LIMIT 1',
          variables: [
            for (final title in _legacyDemoAppointmentTitles)
              drift.Variable.withString(title),
          ],
        )
        .get();
    return demoAppts.isNotEmpty;
  }

  /// Avalia se [authenticatedUserId] tem autorização para sincronizar com este banco local.
  static Future<SyncOwnerGuardDecision> evaluate({
    required AppDatabase db,
    required String? authenticatedUserId,
    bool bindIfUnbound = true,
  }) async {
    final cleanUid = authenticatedUserId?.trim();
    if (cleanUid == null || cleanUid.isEmpty) {
      return const SyncOwnerGuardDecision(
        status: SyncOwnerGuardStatus.unauthenticated,
        message: 'Sincronização bloqueada: nenhuma conta autenticada ativa.',
      );
    }

    if (await _hasDemoDataMarkers(db)) {
      return SyncOwnerGuardDecision(
        status: SyncOwnerGuardStatus.demoModeActive,
        activeUserId: cleanUid,
        message: 'Sincronização bloqueada: modo de demonstração ativo. Dados demo nunca são enviados para a nuvem.',
      );
    }

    final boundOwner = await getBoundOwnerId(db);
    if (boundOwner != null && boundOwner != cleanUid) {
      return SyncOwnerGuardDecision(
        status: SyncOwnerGuardStatus.ownerMismatch,
        activeUserId: cleanUid,
        boundOwnerId: boundOwner,
        message: 'Sincronização bloqueada por isolamento de contas: os dados locais pertencem a outra conta.',
      );
    }

    if (boundOwner == null && bindIfUnbound) {
      await bindOwnerId(db, cleanUid);
    }

    return SyncOwnerGuardDecision(
      status: SyncOwnerGuardStatus.allowed,
      activeUserId: cleanUid,
      boundOwnerId: boundOwner ?? cleanUid,
      message: 'Proprietário verificado.',
    );
  }

  /// Prepara o workspace SQLite local para [authenticatedUserId] ao concluir login
  /// (FA-SEC-04). Se o dispositivo pertencia a outra conta:
  /// - Quando não há operações locais não sincronizadas (ou [discardUnsyncedIfSwitching] == true),
  ///   isola atomicamente o workspace para a nova conta.
  /// - Quando há alterações não sincronizadas da conta anterior e não houve confirmação explícita,
  ///   falha fechado retornando [AccountWorkspacePreparationStatus.requiresConfirmationDueToUnsyncedData]
  ///   para nunca descartar silenciosamente dados pendentes do usuário anterior.
  static Future<AccountWorkspacePreparationResult>
  prepareWorkspaceForAuthenticatedAccount({
    required AppDatabase db,
    required String authenticatedUserId,
    bool discardUnsyncedIfSwitching = false,
  }) async {
    final cleanUid = authenticatedUserId.trim();
    if (cleanUid.isEmpty) {
      throw ArgumentError.value(
        authenticatedUserId,
        'authenticatedUserId',
        'authenticatedUserId vazio.',
      );
    }

    final boundOwner = await getBoundOwnerId(db);
    if (boundOwner == null || boundOwner == cleanUid) {
      return const AccountWorkspacePreparationResult(
        status: AccountWorkspacePreparationStatus.ready,
      );
    }

    final unsyncedOps =
        await (db.select(db.syncQueue)..where(
              (t) =>
                  t.status.equals('pending') |
                  t.status.equals('in_progress') |
                  t.status.equals('conflict') |
                  t.status.equals('failed'),
            ))
            .get();

    if (unsyncedOps.isNotEmpty && !discardUnsyncedIfSwitching) {
      return AccountWorkspacePreparationResult(
        status: AccountWorkspacePreparationStatus
            .requiresConfirmationDueToUnsyncedData,
        previousOwnerId: boundOwner,
        pendingUnsyncedCount: unsyncedOps.length,
      );
    }

    await resetLocalWorkspaceForAccountSwitch(db: db, newOwnerId: cleanUid);
    return AccountWorkspacePreparationResult(
      status: AccountWorkspacePreparationStatus.switchedCleanly,
      previousOwnerId: boundOwner,
      pendingUnsyncedCount: unsyncedOps.length,
    );
  }

  /// Limpa atomicamente os dados locais operacionais, fila e cursores para iniciar
  /// sessão limpa com [newOwnerId], preservando os dados remotos da conta anterior.
  static Future<void> resetLocalWorkspaceForAccountSwitch({
    required AppDatabase db,
    required String newOwnerId,
  }) async {
    final cleanNewOwner = newOwnerId.trim();
    if (cleanNewOwner.isEmpty) {
      throw ArgumentError.value(newOwnerId, 'newOwnerId', 'newOwnerId vazio.');
    }

    await db.transaction(() async {
      // Limpa tabelas filhas primeiro para respeitar PRAGMA foreign_keys = ON
      await db.delete(db.calendarEventLinks).go();
      await db.delete(db.externalCalendarEvents).go();
      await db.delete(db.studySessions).go();
      await db.delete(db.studyParticipants).go();
      await db.delete(db.studentManualOrder).go();
      await db.delete(db.visits).go();
      await db.delete(db.appointments).go();
      await db.delete(db.voiceNotes).go();
      await db.delete(db.familyTies).go();
      await db.delete(db.personPhotos).go();
      await db.delete(db.personPublications).go();
      await db.delete(db.bibleStudies).go();
      await db.delete(db.people).go();
      await db.delete(db.phoneContacts).go();
      await db.delete(db.activityRecords).go();
      await db.delete(db.territoryLandmarks).go();
      await db.delete(db.territorySectors).go();
      await db.delete(db.ministryExperiences).go();
      await db.delete(db.researchArticles).go();
      await db.delete(db.researchTags).go();
      await db.delete(db.inboxEntries).go();
      await db.delete(db.emailAccounts).go();
      await db.delete(db.knowledgeLinks).go();
      await db.delete(db.knowledgeAreas).go();
      await db.delete(db.tasks).go();
      await db.delete(db.projects).go();
      await db.delete(db.knowledgeNotes).go();
      await db.delete(db.knowledgeQuestions).go();
      await db.delete(db.knowledgeDocuments).go();
      await db.delete(db.knowledgeResources).go();
      await db.delete(db.syncQueue).go();

      // Tabelas Ticuna criadas via SQL customizado (limpa apenas se existirem)
      for (final rawTable in [
        'ticuna_words',
        'ticuna_phrases',
        'ticuna_tags',
      ]) {
        final exists = await db
            .customSelect(
              "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
              variables: [drift.Variable.withString(rawTable)],
            )
            .get();
        if (exists.isNotEmpty) {
          await db.customStatement('DELETE FROM $rawTable');
        }
      }

      // Remove cursores, checkpoints E2EE, pendências de download e flags de sessão
      await (db.delete(db.appKvStore)..where(
            (t) =>
                t.key.like('last_synced_at_%') |
                t.key.like('e2ee_%') |
                t.key.like('pending_audio_download_%') |
                t.key.like('pending_ticuna_audio_download_%') |
                t.key.like('pending_doc_download_%') |
                t.key.like('pending_photo_download_%') |
                t.key.like('pending_inbox_meta_download_%') |
                t.key.like('doc_bytes_%') |
                t.key.equals(demoModeKvKey) |
                t.key.equals(offlineModeKvKey),
          ))
          .go();

      await db
          .into(db.appKvStore)
          .insertOnConflictUpdate(
            AppKvStoreCompanion.insert(
              key: ownerKvKey,
              value: cleanNewOwner,
              updatedAt: drift.Value(DateTime.now()),
            ),
          );
    });
  }
}
