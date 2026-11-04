import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_logger.dart';

/// Ambientes suportados pelo aplicativo Field Assistant.
enum AppEnvironment {
  development,
  homologation,
  production;

  /// Converte uma string no respectivo [AppEnvironment] com tolerância a variações.
  /// Padrão seguro para [development] se o valor for nulo ou desconhecido.
  static AppEnvironment fromString(String? raw) {
    if (raw == null) return AppEnvironment.development;
    final normalized = raw.trim().toLowerCase();
    switch (normalized) {
      case 'prod':
      case 'production':
      case 'producao':
      case 'produção':
        return AppEnvironment.production;
      case 'homolog':
      case 'homologation':
      case 'staging':
      case 'qa':
      case 'stage':
      case 'teste':
      case 'test':
        return AppEnvironment.homologation;
      case 'dev':
      case 'development':
      case 'desenvolvimento':
      case 'local':
      default:
        return AppEnvironment.development;
    }
  }

  bool get isProduction => this == AppEnvironment.production;
  bool get isHomologation => this == AppEnvironment.homologation;
  bool get isDevelopment => this == AppEnvironment.development;
}

/// Estado do status de configuração remota do Supabase.
enum ConfigStatus {
  /// Supabase não configurado (URL e Anon Key vazios). Modo puramente offline.
  unconfigured,

  /// Configuração presente, validada e segura para inicialização.
  valid,

  /// Configuração incompleta, malformada ou insegura (ex: chave privilegiada).
  invalid,
}

/// Exceção lançada quando uma configuração remota inválida tenta ser validada de forma estrita.
class AppConfigException implements Exception {
  final String message;
  final List<String> errors;

  AppConfigException(this.message, [this.errors = const []]);

  @override
  String toString() {
    if (errors.isEmpty) {
      return 'AppConfigException: $message';
    }
    return 'AppConfigException: $message\nErros:\n - ${errors.join('\n - ')}';
  }
}

/// Gerenciador centralizado e imutável de configurações de ambiente e backend.
class AppConfig {
  final AppEnvironment environment;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String googleWebClientId;
  final ConfigStatus status;
  final List<String> validationErrors;

  const AppConfig._({
    required this.environment,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.googleWebClientId,
    required this.status,
    required this.validationErrors,
  });

  /// Cria uma instância segura desconfigurada (modo offline local puro).
  factory AppConfig.unconfigured([
    AppEnvironment environment = AppEnvironment.development,
  ]) {
    return AppConfig.create(
      environment: environment,
      supabaseUrl: '',
      supabaseAnonKey: '',
      googleWebClientId: '',
    );
  }

  /// Construtor que lê diretamente as variáveis do ambiente compilado (via `--dart-define` ou `--dart-define-from-file`).
  factory AppConfig.fromEnvironment({
    String? environment,
    String? supabaseUrl,
    String? supabaseAnonKey,
    String? googleWebClientId,
  }) {
    final envStr =
        environment ??
        const String.fromEnvironment('APP_ENV', defaultValue: 'dev');
    final urlStr =
        supabaseUrl ??
        const String.fromEnvironment('SUPABASE_URL', defaultValue: '');
    final keyStr =
        supabaseAnonKey ??
        const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
    final googleClientIdStr =
        googleWebClientId ??
        const String.fromEnvironment('GOOGLE_WEB_CLIENT_ID', defaultValue: '');

    final config = AppConfig.create(
      environment: AppEnvironment.fromString(envStr),
      supabaseUrl: urlStr,
      supabaseAnonKey: keyStr,
      googleWebClientId: googleClientIdStr,
    );

    if (config.isInvalid) {
      AppLogger.warning(
        'AppConfig carregado com erros de validação: ${config.validationErrorMessage}',
      );
    } else {
      AppLogger.info('AppConfig carregado: ${config.toDiagnosticString()}');
    }
    return config;
  }

