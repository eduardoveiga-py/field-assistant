import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/core/biometric_auth_service.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/inbox/jw_email_service.dart';
import 'package:ministerio_pessoal/sync/crypto/recovery_crypto.dart';
import 'package:ministerio_pessoal/sync/crypto/recovery_key_store.dart';
import 'package:ministerio_pessoal/territory/mbtiles/mbtiles_service.dart';
import 'package:ministerio_pessoal/territory/mbtiles/mbtiles_web.dart';
import 'package:ministerio_pessoal/territory/tile_cache/tile_cache_service.dart';
import 'package:ministerio_pessoal/ui/providers.dart';
import 'package:ministerio_pessoal/ui/screens/contacts_map_screen.dart';
import 'package:ministerio_pessoal/ui/screens/settings_screen.dart';
import 'package:ministerio_pessoal/ui/widgets/e2ee_setup_dialog.dart';

class _EmptyTiles implements TileCacheBackend {
  @override
  Future<Uint8List?> getTile(int z, int x, int y, [MapLayerStyle? style]) async => null;
  @override
  Future<void> saveTile(int z, int x, int y, Uint8List bytes, [MapLayerStyle? style]) async {}
  @override
  Future<bool> isTileCached(int z, int x, int y, [MapLayerStyle? style]) async => false;
  @override
  Future<int> getCachedTileCount([MapLayerStyle? style]) async => 0;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    RecoveryKeyStore.resetForTesting();
  });

  group('Map Rotation & Heading Adjustment Tests', () {
    testWidgets('Mapa inicializa com rotação para o norte (0°) e permite girar e resetar suavemente', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final mock = MBTilesService.custom(backend: MBTilesWeb());
      MBTilesService.setMockInstance(mock);
      TileCacheService.instance.backend = _EmptyTiles();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
          ],
          child: const MaterialApp(
            home: ContactsMapScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verifica botão da bússola com tooltip inicial de 0°
      final compassFinder = find.byTooltip('Rotação do mapa (0°). Toque para voltar suavemente ao norte ou arraste para girar.');
      expect(compassFinder, findsOneWidget);

      // Botões de ajuste rápido de rotação
      final rotateRightFinder = find.byTooltip('Girar 45° à direita');
      final rotateLeftFinder = find.byTooltip('Girar 45° à esquerda');
      expect(rotateRightFinder, findsOneWidget);
      expect(rotateLeftFinder, findsOneWidget);

      // Gira 45° à direita
      await tester.tap(rotateRightFinder);
      await tester.pumpAndSettle();

      // Tooltip agora deve indicar 45°
      final compass45Finder = find.byTooltip('Rotação do mapa (45°). Toque para voltar suavemente ao norte ou arraste para girar.');
      expect(compass45Finder, findsOneWidget);

      // Confirma que a seta gira para a direção da rotação (+45° = pi/4)
      final transformFinder = find.descendant(
        of: compass45Finder,
        matching: find.byType(Transform),
      );
      expect(transformFinder, findsOneWidget);
      final transformWidget = tester.widget<Transform>(transformFinder);
      expect(transformWidget.transform.storage[0], closeTo(0.707, 0.02));
      expect(transformWidget.transform.storage[1], closeTo(0.707, 0.02));

      // Toca na bússola para voltar suavemente ao norte (0°)
      await tester.tap(compass45Finder);
      // Avança a animação de retorno suave
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      // Deve ter retornado a 0°
      expect(find.byTooltip('Rotação do mapa (0°). Toque para voltar suavemente ao norte ou arraste para girar.'), findsOneWidget);
      final transform0Finder = find.descendant(
        of: compassFinder,
        matching: find.byType(Transform),
      );
      final transform0Widget = tester.widget<Transform>(transform0Finder);
      expect(transform0Widget.transform.storage[0], closeTo(1.0, 0.01));
      expect(transform0Widget.transform.storage[1], closeTo(0.0, 0.01));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  });

  group('E2EE 24-Word Key Always Visible in Settings Tests', () {
    testWidgets('Card de configuração E2EE de 24 palavras está sempre visível mesmo sem usuário logado', (tester) async {
      tester.view.physicalSize = const Size(1024, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await db.into(db.appKvStore).insert(
        AppKvStoreCompanion.insert(
          key: 'last_silent_backup_timestamp',
          value: DateTime.now().toIso8601String(),
        ),
      );
      final repo = AppRepository(db);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            repositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Rola o ListView para baixo até encontrar a seção de sincronização Supabase
      await tester.scrollUntilVisible(
        find.text('Conta e Sincronização (Supabase)'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Conta e Sincronização (Supabase)'));
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();

      // O card de chave E2EE DEVE estar visível mesmo quando currentUser == null
      expect(
        find.text('Chave E2EE de 24 Palavras Necessária'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(ElevatedButton, 'Configurar / Restaurar Chave de 24 Palavras'),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });

    testWidgets('E2eeSetupDialog.show abre sem exigir userId explícito', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await db.into(db.appKvStore).insert(
        AppKvStoreCompanion.insert(
          key: 'last_silent_backup_timestamp',
          value: DateTime.now().toIso8601String(),
        ),
      );
      final repo = AppRepository(db);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            repositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (ctx) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => E2eeSetupDialog.show(ctx),
                  child: const Text('Abrir Dialog'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Abrir Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Criptografia Ponta a Ponta (E2EE)'), findsOneWidget);
      expect(find.text('Novo Cofre'), findsOneWidget);
      expect(find.text('Restaurar com Frase'), findsOneWidget);

      // Fecha o dialog antes de desmontar o widget
      Navigator.of(tester.element(find.text('Criptografia Ponta a Ponta (E2EE)'))).pop();
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });

    testWidgets('Card E2EE configurado exibe status ativo e ações de chave mesmo sem login', (tester) async {
      tester.view.physicalSize = const Size(1024, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await db.into(db.appKvStore).insert(
        AppKvStoreCompanion.insert(
          key: 'last_silent_backup_timestamp',
          value: DateTime.now().toIso8601String(),
        ),
      );
      final repo = AppRepository(db);

      final keyStore = RecoveryKeyStore();
      final testPhrase = RecoveryCrypto.createPhrase();
      await tester.runAsync(() async {
        await keyStore.install(owner: 'local_user', phrase: testPhrase, confirmation: testPhrase);
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            repositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.scrollUntilVisible(
        find.text('Conta e Sincronização (Supabase)'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Conta e Sincronização (Supabase)'));
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();

      // O card deve indicar E2EE Ativa e permitir reconfigurar ou verificar status
      expect(find.text('Criptografia de Ponta a Ponta Ativa (E2EE)'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Configurar / Restaurar Chave (24 Palavras)'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Verificar Status do Cofre'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });

    testWidgets('E2eeViewPhraseDialog exibe as 24 palavras com botão de cópia', (tester) async {
      const phrase = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon art';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: E2eeViewPhraseDialog(phrase: phrase),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Frase de Recuperação E2EE'), findsOneWidget);
      expect(find.text('Copiar'), findsOneWidget);
      expect(find.text('abandon'), findsWidgets);

      await tester.scrollUntilVisible(
        find.text('art'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('art'), findsOneWidget);
    });
  });

  group('Inbox & Email Supabase Sync Queue Tests', () {
    test('saveDraft enfileira item na sync_queue para replicação ao Supabase', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final service = JwEmailService(db: db, biometricAuth: BiometricAuthService());
      final draft = JwEmailMessage(
        id: 'draft-sync-test-1',
        subject: 'Assunto do Rascunho',
        bodyText: 'Corpo da mensagem de teste',
        from: 'missionario@jw.org',
        to: 'anciao@jw.org',
        date: DateTime.now(),
        isDraft: true,
      );

      await service.saveDraft(draft);

      final entries = await db.select(db.inboxEntries).get();
      expect(entries.length, 1);
      expect(entries.single.id, 'email_draft_draft-sync-test-1');

      final queue = await db.select(db.syncQueue).get();
      expect(queue.length, 1);
      expect(queue.single.entityType, 'inbox_entries');
      expect(queue.single.entityId, 'email_draft_draft-sync-test-1');
      expect(queue.single.operation, 'INSERT');

      final payload = jsonDecode(queue.single.payload) as Map<String, dynamic>;
      expect(payload['content'], contains('Assunto do Rascunho'));

      // Atualiza o rascunho existente - operação agora deve ser UPDATE
      final updatedDraft = draft.copyWith(subject: 'Assunto Atualizado');
      await service.saveDraft(updatedDraft);

      final queueAfterUpdate = await db.select(db.syncQueue).get();
      expect(queueAfterUpdate.length, 2);
      expect(queueAfterUpdate.last.entityType, 'inbox_entries');
      expect(queueAfterUpdate.last.entityId, 'email_draft_draft-sync-test-1');
      expect(queueAfterUpdate.last.operation, 'UPDATE');

      await db.close();
    });
  });
}
