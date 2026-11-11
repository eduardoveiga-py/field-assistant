import 'dart:async';
import 'dart:convert';
import 'dart:io'
    show
        InternetAddress,
        SecureSocket,
        Socket,
        SocketException,
        X509Certificate;
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:drift/drift.dart' as drift;
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../core/app_logger.dart';
import '../core/biometric_auth_service.dart';
import '../database/app_database.dart';
import '../reports/web_downloader.dart';

/// Modelo de mensagem de e-mail teocrático (JW.org Mail e Comunicações Restritas do Hub)
class JwEmailMessage {
  final String id;
  final int? remoteUid;
  final String subject;
  final String from;
  final String to;
  final DateTime date;
  final String bodyText;
  final String? bodyHtml;
  final List<Map<String, dynamic>> attachments;
  final bool isRead;
  final bool isDraft;
  final bool isPermanentRetained;
  final List<String> tags;
  final bool isHubCommunication;
  final String? hubType; // 'letter', 'announcement', 'form', 'policy'

  JwEmailMessage({
    required this.id,
    this.remoteUid,
    required this.subject,
    required this.from,
    required this.to,
    required this.date,
    required this.bodyText,
    this.bodyHtml,
    this.attachments = const [],
    this.isRead = false,
    this.isDraft = false,
    this.isPermanentRetained = true,
    this.tags = const [],
    this.isHubCommunication = false,
    this.hubType,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'remoteUid': remoteUid,
        'subject': subject,
        'from': from,
        'to': to,
        'date': date.toIso8601String(),
        'bodyText': bodyText,
        'bodyHtml': bodyHtml,
        'attachments': attachments,
        'isRead': isRead,
        'isDraft': isDraft,
        'isPermanentRetained': isPermanentRetained,
        'tags': tags,
        'isHubCommunication': isHubCommunication,
        'hubType': hubType,
      };

  factory JwEmailMessage.fromJson(Map<String, dynamic> json) => JwEmailMessage(
        id: json['id'] as String? ?? const Uuid().v4(),
        remoteUid: json['remoteUid'] as int?,
        subject: json['subject'] as String? ?? '(Sem Assunto)',
        from: json['from'] as String? ?? 'jw@jw.org',
        to: json['to'] as String? ?? '',
        date: json['date'] != null
            ? DateTime.tryParse(json['date'] as String) ?? DateTime.now()
            : DateTime.now(),
        bodyText: json['bodyText'] as String? ?? '',
        bodyHtml: json['bodyHtml'] as String?,
        attachments: (json['attachments'] as List<dynamic>?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            const [],
        isRead: json['isRead'] as bool? ?? false,
        isDraft: json['isDraft'] as bool? ?? false,
        isPermanentRetained: json['isPermanentRetained'] as bool? ?? true,
        tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
            const [],
        isHubCommunication: json['isHubCommunication'] as bool? ?? false,
        hubType: json['hubType'] as String?,
      );

  JwEmailMessage copyWith({
    String? id,
    int? remoteUid,
    String? subject,
    String? from,
    String? to,
    DateTime? date,
    String? bodyText,
    String? bodyHtml,
    List<Map<String, dynamic>>? attachments,
    bool? isRead,
    bool? isDraft,
    bool? isPermanentRetained,
    List<String>? tags,
    bool? isHubCommunication,
    String? hubType,
  }) {
    return JwEmailMessage(
      id: id ?? this.id,
      remoteUid: remoteUid ?? this.remoteUid,
      subject: subject ?? this.subject,
      from: from ?? this.from,
      to: to ?? this.to,
      date: date ?? this.date,
      bodyText: bodyText ?? this.bodyText,
      bodyHtml: bodyHtml ?? this.bodyHtml,
      attachments: attachments ?? this.attachments,
      isRead: isRead ?? this.isRead,
      isDraft: isDraft ?? this.isDraft,
      isPermanentRetained: isPermanentRetained ?? this.isPermanentRetained,
      tags: tags ?? this.tags,
      isHubCommunication: isHubCommunication ?? this.isHubCommunication,
      hubType: hubType ?? this.hubType,
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
    buffer.writeln('| **Data** | ${DateFormat('dd/MM/yyyy HH:mm').format(date)} |');
    if (tags.isNotEmpty) {
      buffer.writeln('| **Tags** | ${tags.map((t) => '`#$t`').join(' ')} |');
    }
    if (isHubCommunication) {
      buffer.writeln('| **Origem** | Hub Restrito JW (${hubType ?? "Comunicação"}) |');
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
    final rfcDate = DateFormat('EEE, dd MMM yyyy HH:mm:ss +0000').format(date.toUtc());
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

/// Leitor assíncrono linha-a-linha de streams TCP/TLS para protocolos orientados a texto (RFC 3501 IMAP)
class _ImapLineReader {
  final StreamSubscription<String> _subscription;
  final List<String> _bufferedLines = [];
  final List<Completer<String>> _waiters = [];
  bool _isClosed = false;

  _ImapLineReader(Stream<String> lineStream)
      : _subscription = lineStream.listen(null) {
    _subscription.onData((line) {
      if (_waiters.isNotEmpty) {
        _waiters.removeAt(0).complete(line);
      } else {
        _bufferedLines.add(line);
      }
    });
    _subscription.onDone(() {
      _isClosed = true;
      for (final w in _waiters) {
        if (!w.isCompleted) {
          w.completeError(const JwEmailConnectionException('Conexão encerrada pelo servidor IMAP.'));
        }
      }
      _waiters.clear();
    });
    _subscription.onError((err) {
      for (final w in _waiters) {
        if (!w.isCompleted) {
          w.completeError(JwEmailConnectionException('Erro no fluxo de comunicação IMAP: $err', err));
        }
      }
      _waiters.clear();
    });
  }

  Future<String> readLine({Duration timeout = const Duration(seconds: 10)}) async {
    if (_bufferedLines.isNotEmpty) {
      return _bufferedLines.removeAt(0);
    }
    if (_isClosed) {
      throw const JwEmailConnectionException('Conexão encerrada pelo servidor IMAP.');
    }
    final completer = Completer<String>();
    _waiters.add(completer);
    return completer.future.timeout(
      timeout,
      onTimeout: () {
        _waiters.remove(completer);
        throw const JwEmailConnectionException('Tempo limite esgotado aguardando resposta do servidor IMAP.');
      },
    );
  }

  Future<void> close() async {
    await _subscription.cancel();
  }
}

/// Cliente IMAP puro Dart para conexão SSL/TLS na porta 993 de mail.jw.org
/// com resiliência total para modo offline e retenção permanente.
/// Comunicação RFC 3501 autêntica sem sementes fictícias.
class JwImapClient {
  final String defaultHost;
  final int defaultPort;

  const JwImapClient({
    this.defaultHost = 'mail.jw.org',
    this.defaultPort = 993,
  });

  /// Decodifica cabeçalhos MIME RFC 2047 (=?UTF-8?B?...?= ou =?UTF-8?Q?...?=)
  static String decodeMimeHeader(String raw) {
    final pattern = RegExp(r'=\?([^?]+)\?([bBqQ])\?([^?]+)\?=', caseSensitive: false);
    return raw.replaceAllMapped(pattern, (match) {
      final encoding = match.group(2)!.toUpperCase();
      final text = match.group(3)!;
      try {
        if (encoding == 'B') {
          return utf8.decode(base64.decode(text));
        } else if (encoding == 'Q') {
          return text
              .replaceAll('_', ' ')
              .replaceAllMapped(RegExp(r'=([A-Fa-f0-9]{2})'), (m) {
            final byte = int.parse(m.group(1)!, radix: 16);
            return String.fromCharCode(byte);
          });
        }
      } catch (e, st) {
        AppLogger.debug('Falha ao decodificar cabeçalho RFC 2047: $e', st);
      }
      return match.group(0)!;
    });
  }

  /// Conecta ao servidor IMAP com TLS e sincroniza as mensagens
  Future<List<JwEmailMessage>> fetchRemoteEmails({
    String? host,
    int? port,
    String? username,
    String? password,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    // 1. Se credenciais não forem fornecidas, retorna lista vazia imediatamente sem erro e sem seeds
    if (username == null || username.trim().isEmpty || password == null || password.trim().isEmpty) {
      return const <JwEmailMessage>[];
    }

    // 2. Ambiente Web não possui suporte a sockets TCP diretos via dart:io
    if (kIsWeb) {
      throw const JwEmailConnectionException(
        'Conexão direta a sockets IMAP não é suportada no navegador Web. Utilize o aplicativo Desktop ou Mobile.',
      );
    }

    final targetHost = (host != null && host.trim().isNotEmpty)
        ? host.trim()
        : defaultHost;
    final targetPort = port ?? defaultPort;
    if (targetPort <= 0 || targetPort > 65535) {
      throw JwEmailConnectionException(
        'Porta IMAP inválida ($targetPort). Informe um valor entre 1 e 65535.',
      );
    }

    SecureSocket socket;
    try {
      socket = await SecureSocket.connect(
        targetHost,
        targetPort,
        timeout: timeout,
      );
    } on SocketException catch (e) {
      throw JwEmailConnectionException(
        'Não foi possível conectar ao servidor IMAP em $targetHost:$targetPort: ${e.message}',
        e,
      );
    } on TimeoutException catch (e) {
      throw JwEmailConnectionException(
        'Tempo limite esgotado ao conectar ao servidor IMAP ($targetHost:$targetPort).',
        e,
      );
    } catch (e) {
      throw JwEmailConnectionException(
        'Erro na conexão segura SSL/TLS com $targetHost:$targetPort: $e',
        e,
      );
    }

    final lineStream = utf8.decoder.bind(socket).transform(const LineSplitter());
    final reader = _ImapLineReader(lineStream);

    try {
      // 1. Saudação do Servidor (* OK ...)
      final greeting = await reader.readLine(timeout: timeout);
      if (greeting.startsWith('* BYE')) {
        throw JwEmailConnectionException('Servidor IMAP recusou a conexão: $greeting');
      }

      // 2. Autenticação (LOGIN)
      final safeUser = username.trim().replaceAll(r'\', r'\\').replaceAll('"', r'\"');
      final safePass = password.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
      socket.write('A01 LOGIN "$safeUser" "$safePass"\r\n');
      await socket.flush();

      while (true) {
        final line = await reader.readLine(timeout: timeout);
        if (line.startsWith('A01 OK')) {
          break; // Autenticação bem-sucedida
        } else if (line.startsWith('A01 NO')) {
          throw const JwEmailAuthException('Falha de autenticação IMAP: usuário ou senha incorretos.');
        } else if (line.startsWith('A01 BAD')) {
          throw JwEmailAuthException('Comando de autenticação rejeitado pelo servidor: $line');
        }
      }

      // 3. Seleção da Caixa de Entrada (SELECT INBOX)
      socket.write('A02 SELECT INBOX\r\n');
      await socket.flush();

      int existsCount = 0;
      while (true) {
        final line = await reader.readLine(timeout: timeout);
        if (line.startsWith('* ') && line.contains('EXISTS')) {
          final match = RegExp(r'\*\s+(\d+)\s+EXISTS').firstMatch(line);
          if (match != null) {
            existsCount = int.tryParse(match.group(1) ?? '0') ?? 0;
          }
        }
        if (line.startsWith('A02 OK')) {
          break;
        } else if (line.startsWith('A02 NO') || line.startsWith('A02 BAD')) {
          throw JwEmailConnectionException('Falha ao selecionar caixa de entrada (INBOX): $line');
        }
      }

      // Se a caixa estiver vazia, encerra normalmente
      if (existsCount == 0) {
        try {
          socket.write('A03 LOGOUT\r\n');
          await socket.flush();
        } catch (e, st) {
          AppLogger.debug('Falha ao enviar LOGOUT IMAP (INBOX vazia): $e', st);
        }
        return const <JwEmailMessage>[];
      }

      // 4. Busca das Mensagens (FETCH das mensagens mais recentes, até 25)
      final startIdx = existsCount > 25 ? (existsCount - 24) : 1;
      socket.write('A03 FETCH $startIdx:$existsCount (UID RFC822.SIZE BODY.PEEK[HEADER.FIELDS (SUBJECT FROM TO DATE)] BODY.PEEK[TEXT])\r\n');
      await socket.flush();

      final responseLines = <String>[];
      while (true) {
        final line = await reader.readLine(timeout: timeout);
        if (line.startsWith('A03 OK') || line.startsWith('A03 NO') || line.startsWith('A03 BAD')) {
          break;
        }
        responseLines.add(line);
      }

      // 5. Logout gracioso
      try {
        socket.write('A04 LOGOUT\r\n');
        await socket.flush();
      } catch (e, st) {
        AppLogger.debug('Falha ao enviar LOGOUT IMAP: $e', st);
      }

      // 6. Parsing estruturado das mensagens recebidas
      return _parseImapResponses(responseLines);
    } finally {
      await reader.close();
      try {
        await socket.close();
      } catch (e, st) {
        AppLogger.debug('Falha ao fechar socket IMAP: $e', st);
      }
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
    if (day == null || month == null || year == null || hour == null || minute == null) {
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
    return DateTime.utc(year, month, day, hour, minute, second).subtract(offset);
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
      if (currentSubject != null || currentFrom != null || currentBodyBuffer.isNotEmpty) {
        final fromStr = currentFrom ?? 'desconhecido@jw.org';
        final isHub = fromStr.contains('hub.jw.org');
        final subjectStr = currentSubject ?? '(Sem Assunto)';
        final isForm = subjectStr.toLowerCase().contains('formulário') || subjectStr.toLowerCase().contains('s-');
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

      if (RegExp(r'^BODY\[HEADER[^\]]*\]\s*\{\d+\}\s*$', caseSensitive: false).hasMatch(line.trim())) {
        inBody = false;
        continue;
      }

      if (RegExp(r'^BODY\[TEXT\]\s*\{\d+\}\s*$', caseSensitive: false).hasMatch(line.trim())) {
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
        } else if (line.isEmpty && (currentSubject != null || currentFrom != null)) {
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
    final candidate = angleMatch != null ? angleMatch.group(1)!.trim() : trimmed;
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
        throw JwEmailConnectionException('Resposta SMTP inválida recebida: $line');
      }
      final code = int.tryParse(line.substring(0, 3));
      if (code == null) {
        throw JwEmailConnectionException('Código SMTP inesperado recebido: $line');
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
      final end = (i + lineLength < input.length) ? i + lineLength : input.length;
      buffer.write(input.substring(i, end));
      buffer.write('\r\n');
    }
    return buffer.toString();
  }

  static String _formatRfc2822Date(DateTime dateTime) {
    final utc = dateTime.toUtc();
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    String two(int n) => n.toString().padLeft(2, '0');
    return '${weekdays[utc.weekday - 1]}, ${two(utc.day)} ${months[utc.month - 1]} '
        '${utc.year} ${two(utc.hour)}:${two(utc.minute)}:${two(utc.second)} +0000';
  }

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
    final senderAddr = extractValidEmailAddress(cleanUser);
    if (senderAddr == null) {
      throw const JwEmailAuthException(
        'Endereço de e-mail remetente inválido nas configurações.',
      );
    }

    List<String> recipients = const [];
    if (messageToSend != null) {
      recipients = parseRecipients(messageToSend.to);
      if (recipients.isEmpty) {
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
        utf8.decoder.bind(activeSocket as Stream<List<int>>).transform(
          const LineSplitter(),
        ),
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
        final token = base64.encode(utf8.encode('\u0000$cleanUser\u0000$password'));
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
        final payload = StringBuffer()
          ..write('From: <$senderAddr>\r\n')
          ..write('To: ${recipients.map((r) => '<$r>').join(', ')}\r\n')
          ..write('Subject: ${encodeHeaderValue(messageToSend.subject)}\r\n')
          ..write('Date: ${_formatRfc2822Date(nowUtc)}\r\n')
          ..write('Message-ID: $messageId\r\n')
          ..write('MIME-Version: 1.0\r\n')
          ..write('Content-Type: text/plain; charset=UTF-8\r\n')
          ..write('Content-Transfer-Encoding: base64\r\n')
          ..write('\r\n')
          ..write(bodyEncoded)
          ..write('.\r\n');

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
        AppLogger.debug('Falha não crítica ao encerrar sessão SMTP QUIT: $e', st);
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
/// Garante que correspondências, cartas do Hub e anexos permaneçam
/// salvos localmente no Drift SQLite, imunes à purga remota de 90 dias do servidor.
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
  }) async {
    final remoteMessages = await imapClient.fetchRemoteEmails(
      host: host,
      port: port,
      username: username,
      password: password,
    );

    int savedCount = 0;
    final now = DateTime.now();

    for (final msg in remoteMessages) {
      final entryId = 'email_${msg.id}';

      // Verifica se já existe retido localmente
      final existing = await (db.select(db.inboxEntries)
            ..where((t) => t.id.equals(entryId)))
          .getSingleOrNull();

      if (existing != null) {
        continue; // Já protegido na retenção permanente
      }

      final sourceType = msg.isHubCommunication
          ? (msg.hubType == 'form' ? 'hub_form' : 'hub_letter')
          : 'email';

      final metadata = {
        'permanentRetention': true,
        'retentionDate': now.toIso8601String(),
        'email': msg.toJson(),
      };

      final companion = InboxEntriesCompanion.insert(
        id: entryId,
        content: '${msg.subject}\n\n${msg.bodyText}',
        sourceType: drift.Value(sourceType),
        suggestedCategory: drift.Value(
          msg.isHubCommunication ? 'hub_comms' : 'email_jw',
        ),
        attachments: drift.Value(jsonEncode(msg.attachments)),
        capturedAt: msg.date,
        metadata: drift.Value(jsonEncode(metadata)),
        createdAt: now,
        updatedAt: now,
      );

      await db.into(db.inboxEntries).insert(companion);
      savedCount++;
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
        (t) => t.sourceType.equals('hub_letter') | t.sourceType.equals('hub_form'),
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
                final match = msg.subject.toLowerCase().contains(q) ||
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
          AppLogger.debug('Fallback para InboxEntry bruto em ${entry.id}: $e', st);
        }

        // Fallback construído a partir do InboxEntry bruto
        final isHub = entry.sourceType == 'hub_letter' ||
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

  /// Salva rascunho de e-mail teocrático
  Future<void> saveDraft(JwEmailMessage draft) async {
    final entryId = 'email_draft_${draft.id}';
    final now = DateTime.now();

    final metadata = {
      'permanentRetention': true,
      'isDraft': true,
      'email': draft.copyWith(isDraft: true).toJson(),
    };

    final companion = InboxEntriesCompanion.insert(
      id: entryId,
      content: '${draft.subject}\n\n${draft.bodyText}',
      sourceType: const drift.Value('email_draft'),
      suggestedCategory: const drift.Value('email_jw'),
      capturedAt: now,
      metadata: drift.Value(jsonEncode(metadata)),
      createdAt: now,
      updatedAt: now,
    );

    await db.into(db.inboxEntries).insertOnConflictUpdate(companion);
  }

  /// Envia e-mail real via servidor SMTP autenticado e persiste registro local retido.
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

    final now = DateTime.now();
    final sentMsg = message.copyWith(
      from: message.from.trim().isNotEmpty && message.from != 'local@dispositivo'
          ? message.from
          : username.trim(),
      date: now,
      isDraft: false,
      isRead: true,
      isPermanentRetained: true,
    );

    final targetId = draftId != null ? 'email_draft_$draftId' : 'email_${sentMsg.id}';
    final existingDraft = await (db.select(db.inboxEntries)
          ..where((t) => t.id.equals('email_draft_${sentMsg.id}')))
        .getSingleOrNull();
    final resolvedEntryId =
        draftId != null ? targetId : (existingDraft != null ? existingDraft.id : targetId);

    final metadata = {
      'permanentRetention': true,
      'isDraft': false,
      'sentAt': now.toIso8601String(),
      'smtpHost': host,
      'smtpPort': port,
      'email': sentMsg.toJson(),
    };

    final companion = InboxEntriesCompanion.insert(
      id: resolvedEntryId,
      content: '${sentMsg.subject}\n\n${sentMsg.bodyText}',
      sourceType: const drift.Value('email'),
      suggestedCategory: const drift.Value('email_jw'),
      attachments: drift.Value(jsonEncode(sentMsg.attachments)),
      capturedAt: now,
      metadata: drift.Value(jsonEncode(metadata)),
      createdAt: now,
      updatedAt: now,
    );

    await db.into(db.inboxEntries).insertOnConflictUpdate(companion);
    return sentMsg;
  }

  /// Exportação dinâmica de mensagens ou anotações (Markdown, Texto ou EML)
  Future<String> exportEmail(
    JwEmailMessage message, {
    required String format, // 'markdown', 'text', 'eml'
  }) async {
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
    final filename = '${sanitizedSubject.isEmpty ? "email_retido" : sanitizedSubject}.$extension';
    FileDownloader.download(filename, content);

    return content;
  }

  /// Exportação dinâmica de itens genéricos do Inbox (Notas, ditados, etc.)
  Future<String> exportInboxEntry(
    InboxEntry entry, {
    required String format, // 'markdown', 'text'
  }) async {
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

    final filename = 'inbox_nota_${entry.id.substring(0, 8)}.${format == "text" ? "txt" : "md"}';
    FileDownloader.download(filename, content);

    return content;
  }
}
