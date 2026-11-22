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
          );
          final saved = await persistSyncedMessages(messages, 'gmail_api');
          totalSaved += saved;
          synced++;
        } else if (acc.incomingProtocol == 'microsoft_graph') {
          final service = MicrosoftOAuthService();
          final messages = await service.fetchMessages(
            accountId: acc.id,
            accountEmail: acc.email,
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
        failed.add('${acc.name}: $e');
      }
    }

    return EmailSyncResult(
      accountsSynced: synced,
      totalMessagesSaved: totalSaved,
      failedDetails: failed,
    );
  }
}
