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
  Future<int> Function({
    String? host,
    int? port,
    String? username,
    String? password,
  })?
  onSyncEmails;

  _TestJwEmailService({required super.db, required super.biometricAuth});

  @override
  Future<int> syncEmails({
    String? host,
    int? port,
    String? username,
    String? password,
  }) async {
    if (onSyncEmails != null) {
      return onSyncEmails!(
        host: host,
        port: port,
        username: username,
        password: password,
      );
    }
    return 0;
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
}
