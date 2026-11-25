import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../core/app_logger.dart';
import '../core/biometric_auth_service.dart';
import '../database/app_database.dart';
import 'email_account_model.dart';
import 'email_contacts_manager.dart';
import 'email_html_sanitizer.dart';
import 'exchange_service.dart';
import 'gmail_oauth_service.dart';
import 'jw_email_service.dart';
import 'microsoft_oauth_service.dart';

class EmailSyncResult {
  final int accountsSynced;
  final int totalMessagesSaved;
  final List<String> failedDetails;

  const EmailSyncResult({
    required this.accountsSynced,
    required this.totalMessagesSaved,
    required this.failedDetails,
  });

  bool get hasErrors => failedDetails.isNotEmpty;
}

class EmailMutationResult {
  final int localUpdated;
  final int remoteSynced;
  final int queuedOffline;
  final List<String> warnings;
  final bool hasReadOnlyAccountNotice;

  const EmailMutationResult({
    required this.localUpdated,
    this.remoteSynced = 0,
    this.queuedOffline = 0,
    this.warnings = const [],
    this.hasReadOnlyAccountNotice = false,
  });
}

/// Coordena a sincronização bidirecional multi-protocolo de e-mails
/// (Gmail REST API, Microsoft Graph API, Exchange ActiveSync e IMAP/JW.org)
/// preservando integridade offline, histórico completo de pastas e resposta no servidor.
class EmailSyncCoordinator {
  static const String _rawBytesScrubKey = 'email_rawbytes_scrubbed_v1';
  static const String _pendingRemoteActionsKey =
      'email_pending_remote_actions_v1';

  final AppDatabase db;
  final JwEmailService? jwEmailService;
  final ExchangeReadService? exchangeService;
  final GmailOAuthService? gmailService;
  final MicrosoftOAuthService? microsoftService;

  EmailSyncCoordinator(
    this.db, {
    this.jwEmailService,
    this.exchangeService,
    this.gmailService,
    this.microsoftService,
  });

  /// Remove `rawBytes` serializados por versões anteriores no SQLite/IndexedDB e SyncQueue,
  /// recuperando PWAs congelados por blobs JSON gigantes sem perder mensagens ou `base64`.
  static Future<int> sanitizeLegacyAttachmentBlobs(AppDatabase db) async {
    final marker = await (db.select(
      db.appKvStore,
    )..where((t) => t.key.equals(_rawBytesScrubKey))).getSingleOrNull();
    if (marker?.value == 'done') return 0;

    var cleaned = 0;
    try {
      final bloatedEntries =
          await (db.select(db.inboxEntries)..where(
                (t) =>
                    t.metadata.like('%rawBytes%') |
                    t.attachments.like('%rawBytes%'),
              ))
              .get();

      for (var i = 0; i < bloatedEntries.length; i++) {
        final row = bloatedEntries[i];
        String? nextMeta;
        String? nextAtts;

        if (row.metadata.contains('"rawBytes"')) {
          try {
            final meta = Map<String, dynamic>.from(
              jsonDecode(row.metadata) as Map,
            );
            final emailRaw = meta['email'];
            if (emailRaw is Map) {
              final emailMap = Map<String, dynamic>.from(emailRaw);
              final atts = (emailMap['attachments'] as List<dynamic>?)
                  ?.map((e) => Map<String, dynamic>.from(e as Map))
                  .toList();
              if (atts != null) {
                emailMap['attachments'] =
                    JwEmailMessage.sanitizeAttachmentsForPersistence(atts);
                meta['email'] = emailMap;
                nextMeta = jsonEncode(meta);
              }
            }
          } catch (_) {}
        }

        if (row.attachments.contains('"rawBytes"')) {
          try {
            final decoded = (jsonDecode(row.attachments) as List<dynamic>)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
            nextAtts = jsonEncode(
              JwEmailMessage.sanitizeAttachmentsForPersistence(decoded),
            );
          } catch (_) {}
        }

        if (nextMeta != null || nextAtts != null) {
          await (db.update(
            db.inboxEntries,
          )..where((t) => t.id.equals(row.id))).write(
            InboxEntriesCompanion(
              metadata: nextMeta != null
                  ? drift.Value(nextMeta)
                  : const drift.Value.absent(),
              attachments: nextAtts != null
                  ? drift.Value(nextAtts)
                  : const drift.Value.absent(),
            ),
          );
          cleaned++;
        }

        if (kIsWeb && (i + 1) % 5 == 0) {
          await Future<void>.delayed(Duration.zero);
        }
      }

      final bloatedQueue = await (db.select(
        db.syncQueue,
      )..where((t) => t.payload.like('%rawBytes%'))).get();
      for (var i = 0; i < bloatedQueue.length; i++) {
        final qRow = bloatedQueue[i];
        try {
          final payloadMap = Map<String, dynamic>.from(
            jsonDecode(qRow.payload) as Map,
          );
          var changed = false;
          for (final field in ['attachments', 'metadata']) {
            final val = payloadMap[field];
            if (val is String && val.contains('"rawBytes"')) {
              final inner = jsonDecode(val);
              if (inner is List) {
                payloadMap[field] = jsonEncode(
                  JwEmailMessage.sanitizeAttachmentsForPersistence(
                    inner
                        .map((e) => Map<String, dynamic>.from(e as Map))
                        .toList(),
                  ),
                );
                changed = true;
              } else if (inner is Map && inner['email'] is Map) {
                final emailMap = Map<String, dynamic>.from(
                  inner['email'] as Map,
                );
                final atts = (emailMap['attachments'] as List<dynamic>?)
                    ?.map((e) => Map<String, dynamic>.from(e as Map))
                    .toList();
                if (atts != null) {
                  emailMap['attachments'] =
                      JwEmailMessage.sanitizeAttachmentsForPersistence(atts);
                  final newInner = Map<String, dynamic>.from(inner)
                    ..['email'] = emailMap;
                  payloadMap[field] = jsonEncode(newInner);
                  changed = true;
                }
              }
            }
          }
          if (changed) {
            await (db.update(
              db.syncQueue,
            )..where((t) => t.id.equals(qRow.id))).write(
              SyncQueueCompanion(payload: drift.Value(jsonEncode(payloadMap))),
            );
            cleaned++;
          }
        } catch (_) {}

        if (kIsWeb && (i + 1) % 5 == 0) {
          await Future<void>.delayed(Duration.zero);
        }
      }

      await db
          .into(db.appKvStore)
          .insertOnConflictUpdate(
            AppKvStoreCompanion.insert(
              key: _rawBytesScrubKey,
              value: 'done',
              updatedAt: drift.Value(DateTime.now().toUtc()),
            ),
          );
    } catch (e, st) {
      AppLogger.warning('Falha ao limpar blobs legados de anexos', e, st);
    }
    return cleaned;
  }

