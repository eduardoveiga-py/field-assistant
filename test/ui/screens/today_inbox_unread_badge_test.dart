import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ministerio_pessoal/core/app_theme.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/inbox/inbox_manager.dart';
import 'package:ministerio_pessoal/inbox/jw_email_service.dart';
import 'package:ministerio_pessoal/core/biometric_auth_service.dart';
import 'package:ministerio_pessoal/ui/providers.dart';
import 'package:ministerio_pessoal/ui/screens/today_screen.dart';

Future<void> _insertEmail(
  AppDatabase db, {
  required String id,
  required bool isRead,
  bool isDraft = false,
  String? folderName = 'Caixa de Entrada',
  List<String> labels = const [],
}) async {
  final now = DateTime.now().toUtc();
  final msg = JwEmailMessage(
    id: id,
    subject: 'Assunto $id',
    from: 'remetente@jw.org',
    to: 'eu@jw.org',
    date: now,
    bodyText: 'Corpo do e-mail $id',
    folderName: folderName,
    isRead: isRead,
    isDraft: isDraft,
    labels: labels,
  );
  await db
      .into(db.inboxEntries)
      .insert(
        InboxEntriesCompanion.insert(
          id: 'email_$id',
          content: '${msg.subject}\n\n${msg.bodyText}',
          sourceType: const drift.Value('email'),
          suggestedCategory: const drift.Value('email'),
          capturedAt: now,
          metadata: drift.Value(jsonEncode({'email': msg.toJson()})),
          createdAt: now,
          updatedAt: now,
        ),
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Badge de e-mails não lidos na Tela Inicial', () {
    test('watchUnreadEmailsCount contabiliza apenas e-mails não lidos da caixa de entrada', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(() async => db.close());

      final emailService = JwEmailService(
        db: db,
        biometricAuth: BiometricAuthService(),
      );
      final inboxManager = InboxManager(db: db);

      // 2 não lidos válidos
      await _insertEmail(db, id: 'unread_1', isRead: false);
      await _insertEmail(
        db,
        id: 'unread_2',
        isRead: false,
        folderName: 'INBOX',
      );
      // Lido, rascunho, enviado, spam, lixeira e nota de texto rápida não devem contar
      await _insertEmail(db, id: 'read_1', isRead: true);
      await _insertEmail(
        db,
        id: 'draft_1',
        isRead: false,
        isDraft: true,
        folderName: 'Rascunhos',
      );
      await _insertEmail(
        db,
        id: 'sent_1',
        isRead: false,
        folderName: 'Enviadas',
        labels: const ['SENT'],
      );
      await _insertEmail(db, id: 'spam_1', isRead: false, folderName: 'Spam');
      await _insertEmail(
        db,
        id: 'trash_1',
        isRead: false,
        folderName: 'Lixeira',
      );
      await inboxManager.captureText(content: 'Nota avulsa do Inbox');

      final count = await emailService.watchUnreadEmailsCount().first;
      expect(count, equals(2));

      await emailService.setEmailsReadStatus(['unread_1'], isRead: true);
      final afterRead = await emailService.watchUnreadEmailsCount().first;
      expect(afterRead, equals(1));
    });

    testWidgets(
      'Ícone superior direito na TodayScreen exibe contagem de e-mails não lidos e atualiza ao ler',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());

        final emailService = JwEmailService(
          db: db,
          biometricAuth: BiometricAuthService(),
        );
        final inboxManager = InboxManager(db: db);

        await _insertEmail(db, id: 'u1', isRead: false);
        await _insertEmail(db, id: 'u2', isRead: false);
        await _insertEmail(db, id: 'r1', isRead: true);
        await inboxManager.captureText(content: 'Ideia pendente');

        tester.view.physicalSize = const Size(430, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [databaseProvider.overrideWithValue(db)],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [Locale('pt', 'BR')],
              home: const TodayScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final badgeFinder = find.byKey(
          const Key('btn_today_inbox_unread_badge'),
        );
        expect(badgeFinder, findsOneWidget);
        expect(
          find.descendant(of: badgeFinder, matching: find.text('2')),
          findsOneWidget,
        );

        await emailService.setEmailsReadStatus(['u1'], isRead: true);
        await tester.pumpAndSettle();
        expect(
          find.descendant(of: badgeFinder, matching: find.text('1')),
          findsOneWidget,
        );

        await emailService.setEmailsReadStatus(['u2'], isRead: true);
        await tester.pumpAndSettle();
        final badgeWidget = tester.widget<Badge>(
          find.descendant(of: badgeFinder, matching: find.byType(Badge)),
        );
        expect(badgeWidget.isLabelVisible, isFalse);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
        await db.close();
      },
    );
  });
}
