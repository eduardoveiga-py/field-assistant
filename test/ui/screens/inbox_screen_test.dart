import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ministerio_pessoal/core/biometric_auth_service.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/inbox/email_account_model.dart';
import 'package:ministerio_pessoal/inbox/jw_email_service.dart';
import 'package:ministerio_pessoal/ui/providers.dart';
import 'package:ministerio_pessoal/ui/screens/inbox_screen.dart';

class _AlwaysUnlockedBiometricService extends BiometricAuthService {
  @override
  bool get isSessionUnlocked => true;
}

class _TestJwEmailService extends JwEmailService {
  Function? onSyncEmails;

  _TestJwEmailService({required super.db, required super.biometricAuth});

  @override
  Future<int> syncEmails({
    String? host,
    int? port,
    String? username,
    String? password,
    String? accountEmail,
  }) async {
    if (onSyncEmails != null) {
      try {
        final res = await Function.apply(onSyncEmails!, [], {
          #host: host,
          #port: port,
          #username: username,
          #password: password,
          #accountEmail: accountEmail,
        });
        return res as int;
      } on NoSuchMethodError {
        final res = await Function.apply(onSyncEmails!, [], {
          #host: host,
          #port: port,
          #username: username,
          #password: password,
        });
        return res as int;
      }
    }
    return 0;
  }

  JwEmailMessage? lastSentMessage;
  String? lastSentHost;
  int? lastSentPort;
  String? lastSentUser;
  String? lastSentPass;