  /// Formata exceções de sincronização em mensagens amigáveis e orientativas
  static String friendlyErrorMessage(Object e, [EmailAccount? acc]) {
    final msg = e.toString().toLowerCase();
    final isAuthError =
        e is JwEmailAuthException ||
        msg.contains('401') ||
        msg.contains('auth') ||
        msg.contains('autentica') ||
        msg.contains('expirad') ||
        msg.contains('token') ||
        msg.contains('senha') ||
        msg.contains('credencia');

    final isGmail =
        (acc != null &&
            (acc.incomingProtocol == 'gmail_api' ||
                acc.email.toLowerCase().contains('gmail') ||
                acc.incomingHost.toLowerCase().contains('gmail'))) ||
        msg.contains('gmail');

    final isMicrosoft =
        (acc != null &&
            (acc.incomingProtocol == 'microsoft_graph' ||
                acc.email.toLowerCase().contains('outlook') ||
                acc.email.toLowerCase().contains('hotmail') ||
                acc.incomingHost.toLowerCase().contains('outlook') ||
                acc.incomingHost.toLowerCase().contains('office365'))) ||
        msg.contains('outlook') ||
        msg.contains('hotmail') ||
        msg.contains('office365');

    if (isAuthError) {
      if (acc != null && acc.incomingProtocol == 'gmail_api') {
        return 'Sessão do Gmail expirada ou não autorizada — toque em Reconectar.';
      }
      if (acc != null && acc.incomingProtocol == 'microsoft_graph') {
        return 'Sessão Microsoft expirada ou revogada — toque em Reconectar.';
      }
      if (isGmail) {
        return 'Falha de autenticação (401). No Gmail, use uma Senha de App de 16 dígitos ou OAuth2 se a verificação em duas etapas estiver ativa.';
      }
      if (isMicrosoft) {
        return 'Falha de autenticação (401). No Hotmail/Outlook, configure uma Senha de Aplicativo ou habilite OAuth2/autenticação moderna.';
      }
      return 'Falha de autenticação (verifique usuário e senha).';
    }

    if (e is ExchangeException) {
      return e.message;
    }

    if (e is TimeoutException ||
        msg.contains('timeout') ||
        msg.contains('tempo esgotado')) {
      return 'Tempo limite de conexão esgotado.';
    }

    if (e is JwEmailConnectionException ||
        e.runtimeType.toString() == 'SocketException' ||
        msg.contains('socket') ||
        msg.contains('conexão') ||
        msg.contains('connection')) {
      return 'Falha de conexão. Servidor inacessível ou rede indisponível.';
    }

    final clean = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
    return clean.isNotEmpty ? clean : 'Erro desconhecido ao sincronizar.';
  }