  /// Construtor de fábrica para criação manual e testes, com validação abrangente.
  factory AppConfig.create({
    required AppEnvironment environment,
    required String supabaseUrl,
    required String supabaseAnonKey,
    String googleWebClientId = '',
  }) {
    var trimmedUrl = supabaseUrl.trim();
    // Normalização: remove barra final desnecessária
    while (trimmedUrl.endsWith('/') && trimmedUrl.length > 8) {
      trimmedUrl = trimmedUrl.substring(0, trimmedUrl.length - 1);
    }

    final trimmedKey = supabaseAnonKey.trim();
    final trimmedGoogleClientId = googleWebClientId.trim();
    final List<String> errors = [];

    // Cenário 1: Sem configuração remota (Modo Offline Válido e Seguro)
    if (trimmedUrl.isEmpty && trimmedKey.isEmpty) {
      return AppConfig._(
        environment: environment,
        supabaseUrl: '',
        supabaseAnonKey: '',
        googleWebClientId: trimmedGoogleClientId,
        status: ConfigStatus.unconfigured,
        validationErrors: const [],
      );
    }

    // Cenário 2: Validações de presença
    if (trimmedUrl.isEmpty && trimmedKey.isNotEmpty) {
      errors.add(
        'SUPABASE_URL não pode ser vazia quando SUPABASE_ANON_KEY é fornecida.',
      );
    }
    if (trimmedKey.isEmpty && trimmedUrl.isNotEmpty) {
      errors.add(
        'SUPABASE_ANON_KEY não pode ser vazia quando SUPABASE_URL é fornecida.',
      );
    }

    // Cenário 3: Detecção de placeholders de exemplo não configurados
    if (trimmedUrl.contains('your-supabase-url') ||
        trimmedUrl.contains('example.com') ||
        trimmedUrl.contains('<project-ref>')) {
      errors.add(
        'SUPABASE_URL contém placeholder de exemplo não configurado ($trimmedUrl).',
      );
    }
    if (trimmedKey.contains('your-anon-key') ||
        trimmedKey.contains('your-supabase-anon-key') ||
        trimmedKey.contains('<anon-key>')) {
      errors.add(
        'SUPABASE_ANON_KEY contém placeholder de exemplo não configurado.',
      );
    }

    // Cenário 4: Validação de integridade e segurança da URL
    if (trimmedUrl.isNotEmpty) {
      final uri = Uri.tryParse(trimmedUrl);
      if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
        errors.add(
          'SUPABASE_URL inválida: formato de URI incorreto ($trimmedUrl).',
        );
      } else {
        final scheme = uri.scheme.toLowerCase();
        if (scheme != 'http' && scheme != 'https') {
          errors.add(
            'SUPABASE_URL possui protocolo não suportado ($scheme). Deve ser http ou https.',
          );
        }

        // Credenciais embebidas na URL (Basic Auth) são proibidas por segurança
        if (uri.userInfo.isNotEmpty) {
          errors.add(
            'SUPABASE_URL não pode conter credenciais de usuário na URL.',
          );
        }

        // Parâmetros de consulta e fragmentos são inválidos para endpoint base do Supabase
        if (uri.hasQuery) {
          errors.add(
            'SUPABASE_URL não deve conter parâmetros de consulta (query parameters).',
          );
        }
        if (uri.hasFragment) {
          errors.add('SUPABASE_URL não deve conter fragmentos (#).');
        }

        // Exigência de HTTPS por ambiente
        if (environment.isProduction) {
          if (scheme != 'https') {
            errors.add(
              'Em ambiente de produção (${environment.name}), a SUPABASE_URL deve obrigatoriamente utilizar HTTPS.',
            );
          }
        } else if (environment.isHomologation) {
          if (scheme != 'https' &&
              uri.host != 'localhost' &&
              uri.host != '127.0.0.1') {
            errors.add(
              'Em ambiente de homologação (${environment.name}), a SUPABASE_URL deve obrigatoriamente utilizar HTTPS.',
            );
          }
        }
      }
    }

    // Cenário 5: Validação da chave anon e detecção de credenciais privilegiadas
    if (trimmedKey.isNotEmpty) {
      if (trimmedKey.length < 20) {
        errors.add(
          'SUPABASE_ANON_KEY muito curta ou incompleta (mínimo esperado: 20 caracteres).',
        );
      }

      if (trimmedKey.contains(RegExp(r'\s'))) {
        errors.add(
          'SUPABASE_ANON_KEY não pode conter espaços em branco ou quebras de linha.',
        );
      }

      if (_isPrivilegedKey(trimmedKey)) {
        errors.add(
          'Credencial privilegiada (service_role ou admin token) rejeitada por segurança. '
          'O aplicativo cliente jamais deve receber a service_role key.',
        );
      }
    }

    if (errors.isNotEmpty) {
      return AppConfig._(
        environment: environment,
        supabaseUrl: trimmedUrl,
        supabaseAnonKey: trimmedKey,
        googleWebClientId: trimmedGoogleClientId,
        status: ConfigStatus.invalid,
        validationErrors: List.unmodifiable(errors),
      );
    }

