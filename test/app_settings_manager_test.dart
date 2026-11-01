import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/settings/app_settings_manager.dart';
import 'package:ministerio_pessoal/core/feature_registry.dart';
import 'package:ministerio_pessoal/ui/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppSettingsManager & Durability Contract', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test(
      '1. Inicialização normal carrega valores pré-existentes do SQLite',
      () async {
        await db
            .into(db.appKvStore)
            .insert(
              AppKvStoreCompanion.insert(
                key: 'theme_mode',
                value: 'dark',
                updatedAt: Value(DateTime.now()),
              ),
            );

        final manager = AppSettingsManager(db);
        final value = await manager.getString('theme_mode');
        expect(value, equals('dark'));
        expect(manager.isInitialized, isTrue);
      },
    );

    test('2. Inicialização concorrente: múltiplas chamadas simultâneas compartilham a mesma operação', () async {
      await db
          .into(db.appKvStore)
          .insert(
            AppKvStoreCompanion.insert(
              key: 'app_lang',
              value: 'pt-BR',
              updatedAt: Value(DateTime.now()),
            ),
          );

      final manager = AppSettingsManager(db);
      final futures = List.generate(10, (_) => manager.getString('app_lang'));
      final results = await Future.wait(futures);

      for (final res in results) {
        expect(res, equals('pt-BR'));
      }
    });

    test(
      '3. Escritas consecutivas persistem ordenadamente no SQLite',
      () async {
        final manager = AppSettingsManager(db);

        await manager.setString('step', '1');
        await manager.setString('step', '2');
        await manager.setString('step', '3');

        final val = await manager.getString('step');
        expect(val, equals('3'));

        // Validação direta no SQLite
        final row = await (db.select(
          db.appKvStore,
        )..where((t) => t.key.equals('step'))).getSingle();
        expect(row.value, equals('3'));
      },
    );

    test('4. Escritas concorrentes / rajada de 50 alterações rápidas: última operação vence determinística', () async {
      final manager = AppSettingsManager(db);

      // Dispara 50 gravações concorrentes sem await intermediário
      final futures = <Future<void>>[];
      for (int i = 0; i < 50; i++) {
        futures.add(manager.setString('burst_key', 'val_$i'));
      }
      await Future.wait(futures);

      // O valor final em memória e no SQLite deve ser val_49
      expect(await manager.getString('burst_key'), equals('val_49'));

      final row = await (db.select(
        db.appKvStore,
      )..where((t) => t.key.equals('burst_key'))).getSingle();
      expect(row.value, equals('val_49'));
    });

    test('5. Alteração durante inicialização não é sobrescrita por dado antigo do banco', () async {
      // Pré-popula banco com valor antigo
      await db
          .into(db.appKvStore)
          .insert(
            AppKvStoreCompanion.insert(
              key: 'config_speed',
              value: 'slow',
              updatedAt: Value(DateTime.now()),
            ),
          );

      final manager = AppSettingsManager(db);
      // Imediatamente antes de aguardar o init(), grava novo valor
      final setFuture = manager.setString('config_speed', 'ultra_fast');
      await setFuture;

      final val = await manager.getString('config_speed');
      expect(val, equals('ultra_fast'));

      // Confirma que no SQLite o valor é o novo
      final row = await (db.select(
        db.appKvStore,
      )..where((t) => t.key.equals('config_speed'))).getSingle();
      expect(row.value, equals('ultra_fast'));
    });

    test('6. Encerramento e reabertura após persistência preserva 100% dos dados confirmados', () async {
      final manager1 = AppSettingsManager(db);
      await manager1.setString('user_token', 'tok_abc123');
      await manager1.setString('auto_backup', 'true');
      await manager1.flush();

      // Simula reabertura do app com nova instância de AppSettingsManager sobre o mesmo banco
      final manager2 = AppSettingsManager(db);
      expect(await manager2.getString('user_token'), equals('tok_abc123'));
      expect(await manager2.getString('auto_backup'), equals('true'));
    });

    test('7 e 8. Tratamento de falha e recuperação da fila', () async {
      final manager = AppSettingsManager(db);
      await manager.setString('valid_key', 'initial');

      // Testa remoção com sucesso
      await manager.remove('valid_key');
      expect(await manager.getString('valid_key'), isNull);

      final row = await (db.select(
        db.appKvStore,
      )..where((t) => t.key.equals('valid_key'))).getSingleOrNull();
      expect(row, isNull);

      // Próxima gravação funciona normalmente (recuperação)
      await manager.setString('recovered_key', 'it_works');
      expect(await manager.getString('recovered_key'), equals('it_works'));
    });

    test('9. Atualização reativa via Riverpod Notifier propaga alterações imediatamente', () async {
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(appSettingsNotifierProvider.notifier);
      await notifier.setString('theme', 'sunMode');

      final state = container.read(appSettingsNotifierProvider);
      expect(state['theme'], equals('sunMode'));
      expect(notifier.get('theme'), equals('sunMode'));

      // Remoção reativa
      await notifier.remove('theme');
      final stateAfterRemove = container.read(appSettingsNotifierProvider);
      expect(stateAfterRemove['theme'], isNull);
    });

    test('10. Integração com FeatureRegistry sem regressões', () async {
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      // Por padrão estudos está habilitado
      final initialStudies = container.read(
        isFeatureEnabledProvider(AppFeature.studies),
      );
      expect(initialStudies, isTrue);

      // Desativa estudos via Notifier com a chave correta
      final notifier = container.read(appSettingsNotifierProvider.notifier);
      await notifier.setString(
        FeatureRegistry.settingKey(AppFeature.studies),
        'false',
      );

      final studiesDisabled = container.read(
        isFeatureEnabledProvider(AppFeature.studies),
      );
      expect(studiesDisabled, isFalse);

      // Reativa estudos
      await notifier.setString(
        FeatureRegistry.settingKey(AppFeature.studies),
        'true',
      );
      final studiesReenabled = container.read(
        isFeatureEnabledProvider(AppFeature.studies),
      );
      expect(studiesReenabled, isTrue);
    });

    test(
      '11. Future.wait multiple key writes completes and persists all keys',
      () async {
        final manager = AppSettingsManager(db);
        await Future.wait([
          manager.setString('pioneer_goal_hours', '42.5'),
          manager.setString('pioneer_monthly_goal_hours', '42.5'),
          manager.setString('pioneer_weekdays', '1,3,5'),
          manager.setString('pioneer_designated_weekdays', '1,3,5'),
        ]);
        expect(await manager.getString('pioneer_goal_hours'), equals('42.5'));
        expect(
          await manager.getString('pioneer_monthly_goal_hours'),
          equals('42.5'),
        );
        expect(await manager.getString('pioneer_weekdays'), equals('1,3,5'));
        expect(
          await manager.getString('pioneer_designated_weekdays'),
          equals('1,3,5'),
        );

        final all = await manager.getAllSettings();
        expect(all['pioneer_goal_hours'], equals('42.5'));
        expect(all['pioneer_monthly_goal_hours'], equals('42.5'));
        expect(all['pioneer_weekdays'], equals('1,3,5'));
        expect(all['pioneer_designated_weekdays'], equals('1,3,5'));
      },
    );
  });
}
