import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../core/app_logger.dart';
import '../core/sync_timestamp.dart';
import '../database/app_database.dart';
import 'oauth_token_store.dart';

/// Tipo de provedor de correio suportado
enum EmailProviderType {
  jwpub('JWPUB Oficial', 'mail.jw.org'),
  google('Google (Gmail)', 'imap.gmail.com'),
  hotmail('Hotmail / Outlook', 'outlook.office365.com'),
  exchange('Exchange ActiveSync', 'outlook.office365.com'),
  custom('Outro Provedor (IMAP/SMTP)', '');

  final String label;
  final String defaultHost;
  const EmailProviderType(this.label, this.defaultHost);
}

/// Modelo de conta de e-mail (Multi-contas no Field Assistant estilo Outlook)
class EmailAccount {
  final String id;
  final String name;
  final String email;
  final EmailProviderType providerType;
  final String incomingHost;
  final int incomingPort;
  final String
  incomingProtocol; // 'imap', 'exchange', 'gmail_api' ou 'microsoft_graph'
  final String outgoingHost;
  final int outgoingPort;
  final String outgoingSecurity; // 'starttls' ou 'ssl'
  final String
  outgoingProtocol; // 'smtp', 'exchange', 'gmail_api' ou 'microsoft_graph'
  final String username;
  final bool isActive;
  final DateTime createdAt;
  final String signatureHtml;

  const EmailAccount({
    required this.id,
    required this.name,
    required this.email,
    required this.providerType,
    required this.incomingHost,
    this.incomingPort = 993,
    this.incomingProtocol = 'imap',
    required this.outgoingHost,
    this.outgoingPort = 587,
    this.outgoingSecurity = 'starttls',
    String? outgoingProtocol,
    required this.username,
    this.isActive = true,
    required this.createdAt,
    this.signatureHtml = '',
  }) : outgoingProtocol =
           outgoingProtocol ??
           (incomingProtocol == 'exchange'
               ? 'exchange'
               : (incomingProtocol == 'gmail_api'
                     ? 'gmail_api'
                     : (incomingProtocol == 'microsoft_graph'
                           ? 'microsoft_graph'
                           : 'smtp')));

  bool get isOAuth =>
      incomingProtocol == 'gmail_api' || incomingProtocol == 'microsoft_graph';
  bool get isGmailApi => incomingProtocol == 'gmail_api';
  bool get isMicrosoftGraph => incomingProtocol == 'microsoft_graph';
  bool get isExchange => incomingProtocol == 'exchange';
  bool get isImap => incomingProtocol == 'imap';
  bool get supportsDirectBrowserSync => isGmailApi || isMicrosoftGraph;

  factory EmailAccount.fromDbEntry(EmailAccountDbEntry row) {
    var prov = EmailProviderType.custom;
    for (final p in EmailProviderType.values) {
      if (p.name == row.providerType) {
        prov = p;
        break;
      }
    }
    return EmailAccount(
      id: row.id,
      name: row.name,
      email: row.email,
      providerType: prov,
      incomingHost: row.incomingHost,
      incomingPort: row.incomingPort,
      incomingProtocol: row.incomingProtocol,
      outgoingHost: row.outgoingHost,
      outgoingPort: row.outgoingPort,
      outgoingSecurity: row.outgoingSecurity,
      outgoingProtocol: row.outgoingProtocol,
      username: row.username,
      isActive: row.isActive,
      createdAt: row.createdAt,
      signatureHtml: row.signatureHtml,
    );
  }

