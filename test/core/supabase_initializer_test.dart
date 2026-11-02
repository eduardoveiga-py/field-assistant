import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ministerio_pessoal/core/app_config.dart';
import 'package:ministerio_pessoal/core/supabase_initializer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Unidade U2 — SupabaseInitializer (Inicialização e Ciclo de Vida)', () {
    setUp(() async {
      await SupabaseInitializer.resetForTesting();
    });

    tearDown(() async {
      await SupabaseInitializer.resetForTesting();
    });

    test('1. Configuração ausente: permanece unconfigured e opera offline sem tentar conectar', () async {
      final unconfiguredConfig = AppConfig.create(
        environment: AppEnvironment.development,
        supabaseUrl: '',
        supabaseAnonKey: '',
      );

      expect(unconfiguredConfig.isOfflineOnly, isTrue);

      final state = await initializeSupabaseIfConfigured(
        config: unconfiguredConfig,
      );

      expect(state, equals(SupabaseConnectionState.unconfigured));
      expect(SupabaseInitializer.isInitialized, isFalse);
      expect(SupabaseInitializer.clientOrNull, isNull);
      expect(SupabaseInitializer.currentState.isOffline, isTrue);
      expect(SupabaseInitializer.currentState.isReady, isFalse);
    });

    test('2. Configuração inválida: rejeita imediatamente com estado error sem expor credenciais', () async {
      // URL inválida com query parameters não permitidos
      final invalidConfig = AppConfig.create(
        environment: AppEnvironment.development,
        supabaseUrl: 'https://test.supabase.co?token=secret123',
        supabaseAnonKey: 'dummy-anon-key',
      );

      expect(invalidConfig.isInvalid, isTrue);

      final state = await initializeSupabaseIfConfigured(config: invalidConfig);

      expect(state, equals(SupabaseConnectionState.error));
      expect(SupabaseInitializer.isInitialized, isFalse);
      expect(SupabaseInitializer.clientOrNull, isNull);
      expect(SupabaseInitializer.currentState.hasError, isTrue);
      expect(
        SupabaseInitializer.currentInfo.errorMessage,
        contains('Configuração inválida'),
      );
      // Garante que o segredo não vazou na mensagem de erro
      expect(
        SupabaseInitializer.currentInfo.errorMessage,
        isNot(contains('secret123')),
      );
    });

    test('3. Configuração válida: inicialização com sucesso transiciona para initialized/connected', () async {
      final validConfig = AppConfig.create(
        environment: AppEnvironment.development,
        supabaseUrl: 'https://valid-project.supabase.co',
        supabaseAnonKey: 'valid-anon-key-1234567890',
      );

      int initCalls = 0;
      final mockClient = MockClient((request) async {
        return http.Response('{"ok": true}', 200);
      });

      final recordedStates = <SupabaseConnectionState>[];
      final subscription = SupabaseInitializer.stateStream.listen(
        recordedStates.add,
      );

      final state = await SupabaseInitializer.initializeIfConfigured(
        config: validConfig,
        httpClient: mockClient,
        customInit:
            ({
              required String url,
              required String anonKey,
              http.Client? httpClient,
            }) async {
              initCalls++;
              return SupabaseClient(url, anonKey, httpClient: httpClient);
            },
      );

      await Future.delayed(const Duration(milliseconds: 50));
      await subscription.cancel();

      expect(initCalls, equals(1));
      expect(SupabaseInitializer.isInitialized, isTrue);
      expect(state, equals(SupabaseConnectionState.connected));
      expect(recordedStates, contains(SupabaseConnectionState.initializing));
      expect(recordedStates, contains(SupabaseConnectionState.initialized));
      expect(recordedStates, contains(SupabaseConnectionState.connected));
    });

    test('4. Idempotência: chamadas repetidas consecutivas retornam o mesmo estado sem reexecução', () async {
      final validConfig = AppConfig.create(
        environment: AppEnvironment.development,
        supabaseUrl: 'https://valid-project.supabase.co',
        supabaseAnonKey: 'valid-anon-key-1234567890',
      );

      int initExecutions = 0;
      final mockHttpClient = MockClient(
        (req) async => http.Response('[]', 200),
      );

      final state1 = await SupabaseInitializer.initializeIfConfigured(
        config: validConfig,
        httpClient: mockHttpClient,
        customInit: ({required url, required anonKey, httpClient}) async {
          initExecutions++;
          return SupabaseClient(url, anonKey, httpClient: httpClient);
        },
      );

      expect(initExecutions, equals(1));
      expect(state1, equals(SupabaseConnectionState.connected));

      // Segunda e terceira chamadas consecutivas
      final state2 = await SupabaseInitializer.initializeIfConfigured(
        config: validConfig,
        httpClient: mockHttpClient,
        customInit: ({required url, required anonKey, httpClient}) async {
          initExecutions++;
          return SupabaseClient(url, anonKey, httpClient: httpClient);
        },
      );

      final state3 = await SupabaseInitializer.initializeIfConfigured(
        config: validConfig,
        httpClient: mockHttpClient,
        customInit: ({required url, required anonKey, httpClient}) async {
          initExecutions++;
          return SupabaseClient(url, anonKey, httpClient: httpClient);
        },
      );

      expect(
        initExecutions,
        equals(1),
        reason: 'customInit deve ser chamado exatamente uma vez',
      );
      expect(state2, equals(state1));
      expect(state3, equals(state1));
    });

    test('5. Concorrência: múltiplas chamadas simultâneas aguardam lock e executam apenas uma vez', () async {
      final validConfig = AppConfig.create(
        environment: AppEnvironment.development,
        supabaseUrl: 'https://valid-project.supabase.co',
        supabaseAnonKey: 'valid-anon-key-1234567890',
      );

      int concurrentInitExecutions = 0;
      final mockHttpClient = MockClient(
        (req) async => http.Response('[]', 200),
      );

      // 10 chamadas concorrentes disparadas no mesmo instante
      final results = await Future.wait(
        List.generate(
          10,
          (_) => SupabaseInitializer.initializeIfConfigured(
            config: validConfig,
            httpClient: mockHttpClient,
            customInit: ({required url, required anonKey, httpClient}) async {
              concurrentInitExecutions++;
              // Simula latência de rede/inicialização
              await Future.delayed(const Duration(milliseconds: 30));
              return SupabaseClient(url, anonKey, httpClient: httpClient);
            },
          ),
        ),
      );

      expect(concurrentInitExecutions, equals(1));
      for (final result in results) {
        expect(result, equals(SupabaseConnectionState.connected));
      }
    });

    test('6. Falha de rede durante inicialização: transiciona para disconnected sem estourar exceção', () async {
      final validConfig = AppConfig.create(
        environment: AppEnvironment.development,
        supabaseUrl: 'https://valid-project.supabase.co',
        supabaseAnonKey: 'valid-anon-key-1234567890',
      );

      final state = await SupabaseInitializer.initializeIfConfigured(
        config: validConfig,
        customInit: ({required url, required anonKey, httpClient}) async {
          throw const SocketException('No route to host (dispositivo offline)');
        },
      );

      expect(state, equals(SupabaseConnectionState.disconnected));
      expect(
        SupabaseInitializer.currentState,
        equals(SupabaseConnectionState.disconnected),
      );
      expect(SupabaseInitializer.currentState.isOffline, isTrue);
      expect(
        SupabaseInitializer.currentInfo.errorMessage,
        contains('Sem conectividade'),
      );
    });

    test('7. Timeout de rede durante inicialização: transiciona para disconnected com mensagem segura', () async {
      final validConfig = AppConfig.create(
        environment: AppEnvironment.development,
        supabaseUrl: 'https://valid-project.supabase.co',
        supabaseAnonKey: 'valid-anon-key-1234567890',
      );

      final state = await SupabaseInitializer.initializeIfConfigured(
        config: validConfig,
        customInit: ({required url, required anonKey, httpClient}) async {
          throw TimeoutException('Tempo de conexão esgotado');
        },
      );

      expect(state, equals(SupabaseConnectionState.disconnected));
      expect(
        SupabaseInitializer.currentState,
        equals(SupabaseConnectionState.disconnected),
      );
    });

    test('8. checkConnectivity: probe ativo valida reachability e transiciona entre connected e disconnected', () async {
      final validConfig = AppConfig.create(
        environment: AppEnvironment.development,
        supabaseUrl: 'https://probe-test.supabase.co',
        supabaseAnonKey: 'valid-anon-key-1234567890',
      );

      bool simulateOffline = false;
      final mockHttpClient = MockClient((request) async {
        if (simulateOffline) {
          throw const SocketException('Network is down');
        }
        return http.Response('{"ok": true}', 200);
      });

      await SupabaseInitializer.initializeIfConfigured(
        config: validConfig,
        httpClient: mockHttpClient,
        customInit: ({required url, required anonKey, httpClient}) async {
          return SupabaseClient(url, anonKey, httpClient: httpClient);
        },
        checkConnectivityOnStartup: true,
      );

      expect(
        SupabaseInitializer.currentState,
        equals(SupabaseConnectionState.connected),
      );

      // Simula queda de conectividade
      simulateOffline = true;
      final stateOffline = await SupabaseInitializer.checkConnectivity(
        httpClient: mockHttpClient,
      );
      expect(stateOffline, equals(SupabaseConnectionState.disconnected));

      // Simula restauração de conectividade
      simulateOffline = false;
      final stateOnline = await SupabaseInitializer.checkConnectivity(
        httpClient: mockHttpClient,
      );
      expect(stateOnline, equals(SupabaseConnectionState.connected));
    });

    test('9. Blindagem contra acesso prematuro: clientOrNull retorna null sem lançar AssertionError', () {
      expect(SupabaseInitializer.isInitialized, isFalse);

      // Nunca pode disparar AssertionError
      expect(() => SupabaseInitializer.clientOrNull, returnsNormally);
      expect(SupabaseInitializer.clientOrNull, isNull);
    });

    test('10. Riverpod Providers: expõem estado, streams e cliente com isolamento e segurança', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // 1. Estado inicial não configurado
      expect(
        container.read(supabaseConnectionStateProvider),
        equals(SupabaseConnectionState.unconfigured),
      );
      expect(container.read(supabaseClientProvider), isNull);

      // 2. Mock state injetado
      final validConfig = AppConfig.create(
        environment: AppEnvironment.development,
        supabaseUrl: 'https://riverpod-test.supabase.co',
        supabaseAnonKey: 'test-key-123',
      );
      final dummyClient = SupabaseClient(
        'https://riverpod-test.supabase.co',
        'test-key-123',
      );

      SupabaseInitializer.setMockStateForTesting(
        state: SupabaseConnectionState.connected,
        client: dummyClient,
        config: validConfig,
      );

      await Future.delayed(const Duration(milliseconds: 20));

      expect(
        container.read(supabaseConnectionStateProvider),
        equals(SupabaseConnectionState.connected),
      );
      expect(container.read(supabaseClientProvider), isNotNull);
      expect(container.read(supabaseClientProvider), equals(dummyClient));
    });
  });
}
