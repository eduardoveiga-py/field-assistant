import 'dart:async';
import 'dart:convert';
import 'dart:typed_data' show Uint8List;
import 'dart:io'
    show
        InternetAddress,
        SecureSocket,
        Socket,
        SocketException,
        TlsException,
        X509Certificate;

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:drift/drift.dart' as drift;
import 'package:intl/intl.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:collection/collection.dart';
import 'package:enough_mail/imap.dart' as mail;
import 'package:uuid/uuid.dart';

import '../core/app_logger.dart';
import '../core/biometric_auth_service.dart';
import '../core/sync_timestamp.dart';
import '../database/app_database.dart';
import '../reports/knowledge_and_email_pdf_service.dart';
import '../reports/web_downloader.dart';
import 'email_account_model.dart';
import 'email_contacts_manager.dart';
import 'email_html_sanitizer.dart';

/// Modelo de mensagem de e-mail teocrático (JW.org Mail e Comunicações Restritas do Hub)
class JwEmailMessage {
  final String id;
  final int? remoteUid;
  final String? folderId;
  final String? folderName;
  final String subject;
  final String from;
  final String to;
  final List<String> cc;
  final List<String> bcc;
  final String? accountEmail;
  final DateTime date;
  final String bodyText;
  final String? bodyHtml;

  /// MIME original em Base64, incluindo anexos, quando obtido via IMAP.
  final String? rawEmlBase64;
  final List<Map<String, dynamic>> attachments;
  final bool isRead;
  final bool isDraft;
  final bool isPermanentRetained;
  final List<String> tags;
  final List<String> labels;
  final bool isHubCommunication;
  final String? hubType; // 'letter', 'announcement', 'form', 'policy'
  /// Indica carga leve (apenas metadados de estado, sem re-baixar corpo/anexos).
  final bool isMetadataOnly;

  JwEmailMessage({
    required this.id,
    this.remoteUid,
    this.folderId,
    this.folderName,
    required this.subject,
    required this.from,
    required this.to,
    this.cc = const [],
    this.bcc = const [],
    this.accountEmail,
    required this.date,
    required this.bodyText,
    this.bodyHtml,
    this.rawEmlBase64,
    this.attachments = const [],
    this.isRead = false,
    this.isDraft = false,
    this.isPermanentRetained = true,
    this.tags = const [],
    this.labels = const [],
    this.isHubCommunication = false,
    this.hubType,
    this.isMetadataOnly = false,
  });

  /// Remove `rawBytes` (`Uint8List`) e converte eventuais buffers binários antes da persistência em JSON/SQLite,
  /// evitando serialização de arrays inteiros gigantes na Web/IndexedDB e no SyncQueue.
  static List<Map<String, dynamic>> sanitizeAttachmentsForPersistence(
    List<Map<String, dynamic>> attachments,
  ) {
    if (attachments.isEmpty) return const [];
    return attachments.map((att) {
      final clean = <String, dynamic>{};
      for (final entry in att.entries) {
        if (entry.key == 'rawBytes') continue;
        final v = entry.value;
        if (v is Uint8List) continue;
        clean[entry.key] = v;
      }
      return clean;
    }).toList();
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'remoteUid': remoteUid,
    'folderId': folderId,
    'folderName': folderName,
    'subject': subject,
    'from': from,
    'to': to,
    'cc': cc,
    'bcc': bcc,
    'accountEmail': accountEmail,
    'date': date.toIso8601String(),
    'bodyText': bodyText,
    'bodyHtml': bodyHtml,
    'rawEmlBase64': rawEmlBase64,
    'attachments': sanitizeAttachmentsForPersistence(attachments),
    'isRead': isRead,
    'isDraft': isDraft,
    'isPermanentRetained': isPermanentRetained,
    'tags': tags,
    'labels': labels,
    'isHubCommunication': isHubCommunication,
    'hubType': hubType,
  };

