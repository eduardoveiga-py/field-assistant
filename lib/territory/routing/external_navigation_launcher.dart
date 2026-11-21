import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_logger.dart';

/// Aplicativos suportados para navegação externa.
enum ExternalNavigationApp {
  organicMaps('Organic Maps', 'Navegação 100% offline'),
  appleMaps('Apple Maps', 'Mapas nativos do iOS/macOS'),
  googleMaps('Google Maps', 'Navegação online');

  final String displayName;
  final String description;
  const ExternalNavigationApp(this.displayName, this.description);
}

/// Helper centralizado para navegação externa com 1 toque (FA-MAP-03).
///
/// Oferece integração direta com Organic Maps (padrão recomendado para uso offline
/// sem internet no campo), Apple Maps (iOS/macOS) e Google Maps (fallback universal).
class ExternalNavigationLauncher {
  /// Constrói a URI para o Organic Maps (om://).
  ///
  /// Caso haja coordenadas de origem (GPS atual), utiliza o esquema de rota veicular:
  /// `om://route?sll=$originLat,$originLng&dll=$lat,$lng&dname=${Uri.encodeComponent(label)}&type=vehicle`
  ///
  /// Caso contrário, utiliza o esquema de visualização de ponto no mapa:
  /// `om://map?v=1&ll=$lat,$lng&n=${Uri.encodeComponent(label)}`
  static Uri buildOrganicMapsUri({
    required double lat,
    required double lng,
    required String label,
    double? originLat,
    double? originLng,
  }) {
    final encodedLabel = Uri.encodeComponent(label);
    if (originLat != null && originLng != null) {
      return Uri.parse(
        'om://route?sll=$originLat,$originLng&dll=$lat,$lng&dname=$encodedLabel&type=vehicle',
      );
    }
    return Uri.parse('om://map?v=1&ll=$lat,$lng&n=$encodedLabel');
  }

  /// Constrói a URI para o Apple Maps (https://maps.apple.com/).
  static Uri buildAppleMapsUri({
    required double lat,
    required double lng,
    required String label,
  }) {
    final encodedLabel = Uri.encodeComponent(label);
    return Uri.parse('https://maps.apple.com/?daddr=$lat,$lng&q=$encodedLabel');
  }

  /// Constrói a URI universal para o Google Maps (https://www.google.com/maps/dir/).
  static Uri buildGoogleMapsUri({
    required double lat,
    required double lng,
    double? originLat,
    double? originLng,
  }) {
    if (originLat != null && originLng != null) {
      return Uri.parse(
        'https://www.google.com/maps/dir/?api=1&origin=$originLat,$originLng&destination=$lat,$lng',
      );
    }
    return Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );
  }

  /// Lança a navegação externa para o app selecionado, com verificação via [canLaunchUrl]
  /// e fallback seguro para Google Maps caso o app escolhido não esteja instalado.
  ///
  /// Retorna `true` se o app selecionado foi aberto com sucesso, ou `false` se foi
  /// necessário executar o fallback para Google Maps (ou se ambos falharam).
  static Future<bool> launchNavigation({
    required ExternalNavigationApp app,
    required double lat,
    required double lng,
    required String label,
    double? originLat,
    double? originLng,
    LaunchMode launchMode = LaunchMode.externalApplication,
    Future<bool> Function(Uri url)? canLaunchChecker,
    Future<bool> Function(Uri url, {LaunchMode mode})? urlLauncher,
  }) async {
    final canLaunch = canLaunchChecker ?? canLaunchUrl;
    final launcher =
        urlLauncher ??
        ((url, {mode = LaunchMode.externalApplication}) =>
            launchUrl(url, mode: mode));

    Uri targetUri;
    switch (app) {
      case ExternalNavigationApp.organicMaps:
        targetUri = buildOrganicMapsUri(
          lat: lat,
          lng: lng,
          label: label,
          originLat: originLat,
          originLng: originLng,
        );
        break;
      case ExternalNavigationApp.appleMaps:
        targetUri = buildAppleMapsUri(lat: lat, lng: lng, label: label);
        break;
      case ExternalNavigationApp.googleMaps:
        targetUri = buildGoogleMapsUri(
          lat: lat,
          lng: lng,
          originLat: originLat,
          originLng: originLng,
        );
        break;
    }

    try {
      final isSupported = await canLaunch(targetUri);
      if (isSupported) {
        final success = await launcher(targetUri, mode: launchMode);
        if (success) return true;
      }
    } catch (e, st) {
      AppLogger.warning(
        'Falha ao abrir rota em ${app.displayName}: $targetUri',
        e,
        st,
      );
    }

    // Fallback gracioso para Google Maps caso o app específico não esteja instalado
    if (app != ExternalNavigationApp.googleMaps) {
      AppLogger.info(
        'App de navegação ${app.displayName} indisponível. Executando fallback seguro para Google Maps.',
      );
      final fallbackUri = buildGoogleMapsUri(
        lat: lat,
        lng: lng,
        originLat: originLat,
        originLng: originLng,
      );
      try {
        if (await canLaunch(fallbackUri)) {
          await launcher(fallbackUri, mode: launchMode);
        }
      } catch (e, st) {
        AppLogger.warning(
          'Falha no fallback de navegação para Google Maps: $fallbackUri',
          e,
          st,
        );
      }
      return false;
    }

    return false;
  }

  /// Exibe ModalBottomSheet com opções de navegação externa com 1 toque.
  static Future<void> showNavigationSheet(
    BuildContext context, {
    required double lat,
    required double lng,
    required String label,
    double? originLat,
    double? originLng,
  }) async {
    final isApplePlatform = !kIsWeb && (Platform.isIOS || Platform.isMacOS);

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: theme.dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'Navegar até "$label"',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Escolha o aplicativo de mapas preferido:',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  key: const Key('nav_opt_organic_maps'),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE8F5E9),
                    child: Icon(Icons.navigation, color: Color(0xFF2E7D32)),
                  ),
                  title: const Text(
                    'Organic Maps',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    '100% offline, sem rastreamento (Recomendado)',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    final openedDirectly = await launchNavigation(
                      app: ExternalNavigationApp.organicMaps,
                      lat: lat,
                      lng: lng,
                      label: label,
                      originLat: originLat,
                      originLng: originLng,
                    );
                    if (!openedDirectly && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Organic Maps não instalado. Abrindo no Google Maps...',
                          ),
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
                  },
                ),
                if (isApplePlatform)
                  ListTile(
                    key: const Key('nav_opt_apple_maps'),
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFF5F5F5),
                      child: Icon(Icons.map, color: Colors.black87),
                    ),
                    title: const Text(
                      'Apple Maps',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text('Nativo do iOS e macOS'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await launchNavigation(
                        app: ExternalNavigationApp.appleMaps,
                        lat: lat,
                        lng: lng,
                        label: label,
                        originLat: originLat,
                        originLng: originLng,
                      );
                    },
                  ),
                ListTile(
                  key: const Key('nav_opt_google_maps'),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE3F2FD),
                    child: Icon(Icons.directions, color: Color(0xFF1565C0)),
                  ),
                  title: const Text(
                    'Google Maps',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('Navegação e trânsito online'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await launchNavigation(
                      app: ExternalNavigationApp.googleMaps,
                      lat: lat,
                      lng: lng,
                      label: label,
                      originLat: originLat,
                      originLng: originLng,
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}
