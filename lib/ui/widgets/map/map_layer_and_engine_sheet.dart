import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../territory/map_engine/map_engine_selector.dart';
import '../../../territory/tile_cache/tile_cache_service.dart';
import 'maplibre_vector_map_view.dart';

/// Bottom sheet desacoplado para seleção de motor cartográfico (MapLibre Native
/// vetorial Nível 2 vs Raster clássico) e estilos de camada do mapa.
Future<void> showMapLayerAndEngineSheet({
  required BuildContext context,
  required MapEnginePreference currentPreference,
  required String activeEngineName,
  required String? activeVectorPackageId,
  required bool isEngineOverridden,
  required ValueChanged<MapEnginePreference> onPreferenceChanged,
  required ValueChanged<MapLayerStyle> onLayerStyleChanged,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final supportsNative = MapLibreVectorMapView.isSupportedOnCurrentPlatform;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      final currentStyle = TileCacheService.instance.activeStyle;
      return SafeArea(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Semantics(
                    header: true,
                    child: const Text(
                      'Camadas e Motor do Mapa',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Fechar opções de camadas do mapa',
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.layers_rounded,
                          size: 18,
                          color: AppTheme.primaryBlue,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Motor ativo: $activeEngineName',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      activeVectorPackageId != null
                          ? 'Pacote vetorial offline detectado: $activeVectorPackageId'
                          : (supportsNative
                                ? 'Importe um pacote .pmtiles ou .mbtiles vetorial em Mapas Offline para ativar automaticamente o MapLibre Native.'
                                : 'Plataforma desktop utiliza fallback Raster seguro (MapLibre Native ativo em iOS, Android e Web).'),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    if (!isEngineOverridden && supportsNative) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final pref in MapEnginePreference.values)
                            Semantics(
                              button: true,
                              selected: currentPreference == pref,
                              label: 'Modo de motor do mapa: ${pref.label}',
                              child: ChoiceChip(
                                label: Text(
                                  pref.label,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                selected: currentPreference == pref,
                                onSelected: (_) {
                                  Navigator.pop(ctx);
                                  onPreferenceChanged(pref);
                                },
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Semantics(
                header: true,
                child: const Text(
                  'Estilo Visual (Modo Raster / Cache)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 6),
              for (final style in MapLayerStyle.values)
                Semantics(
                  button: true,
                  selected: currentStyle == style,
                  label: 'Estilo de mapa ${style.label}: ${style.description}',
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: currentStyle == style
                            ? AppTheme.accentTeal.withValues(alpha: 0.15)
                            : (isDark
                                  ? Colors.white10
                                  : Colors.black.withValues(alpha: 0.05)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        style.icon,
                        color: currentStyle == style
                            ? AppTheme.accentTeal
                            : null,
                      ),
                    ),
                    title: Text(
                      style.label,
                      style: TextStyle(
                        fontWeight: currentStyle == style
                            ? FontWeight.bold
                            : FontWeight.w600,
                        color: currentStyle == style
                            ? AppTheme.accentTeal
                            : null,
                      ),
                    ),
                    subtitle: Text(
                      style.description,
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: currentStyle == style
                        ? const Icon(
                            Icons.check_circle,
                            color: AppTheme.accentTeal,
                          )
                        : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      onLayerStyleChanged(style);
                    },
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}
