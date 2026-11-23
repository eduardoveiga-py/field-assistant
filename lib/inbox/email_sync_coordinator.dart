import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../core/app_logger.dart';
import '../core/biometric_auth_service.dart';
import '../core/sync_timestamp.dart';
import '../database/app_database.dart';
import 'email_account_model.dart';
import 'email_contacts_manager.dart';
import 'exchange_service.dart';
import 'gmail_oauth_service.dart';
import 'jw_email_service.dart';
import 'microsoft_oauth_service.dart';

/// Resultado consolidado da sincronização de contas de e-mail
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

/// Coordenador unificado de sincronização de e-mails para todas as contas ativas
class EmailSyncCoordinator {
  final AppDatabase db;
  final JwEmailService? jwEmailService;
  final ExchangeReadService? exchangeService;

  EmailSyncCoordinator(this.db, {this.jwEmailService, this.exchangeService});

  /// Formata exceções de sincronização em mensagens amigáveis e orientativas
  static String friendlyErrorMessage(Object e, [EmailAccount? acc]) {
    final msg = e.toString().toLowerCase();
    final isAuthError =
        e is JwEmailAuthException ||
        msg.contains('401') ||
        msg.contains('auth') ||
        msg.contains('autenticação') ||
        msg.contains('senha') ||
        msg.contains('credencia');

    final isGmail =
        (acc != null &&
            (acc.email.toLowerCase().contains('gmail') ||
                acc.incomingHost.toLowerCase().contains('gmail'))) ||
        msg.contains('gmail');

    final isMicrosoft =
        (acc != null &&
            (acc.email.toLowerCase().contains('outlook') ||
                acc.email.toLowerCase().contains('hotmail') ||
                acc.incomingHost.toLowerCase().contains('outlook') ||
                acc.incomingHost.toLowerCase().contains('office365'))) ||
        msg.contains('outlook') ||
        msg.contains('hotmail') ||
        msg.contains('office365');

    if (isAuthError) {
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

  /// Persiste mensagens sincronizadas no banco local preservando integridade e idempotência
  Future<int> persistSyncedMessages(
    List<JwEmailMessage> messages,
    String protocol,
  ) async {
    var savedCount = 0;
    final now = DateTime.now().toUtc();
    for (final msg in messages) {
      final entryId = msg.id.startsWith('email_') ? msg.id : 'email_${msg.id}';
      final existing = await (db.select(
        db.inboxEntries,
      )..where((t) => t.id.equals(entryId))).getSingleOrNull();

      if (existing != null) continue;

      final metadata = {
        'permanentRetention': true,
        'retentionDate': now.toIso8601String(),
        'email': msg.toJson(),
        'protocol': protocol,
      };

      await db
          .into(db.inboxEntries)
          .insert(
            InboxEntriesCompanion.insert(
              id: entryId,
              content: '${msg.subject}\n\n${msg.bodyText}',
              sourceType: const drift.Value('email'),
              suggestedCategory: const drift.Value('email_jw'),
              attachments: drift.Value(jsonEncode(msg.attachments)),
              capturedAt: msg.date.toUtc(),
              metadata: drift.Value(jsonEncode(metadata)),
              createdAt: now,
              updatedAt: now,
              revision: const drift.Value(1),
            ),
          );

      try {
        final inserted = await (db.select(
          db.inboxEntries,
        )..where((t) => t.id.equals(entryId))).getSingle();
        await db
            .into(db.syncQueue)
            .insert(
              SyncQueueCompanion.insert(
                id: const Uuid().v4(),
                entityType: 'inbox_entries',
                entityId: entryId,
                operation: 'INSERT',
                payload: jsonEncode(
                  SyncTimestamp.normalizeMapDates(inserted.toJson()),
                ),
                createdAt: now,
              ),
            );
      } catch (_) {}

      await EmailContactsManager.recordSender(db, msg.from);
      savedCount++;
    }
    return savedCount;
  }

  /// Executa a sincronização de todas as contas ativas cadastradas
  Future<EmailSyncResult> syncAll() async {
    final accounts = await EmailAccountsManager.loadAccounts(db);
    if (accounts.isEmpty) {
      return const EmailSyncResult(
        accountsSynced: 0,
        totalMessagesSaved: 0,
        failedDetails: [],
      );
    }

    var totalSaved = 0;
    var synced = 0;
    final failed = <String>[];

    for (final acc in accounts) {
      if (!acc.isActive) continue;
      try {
        if (acc.incomingProtocol == 'gmail_api') {
          final service = GmailOAuthService();
          final messages = await service.fetchMessages(
            accountId: acc.id,
            accountEmail: acc.email,
            maxResults: 200,
          );
          final saved = await persistSyncedMessages(messages, 'gmail_api');
          totalSaved += saved;
          synced++;
        } else if (acc.incomingProtocol == 'microsoft_graph') {
          final service = MicrosoftOAuthService();
          final messages = await service.fetchMessages(
            accountId: acc.id,
            accountEmail: acc.email,
            maxResults: 200,
          );
          final saved = await persistSyncedMessages(
            messages,
            'microsoft_graph',
          );
          totalSaved += saved;
          synced++;
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
}
