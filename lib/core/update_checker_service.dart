import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'app_logger.dart';
import 'app_version.dart';

/// Status detalhado da verificação de atualização
enum UpdateCheckStatus {
  upToDate,
  updateAvailable,
  checkFailed,
  sourceUnavailable,
}

/// Informações sobre o status de atualização do aplicativo.
class AppUpdateInfo {
  final UpdateCheckStatus status;
  final bool hasUpdate;
  final String currentVersion;
  final String latestVersion;
  final String releaseDate;
  final String releaseNotes;
  final String downloadUrl;
  final String sourceCatalogUrl;
  final int? sizeBytes;
  final String minOSVersion;
  final bool isLiveContainerCompatible;
  final String? errorMessage;

  const AppUpdateInfo({
    this.status = UpdateCheckStatus.upToDate,
    required this.hasUpdate,
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseDate,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.sourceCatalogUrl,
    this.sizeBytes,
    this.minOSVersion = '14.0',
    this.isLiveContainerCompatible = true,
    this.errorMessage,
  });

  factory AppUpdateInfo.upToDate({
    String? currentVersion,
    String? latestVersion,
    String? downloadUrl,
    String? releaseDate,
    String? releaseNotes,
  }) {
    final cur = currentVersion ?? AppVersion.version;
    return AppUpdateInfo(
      status: UpdateCheckStatus.upToDate,
      hasUpdate: false,
      currentVersion: cur,
      latestVersion: latestVersion ?? cur,
      releaseDate: releaseDate ?? AppVersion.releaseDate,
      releaseNotes: releaseNotes ?? 'Você já está utilizando a versão mais recente do Ministério Pessoal.',
      downloadUrl: downloadUrl ?? AppVersion.latestIpaDownloadUrl,
      sourceCatalogUrl: AppVersion.appsJsonUrl,
    );
  }

  factory AppUpdateInfo.noUpdate({String? currentVersion}) =>
      AppUpdateInfo.upToDate(currentVersion: currentVersion);

  factory AppUpdateInfo.updateAvailable({
    required String currentVersion,
    required String latestVersion,
    required String releaseDate,
    required String releaseNotes,
    required String downloadUrl,
    required String sourceCatalogUrl,
    int? sizeBytes,
    String minOSVersion = '14.0',
    bool isLiveContainerCompatible = true,
  }) {
    return AppUpdateInfo(
      status: UpdateCheckStatus.updateAvailable,
      hasUpdate: true,
      currentVersion: currentVersion,
      latestVersion: latestVersion,
      releaseDate: releaseDate,
      releaseNotes: releaseNotes,
      downloadUrl: downloadUrl,
      sourceCatalogUrl: sourceCatalogUrl,
      sizeBytes: sizeBytes,
      minOSVersion: minOSVersion,
      isLiveContainerCompatible: isLiveContainerCompatible,
    );
  }

  factory AppUpdateInfo.checkFailed({
    String? currentVersion,
    String? message,
  }) {
    final cur = currentVersion ?? AppVersion.version;
    return AppUpdateInfo(
      status: UpdateCheckStatus.checkFailed,
      hasUpdate: false,
      currentVersion: cur,
      latestVersion: cur,
      releaseDate: AppVersion.releaseDate,
      releaseNotes: message ?? 'Não foi possível verificar atualizações.',
      downloadUrl: AppVersion.latestIpaDownloadUrl,
      sourceCatalogUrl: AppVersion.appsJsonUrl,
      errorMessage: message,
    );
  }

  factory AppUpdateInfo.sourceUnavailable({
    String? currentVersion,
    String? message,
  }) {
    final cur = currentVersion ?? AppVersion.version;
    return AppUpdateInfo(
      status: UpdateCheckStatus.sourceUnavailable,
      hasUpdate: false,
      currentVersion: cur,
      latestVersion: cur,
      releaseDate: AppVersion.releaseDate,
      releaseNotes: message ?? 'Fontes de atualização indisponíveis no momento.',
      downloadUrl: AppVersion.latestIpaDownloadUrl,
      sourceCatalogUrl: AppVersion.appsJsonUrl,
      errorMessage: message,
    );
  }

