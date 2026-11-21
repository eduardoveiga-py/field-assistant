import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;
import 'package:drift/drift.dart' as drift;
import 'package:eas_client/eas_client.dart' as eas;
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:uuid/uuid.dart';

import '../core/sync_timestamp.dart';

import '../database/app_database.dart';
import 'jw_email_service.dart';
import 'email_contacts_manager.dart';

/// Exchange MVP: only read incoming changes. Never sends commands that mutate
/// the mailbox and never claims to apply or acknowledge device policies.
class ExchangeException implements Exception {
  final String message;
  const ExchangeException(this.message);
  @override
  String toString() => message;
}

class _NoRedirectClient extends http.BaseClient {
  final http.Client _inner;
  _NoRedirectClient(http.Client? inner) : _inner = inner ?? http.Client();
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    // Never forward Authorization to a redirect target automatically.
    request.followRedirects = false;
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}

abstract class ExchangeSession {
  Future<String> inboxId();
  Future<List<eas.EasFolder>> mailFolders();
  Future<eas.SyncResult> readPage(String folder, String key);
  Future<void> sendMail({
    required String to,
    required String subject,
    required String body,
    String? from,
    List<String> cc = const [],
    List<String> bcc = const [],
    List<Map<String, dynamic>> attachments = const [],
  });
  void close();
}

class ExchangeProtocolSession implements ExchangeSession {
  final eas.EasHttpClient _client;
  final String _username;

  ExchangeProtocolSession({
    required String host,
    required String username,
    required String password,
    required String deviceId,
    http.Client? httpClient,
  }) : _username = username,
       _client = eas.EasHttpClient(
         server: _validateHost(host),
         credentials: eas.BasicCredentials(
           username: username,
           password: password,
         ),
         deviceId: deviceId,
         deviceType: 'FieldAssistant',
         protocolVersion: '14.1',
         commandTimeout: const Duration(seconds: 45),
         maxResponseSize: 16 * 1024 * 1024,
         httpClient: _NoRedirectClient(httpClient),
       );

  static String _validateHost(String value) {
    if (kIsWeb) {
      throw const ExchangeException(
        'Exchange não está disponível diretamente no navegador Web.',
      );
    }
    final host = value.trim().toLowerCase();
    final uri = Uri.tryParse('https://$host');
    if (uri == null ||
        uri.host != host ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.path.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        !RegExp(r'^[a-z0-9.-]+$').hasMatch(host)) {
      throw const ExchangeException(
        'Informe apenas o nome do servidor Exchange, sem https://, porta ou caminho.',
      );
    }
    return host;
  }

  @override
  Future<List<eas.EasFolder>> mailFolders() async {
    final folders = await eas.FolderSyncCommand(syncKey: '0').execute(_client);
    if (!folders.isSuccess) {
      throw ExchangeException(
        'Exchange recusou a listagem de pastas (código ${folders.status}).',
      );
    }
    final result = folders.addedFolders
        .where((f) => f.isMailFolder && f.serverId.isNotEmpty)
        .toList();
    if (result.where((f) => f.type == eas.EasFolderType.defaultInbox).length !=
            1 ||
        result.map((f) => f.serverId).toSet().length != result.length) {
      throw const ExchangeException(
        'Exchange não retornou uma lista de pastas de correio válida.',
      );
    }
    return result;
  }

  @override
  Future<String> inboxId() async => (await mailFolders())
      .singleWhere((f) => f.type == eas.EasFolderType.defaultInbox)
      .serverId;

  @override
  Future<eas.SyncResult> readPage(String folder, String key) => eas.SyncCommand(
    syncKey: key,
    collectionId: folder,
    protocolVersion: '14.1',
    windowSize: 10,
    bodyType: 1,
    bodyTruncationSize: 262144,
  ).execute(_client);

  /// Leitura de anexos por intervalo via comando FetchAttachment do Exchange.
  Future<eas.ItemOperationsResult> readAttachmentRange(
    String reference,
    int start,
    int end,
  ) => eas.FetchAttachmentCommand(
    fileReference: reference,
    rangeStart: start,
    rangeEnd: end,
  ).execute(_client);

