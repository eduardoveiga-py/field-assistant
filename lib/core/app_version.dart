/// Centralização de versão e metadados do aplicativo Ministério Pessoal.
/// Fonte única da verdade para versionamento, release notes e cabeçalhos de rede.
class AppVersion {
  AppVersion._();

  /// Versão Semântica Oficial (Major.Minor.Patch)
  static const String version = '1.3.4';

  /// Número sequencial da compilação (build number)
  static const int buildNumber = 11;

  /// Prefixo canônico para exibição em interfaces
  static const String displayVersion = 'v$version';

  /// Rótulo completo para interfaces de configurações e diagnóstico
  static const String fullDisplayVersion = 'v$version+$buildNumber';

  /// Data oficial do lançamento (AAAA-MM-DD)
  static const String releaseDate = '2026-11-11';

  /// Nome amigável do aplicativo
  static const String appName = 'Ministério Pessoal';

  /// Repositório oficial no GitHub
  static const String githubRepo = 'eduardoveiga-py/field-assistant';

  /// URL da API GitHub para checagem da última release
  static const String latestReleaseApiUrl =
      'https://api.github.com/repos/eduardoveiga-py/field-assistant/releases/latest';

  /// URL oficial imutável do arquivo apps.json fixada na tag da versão atual (A10)
  static const String pinnedAppsJsonUrl =
      'https://cdn.jsdelivr.net/gh/eduardoveiga-py/field-assistant@v$version/apps.json';

  /// URL de manifesto apps.json anexado diretamente à última GitHub Release
  static const String releaseAppsJsonUrl =
      'https://github.com/eduardoveiga-py/field-assistant/releases/latest/download/apps.json';

  /// URL legada de fallback do apps.json (usada apenas se fontes imutáveis falharem)
  static const String appsJsonUrl =
      'https://cdn.jsdelivr.net/gh/eduardoveiga-py/field-assistant@master/apps.json';

  /// URL de download direto do IPA unsigned
  static const String latestIpaDownloadUrl =
      'https://github.com/eduardoveiga-py/field-assistant/releases/latest/download/app-release-unsigned.ipa';

  /// URL de download direto do APK Android
  static const String latestApkDownloadUrl =
      'https://github.com/eduardoveiga-py/field-assistant/releases/latest/download/app-arm64-v8a-release.apk';

  /// URL oficial para adicionar a fonte de apps no LiveContainer (aponta para release publicada, nunca para branch móvel)
  static String get liveContainerSourceUrl =>
      'livecontainer://sources?url=${Uri.encodeComponent(releaseAppsJsonUrl)}';

  /// Alias de conveniência para liveContainerSourceUrl
  static String get liveContainerInstallUrl => liveContainerSourceUrl;

  /// User-Agent oficial para requisições externas (OSM, APIs, Nominatim)
  /// em estrita conformidade com as políticas do OpenStreetMap.
  static const String userAgent =
      'MinisterioPessoal/$version (https://github.com/eduardoveiga-py/field-assistant)';

  /// Compara duas versões semânticas (ex: '1.2.0' vs '1.1.1').
  /// Retorna:
  ///   > 0 se [a] for mais recente que [b]
  ///   < 0 se [a] for mais antiga que [b]
  ///   = 0 se forem iguais
  static int compare(String a, String b) {
    final cleanA = _cleanVersion(a);
    final cleanB = _cleanVersion(b);

    final partsA = cleanA.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final partsB = cleanB.split('.').map((p) => int.tryParse(p) ?? 0).toList();

    final maxLen = partsA.length > partsB.length ? partsA.length : partsB.length;
    for (int i = 0; i < maxLen; i++) {
      final valA = i < partsA.length ? partsA[i] : 0;
      final valB = i < partsB.length ? partsB[i] : 0;
      if (valA != valB) {
        return valA.compareTo(valB);
      }
    }
    return 0;
  }

  /// Verifica se a versão [candidate] é estritamente mais recente que a versão corrente do app.
  static bool isNewerThanCurrent(String candidate) {
    return compare(candidate, version) > 0;
  }

  static String _cleanVersion(String v) {
    var s = v.trim();
    if (s.startsWith('v') || s.startsWith('V')) {
      s = s.substring(1);
    }
    final plusIndex = s.indexOf('+');
    if (plusIndex != -1) {
      s = s.substring(0, plusIndex);
    }
    return s;
  }
}