  @override
  Future<JwEmailMessage> sendEmail({
    required String host,
    required int port,
    required String username,
    required String password,
    required JwEmailMessage message,
    String securityMode = 'starttls',
    String? draftId,
  }) async {
    lastSentHost = host;
    lastSentPort = port;
    lastSentUser = username;
    lastSentPass = password;
    lastSentMessage = message;
    return message;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('R2: Display Real Email Sync Errors in InboxScreen', () {
    testWidgets(
      'TC-INBOX-SYNC-01: Exibe erro claro quando conta não possui senha configurada (nunca verde)',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        final repo = AppRepository(db);

        // Salva conta sem senha
        final account = EmailAccount.createPreset(
          providerType: EmailProviderType.google,
          name: 'Gmail Pessoal',
          email: 'irmao@gmail.com',
          username: 'irmao@gmail.com',
        );
        await EmailAccountsManager.saveAccount(db, account);

        final emailService = _TestJwEmailService(
          db: db,
          biometricAuth: _AlwaysUnlockedBiometricService(),
        );

        tester.view.physicalSize = const Size(800, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              repositoryProvider.overrideWithValue(repo),
              jwEmailServiceProvider.overrideWithValue(emailService),
              biometricAuthServiceProvider.overrideWithValue(
                _AlwaysUnlockedBiometricService(),
              ),
            ],
            child: const MaterialApp(home: InboxScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Clica no botão de sincronização no AppBar
        final syncBtn = find.byTooltip('Sincronizar E-mails / Hub');
        expect(syncBtn, findsOneWidget);
        await tester.tap(syncBtn);
        await tester.pumpAndSettle();

        // Verifica que o SnackBar de erro exibe 'senha não configurada'
        expect(find.byType(SnackBar), findsOneWidget);
        expect(
          find.textContaining('Falha na sincronização de e-mail:'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Gmail Pessoal: senha não configurada'),
          findsOneWidget,
        );

        // Confirma que NÃO exibe a mensagem de sucesso verde
        expect(
          find.textContaining('Sincronização global concluída'),
          findsNothing,
        );

        // Limpa o SnackBar e descarta o widget e o banco para evitar timers pendentes
        await tester.pump(const Duration(seconds: 7));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await db.close();
        await tester.pump(const Duration(milliseconds: 100));
      },
    );

    testWidgets(
      'TC-INBOX-SYNC-02: Exibe dica clara de 401/Senha de App quando Gmail falha autenticação',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        final repo = AppRepository(db);

        final account = EmailAccount.createPreset(
          providerType: EmailProviderType.google,
          name: 'Gmail Conta',
          email: 'usuario@gmail.com',
          username: 'usuario@gmail.com',
        );
        await EmailAccountsManager.saveAccount(
          db,
          account,
          password: 'wrong_password',
        );

        final emailService = _TestJwEmailService(
          db: db,
          biometricAuth: _AlwaysUnlockedBiometricService(),
        );
        emailService.onSyncEmails = ({host, password, port, username}) async {
          throw const JwEmailAuthException(
            '401 Unauthorized / Bad credentials',
          );
        };

        tester.view.physicalSize = const Size(800, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              repositoryProvider.overrideWithValue(repo),
              jwEmailServiceProvider.overrideWithValue(emailService),
              biometricAuthServiceProvider.overrideWithValue(
                _AlwaysUnlockedBiometricService(),
              ),
            ],
            child: const MaterialApp(home: InboxScreen()),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Sincronizar E-mails / Hub'));
        await tester.pumpAndSettle();

        expect(find.byType(SnackBar), findsOneWidget);
        expect(
          find.textContaining('Falha na sincronização de e-mail:'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Senha de App de 16 dígitos'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Sincronização global concluída'),
          findsNothing,
        );

        await tester.pump(const Duration(seconds: 7));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await db.close();
        await tester.pump(const Duration(milliseconds: 100));
      },
    );

    testWidgets(
      'TC-INBOX-SYNC-03: Exibe dica clara de 401/OAuth2 quando Hotmail/Outlook falha autenticação',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        final repo = AppRepository(db);

        final account = EmailAccount.createPreset(
          providerType: EmailProviderType.hotmail,
          name: 'Outlook Pessoal',
          email: 'irmao@outlook.com',
          username: 'irmao@outlook.com',
        );
        await EmailAccountsManager.saveAccount(
          db,
          account,
          password: 'invalid_pass',
        );

        final emailService = _TestJwEmailService(
          db: db,
          biometricAuth: _AlwaysUnlockedBiometricService(),
        );
        emailService.onSyncEmails = ({host, password, port, username}) async {
          throw const JwEmailAuthException('401 Authentication failure');
        };

        tester.view.physicalSize = const Size(800, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              repositoryProvider.overrideWithValue(repo),
              jwEmailServiceProvider.overrideWithValue(emailService),
              biometricAuthServiceProvider.overrideWithValue(
                _AlwaysUnlockedBiometricService(),
              ),
            ],
            child: const MaterialApp(home: InboxScreen()),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Sincronizar E-mails / Hub'));
        await tester.pumpAndSettle();

        expect(find.byType(SnackBar), findsOneWidget);
        expect(
          find.textContaining('Falha na sincronização de e-mail:'),
          findsOneWidget,
        );
        expect(find.textContaining('autenticação moderna'), findsOneWidget);

        await tester.pump(const Duration(seconds: 7));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await db.close();
        await tester.pump(const Duration(milliseconds: 100));
      },
    );

    testWidgets(
      'TC-INBOX-SYNC-04: Exibe SnackBar de aviso (laranja) em sincronização parcial',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        final repo = AppRepository(db);

        // Conta 1: com senha
        final acc1 = EmailAccount.createPreset(
          providerType: EmailProviderType.jwpub,
          name: 'Conta OK',
          email: 'ok@jwpub.org',
          username: 'ok@jwpub.org',
        );
        await EmailAccountsManager.saveAccount(
          db,
          acc1,
          password: 'valid_password',
        );

        // Conta 2: sem senha
        final acc2 = EmailAccount.createPreset(
          providerType: EmailProviderType.google,
          name: 'Conta Sem Senha',
          email: 'fail@gmail.com',
          username: 'fail@gmail.com',
        );
        await EmailAccountsManager.saveAccount(db, acc2);

        final emailService = _TestJwEmailService(
          db: db,
          biometricAuth: _AlwaysUnlockedBiometricService(),
        );
        emailService.onSyncEmails = ({host, password, port, username}) async {
          return 3; // 3 emails salvos na conta 1
        };

        tester.view.physicalSize = const Size(800, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              repositoryProvider.overrideWithValue(repo),
              jwEmailServiceProvider.overrideWithValue(emailService),
              biometricAuthServiceProvider.overrideWithValue(
                _AlwaysUnlockedBiometricService(),
              ),
            ],
            child: const MaterialApp(home: InboxScreen()),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Sincronizar E-mails / Hub'));
        await tester.pumpAndSettle();

        expect(find.byType(SnackBar), findsOneWidget);
        expect(
          find.textContaining(
            'Sincronização parcial: 3 nova(s) mensagem(ns) de 1 conta(s)',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining('Conta Sem Senha: senha não configurada'),
          findsOneWidget,
        );

        await tester.pump(const Duration(seconds: 7));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await db.close();
        await tester.pump(const Duration(milliseconds: 100));
      },
    );

    testWidgets(
      'TC-INBOX-SYNC-05: TimeoutException com mensagem contendo connection mapeia para Tempo limite de conexão esgotado',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        final repo = AppRepository(db);

        final account = EmailAccount.createPreset(
          providerType: EmailProviderType.jwpub,
          name: 'TimeoutAcc',
          email: 'timeout@jwpub.org',
          username: 'timeout@jwpub.org',
        );
        await EmailAccountsManager.saveAccount(
          db,
          account,
          password: 'test_password',
        );

        final emailService = _TestJwEmailService(
          db: db,
          biometricAuth: _AlwaysUnlockedBiometricService(),
        );
        emailService.onSyncEmails = ({host, password, port, username}) async {
          throw TimeoutException('Connection timed out after 10000ms');
        };

        tester.view.physicalSize = const Size(800, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              repositoryProvider.overrideWithValue(repo),
              jwEmailServiceProvider.overrideWithValue(emailService),
              biometricAuthServiceProvider.overrideWithValue(
                _AlwaysUnlockedBiometricService(),
              ),
            ],
            child: const MaterialApp(home: InboxScreen()),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Sincronizar E-mails / Hub'));
        await tester.pumpAndSettle();

        expect(find.byType(SnackBar), findsOneWidget);
        expect(
          find.textContaining('Falha na sincronização de e-mail:'),
          findsOneWidget,
        );
        expect(
          find.textContaining('TimeoutAcc: Tempo limite de conexão esgotado.'),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            'Falha de conexão. Servidor inacessível ou rede indisponível.',
          ),
          findsNothing,
        );

        await tester.pump(const Duration(seconds: 7));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await db.close();
        await tester.pump(const Duration(milliseconds: 100));
      },
    );
  });

  group('R3: Dedicated Folder Selector & Filtering in InboxScreen', () {
    testWidgets(
      'TC-INBOX-FOLDER-01: Barra dedicada de pastas e chips possuem chaves determinísticas e filtram mensagens',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        final repo = AppRepository(db);

        // Insere mensagens de teste cobrindo todas as pastas
        final now = DateTime.now();

        // 1. Mensagem recebida da Caixa de Entrada
        final inboxMsg = JwEmailMessage(
          id: 'msg-inbox',
          folderName: 'INBOX',
          subject: 'Boas Novas de Hoje',
          from: 'anunciador@jw.org',
          to: 'publicador@jw.org',
          date: now,
          bodyText: 'Texto da caixa de entrada',
          isDraft: false,
          isRead: false,
        );

        // 2. Mensagem enviada
        final sentMsg = JwEmailMessage(
          id: 'msg-sent',
          folderName: 'Sent Items',
          subject: 'Relatório Mensal de Campo',
          from: 'publicador@jw.org',
          to: 'secretario@jw.org',
          date: now.subtract(const Duration(hours: 1)),
          bodyText: 'Segue anexo meu relatório.',
          isDraft: false,
          isRead: true,
        );

        // 3. Rascunho
        final draftMsg = JwEmailMessage(
          id: 'msg-draft',
          folderName: 'Drafts',
          subject: 'Rascunho de Carta de Agradecimento',
          from: 'publicador@jw.org',
          to: 'estudante@gmail.com',
          date: now.subtract(const Duration(hours: 2)),
          bodyText: 'Prezado morador...',
          isDraft: true,
          isRead: true,
        );

        // 4. Spam
        final spamMsg = JwEmailMessage(
          id: 'msg-spam',
          folderName: 'Junk E-mail',
          subject: 'Promoção Não Solicitada',
          from: 'promo@marketing.com',
          to: 'publicador@jw.org',
          date: now.subtract(const Duration(hours: 3)),
          bodyText: 'Ganhe um brinde!',
          isDraft: false,
          isRead: true,
        );

        // 5. Lixeira
        final trashMsg = JwEmailMessage(
          id: 'msg-trash',
          folderName: 'Deleted Items',
          subject: 'Aviso Antigo Deletado',
          from: 'admin@sistema.com',
          to: 'publicador@jw.org',
          date: now.subtract(const Duration(days: 2)),
          bodyText: 'Mensagem descartada na lixeira.',
          isDraft: false,
          isRead: true,
        );

        for (final msg in [inboxMsg, sentMsg, draftMsg, spamMsg, trashMsg]) {
          await db
              .into(db.inboxEntries)
              .insert(
                InboxEntriesCompanion.insert(
                  id: 'email_${msg.id}',
                  sourceType: drift.Value(
                    msg.isDraft ? 'email_draft' : 'email',
                  ),
                  content: msg.bodyText,
                  capturedAt: msg.date,
                  createdAt: now,
                  updatedAt: now,
                  metadata: drift.Value(jsonEncode({'email': msg.toJson()})),
                ),
              );
        }

        tester.view.physicalSize = const Size(800, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              repositoryProvider.overrideWithValue(repo),
              biometricAuthServiceProvider.overrideWithValue(
                _AlwaysUnlockedBiometricService(),
              ),
            ],
            child: const MaterialApp(home: InboxScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Muda para a aba 'JW Mail'
        await tester.tap(find.text('JW Mail'));
        await tester.pumpAndSettle();

        // 1. Verifica existência da barra dedicada de pastas e chips com chaves
        expect(
          find.byKey(const Key('email_folder_selector_bar')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('folder_chip_todas_as_pastas')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('folder_chip_caixa_de_entrada')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('folder_chip_enviadas')), findsOneWidget);
        expect(find.byKey(const Key('folder_chip_rascunhos')), findsOneWidget);
        expect(find.byKey(const Key('folder_chip_spam')), findsOneWidget);
        expect(find.byKey(const Key('folder_chip_lixeira')), findsOneWidget);

        // 2. Filtra por 'Caixa de Entrada'
        await tester.ensureVisible(
          find.byKey(const Key('folder_chip_caixa_de_entrada')),
        );
        await tester.tap(find.byKey(const Key('folder_chip_caixa_de_entrada')));
        await tester.pumpAndSettle();

        expect(find.text('Boas Novas de Hoje'), findsOneWidget);
        expect(find.text('Relatório Mensal de Campo'), findsNothing);
        expect(find.text('Rascunho de Carta de Agradecimento'), findsNothing);
        expect(find.text('Promoção Não Solicitada'), findsNothing);
        expect(find.text('Aviso Antigo Deletado'), findsNothing);

        // 3. Filtra por 'Enviadas'
        await tester.ensureVisible(
          find.byKey(const Key('folder_chip_enviadas')),
        );
        await tester.tap(find.byKey(const Key('folder_chip_enviadas')));
        await tester.pumpAndSettle();

        expect(find.text('Relatório Mensal de Campo'), findsOneWidget);
        expect(find.text('Boas Novas de Hoje'), findsNothing);
        expect(find.text('Promoção Não Solicitada'), findsNothing);

        // 4. Filtra por 'Rascunhos'
        await tester.ensureVisible(
          find.byKey(const Key('folder_chip_rascunhos')),
        );
        await tester.tap(find.byKey(const Key('folder_chip_rascunhos')));
        await tester.pumpAndSettle();

        expect(find.text('Rascunho de Carta de Agradecimento'), findsOneWidget);
        expect(find.text('Boas Novas de Hoje'), findsNothing);

        // 5. Filtra por 'Spam'
        await tester.ensureVisible(find.byKey(const Key('folder_chip_spam')));
        await tester.tap(find.byKey(const Key('folder_chip_spam')));
        await tester.pumpAndSettle();

        expect(find.text('Promoção Não Solicitada'), findsOneWidget);
        expect(find.text('Boas Novas de Hoje'), findsNothing);

        // 6. Filtra por 'Lixeira'
        await tester.ensureVisible(
          find.byKey(const Key('folder_chip_lixeira')),
        );
        await tester.tap(find.byKey(const Key('folder_chip_lixeira')));
        await tester.pumpAndSettle();

        expect(find.text('Aviso Antigo Deletado'), findsOneWidget);
        expect(find.text('Boas Novas de Hoje'), findsNothing);

        // 7. Volta para 'Todas as pastas' e testa filtro de 'Não lidos'
        await tester.ensureVisible(
          find.byKey(const Key('folder_chip_todas_as_pastas')),
        );
        await tester.tap(find.byKey(const Key('folder_chip_todas_as_pastas')));
        await tester.pumpAndSettle();

        expect(find.text('Boas Novas de Hoje'), findsOneWidget);
        expect(find.text('Relatório Mensal de Campo'), findsOneWidget);

        // Ativa filtro Não Lidos
        final unreadChip = find.byKey(const Key('filter_unread_chip'));
        expect(unreadChip, findsOneWidget);
        await tester.ensureVisible(unreadChip);
        await tester.tap(unreadChip);
        await tester.pumpAndSettle();

        // Apenas 'Boas Novas de Hoje' está como isRead=false
        expect(find.text('Boas Novas de Hoje'), findsOneWidget);
        expect(find.text('Relatório Mensal de Campo'), findsNothing);
        expect(find.text('Aviso Antigo Deletado'), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await db.close();
        await tester.pump(const Duration(milliseconds: 100));
      },
    );
  });

  group('R6: Compose & Send Email Multi-Account Integration Tests', () {
    testWidgets(
      'TC-INBOX-COMPOSE-01: Modal exibe seletor de conta com contas configuradas e envia via SMTP da conta',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        final repo = AppRepository(db);

        final account = EmailAccount.createPreset(
          providerType: EmailProviderType.google,
          name: 'Gmail Trabalho',
          email: 'trabalho@gmail.com',
          username: 'trabalho@gmail.com',
        );
        await EmailAccountsManager.saveAccount(
          db,
          account,
          password: 'app_password_123',
        );

        final emailService = _TestJwEmailService(
          db: db,
          biometricAuth: _AlwaysUnlockedBiometricService(),
        );

        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              repositoryProvider.overrideWithValue(repo),
              jwEmailServiceProvider.overrideWithValue(emailService),
              biometricAuthServiceProvider.overrideWithValue(
                _AlwaysUnlockedBiometricService(),
              ),
            ],
            child: const MaterialApp(home: InboxScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Muda para a aba de E-mail
        final emailTab = find.text('JW Mail');
        await tester.tap(emailTab);
        await tester.pumpAndSettle();

        // 2. Toca no FAB de Compor / Novo E-mail
        final fab = find.widgetWithText(FloatingActionButton, 'Novo Rascunho');
        expect(fab, findsOneWidget);
        await tester.tap(fab);
        await tester.pumpAndSettle();

        // 3. Verifica que o seletor de conta de envio está presente e selecionou trabalho@gmail.com
        expect(
          find.byKey(const Key('compose_account_selector')),
          findsOneWidget,
        );
        expect(
          find.textContaining('Gmail Trabalho <trabalho@gmail.com>'),
          findsOneWidget,
        );

        // 4. Preenche destinatário, assunto e conteúdo
        final toField = find.widgetWithText(TextField, 'Para *');
        await tester.enterText(toField, 'destinatario@exemplo.com');

        final subjectField = find.widgetWithText(TextField, 'Assunto *');
        await tester.enterText(subjectField, 'Assunto do Teste');

        final contentField = find.widgetWithText(
          TextField,
          'Conteúdo da Mensagem *',
        );
        await tester.enterText(contentField, 'Olá, este é um e-mail de teste.');
        await tester.pumpAndSettle();

        // 5. Toca em Enviar E-mail
        final sendButton = find.widgetWithText(FilledButton, 'Enviar E-mail');
        await tester.tap(sendButton);
        await tester.pumpAndSettle();

        // 6. Verifica que o serviço SMTP foi invocado com a configuração da conta multi-contas
        expect(emailService.lastSentHost, equals('smtp.gmail.com'));
        expect(emailService.lastSentPort, equals(587));
        expect(emailService.lastSentUser, equals('trabalho@gmail.com'));
        expect(emailService.lastSentPass, equals('app_password_123'));
        expect(
          emailService.lastSentMessage?.to,
          equals('destinatario@exemplo.com'),
        );
        expect(
          emailService.lastSentMessage?.accountEmail,
          equals('trabalho@gmail.com'),
        );
        expect(emailService.lastSentMessage?.folderName, equals('Enviados'));

        // 7. Confirma exibição do SnackBar de sucesso
        expect(find.byType(SnackBar), findsOneWidget);
        expect(
          find.textContaining('E-mail enviado com sucesso via SMTP'),
          findsOneWidget,
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await db.close();
        await tester.pump(const Duration(milliseconds: 100));
      },
    );

    testWidgets(
      'TC-INBOX-COMPOSE-02: Salva rascunho vinculando accountEmail da conta selecionada',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        final repo = AppRepository(db);

        final account = EmailAccount.createPreset(
          providerType: EmailProviderType.hotmail,
          name: 'Hotmail Teste',
          email: 'irmao@hotmail.com',
          username: 'irmao@hotmail.com',
        );
        await EmailAccountsManager.saveAccount(
          db,
          account,
          password: 'pass_hotmail_123',
        );

        final emailService = _TestJwEmailService(
          db: db,
          biometricAuth: _AlwaysUnlockedBiometricService(),
        );

        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              repositoryProvider.overrideWithValue(repo),
              jwEmailServiceProvider.overrideWithValue(emailService),
              biometricAuthServiceProvider.overrideWithValue(
                _AlwaysUnlockedBiometricService(),
              ),
            ],
            child: const MaterialApp(home: InboxScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Muda para a aba de E-mail
        final emailTab = find.text('JW Mail');
        await tester.tap(emailTab);
        await tester.pumpAndSettle();

        // 2. Toca no FAB de Compor
        final fab = find.widgetWithText(FloatingActionButton, 'Novo Rascunho');
        await tester.tap(fab);
        await tester.pumpAndSettle();

        // 3. Preenche assunto e conteúdo
        final subjectField = find.widgetWithText(TextField, 'Assunto *');
        await tester.enterText(subjectField, 'Meu Rascunho Hotmail');

        final contentField = find.widgetWithText(
          TextField,
          'Conteúdo da Mensagem *',
        );
        await tester.enterText(contentField, 'Texto do rascunho');
        await tester.pumpAndSettle();

        // 4. Toca em Salvar Rascunho
        final draftButton = find.widgetWithText(
          OutlinedButton,
          'Salvar Rascunho',
        );
        await tester.tap(draftButton);
        await tester.pumpAndSettle();

        // 5. Verifica que o rascunho foi salvo no banco com accountEmail e folderName
        final entries = await db.select(db.inboxEntries).get();
        expect(
          entries.any((e) => e.content.contains('Meu Rascunho Hotmail')),
          isTrue,
        );
        final entry = entries.firstWhere(
          (e) => e.content.contains('Meu Rascunho Hotmail'),
        );
        final meta = jsonDecode(entry.metadata) as Map<String, dynamic>;
        final emailJson = meta['email'] as Map<String, dynamic>;
        expect(emailJson['accountEmail'], equals('irmao@hotmail.com'));
        expect(emailJson['folderName'], equals('Rascunhos'));
        expect(emailJson['isDraft'], isTrue);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await db.close();
        await tester.pump(const Duration(milliseconds: 100));
      },
    );
  });
}