  /// Envio de e-mails via comando Exchange ActiveSync (SendMail)
  @override
  Future<void> sendMail({
    required String to,
    required String subject,
    required String body,
    String? from,
    List<String> cc = const [],
    List<String> bcc = const [],
    List<Map<String, dynamic>> attachments = const [],
  }) async {
    final clientId = const Uuid().v4();
    final nowUtc = DateTime.now().toUtc();
    final sender = from ?? _username;

    final payload = StringBuffer()
      ..write('From: <$sender>\r\n')
      ..write('To: $to\r\n');
    if (cc.isNotEmpty) {
      payload.write('Cc: ${cc.join(", ")}\r\n');
    }
    payload
      ..write('Subject: $subject\r\n')
      ..write('Date: ${nowUtc.toIso8601String()}\r\n')
      ..write('MIME-Version: 1.0\r\n');

    if (attachments.isEmpty) {
      payload
        ..write('Content-Type: text/plain; charset=UTF-8\r\n')
        ..write('\r\n')
        ..write(body);
    } else {
      final boundary = '===_EAS_${const Uuid().v4().replaceAll("-", "")}_===';
      payload
        ..write('Content-Type: multipart/mixed; boundary="$boundary"\r\n')
        ..write('\r\n')
        ..write('--$boundary\r\n')
        ..write('Content-Type: text/plain; charset=UTF-8\r\n')
        ..write('Content-Transfer-Encoding: 8bit\r\n')
        ..write('\r\n')
        ..write(body)
        ..write('\r\n');

      for (final att in attachments) {
        final name = (att['name'] ?? 'anexo').toString();
        final base64Content = (att['base64'] ?? '').toString();
        final contentType = (att['contentType'] ?? 'application/octet-stream')
            .toString();
        if (base64Content.isNotEmpty) {
          payload
            ..write('--$boundary\r\n')
            ..write('Content-Type: $contentType; name="$name"\r\n')
            ..write('Content-Transfer-Encoding: base64\r\n')
            ..write('Content-Disposition: attachment; filename="$name"\r\n')
            ..write('\r\n')
            ..write(base64Content)
            ..write('\r\n');
        }
      }
      payload.write('--$boundary--\r\n');
    }

    await eas.SendMailCommand(
      clientId: clientId,
      mimeContent: payload.toString(),
      saveInSentItems: true,
    ).execute(_client);
  }

  @override
  void close() => _client.dispose();
}

String _digest(Object value) =>
    crypto.sha256.convert(utf8.encode(jsonEncode(value))).toString();

class ExchangeReadResult {
  final int saved;
  final bool moreAvailable;
  final int foldersRead;
  const ExchangeReadResult(
    this.saved,
    this.moreAvailable, {
    this.foldersRead = 1,
  });
}

class ExchangeReadService {
  final AppDatabase db;
  ExchangeReadService(this.db);