  /// Retorna o tamanho formatado em megabytes amigáveis.
  String get formattedSize {
    if (sizeBytes == null || sizeBytes! <= 0) return 'Tamanho sob consulta';
    final mb = sizeBytes! / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }
}

/// Serviço responsável por verificar e acionar atualizações do aplicativo.
///
/// **Resposta Arquitetural sobre Atualização no iOS / LiveContainer:**
/// No ecossistema iOS (incluindo ambientes de sideloading como LiveContainer, TrollStore e AltStore),
/// o sandbox e a assinatura de código do sistema operacional impedem que um aplicativo substitua
/// seu próprio binário executável em execução.
///
/// Contudo, o aplicativo realiza a verificação proativa via API do GitHub e catálogo `apps.json`:
/// 1. Detecta novas versões lançadas e obtém as notas de lançamento completas.
/// 2. No LiveContainer: aciona o scheme `livecontainer://sources?url=...` ou direciona para
///    a fonte oficial no LiveContainer, permitindo atualização em 1 toque.
/// 3. No Android: efetua download direto do APK `app-arm64-v8a-release.apk` para instalação.
/// 4. Na Web: aciona invalidação de Service Worker e recarregamento instantâneo.
class UpdateCheckerService {
  final http.Client _client;

  UpdateCheckerService({http.Client? client}) : _client = client ?? http.Client();

  /// Verifica se há atualizações disponíveis consultando o GitHub Releases ou fallback apps.json.
  Future<AppUpdateInfo> checkForUpdate({
    String? currentVersion,
    Duration timeout = const Duration(seconds: 8),
    TargetPlatform? platformOverride,
  }) async {
    final cur = currentVersion ?? AppVersion.version;
    final platform = platformOverride ?? defaultTargetPlatform;

    bool githubNetworkError = false;
    String? githubErrorMsg;

    // 1. Tenta consulta ao GitHub Releases API
    try {
      final githubInfo = await _checkGitHubReleases(cur, timeout, platform: platform);
      if (githubInfo != null) return githubInfo;
      githubErrorMsg = 'GitHub Releases retornou resposta sem versão válida';
    } catch (e) {
      githubNetworkError = true;
      githubErrorMsg = e.toString();
      AppLogger.warning('Consulta ao GitHub Releases falhou ($e). Tentando fallback apps.json...');
    }

    // 2. Fallback: consulta ao apps.json no jsDelivr CDN
    bool appsJsonNetworkError = false;
    String? appsJsonErrorMsg;

    try {
      final appsJsonInfo = await _checkAppsJson(cur, timeout, platform: platform);
      if (appsJsonInfo != null) return appsJsonInfo;
      appsJsonErrorMsg = 'apps.json retornou dados inválidos';
    } catch (e) {
      appsJsonNetworkError = true;
      appsJsonErrorMsg = e.toString();
      AppLogger.warning('Consulta ao apps.json falhou: $e');
    }

    // Se ambas as fontes falharam por indisponibilidade de rede/servidor
    if (githubNetworkError && appsJsonNetworkError) {
      return AppUpdateInfo.sourceUnavailable(
        currentVersion: cur,
        message: 'Fontes de atualização indisponíveis. Verifique sua conexão com a internet.',
      );
    }

    final extra = ' (apps.json: $appsJsonErrorMsg)';
    return AppUpdateInfo.checkFailed(
      currentVersion: cur,
      message: 'Não foi possível verificar atualizações: $githubErrorMsg$extra',
    );
  }