    return AppConfig._(
      environment: environment,
      supabaseUrl: trimmedUrl,
      supabaseAnonKey: trimmedKey,
      googleWebClientId: trimmedGoogleClientId,
      status: ConfigStatus.valid,
      validationErrors: const [],
    );
  }

  /// Verifica se a chave fornecida corresponde a uma credencial privilegiada de serviço ou token de gerenciamento.
  static bool _isPrivilegedKey(String key) {
    final lower = key.toLowerCase();
    if (lower.contains('service_role') ||
        lower.contains('supabase_admin') ||
        lower.contains('super_admin')) {
      return true;
    }
    if (key.startsWith('sbp_')) {
      // Supabase personal management token
      return true;
    }

    // Inspeciona payload se for JWT
    final parts = key.split('.');
    if (parts.length == 3) {
      try {
        final payloadJson = _decodeJwtPayload(parts[1]);
        if (payloadJson != null) {
          final role = payloadJson['role']?.toString().toLowerCase();
          if (role == 'service_role' ||
              role == 'supabase_admin' ||
              role == 'admin' ||
              role == 'super_admin' ||
              role == 'postgres') {
            return true;
          }
        }
      } catch (_) {}
    }
    return false;
  }

  static Map<String, dynamic>? _decodeJwtPayload(String base64UrlPayload) {
    try {
      final normalized = base64.normalize(base64UrlPayload);
      final decodedBytes = base64.decode(normalized);
      final decodedString = utf8.decode(decodedBytes);
      final dynamic parsed = jsonDecode(decodedString);
      if (parsed is Map<String, dynamic>) {
        return parsed;
      }
    } catch (_) {}
    return null;
  }

  /// Retorna `true` se a configuração remota estiver válida e pronta para conexão.
  bool get isConfigured => status == ConfigStatus.valid;

  /// Retorna `true` se o aplicativo estiver operando em modo puramente offline (sem URL/chave).
  bool get isOfflineOnly => status == ConfigStatus.unconfigured;

  /// Retorna `true` se a configuração é válida (seja com Supabase ativo ou puramente offline).
  bool get isValid => status != ConfigStatus.invalid;

  /// Retorna `true` se há erros de validação na configuração fornecida.
  bool get isInvalid => status == ConfigStatus.invalid;

  /// Mensagem resumida de erros de validação, se houver.
  String? get validationErrorMessage =>
      validationErrors.isEmpty ? null : validationErrors.join('; ');

  /// Versão mascarada da URL para logs, ocultando eventuais credenciais de usuário.
  String get maskedUrl {
    if (supabaseUrl.isEmpty) return '(vazio)';
    final uri = Uri.tryParse(supabaseUrl);
    if (uri != null && uri.userInfo.isNotEmpty) {
      return uri.replace(userInfo: '***:***').toString();
    }
    return supabaseUrl;
  }

  /// Versão mascarada da chave anon key para logs técnicos seguros, evitando vazamento de segredos.
  String get maskedAnonKey {
    if (supabaseAnonKey.isEmpty) return '(não configurada)';
    if (supabaseAnonKey.length <= 12) {
      return '*** (len: ${supabaseAnonKey.length})';
    }
    return '${supabaseAnonKey.substring(0, 6)}...${supabaseAnonKey.substring(supabaseAnonKey.length - 4)} (len: ${supabaseAnonKey.length})';
  }

  /// Versão mascarada do Google Web Client ID para logs diagnósticos seguros.
  String get maskedGoogleWebClientId {
    if (googleWebClientId.isEmpty) return '(não configurado)';
    if (googleWebClientId.length <= 16) return '***';
    return '${googleWebClientId.substring(0, 8)}...${googleWebClientId.substring(googleWebClientId.length - 8)}';
  }

  /// Valida estritamente a configuração.
  /// Lança [AppConfigException] se [isInvalid] for verdadeiro ou se [requireConfigured] for true e estiver em modo offline.
  void validateOrThrow({bool requireConfigured = false}) {
    if (isInvalid) {
      throw AppConfigException(
        'Configuração de ambiente inválida: $validationErrorMessage',
        validationErrors,
      );
    }
    if (requireConfigured && isOfflineOnly) {
      throw AppConfigException(
        'Configuração remota ausente. SUPABASE_URL e SUPABASE_ANON_KEY são obrigatórios para este modo.',
      );
    }
  }

  /// Representação de diagnóstico técnico segura, que nunca expõe chaves completas ou credenciais.
  String toDiagnosticString() {
    if (isInvalid) {
      return 'AppConfig(env: ${environment.name}, status: ${status.name}, url: $maskedUrl, anonKey: $maskedAnonKey, googleClientId: $maskedGoogleWebClientId, errors: [${validationErrors.join("; ")}])';
    }
    return 'AppConfig(env: ${environment.name}, status: ${status.name}, url: $maskedUrl, anonKey: $maskedAnonKey, googleClientId: $maskedGoogleWebClientId)';
  }

  /// Cria uma cópia com campos modificados, revalidando através de [AppConfig.create].
  AppConfig copyWith({
    AppEnvironment? environment,
    String? supabaseUrl,
    String? supabaseAnonKey,
    String? googleWebClientId,
  }) {
    return AppConfig.create(
      environment: environment ?? this.environment,
      supabaseUrl: supabaseUrl ?? this.supabaseUrl,
      supabaseAnonKey: supabaseAnonKey ?? this.supabaseAnonKey,
      googleWebClientId: googleWebClientId ?? this.googleWebClientId,
    );
  }

  @override
  String toString() => toDiagnosticString();
}

/// Notifier para gestão reativa e atualização dinâmica de configurações de ambiente e nuvem.
class AppConfigNotifier extends Notifier<AppConfig> {
  final AppConfig? _initialConfig;

  AppConfigNotifier([this._initialConfig]);

  @override
  AppConfig build() => _initialConfig ?? AppConfig.fromEnvironment();

  /// Atualiza dinamicamente a configuração do app em tempo de execução.
  void updateConfig(AppConfig newConfig) {
    state = newConfig;
  }
}

/// Provider Riverpod para disponibilização global e reativa da configuração validada.
final appConfigProvider = NotifierProvider<AppConfigNotifier, AppConfig>(
  AppConfigNotifier.new,
);