  /// Saves previews only; not a complete mailbox backup. Each page, its
  /// outgoing sync queue records and its new Exchange key commit atomically.
  Future<ExchangeReadResult> sync({
    required ExchangeSession session,
    required String host,
    required String account,
    required String deviceId,
    int maxPages = 50,
    bool allMailFolders = false,
  }) async {
    if (maxPages < 1) throw ArgumentError.value(maxPages, 'maxPages');
    try {
      final folders = allMailFolders
          ? await session.mailFolders()
          : [
              eas.EasFolder(
                serverId: await session.inboxId(),
                parentId: '0',
                displayName: 'Caixa de entrada',
                type: eas.EasFolderType.defaultInbox,
              ),
            ];
      if (folders.isEmpty ||
          folders.any((f) => !f.isMailFolder || f.serverId.isEmpty) ||
          folders.map((f) => f.serverId).toSet().length != folders.length) {
        throw const ExchangeException(
          'Exchange retornou pastas de correio inválidas; nada foi apagado.',
        );
      }
      var totalSaved = 0;
      var anyMore = false;
      for (final mailFolder in folders) {
        final folder = mailFolder.serverId;
        final keyId =
            'eas_sync_${_digest([host.toLowerCase(), account.toLowerCase(), deviceId, folder])}';
        final row = await (db.select(
          db.appKvStore,
        )..where((t) => t.key.equals(keyId))).getSingleOrNull();
        var key = row?.value ?? '0';
        var saved = 0;
        var resetAttempted = false;
        var more = true;
        for (var page = 0; page < maxPages && more; page++) {
          final result = await session.readPage(folder, key);
          if (result.status == 3 && key != '0' && !resetAttempted) {
            key = '0';
            resetAttempted = true;
            continue;
          }
          if (result.status != 1 ||
              result.collectionId != folder ||
              result.syncKey.isEmpty ||
              result.syncKey == '0') {
            throw ExchangeException(
              'Exchange recusou a sincronização (código ${result.status}); mensagens locais preservadas.',
            );
          }
          if (result.moreAvailable && result.syncKey == key) {
            throw const ExchangeException(
              'Exchange não avançou a sincronização; mensagens locais preservadas.',
            );
          }
          final initial = key == '0';
          final changes = [...result.addedEmails, ...result.changedEmails];
          if (changes.any((m) => m.serverId.isEmpty)) {
            throw const ExchangeException(
              'Exchange retornou mensagem sem identificador; lote não salvo.',
            );
          }
          await db.transaction(() async {
            final now = DateTime.now();
            for (final item in changes) {
              // Preserve download references locally even though attachment bytes
              // are not imported yet. A partial Change with no attachment field
              // must never erase known references.
              if (item.attachments.isNotEmpty) {
                final refKey =
                    'eas_attachment_refs_${_digest([host.toLowerCase(), account.toLowerCase(), folder, item.serverId])}';
                final prior = await (db.select(
                  db.appKvStore,
                )..where((t) => t.key.equals(refKey))).getSingleOrNull();
                final savedRefs = <Map<String, dynamic>>[];
                if (prior != null) {
                  final decoded = jsonDecode(prior.value);
                  if (decoded is! Map ||
                      decoded['version'] != 1 ||
                      decoded['attachments'] is! List) {
                    throw const FormatException(
                      'Índice local de anexos inválido; lote preservado.',
                    );
                  }
                  for (final value in decoded['attachments'] as List) {
                    if (value is! Map) {
                      throw const FormatException(
                        'Índice local de anexos inválido.',
                      );
                    }
                    savedRefs.add(Map<String, dynamic>.from(value));
                  }
                }
                for (final attachment in item.attachments) {
                  final ref = attachment.fileReference;
                  final entry = <String, dynamic>{
                    'fileReference': ref,
                    'name': attachment.displayName,
                    'estimatedSize': attachment.estimatedSize,
                    'contentType': attachment.contentType,
                    'isInline': attachment.isInline,
                    'method': attachment.method,
                  };
                  final index = ref.isEmpty
                      ? -1
                      : savedRefs.indexWhere((e) => e['fileReference'] == ref);
                  if (index >= 0) {
                    savedRefs[index] = entry;
                  } else if (!savedRefs.any(
                    (e) => jsonEncode(e) == jsonEncode(entry),
                  )) {
                    savedRefs.add(entry);
                  }
                }
                await db
                    .into(db.appKvStore)
                    .insertOnConflictUpdate(
                      AppKvStoreCompanion.insert(
                        key: refKey,
                        value: jsonEncode({
                          'version': 1,
                          'host': host.toLowerCase(),
                          'account': account.toLowerCase(),
                          'folderId': folder,
                          'serverId': item.serverId,
                          'attachments': savedRefs,
                        }),
                        updatedAt: drift.Value(now),
                      ),
                    );
              }
              // Change responses can be partial; keep previous snapshots rather
              // than replacing them with blank fields.
              final data = [
                item.subject,
                item.from,
                item.to,
                item.body,
                item.bodyTruncated,
                item.dateReceived?.toIso8601String(),
                item.attachments.length,
              ];
              final id =
                  'email_eas_${_digest([host.toLowerCase(), account.toLowerCase(), folder, item.serverId, data])}';
              final exists = await (db.select(
                db.inboxEntries,
              )..where((t) => t.id.equals(id))).getSingleOrNull();
              if (exists != null) continue;
              final body = item.body ?? '';
              final attachmentsList = item.attachments.map((att) {
                final name = att.displayName.isNotEmpty
                    ? att.displayName
                    : (att.fileReference.isNotEmpty
                          ? att.fileReference
                          : 'anexo');
                final ct = att.contentType?.toLowerCase() ?? '';
                final type = ct.contains('pdf')
                    ? 'pdf'
                    : (ct.contains('image') ||
                              ct.contains('png') ||
                              ct.contains('jpeg') ||
                              ct.contains('jpg')
                          ? 'image'
                          : (ct.contains('word') || ct.contains('doc')
                                ? 'doc'
                                : 'file'));
                return {
                  'name': name,
                  'fileReference': att.fileReference,
                  'size': att.estimatedSize,
                  'contentType': att.contentType,
                  'path': att.fileReference.isNotEmpty
                      ? att.fileReference
                      : name,
                  'type': type,
                  'isInline': att.isInline,
                };
              }).toList();

              final message = JwEmailMessage(
                folderId: folder,
                folderName: mailFolder.displayName,
                id: id.substring('email_'.length),
                subject: item.subject.isEmpty ? '(Sem assunto)' : item.subject,
                from: item.from,
                to: item.to,
                date: item.dateReceived ?? now,
                bodyText: body,
                attachments: attachmentsList,
                isRead: item.read,
                isPermanentRetained: false,
              );
              await EmailContactsManager.recordSender(db, item.from);
              final metadata = {
                'email': message.toJson(),
                'exchangePreview': true,
                'exchangeMail': true,
                'bodyMayBeIncomplete': item.body == null || item.bodyTruncated,
                'attachmentCount': item.attachments.length,
              };
              await db
                  .into(db.inboxEntries)
                  .insert(
                    InboxEntriesCompanion.insert(
                      id: id,
                      content: '${message.subject}\n\n$body',
                      sourceType: const drift.Value('email'),
                      suggestedCategory: const drift.Value('email_jw'),
                      capturedAt: message.date,
                      metadata: drift.Value(jsonEncode(metadata)),
                      createdAt: now,
                      updatedAt: now,
                    ),
                  );
              // Do not advance the EAS key if durable cross-device queueing fails.
              final inserted = await (db.select(
                db.inboxEntries,
              )..where((t) => t.id.equals(id))).getSingle();
              await db
                  .into(db.syncQueue)
                  .insert(
                    SyncQueueCompanion.insert(
                      id: const Uuid().v4(),
                      entityType: 'inbox_entries',
                      entityId: id,
                      operation: 'INSERT',
                      payload: jsonEncode(
                        SyncTimestamp.normalizeMapDates(inserted.toJson()),
                      ),
                      createdAt: now,
                    ),
                  );
              saved++;
            }
            await db
                .into(db.appKvStore)
                .insertOnConflictUpdate(
                  AppKvStoreCompanion.insert(
                    key: keyId,
                    value: result.syncKey,
                    updatedAt: drift.Value(now),
                  ),
                );
          });
          key = result.syncKey;
          // EAS initial key negotiation is followed by a fetch even if the first
          // response has no MoreAvailable flag.
          more =
              (initial && result.syncKey.isNotEmpty && result.syncKey != '0') ||
              result.moreAvailable;
        }
        totalSaved += saved;
        anyMore = anyMore || more;
      }
      return ExchangeReadResult(
        totalSaved,
        anyMore,
        foldersRead: folders.length,
      );
    } on ExchangeException {
      rethrow;
    } on eas.EasRemoteWipeException {
      throw const ExchangeException(
        'O servidor solicita ação de segurança no dispositivo. Procure o administrador; nada foi apagado ou confirmado pelo aplicativo.',
      );
    } on eas.EasAuthException {
      throw const ExchangeException(
        'Autenticação Exchange recusada. Confirme o método de acesso permitido com o administrador.',
      );
    } on eas.EasForbiddenException {
      throw const ExchangeException(
        'Acesso Exchange negado. Confirme a permissão para este dispositivo com o administrador.',
      );
    } on eas.EasCommandException catch (e) {
      if (e.requiresProvisioning) {
        throw const ExchangeException(
          'O servidor exige políticas de dispositivo que este aplicativo ainda não aplica. Procure o administrador.',
        );
      }
      throw ExchangeException(
        'Falha no comando Exchange (HTTP ${e.statusCode ?? '-'}, código ${e.easStatus ?? '-'}).',
      );
    } on TimeoutException {
      throw const ExchangeException('Tempo esgotado na conexão Exchange.');
    } catch (_) {
      throw const ExchangeException(
        'Não foi possível conectar ou ler o Exchange. Confira o servidor, a rede e a autenticação.',
      );
    } finally {
      session.close();
    }
  }
}
