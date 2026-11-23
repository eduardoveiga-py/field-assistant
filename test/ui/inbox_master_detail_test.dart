import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:ministerio_pessoal/core/biometric_auth_service.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/inbox/email_account_model.dart';
import 'package:ministerio_pessoal/inbox/email_sync_coordinator.dart';
import 'package:ministerio_pessoal/inbox/jw_email_service.dart';
import 'package:ministerio_pessoal/ui/providers.dart';
import 'package:ministerio_pessoal/ui/screens/inbox_screen.dart';

class _AlwaysUnlockedBiometricService extends BiometricAuthService {
  @override
  bool get isSessionUnlocked => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('InboxScreen Outlook Master-Detail & HTML Reader Tests', () {
    late AppDatabase db;
    late AppRepository repo;
    late JwEmailService emailService;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = AppRepository(db);
      emailService = JwEmailService(
        db: db,
        biometricAuth: _AlwaysUnlockedBiometricService(),
      );

      // Cria uma conta de e-mail Hotmail
      final acc = EmailAccount.createPreset(
        providerType: EmailProviderType.hotmail,
        name: 'Hotmail',
        email: 'eduveiga@hotmail.com',
        username: 'eduveiga@hotmail.com',
      );
      await EmailAccountsManager.saveAccount(db, acc);

      // Insere um e-mail sincronizado no banco de dados com HTML rico
      final coordinator = EmailSyncCoordinator(db);
      await coordinator.persistSyncedMessages([
        JwEmailMessage(
          id: 'test_msg_001',
          subject: 'Suas lembranças desse dia',
          bodyText: 'Confira suas fotos no OneDrive.',
          bodyHtml: '<p>Olá, <b>Eduardo</b>!</p><p>Confira suas fotos no OneDrive.</p>',
          from: '"OneDrive" <photos@onedrive.com>',
          to: 'eduveiga@hotmail.com',
          accountEmail: 'eduveiga@hotmail.com',
          date: DateTime.now(),
          folderName: 'Caixa de Entrada',
          attachments: [
            {'name': 'relatorio.pdf', 'type': 'pdf', 'size': 2048},
          ],
        ),
      ], 'microsoft_graph');
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets(
      'renders Master-Detail Split View on iPad (width 1024px) with Outlook detail pane',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 768);
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

        // Alterna para a aba JW Mail
        await tester.tap(find.text('JW Mail'));
        await tester.pumpAndSettle();

        // Verifica que no layout largo (1024px) há VerticalDivider separando as colunas
        expect(find.byType(VerticalDivider), findsOneWidget);

        // Verifica que o painel de detalhes do Outlook renderiza o assunto e remetente limpos
        expect(find.text('Suas lembranças desse dia'), findsWidgets);
        expect(find.text('OneDrive'), findsWidgets);

        // Verifica os botões de ação do painel Outlook
        expect(find.text('Responder'), findsOneWidget);
        expect(find.text('Excluir'), findsOneWidget);
        expect(find.text('Exportar'), findsOneWidget);
        expect(find.text('Virar Tarefa'), findsOneWidget);
        expect(find.text('Virar Pesquisa'), findsOneWidget);

        // Verifica que o anexo PDF é exibido com ícone de PDF
        expect(find.textContaining('relatorio.pdf'), findsOneWidget);
        expect(find.byIcon(Icons.picture_as_pdf), findsOneWidget);

        // Verifica renderizador HTML rico
        expect(find.byType(HtmlWidget), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 50));
      },
    );

    testWidgets(
      'renders single-column on mobile (390px) and opens full-screen reader on tap',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
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

        // Alterna para a aba JW Mail
        await tester.tap(find.text('JW Mail'));
        await tester.pumpAndSettle();

        // No mobile (<700px), não há VerticalDivider na aba de e-mails
        expect(find.byType(VerticalDivider), findsNothing);

        // Toca no card de e-mail na lista
        await tester.tap(find.text('Suas lembranças desse dia'));
        await tester.pumpAndSettle();

        // Abre a tela de leitura completa (Scaffold com AppBar)
        expect(find.byType(AppBar), findsWidgets);
        expect(find.text('Responder'), findsOneWidget);
        expect(find.text('Excluir'), findsOneWidget);
        expect(find.text('Exportar'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 50));
      },
    );
  });
}