  EmailAccountsCompanion toDbCompanion({
    required DateTime updatedAt,
    int revision = 1,
    DateTime? deletedAt,
  }) {
    return EmailAccountsCompanion(
      id: drift.Value(id),
      name: drift.Value(name),
      email: drift.Value(email),
      providerType: drift.Value(providerType.name),
      incomingHost: drift.Value(incomingHost),
      incomingPort: drift.Value(incomingPort),
      incomingProtocol: drift.Value(incomingProtocol),
      outgoingHost: drift.Value(outgoingHost),
      outgoingPort: drift.Value(outgoingPort),
      outgoingSecurity: drift.Value(outgoingSecurity),
      outgoingProtocol: drift.Value(outgoingProtocol),
      username: drift.Value(username),
      isActive: drift.Value(isActive),
      signatureHtml: drift.Value(signatureHtml),
      createdAt: drift.Value(createdAt),
      updatedAt: drift.Value(updatedAt),
      deletedAt: drift.Value(deletedAt),
      revision: drift.Value(revision),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'providerType': providerType.name,
    'incomingHost': incomingHost,
    'incomingPort': incomingPort,
    'incomingProtocol': incomingProtocol,
    'outgoingHost': outgoingHost,
    'outgoingPort': outgoingPort,
    'outgoingSecurity': outgoingSecurity,
    'outgoingProtocol': outgoingProtocol,
    'username': username,
    'isActive': isActive,
    'createdAt': createdAt.toIso8601String(),
    'signatureHtml': signatureHtml,
  };

  EmailAccount copyWith({
    String? id,
    String? name,
    String? email,
    EmailProviderType? providerType,
    String? incomingHost,
    int? incomingPort,
    String? incomingProtocol,
    String? outgoingHost,
    int? outgoingPort,
    String? outgoingSecurity,
    String? outgoingProtocol,
    String? username,
    bool? isActive,
    DateTime? createdAt,
    String? signatureHtml,
  }) {
    return EmailAccount(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      providerType: providerType ?? this.providerType,
      incomingHost: incomingHost ?? this.incomingHost,
      incomingPort: incomingPort ?? this.incomingPort,
      incomingProtocol: incomingProtocol ?? this.incomingProtocol,
      outgoingHost: outgoingHost ?? this.outgoingHost,
      outgoingPort: outgoingPort ?? this.outgoingPort,
      outgoingSecurity: outgoingSecurity ?? this.outgoingSecurity,
      outgoingProtocol: outgoingProtocol ?? this.outgoingProtocol,
      username: username ?? this.username,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      signatureHtml: signatureHtml ?? this.signatureHtml,
    );
  }

  factory EmailAccount.fromJson(Map<String, dynamic> json) {
    EmailProviderType prov = EmailProviderType.custom;
    final provName = json['providerType'] as String? ?? 'custom';
    for (final p in EmailProviderType.values) {
      if (p.name == provName) {
        prov = p;
        break;
      }
    }

    final incomingProtocol = json['incomingProtocol'] as String? ?? 'imap';
    final outgoingProtocol =
        json['outgoingProtocol'] as String? ??
        (incomingProtocol == 'exchange'
            ? 'exchange'
            : (incomingProtocol == 'gmail_api'
                  ? 'gmail_api'
                  : (incomingProtocol == 'microsoft_graph'
                        ? 'microsoft_graph'
                        : 'smtp')));

    return EmailAccount(
      id: json['id'] as String? ?? const Uuid().v4(),
      name: json['name'] as String? ?? 'Conta de E-mail',
      email: json['email'] as String? ?? '',
      providerType: prov,
      incomingHost: json['incomingHost'] as String? ?? '',
      incomingPort: json['incomingPort'] as int? ?? 993,
      incomingProtocol: incomingProtocol,
      outgoingHost: json['outgoingHost'] as String? ?? '',
      outgoingPort: json['outgoingPort'] as int? ?? 587,
      outgoingSecurity: json['outgoingSecurity'] as String? ?? 'starttls',
      outgoingProtocol: outgoingProtocol,
      username: json['username'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      signatureHtml: (json['signatureHtml'] as String?) ?? '',
    );
  }

  /// Gera predefinição de configuração recomendada baseada no provedor
  static EmailAccount createPreset({
    String? id,
    required EmailProviderType providerType,
    required String name,
    required String email,
    required String username,
    String? customHost,
  }) {
    final now = DateTime.now();
    final effectiveId = id ?? const Uuid().v4();
    switch (providerType) {
      case EmailProviderType.jwpub:
        return EmailAccount(
          id: effectiveId,
          name: name.isNotEmpty ? name : 'JWPUB Oficial',
          email: email,
          providerType: EmailProviderType.jwpub,
          incomingHost: customHost?.isNotEmpty == true
              ? customHost!
              : 'mail.jw.org',
          incomingPort: 993,
          incomingProtocol: 'imap',
          outgoingHost: customHost?.isNotEmpty == true
              ? customHost!
              : 'mail.jw.org',
          outgoingPort: 587,
          outgoingSecurity: 'starttls',
          username: username,
          createdAt: now,
        );
      case EmailProviderType.google:
        return EmailAccount(
          id: effectiveId,
          name: name.isNotEmpty ? name : 'Google (Gmail)',
          email: email,
          providerType: EmailProviderType.google,
          incomingHost: 'imap.gmail.com',
          incomingPort: 993,
          incomingProtocol: 'imap',
          outgoingHost: 'smtp.gmail.com',
          outgoingPort: 587,
          outgoingSecurity: 'starttls',
          username: username,
          createdAt: now,
        );
      case EmailProviderType.hotmail:
        return EmailAccount(
          id: effectiveId,
          name: name.isNotEmpty ? name : 'Hotmail / Outlook',
          email: email,
          providerType: EmailProviderType.hotmail,
          incomingHost: 'outlook.office365.com',
          incomingPort: 993,
          incomingProtocol: 'imap',
          outgoingHost: 'smtp.office365.com',
          outgoingPort: 587,
          outgoingSecurity: 'starttls',
          username: username,
          createdAt: now,
        );
      case EmailProviderType.exchange:
        return EmailAccount(
          id: effectiveId,
          name: name.isNotEmpty ? name : 'Exchange Corporativo',
          email: email,
          providerType: EmailProviderType.exchange,
          incomingHost: customHost?.isNotEmpty == true
              ? customHost!
              : 'outlook.office365.com',
          incomingPort: 443,
          incomingProtocol: 'exchange',
          outgoingHost: customHost?.isNotEmpty == true
              ? customHost!
              : 'outlook.office365.com',
          outgoingPort: 443,
          outgoingSecurity: 'ssl',
          username: username,
          createdAt: now,
        );
      case EmailProviderType.custom:
        return EmailAccount(
          id: effectiveId,
          name: name.isNotEmpty ? name : 'Personalizado',
          email: email,
          providerType: EmailProviderType.custom,
          incomingHost: customHost ?? '',
          incomingPort: 993,
          incomingProtocol: 'imap',
          outgoingHost: customHost ?? '',
          outgoingPort: 587,
          outgoingSecurity: 'starttls',
          username: username,
          createdAt: now,
        );
    }
  }
}

/// Gerenciador central de Multi-Contas de e-mail.
/// Persiste metadados de conta (sem senhas nem tokens OAuth) na tabela tipada `email_accounts`
/// com fila de sincronização E2EE multi-dispositivos, mantendo senhas/tokens estritamente locais.
class EmailAccountsManager {
  static const String _accountsKvKey = 'multi_email_accounts_registry';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static const String legacyImapAccountId = 'legacy_imap_account';
  static const String legacyEasAccountId = 'legacy_eas_account';

  static String _passwordKey(String accountId) =>
      'email_acc_${accountId}_password';

  static Future<void> _enqueueSync(
    AppDatabase db, {
    required String operation,
    required EmailAccountDbEntry entry,
    Map<String, dynamic>? baseData,
  }) async {
    final now = DateTime.now();
    final payload = SyncTimestamp.normalizeMapDates(entry.toJson());
    // Garantia defensiva extra: nunca gravar senha ou tokens em sync_queue.
    payload.remove('password');
    payload.remove('accessToken');
    payload.remove('refreshToken');
    if (baseData != null) {
      payload['_base'] = SyncTimestamp.normalizeMapDates(baseData);
    }
    await db
        .into(db.syncQueue)
        .insert(
          SyncQueueCompanion.insert(
            id: const Uuid().v4(),
            entityType: 'email_accounts',
            entityId: entry.id,
            operation: operation,
            payload: jsonEncode(payload),
            createdAt: now,
          ),
        );
  }

  static Future<void> _syncKvMirror(
    AppDatabase db,
    List<EmailAccount> activeAccounts,
  ) async {
    final encoded = jsonEncode(activeAccounts.map((a) => a.toJson()).toList());
    await db
        .into(db.appKvStore)
        .insertOnConflictUpdate(
          AppKvStoreCompanion.insert(
            key: _accountsKvKey,
            value: encoded,
            updatedAt: drift.Value(DateTime.now()),
          ),
        );
  }

  /// Observa contas de e-mail ativas reativamente (atualiza ao receber via E2EE).
  static Stream<List<EmailAccount>> watchAccounts(AppDatabase db) {
    final query = db.select(db.emailAccounts)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([(t) => drift.OrderingTerm.asc(t.createdAt)]);
    return query.watch().map(
      (rows) => rows
          .map(EmailAccount.fromDbEntry)
          .where((a) => a.email.isNotEmpty)
          .toList(),
    );
  }

  /// Verifica se este dispositivo possui credencial local (senha ou token OAuth) para [account].
  static Future<bool> hasLocalCredentials(
    EmailAccount account, [
    AppDatabase? db,
  ]) async {
    if (account.isOAuth) {
      try {
        final bundle = await const OAuthTokenStore().readTokenBundle(
          account.id,
        );
        if (bundle == null) return false;
        final hasRefresh =
            bundle.refreshToken != null && bundle.refreshToken!.isNotEmpty;
        return !bundle.isExpired || hasRefresh;
      } catch (e, st) {
        AppLogger.debug(
          'Falha ao consultar OAuth local para ${account.id}: $e',
          st,
        );
        return false;
      }
    }
    final pass = await getAccountPassword(account.id, db);
    return pass != null && pass.trim().isNotEmpty;
  }

  /// Carrega todas as contas de e-mail cadastradas (migra automaticamente de KV legado se necessário).
  static Future<List<EmailAccount>> loadAccounts(AppDatabase db) async {
    final typedRows =
        await (db.select(db.emailAccounts)
              ..where((t) => t.deletedAt.isNull())
              ..orderBy([(t) => drift.OrderingTerm.asc(t.createdAt)]))
            .get();

    if (typedRows.isNotEmpty) {
      return typedRows
          .map(EmailAccount.fromDbEntry)
          .where((a) => a.email.isNotEmpty)
          .toList();
    }

    // Fallback de promoção única caso o KV tenha contas ainda não gravadas em `email_accounts`.
    final accounts = <EmailAccount>[];
    final row = await (db.select(
      db.appKvStore,
    )..where((t) => t.key.equals(_accountsKvKey))).getSingleOrNull();
    if (row != null && row.value.isNotEmpty) {
      try {
        final decoded = jsonDecode(row.value);
        if (decoded is List) {
          accounts.addAll(
            decoded
                .map(
                  (e) => EmailAccount.fromJson(
                    Map<String, dynamic>.from(e as Map),
                  ),
                )
                .where((a) => a.email.isNotEmpty),
          );
        }
      } catch (e, st) {
        AppLogger.warning(
          'JSON inválido ao carregar registro legado $_accountsKvKey',
          e,
          st,
        );
      }
    }

    if (accounts.isEmpty) {
      final legacyImapEmail = await (db.select(
        db.appKvStore,
      )..where((t) => t.key.equals('jw_imap_email'))).getSingleOrNull();
      final legacyEasEmail = await (db.select(
        db.appKvStore,
      )..where((t) => t.key.equals('jw_eas_email'))).getSingleOrNull();
      final protocol = await (db.select(
        db.appKvStore,
      )..where((t) => t.key.equals('jw_mail_protocol'))).getSingleOrNull();

      if (protocol?.value == 'exchange' &&
          legacyEasEmail?.value.isNotEmpty == true) {
        final host = await (db.select(
          db.appKvStore,
        )..where((t) => t.key.equals('jw_eas_host'))).getSingleOrNull();
        accounts.add(
          EmailAccount.createPreset(
            id: legacyEasAccountId,
            providerType: EmailProviderType.exchange,
            name: 'Exchange Principal',
            email: legacyEasEmail!.value,
            username: legacyEasEmail.value,
            customHost: host?.value,
          ),
        );
      } else if (legacyImapEmail?.value.isNotEmpty == true) {
        final host = await (db.select(
          db.appKvStore,
        )..where((t) => t.key.equals('jw_imap_host'))).getSingleOrNull();
        accounts.add(
          EmailAccount.createPreset(
            id: legacyImapAccountId,
            providerType: EmailProviderType.jwpub,
            name: 'JWPUB Principal',
            email: legacyImapEmail!.value,
            username: legacyImapEmail.value,
            customHost: host?.value,
          ),
        );
      }
    }

    if (accounts.isNotEmpty) {
      final now = DateTime.now();
      await db.transaction(() async {
        for (final acc in accounts) {
          final existing = await (db.select(
            db.emailAccounts,
          )..where((t) => t.id.equals(acc.id))).getSingleOrNull();
          if (existing != null) continue;
          await db
              .into(db.emailAccounts)
              .insert(acc.toDbCompanion(updatedAt: now));
          final inserted = await (db.select(
            db.emailAccounts,
          )..where((t) => t.id.equals(acc.id))).getSingle();
          await _enqueueSync(db, operation: 'INSERT', entry: inserted);
        }
      });
    }

    return accounts;
  }

  /// Salva uma conta (metadados sincronizados via E2EE sem senha) e senha local no cofre seguro,
  /// deduplicando por `(username, incomingProtocol)`.
  static Future<void> saveAccount(
    AppDatabase db,
    EmailAccount account, {
    String? password,
  }) async {
    final now = DateTime.now();
    final existing = await loadAccounts(db);
    final targetUser =
        (account.username.trim().isNotEmpty
                ? account.username.trim()
                : account.email.trim())
            .toLowerCase();
    final targetProtocol = account.incomingProtocol;

    final result = <EmailAccount>[account];
    final seenKeys = <String>{};
    if (targetUser.isNotEmpty) {
      seenKeys.add('$targetUser::$targetProtocol');
    }

    final duplicateIdsToDelete = <String>[];
    for (final a in existing) {
      if (a.id == account.id) continue;
      final u =
          (a.username.trim().isNotEmpty ? a.username.trim() : a.email.trim())
              .toLowerCase();
      final key = '$u::${a.incomingProtocol}';
      if (u.isNotEmpty && seenKeys.contains(key)) {
        duplicateIdsToDelete.add(a.id);
        continue;
      }
      if (u.isNotEmpty) seenKeys.add(key);
      result.add(a);
    }

    await db.transaction(() async {
      // Marca duplicatas substituídas com soft-delete e enfileira tombstone E2EE.
      for (final dupId in duplicateIdsToDelete) {
        final dupRow = await (db.select(
          db.emailAccounts,
        )..where((t) => t.id.equals(dupId))).getSingleOrNull();
        if (dupRow != null && dupRow.deletedAt == null) {
          await (db.update(
            db.emailAccounts,
          )..where((t) => t.id.equals(dupId))).write(
            EmailAccountsCompanion(
              deletedAt: drift.Value(now),
              updatedAt: drift.Value(now),
              revision: drift.Value(dupRow.revision + 1),
            ),
          );
          final deletedRow = await (db.select(
            db.emailAccounts,
          )..where((t) => t.id.equals(dupId))).getSingle();
          await _enqueueSync(
            db,
            operation: 'DELETE',
            entry: deletedRow,
            baseData: dupRow.toJson(),
          );
        }
      }

      final prevRow = await (db.select(
        db.emailAccounts,
      )..where((t) => t.id.equals(account.id))).getSingleOrNull();
      final nextRev = prevRow == null ? 1 : prevRow.revision + 1;
      final comp = account.toDbCompanion(
        updatedAt: now,
        revision: nextRev,
        deletedAt: null,
      );
      await db.into(db.emailAccounts).insertOnConflictUpdate(comp);
      final persisted = await (db.select(
        db.emailAccounts,
      )..where((t) => t.id.equals(account.id))).getSingle();

      await _enqueueSync(
        db,
        operation: prevRow == null ? 'INSERT' : 'UPDATE',
        entry: persisted,
        baseData: prevRow?.toJson(),
      );
      await _syncKvMirror(db, result);
    });

    if (password != null && password.isNotEmpty) {
      await _secureStorage.write(
        key: _passwordKey(account.id),
        value: password,
      );
    }
  }

  /// Atualiza apenas a senha local deste dispositivo sem alterar os metadados sincronizados.
  static Future<void> setLocalAccountPassword(
    String accountId,
    String password,
  ) async {
    final clean = password.trim();
    if (clean.isEmpty) return;
    await _secureStorage.write(key: _passwordKey(accountId), value: clean);
  }

  /// Recupera a senha armazenada com criptografia de hardware (estritamente local).
  static Future<String?> getAccountPassword(
    String accountId, [
    AppDatabase? db,
  ]) async {
    final direct = await _secureStorage.read(key: _passwordKey(accountId));
    if (direct != null && direct.isNotEmpty) return direct;

    if (accountId == legacyEasAccountId ||
        accountId.contains('eas') ||
        accountId.contains('exchange')) {
      final easPass = await _secureStorage.read(key: 'jw_eas_password');
      if (easPass != null && easPass.isNotEmpty) return easPass;
      final altEasPass = await _secureStorage.read(key: 'eas_password');
      if (altEasPass != null && altEasPass.isNotEmpty) return altEasPass;
    }

    final imapPass = await _secureStorage.read(key: 'jw_imap_password');
    if (imapPass != null && imapPass.isNotEmpty) return imapPass;

    if (db != null) {
      final legacyRow = await (db.select(
        db.appKvStore,
      )..where((t) => t.key.equals('jw_imap_password'))).getSingleOrNull();
      if (legacyRow != null && legacyRow.value.isNotEmpty) {
        return legacyRow.value;
      }
      final legacyEasRow = await (db.select(
        db.appKvStore,
      )..where((t) => t.key.equals('jw_eas_password'))).getSingleOrNull();
      if (legacyEasRow != null && legacyEasRow.value.isNotEmpty) {
        return legacyEasRow.value;
      }
    }

    return null;
  }

  /// Remove uma conta cadastrada (propaga tombstone E2EE entre aparelhos) e limpa credenciais locais.
  static Future<void> deleteAccount(AppDatabase db, String accountId) async {
    final now = DateTime.now();
    await db.transaction(() async {
      final existingRow = await (db.select(
        db.emailAccounts,
      )..where((t) => t.id.equals(accountId))).getSingleOrNull();
      if (existingRow != null && existingRow.deletedAt == null) {
        await (db.update(
          db.emailAccounts,
        )..where((t) => t.id.equals(accountId))).write(
          EmailAccountsCompanion(
            deletedAt: drift.Value(now),
            updatedAt: drift.Value(now),
            revision: drift.Value(existingRow.revision + 1),
          ),
        );
        final updatedRow = await (db.select(
          db.emailAccounts,
        )..where((t) => t.id.equals(accountId))).getSingle();
        await _enqueueSync(
          db,
          operation: 'DELETE',
          entry: updatedRow,
          baseData: existingRow.toJson(),
        );
      }

      final active = await (db.select(
        db.emailAccounts,
      )..where((t) => t.deletedAt.isNull())).get();
      await _syncKvMirror(db, active.map(EmailAccount.fromDbEntry).toList());
    });

    try {
      await _secureStorage.delete(key: _passwordKey(accountId));
    } catch (e, st) {
      AppLogger.warning(
        'Falha ao limpar senha local ao remover conta $accountId',
        e,
        st,
      );
    }
    try {
      await OAuthTokenStore(secureStorage: _secureStorage)
          .deleteTokenBundle(accountId);
    } catch (e, st) {
      AppLogger.warning(
        'Falha ao limpar token OAuth local ao remover conta $accountId',
        e,
        st,
      );
    }
  }
}
