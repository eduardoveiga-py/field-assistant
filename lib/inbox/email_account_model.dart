import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

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
  };

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
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EmailAccount &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

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

/// Gerenciador central de Multi-Contas de e-mail
class EmailAccountsManager {
  static const String _accountsKvKey = 'multi_email_accounts_registry';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static const String legacyImapAccountId = 'legacy_imap_account';
  static const String legacyEasAccountId = 'legacy_eas_account';

  static String _passwordKey(String accountId) =>
      'email_acc_${accountId}_password';

  /// Carrega todas as contas de e-mail cadastradas
  static Future<List<EmailAccount>> loadAccounts(AppDatabase db) async {
    final row = await (db.select(
      db.appKvStore,
    )..where((t) => t.key.equals(_accountsKvKey))).getSingleOrNull();

    final accounts = <EmailAccount>[];
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
      } catch (_) {}
    }

    // Se nenhuma conta estiver no multi-registro, sincroniza a conta primária legada se existir
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
        final acc = EmailAccount.createPreset(
          id: legacyEasAccountId,
          providerType: EmailProviderType.exchange,
          name: 'Exchange Principal',
          email: legacyEasEmail!.value,
          username: legacyEasEmail.value,
          customHost: host?.value,
        );
        accounts.add(acc);
      } else if (legacyImapEmail?.value.isNotEmpty == true) {
        final host = await (db.select(
          db.appKvStore,
        )..where((t) => t.key.equals('jw_imap_host'))).getSingleOrNull();
        final acc = EmailAccount.createPreset(
          id: legacyImapAccountId,
          providerType: EmailProviderType.jwpub,
          name: 'JWPUB Principal',
          email: legacyImapEmail!.value,
          username: legacyImapEmail.value,
          customHost: host?.value,
        );
        accounts.add(acc);
      }
    }

    return accounts;
  }

  /// Salva uma conta e sua senha de forma segura
  static Future<void> saveAccount(
    AppDatabase db,
    EmailAccount account, {
    String? password,
  }) async {
    final existing = await loadAccounts(db);
    final map = {for (final a in existing) a.id: a};
    map[account.id] = account;

    final encoded = jsonEncode(map.values.map((a) => a.toJson()).toList());
    await db
        .into(db.appKvStore)
        .insertOnConflictUpdate(
          AppKvStoreCompanion.insert(
            key: _accountsKvKey,
            value: encoded,
            updatedAt: drift.Value(DateTime.now()),
          ),
        );

    if (password != null && password.isNotEmpty) {
      await _secureStorage.write(
        key: _passwordKey(account.id),
        value: password,
      );
    }
  }

  /// Recupera a senha armazenada com criptografia de hardware
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

  /// Remove uma conta cadastrada e suas credenciais
  static Future<void> deleteAccount(AppDatabase db, String accountId) async {
    final existing = await loadAccounts(db);
    final filtered = existing.where((a) => a.id != accountId).toList();

    final encoded = jsonEncode(filtered.map((a) => a.toJson()).toList());
    await db
        .into(db.appKvStore)
        .insertOnConflictUpdate(
          AppKvStoreCompanion.insert(
            key: _accountsKvKey,
            value: encoded,
            updatedAt: drift.Value(DateTime.now()),
          ),
        );

    try {
      await _secureStorage.delete(key: _passwordKey(accountId));
    } catch (_) {}
    try {
      await OAuthTokenStore(secureStorage: _secureStorage)
          .deleteTokenBundle(accountId);
    } catch (_) {}
  }
}
