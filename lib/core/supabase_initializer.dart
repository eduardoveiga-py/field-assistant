import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_config.dart';
import 'app_logger.dart';

/// Assinatura para injeção personalizada do inicializador do Supabase (utilizado em testes).
typedef SupabaseCustomInitializer = FutureOr<SupabaseClient?> Function({
  required String url,
  required String anonKey,
  http.Client? httpClient,
});

/// Estados transparentes do ciclo de vida e conectividade com o Supabase remoto.
enum SupabaseConnectionState {
  /// Supabase não configurado (URL e Chave vazios). Modo puramente offline local.
  unconfigured,

  /// Processo de inicialização do SDK em andamento.
  initializing,

  /// SDK Supabase inicializado localmente com sucesso, aguardando prova de conectividade.
  initialized,

  /// Conexão de rede remota ativa e verificada com o backend Supabase.
  connected,

  /// SDK inicializado, mas sem conexão de rede (dispositivo offline ou host inalcançável).
  disconnected,

  /// Conexão remota estabelecida, mas uma sessão de usuário autenticado é necessária.
  authenticationRequired,

  /// Sessão de autenticação expirada e renovação automática pendente ou falhou.
  authenticationExpired,

  /// Falha fatal de configuração ou erro na inicialização do SDK.
  error;

  /// Retorna `true` se o SDK estiver pronto para uso operacional local ou remoto.
  bool get isReady =>
      this == SupabaseConnectionState.initialized ||
      this == SupabaseConnectionState.connected;

  /// Retorna `true` se estiver operando em modo offline (sem configuração ou desconectado).
  bool get isOffline =>
      this == SupabaseConnectionState.unconfigured ||
      this == SupabaseConnectionState.disconnected;

  /// Retorna `true` se houver conexão ativa remota comprovada.
  bool get isConnected => this == SupabaseConnectionState.connected;

  /// Retorna `true` se ocorreu um erro de configuração ou falha técnica.
  bool get hasError => this == SupabaseConnectionState.error;
}

/// Registro diagnóstico do estado e timestamp do Supabase.
@immutable
class SupabaseStateInfo {
  final SupabaseConnectionState state;
  final String? errorMessage;
  final DateTime timestamp;

  const SupabaseStateInfo({
    required this.state,
    this.errorMessage,
    required this.timestamp,
  });

  @override
  String toString() =>
      'SupabaseStateInfo(state: ${state.name}, error: $errorMessage, time: $timestamp)';
}

/// Inicializador centralizado, idempotente e resiliente do Supabase.
///
/// Garante que `Supabase.instance.client` NUNCA seja acessado antes da inicialização
/// bem-sucedida, prevenindo qualquer [AssertionError] em tempo de execução.
class SupabaseInitializer {
  SupabaseInitializer._();

  static bool _isInitialized = false;
  static SupabaseConnectionState _currentState =
      SupabaseConnectionState.unconfigured;
  static SupabaseStateInfo _currentInfo = SupabaseStateInfo(
    state: SupabaseConnectionState.unconfigured,
    timestamp: DateTime.now(),
  );

  static final StreamController<SupabaseConnectionState> _stateController =
      StreamController<SupabaseConnectionState>.broadcast();
  static final StreamController<SupabaseStateInfo> _infoController =
      StreamController<SupabaseStateInfo>.broadcast();

  static Completer<SupabaseConnectionState>? _initCompleter;
  static AppConfig? _activeConfig;
  static SupabaseClient? _clientOverride;
  static http.Client? _defaultHttpClient;
  static StreamSubscription<AuthState>? _authSubscription;

  /// Indica se o SDK Supabase foi inicializado com sucesso.
  static bool get isInitialized => _isInitialized;

  /// Retorna o estado atual da conexão com o Supabase.
  static SupabaseConnectionState get currentState => _currentState;

  /// Retorna o diagnóstico detalhado atual.
  static SupabaseStateInfo get currentInfo => _currentInfo;

  /// Stream reativo para observar transições do estado da conexão.
  static Stream<SupabaseConnectionState> get stateStream =>
      _stateController.stream;