  Future<AppUpdateInfo?> _checkGitHubReleases(
    String currentVersion,
    Duration timeout, {
    TargetPlatform? platform,
  }) async {
    final targetPlatform = platform ?? defaultTargetPlatform;
    final uri = Uri.parse(AppVersion.latestReleaseApiUrl);
    final response = await _client.get(
      uri,
      headers: {
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': AppVersion.userAgent,
      },
    ).timeout(timeout);

    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final tagName = data['tag_name'] as String? ?? '';
    final body = data['body'] as String? ?? 'Melhorias de desempenho e estabilidade.';
    final publishedAt = data['published_at'] as String? ?? '';

    // Extrai versão limpa (ex: 'v1.2.0' -> '1.2.0')
    final remoteVersion = _cleanVersion(tagName);
    if (remoteVersion.isEmpty) return null;

    final isNewer = AppVersion.compare(remoteVersion, currentVersion) > 0;

    // Seleção de asset de acordo com a plataforma (Android -> .apk; iOS -> .ipa)
    String downloadUrl;
    int? sizeBytes;
    final assets = data['assets'] as List<dynamic>? ?? [];

    if (targetPlatform == TargetPlatform.android) {
      downloadUrl = 'https://github.com/${AppVersion.githubRepo}/releases/latest/download/app-arm64-v8a-release.apk';
      dynamic selectedApk;
      // Preferência 1: app-arm64-v8a-release.apk
      for (final asset in assets) {
        if (asset is Map<String, dynamic>) {
          final name = (asset['name'] as String? ?? '').toLowerCase();
          if (name.contains('arm64-v8a') && name.endsWith('.apk')) {
            selectedApk = asset;
            break;
          }
        }
      }
      // Preferência 2: app-release.apk ou qualquer .apk
      if (selectedApk == null) {
        for (final asset in assets) {
          if (asset is Map<String, dynamic>) {
            final name = (asset['name'] as String? ?? '').toLowerCase();
            if (name.endsWith('.apk')) {
              selectedApk = asset;
              break;
            }
          }
        }
      }
      // Se nenhum APK específico foi encontrado nos assets, mantém a URL padrão canônica do APK
      if (selectedApk != null) {
        downloadUrl = selectedApk['browser_download_url'] as String? ?? downloadUrl;
        sizeBytes = selectedApk['size'] as int?;
      }
    } else {
      // iOS / iPadOS / macOS: seleciona .ipa
      downloadUrl = AppVersion.latestIpaDownloadUrl;
      dynamic selectedIpa;
      for (final asset in assets) {
        if (asset is Map<String, dynamic>) {
          final name = (asset['name'] as String? ?? '').toLowerCase();
          if (name.endsWith('.ipa')) {
            selectedIpa = asset;
            break;
          }
        }
      }
      // Se nenhum IPA foi encontrado nos assets, mantém a URL padrão canônica do IPA
      if (selectedIpa != null) {
        downloadUrl = selectedIpa['browser_download_url'] as String? ?? downloadUrl;
        sizeBytes = selectedIpa['size'] as int?;
      }
    }

    String releaseDate = AppVersion.releaseDate;
    if (publishedAt.isNotEmpty && publishedAt.length >= 10) {
      releaseDate = publishedAt.substring(0, 10);
    }

    if (isNewer) {
      return AppUpdateInfo.updateAvailable(
        currentVersion: currentVersion,
        latestVersion: remoteVersion,
        releaseDate: releaseDate,
        releaseNotes: body,
        downloadUrl: downloadUrl,
        sourceCatalogUrl: AppVersion.appsJsonUrl,
        sizeBytes: sizeBytes,
      );
    } else {
      return AppUpdateInfo.upToDate(
        currentVersion: currentVersion,
        latestVersion: remoteVersion,
        releaseDate: releaseDate,
        releaseNotes: 'Você já está utilizando a versão mais recente do Ministério Pessoal.',
        downloadUrl: downloadUrl,
      );
    }
  }