  factory JwEmailMessage.fromJson(Map<String, dynamic> json) => JwEmailMessage(
    id: json['id'] as String? ?? const Uuid().v4(),
    remoteUid: json['remoteUid'] as int?,
    folderId: json['folderId'] as String?,
    folderName: json['folderName'] as String?,
    subject: json['subject'] as String? ?? '(Sem Assunto)',
    from: json['from'] as String? ?? 'jw@jw.org',
    to: json['to'] as String? ?? '',
    cc:
        (json['cc'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
        const [],
    bcc:
        (json['bcc'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
        const [],
    accountEmail: json['accountEmail'] as String?,
    date: json['date'] != null
        ? DateTime.tryParse(json['date'] as String) ?? DateTime.now()
        : DateTime.now(),
    bodyText: json['bodyText'] as String? ?? '',
    bodyHtml: json['bodyHtml'] as String?,
    rawEmlBase64: json['rawEmlBase64'] as String?,
    attachments:
        (json['attachments'] as List<dynamic>?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        const [],
    isRead: json['isRead'] as bool? ?? false,
    isDraft: json['isDraft'] as bool? ?? false,
    isPermanentRetained: json['isPermanentRetained'] as bool? ?? true,
    tags:
        (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
        const [],
    labels:
        (json['labels'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
        const [],
    isHubCommunication: json['isHubCommunication'] as bool? ?? false,
    hubType: json['hubType'] as String?,
  );

  JwEmailMessage copyWith({
    String? id,
    int? remoteUid,
    String? folderId,
    String? folderName,
    String? subject,
    String? from,
    String? to,
    List<String>? cc,
    List<String>? bcc,
    String? accountEmail,
    DateTime? date,
    String? bodyText,
    String? bodyHtml,
    String? rawEmlBase64,
    List<Map<String, dynamic>>? attachments,
    bool? isRead,
    bool? isDraft,
    bool? isPermanentRetained,
    List<String>? tags,
    List<String>? labels,
    bool? isHubCommunication,
    String? hubType,
    bool? isMetadataOnly,
  }) {
    return JwEmailMessage(
      id: id ?? this.id,
      remoteUid: remoteUid ?? this.remoteUid,
      folderId: folderId ?? this.folderId,
      folderName: folderName ?? this.folderName,
      subject: subject ?? this.subject,
      from: from ?? this.from,
      to: to ?? this.to,
      cc: cc ?? this.cc,
      bcc: bcc ?? this.bcc,
      accountEmail: accountEmail ?? this.accountEmail,
      date: date ?? this.date,
      bodyText: bodyText ?? this.bodyText,
      bodyHtml: bodyHtml ?? this.bodyHtml,
      rawEmlBase64: rawEmlBase64 ?? this.rawEmlBase64,
      attachments: attachments ?? this.attachments,
      isRead: isRead ?? this.isRead,
      isDraft: isDraft ?? this.isDraft,
      isPermanentRetained: isPermanentRetained ?? this.isPermanentRetained,
      tags: tags ?? this.tags,
      labels: labels ?? this.labels,
      isHubCommunication: isHubCommunication ?? this.isHubCommunication,
      hubType: hubType ?? this.hubType,
      isMetadataOnly: isMetadataOnly ?? this.isMetadataOnly,
    );
  }

  /// Converte a mensagem em Markdown formatado
  String toMarkdown() {
    final buffer = StringBuffer();
    buffer.writeln('# $subject');
    buffer.writeln();
    buffer.writeln('| Campo | Informação |');
    buffer.writeln('| :--- | :--- |');
    buffer.writeln('| **De** | `$from` |');
    buffer.writeln('| **Para** | `$to` |');
    buffer.writeln(
      '| **Data** | ${DateFormat('dd/MM/yyyy HH:mm').format(date)} |',
    );
    if (tags.isNotEmpty) {
      buffer.writeln('| **Tags** | ${tags.map((t) => '`#$t`').join(' ')} |');
    }
    if (isHubCommunication) {
      buffer.writeln(
        '| **Origem** | Hub Restrito JW (${hubType ?? "Comunicação"}) |',
      );
    }
    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln();
    buffer.writeln(bodyText);
    buffer.writeln();
    if (attachments.isNotEmpty) {
      buffer.writeln('### Anexos Retidos');
      for (final att in attachments) {
        final name = att['name'] ?? 'anexo';
        final size = att['size'] != null ? ' (${att['size']} bytes)' : '';
        buffer.writeln('- 📎 **$name**$size');
      }
    }
    return buffer.toString();
  }

  /// Converte para formato padrão RFC822 / .eml
  String toEml() {
    final rfcDate = DateFormat('EEE, dd MMM yyyy HH:mm:ss +0000')
        .format(date.toUtc());
    final buffer = StringBuffer();
    buffer.writeln('From: $from');
    buffer.writeln('To: $to');
    buffer.writeln('Date: $rfcDate');
    buffer.writeln('Subject: $subject');
    buffer.writeln('MIME-Version: 1.0');
    buffer.writeln('X-JW-Retained: Permanent');
    if (isHubCommunication) {
      buffer.writeln('X-Hub-JW-Restricted: true');
    }
    buffer.writeln('Content-Type: text/plain; charset=UTF-8');
    buffer.writeln();
    buffer.writeln(bodyText);
    return buffer.toString();
  }

  /// Converte para texto plano
  String toPlainText() {
    final buffer = StringBuffer();
    buffer.writeln('ASSUNTO: $subject');
    buffer.writeln('DE: $from');
    buffer.writeln('PARA: $to');
    buffer.writeln('DATA: ${DateFormat('dd/MM/yyyy HH:mm').format(date)}');
    if (tags.isNotEmpty) buffer.writeln('TAGS: ${tags.join(', ')}');
    buffer.writeln('----------------------------------------');
    buffer.writeln(bodyText);
    return buffer.toString();
  }
}

/// Exceção base para operações do serviço de e-mail teocrático
class JwEmailException implements Exception {
  final String message;
  final dynamic cause;

  const JwEmailException(this.message, [this.cause]);

  @override
  String toString() => message;
}

/// Exceção lançada em falhas de rede, socket, timeout ou servidor inacessível
class JwEmailConnectionException extends JwEmailException {
  const JwEmailConnectionException(super.message, [super.cause]);
}

/// Exceção lançada em caso de credenciais rejeitadas ou erro de autenticação IMAP
class JwEmailAuthException extends JwEmailException {
  const JwEmailAuthException(super.message, [super.cause]);
}

/// Interface para permitir testes com sessões IMAP determinísticas.
abstract class JwImapSession {
  Future<void> connect(
    String host,
    int port,
    String username,
    String password,
    Duration timeout,
  );
  Future<int> selectInbox();
  Future<List<int>> searchUids();
  Future<List<JwEmailMessage>> fetchUids(List<int> uids);
  Future<void> close();
}

typedef JwImapSessionFactory = JwImapSession Function(Duration timeout);
typedef JwMissingUids = Future<Set<int>> Function(
  int uidValidity,
  List<int> uids,
);
typedef JwMissingMailboxUids = Future<Set<int>> Function(
  String mailboxPath,
  int uidValidity,
  List<int> uids,
);

/// Metadados de pasta IMAP mapeados para as pastas padrão do app.
class JwImapMailboxInfo {
  final String path;
  final String folderName;
  final bool isDraft;
  final bool isSent;
  final bool isJunk;
  final bool isTrash;

  const JwImapMailboxInfo({
    required this.path,
    required this.folderName,
    this.isDraft = false,
    this.isSent = false,
    this.isJunk = false,
    this.isTrash = false,
  });
}

/// Estado remoto resumido de um UID IMAP (`\Seen`).
class JwImapUidFlag {
  final int uid;
  final bool isSeen;

  const JwImapUidFlag({required this.uid, required this.isSeen});
}

/// Extensão opcional de [JwImapSession] com suporte multi-pastas (Enviadas, Rascunhos, Spam, Lixeira)
/// e mutações bidirecionais (`STORE \Seen`, `MOVE`, `DELETE`).
abstract class JwImapFolderSession implements JwImapSession {
  Future<List<JwImapMailboxInfo>> listTargetMailboxes();
  Future<int> selectMailbox(String mailboxPath);
  Future<List<JwImapUidFlag>> searchUidFlags();
  Future<List<JwEmailMessage>> fetchUidsInMailbox(
    List<int> uids, {
    required JwImapMailboxInfo mailbox,
  });
  Future<void> setReadFlag(
    List<int> uids, {
    required String mailboxPath,
    required bool isRead,
  });
  Future<void> moveUidsToFolder(
    List<int> uids, {
    required String sourceMailbox,
    required String targetFolderName,
  });
  Future<void> deleteUids(
    List<int> uids, {
    required String sourceMailbox,
    bool permanent = false,
  });
}

/// Converte a mensagem MIME já analisada pela biblioteca sem perder os bytes.
@visibleForTesting
JwEmailMessage jwEmailFromMime(mail.MimeMessage message) {
  final uid = message.uid;
  final data = message.mimeData;
  if (uid == null || data == null || !data.containsHeader) {
    throw const JwEmailConnectionException(
      'Resposta IMAP incompleta: UID ou corpo ausente.',
    );
  }
  // Não reconstruir bytes de um texto já decodificado: isso poderia alterar
  // silenciosamente o MIME ou anexos com codificação diferente de UTF-8.
  if (data is! mail.BinaryMimeData) {
    throw const JwEmailConnectionException(
      'Servidor IMAP não retornou o MIME em bytes.',
    );
  }
  final raw = data.data;
  if (message.size != null && message.size != raw.length) {
    throw const JwEmailConnectionException(
      'Tamanho do MIME IMAP não confere; sincronize novamente.',
    );
  }
  final from = message.decodeHeaderValue('from') ?? 'desconhecido';
  final subject = message.decodeSubject() ?? '(Sem Assunto)';
  final isHub = from.toLowerCase().contains('hub.jw.org');
  return JwEmailMessage(
    id: 'imap_$uid',
    remoteUid: uid,
    subject: subject,
    from: from,
    to: message.decodeHeaderValue('to') ?? '',
    date: message.decodeDate() ?? DateTime.now(),
    bodyText: message.decodeTextPlainPart() ?? '',
    bodyHtml: message.decodeTextHtmlPart(),
    rawEmlBase64: base64Encode(raw),
    isRead: message.isSeen,
    isHubCommunication: isHub,
    hubType: isHub
        ? (subject.toLowerCase().contains('formulário') ? 'form' : 'letter')
        : null,
  );
}

class _EnoughMailSession implements JwImapFolderSession {
  final mail.ImapClient client;
  _EnoughMailSession(Duration timeout)
    : client = mail.ImapClient(
        defaultWriteTimeout: timeout,
        defaultResponseTimeout: timeout,
      );

  static String? _classifyCanonicalFolder(mail.Mailbox box) {
    final lower = '${box.encodedName} ${box.path}'.toLowerCase();
    if (box.isInbox || box.path.toUpperCase() == 'INBOX') {
      return 'Caixa de Entrada';
    }
    if (box.isSent ||
        RegExp(r'\b(sent|enviados|enviadas|itens enviados)\b')
            .hasMatch(lower)) {
      return 'Enviadas';
    }
    if (box.isDrafts ||
        RegExp(r'\b(draft|drafts|rascunhos)\b').hasMatch(lower)) {
      return 'Rascunhos';
    }
    if (box.isJunk || RegExp(r'\b(spam|junk|lixo)\b').hasMatch(lower)) {
      return 'Spam';
    }
    if (box.isTrash ||
        RegExp(r'\b(trash|deleted|lixeira|itens exclu)\b').hasMatch(lower)) {
      return 'Lixeira';
    }
    return null;
  }

  @override
  Future<List<JwImapMailboxInfo>> listTargetMailboxes() async {
    final boxes = await client.listMailboxes(recursive: true);
    final byCanonical = <String, JwImapMailboxInfo>{};
    for (final box in boxes) {
      if (box.isNotSelectable) continue;
      final folderName = _classifyCanonicalFolder(box);
      if (folderName == null) continue;
      byCanonical.putIfAbsent(
        folderName,
        () => JwImapMailboxInfo(
          path: box.path.isNotEmpty ? box.path : box.encodedPath,
          folderName: folderName,
          isDraft: folderName == 'Rascunhos',
          isSent: folderName == 'Enviadas',
          isJunk: folderName == 'Spam',
          isTrash: folderName == 'Lixeira',
        ),
      );
    }
    byCanonical.putIfAbsent(
      'Caixa de Entrada',
      () => const JwImapMailboxInfo(
        path: 'INBOX',
        folderName: 'Caixa de Entrada',
      ),
    );
    const preferredOrder = [
      'Caixa de Entrada',
      'Enviadas',
      'Rascunhos',
      'Spam',
      'Lixeira',
    ];
    final ordered = <JwImapMailboxInfo>[];
    for (final name in preferredOrder) {
      final info = byCanonical[name];
      if (info != null) ordered.add(info);
    }
    return ordered;
  }

  @override
  Future<int> selectMailbox(String mailboxPath) async {
    final box = mailboxPath.toUpperCase() == 'INBOX'
        ? await client.selectInbox()
        : await client.selectMailboxByPath(mailboxPath);
    final validity = box.uidValidity;
    if (validity == null || validity <= 0) {
      throw const JwEmailConnectionException(
        'Servidor IMAP não informou UIDVALIDITY.',
      );
    }
    return validity;
  }

  @override
  Future<List<JwImapUidFlag>> searchUidFlags() async {
    final uids = await searchUids();
    if (uids.isEmpty) return const [];
    final recentUids = uids.length > 150
        ? uids.sublist(uids.length - 150)
        : uids;
    try {
      final res = await client.uidFetchMessages(
        mail.MessageSequence.fromIds(recentUids, isUid: true),
        '(UID FLAGS)',
        responseTimeout: client.defaultResponseTimeout,
      );
      final seenByUid = <int, bool>{
        for (final msg in res.messages)
          if (msg.uid != null) msg.uid!: msg.isSeen,
      };
      return recentUids
          .map(
            (uid) => JwImapUidFlag(uid: uid, isSeen: seenByUid[uid] ?? false),
          )
          .toList();
    } catch (_) {
      return recentUids
          .map((uid) => JwImapUidFlag(uid: uid, isSeen: false))
          .toList();
    }
  }

  @override
  Future<List<JwEmailMessage>> fetchUidsInMailbox(
    List<int> uids, {
    required JwImapMailboxInfo mailbox,
  }) async {
    final result = await client.uidFetchMessages(
      mail.MessageSequence.fromIds(uids, isUid: true),
      '(UID FLAGS RFC822.SIZE BODY.PEEK[])',
      responseTimeout: client.defaultResponseTimeout,
    );
    if (result.messages.any((message) => message.size == null)) {
      throw const JwEmailConnectionException(
        'Servidor IMAP não informou o tamanho da mensagem.',
      );
    }
    return result.messages
        .map(
          (m) => jwEmailFromMime(m).copyWith(
            folderId: mailbox.path,
            folderName: mailbox.folderName,
            isDraft: mailbox.isDraft,
          ),
        )
        .toList();
  }

  @override
  Future<void> setReadFlag(
    List<int> uids, {
    required String mailboxPath,
    required bool isRead,
  }) async {
    if (uids.isEmpty) return;
    await selectMailbox(mailboxPath);
    await client.uidStore(mail.MessageSequence.fromIds(uids, isUid: true), [
      mail.MessageFlags.seen,
    ], action: isRead ? mail.StoreAction.add : mail.StoreAction.remove);
  }

  @override
  Future<void> moveUidsToFolder(
    List<int> uids, {
    required String sourceMailbox,
    required String targetFolderName,
  }) async {
    if (uids.isEmpty) return;
    final boxes = await listTargetMailboxes();
    final target = boxes
        .where((b) => b.folderName == targetFolderName)
        .firstOrNull;
    if (target == null) {
      throw JwEmailConnectionException(
        'Pasta IMAP de destino "$targetFolderName" não encontrada.',
      );
    }
    if (target.path == sourceMailbox) return;
    await selectMailbox(sourceMailbox);
    final seq = mail.MessageSequence.fromIds(uids, isUid: true);
    try {
      await client.uidMove(seq, targetMailboxPath: target.path);
    } catch (_) {
      await client.uidCopy(seq, targetMailboxPath: target.path);
      await client.uidStore(seq, [mail.MessageFlags.deleted]);
      await client.expunge();
    }
  }

  @override
  Future<void> deleteUids(
    List<int> uids, {
    required String sourceMailbox,
    bool permanent = false,
  }) async {
    if (uids.isEmpty) return;
    if (!permanent) {
      final boxes = await listTargetMailboxes();
      final trash = boxes.where((b) => b.isTrash).firstOrNull;
      if (trash != null && trash.path != sourceMailbox) {
        await moveUidsToFolder(
          uids,
          sourceMailbox: sourceMailbox,
          targetFolderName: trash.folderName,
        );
        return;
      }
    }
    await selectMailbox(sourceMailbox);
    final seq = mail.MessageSequence.fromIds(uids, isUid: true);
    await client.uidStore(seq, [mail.MessageFlags.deleted]);
    await client.expunge();
  }

  @override
  Future<void> connect(
    String host,
    int port,
    String username,
    String password,
    Duration timeout,
  ) async {
    // LOGIN da biblioteca envolve os argumentos em aspas, portanto precisamos
    // escapar esses caracteres e rejeitar controles para evitar injeção IMAP.
    if (RegExp(r'[\x00-\x1f\x7f]').hasMatch(username) ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(password)) {
      throw const JwEmailAuthException(
        'Credenciais IMAP contêm caracteres de controle inválidos.',
      );
    }
    String quoted(String value) =>
        value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
    await client
        .connectToServer(host, port, isSecure: true, timeout: timeout)
        .timeout(timeout);
    try {
      await client.login(quoted(username), quoted(password)).timeout(timeout);
    } on mail.ImapException {
      throw const JwEmailAuthException(
        'Falha de autenticação IMAP. Verifique usuário e senha.',
      );
    }
  }

  @override
  Future<int> selectInbox() async {
    final box = await client.selectInbox();
    final validity = box.uidValidity;
    if (validity == null || validity <= 0) {
      throw const JwEmailConnectionException(
        'Servidor IMAP não informou UIDVALIDITY.',
      );
    }
    return validity;
  }

  @override
  Future<List<int>> searchUids() async {
    final result = await client.uidSearchMessages(
      searchCriteria: 'ALL',
      responseTimeout: client.defaultResponseTimeout,
    );
    final sequence = result.matchingSequence;
    if (sequence == null) {
      throw const JwEmailConnectionException(
        'Servidor IMAP não retornou lista de UIDs.',
      );
    }
    return sequence.toList();
  }

  @override
  Future<List<JwEmailMessage>> fetchUids(List<int> uids) async {
    final result = await client.uidFetchMessages(
      mail.MessageSequence.fromIds(uids, isUid: true),
      '(UID RFC822.SIZE BODY.PEEK[])',
      responseTimeout: client.defaultResponseTimeout,
    );
    if (result.messages.any((message) => message.size == null)) {
      throw const JwEmailConnectionException(
        'Servidor IMAP não informou o tamanho da mensagem.',
      );
    }
    return result.messages.map(jwEmailFromMime).toList();
  }

  @override
  Future<void> close() async {
    if (client.isConnected) {
      try {
        await client.logout().timeout(const Duration(seconds: 3));
      } catch (_) {}
      await client.disconnect().timeout(const Duration(seconds: 3));
    }
  }
}

// Nunca exibir resposta bruta do servidor: pode conter credenciais ou mensagens.
Future<T> _imapStage<T>(
  String stage,
  Future<T> Function() action,
  Duration timeout,
) async {
  try {
    return await action().timeout(timeout);
  } on JwEmailException {
    rethrow;
  } on TimeoutException {
    throw JwEmailConnectionException(
      'Tempo esgotado na etapa IMAP: $stage. Confira servidor, porta e rede.',
    );
  } on TlsException {
    throw JwEmailConnectionException(
      'Falha TLS na etapa IMAP: $stage. Confira servidor, porta e certificado.',
    );
  } on SocketException {
    throw JwEmailConnectionException(
      'Não foi possível conectar ou manter a conexão IMAP na etapa: $stage. Confira servidor, porta e rede.',
    );
  } catch (_) {
    throw JwEmailConnectionException(
      'Falha na etapa IMAP: $stage. Confira se o servidor suporta IMAP e a configuração da conta.',
    );
  }
}

/// Cliente IMAP com conexão SSL/TLS para importação incremental da INBOX.
/// Comunicação RFC 3501 autêntica sem sementes fictícias.
class JwImapClient {
  final String defaultHost;
  final int defaultPort;
  final JwImapSessionFactory? sessionFactory;

  const JwImapClient({
    this.defaultHost = 'mail.jw.org',
    this.defaultPort = 993,
    this.sessionFactory,
  });

  /// Decodifica cabeçalhos MIME RFC 2047 (=?UTF-8?B?...?= ou =?UTF-8?Q?...?=)
  static String decodeMimeHeader(String raw) {
    final pattern = RegExp(
      r'=\?([^?]+)\?([bBqQ])\?([^?]+)\?=',
      caseSensitive: false,
    );
    return raw.replaceAllMapped(pattern, (match) {
      final encoding = match.group(2)!.toUpperCase();
      final text = match.group(3)!;
      try {
        if (encoding == 'B') {
          return utf8.decode(base64.decode(text));
        } else if (encoding == 'Q') {
          return text.replaceAll('_', ' ').replaceAllMapped(
            RegExp(r'=([A-Fa-f0-9]{2})'),
            (m) {
              final byte = int.parse(m.group(1)!, radix: 16);
              return String.fromCharCode(byte);
            },
          );
        }
      } catch (e, st) {
        AppLogger.debug('Falha ao decodificar cabeçalho RFC 2047: $e', st);
      }
      return match.group(0)!;
    });
  }

  /// UID só é único dentro de uma conta, caixa e geração de UIDVALIDITY.
  @visibleForTesting
  static String scopedMessageId({
    required String host,
    required int port,
    required String username,
    required int uidValidity,
    required int uid,
    String mailbox = 'INBOX',
  }) {
    final normalizedMailbox = mailbox.trim().isEmpty
        ? 'INBOX'
        : (mailbox.trim().toUpperCase() == 'INBOX' ? 'INBOX' : mailbox.trim());
    final scope = jsonEncode([
      host.trim().toLowerCase(),
      port,
      username.trim(),
      normalizedMailbox,
      uidValidity,
    ]);
    return 'imap_${crypto.sha256.convert(utf8.encode(scope))}_$uid';
  }

  /// Verifica login e acesso à INBOX sem baixar nem ler mensagens da caixa.
  Future<void> verifyConnection({
    required String host,
    required int port,
    required String username,
    required String password,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    if (kIsWeb) {
      throw const JwEmailConnectionException(
        'IMAP direto não é suportado no navegador.',
      );
    }
    if (host.trim().isEmpty ||
        username.trim().isEmpty ||
        password.isEmpty ||
        port <= 0 ||
        port > 65535) {
      throw const JwEmailConnectionException(
        'Informe servidor, porta e credenciais IMAP válidos.',
      );
    }
    final session =
        sessionFactory?.call(timeout) ?? _EnoughMailSession(timeout);
    try {
      await _imapStage(
        'conexão e autenticação',
        () => session.connect(
          host.trim(),
          port,
          username.trim(),
          password,
          timeout,
        ),
        timeout,
      );
      final validity = await _imapStage(
        'abertura da INBOX',
        session.selectInbox,
        timeout,
      );
      if (validity <= 0) {
        throw const JwEmailConnectionException('UIDVALIDITY inválido.');
      }
    } finally {
      try {
        await session.close();
      } catch (_) {}
    }
  }

  /// Compatibilidade para consumidores que precisam de uma lista completa.
  /// A sincronização da Inbox usa a API em páginas para persistir progresso.
  Future<List<JwEmailMessage>> fetchRemoteEmails({
    String? host,
    int? port,
    String? username,
    String? password,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final result = <JwEmailMessage>[];
    await for (final page in fetchRemoteEmailPages(
      host: host,
      port: port,
      username: username,
      password: password,
      timeout: timeout,
    )) {
      result.addAll(page);
    }
    return result;
  }

  /// Varre INBOX mantendo a assinatura original para subclasses de teste.
  Stream<List<JwEmailMessage>> fetchRemoteEmailPages({
    String? host,
    int? port,
    String? username,
    String? password,
    String? accountEmail,
    Duration timeout = const Duration(seconds: 60),
    JwMissingUids? missingUids,
  }) => fetchAllMailboxPages(
    host: host,
    port: port,
    username: username,
    password: password,
    accountEmail: accountEmail,
    timeout: timeout,
    missingUids: missingUids,
  );

  /// Varre INBOX e, quando suportado, as pastas Enviadas, Rascunhos, Spam e Lixeira;
  /// cada página é entregue antes de buscar a próxima, permitindo gravação incremental.
  Stream<List<JwEmailMessage>> fetchAllMailboxPages({
    String? host,
    int? port,
    String? username,
    String? password,
    String? accountEmail,
    Duration timeout = const Duration(seconds: 60),
    JwMissingUids? missingUids,
    JwMissingMailboxUids? missingMailboxUids,
    Future<void> Function(
      String mailboxPath,
      String folderName,
      int validity,
      List<JwImapUidFlag> flags,
    )?
    onMailboxFlags,
  }) async* {
    if (username == null ||
        username.trim().isEmpty ||
        password == null ||
        password.isEmpty) {
      return;
    }
    if (kIsWeb) {
      throw const JwEmailConnectionException(
        'IMAP direto não é suportado no navegador.',
      );
    }
    final targetHost = host?.trim().isNotEmpty == true
        ? host!.trim()
        : defaultHost;
    final targetPort = port ?? defaultPort;
    if (targetPort <= 0 || targetPort > 65535) {
      throw JwEmailConnectionException(
        'Porta IMAP inválida ($targetPort). Informe um valor entre 1 e 65535.',
      );
    }
    final session =
        sessionFactory?.call(timeout) ?? _EnoughMailSession(timeout);
    try {
      await _imapStage(
        'conexão e autenticação',
        () => session.connect(
          targetHost,
          targetPort,
          username.trim(),
          password,
          timeout,
        ),
        timeout,
      );
      final effectiveAccountEmail =
          (accountEmail != null && accountEmail.trim().isNotEmpty)
          ? accountEmail.trim().toLowerCase()
          : username.trim();

      if (session is JwImapFolderSession) {
        final mailboxes = await _imapStage(
          'listagem de pastas IMAP',
          session.listTargetMailboxes,
          timeout,
        );
        for (final box in mailboxes) {
          final isInbox = box.path.toUpperCase() == 'INBOX';
          int validity;
          try {
            validity = await _imapStage(
              'abertura da pasta ${box.folderName}',
              () => isInbox
                  ? session.selectInbox()
                  : session.selectMailbox(box.path),
              timeout,
            );
          } catch (e) {
            if (isInbox) rethrow;
            AppLogger.warning(
              'Pasta IMAP ${box.folderName} (${box.path}) indisponível: $e',
            );
            continue;
          }
          if (validity <= 0) {
            if (isInbox) {
              throw const JwEmailConnectionException('UIDVALIDITY inválido.');
            }
            continue;
          }
          final uidFlags = await _imapStage(
            'leitura de flags em ${box.folderName}',
            session.searchUidFlags,
            timeout,
          );
          if (onMailboxFlags != null && uidFlags.isNotEmpty) {
            await onMailboxFlags(box.path, box.folderName, validity, uidFlags);
          }
          final uids = uidFlags.map((f) => f.uid).toList();
          if (uids.any((uid) => uid <= 0) ||
              uids.toSet().length != uids.length) {
            throw const JwEmailConnectionException(
              'Lista de UIDs IMAP inválida.',
            );
          }
          uids.sort();
          const pageSize = 10;
          for (var start = 0; start < uids.length; start += pageSize) {
            final end = start + pageSize < uids.length
                ? start + pageSize
                : uids.length;
            final page = uids.sublist(start, end);
            final wanted = missingMailboxUids != null
                ? await missingMailboxUids(box.path, validity, page)
                : (missingUids != null
                      ? await missingUids(validity, page)
                      : page.toSet());
            if (!page.toSet().containsAll(wanted)) {
              throw const JwEmailConnectionException(
                'Filtro de mensagens IMAP inválido.',
              );
            }
            if (wanted.isEmpty) continue;
            final fetched = await _imapStage(
              'leitura de mensagens em ${box.folderName}',
              () => session.fetchUidsInMailbox(
                page.where(wanted.contains).toList(),
                mailbox: box,
              ),
              timeout,
            );
            final received = fetched.map((item) => item.remoteUid).toSet();
            if (fetched.length != wanted.length ||
                received.contains(null) ||
                received.length != wanted.length ||
                !received.containsAll(wanted)) {
              throw const JwEmailConnectionException(
                'Página IMAP incompleta; sincronize novamente para retomar.',
              );
            }
            yield fetched
                .map(
                  (item) => item.copyWith(
                    id: scopedMessageId(
                      host: targetHost,
                      port: targetPort,
                      username: username.trim(),
                      uidValidity: validity,
                      uid: item.remoteUid!,
                      mailbox: box.path,
                    ),
                    accountEmail: effectiveAccountEmail,
                    folderId: item.folderId ?? box.path,
                    folderName: item.folderName ?? box.folderName,
                    isDraft: item.isDraft || box.isDraft,
                  ),
                )
                .toList();
          }
        }
      } else {
        final validity = await _imapStage(
          'abertura da INBOX',
          session.selectInbox,
          timeout,
        );
        if (validity <= 0) {
          throw const JwEmailConnectionException('UIDVALIDITY inválido.');
        }
        final uids = await _imapStage(
          'listagem de mensagens',
          session.searchUids,
          timeout,
        );
        if (uids.any((uid) => uid <= 0) || uids.toSet().length != uids.length) {
          throw const JwEmailConnectionException(
            'Lista de UIDs IMAP inválida.',
          );
        }
        uids.sort();
        const pageSize = 10; // Tamanho de lote, não limite da caixa.
        for (var start = 0; start < uids.length; start += pageSize) {
          final end = start + pageSize < uids.length
              ? start + pageSize
              : uids.length;
          final page = uids.sublist(start, end);
          final wanted = missingUids == null
              ? page.toSet()
              : await missingUids(validity, page);
          if (!page.toSet().containsAll(wanted)) {
            throw const JwEmailConnectionException(
              'Filtro de mensagens IMAP inválido.',
            );
          }
          if (wanted.isEmpty) continue;
          final fetched = await _imapStage(
            'leitura de mensagens',
            () => session.fetchUids(page.where(wanted.contains).toList()),
            timeout,
          );
          final received = fetched.map((item) => item.remoteUid).toSet();
          if (fetched.length != wanted.length ||
              received.contains(null) ||
              received.length != wanted.length ||
              !received.containsAll(wanted)) {
            throw const JwEmailConnectionException(
              'Página IMAP incompleta; sincronize novamente para retomar.',
            );
          }
          yield fetched
              .map(
                (item) => item.copyWith(
                  id: scopedMessageId(
                    host: targetHost,
                    port: targetPort,
                    username: username.trim(),
                    uidValidity: validity,
                    uid: item.remoteUid!,
                  ),
                  accountEmail: effectiveAccountEmail,
                  folderName: item.folderName ?? 'Caixa de Entrada',
                ),
              )
              .toList();
        }
      }
    } on JwEmailException {
      rethrow;
    } catch (_) {
      // Não incluir respostas brutas: podem conter credenciais ou mensagens.
      throw const JwEmailConnectionException(
        'Falha na conexão ou na leitura IMAP. Tente novamente.',
      );
    } finally {
      try {
        await session.close();
      } catch (_) {}
    }
  }

  Future<void> pushReadFlag({
    required String host,
    required int port,
    required String username,
    required String password,
    required String mailboxPath,
    required List<int> uids,
    required bool isRead,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (kIsWeb || uids.isEmpty) return;
    final session =
        sessionFactory?.call(timeout) ?? _EnoughMailSession(timeout);
    if (session is! JwImapFolderSession) return;
    try {
      await session.connect(host, port, username, password, timeout);
      await session.setReadFlag(uids, mailboxPath: mailboxPath, isRead: isRead);
    } finally {
      try {
        await session.close();
      } catch (_) {}
    }
  }

  Future<void> pushMoveToFolder({
    required String host,
    required int port,
    required String username,
    required String password,
    required String sourceMailbox,
    required List<int> uids,
    required String targetFolderName,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (kIsWeb || uids.isEmpty) return;
    final session =
        sessionFactory?.call(timeout) ?? _EnoughMailSession(timeout);
    if (session is! JwImapFolderSession) return;
    try {
      await session.connect(host, port, username, password, timeout);
      await session.moveUidsToFolder(
        uids,
        sourceMailbox: sourceMailbox,
        targetFolderName: targetFolderName,
      );
    } finally {
      try {
        await session.close();
      } catch (_) {}
    }
  }

  Future<void> pushDeleteUids({
    required String host,
    required int port,
    required String username,
    required String password,
    required String sourceMailbox,
    required List<int> uids,
    bool permanent = false,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (kIsWeb || uids.isEmpty) return;
    final session =
        sessionFactory?.call(timeout) ?? _EnoughMailSession(timeout);
    if (session is! JwImapFolderSession) return;
    try {
      await session.connect(host, port, username, password, timeout);
      await session.deleteUids(
        uids,
        sourceMailbox: sourceMailbox,
        permanent: permanent,
      );
    } finally {
      try {
        await session.close();
      } catch (_) {}
    }
  }

  /// Analisa datas no formato RFC 2822 (ex: `Mon, 10 Nov 2026 12:00:00 -0400`) ou ISO-8601.
  @visibleForTesting
  static DateTime? parseEmailDate(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final iso = DateTime.tryParse(trimmed);
    if (iso != null) return iso;

    final match = RegExp(
      r'^(?:[A-Za-z]{3},\s*)?(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})\s+(\d{2}):(\d{2})(?::(\d{2}))?(?:\s*([+-]\d{4}|UTC|GMT|Z))?',
    ).firstMatch(trimmed);
    if (match == null) return null;

    const months = {
      'jan': 1,
      'feb': 2,
      'mar': 3,
      'apr': 4,
      'may': 5,
      'jun': 6,
      'jul': 7,
      'aug': 8,
      'sep': 9,
      'oct': 10,
      'nov': 11,
      'dec': 12,
    };
    final day = int.tryParse(match.group(1)!);
    final month = months[match.group(2)!.toLowerCase()];
    final year = int.tryParse(match.group(3)!);
    final hour = int.tryParse(match.group(4)!);
    final minute = int.tryParse(match.group(5)!);
    final second = int.tryParse(match.group(6) ?? '0') ?? 0;
    if (day == null ||
        month == null ||
        year == null ||
        hour == null ||
        minute == null) {
      return null;
    }

    final tz = match.group(7);
    if (tz == null || tz == 'UTC' || tz == 'GMT' || tz == 'Z') {
      return DateTime.utc(year, month, day, hour, minute, second);
    }
    final sign = tz.startsWith('-') ? -1 : 1;
    final digits = tz.substring(1);
    final tzHours = int.tryParse(digits.substring(0, 2)) ?? 0;
    final tzMins = int.tryParse(digits.substring(2, 4)) ?? 0;
    final offset = Duration(hours: tzHours, minutes: tzMins) * sign;
    return DateTime.utc(
      year,
      month,
      day,
      hour,
      minute,
      second,
    ).subtract(offset);
  }

  /// Parser estruturado das respostas FETCH do IMAP (exposto para testes).
  @visibleForTesting
  List<JwEmailMessage> parseImapResponsesForTest(List<String> lines) =>
      _parseImapResponses(lines);

  /// Parser estruturado das respostas FETCH do IMAP
  List<JwEmailMessage> _parseImapResponses(List<String> lines) {
    final messages = <JwEmailMessage>[];
    String? currentSubject;
    String? currentFrom;
    String? currentTo;
    DateTime? currentDate;
    int? currentUid;
    final currentBodyBuffer = StringBuffer();
    bool inBody = false;

    void flushCurrent() {
      if (currentSubject != null ||
          currentFrom != null ||
          currentBodyBuffer.isNotEmpty) {
        final fromStr = currentFrom ?? 'desconhecido@jw.org';
        final isHub = fromStr.contains('hub.jw.org');
        final subjectStr = currentSubject ?? '(Sem Assunto)';
        final isForm =
            subjectStr.toLowerCase().contains('formulário') ||
            subjectStr.toLowerCase().contains('s-');
        final bodyLines = currentBodyBuffer.toString().split('\n');
        while (bodyLines.isNotEmpty && bodyLines.last.trim().isEmpty) {
          bodyLines.removeLast();
        }
        if (bodyLines.isNotEmpty && bodyLines.last.trim() == ')') {
          bodyLines.removeLast();
        }
        var bodyStr = bodyLines.join('\n').trim();
        if (bodyStr.endsWith(')') && !bodyStr.contains('(')) {
          bodyStr = bodyStr.substring(0, bodyStr.length - 1).trimRight();
        }

        messages.add(
          JwEmailMessage(
            id: currentUid != null ? 'imap_$currentUid' : const Uuid().v4(),
            remoteUid: currentUid,
            subject: subjectStr,
            from: fromStr,
            to: currentTo ?? 'me@jw.org',
            date: currentDate ?? DateTime.now(),
            bodyText: bodyStr,
            isHubCommunication: isHub,
            hubType: isHub ? (isForm ? 'form' : 'letter') : null,
            isPermanentRetained: true,
          ),
        );
      }
      currentSubject = null;
      currentFrom = null;
      currentTo = null;
      currentDate = null;
      currentUid = null;
      currentBodyBuffer.clear();
      inBody = false;
    }

    for (final line in lines) {
      if (line.startsWith('* ') && line.contains('FETCH')) {
        flushCurrent();
        final uidMatch = RegExp(r'UID\s+(\d+)').firstMatch(line);
        if (uidMatch != null) {
          currentUid = int.tryParse(uidMatch.group(1)!);
        }
        continue;
      }

      if (RegExp(r'^A\d+\s+(OK|NO|BAD)\b').hasMatch(line)) {
        flushCurrent();
        continue;
      }

      if (RegExp(
        r'^BODY\[HEADER[^\]]*\]\s*\{\d+\}\s*$',
        caseSensitive: false,
      ).hasMatch(line.trim())) {
        inBody = false;
        continue;
      }

      if (RegExp(
        r'^BODY\[TEXT\]\s*\{\d+\}\s*$',
        caseSensitive: false,
      ).hasMatch(line.trim())) {
        inBody = true;
        continue;
      }

      if (!inBody) {
        final lower = line.toLowerCase();
        if (lower.startsWith('subject:')) {
          currentSubject = decodeMimeHeader(line.substring(8).trim());
        } else if (lower.startsWith('from:')) {
          currentFrom = decodeMimeHeader(line.substring(5).trim());
        } else if (lower.startsWith('to:')) {
          currentTo = decodeMimeHeader(line.substring(3).trim());
        } else if (lower.startsWith('date:')) {
          currentDate = parseEmailDate(line.substring(5).trim());
        } else if (line.isEmpty &&
            (currentSubject != null || currentFrom != null)) {
          inBody = true;
        }
      } else {
        currentBodyBuffer.writeln(line);
      }
    }
    flushCurrent();

    return messages;
  }
}

/// Leitor assíncrono linha-a-linha para servidor SMTP (RFC 5321).
/// Usa [pauseSubscription] durante o upgrade STARTTLS sem encerrar o socket TCP.
class _SmtpLineReader {
  final StreamSubscription<String> _subscription;
  final List<String> _bufferedLines = [];
  final List<Completer<String>> _waiters = [];
  bool _isClosed = false;
  bool _detached = false;

  _SmtpLineReader(Stream<String> lineStream)
    : _subscription = lineStream.listen(null) {
    _subscription.onData((line) {
      if (_detached) return;
      if (_waiters.isNotEmpty) {
        _waiters.removeAt(0).complete(line);
      } else {
        _bufferedLines.add(line);
      }
    });
    _subscription.onDone(() {
      if (_detached) return;
      _isClosed = true;
      for (final w in _waiters) {
        if (!w.isCompleted) {
          w.completeError(
            const JwEmailConnectionException(
              'Conexão encerrada inesperadamente pelo servidor SMTP.',
            ),
          );
        }
      }
      _waiters.clear();
    });
    _subscription.onError((err) {
      if (_detached) return;
      for (final w in _waiters) {
        if (!w.isCompleted) {
          w.completeError(
            JwEmailConnectionException(
              'Erro no fluxo de comunicação SMTP: $err',
              err,
            ),
          );
        }
      }
      _waiters.clear();
    });
  }

  void pauseForTlsUpgrade() {
    _detached = true;
    _subscription.pause();
    _waiters.clear();
  }

  Future<String> readLine({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    if (_bufferedLines.isNotEmpty) {
      return _bufferedLines.removeAt(0);
    }
    if (_isClosed) {
      throw const JwEmailConnectionException(
        'Conexão encerrada pelo servidor SMTP.',
      );
    }
    final completer = Completer<String>();
    _waiters.add(completer);
    return completer.future.timeout(
      timeout,
      onTimeout: () {
        _waiters.remove(completer);
        throw const JwEmailConnectionException(
          'Tempo limite esgotado aguardando resposta do servidor SMTP.',
        );
      },
    );
  }

  Future<void> close() async {
    _detached = true;
    await _subscription.cancel();
  }
}

/// Resposta multi-linha padronizada RFC 5321 (ex: `250-PIPELINING` ... `250 AUTH PLAIN LOGIN`).
class _SmtpResponse {
  final int code;
  final List<String> lines;

  const _SmtpResponse(this.code, this.lines);

  String get summary => lines.join(' | ');
}

/// Cliente SMTP puro Dart autenticado (RFC 5321 / 3207 STARTTLS / 4954 AUTH PLAIN & LOGIN).
/// Suporta porta 587 (STARTTLS obrigatório por padrão) e porta 465 (SSL/TLS implícito).
class JwSmtpClient {
  final String defaultHost;
  final int defaultPort;
  final String defaultSecurityMode; // 'starttls' ou 'ssl'

  /// Permite conexão sem TLS exclusivamente em testes unitários loopback locais.
  @visibleForTesting
  final bool allowPlaintextForTesting;

  /// Permite validar certificados auto-assinados exclusivamente em testes loopback TLS/STARTTLS.
  @visibleForTesting
  final bool Function(X509Certificate)? onBadCertificateForTesting;

  const JwSmtpClient({
    this.defaultHost = 'mail.jw.org',
    this.defaultPort = 587,
    this.defaultSecurityMode = 'starttls',
    this.allowPlaintextForTesting = false,
    this.onBadCertificateForTesting,
  });

  /// Extrai e valida endereço puro a partir de `"Nome <user@dom>"` ou `"user@dom"`.
  static String? extractValidEmailAddress(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed.contains('\r') || trimmed.contains('\n')) {
      return null;
    }
    final angleMatch = RegExp(r'<([^<>\s]+@[^<>\s]+)>').firstMatch(trimmed);
    final candidate = angleMatch != null
        ? angleMatch.group(1)!.trim()
        : trimmed;
    final emailRegex = RegExp(r'^[^\s@<>]+@[^\s@<>]+\.[^\s@<>]+$');
    if (!emailRegex.hasMatch(candidate)) {
      return null;
    }
    return candidate;
  }

  /// Faz parse de múltiplos destinatários separados por `,` ou `;`.
  static List<String> parseRecipients(String raw) {
    final result = <String>[];
    for (final part in raw.split(RegExp(r'[,;]'))) {
      final addr = extractValidEmailAddress(part);
      if (addr != null) {
        result.add(addr);
      }
    }
    return result;
  }

  /// Codifica cabeçalho UTF-8 em RFC 2047 Base64 quando contém caracteres não-ASCII.
  static String encodeHeaderValue(String value) {
    final sanitized = value.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
    final isAscii = sanitized.codeUnits.every((c) => c >= 0x20 && c <= 0x7e);
    if (isAscii) return sanitized;
    return '=?UTF-8?B?${base64.encode(utf8.encode(sanitized))}?=';
  }

  static Future<_SmtpResponse> _readResponse(
    _SmtpLineReader reader,
    Duration timeout,
  ) async {
    final lines = <String>[];
    int? finalCode;
    while (true) {
      final line = await reader.readLine(timeout: timeout);
      if (line.length < 3) {
        throw JwEmailConnectionException(
          'Resposta SMTP inválida recebida: $line',
        );
      }
      final code = int.tryParse(line.substring(0, 3));
      if (code == null) {
        throw JwEmailConnectionException(
          'Código SMTP inesperado recebido: $line',
        );
      }
      lines.add(line.length > 4 ? line.substring(4).trim() : '');
      final isContinuation = line.length > 3 && line[3] == '-';
      if (!isContinuation) {
        finalCode = code;
        break;
      }
    }
    return _SmtpResponse(finalCode, lines);
  }

  static Future<void> _sendCommand(dynamic socket, String command) async {
    socket.write('$command\r\n');
    await socket.flush();
  }

  static String _wrapBase64Lines(String input, {int lineLength = 76}) {
    final buffer = StringBuffer();
    for (int i = 0; i < input.length; i += lineLength) {
      final end = (i + lineLength < input.length)
          ? i + lineLength
          : input.length;
      buffer.write(input.substring(i, end));
      buffer.write('\r\n');
    }
    return buffer.toString();
  }

  static String formatRfc2822Date(DateTime dateTime) {
    final utc = dateTime.toUtc();
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    String two(int n) => n.toString().padLeft(2, '0');
    return '${weekdays[utc.weekday - 1]}, ${two(utc.day)} ${months[utc.month - 1]} '
        '${utc.year} ${two(utc.hour)}:${two(utc.minute)}:${two(utc.second)} +0000';
  }

  static String _formatRfc2822Date(DateTime dateTime) =>
      formatRfc2822Date(dateTime);

  Future<void> _executeSmtpSession({
    required String? host,
    required int? port,
    required String? username,
    required String? password,
    required String securityMode,
    required Duration timeout,
    JwEmailMessage? messageToSend,
  }) async {
    if (username == null ||
        username.trim().isEmpty ||
        password == null ||
        password.isEmpty) {
      throw const JwEmailAuthException(
        'Credenciais de e-mail não configuradas. Informe e-mail e senha nas Configurações.',
      );
    }

    final cleanUser = username.trim();
    final messageSender =
        (messageToSend != null &&
            messageToSend.from.trim().isNotEmpty &&
            messageToSend.from.trim() != 'local@dispositivo')
        ? extractValidEmailAddress(messageToSend.from)
        : null;
    final senderAddr = messageSender ?? extractValidEmailAddress(cleanUser);
    if (senderAddr == null) {
      throw const JwEmailAuthException(
        'Endereço de e-mail remetente inválido nas configurações.',
      );
    }

    List<String> recipients = [];
    if (messageToSend != null) {
      recipients = <String>{
        ...parseRecipients(messageToSend.to),
        ...messageToSend.cc.expand((c) => parseRecipients(c)),
        ...messageToSend.bcc.expand((b) => parseRecipients(b)),
      }.toList();
      if (parseRecipients(messageToSend.to).isEmpty) {
        throw const JwEmailException(
          'Informe ao menos um destinatário de e-mail válido no campo "Para".',
        );
      }
      if (messageToSend.subject.trim().isEmpty) {
        throw const JwEmailException(
          'O assunto da mensagem não pode ficar vazio.',
        );
      }
    }

    if (kIsWeb) {
      throw const JwEmailConnectionException(
        'Envio direto via socket SMTP não é suportado no navegador Web. Utilize o aplicativo Desktop ou Mobile.',
      );
    }

    final targetHost = (host != null && host.trim().isNotEmpty)
        ? host.trim()
        : defaultHost;
    final targetPort = port ?? defaultPort;
    if (targetPort <= 0 || targetPort > 65535) {
      throw JwEmailConnectionException(
        'Porta SMTP inválida ($targetPort). Informe um valor entre 1 e 65535.',
      );
    }
    final effectiveMode = securityMode.trim().toLowerCase();
    final useImplicitSsl =
        effectiveMode == 'ssl' || (effectiveMode.isEmpty && targetPort == 465);

    dynamic activeSocket;
    _SmtpLineReader? reader;

    Future<void> connectAndRun() async {
      try {
        if (useImplicitSsl) {
          activeSocket = await SecureSocket.connect(
            targetHost,
            targetPort,
            timeout: timeout,
            onBadCertificate: onBadCertificateForTesting,
          );
        } else {
          activeSocket = await Socket.connect(
            targetHost,
            targetPort,
            timeout: timeout,
          );
        }
      } on SocketException catch (e) {
        throw JwEmailConnectionException(
          'Não foi possível conectar ao servidor SMTP $targetHost:$targetPort: ${e.message}',
          e,
        );
      } on TimeoutException catch (e) {
        throw JwEmailConnectionException(
          'Tempo limite esgotado ao conectar ao servidor SMTP ($targetHost:$targetPort).',
          e,
        );
      } catch (e) {
        throw JwEmailConnectionException(
          'Falha ao abrir conexão SMTP com $targetHost:$targetPort: $e',
          e,
        );
      }

      reader = _SmtpLineReader(
        utf8.decoder
            .bind(activeSocket as Stream<List<int>>)
            .transform(const LineSplitter()),
      );

      final greeting = await _readResponse(reader!, timeout);
      if (greeting.code != 220) {
        throw JwEmailConnectionException(
          'Servidor SMTP recusou a saudação inicial (${greeting.code}): ${greeting.summary}',
        );
      }

      final ehloHost = senderAddr.split('@').last;
      await _sendCommand(activeSocket, 'EHLO $ehloHost');
      var ehloResp = await _readResponse(reader!, timeout);
      if (ehloResp.code != 250) {
        throw JwEmailConnectionException(
          'Servidor SMTP rejeitou EHLO (${ehloResp.code}): ${ehloResp.summary}',
        );
      }

      if (!useImplicitSsl) {
        final supportsStartTls = ehloResp.lines.any(
          (l) => l.toUpperCase().split(RegExp(r'\s+')).contains('STARTTLS'),
        );
        if (supportsStartTls) {
          await _sendCommand(activeSocket, 'STARTTLS');
          final startTlsResp = await _readResponse(reader!, timeout);
          if (startTlsResp.code != 220) {
            throw JwEmailConnectionException(
              'Falha ao iniciar STARTTLS (${startTlsResp.code}): ${startTlsResp.summary}',
            );
          }
          final plainSocket = activeSocket as Socket;
          reader!.pauseForTlsUpgrade();
          final sniHost = InternetAddress.tryParse(targetHost) != null
              ? null
              : targetHost;
          final secured = await SecureSocket.secure(
            plainSocket,
            host: sniHost,
            onBadCertificate: onBadCertificateForTesting,
          );
          activeSocket = secured;
          reader = _SmtpLineReader(
            utf8.decoder.bind(secured).transform(const LineSplitter()),
          );

          await _sendCommand(activeSocket, 'EHLO $ehloHost');
          ehloResp = await _readResponse(reader!, timeout);
          if (ehloResp.code != 250) {
            throw JwEmailConnectionException(
              'Servidor SMTP rejeitou EHLO pós-TLS (${ehloResp.code}): ${ehloResp.summary}',
            );
          }
        } else if (!allowPlaintextForTesting) {
          throw JwEmailConnectionException(
            'Servidor SMTP ($targetHost:$targetPort) não oferece criptografia STARTTLS segura.',
          );
        }
      }

      // Negociação de autenticação AUTH PLAIN / AUTH LOGIN (RFC 4954)
      final authCaps = ehloResp.lines
          .where((l) => l.toUpperCase().startsWith('AUTH'))
          .join(' ')
          .toUpperCase();
      final supportsLogin = authCaps.contains('LOGIN');
      final supportsPlain = authCaps.contains('PLAIN') || !supportsLogin;

      if (supportsPlain) {
        final token = base64.encode(
          utf8.encode('\u0000$cleanUser\u0000$password'),
        );
        await _sendCommand(activeSocket, 'AUTH PLAIN $token');
        final authResp = await _readResponse(reader!, timeout);
        if (authResp.code == 334) {
          await _sendCommand(activeSocket, token);
          final secondResp = await _readResponse(reader!, timeout);
          if (secondResp.code != 235) {
            throw JwEmailAuthException(
              'Falha de autenticação SMTP (${secondResp.code}): ${secondResp.summary}',
            );
          }
        } else if (authResp.code != 235) {
          throw JwEmailAuthException(
            'Falha de autenticação SMTP (${authResp.code}): ${authResp.summary}',
          );
        }
      } else {
        await _sendCommand(activeSocket, 'AUTH LOGIN');
        final userPrompt = await _readResponse(reader!, timeout);
        if (userPrompt.code != 334) {
          throw JwEmailAuthException(
            'Servidor SMTP rejeitou AUTH LOGIN (${userPrompt.code}): ${userPrompt.summary}',
          );
        }
        await _sendCommand(activeSocket, base64.encode(utf8.encode(cleanUser)));
        final passPrompt = await _readResponse(reader!, timeout);
        if (passPrompt.code != 334) {
          throw JwEmailAuthException(
            'Falha ao enviar usuário no AUTH LOGIN (${passPrompt.code}): ${passPrompt.summary}',
          );
        }
        await _sendCommand(activeSocket, base64.encode(utf8.encode(password)));
        final authResp = await _readResponse(reader!, timeout);
        if (authResp.code != 235) {
          throw JwEmailAuthException(
            'Credenciais SMTP rejeitadas (${authResp.code}): ${authResp.summary}',
          );
        }
      }

      // Envio efetivo da mensagem quando solicitado
      if (messageToSend != null) {
        await _sendCommand(activeSocket, 'MAIL FROM:<$senderAddr>');
        final fromResp = await _readResponse(reader!, timeout);
        if (fromResp.code < 200 || fromResp.code >= 300) {
          throw JwEmailConnectionException(
            'Servidor rejeitou remetente MAIL FROM (${fromResp.code}): ${fromResp.summary}',
          );
        }

        for (final rcpt in recipients) {
          await _sendCommand(activeSocket, 'RCPT TO:<$rcpt>');
          final rcptResp = await _readResponse(reader!, timeout);
          if (rcptResp.code < 200 || rcptResp.code >= 300) {
            throw JwEmailConnectionException(
              'Servidor rejeitou destinatário $rcpt (${rcptResp.code}): ${rcptResp.summary}',
            );
          }
        }

        await _sendCommand(activeSocket, 'DATA');
        final dataReady = await _readResponse(reader!, timeout);
        if (dataReady.code != 354) {
          throw JwEmailConnectionException(
            'Servidor rejeitou início de dados DATA (${dataReady.code}): ${dataReady.summary}',
          );
        }

        final nowUtc = DateTime.now().toUtc();
        final messageId =
            '<${const Uuid().v4()}@${senderAddr.split('@').last}>';
        final bodyEncoded = _wrapBase64Lines(
          base64.encode(utf8.encode(messageToSend.bodyText)),
        );
        final toRecipients = parseRecipients(messageToSend.to);
        final payload = StringBuffer()
          ..write('From: <$senderAddr>\r\n')
          ..write('To: ${toRecipients.map((r) => '<$r>').join(', ')}\r\n');
        if (messageToSend.cc.isNotEmpty) {
          final ccRecipients = messageToSend.cc
              .expand((c) => parseRecipients(c))
              .toList();
          if (ccRecipients.isNotEmpty) {
            payload.write(
              'Cc: ${ccRecipients.map((r) => '<$r>').join(', ')}\r\n',
            );
          }
        }
        payload
          ..write('Subject: ${encodeHeaderValue(messageToSend.subject)}\r\n')
          ..write('Date: ${_formatRfc2822Date(nowUtc)}\r\n')
          ..write('Message-ID: $messageId\r\n')
          ..write('MIME-Version: 1.0\r\n');

        if (messageToSend.attachments.isEmpty) {
          payload
            ..write('Content-Type: text/plain; charset=UTF-8\r\n')
            ..write('Content-Transfer-Encoding: base64\r\n')
            ..write('\r\n')
            ..write(bodyEncoded)
            ..write('.\r\n');
        } else {
          final boundary =
              '===_FA_${const Uuid().v4().replaceAll("-", "")}_===';
          payload
            ..write('Content-Type: multipart/mixed; boundary="$boundary"\r\n')
            ..write('\r\n')
            ..write('--$boundary\r\n')
            ..write('Content-Type: text/plain; charset=UTF-8\r\n')
            ..write('Content-Transfer-Encoding: base64\r\n')
            ..write('\r\n')
            ..write(bodyEncoded)
            ..write('\r\n');

          for (final att in messageToSend.attachments) {
            final name = (att['name'] ?? 'anexo').toString();
            final base64Content = (att['base64'] ?? '').toString();
            final contentType =
                (att['contentType'] ?? 'application/octet-stream').toString();
            if (base64Content.isNotEmpty) {
              payload
                ..write('--$boundary\r\n')
                ..write(
                  'Content-Type: $contentType; name="${encodeHeaderValue(name)}"\r\n',
                )
                ..write('Content-Transfer-Encoding: base64\r\n')
                ..write(
                  'Content-Disposition: attachment; filename="${encodeHeaderValue(name)}"\r\n',
                )
                ..write('\r\n')
                ..write(_wrapBase64Lines(base64Content))
                ..write('\r\n');
            }
          }
          payload
            ..write('--$boundary--\r\n')
            ..write('.\r\n');
        }

        activeSocket.write(payload.toString());
        await activeSocket.flush();

        final accepted = await _readResponse(reader!, timeout);
        if (accepted.code < 200 || accepted.code >= 300) {
          throw JwEmailConnectionException(
            'Servidor não confirmou aceitação da mensagem (${accepted.code}): ${accepted.summary}',
          );
        }
      }

      try {
        await _sendCommand(activeSocket, 'QUIT');
        await activeSocket.flush();
      } catch (e, st) {
        AppLogger.debug(
          'Falha não crítica ao encerrar sessão SMTP QUIT: $e',
          st,
        );
      }
    }

    try {
      await connectAndRun();
    } finally {
      try {
        await reader?.close();
      } catch (e, st) {
        AppLogger.debug('Falha ao fechar leitor de stream SMTP: $e', st);
      }
      try {
        await activeSocket?.close();
      } catch (e, st) {
        AppLogger.debug('Falha ao fechar socket SMTP: $e', st);
      }
    }
  }

  /// Testa conexão real + autenticação SMTP sem enviar mensagem.
  Future<void> verifyConnection({
    String? host,
    int? port,
    String? username,
    String? password,
    String? securityMode,
    Duration timeout = const Duration(seconds: 12),
  }) {
    return _executeSmtpSession(
      host: host,
      port: port,
      username: username,
      password: password,
      securityMode: securityMode ?? defaultSecurityMode,
      timeout: timeout,
    );
  }

  /// Autentica e envia a mensagem pelo servidor SMTP configurado.
  Future<void> sendMail({
    String? host,
    int? port,
    String? username,
    String? password,
    required JwEmailMessage message,
    String? securityMode,
    Duration timeout = const Duration(seconds: 15),
  }) {
    return _executeSmtpSession(
      host: host,
      port: port,
      username: username,
      password: password,
      securityMode: securityMode ?? defaultSecurityMode,
      timeout: timeout,
      messageToSend: message,
    );
  }
}

/// Motor de Retenção Permanente e Gerenciador de E-mail / Hub JW.org
/// Persiste localmente as mensagens IMAP importadas no Drift SQLite.
class JwEmailService {
  final AppDatabase db;
  final BiometricAuthService biometricAuth;
  final JwImapClient imapClient;
  final JwSmtpClient smtpClient;

  JwEmailService({
    required this.db,
    required this.biometricAuth,
    this.imapClient = const JwImapClient(),
    this.smtpClient = const JwSmtpClient(),
  });

  // ==========================================
  // SINCRONIZAÇÃO E RETENÇÃO PERMANENTE (DRIFT)
  // ==========================================

  /// Sincroniza e salva永久amente mensagens locais na tabela InboxEntries
  Future<int> syncEmails({
    String? host,
    int? port,
    String? username,
    String? password,
    String? accountEmail,
  }) async {
    final targetHost = host?.trim().isNotEmpty == true
        ? host!.trim()
        : imapClient.defaultHost;
    final targetPort = port ?? imapClient.defaultPort;
    final account = username?.trim() ?? '';
    int savedCount = 0;

    Future<Set<int>> handleMissingUids(int validity, List<int> uids) async {
      final ids = {
        for (final uid in uids)
          uid:
              'email_${JwImapClient.scopedMessageId(host: targetHost, port: targetPort, username: account, uidValidity: validity, uid: uid)}',
      };
      final existing = await (db.select(
        db.inboxEntries,
      )..where((t) => t.id.isIn(ids.values.toList()))).get();
      final retained = existing.map((item) => item.id).toSet();
      return ids.entries
          .where((item) => !retained.contains(item.value))
          .map((item) => item.key)
          .toSet();
    }

    final Stream<List<JwEmailMessage>> pagesStream =
        imapClient.runtimeType == JwImapClient
        ? imapClient.fetchAllMailboxPages(
            host: host,
            port: port,
            username: username,
            password: password,
            accountEmail: accountEmail,
            missingUids: handleMissingUids,
            missingMailboxUids: (mailboxPath, validity, uids) async {
              final ids = {
                for (final uid in uids)
                  uid:
                      'email_${JwImapClient.scopedMessageId(host: targetHost, port: targetPort, username: account, uidValidity: validity, uid: uid, mailbox: mailboxPath)}',
              };
              final existing = await (db.select(
                db.inboxEntries,
              )..where((t) => t.id.isIn(ids.values.toList()))).get();
              final retained = existing.map((item) => item.id).toSet();
              return ids.entries
                  .where((item) => !retained.contains(item.value))
                  .map((item) => item.key)
                  .toSet();
            },
            onMailboxFlags: (mailboxPath, folderName, validity, flags) async {
              final entryIds = <int, String>{
                for (final flag in flags)
                  flag.uid:
                      'email_${JwImapClient.scopedMessageId(host: targetHost, port: targetPort, username: account, uidValidity: validity, uid: flag.uid, mailbox: mailboxPath)}',
              };
              if (entryIds.isEmpty) return;
              final existingRows = await (db.select(
                db.inboxEntries,
              )..where((t) => t.id.isIn(entryIds.values.toList()))).get();
              if (existingRows.isEmpty) return;
              final flagByEntryId = {
                for (final flag in flags) entryIds[flag.uid]!: flag.isSeen,
              };
              await db.transaction(() async {
                final now = DateTime.now().toUtc();
                for (final row in existingRows) {
                  if (row.metadata.isEmpty) continue;
                  final meta = jsonDecode(row.metadata) as Map<String, dynamic>;
                  final rawEmail = meta['email'];
                  if (rawEmail is! Map) continue;
                  final emailMap = Map<String, dynamic>.from(rawEmail);
                  final currentIsRead = emailMap['isRead'] as bool? ?? false;
                  final currentFolder = emailMap['folderName'] as String?;
                  final remoteIsRead = flagByEntryId[row.id] ?? currentIsRead;
                  if (currentIsRead == remoteIsRead &&
                      currentFolder == folderName &&
                      emailMap['folderId'] == mailboxPath) {
                    continue;
                  }
                  emailMap['isRead'] = remoteIsRead;
                  emailMap['folderName'] = folderName;
                  emailMap['folderId'] = mailboxPath;
                  meta['email'] = emailMap;
                  final updatedMeta = jsonEncode(meta);
                  await (db.update(
                    db.inboxEntries,
                  )..where((t) => t.id.equals(row.id))).write(
                    InboxEntriesCompanion(
                      metadata: drift.Value(updatedMeta),
                      updatedAt: drift.Value(now),
                      revision: drift.Value(row.revision + 1),
                    ),
                  );
                }
              });
            },
          )
        : imapClient.fetchRemoteEmailPages(
            host: host,
            port: port,
            username: username,
            password: password,
            accountEmail: accountEmail,
            missingUids: handleMissingUids,
          );

    await for (final page in pagesStream) {
      // Cada lote é confirmado antes de solicitar o próximo. Em interrupção,
      // a próxima execução consulta o banco e busca somente UIDs ausentes.
      await db.transaction(() async {
        final now = DateTime.now().toUtc();
        for (final msg in page) {
          final entryId = 'email_${msg.id}';
          final existing = await (db.select(
            db.inboxEntries,
          )..where((t) => t.id.equals(entryId))).getSingleOrNull();
          if (existing != null) continue;
          final sourceType = msg.isHubCommunication
              ? (msg.hubType == 'form' ? 'hub_form' : 'hub_letter')
              : 'email';
          final persistedAttachments =
              JwEmailMessage.sanitizeAttachmentsForPersistence(msg.attachments);
          final metadata = {
            'permanentRetention': true,
            'retentionDate': now.toIso8601String(),
            'email': msg.toJson(),
          };
          final category = msg.isHubCommunication
              ? (msg.hubType == 'form'
                    ? 'hub_form'
                    : (msg.hubType == 'letter' ? 'hub_letter' : 'hub_comms'))
              : 'email';
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
                  attachments: drift.Value(jsonEncode(persistedAttachments)),
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
          await EmailContactsManager.recordSender(db, msg.from);
          savedCount++;
        }
      });
    }

    return savedCount;
  }

  /// Observa mensagens retidas permanentemente
  Stream<List<JwEmailMessage>> watchRetainedEmails({
    bool hubOnly = false,
    String? tagFilter,
    String? searchQuery,
  }) {
    final query = db.select(db.inboxEntries)
      ..where((t) => t.deletedAt.isNull());

    if (hubOnly) {
      query.where(
        (t) =>
            t.sourceType.equals('hub_letter') | t.sourceType.equals('hub_form'),
      );
    } else {
      query.where(
        (t) =>
            t.sourceType.equals('email') |
            t.sourceType.equals('email_draft') |
            t.sourceType.equals('hub_letter') |
            t.sourceType.equals('hub_form'),
      );
    }

    query.orderBy([(t) => drift.OrderingTerm.desc(t.capturedAt)]);

    return query.watch().map((entries) {
      final messages = <JwEmailMessage>[];
      for (final entry in entries) {
        try {
          if (entry.metadata.isNotEmpty) {
            final meta = jsonDecode(entry.metadata) as Map<String, dynamic>;
            if (meta.containsKey('email')) {
              final emailMap = Map<String, dynamic>.from(meta['email'] as Map);
              var msg = JwEmailMessage.fromJson(emailMap);
              if (hubOnly && !msg.isHubCommunication) continue;
              if (tagFilter != null &&
                  tagFilter.isNotEmpty &&
                  !msg.tags.contains(tagFilter)) {
                continue;
              }
              if (searchQuery != null && searchQuery.trim().isNotEmpty) {
                final q = searchQuery.toLowerCase();
                final match =
                    msg.subject.toLowerCase().contains(q) ||
                    msg.bodyText.toLowerCase().contains(q) ||
                    msg.from.toLowerCase().contains(q) ||
                    msg.tags.any((t) => t.toLowerCase().contains(q));
                if (!match) continue;
              }
              messages.add(msg);
              continue;
            }
          }
        } catch (e, st) {
          AppLogger.debug(
            'Fallback para InboxEntry bruto em ${entry.id}: $e',
            st,
          );
        }

        // Fallback construído a partir do InboxEntry bruto
        final isHub =
            entry.sourceType == 'hub_letter' ||
            entry.sourceType == 'hub_form' ||
            entry.suggestedCategory == 'hub_comms';
        final split = entry.content.split('\n\n');
        final subject = split.first;
        final body = split.length > 1 ? split.sublist(1).join('\n\n') : '';

        messages.add(
          JwEmailMessage(
            id: entry.id.replaceFirst('email_', ''),
            subject: subject,
            from: isHub ? 'hub.jw.org' : 'mail.jw.org',
            to: 'local_user',
            date: entry.capturedAt,
            bodyText: body,
            isHubCommunication: isHub,
            hubType: entry.sourceType == 'hub_form' ? 'form' : 'letter',
          ),
        );
      }
      return messages;
    });
  }

  /// Salva rascunho de e-mail teocrático de forma transacional com controle de revisão e snapshot `_base`.
  Future<void> saveDraft(JwEmailMessage draft) async {
    final entryId = 'email_draft_${draft.id}';
    final now = DateTime.now().toUtc();

    final metadata = {
      'permanentRetention': true,
      'isDraft': true,
      'email': draft.copyWith(isDraft: true).toJson(),
    };

    await db.transaction(() async {
      final existingDraft = await (db.select(
        db.inboxEntries,
      )..where((t) => t.id.equals(entryId))).getSingleOrNull();
      final isUpdate = existingDraft != null;
      final nextRevision = isUpdate ? existingDraft.revision + 1 : 1;

      bool isExchange = false;
      if (draft.accountEmail != null && draft.accountEmail!.isNotEmpty) {
        final accounts = await EmailAccountsManager.loadAccounts(db);
        final acc = accounts.firstWhereOrNull(
          (a) => a.email.toLowerCase() == draft.accountEmail!.toLowerCase(),
        );
        isExchange = acc?.incomingProtocol == 'exchange';
      }
      final cleanBody = draft.bodyText.isNotEmpty
          ? EmailHtmlSanitizer.extractPlainText(draft.bodyText)
          : (draft.bodyHtml != null
                ? EmailHtmlSanitizer.extractPlainText(draft.bodyHtml!)
                : '');

      final companion = InboxEntriesCompanion.insert(
        id: entryId,
        content: '${draft.subject}\n\n$cleanBody'.trim(),
        sourceType: const drift.Value('email_draft'),
        suggestedCategory: drift.Value(isExchange ? 'email_jw' : 'email'),
        attachments: drift.Value(jsonEncode(draft.attachments)),
        capturedAt: isUpdate ? existingDraft.capturedAt : now,
        metadata: drift.Value(jsonEncode(metadata)),
        createdAt: isUpdate ? existingDraft.createdAt : now,
        updatedAt: now,
        revision: drift.Value(nextRevision),
      );

      await db.into(db.inboxEntries).insertOnConflictUpdate(companion);
      final persisted = await (db.select(
        db.inboxEntries,
      )..where((t) => t.id.equals(entryId))).getSingle();

      final payload = SyncTimestamp.normalizeMapDates(persisted.toJson());
      if (isUpdate) {
        payload['_base'] = SyncTimestamp.normalizeMapDates(
          existingDraft.toJson(),
        );
      }

      await db
          .into(db.syncQueue)
          .insert(
            SyncQueueCompanion.insert(
              id: const Uuid().v4(),
              entityType: 'inbox_entries',
              entityId: entryId,
              operation: isUpdate ? 'UPDATE' : 'INSERT',
              payload: jsonEncode(payload),
              createdAt: now,
            ),
          );
    });
  }

  /// Envia e-mail real via servidor SMTP autenticado e persiste registro local retido
  /// em transação única com incremento de `revision` e snapshot `_base`.
  /// Nunca simula envio: falhas de configuração, autenticação ou rede lançam [JwEmailException].
  Future<JwEmailMessage> sendEmail({
    required String host,
    required int port,
    required String username,
    required String password,
    required JwEmailMessage message,
    String securityMode = 'starttls',
    String? draftId,
  }) async {
    await smtpClient.sendMail(
      host: host,
      port: port,
      username: username,
      password: password,
      message: message,
      securityMode: securityMode,
    );

    final now = DateTime.now().toUtc();
    final sentMsg = message.copyWith(
      accountEmail: message.accountEmail ?? username.trim(),
      folderName: message.folderName ?? 'Enviados',
      from:
          message.from.trim().isNotEmpty && message.from != 'local@dispositivo'
          ? message.from
          : username.trim(),
      date: now,
      isDraft: false,
      isRead: true,
      isPermanentRetained: true,
    );

    final targetId = draftId != null
        ? 'email_draft_$draftId'
        : 'email_${sentMsg.id}';

    final metadata = {
      'permanentRetention': true,
      'isDraft': false,
      'sentAt': now.toIso8601String(),
      'smtpHost': host,
      'smtpPort': port,
      'email': sentMsg.toJson(),
    };

    await db.transaction(() async {
      final existingDraft = draftId == null
          ? await (db.select(db.inboxEntries)
                  ..where((t) => t.id.equals('email_draft_${sentMsg.id}')))
                .getSingleOrNull()
          : null;
      final resolvedEntryId = draftId != null
          ? targetId
          : (existingDraft?.id ?? targetId);

      final existingSent = await (db.select(
        db.inboxEntries,
      )..where((t) => t.id.equals(resolvedEntryId))).getSingleOrNull();
      final isUpdate = existingSent != null;
      final nextRevision = isUpdate ? existingSent.revision + 1 : 1;

      bool isExchange = false;
      if (sentMsg.accountEmail != null && sentMsg.accountEmail!.isNotEmpty) {
        final accounts = await EmailAccountsManager.loadAccounts(db);
        final acc = accounts.firstWhereOrNull(
          (a) => a.email.toLowerCase() == sentMsg.accountEmail!.toLowerCase(),
        );
        isExchange = acc?.incomingProtocol == 'exchange';
      }
      final cleanBody = sentMsg.bodyText.isNotEmpty
          ? EmailHtmlSanitizer.extractPlainText(sentMsg.bodyText)
          : (sentMsg.bodyHtml != null
                ? EmailHtmlSanitizer.extractPlainText(sentMsg.bodyHtml!)
                : '');

      final companion = InboxEntriesCompanion.insert(
        id: resolvedEntryId,
        content: '${sentMsg.subject}\n\n$cleanBody'.trim(),
        sourceType: const drift.Value('email'),
        suggestedCategory: drift.Value(isExchange ? 'email_jw' : 'email'),
        attachments: drift.Value(jsonEncode(sentMsg.attachments)),
        capturedAt: now,
        metadata: drift.Value(jsonEncode(metadata)),
        createdAt: isUpdate ? existingSent.createdAt : now,
        updatedAt: now,
        revision: drift.Value(nextRevision),
      );

      await db.into(db.inboxEntries).insertOnConflictUpdate(companion);
      final persisted = await (db.select(
        db.inboxEntries,
      )..where((t) => t.id.equals(resolvedEntryId))).getSingle();

      final payload = SyncTimestamp.normalizeMapDates(persisted.toJson());
      if (isUpdate) {
        payload['_base'] = SyncTimestamp.normalizeMapDates(
          existingSent.toJson(),
        );
      }

      await db
          .into(db.syncQueue)
          .insert(
            SyncQueueCompanion.insert(
              id: const Uuid().v4(),
              entityType: 'inbox_entries',
              entityId: resolvedEntryId,
              operation: isUpdate ? 'UPDATE' : 'INSERT',
              payload: jsonEncode(payload),
              createdAt: now,
            ),
          );
    });
    return sentMsg;
  }

  /// Exportação dinâmica de mensagens ou anotações (PDF, Markdown, Texto ou EML)
  Future<String> exportEmail(
    JwEmailMessage message, {
    required String format, // 'pdf', 'markdown', 'text', 'eml'
  }) async {
    if (format.toLowerCase() == 'pdf') {
      final saved = await KnowledgeAndEmailPdfService.exportEmailPdf(message);
      return saved ?? '';
    }
    String content;
    String extension;

    switch (format.toLowerCase()) {
      case 'eml':
      case 'email':
        content = message.toEml();
        extension = 'eml';
        break;
      case 'text':
      case 'txt':
        content = message.toPlainText();
        extension = 'txt';
        break;
      case 'markdown':
      case 'md':
      default:
        content = message.toMarkdown();
        extension = 'md';
        break;
    }

    // Copia para área de transferência para facilidade do usuário
    await Clipboard.setData(ClipboardData(text: content));

    // Aciona download do arquivo (Web ou plataforma de destino)
    final sanitizedSubject = message.subject
        .replaceAll(RegExp(r'[^\w\s\-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    final filename =
        '${sanitizedSubject.isEmpty ? "email_retido" : sanitizedSubject}.$extension';
    FileDownloader.download(filename, content);

    return content;
  }

  /// Exportação dinâmica de itens genéricos do Inbox (PDF, Markdown ou Texto)
  Future<String> exportInboxEntry(
    InboxEntry entry, {
    required String format, // 'pdf', 'markdown', 'text'
  }) async {
    if (format.toLowerCase() == 'pdf') {
      final saved = await KnowledgeAndEmailPdfService.exportInboxEntryPdf(
        entry,
      );
      return saved ?? '';
    }
    final buffer = StringBuffer();
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(entry.capturedAt);

    if (format.toLowerCase() == 'text' || format.toLowerCase() == 'txt') {
      buffer.writeln('ITEM DE INBOX [${entry.sourceType.toUpperCase()}]');
      buffer.writeln('DATA: $dateStr');
      if (entry.suggestedCategory != null) {
        buffer.writeln('CATEGORIA: ${entry.suggestedCategory}');
      }
      buffer.writeln('----------------------------------------');
      buffer.writeln(entry.content);
    } else {
      buffer.writeln('# Nota do Inbox (${entry.sourceType.toUpperCase()})');
      buffer.writeln();
      buffer.writeln('| Detalhe | Valor |');
      buffer.writeln('| :--- | :--- |');
      buffer.writeln('| **Capturado em** | $dateStr |');
      buffer.writeln('| **Tipo** | `${entry.sourceType}` |');
      if (entry.suggestedCategory != null) {
        buffer.writeln('| **Categoria** | `${entry.suggestedCategory}` |');
      }
      buffer.writeln();
      buffer.writeln('---');
      buffer.writeln();
      buffer.writeln(entry.content);
    }

    final content = buffer.toString();
    await Clipboard.setData(ClipboardData(text: content));

    final filename =
        'inbox_nota_${entry.id.substring(0, 8)}.${format == "text" ? "txt" : "md"}';
    FileDownloader.download(filename, content);

    return content;
  }

  static String _entryIdFor(String emailId) =>
      emailId.startsWith('email_') ? emailId : 'email_$emailId';

  /// Atualiza o status de leitura (`isRead`) de um ou mais e-mails em transação única.
  Future<int> setEmailsReadStatus(
    List<String> emailIds, {
    required bool isRead,
  }) async {
    if (emailIds.isEmpty) return 0;
    final entryIds = emailIds.map(_entryIdFor).toSet().toList();
    var updated = 0;
    await db.transaction(() async {
      final rows = await (db.select(
        db.inboxEntries,
      )..where((t) => t.id.isIn(entryIds))).get();
      final now = DateTime.now().toUtc();
      for (final row in rows) {
        if (row.metadata.isEmpty) continue;
        final meta = Map<String, dynamic>.from(jsonDecode(row.metadata) as Map);
        final rawEmail = meta['email'];
        if (rawEmail is! Map) continue;
        final emailMap = Map<String, dynamic>.from(rawEmail);
        if ((emailMap['isRead'] as bool? ?? false) == isRead) continue;
        emailMap['isRead'] = isRead;
        emailMap['attachments'] =
            JwEmailMessage.sanitizeAttachmentsForPersistence(
              (emailMap['attachments'] as List<dynamic>?)
                      ?.map((e) => Map<String, dynamic>.from(e as Map))
                      .toList() ??
                  const [],
            );
        meta['email'] = emailMap;
        final updatedMeta = jsonEncode(meta);
        await (db.update(
          db.inboxEntries,
        )..where((t) => t.id.equals(row.id))).write(
          InboxEntriesCompanion(
            metadata: drift.Value(updatedMeta),
            updatedAt: drift.Value(now),
            revision: drift.Value(row.revision + 1),
          ),
        );
        final refreshed = await (db.select(
          db.inboxEntries,
        )..where((t) => t.id.equals(row.id))).getSingle();
        await db
            .into(db.syncQueue)
            .insert(
              SyncQueueCompanion.insert(
                id: const Uuid().v4(),
                entityType: 'inbox_entries',
                entityId: row.id,
                operation: 'UPDATE',
                payload: jsonEncode(refreshed.toJson()),
                createdAt: now,
              ),
            );
        updated++;
      }
    });
    return updated;
  }

  /// Move um ou mais e-mails localmente para [targetFolderName], preservando metadados
  /// e atualizando eventuais novos IDs remotos retornados pelo servidor (ex.: Graph `/move`).
  Future<int> moveEmailsToFolder(
    List<String> emailIds, {
    required String targetFolderName,
    Map<String, String>? updatedRemoteIds,
  }) async {
    if (emailIds.isEmpty) return 0;
    final entryIds = emailIds.map(_entryIdFor).toSet().toList();
    var moved = 0;
    await db.transaction(() async {
      final rows = await (db.select(
        db.inboxEntries,
      )..where((t) => t.id.isIn(entryIds))).get();
      final now = DateTime.now().toUtc();
      for (final row in rows) {
        if (row.metadata.isEmpty) continue;
        final meta = Map<String, dynamic>.from(jsonDecode(row.metadata) as Map);
        final rawEmail = meta['email'];
        if (rawEmail is! Map) continue;
        final emailMap = Map<String, dynamic>.from(rawEmail);
        final originalEmailId = emailMap['id']?.toString();
        final newRemoteId =
            updatedRemoteIds?[originalEmailId] ?? updatedRemoteIds?[row.id];

        emailMap['folderName'] = targetFolderName;
        emailMap['isDraft'] = targetFolderName == 'Rascunhos';
        if (newRemoteId != null && newRemoteId.isNotEmpty) {
          emailMap['remoteId'] = newRemoteId;
        }
        emailMap['attachments'] =
            JwEmailMessage.sanitizeAttachmentsForPersistence(
              (emailMap['attachments'] as List<dynamic>?)
                      ?.map((e) => Map<String, dynamic>.from(e as Map))
                      .toList() ??
                  const [],
            );
        meta['email'] = emailMap;

        final updatedMeta = jsonEncode(meta);
        await (db.update(
          db.inboxEntries,
        )..where((t) => t.id.equals(row.id))).write(
          InboxEntriesCompanion(
            metadata: drift.Value(updatedMeta),
            updatedAt: drift.Value(now),
            revision: drift.Value(row.revision + 1),
          ),
        );
        final refreshed = await (db.select(
          db.inboxEntries,
        )..where((t) => t.id.equals(row.id))).getSingle();
        await db
            .into(db.syncQueue)
            .insert(
              SyncQueueCompanion.insert(
                id: const Uuid().v4(),
                entityType: 'inbox_entries',
                entityId: row.id,
                operation: 'UPDATE',
                payload: jsonEncode(refreshed.toJson()),
                createdAt: now,
              ),
            );
        moved++;
      }
    });
    return moved;
  }

  /// Exclui em lote mensagens de e-mail (soft-delete local; se [moveToTrashOnly]
  /// for true e a mensagem não estiver na Lixeira, move para Lixeira em vez de ocultar).
  Future<int> deleteEmails(
    List<String> emailIds, {
    bool moveToTrashOnly = false,
  }) async {
    if (emailIds.isEmpty) return 0;
    final entryIds = emailIds.map(_entryIdFor).toSet().toList();
    if (moveToTrashOnly) {
      return moveEmailsToFolder(entryIds, targetFolderName: 'Lixeira');
    }
    var deleted = 0;
    await db.transaction(() async {
      final rows = await (db.select(
        db.inboxEntries,
      )..where((t) => t.id.isIn(entryIds))).get();
      final now = DateTime.now().toUtc();
      for (final row in rows) {
        await (db.update(
          db.inboxEntries,
        )..where((t) => t.id.equals(row.id))).write(
          InboxEntriesCompanion(
            deletedAt: drift.Value(now),
            updatedAt: drift.Value(now),
            revision: drift.Value(row.revision + 1),
          ),
        );
        await db
            .into(db.syncQueue)
            .insert(
              SyncQueueCompanion.insert(
                id: const Uuid().v4(),
                entityType: 'inbox_entries',
                entityId: row.id,
                operation: 'UPDATE',
                payload: jsonEncode({
                  'id': row.id,
                  'deleted_at': now.toIso8601String(),
                }),
                createdAt: now,
              ),
            );
        deleted++;
      }
    });
    return deleted;
  }

  /// Exclui uma mensagem de e-mail (soft-delete seguro preservando integridade local e de sincronização)
  Future<void> deleteEmail(String emailId) async {
    await deleteEmails([emailId]);
  }
}
