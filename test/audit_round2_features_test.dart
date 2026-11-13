import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/core/biometric_auth_service.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/inbox/jw_email_service.dart';
import 'package:ministerio_pessoal/sync/supabase_sync_service.dart';
import 'package:ministerio_pessoal/territory/geolocation_helper.dart';
import 'package:ministerio_pessoal/territory/mbtiles/mbtiles_native.dart';
import 'package:ministerio_pessoal/territory/mbtiles/mbtiles_service.dart';
import 'package:ministerio_pessoal/ui/providers.dart';
import 'package:ministerio_pessoal/ui/screens/auth_splash_screen.dart';
import 'package:ministerio_pessoal/ui/screens/contacts_map_screen.dart';
import 'package:ministerio_pessoal/ui/screens/download_maps_screen.dart';
import 'package:ministerio_pessoal/ui/screens/inbox_screen.dart';
import 'package:ministerio_pessoal/ui/screens/settings_screen.dart';
import 'package:ministerio_pessoal/ui/widgets/map_location_picker_dialog.dart';

class _CapturedSmtpSession {
  final List<String> commands = [];
  String? receivedMailFrom;
  final List<String> receivedRcptTo = [];
  String? receivedDataPayload;
}

Future<({ServerSocket server, Future<_CapturedSmtpSession> sessionFuture})>
    _startLoopbackSmtpServer({
  bool advertiseStartTls = false,
  String authCapabilities = 'AUTH PLAIN LOGIN',
  int authResultCode = 235,
}) async {
  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final completer = Completer<_CapturedSmtpSession>();

  server.listen((socket) {
    final session = _CapturedSmtpSession();
    final dataBuffer = StringBuffer();
    bool inDataMode = false;
    int authStep = 0;

    socket.write('220 localhost ESMTP TestRelay\r\n');
    final lineBuffer = StringBuffer();

    socket.listen(
      (bytes) {
        lineBuffer.write(utf8.decode(bytes));
        while (true) {
          final content = lineBuffer.toString();
          final crlf = content.indexOf('\r\n');
          if (crlf == -1) break;
          final line = content.substring(0, crlf);
          lineBuffer.clear();
          lineBuffer.write(content.substring(crlf + 2));

          if (inDataMode) {
            if (line == '.') {
              inDataMode = false;
              session.receivedDataPayload = dataBuffer.toString();
              socket.write('250 2.0.0 Ok: queued\r\n');
            } else {
              dataBuffer.writeln(line);
            }
            continue;
          }

          session.commands.add(line);
          final upper = line.toUpperCase();

          if (authStep == 1) {
            authStep = 2;
            socket.write('334 UGFzc3dvcmQ6\r\n'); // Password:
            continue;
          }
          if (authStep == 2) {
            authStep = 0;
            if (authResultCode == 235) {
              socket.write('235 2.7.0 Authentication successful\r\n');
            } else {
              socket.write('535 5.7.8 Authentication credentials invalid\r\n');
            }
            continue;
          }

          if (upper.startsWith('EHLO')) {
            socket.write('250-localhost Hello\r\n');
            if (advertiseStartTls) {
              socket.write('250-STARTTLS\r\n');
            }
            socket.write('250 $authCapabilities\r\n');
          } else if (upper.startsWith('AUTH PLAIN')) {
            if (authResultCode == 235) {
              socket.write('235 2.7.0 Authentication successful\r\n');
            } else {
              socket.write('535 5.7.8 Authentication credentials invalid\r\n');
            }
          } else if (upper == 'AUTH LOGIN') {
            authStep = 1;
            socket.write('334 VXNlcm5hbWU6\r\n'); // Username:
          } else if (upper.startsWith('MAIL FROM:')) {
            session.receivedMailFrom = line.substring(10).trim();
            socket.write('250 2.1.0 Ok\r\n');
          } else if (upper.startsWith('RCPT TO:')) {
            session.receivedRcptTo.add(line.substring(8).trim());
            socket.write('250 2.1.5 Ok\r\n');
          } else if (upper == 'DATA') {
            inDataMode = true;
            socket.write('354 End data with <CR><LF>.<CR><LF>\r\n');
          } else if (upper == 'QUIT') {
            socket.write('221 2.0.0 Bye\r\n');
            socket.close();
          } else {
            socket.write('500 Unrecognized command\r\n');
          }
        }
      },
      onDone: () {
        if (!completer.isCompleted) {
          completer.complete(session);
        }
      },
    );
  });

  return (server: server, sessionFuture: completer.future);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    GeolocationHelper.locationOverride = null;
  });

  tearDown(() {
    GeolocationHelper.locationOverride = null;
  });

  group('GeolocationHelper & ContactsMapScreen GPS UX', () {
    test('getCurrentLocationWithStatus propagates status and coordinates', () async {
      GeolocationHelper.locationOverride = () async => const GeolocationResult(
            status: GeolocationStatus.permissionDenied,
          );
      final denied = await GeolocationHelper.getCurrentLocationWithStatus();
      expect(denied.isSuccess, isFalse);
      expect(denied.coordinates, isNull);
      expect(denied.userMessage, contains('Permissão'));
      expect(await GeolocationHelper.getCurrentLocation(), isNull);

      GeolocationHelper.locationOverride = () async => const GeolocationResult(
            status: GeolocationStatus.success,
            coordinates: (latitude: -3.11, longitude: -67.95),
          );
      final ok = await GeolocationHelper.getCurrentLocationWithStatus();
      expect(ok.isSuccess, isTrue);
      expect(ok.coordinates!.latitude, closeTo(-3.11, 0.0001));
      expect(ok.coordinates!.longitude, closeTo(-67.95, 0.0001));
    });

    testWidgets(
      'ContactsMapScreen GPS denial preserves the current map view',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 768);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final db = AppDatabase.forTesting(NativeDatabase.memory());
        final repo = AppRepository(db);
        addTearDown(db.close);

        GeolocationHelper.locationOverride = () async => const GeolocationResult(
              status: GeolocationStatus.permissionDenied,
            );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              repositoryProvider.overrideWithValue(repo),
            ],
            child: const MaterialApp(home: ContactsMapScreen()),
          ),
        );
        await tester.pumpAndSettle();

        final gpsFab = find.byTooltip('Minha Localização GPS');
        expect(gpsFab, findsOneWidget);
        await tester.tap(gpsFab);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          find.textContaining('Permissão de localização negada'),
          findsOneWidget,
        );
        expect(
          find.textContaining('O mapa permaneceu na posição anterior'),
          findsOneWidget,
        );

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      },
    );

    testWidgets(
      'ContactsMapScreen GPS button uses real coordinates without error SnackBar on success',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 768);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final db = AppDatabase.forTesting(NativeDatabase.memory());
        final repo = AppRepository(db);
        addTearDown(db.close);

        GeolocationHelper.locationOverride = () async => const GeolocationResult(
              status: GeolocationStatus.success,
              coordinates: (latitude: -3.1200, longitude: -67.9500),
            );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              repositoryProvider.overrideWithValue(repo),
            ],
            child: const MaterialApp(home: ContactsMapScreen()),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Minha Localização GPS'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(SnackBar), findsNothing);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      },
    );
  });

  group('JwSmtpClient & JwEmailService.sendEmail', () {
    test('Sends real email via loopback SMTP AUTH PLAIN and converts draft to sent', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final bio = BiometricAuthService();
      final relay = await _startLoopbackSmtpServer();
      addTearDown(relay.server.close);

      const smtp = JwSmtpClient(allowPlaintextForTesting: true);
      final emailService = JwEmailService(
        db: db,
        biometricAuth: bio,
        smtpClient: smtp,
      );

      final draft = JwEmailMessage(
        id: 'draft-100',
        subject: 'Relatório Mensal — João',
        from: 'publicador@jw.org',
        to: 'Secretário <secretario@jw.org>, corpo@jw.org',
        date: DateTime(2026, 11, 10, 14, 0),
        bodyText: 'Segue relatório de campo com acentuação UTF-8.',
        isDraft: true,
        tags: const ['relatorio'],
      );
      await emailService.saveDraft(draft);

      final sent = await emailService.sendEmail(
        host: '127.0.0.1',
        port: relay.server.port,
        username: 'publicador@jw.org',
        password: 'app-secret-password',
        message: draft,
        securityMode: 'starttls',
        draftId: draft.id,
      );

      final captured = await relay.sessionFuture;
      expect(sent.isDraft, isFalse);
      expect(captured.receivedMailFrom, equals('<publicador@jw.org>'));
      expect(
        captured.receivedRcptTo,
        equals(['<secretario@jw.org>', '<corpo@jw.org>']),
      );
      expect(
        captured.commands.any((c) => c.startsWith('AUTH PLAIN ')),
        isTrue,
      );
      expect(captured.receivedDataPayload, contains('Subject: =?UTF-8?B?'));
      expect(captured.receivedDataPayload, contains('Content-Transfer-Encoding: base64'));

      // Draft row converted to retained sent email
      final row = await (db.select(db.inboxEntries)
            ..where((t) => t.id.equals('email_draft_draft-100')))
          .getSingle();
      expect(row.sourceType, equals('email'));
      final meta = jsonDecode(row.metadata) as Map<String, dynamic>;
      expect(meta['isDraft'], isFalse);
    });

    test('Falls back to AUTH LOGIN when server advertises only LOGIN', () async {
      final relay = await _startLoopbackSmtpServer(
        authCapabilities: 'AUTH LOGIN',
      );
      addTearDown(relay.server.close);

      const smtp = JwSmtpClient(allowPlaintextForTesting: true);
      await smtp.verifyConnection(
        host: '127.0.0.1',
        port: relay.server.port,
        username: 'elder@jw.org',
        password: 'pw',
      );

      final captured = await relay.sessionFuture;
      expect(captured.commands, contains('AUTH LOGIN'));
      expect(
        captured.commands,
        contains(base64.encode(utf8.encode('elder@jw.org'))),
      );
      expect(captured.commands, contains(base64.encode(utf8.encode('pw'))));
    });

    test('Throws JwEmailAuthException on 535 and preserves draft intact', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final relay = await _startLoopbackSmtpServer(authResultCode: 535);
      addTearDown(relay.server.close);

      final emailService = JwEmailService(
        db: db,
        biometricAuth: BiometricAuthService(),
        smtpClient: const JwSmtpClient(allowPlaintextForTesting: true),
      );

      final draft = JwEmailMessage(
        id: 'draft-535',
        subject: 'Teste Falha',
        from: 'user@jw.org',
        to: 'dest@jw.org',
        date: DateTime(2026, 11, 10),
        bodyText: 'Corpo',
        isDraft: true,
      );
      await emailService.saveDraft(draft);

      await expectLater(
        () => emailService.sendEmail(
          host: '127.0.0.1',
          port: relay.server.port,
          username: 'user@jw.org',
          password: 'wrong',
          message: draft,
          draftId: draft.id,
        ),
        throwsA(isA<JwEmailAuthException>()),
      );

      final row = await (db.select(db.inboxEntries)
            ..where((t) => t.id.equals('email_draft_draft-535')))
          .getSingle();
      expect(row.sourceType, equals('email_draft'));
    });

    test('Production JwSmtpClient refuses server without STARTTLS on port 587', () async {
      final relay = await _startLoopbackSmtpServer(advertiseStartTls: false);
      addTearDown(relay.server.close);

      const smtp = JwSmtpClient(); // allowPlaintextForTesting = false
      await expectLater(
        () => smtp.verifyConnection(
          host: '127.0.0.1',
          port: relay.server.port,
          username: 'user@jw.org',
          password: 'secret',
        ),
        throwsA(isA<JwEmailConnectionException>()),
      );
    });

    test('JwSmtpClient and JwImapClient reject out-of-range ports cleanly', () async {
      const smtp = JwSmtpClient();
      const imap = JwImapClient();
      await expectLater(
        () => smtp.verifyConnection(
          host: '127.0.0.1',
          port: 70000,
          username: 'user@jw.org',
          password: 'secret',
        ),
        throwsA(isA<JwEmailConnectionException>()),
      );
      await expectLater(
        () => imap.fetchRemoteEmails(
          host: '127.0.0.1',
          port: 0,
          username: 'user@jw.org',
          password: 'secret',
        ),
        throwsA(isA<JwEmailConnectionException>()),
      );
    });

    test('JwSmtpClient performs real TLS handshake for STARTTLS (587) and implicit SSL (465)', () async {
      String? opensslBin;
      for (final candidate in [
        'openssl',
        r'C:\Program Files\Git\usr\bin\openssl.exe',
      ]) {
        try {
          final res = Process.runSync(candidate, ['version']);
          if (res.exitCode == 0) {
            opensslBin = candidate;
            break;
          }
        } catch (_) {}
      }
      if (opensslBin == null) {
        return; // openssl binary absent on host
      }

      final certDir = Directory.systemTemp.createTempSync('smtp_tls_cert_');
      addTearDown(() {
        if (certDir.existsSync()) {
          certDir.deleteSync(recursive: true);
        }
      });

      final certPath = '${certDir.path}/cert.pem';
      final keyPath = '${certDir.path}/key.pem';
      final gen = Process.runSync(opensslBin, [
        'req',
        '-x509',
        '-newkey',
        'rsa:2048',
        '-keyout',
        keyPath,
        '-out',
        certPath,
        '-days',
        '1',
        '-nodes',
        '-subj',
        '/CN=127.0.0.1',
      ]);
      expect(gen.exitCode, equals(0), reason: 'openssl failed: ${gen.stderr}');

      final serverCtx = SecurityContext()
        ..useCertificateChain(certPath)
        ..usePrivateKey(keyPath);

      Future<void> handleTlsSmtpSession(
        Stream<List<int>> rawStream,
        void Function(String) writeFn,
        Future<void> Function() flushFn,
        Future<void> Function() closeFn,
        _CapturedSmtpSession session,
      ) async {
        bool inData = false;
        final dataBuf = StringBuffer();
        await for (final line
            in utf8.decoder.bind(rawStream).transform(const LineSplitter())) {
          if (inData) {
            if (line == '.') {
              inData = false;
              session.receivedDataPayload = dataBuf.toString();
              writeFn('250 2.0.0 Ok\r\n');
            } else {
              dataBuf.writeln(line);
            }
            continue;
          }
          session.commands.add(line);
          final upper = line.toUpperCase();
          if (upper.startsWith('EHLO')) {
            writeFn('250-localhost TLS\r\n250 AUTH PLAIN\r\n');
          } else if (upper.startsWith('AUTH PLAIN')) {
            writeFn('235 2.7.0 OK\r\n');
          } else if (upper.startsWith('MAIL FROM:')) {
            session.receivedMailFrom = line.substring(10).trim();
            writeFn('250 OK\r\n');
          } else if (upper.startsWith('RCPT TO:')) {
            session.receivedRcptTo.add(line.substring(8).trim());
            writeFn('250 OK\r\n');
          } else if (upper == 'DATA') {
            inData = true;
            writeFn('354 Go ahead\r\n');
          } else if (upper == 'QUIT') {
            writeFn('221 Bye\r\n');
            await flushFn();
            await closeFn();
            break;
          }
        }
      }

      // 1. Implicit SSL/TLS (465 mode)
      final sslServer = await SecureServerSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
        serverCtx,
      );
      addTearDown(sslServer.close);
      final sslSession = _CapturedSmtpSession();
      final sslDone = Completer<void>();
      sslServer.listen((sock) async {
        sock.write('220 localhost ESMTP SSL\r\n');
        await handleTlsSmtpSession(
          sock,
          sock.write,
          sock.flush,
          sock.close,
          sslSession,
        );
        if (!sslDone.isCompleted) sslDone.complete();
      });

      final smtpTls = JwSmtpClient(
        onBadCertificateForTesting: (_) => true,
      );
      await smtpTls.sendMail(
        host: '127.0.0.1',
        port: sslServer.port,
        username: 'elder@jw.org',
        password: 'pw',
        securityMode: 'ssl',
        message: JwEmailMessage(
          id: 'ssl-1',
          subject: 'Teste SSL 465',
          from: 'elder@jw.org',
          to: 'dest@jw.org',
          date: DateTime(2026, 11, 10),
          bodyText: 'Corpo cifrado SSL',
        ),
      );
      await sslDone.future;
      expect(sslSession.receivedMailFrom, equals('<elder@jw.org>'));
      expect(sslSession.receivedRcptTo, equals(['<dest@jw.org>']));

      // 2. Explicit STARTTLS upgrade (587 mode)
      final startTlsServer = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(startTlsServer.close);
      final startTlsSession = _CapturedSmtpSession();
      final startTlsDone = Completer<void>();
      startTlsServer.listen((sock) {
        sock.write('220 localhost ESMTP\r\n');
        final lineBuf = StringBuffer();
        late StreamSubscription<List<int>> sub;
        sub = sock.listen((bytes) async {
          lineBuf.write(utf8.decode(bytes));
          while (true) {
            final s = lineBuf.toString();
            final idx = s.indexOf('\r\n');
            if (idx == -1) break;
            final line = s.substring(0, idx);
            lineBuf.clear();
            lineBuf.write(s.substring(idx + 2));
            startTlsSession.commands.add(line);
            final upper = line.toUpperCase();
            if (upper.startsWith('EHLO')) {
              sock.write('250-localhost\r\n250 STARTTLS\r\n');
            } else if (upper == 'STARTTLS') {
              sock.write('220 Ready to start TLS\r\n');
              await sock.flush();
              sub.pause();
              final secured = await SecureSocket.secureServer(sock, serverCtx);
              await handleTlsSmtpSession(
                secured,
                secured.write,
                secured.flush,
                secured.close,
                startTlsSession,
              );
              if (!startTlsDone.isCompleted) startTlsDone.complete();
              break;
            }
          }
        });
      });

      await smtpTls.sendMail(
        host: '127.0.0.1',
        port: startTlsServer.port,
        username: 'elder@jw.org',
        password: 'pw',
        securityMode: 'starttls',
        message: JwEmailMessage(
          id: 'starttls-1',
          subject: 'Teste STARTTLS 587',
          from: 'elder@jw.org',
          to: 'dest2@jw.org',
          date: DateTime(2026, 11, 10),
          bodyText: 'Corpo cifrado STARTTLS',
        ),
      );
      await startTlsDone.future;
      expect(startTlsSession.commands, contains('STARTTLS'));
      expect(startTlsSession.receivedMailFrom, equals('<elder@jw.org>'));
      expect(startTlsSession.receivedRcptTo, equals(['<dest2@jw.org>']));
    });
  });

  group('UI Interactive Flows (DownloadMaps, Inbox SMTP, Settings, Auth, Picker)', () {
    testWidgets('DownloadMapsScreen configures base URL and per-region custom URL', (tester) async {
      final tempDir = Directory.systemTemp.createTempSync('dl_maps_ui_');
      addTearDown(() {
        if (tempDir.existsSync()) {
          try {
            tempDir.deleteSync(recursive: true);
          } catch (_) {}
        }
      });

      final backend = MBTilesNative(customDir: tempDir);
      final svc = MBTilesService.custom(backend: backend);
      await tester.runAsync(() => svc.init());
      MBTilesService.setMockInstance(svc);
      addTearDown(() {
        svc.dispose();
        backend.dispose();
        MBTilesService.setMockInstance(MBTilesService.custom());
      });

      await tester.pumpWidget(
        const MaterialApp(home: DownloadMapsScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Importar .mbtiles local'), findsOneWidget);
      await tester.tap(find.text('Configurar URL Catálogo'));
      await tester.pumpAndSettle();

      expect(find.text('URL Base do Catálogo .mbtiles'), findsOneWidget);
      await tester.enterText(
        find.byType(TextField).last,
        'https://mirror.jw.example/mbtiles',
      );
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(svc.customBaseUrl, equals('https://mirror.jw.example/mbtiles'));
      expect(find.text('URL Base Personalizada'), findsOneWidget);

      // Open per-region popup menu and configure region-specific custom URL
      await tester.tap(find.byTooltip('Opções do pacote').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('URL personalizada'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField).last,
        'https://custom.cdn.example/solimoes_v2.mbtiles',
      );
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(
        svc.getRegionCustomUrl('br_am_solimoes'),
        equals('https://custom.cdn.example/solimoes_v2.mbtiles'),
      );
    });

    testWidgets('InboxScreen compose sheet validates missing credentials and sends via SMTP when configured', (tester) async {
      tester.view.physicalSize = const Size(1024, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final bio = BiometricAuthService();
      await tester.runAsync(() => bio.setPin('1234')); // Unlocks session for test

      final relay = await tester.runAsync(() => _startLoopbackSmtpServer());
      addTearDown(relay!.server.close);

      final emailSvc = JwEmailService(
        db: db,
        biometricAuth: bio,
        smtpClient: const JwSmtpClient(allowPlaintextForTesting: true),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            biometricAuthServiceProvider.overrideWithValue(bio),
            jwEmailServiceProvider.overrideWithValue(emailSvc),
          ],
          child: const MaterialApp(home: InboxScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to JW Mail tab
      await tester.tap(find.text('JW Mail'));
      await tester.pumpAndSettle();

      // Open compose/draft sheet
      await tester.tap(find.text('Novo Rascunho'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Para (ex: corpo.anciaos@jw.org)'),
        'secretario@jw.org',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Assunto *'),
        'Relatório UI SMTP',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Conteúdo da Mensagem *'),
        'Enviado direto da UI do InboxScreen.',
      );

      final sendBtn = find.text('Enviar Agora (SMTP)');
      await tester.ensureVisible(sendBtn);
      await tester.pumpAndSettle();

      // Without configured credentials -> clear inline error + shortcut button
      await tester.tap(sendBtn);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Credenciais IMAP/SMTP não configuradas'),
        findsOneWidget,
      );
      expect(find.text('Configurar E-mail/SMTP'), findsOneWidget);

      // Configure credentials in DB + SecureStorage and retry send
      await tester.runAsync(() async {
        await db.into(db.appKvStore).insertOnConflictUpdate(
          AppKvStoreCompanion.insert(key: 'jw_imap_email', value: 'publicador@jw.org'),
        );
        await const FlutterSecureStorage().write(key: 'jw_imap_password', value: 'pw123');
        await db.into(db.appKvStore).insertOnConflictUpdate(
          AppKvStoreCompanion.insert(key: 'jw_smtp_host', value: '127.0.0.1'),
        );
        await db.into(db.appKvStore).insertOnConflictUpdate(
          AppKvStoreCompanion.insert(
            key: 'jw_smtp_port',
            value: relay.server.port.toString(),
          ),
        );
      });

      Object? capturedSession;
      var sessionDone = false;
      relay.sessionFuture.then((s) {
        capturedSession = s;
        sessionDone = true;
      });

      await tester.ensureVisible(sendBtn);
      await tester.pumpAndSettle();
      await tester.tap(sendBtn);

      for (int i = 0; i < 120 && !sessionDone; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
        await tester.pump(const Duration(milliseconds: 25));
      }

      expect(sessionDone, isTrue, reason: 'SMTP session did not complete in time');
      final captured = capturedSession! as _CapturedSmtpSession;
      await tester.pumpAndSettle();
      expect(captured.receivedMailFrom, equals('<publicador@jw.org>'));
      expect(captured.receivedRcptTo, equals(['<secretario@jw.org>']));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('SettingsScreen exposes SMTP fields and validates runtime Supabase dialog', (tester) async {
      tester.view.physicalSize = const Size(1024, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Servidor SMTP (Saída)'), findsOneWidget);
      expect(find.text('STARTTLS (587)'), findsOneWidget);
      expect(find.text('SSL/TLS (465)'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Configurar Supabase (URL/Chave)'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Configurar Supabase (URL/Chave)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Configurar Supabase (URL/Chave)'));
      await tester.pumpAndSettle();

      expect(find.text('Configuração Runtime do Supabase'), findsOneWidget);
      await tester.tap(find.text('Salvar e Conectar'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Informe a URL do projeto Supabase'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('SupabaseAuthScreen displays friendly message when Supabase is uninitialized', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: SupabaseAuthScreen(onAuthenticated: () {})),
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'E-mail *'),
        'user@jw.org',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Senha *'),
        '123456',
      );
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Servidor de nuvem ainda não configurado'),
        findsOneWidget,
      );
    });

    testWidgets('MapLocationPickerDialog handles GPS denial cleanly with and without initial coords', (tester) async {
      GeolocationHelper.locationOverride = () async => const GeolocationResult(
            status: GeolocationStatus.permissionDenied,
          );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MapLocationPickerDialog(
              initialLat: -3.15,
              initialLng: -67.90,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Minha Posição GPS'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Mantendo o ponto atual'), findsOneWidget);
      expect(find.textContaining('-3.150000, -67.900000'), findsOneWidget);
    });
  });

  group('Supabase Runtime Config & Web Tile CSP', () {
    test('Runtime Supabase credentials validate, persist and clear cleanly', () async {
      expect(
        SupabaseSyncService.validateSupabaseCredentials('', 'short'),
        isNotNull,
      );
      expect(
        SupabaseSyncService.validateSupabaseCredentials(
          'https://your-supabase-url.supabase.co',
          'your-anon-key-placeholder-123456',
        ),
        isNotNull,
      );
      expect(
        SupabaseSyncService.validateSupabaseCredentials(
          'https://meuprojeto.supabase.co',
          'sb_publishable_abcdefghijklmnopqrstuvwxyz1234',
        ),
        isNull,
      );

      await SupabaseSyncService.configureAndInitialize(
        url: 'https://meuprojeto.supabase.co',
        anonKey: 'sb_publishable_abcdefghijklmnopqrstuvwxyz1234',
        initializeClient: false,
      );
      expect(await SupabaseSyncService.hasRuntimeConfig(), isTrue);
      expect(
        await SupabaseSyncService.getRuntimeUrl(),
        equals('https://meuprojeto.supabase.co'),
      );

      await SupabaseSyncService.clearRuntimeConfig(
        disposeClientIfNoCompileTime: false,
      );
      expect(await SupabaseSyncService.hasRuntimeConfig(), isFalse);
      expect(await SupabaseSyncService.getRuntimeUrl(), isNull);
    });

    test('web/index.html CSP allows all 4 map tile providers', () {
      final html = File('web/index.html').readAsStringSync();
      for (final domain in const [
        'https://tile.openstreetmap.org',
        'https://*.openstreetmap.fr',
        'https://server.arcgisonline.com',
        'https://tile.opentopomap.org',
        'https://*.basemaps.cartocdn.com',
      ]) {
        expect(html, contains(domain));
      }
    });
  });
}