  Future<AppUpdateInfo?> _checkAppsJson(
    String currentVersion,
    Duration timeout, {
    TargetPlatform? platform,
  }) async {
    final uri = Uri.parse(AppVersion.appsJsonUrl);
    final response = await _client.get(
      uri,
      headers: {'User-Agent': AppVersion.userAgent},
    ).timeout(timeout);

    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final apps = data['apps'] as List<dynamic>? ?? [];
    if (apps.isEmpty) return null;

    final appData = apps.first as Map<String, dynamic>;
    final remoteVersion = _cleanVersion(appData['version'] as String? ?? '');
    if (remoteVersion.isEmpty) return null;

    final isNewer = AppVersion.compare(remoteVersion, currentVersion) > 0;
    final releaseDate = appData['versionDate'] as String? ?? AppVersion.releaseDate;
    final notes = appData['versionDescription'] as String? ?? 'Atualização disponível.';

    final targetPlatform = platform ?? defaultTargetPlatform;
    String downloadUrl;
    if (targetPlatform == TargetPlatform.android) {
      downloadUrl = appData['downloadURL_apk'] as String? ??
          appData['downloadUrlApk'] as String? ??
          appData['downloadURL'] as String? ??
          'https://github.com/${AppVersion.githubRepo}/releases/latest/download/app-arm64-v8a-release.apk';
    } else {
      downloadUrl = appData['downloadURL'] as String? ?? AppVersion.latestIpaDownloadUrl;
    }
    final sizeBytes = appData['size'] as int?;

    if (isNewer) {
      return AppUpdateInfo.updateAvailable(
        currentVersion: currentVersion,
        latestVersion: remoteVersion,
        releaseDate: releaseDate,
        releaseNotes: notes,
        downloadUrl: downloadUrl,
        sourceCatalogUrl: AppVersion.appsJsonUrl,
        sizeBytes: sizeBytes,
      );
    } else {
      return AppUpdateInfo.upToDate(
        currentVersion: currentVersion,
        latestVersion: remoteVersion,
        releaseDate: releaseDate,
        releaseNotes: notes.isNotEmpty ? notes : 'Você já está utilizando a versão mais recente do Ministério Pessoal.',
        downloadUrl: downloadUrl,
      );
    }
  }

  /// Aciona o fluxo de instalação ou atualização da aplicação de acordo com a plataforma.
  Future<bool> launchUpdate(AppUpdateInfo info, {TargetPlatform? platformOverride}) async {
    final platform = platformOverride ?? defaultTargetPlatform;
    try {
      // 1. No iOS/iPadOS, tenta abrir fonte do LiveContainer via URL scheme customizado
      if (platform == TargetPlatform.iOS) {
        final liveContainerScheme = Uri.parse('livecontainer://sources?url=${Uri.encodeComponent(info.sourceCatalogUrl)}');
        if (await canLaunchUrl(liveContainerScheme)) {
          return await launchUrl(liveContainerScheme, mode: LaunchMode.externalApplication);
        }
      }

      // 2. No Android e fallback iOS: download direto do APK / IPA
      final downloadUri = Uri.parse(info.downloadUrl);
      if (await canLaunchUrl(downloadUri)) {
        return await launchUrl(downloadUri, mode: LaunchMode.externalApplication);
      }

      // 3. Fallback genérico: abre a página do repositório
      final repoUri = Uri.parse('https://github.com/${AppVersion.githubRepo}/releases/latest');
      return await launchUrl(repoUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      AppLogger.error('Erro ao abrir link de atualização: $e');
      return false;
    }
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

/// Provider para injeção e consumo do UpdateCheckerService
final updateCheckerServiceProvider = Provider<UpdateCheckerService>((ref) {
  return UpdateCheckerService();
});

/// Provider de estado que armazena o status da última verificação de atualização
final updateCheckStateProvider =
    AsyncNotifierProvider<UpdateCheckNotifier, AppUpdateInfo?>(
  UpdateCheckNotifier.new,
);

class UpdateCheckNotifier extends AsyncNotifier<AppUpdateInfo?> {
  @override
  FutureOr<AppUpdateInfo?> build() {
    return null;
  }

  Future<AppUpdateInfo> check({bool force = false}) async {
    state = const AsyncValue.loading();
    try {
      final service = ref.read(updateCheckerServiceProvider);
      final info = await service.checkForUpdate();
      state = AsyncValue.data(info);
      return info;
    } catch (err, st) {
      state = AsyncValue.error(err, st);
      rethrow;
    }
  }
}