  /// Stream reativo com informações detalhadas de diagnóstico.
  static Stream<SupabaseStateInfo> get infoStream => _infoController.stream;

  /// Acesso seguro ao [SupabaseClient]. Retorna `null` se não inicializado,
  /// evitando categoricamente o lançamento de [AssertionError].
  static SupabaseClient? get clientOrNull {
    if (_clientOverride != null) return _clientOverride;
    if (!_isInitialized) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Inicializa o Supabase de forma centralizada e idempotente.
  ///
  /// - Se já estiver inicializado, retorna o estado atual sem reinicializar.
  /// - Se uma inicialização estiver em andamento concorrente, aguarda a mesma Future.
  /// - Se [config.status != ConfigStatus.valid], não tenta inicializar e não lança exceção.
  /// - Se houver falha de rede ou timeout, transiciona para [SupabaseConnectionState.disconnected].
  /// - Jamais vaza segredos (tokens ou credenciais) nos logs.
  static Future<SupabaseConnectionState> initializeIfConfigured({
    AppConfig? config,
    http.Client? httpClient,
    SupabaseCustomInitializer? customInit,
    bool checkConnectivityOnStartup = true,
  }) async {
    // Bloqueio de concorrência: se já houver inicialização em progresso, aguarda a mesma Future
    if (_initCompleter != null && !_initCompleter!.isCompleted) {
      AppLogger.debug(
        'SupabaseInitializer: aguardando inicialização concorrente...',
      );
      return _initCompleter!.future;
    }

    // Idempotência: se já inicializado com sucesso, retorna o estado atual imediatamente
    if (_isInitialized) {
      AppLogger.debug(
        'SupabaseInitializer: já inicializado previamente. Estado atual: ${_currentState.name}',
      );
      return _currentState;
    }

    final completer = Completer<SupabaseConnectionState>();
    _initCompleter = completer;

    final appConfig = config ?? AppConfig.fromEnvironment();
    if (httpClient != null) _defaultHttpClient = httpClient;

    try {
      // 1. Caso desconfigurado (modo puramente offline)
      if (appConfig.status == ConfigStatus.unconfigured) {
        AppLogger.info(
          'Supabase não configurado. Inicialização remota ignorada (modo offline local seguro).',
        );
        _updateState(SupabaseConnectionState.unconfigured);
        completer.complete(SupabaseConnectionState.unconfigured);
        return SupabaseConnectionState.unconfigured;
      }

      // 2. Caso configuração inválida
      if (appConfig.status == ConfigStatus.invalid) {
        final errorSummary = appConfig.validationErrors.join('; ');
        AppLogger.error(
          'SupabaseInitializer: configuração rejeitada (${appConfig.maskedUrl}): $errorSummary',
        );
        _updateState(
          SupabaseConnectionState.error,
          errorMessage: 'Configuração inválida: $errorSummary',
        );
        completer.complete(SupabaseConnectionState.error);
        return SupabaseConnectionState.error;
      }

      // 3. Início da inicialização
      _updateState(SupabaseConnectionState.initializing);
      AppLogger.info(
        'SupabaseInitializer: inicializando SDK com endpoint ${appConfig.maskedUrl}...',
      );

      if (customInit != null) {
        final injectedClient = await customInit(
          url: appConfig.supabaseUrl,
          anonKey: appConfig.supabaseAnonKey,
          httpClient: httpClient,
        );
        if (injectedClient != null) {
          _clientOverride = injectedClient;
        }
      } else {
        await Supabase.initialize(
          url: appConfig.supabaseUrl,
          publishableKey: appConfig.supabaseAnonKey,
          httpClient: httpClient,
          authOptions: const FlutterAuthClientOptions(autoRefreshToken: true),
        );
      }

      _isInitialized = true;
      _activeConfig = appConfig;
      _updateState(SupabaseConnectionState.initialized);
      AppLogger.info('SupabaseInitializer: SDK inicializado com sucesso.');

      _setupAuthListener();

      if (checkConnectivityOnStartup) {
        await checkConnectivity(
          httpClient: httpClient,
          timeout: const Duration(seconds: 4),
        );
      }

      completer.complete(_currentState);
      return _currentState;
    } catch (e, stackTrace) {
      if (_isNetworkException(e)) {
        AppLogger.warning(
          'SupabaseInitializer: falha de rede/conectividade durante inicialização (${appConfig.maskedUrl})',
          e,
        );
        _updateState(
          SupabaseConnectionState.disconnected,
          errorMessage: 'Sem conectividade com o servidor remoto.',
        );
        completer.complete(SupabaseConnectionState.disconnected);
        return SupabaseConnectionState.disconnected;
      } else {
        AppLogger.error(
          'SupabaseInitializer: erro inesperado na inicialização (${appConfig.maskedUrl})',
          e,
          stackTrace,
        );
        _updateState(SupabaseConnectionState.error, errorMessage: e.toString());
        completer.complete(SupabaseConnectionState.error);
        return SupabaseConnectionState.error;
      }
    } finally {
      if (!completer.isCompleted) {
        completer.complete(_currentState);
      }
    }
  }

  /// Verifica conectividade de rede ativa com o backend do Supabase
  static Future<SupabaseConnectionState> checkConnectivity({
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    if (_activeConfig == null || !_isInitialized) {
      if (_currentState == SupabaseConnectionState.unconfigured) {
        return SupabaseConnectionState.unconfigured;
      }
      return _currentState;
    }

    final url = _activeConfig!.supabaseUrl;
    final anonKey = _activeConfig!.supabaseAnonKey;
    final client = httpClient ?? _defaultHttpClient ?? http.Client();
    final shouldCloseClient = httpClient == null && _defaultHttpClient == null;

    try {
      final probeUri = Uri.parse('$url/rest/v1/');
      final response = await client
          .get(
            probeUri,
            headers: {'apikey': anonKey, 'Authorization': 'Bearer $anonKey'},
          )
          .timeout(timeout);

      // Qualquer resposta HTTP recebida do servidor confirma que o backend está alcançável
      if (response.statusCode >= 200 && response.statusCode < 500) {
        final currentClient = clientOrNull;
        final session = currentClient?.auth.currentSession;
        if (session != null && session.isExpired) {
          _updateState(SupabaseConnectionState.authenticationExpired);
        } else {
          _updateState(SupabaseConnectionState.connected);
        }
      } else {
        _updateState(
          SupabaseConnectionState.disconnected,
          errorMessage:
              'Status de resposta remoto inesperado: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (_isNetworkException(e)) {
        _updateState(
          SupabaseConnectionState.disconnected,
          errorMessage: 'Backend inalcançável: $e',
        );
      } else {
        _updateState(
          SupabaseConnectionState.error,
          errorMessage: 'Erro na verificação de conectividade: $e',
        );
      }
    } finally {
      if (shouldCloseClient) {
        client.close();
      }
    }

    return _currentState;
  }

  static void _setupAuthListener() {
    try {
      final client = clientOrNull;
      if (client != null) {
        _authSubscription?.cancel();
        _authSubscription = client.auth.onAuthStateChange.listen(
          (data) {
            final event = data.event;
            final session = data.session;
            if (event == AuthChangeEvent.signedIn ||
                event == AuthChangeEvent.tokenRefreshed) {
              _updateState(SupabaseConnectionState.connected);
            } else if (event == AuthChangeEvent.signedOut) {
              _updateState(SupabaseConnectionState.authenticationRequired);
            } else if (session != null && session.isExpired) {
              _updateState(SupabaseConnectionState.authenticationExpired);
            }
          },
          onError: (Object err) {
            AppLogger.warning('Erro no stream de autenticação Supabase', err);
          },
        );
      }
    } catch (_) {}
  }

  static bool _isNetworkException(Object error) {
    final str = error.toString().toLowerCase();
    return str.contains('socketexception') ||
        str.contains('network') ||
        str.contains('connection refused') ||
        str.contains('failed host lookup') ||
        str.contains('clientexception') ||
        str.contains('timeoutexception') ||
        str.contains('handshakeexception') ||
        str.contains('os error') ||
        str.contains('timed out');
  }

  static void _updateState(
    SupabaseConnectionState newState, {
    String? errorMessage,
  }) {
    _currentState = newState;
    _currentInfo = SupabaseStateInfo(
      state: newState,
      errorMessage: errorMessage,
      timestamp: DateTime.now(),
    );
    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
    if (!_infoController.isClosed) {
      _infoController.add(_currentInfo);
    }
  }

  /// Método utilitário de teste para redefinir o estado e permitir testes isolados
  @visibleForTesting
  static Future<void> resetForTesting() async {
    _initCompleter = null;
    _isInitialized = false;
    _activeConfig = null;
    _clientOverride = null;
    _defaultHttpClient = null;
    await _authSubscription?.cancel();
    _authSubscription = null;
    _currentState = SupabaseConnectionState.unconfigured;
    _currentInfo = SupabaseStateInfo(
      state: SupabaseConnectionState.unconfigured,
      timestamp: DateTime.now(),
    );
    try {
      await Supabase.instance.dispose();
    } catch (_) {}
  }

  /// Injeta um cliente de mock e força um estado para testes unitários
  @visibleForTesting
  static void setMockStateForTesting({
    required SupabaseConnectionState state,
    SupabaseClient? client,
    AppConfig? config,
    String? errorMessage,
    http.Client? httpClient,
  }) {
    _currentState = state;
    _clientOverride = client;
    if (httpClient != null) _defaultHttpClient = httpClient;
    _isInitialized =
        client != null ||
        state == SupabaseConnectionState.initialized ||
        state == SupabaseConnectionState.connected;
    if (config != null) _activeConfig = config;
    _updateState(state, errorMessage: errorMessage);
  }
}

/// Função de conveniência de nível superior exigida pela especificação U2.
Future<SupabaseConnectionState> initializeSupabaseIfConfigured({
  AppConfig? config,
  http.Client? httpClient,
  SupabaseCustomInitializer? customInit,
  bool checkConnectivityOnStartup = true,
}) {
  return SupabaseInitializer.initializeIfConfigured(
    config: config,
    httpClient: httpClient,
    customInit: customInit,
    checkConnectivityOnStartup: checkConnectivityOnStartup,
  );
}

/// Notifier do estado de conexão para atualização reativa no Riverpod
class SupabaseConnectionStateNotifier
    extends Notifier<SupabaseConnectionState> {
  StreamSubscription<SupabaseConnectionState>? _subscription;

  @override
  SupabaseConnectionState build() {
    _subscription?.cancel();
    _subscription = SupabaseInitializer.stateStream.listen((newState) {
      state = newState;
    });
    ref.onDispose(() => _subscription?.cancel());
    return SupabaseInitializer.currentState;
  }
}

/// Provider do estado atual da conexão Supabase.
final supabaseConnectionStateProvider =
    NotifierProvider<SupabaseConnectionStateNotifier, SupabaseConnectionState>(
      SupabaseConnectionStateNotifier.new,
    );

/// Notifier do cliente Supabase seguro para atualização reativa no Riverpod
class SupabaseClientNotifier extends Notifier<SupabaseClient?> {
  StreamSubscription<SupabaseConnectionState>? _subscription;

  @override
  SupabaseClient? build() {
    _subscription?.cancel();
    _subscription = SupabaseInitializer.stateStream.listen((_) {
      state = SupabaseInitializer.clientOrNull;
    });
    ref.onDispose(() => _subscription?.cancel());
    return SupabaseInitializer.clientOrNull;
  }
}

/// Provider do cliente Supabase seguro (nulo se não inicializado).
final supabaseClientProvider =
    NotifierProvider<SupabaseClientNotifier, SupabaseClient?>(
      SupabaseClientNotifier.new,
    );

/// StreamProvider reativo para a interface observar transições de conectividade remota.
final supabaseConnectionStateStreamProvider =
    StreamProvider<SupabaseConnectionState>((ref) {
      return SupabaseInitializer.stateStream;
    });
