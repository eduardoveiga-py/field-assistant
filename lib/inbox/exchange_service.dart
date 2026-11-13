import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;
import 'package:drift/drift.dart' as drift;
import 'package:eas_client/eas_client.dart' as eas;
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;

import '../database/app_database.dart';
import 'jw_email_service.dart';

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
  Future<eas.SyncResult> readPage(String folder, String key);
  void close();
}

class ExchangeProtocolSession implements ExchangeSession {
  final eas.EasHttpClient _client;
  ExchangeProtocolSession({required String host, required String username,
      required String password, required String deviceId, http.Client? httpClient})
      : _client = eas.EasHttpClient(
          server: _validateHost(host),
          credentials: eas.BasicCredentials(username: username, password: password),
          deviceId: deviceId,
          deviceType: 'FieldAssistant',
          protocolVersion: '14.1',
          commandTimeout: const Duration(seconds: 45),
          maxResponseSize: 16 * 1024 * 1024,
          httpClient: _NoRedirectClient(httpClient),
        );

  static String _validateHost(String value) {
    if (kIsWeb) throw const ExchangeException('Exchange experimental não está disponível no navegador.');
    final host = value.trim().toLowerCase();
    final uri = Uri.tryParse('https://$host');
    if (uri == null || uri.host != host || uri.userInfo.isNotEmpty ||
        uri.hasPort || uri.path.isNotEmpty || uri.hasQuery || uri.hasFragment ||
        !RegExp(r'^[a-z0-9.-]+$').hasMatch(host)) {
      throw const ExchangeException('Informe apenas o nome do servidor Exchange, sem https://, porta ou caminho.');
    }
    return host;
  }

  @override
  Future<String> inboxId() async {
    final folders = await eas.FolderSyncCommand(syncKey: '0').execute(_client);
    if (!folders.isSuccess) throw ExchangeException('Exchange recusou a listagem de pastas (código ${folders.status}).');
    final matches = folders.addedFolders.where((f) => f.type == eas.EasFolderType.defaultInbox && f.serverId.isNotEmpty).toList();
    if (matches.length != 1) throw const ExchangeException('Exchange não retornou uma caixa de entrada identificável.');
    return matches.single.serverId;
  }

  @override
  Future<eas.SyncResult> readPage(String folder, String key) => eas.SyncCommand(
    syncKey: key, collectionId: folder, protocolVersion: '14.1', windowSize: 10,
    bodyType: 1, bodyTruncationSize: 262144,
  ).execute(_client);

  @override
  void close() => _client.dispose();
}

String _digest(Object value) => crypto.sha256.convert(utf8.encode(jsonEncode(value))).toString();

class ExchangeReadResult {
  final int saved;
  final bool moreAvailable;
  const ExchangeReadResult(this.saved, this.moreAvailable);
}

class ExchangeReadService {
  final AppDatabase db;
  ExchangeReadService(this.db);

  /// Each batch and its next key commit together. No remote or local deletion.
  /// Replaying a page is safe. Content/attachments may be incomplete: this is
  /// not a backup or a replacement for the official mail client.
  Future<ExchangeReadResult> sync({required ExchangeSession session,
      required String host, required String account, required String deviceId,
      int maxPages = 50}) async {
    if (maxPages < 1) throw ArgumentError.value(maxPages, 'maxPages');
    try {
      final folder = await session.inboxId();
      final keyId = 'eas_sync_${_digest([host.toLowerCase(), account.toLowerCase(), deviceId, folder])}';
      final row = await (db.select(db.appKvStore)..where((t) => t.key.equals(keyId))).getSingleOrNull();
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
        if (result.status != 1 || result.collectionId != folder || result.syncKey.isEmpty || result.syncKey == '0') {
          throw ExchangeException('Exchange recusou a sincronização (código ${result.status}); mensagens locais preservadas.');
        }
        if (result.moreAvailable && result.syncKey == key) {
          throw const ExchangeException('Exchange não avançou a sincronização; mensagens locais preservadas.');
        }
        final initial = key == '0';
        final changes = [...result.addedEmails, ...result.changedEmails];
        if (changes.any((m) => m.serverId.isEmpty)) {
          throw const ExchangeException('Exchange retornou mensagem sem identificador; lote não salvo.');
        }
        await db.transaction(() async {
          final now = DateTime.now();
          for (final item in changes) {
            // Change responses can be partial; keep previous snapshots rather
            // than replacing them with blank fields.
            final data = [item.subject, item.from, item.to, item.body, item.bodyTruncated,
              item.dateReceived?.toIso8601String(), item.attachments.length];
            final id = 'email_eas_${_digest([host.toLowerCase(), account.toLowerCase(), folder, item.serverId, data])}';
            final exists = await (db.select(db.inboxEntries)..where((t) => t.id.equals(id))).getSingleOrNull();
            if (exists != null) continue;
            final body = item.body ?? '';
            final message = JwEmailMessage(
              id: id.substring('email_'.length), subject: item.subject.isEmpty ? '(Sem assunto)' : item.subject,
              from: item.from, to: item.to, date: item.dateReceived ?? now,
              bodyText: '[Prévia experimental do Exchange: corpo pode estar incompleto; anexos não são importados. Consulte a mensagem original.]\n\n$body',
              isRead: item.read, isPermanentRetained: false,
            );
            final metadata = {'email': message.toJson(), 'exchangePreview': true,
              'bodyMayBeIncomplete': item.body == null || item.bodyTruncated,
              'attachmentCount': item.attachments.length};
            await db.into(db.inboxEntries).insert(InboxEntriesCompanion.insert(
              id: id, content: '${message.subject}\n\n$body',
              sourceType: const drift.Value('email'),
              suggestedCategory: const drift.Value('email_jw'),
              capturedAt: message.date, metadata: drift.Value(jsonEncode(metadata)),
              createdAt: now, updatedAt: now));
            saved++;
          }
          await db.into(db.appKvStore).insertOnConflictUpdate(AppKvStoreCompanion.insert(
            key: keyId, value: result.syncKey, updatedAt: drift.Value(now)));
        });
        key = result.syncKey;
        // EAS initial key negotiation is followed by a fetch even if the first
        // response has no MoreAvailable flag.
        more = initial || result.moreAvailable;
      }
      return ExchangeReadResult(saved, more);
    } on ExchangeException {
      rethrow;
    } on eas.EasRemoteWipeException {
      throw const ExchangeException('O servidor solicita ação de segurança no dispositivo. Procure o administrador; nada foi apagado ou confirmado pelo aplicativo.');
    } on eas.EasAuthException {
      throw const ExchangeException('Autenticação Exchange recusada. Confirme o método de acesso permitido com o administrador.');
    } on eas.EasForbiddenException {
      throw const ExchangeException('Acesso Exchange negado. Confirme a permissão para este dispositivo com o administrador.');
    } on eas.EasCommandException catch (e) {
      if (e.requiresProvisioning) {
        throw const ExchangeException('O servidor exige políticas de dispositivo que este aplicativo ainda não aplica. Procure o administrador.');
      }
      throw ExchangeException('Falha no comando Exchange (HTTP ${e.statusCode ?? '-'}, código ${e.easStatus ?? '-'}).');
    } on TimeoutException {
      throw const ExchangeException('Tempo esgotado na conexão Exchange.');
    } catch (_) {
      throw const ExchangeException('Não foi possível conectar ou ler o Exchange. Confira o servidor, a rede e a autenticação.');
    } finally {
      session.close();
    }
  }
}
