import 'dart:async';
import 'dart:io';

/// Exceção lançada imediatamente quando uma requisição de rede tenta alcançar
/// a internet ou qualquer endereço que não seja de loopback local
/// enquanto o modo avião estiver ativado (FAES §1, Fail-Closed Verification).
class AirplaneModeViolationException implements Exception {
  final Uri uri;
  final String method;
  final String blockedHost;
  final String reason;

  AirplaneModeViolationException({
    required this.uri,
    required this.blockedHost,
    this.method = 'UNKNOWN',
    String? reason,
  }) : reason = reason ??
            'External network request blocked while Airplane Mode is active.';

  @override
  String toString() =>
      'AirplaneModeViolationException: $reason [Method: $method, Host: $blockedHost, URI: $uri]';
}

/// Gate de rede fail-closed baseado em [HttpOverrides] que intercepta todas as
/// chamadas HTTP/HTTPS originadas pelo Dart Runtime.
///
/// Permite estritamente tráfego para a interface de loopback (`127.0.0.1`, `localhost`, `::1`)
/// necessário para o servidor de tiles vetoriais offline ([OfflineTileServer]).
/// Qualquer tentativa de conexão para hosts externos lança [AirplaneModeViolationException].
class AirplaneNetworkGate extends HttpOverrides {
  final Set<String> allowedHosts;
  bool airplaneModeActive;
  HttpOverrides? _previousOverrides;

  AirplaneNetworkGate({
    Set<String>? allowedHosts,
    this.airplaneModeActive = true,
  }) : allowedHosts = allowedHosts != null
            ? allowedHosts.map((h) => h.toLowerCase().trim()).toSet()
            : const {'127.0.0.1', 'localhost', '::1'};

  /// Verifica se um host é permitido pelo gate.
  bool isAllowed(String host) {
    if (!airplaneModeActive) return true;
    return allowedHosts.contains(host.toLowerCase().trim());
  }

  /// Instala este gate globalmente em [HttpOverrides.global], salvando o estado prévio.
  AirplaneNetworkGate install() {
    _previousOverrides = HttpOverrides.current;
    HttpOverrides.global = this;
    return this;
  }

  /// Restaura os overrides prévios de rede.
  void uninstall() {
    HttpOverrides.global = _previousOverrides;
    _previousOverrides = null;
  }

  /// Executa [computation] dentro de uma zona com [AirplaneNetworkGate] ativo.
  static R runWithGate<R>(
    R Function() computation, {
    Set<String>? allowedHosts,
    bool airplaneMode = true,
  }) {
    final gate = AirplaneNetworkGate(
      allowedHosts: allowedHosts,
      airplaneModeActive: airplaneMode,
    );
    return HttpOverrides.runWithHttpOverrides<R>(computation, gate);
  }

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    // Cria o cliente nativo de base
    final nativeClient = super.createHttpClient(context);
    if (!airplaneModeActive) {
      return nativeClient;
    }
    return _AirplaneGateHttpClient(nativeClient, this);
  }
}

/// Decorator de [HttpClient] que intercepta e valida o destino de cada requisição.
class _AirplaneGateHttpClient implements HttpClient {
  final HttpClient _inner;
  final AirplaneNetworkGate _gate;

  _AirplaneGateHttpClient(this._inner, this._gate);

  void _validateDestination(String host, Uri uri, String method) {
    if (!_gate.isAllowed(host)) {
      throw AirplaneModeViolationException(
        uri: uri,
        blockedHost: host,
        method: method,
        reason:
            'Blocked external network call to "$host" ($uri) while Airplane Mode is active. '
            'Only loopback hosts (${_gate.allowedHosts.join(", ")}) are permitted.',
      );
    }
  }

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) {
    _validateDestination(url.host, url, method);
    return _inner.openUrl(method, url);
  }

  @override
  Future<HttpClientRequest> open(
    String method,
    String host,
    int port,
    String path,
  ) {
    final uri = Uri(scheme: 'http', host: host, port: port, path: path);
    _validateDestination(host, uri, method);
    return _inner.open(method, host, port, path);
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);

  @override
  Future<HttpClientRequest> postUrl(Uri url) => openUrl('POST', url);

  @override
  Future<HttpClientRequest> putUrl(Uri url) => openUrl('PUT', url);

  @override
  Future<HttpClientRequest> deleteUrl(Uri url) => openUrl('DELETE', url);

  @override
  Future<HttpClientRequest> patchUrl(Uri url) => openUrl('PATCH', url);

  @override
  Future<HttpClientRequest> headUrl(Uri url) => openUrl('HEAD', url);

  @override
  Future<HttpClientRequest> get(String host, int port, String path) =>
      open('GET', host, port, path);

  @override
  Future<HttpClientRequest> post(String host, int port, String path) =>
      open('POST', host, port, path);

  @override
  Future<HttpClientRequest> put(String host, int port, String path) =>
      open('PUT', host, port, path);

  @override
  Future<HttpClientRequest> delete(String host, int port, String path) =>
      open('DELETE', host, port, path);

  @override
  Future<HttpClientRequest> patch(String host, int port, String path) =>
      open('PATCH', host, port, path);

  @override
  Future<HttpClientRequest> head(String host, int port, String path) =>
      open('HEAD', host, port, path);

  @override
  bool get autoUncompress => _inner.autoUncompress;

  @override
  set autoUncompress(bool value) => _inner.autoUncompress = value;

  @override
  Duration? get connectionTimeout => _inner.connectionTimeout;

  @override
  set connectionTimeout(Duration? value) => _inner.connectionTimeout = value;

  @override
  Duration get idleTimeout => _inner.idleTimeout;

  @override
  set idleTimeout(Duration value) => _inner.idleTimeout = value;

  @override
  int? get maxConnectionsPerHost => _inner.maxConnectionsPerHost;

  @override
  set maxConnectionsPerHost(int? value) => _inner.maxConnectionsPerHost = value;

  @override
  String? get userAgent => _inner.userAgent;

  @override
  set userAgent(String? value) => _inner.userAgent = value;

  @override
  void addCredentials(
    Uri url,
    String realm,
    HttpClientCredentials credentials,
  ) =>
      _inner.addCredentials(url, realm, credentials);

  @override
  void addProxyCredentials(
    String host,
    int port,
    String realm,
    HttpClientCredentials credentials,
  ) =>
      _inner.addProxyCredentials(host, port, realm, credentials);

  @override
  set authenticate(
    Future<bool> Function(Uri url, String scheme, String? realm)? f,
  ) =>
      _inner.authenticate = f;

  @override
  set authenticateProxy(
    Future<bool> Function(
      String host,
      int port,
      String scheme,
      String? realm,
    )?
    f,
  ) =>
      _inner.authenticateProxy = f;

  @override
  set badCertificateCallback(
    bool Function(X509Certificate cert, String host, int port)? callback,
  ) =>
      _inner.badCertificateCallback = callback;

  @override
  set findProxy(String Function(Uri url)? f) => _inner.findProxy = f;

  @override
  set connectionFactory(
    Future<ConnectionTask<Socket>> Function(
      Uri url,
      String? proxyHost,
      int? proxyPort,
    )?
    f,
  ) =>
      _inner.connectionFactory = f;

  @override
  set keyLog(Function(String line)? callback) => _inner.keyLog = callback;

  @override
  void close({bool force = false}) => _inner.close(force: force);
}