  Future<Set<String>> _loadPendingRemoteMessageIds() async {
    final pending = await _loadPendingRemoteActions();
    return pending
        .map((a) => (a['entryId'] as String?) ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  /// Persiste mensagens sincronizadas no banco local em lotes transacionais,
  /// reconciliando mudanças de leitura/pasta vindas do servidor externo e
  /// evitando gravação de `rawBytes` no SQLite.
  Future<int> persistSyncedMessages(
    List<JwEmailMessage> messages,
    String protocol,
  ) async {
    if (messages.isEmpty) return 0;

    final now = DateTime.now().toUtc();
    final pendingEntryIds = await _loadPendingRemoteMessageIds();
    var savedCount = 0;

    final entryIds = messages
        .map((m) => m.id.startsWith('email_') ? m.id : 'email_${m.id}')
        .toSet()
        .toList();

    final existingById = <String, InboxEntry>{};
    const lookupChunk = 100;
    for (var i = 0; i < entryIds.length; i += lookupChunk) {
      final slice = entryIds.sublist(
        i,
        (i + lookupChunk > entryIds.length) ? entryIds.length : i + lookupChunk,
      );
      final rows = await (db.select(
        db.inboxEntries,
      )..where((t) => t.id.isIn(slice))).get();
      for (final r in rows) {
        existingById[r.id] = r;
      }
    }

    // Mapeia também eventuais e-mails movidos cujo `remoteId` mudou no servidor (ex.: Graph `/move`)
    final movedRemoteLookup = <String, InboxEntry>{};
    final allRowsWithRemoteId = await (db.select(
      db.inboxEntries,
    )..where((t) => t.metadata.like('%"remoteId"%'))).get();
    for (final row in allRowsWithRemoteId) {
      try {
        final meta = jsonDecode(row.metadata) as Map<String, dynamic>;
        final emailRaw = meta['email'];
        if (emailRaw is Map) {
          final remoteId = emailRaw['remoteId']?.toString();
          if (remoteId != null && remoteId.isNotEmpty) {
            movedRemoteLookup[remoteId] = row;
          }
        }
      } catch (_) {}
    }

    const txBatchSize = 25;
    for (var start = 0; start < messages.length; start += txBatchSize) {
      final end = (start + txBatchSize > messages.length)
          ? messages.length
          : start + txBatchSize;
      final chunk = messages.sublist(start, end);

      await db.transaction(() async {
        for (final msg in chunk) {
          final rawKey = msg.id.startsWith('email_')
              ? msg.id.substring(6)
              : msg.id;
          final entryId = 'email_$rawKey';
          final existing = existingById[entryId] ?? movedRemoteLookup[rawKey];

          if (existing != null) {
            if (pendingEntryIds.contains(existing.id)) continue;

            try {
              final existingMeta = existing.metadata.isNotEmpty
                  ? Map<String, dynamic>.from(
                      jsonDecode(existing.metadata) as Map,
                    )
                  : <String, dynamic>{};
              final rawExistingEmail = existingMeta['email'];
              if (rawExistingEmail is! Map) continue;
              final existingEmailMap = Map<String, dynamic>.from(
                rawExistingEmail,
              );

              final existingIsRead =
                  existingEmailMap['isRead'] as bool? ?? false;
              final existingFolder = existingEmailMap['folderName'] as String?;
              final existingFolderId = existingEmailMap['folderId'] as String?;
              final existingIsDraft =
                  existingEmailMap['isDraft'] as bool? ?? false;
              final existingLabels =
                  (existingEmailMap['labels'] as List<dynamic>?)
                      ?.map((e) => e.toString())
                      .toList() ??
                  const <String>[];

              final labelsChanged =
                  msg.labels.isNotEmpty &&
                  !listEquals(existingLabels, msg.labels);
              final readChanged = existingIsRead != msg.isRead;
              final folderChanged =
                  (msg.folderName != null &&
                      msg.folderName != existingFolder) ||
                  (msg.folderId != null && msg.folderId != existingFolderId);
              final draftChanged = existingIsDraft != msg.isDraft;

              if (!readChanged &&
                  !folderChanged &&
                  !draftChanged &&
                  !labelsChanged) {
                continue;
              }

              existingEmailMap['isRead'] = msg.isRead;
              if (msg.folderName != null) {
                existingEmailMap['folderName'] = msg.folderName;
              }
              if (msg.folderId != null) {
                existingEmailMap['folderId'] = msg.folderId;
              }
              existingEmailMap['isDraft'] = msg.isDraft;
              if (msg.labels.isNotEmpty) {
                existingEmailMap['labels'] = msg.labels;
              }
              // Reconciliacao de restauração se o servidor moveu para fora da Lixeira
              final restoredFromTrash =
                  existing.deletedAt != null &&
                  msg.folderName != null &&
                  msg.folderName != 'Lixeira';

              existingMeta['email'] = existingEmailMap;
              final updatedMeta = jsonEncode(existingMeta);
              await (db.update(
                db.inboxEntries,
              )..where((t) => t.id.equals(existing.id))).write(
                InboxEntriesCompanion(
                  metadata: drift.Value(updatedMeta),
                  deletedAt: restoredFromTrash
                      ? const drift.Value(null)
                      : const drift.Value.absent(),
                  updatedAt: drift.Value(now),
                  revision: drift.Value(existing.revision + 1),
                ),
              );
              final updatedRow = await (db.select(
                db.inboxEntries,
              )..where((t) => t.id.equals(existing.id))).getSingle();
              await db
                  .into(db.syncQueue)
                  .insert(
                    SyncQueueCompanion.insert(
                      id: const Uuid().v4(),
                      entityType: 'inbox_entries',
                      entityId: existing.id,
                      operation: 'UPDATE',
                      payload: jsonEncode(updatedRow.toJson()),
                      createdAt: now,
                    ),
                  );
            } catch (e, st) {
              AppLogger.warning(
                'Falha ao reconciliar estado remoto para ${existing.id}',
                e,
                st,
              );
            }
            continue;
          }

          final sanitizedMsg = msg.copyWith(
            attachments: JwEmailMessage.sanitizeAttachmentsForPersistence(
              msg.attachments,
            ),
          );
          final metadata = {
            'permanentRetention': true,
            'retentionDate': now.toIso8601String(),
            'email': sanitizedMsg.toJson(),
            'protocol': protocol,
          };

          final isExchange = protocol == 'exchange';
          final category = msg.isHubCommunication
              ? (msg.hubType == 'form'
                    ? 'hub_form'
                    : (msg.hubType == 'letter' ? 'hub_letter' : 'hub_comms'))
              : (isExchange ? 'email_jw' : 'email');

          final sourceType = msg.isHubCommunication
              ? (msg.hubType == 'form' ? 'hub_form' : 'hub_letter')
              : (msg.isDraft ? 'email_draft' : 'email');

          final cleanBody = msg.bodyText.isNotEmpty
              ? EmailHtmlSanitizer.extractPlainText(
                  msg.bodyText,
                  cleanMarkdown: true,
                )
              : (msg.bodyHtml != null
                    ? EmailHtmlSanitizer.extractPlainText(
                        msg.bodyHtml!,
                        cleanMarkdown: true,
                      )
                    : '');

          await db
              .into(db.inboxEntries)
              .insert(
                InboxEntriesCompanion.insert(
                  id: entryId,
                  content: '${msg.subject}\n\n$cleanBody'.trim(),
                  sourceType: drift.Value(sourceType),
                  suggestedCategory: drift.Value(category),
                  attachments: drift.Value(
                    jsonEncode(sanitizedMsg.attachments),
                  ),
                  capturedAt: msg.date.toUtc(),
                  metadata: drift.Value(jsonEncode(metadata)),
                  createdAt: now,
                  updatedAt: now,
                  revision: const drift.Value(1),
                ),
              );

          final inserted = await (db.select(
            db.inboxEntries,
          )..where((t) => t.id.equals(entryId))).getSingle();
          existingById[entryId] = inserted;

          await db
              .into(db.syncQueue)
              .insert(
                SyncQueueCompanion.insert(
                  id: const Uuid().v4(),
                  entityType: 'inbox_entries',
                  entityId: entryId,
                  operation: 'INSERT',
                  payload: jsonEncode(inserted.toJson()),
                  createdAt: now,
                ),
              );

          if (msg.from.isNotEmpty) {
            await EmailContactsManager.recordSender(db, msg.from);
          }

          savedCount++;
        }
      });

      if (kIsWeb && end < messages.length) {
        await Future<void>.delayed(Duration.zero);
      }
    }
    return savedCount;
  }

  Future<Set<String>> _loadKnownRawMessageIds() async {
    final rows =
        await (db.select(db.inboxEntries)..where(
              (t) =>
                  t.deletedAt.isNull() &
                  (t.sourceType.equals('email') |
                      t.sourceType.equals('email_draft') |
                      t.sourceType.equals('hub_letter') |
                      t.sourceType.equals('hub_form')),
            ))
            .get();
    final known = <String>{};
    for (final row in rows) {
      final stripped = row.id.startsWith('email_')
          ? row.id.substring(6)
          : row.id;
      if (stripped.isNotEmpty) known.add(stripped);
      if (row.metadata.isNotEmpty) {
        try {
          final meta = jsonDecode(row.metadata) as Map<String, dynamic>;
          final emailRaw = meta['email'];
          if (emailRaw is Map) {
            final rid = emailRaw['remoteId']?.toString();
            if (rid != null && rid.isNotEmpty) known.add(rid);
            final eid = emailRaw['id']?.toString();
            if (eid != null && eid.isNotEmpty) known.add(eid);
          }
        } catch (_) {}
      }
    }
    return known;
  }

  /// Executa a sincronização bidirecional de todas as contas ativas cadastradas.
  Future<EmailSyncResult> syncAll({
    bool interactive = false,
    int maxPerAccount = 200,
  }) async {
    await sanitizeLegacyAttachmentBlobs(db);

    final accounts = await EmailAccountsManager.loadAccounts(db);
    if (accounts.isEmpty) {
      return const EmailSyncResult(
        accountsSynced: 0,
        totalMessagesSaved: 0,
        failedDetails: [],
      );
    }

    // Envia primeiro alterações pendentes feitas offline antes de puxar estado remoto
    final pendingWarnings = await flushPendingRemoteActions(
      accounts,
      interactive: interactive,
    );

    final knownIds = await _loadKnownRawMessageIds();

    var synced = 0;
    var totalSaved = 0;
    final failed = <String>[...pendingWarnings];

    for (final acc in accounts) {
      if (!acc.isActive) continue;

      try {
        if (acc.incomingProtocol == 'gmail_api') {
          final service = gmailService ?? GmailOAuthService();
          final folderWarnings = <String>[];
          final messages = await service.fetchMessages(
            accountId: acc.id,
            accountEmail: acc.email,
            maxResults: maxPerAccount,
            allowInteractiveRefresh: interactive,
            knownMessageIds: knownIds,
            folderWarnings: folderWarnings,
          );
          final saved = await persistSyncedMessages(messages, 'gmail_api');
          totalSaved += saved;
          synced++;
          if (folderWarnings.isNotEmpty) {
            failed.addAll(folderWarnings.map((w) => '${acc.name}: $w'));
          }
        } else if (acc.incomingProtocol == 'microsoft_graph') {
          final service = microsoftService ?? MicrosoftOAuthService();
          final folderWarnings = <String>[];
          final messages = await service.fetchMessages(
            accountId: acc.id,
            accountEmail: acc.email,
            maxResults: maxPerAccount,
            knownMessageIds: knownIds,
            folderWarnings: folderWarnings,
          );
          final saved = await persistSyncedMessages(
            messages,
            'microsoft_graph',
          );
          totalSaved += saved;
          synced++;
          if (folderWarnings.isNotEmpty) {
            failed.addAll(folderWarnings.map((w) => '${acc.name}: $w'));
          }
        } else if (kIsWeb) {
          failed.add(
            '${acc.name}: Conexão direta IMAP/Exchange indisponível na Web; sincronize via app nativo.',
          );
        } else {
          final pass = await EmailAccountsManager.getAccountPassword(
            acc.id,
            db,
          );
          if (pass == null || pass.trim().isEmpty) {
            failed.add('${acc.name}: senha não configurada');
            continue;
          }

          if (acc.incomingProtocol == 'exchange') {
            final storage = const FlutterSecureStorage();
            final deviceId =
                (await storage.read(key: 'jw_eas_device_id')) ??
                const Uuid().v4();
            final session = ExchangeProtocolSession(
              host: acc.incomingHost,
              username: acc.username,
              password: pass,
              deviceId: deviceId,
            );
            final exService = exchangeService ?? ExchangeReadService(db);
            final res = await exService.sync(
              session: session,
              host: acc.incomingHost,
              account: acc.email,
              deviceId: deviceId,
              allMailFolders: true,
            );
            totalSaved += res.saved;
            synced++;
          } else {
            final emailService =
                jwEmailService ??
                JwEmailService(db: db, biometricAuth: BiometricAuthService());
            final saved = await emailService.syncEmails(
              host: acc.incomingHost,
              port: acc.incomingPort,
              username: acc.username,
              password: pass,
              accountEmail: acc.email,
            );
            totalSaved += saved.toInt();
            synced++;
          }
        }
      } catch (e, st) {
        AppLogger.warning('Falha ao sincronizar conta ${acc.name}: $e', e, st);
        final friendly = friendlyErrorMessage(e, acc);
        failed.add('${acc.name}: $friendly');
      }
    }

    return EmailSyncResult(
      accountsSynced: synced,
      totalMessagesSaved: totalSaved,
      failedDetails: failed,
    );
  }

  EmailAccount? _resolveAccountForMessage(
    JwEmailMessage msg,
    List<EmailAccount> accounts,
  ) {
    final targetEmail = (msg.accountEmail ?? '').trim().toLowerCase();
    if (targetEmail.isEmpty) return null;
    return accounts
        .where((a) => a.email.trim().toLowerCase() == targetEmail)
        .firstOrNull;
  }

  /// Indica se um ID de e-mail é sintético local (ex.: UUID v4 de rascunho/enviada local)
  /// e não um ID remoto válido do Gmail ou Microsoft Graph.
  static bool isLocalSyntheticMessageId(String rawId) =>
      MicrosoftOAuthService.isSyntheticLocalId(rawId);

  static bool _isPermanentInvalidIdOrMissingError(Object e) {
    final lower = e.toString().toLowerCase();
    return lower.contains('errorinvalididmalformed') ||
        lower.contains('invalididmalformed') ||
        lower.contains('id is malformed') ||
        lower.contains('invalid compression id') ||
        (lower.contains('http 404') && lower.contains('recusou'));
  }

  Future<String> _resolveEffectiveRemoteId(JwEmailMessage msg) async {
    final entryId = msg.id.startsWith('email_') ? msg.id : 'email_${msg.id}';
    final row = await (db.select(
      db.inboxEntries,
    )..where((t) => t.id.equals(entryId))).getSingleOrNull();
    if (row != null && row.metadata.isNotEmpty) {
      try {
        final meta = jsonDecode(row.metadata) as Map<String, dynamic>;
        final emailRaw = meta['email'];
        if (emailRaw is Map) {
          final rid = emailRaw['remoteId']?.toString();
          if (rid != null && rid.isNotEmpty) return rid;
        }
      } catch (_) {}
    }
    return msg.id.startsWith('email_') ? msg.id.substring(6) : msg.id;
  }

  /// Caso uma mensagem enviada localmente ainda tenha ID sintético (UUID v4), tenta
  /// reconciliar localmente ou no servidor Graph (`sentitems`) o ItemId real para não gerar HTTP 400.
  Future<String?> _tryResolveSyntheticRemoteId({
    required EmailAccount acc,
    required String entryId,
    required String subject,
    DateTime? sentDateUtc,
  }) async {
    // 1. Verifica se já existe outra linha sincronizada do servidor com mesmo assunto/data/conta
    final targetSub = subject.trim().toLowerCase();
    final targetEmail = acc.email.trim().toLowerCase();
    if (targetSub.isNotEmpty) {
      final candidateRows = await (db.select(
        db.inboxEntries,
      )..where((t) => t.sourceType.equals('email'))).get();
      for (final row in candidateRows) {
        if (row.id == entryId) continue;
        try {
          final meta = jsonDecode(row.metadata) as Map<String, dynamic>;
          final emailRaw = meta['email'];
          if (emailRaw is! Map) continue;
          final rowAcc = (emailRaw['accountEmail']?.toString() ?? '')
              .trim()
              .toLowerCase();
          if (rowAcc != targetEmail) continue;
          final rowSub = (emailRaw['subject']?.toString() ?? '')
              .trim()
              .toLowerCase();
          if (rowSub != targetSub) continue;
          final rid =
              emailRaw['remoteId']?.toString() ??
              emailRaw['id']?.toString() ??
              (row.id.startsWith('email_') ? row.id.substring(6) : row.id);
          if (isLocalSyntheticMessageId(rid)) continue;
          if (sentDateUtc != null) {
            final rowDate = DateTime.tryParse(
              emailRaw['date']?.toString() ?? '',
            )?.toUtc();
            if (rowDate != null &&
                rowDate.difference(sentDateUtc.toUtc()).inMinutes.abs() > 20) {
              continue;
            }
          }
          await _bindRemoteIdToEntry(entryId, rid);
          return rid;
        } catch (_) {}
      }
    }

    // 2. Consulta leve em sentitems no Microsoft Graph (quando aplicável)
    if (acc.incomingProtocol == 'microsoft_graph' && targetSub.isNotEmpty) {
      final ms = microsoftService ?? MicrosoftOAuthService();
      final resolved = await ms.findRecentSentMessageId(
        accountId: acc.id,
        subject: subject,
        sentAfterUtc: sentDateUtc,
      );
      if (resolved != null && resolved.isNotEmpty) {
        await _bindRemoteIdToEntry(entryId, resolved);
        return resolved;
      }
    }
    return null;
  }

  Future<void> _bindRemoteIdToEntry(String entryId, String remoteId) async {
    final row = await (db.select(
      db.inboxEntries,
    )..where((t) => t.id.equals(entryId))).getSingleOrNull();
    if (row == null || row.metadata.isEmpty) return;
    try {
      final meta = Map<String, dynamic>.from(jsonDecode(row.metadata) as Map);
      final emailRaw = meta['email'];
      if (emailRaw is Map) {
        final emailMap = Map<String, dynamic>.from(emailRaw);
        emailMap['remoteId'] = remoteId;
        emailMap.remove('isLocalSentPendingResolution');
        meta['email'] = emailMap;
        await (db.update(
          db.inboxEntries,
        )..where((t) => t.id.equals(entryId))).write(
          InboxEntriesCompanion(metadata: drift.Value(jsonEncode(meta))),
        );
      }
    } catch (_) {}
  }

  /// Atualiza status de leitura (`isRead`) localmente e reflete no servidor da conta conectada.
  Future<EmailMutationResult> updateReadStatus(
    List<JwEmailMessage> messages, {
    required bool isRead,
    bool interactive = false,
  }) async {
    if (messages.isEmpty) return const EmailMutationResult(localUpdated: 0);
    final emailSvc =
        jwEmailService ??
        JwEmailService(db: db, biometricAuth: BiometricAuthService());
    final ids = messages.map((m) => m.id).toList();
    final localCount = await emailSvc.setEmailsReadStatus(ids, isRead: isRead);

    final accounts = await EmailAccountsManager.loadAccounts(db);
    return _pushMutationsToServers(
      messages: messages,
      accounts: accounts,
      actionType: 'read',
      isRead: isRead,
      localCount: localCount,
      interactive: interactive,
    );
  }

  /// Move mensagens de pasta localmente e reflete no servidor (`Gmail`, `Microsoft Graph`, `IMAP`).
  Future<EmailMutationResult> moveMessagesToFolder(
    List<JwEmailMessage> messages, {
    required String targetFolderName,
    bool interactive = false,
  }) async {
    if (messages.isEmpty) return const EmailMutationResult(localUpdated: 0);
    final emailSvc =
        jwEmailService ??
        JwEmailService(db: db, biometricAuth: BiometricAuthService());
    final ids = messages.map((m) => m.id).toList();
    final localCount = await emailSvc.moveEmailsToFolder(
      ids,
      targetFolderName: targetFolderName,
    );

    final accounts = await EmailAccountsManager.loadAccounts(db);
    return _pushMutationsToServers(
      messages: messages,
      accounts: accounts,
      actionType: 'move',
      targetFolderName: targetFolderName,
      localCount: localCount,
      interactive: interactive,
    );
  }

  /// Exclui mensagens (move para `Lixeira` ou apaga em definitivo se já estiver na Lixeira) e reflete no servidor.
  Future<EmailMutationResult> deleteMessages(
    List<JwEmailMessage> messages, {
    bool permanent = false,
    bool interactive = false,
  }) async {
    if (messages.isEmpty) return const EmailMutationResult(localUpdated: 0);
    final emailSvc =
        jwEmailService ??
        JwEmailService(db: db, biometricAuth: BiometricAuthService());
    final trashOrSoftMoveIds = <String>[];
    final permanentDeleteIds = <String>[];

    for (final msg in messages) {
      final inTrash = msg.folderName == 'Lixeira';
      if (permanent || inTrash) {
        permanentDeleteIds.add(msg.id);
      } else {
        trashOrSoftMoveIds.add(msg.id);
      }
    }

    var localCount = 0;
    if (trashOrSoftMoveIds.isNotEmpty) {
      localCount += await emailSvc.deleteEmails(
        trashOrSoftMoveIds,
        moveToTrashOnly: true,
      );
    }
    if (permanentDeleteIds.isNotEmpty) {
      localCount += await emailSvc.deleteEmails(permanentDeleteIds);
    }

    final accounts = await EmailAccountsManager.loadAccounts(db);
    final toTrashMsgs = messages
        .where((m) => trashOrSoftMoveIds.contains(m.id))
        .toList();
    final permMsgs = messages
        .where((m) => permanentDeleteIds.contains(m.id))
        .toList();

    var remoteSynced = 0;
    var queuedOffline = 0;
    final warnings = <String>[];
    var readOnlyNotice = false;

    if (toTrashMsgs.isNotEmpty) {
      final res = await _pushMutationsToServers(
        messages: toTrashMsgs,
        accounts: accounts,
        actionType: 'delete',
        permanent: false,
        localCount: localCount,
        interactive: interactive,
      );
      remoteSynced += res.remoteSynced;
      queuedOffline += res.queuedOffline;
      warnings.addAll(res.warnings);
      readOnlyNotice = readOnlyNotice || res.hasReadOnlyAccountNotice;
    }

    if (permMsgs.isNotEmpty) {
      final res = await _pushMutationsToServers(
        messages: permMsgs,
        accounts: accounts,
        actionType: 'delete',
        permanent: true,
        localCount: localCount,
        interactive: interactive,
      );
      remoteSynced += res.remoteSynced;
      queuedOffline += res.queuedOffline;
      warnings.addAll(res.warnings);
      readOnlyNotice = readOnlyNotice || res.hasReadOnlyAccountNotice;
    }

    return EmailMutationResult(
      localUpdated: localCount,
      remoteSynced: remoteSynced,
      queuedOffline: queuedOffline,
      warnings: warnings,
      hasReadOnlyAccountNotice: readOnlyNotice,
    );
  }

  Future<EmailMutationResult> _pushMutationsToServers({
    required List<JwEmailMessage> messages,
    required List<EmailAccount> accounts,
    required String actionType,
    bool? isRead,
    String? targetFolderName,
    bool permanent = false,
    required int localCount,
    bool interactive = false,
  }) async {
    var remoteSynced = 0;
    var queuedOffline = 0;
    var readOnlyNotice = false;
    final warnings = <String>[];

    for (final msg in messages) {
      final acc = _resolveAccountForMessage(msg, accounts);
      if (acc == null) continue;

      if (acc.incomingProtocol == 'exchange') {
        readOnlyNotice = true;
        continue;
      }

      if (kIsWeb &&
          acc.incomingProtocol != 'gmail_api' &&
          acc.incomingProtocol != 'microsoft_graph') {
        warnings.add(
          '${acc.name}: alteração aplicada localmente (IMAP direto indisponível na Web).',
        );
        continue;
      }

      var remoteId = await _resolveEffectiveRemoteId(msg);
      final isOAuthProtocol =
          acc.incomingProtocol == 'microsoft_graph' ||
          acc.incomingProtocol == 'gmail_api';
      if (isOAuthProtocol && isLocalSyntheticMessageId(remoteId)) {
        final entryId = msg.id.startsWith('email_')
            ? msg.id
            : 'email_${msg.id}';
        final resolved = await _tryResolveSyntheticRemoteId(
          acc: acc,
          entryId: entryId,
          subject: msg.subject,
          sentDateUtc: msg.date,
        );
        if (resolved == null || isLocalSyntheticMessageId(resolved)) {
          // Registro puramente local (ex.: rascunho/enviada sem ItemId no servidor):
          // não envia UUID sintético para o Graph/Gmail para evitar HTTP 400 ErrorInvalidIdMalformed.
          continue;
        }
        remoteId = resolved;
      }

      final actionMap = <String, dynamic>{
        'entryId': msg.id.startsWith('email_') ? msg.id : 'email_${msg.id}',
        'accountId': acc.id,
        'accountEmail': acc.email,
        'protocol': acc.incomingProtocol,
        'messageId': msg.id,
        'remoteId': remoteId,
        'remoteUid': msg.remoteUid,
        'mailboxPath': msg.folderId ?? 'INBOX',
        'action': actionType,
        'isRead': isRead,
        'targetFolderName': targetFolderName,
        'permanent': permanent,
      };

      try {
        await _executeSingleRemoteAction(
          actionMap,
          acc: acc,
          interactive: interactive,
        );
        remoteSynced++;
      } catch (e, st) {
        if (_isPermanentInvalidIdOrMissingError(e)) {
          AppLogger.info(
            'Descartando sincronização remota para ID sintético/inexistente ($actionType / ${acc.name}): $e',
          );
          continue;
        }
        AppLogger.warning(
          'Falha ao enviar alteração "$actionType" para ${acc.name}; enfileirando para retry offline',
          e,
          st,
        );
        await _enqueuePendingRemoteAction(actionMap);
        queuedOffline++;
        warnings.add(
          '${acc.name}: alterado localmente; sincronização com o servidor ficou pendente (${friendlyErrorMessage(e, acc)}).',
        );
      }
    }

    return EmailMutationResult(
      localUpdated: localCount,
      remoteSynced: remoteSynced,
      queuedOffline: queuedOffline,
      warnings: warnings,
      hasReadOnlyAccountNotice: readOnlyNotice,
    );
  }

  Future<void> _executeSingleRemoteAction(
    Map<String, dynamic> action, {
    required EmailAccount acc,
    bool interactive = false,
  }) async {
    final type = action['action'] as String? ?? '';
    final messageId =
        (action['remoteId'] as String?) ?? (action['messageId'] as String);
    final isRead = action['isRead'] as bool? ?? true;
    final targetFolder =
        action['targetFolderName'] as String? ?? 'Caixa de Entrada';
    final permanent = action['permanent'] as bool? ?? false;

    if (acc.incomingProtocol == 'gmail_api') {
      final gmail = gmailService ?? GmailOAuthService();
      switch (type) {
        case 'read':
          await gmail.markMessageRead(
            accountId: acc.id,
            messageId: messageId,
            isRead: isRead,
            allowInteractiveRefresh: interactive,
          );
          break;
        case 'move':
          await gmail.moveMessageToFolder(
            accountId: acc.id,
            messageId: messageId,
            targetFolderName: targetFolder,
            allowInteractiveRefresh: interactive,
          );
          break;
        case 'delete':
          await gmail.deleteMessage(
            accountId: acc.id,
            messageId: messageId,
            permanent: permanent,
            allowInteractiveRefresh: interactive,
          );
          break;
      }
    } else if (acc.incomingProtocol == 'microsoft_graph') {
      final ms = microsoftService ?? MicrosoftOAuthService();
      switch (type) {
        case 'read':
          await ms.markMessageRead(
            accountId: acc.id,
            messageId: messageId,
            isRead: isRead,
          );
          break;
        case 'move':
          final newRemoteId = await ms.moveMessageToFolder(
            accountId: acc.id,
            messageId: messageId,
            targetFolderName: targetFolder,
          );
          if (newRemoteId != null && newRemoteId.isNotEmpty) {
            final svc =
                jwEmailService ??
                JwEmailService(db: db, biometricAuth: BiometricAuthService());
            await svc.moveEmailsToFolder(
              [action['messageId'] as String],
              targetFolderName: targetFolder,
              updatedRemoteIds: {
                action['messageId'] as String: newRemoteId,
                action['entryId'] as String: newRemoteId,
              },
            );
          }
          break;
        case 'delete':
          final deletedNewId = await ms.deleteMessage(
            accountId: acc.id,
            messageId: messageId,
            permanent: permanent,
          );
          if (!permanent && deletedNewId != null && deletedNewId.isNotEmpty) {
            final svc =
                jwEmailService ??
                JwEmailService(db: db, biometricAuth: BiometricAuthService());
            await svc.moveEmailsToFolder(
              [action['messageId'] as String],
              targetFolderName: 'Lixeira',
              updatedRemoteIds: {
                action['messageId'] as String: deletedNewId,
                action['entryId'] as String: deletedNewId,
              },
            );
          }
          break;
      }
    } else if (!kIsWeb && acc.incomingProtocol == 'imap') {
      final pass = await EmailAccountsManager.getAccountPassword(acc.id, db);
      if (pass == null || pass.trim().isEmpty) {
        throw const JwEmailAuthException('Senha IMAP não configurada.');
      }
      final uid = action['remoteUid'] as int?;
      if (uid == null || uid <= 0) return;
      final mailboxPath = action['mailboxPath'] as String? ?? 'INBOX';
      final imapClient =
          (jwEmailService ??
                  JwEmailService(db: db, biometricAuth: BiometricAuthService()))
              .imapClient;
      switch (type) {
        case 'read':
          await imapClient.pushReadFlag(
            host: acc.incomingHost,
            port: acc.incomingPort,
            username: acc.username,
            password: pass,
            mailboxPath: mailboxPath,
            uids: [uid],
            isRead: isRead,
          );
          break;
        case 'move':
          await imapClient.pushMoveToFolder(
            host: acc.incomingHost,
            port: acc.incomingPort,
            username: acc.username,
            password: pass,
            sourceMailbox: mailboxPath,
            uids: [uid],
            targetFolderName: targetFolder,
          );
          break;
        case 'delete':
          await imapClient.pushDeleteUids(
            host: acc.incomingHost,
            port: acc.incomingPort,
            username: acc.username,
            password: pass,
            sourceMailbox: mailboxPath,
            uids: [uid],
            permanent: permanent,
          );
          break;
      }
    }
  }

  Future<List<Map<String, dynamic>>> _loadPendingRemoteActions() async {
    final row = await (db.select(
      db.appKvStore,
    )..where((t) => t.key.equals(_pendingRemoteActionsKey))).getSingleOrNull();
    if (row == null || row.value.isEmpty) return [];
    try {
      final decoded = jsonDecode(row.value) as List<dynamic>;
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _savePendingRemoteActions(
    List<Map<String, dynamic>> actions,
  ) async {
    await db
        .into(db.appKvStore)
        .insertOnConflictUpdate(
          AppKvStoreCompanion.insert(
            key: _pendingRemoteActionsKey,
            value: jsonEncode(actions),
            updatedAt: drift.Value(DateTime.now().toUtc()),
          ),
        );
  }

  Future<void> _enqueuePendingRemoteAction(Map<String, dynamic> action) async {
    final queue = await _loadPendingRemoteActions();
    final keyEntry = action['entryId'] as String? ?? '';
    final actionType = action['action'] as String? ?? '';
    // Substitui mutação idempotente do mesmo tipo e mensagem para evitar redundância
    queue.removeWhere(
      (item) => item['entryId'] == keyEntry && item['action'] == actionType,
    );
    queue.add(action);
    await _savePendingRemoteActions(queue);
  }

  /// Tenta enviar mutações remotas enfileiradas durante uso offline.
  Future<List<String>> flushPendingRemoteActions(
    List<EmailAccount> accounts, {
    bool interactive = false,
  }) async {
    final queue = await _loadPendingRemoteActions();
    if (queue.isEmpty) return const [];

    final remaining = <Map<String, dynamic>>[];
    final warnings = <String>[];
    for (final action in queue) {
      final accId = action['accountId'] as String?;
      final accEmail = (action['accountEmail'] as String? ?? '').toLowerCase();
      final acc = accounts
          .where(
            (a) =>
                (accId != null && a.id == accId) ||
                a.email.toLowerCase() == accEmail,
          )
          .firstOrNull;
      if (acc == null) continue;
      if (kIsWeb &&
          acc.incomingProtocol != 'gmail_api' &&
          acc.incomingProtocol != 'microsoft_graph') {
        remaining.add(action);
        continue;
      }

      // Saneamento automático de ações legadas com ID sintético local (ex.: UUIDv4 enfileirado anteriormente)
      final queuedRemoteId =
          (action['remoteId'] as String?) ??
          (action['messageId'] as String? ?? '');
      if ((acc.incomingProtocol == 'microsoft_graph' ||
              acc.incomingProtocol == 'gmail_api') &&
          isLocalSyntheticMessageId(queuedRemoteId)) {
        final entryId = action['entryId'] as String? ?? '';
        String subject = '';
        DateTime? sentAt;
        if (entryId.isNotEmpty) {
          final row = await (db.select(
            db.inboxEntries,
          )..where((t) => t.id.equals(entryId))).getSingleOrNull();
          if (row != null && row.metadata.isNotEmpty) {
            try {
              final meta = jsonDecode(row.metadata) as Map<String, dynamic>;
              final emailRaw = meta['email'];
              if (emailRaw is Map) {
                subject = emailRaw['subject']?.toString() ?? '';
                sentAt = DateTime.tryParse(emailRaw['date']?.toString() ?? '');
              }
            } catch (_) {}
          }
        }
        final resolved = subject.isNotEmpty
            ? await _tryResolveSyntheticRemoteId(
                acc: acc,
                entryId: entryId,
                subject: subject,
                sentDateUtc: sentAt,
              )
            : null;
        if (resolved == null || isLocalSyntheticMessageId(resolved)) {
          // Descarta ação impossível de enviar (evita loop infinito de HTTP 400 ErrorInvalidIdMalformed).
          continue;
        }
        action['remoteId'] = resolved;
      }

      try {
        await _executeSingleRemoteAction(
          action,
          acc: acc,
          interactive: interactive,
        );
      } catch (e, st) {
        if (_isPermanentInvalidIdOrMissingError(e)) {
          AppLogger.info(
            'Ação pendente descartada por ID inválido ou inexistente no servidor (${action['action']} / ${acc.name}): $e',
          );
          continue;
        }
        AppLogger.warning(
          'Falha ao reenviar ação pendente de e-mail (${action['action']}) para ${acc.name}',
          e,
          st,
        );
        remaining.add(action);
        warnings.add(
          '${acc.name}: ação pendente aguardando conexão (${friendlyErrorMessage(e, acc)}).',
        );
      }
    }

    await _savePendingRemoteActions(remaining);
    return warnings;
  }
}
