import 'dart:async';
import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../theme/app_theme.dart';
import '../../territory/geolocation_helper.dart';
import '../../services/nominatim_reverse_geocoding_service.dart';

enum _PickerLayerMode { street, satellite, dark }

/// Modal interativo para seleção precisa de coordenadas geográficas via mapa.
/// - Coordenada padrão em Santo Antônio do Içá, AM (-3.1022, -67.9397).
/// - Zoom via roda do mouse ou botões (+/-) trava 100% no pino selecionado sem deslocar o mapa.
/// - Barra de busca integrada priorizando Santo Antônio do Içá, AM.
/// - Alternador de camadas (Ruas OSM / Satélite Esri / Modo Escuro).
class MapLocationPickerDialog extends StatefulWidget {
  final double initialLat;
  final double initialLng;
  final String? initialAddress;
  final String? initialNeighborhood;

  const MapLocationPickerDialog({
    super.key,
    required this.initialLat,
    required this.initialLng,
    this.initialAddress,
    this.initialNeighborhood,
  });

  /// Método utilitário para exibir o diálogo de forma padronizada
  static Future<ReverseGeocodingResult?> show(
    BuildContext context, {
    required double initialLat,
    required double initialLng,
    String? initialAddress,
    String? initialNeighborhood,
  }) {
    return showDialog<ReverseGeocodingResult>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => MapLocationPickerDialog(
        initialLat: initialLat,
        initialLng: initialLng,
        initialAddress: initialAddress,
        initialNeighborhood: initialNeighborhood,
      ),
    );
  }

  @override
  State<MapLocationPickerDialog> createState() =>
      _MapLocationPickerDialogState();
}

class _MapLocationPickerDialogState extends State<MapLocationPickerDialog> {
  final MapController _mapController = MapController();
  late final TextEditingController _searchController;
  late double _selectedLat;
  late double _selectedLng;
  double _currentZoom = 16.0;

  bool _isLoadingAddress = false;
  bool _isSearching = false;
  String _statusText = 'Carregando endereço...';
  ReverseGeocodingResult? _geocodedResult;
  _PickerLayerMode _layerMode = _PickerLayerMode.street;

  Timer? _debounceTimer;

  static bool _isLegacyManausOrZero(double lat, double lng) {
    if (lat.abs() < 0.001 && lng.abs() < 0.001) return true;
    // Detecta coordenada antiga padrão de Manaus (-3.1190, -60.0217)
    if ((lat - (-3.1190)).abs() < 0.03 && (lng - (-60.0217)).abs() < 0.03) {
      return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    final initialQuery = [
      if (widget.initialAddress != null &&
          widget.initialAddress!.trim().isNotEmpty)
        widget.initialAddress!.trim(),
      if (widget.initialNeighborhood != null &&
          widget.initialNeighborhood!.trim().isNotEmpty)
        widget.initialNeighborhood!.trim(),
    ].join(', ');
    _searchController = TextEditingController(text: initialQuery);

    if (_isLegacyManausOrZero(widget.initialLat, widget.initialLng)) {
      _selectedLat = GeolocationHelper.defaultLat;
      _selectedLng = GeolocationHelper.defaultLng;
    } else {
      _selectedLat = widget.initialLat;
      _selectedLng = widget.initialLng;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isLegacyManausOrZero(widget.initialLat, widget.initialLng) &&
          initialQuery.isNotEmpty) {
        _searchAddress(initialQuery);
      } else {
        _performReverseGeocoding(_selectedLat, _selectedLng);
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onPositionChanged(MapCamera position, bool hasGesture) {
    // Atualiza o pino apenas quando o usuario arrasta o mapa (pan),
    // nunca permitindo que o zoom tire o foco da coordenada selecionada!
    if (hasGesture) {
      setState(() {
        _selectedLat = position.center.latitude;
        _selectedLng = position.center.longitude;
        _currentZoom = position.zoom;
      });

      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 650), () {
        _performReverseGeocoding(_selectedLat, _selectedLng);
      });
    } else {
      setState(() {
        _currentZoom = position.zoom;
      });
    }
  }

  /// Aplica zoom mantendo o foco 100% cravado em (_selectedLat, _selectedLng)
  void _zoomKeepingFocus(double delta) {
    final targetZoom = (_currentZoom + delta).clamp(4.0, 19.0);
    final fixedCenter = LatLng(_selectedLat, _selectedLng);
    setState(() {
      _currentZoom = targetZoom;
    });
    _mapController.move(fixedCenter, targetZoom);
  }

  Future<Map<String, dynamic>?> _queryNominatim(String q) async {
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/search?format=json&addressdetails=1&q=${Uri.encodeComponent(q)}&limit=1',
    );
    final resp = await http
        .get(
          uri,
          headers: const {
            'User-Agent': 'com.fieldassistant.app/1.0',
            'Accept-Language': 'pt-BR,pt;q=0.9',
          },
        )
        .timeout(const Duration(seconds: 8));
    if (resp.statusCode == 200) {
      final list = jsonDecode(resp.body) as List<dynamic>;
      if (list.isNotEmpty) {
        return list.first as Map<String, dynamic>;
      }
    }
    return null;
  }

  Future<void> _searchAddress(String rawQuery) async {
    final q = rawQuery.trim();
    if (q.isEmpty) return;
    setState(() => _isSearching = true);
    try {
      final lower = q.toLowerCase();
      Map<String, dynamic>? match;
      if (!lower.contains('santo ant') &&
          !lower.contains('amazonas') &&
          !lower.contains(', am')) {
        match = await _queryNominatim(
          '$q, Santo Antônio do Içá, Amazonas, Brasil',
        );
        match ??= await _queryNominatim('$q, Amazonas, Brasil');
      }
      match ??= await _queryNominatim(q);

      if (match != null && mounted) {
        final lat = double.tryParse(match['lat']?.toString() ?? '');
        final lon = double.tryParse(match['lon']?.toString() ?? '');
        if (lat != null && lon != null) {
          setState(() {
            _selectedLat = lat;
            _selectedLng = lon;
            _currentZoom = 17.0;
          });
          _mapController.move(LatLng(lat, lon), 17.0);
          await _performReverseGeocoding(lat, lon);
        }
      }
    } catch (_) {
      // Mantém posição atual caso offline
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _performReverseGeocoding(double lat, double lng) async {
    if (!mounted) return;
    setState(() {
      _isLoadingAddress = true;
    });

    try {
      final result = await NominatimReverseGeocodingService.fetchAddress(
        lat,
        lng,
      );
      if (!mounted) return;
      setState(() {
        _geocodedResult = result;
        _isLoadingAddress = false;
        if (result != null && result.formattedAddress.isNotEmpty) {
          _statusText = result.formattedAddress;
        } else {
          _statusText = 'Coordenada marcada em Santo Antônio do Içá, AM';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingAddress = false;
        _statusText = 'Coordenada marcada manualmente no mapa';
      });
    }
  }

  Future<void> _centerOnDeviceLocation() async {
    final pos = await GeolocationHelper.getCurrentLocation();
    final targetLat = pos?.latitude ?? GeolocationHelper.defaultLat;
    final targetLng = pos?.longitude ?? GeolocationHelper.defaultLng;
    if (mounted) {
      final newCenter = LatLng(targetLat, targetLng);
      setState(() {
        _selectedLat = targetLat;
        _selectedLng = targetLng;
        _currentZoom = 16.0;
      });
      _mapController.move(newCenter, 16.0);
      _performReverseGeocoding(targetLat, targetLng);
    }
  }

  void _cycleLayer() {
    setState(() {
      switch (_layerMode) {
        case _PickerLayerMode.street:
          _layerMode = _PickerLayerMode.satellite;
          break;
        case _PickerLayerMode.satellite:
          _layerMode = _PickerLayerMode.dark;
          break;
        case _PickerLayerMode.dark:
          _layerMode = _PickerLayerMode.street;
          break;
      }
    });
  }

  String _getLayerUrl() {
    switch (_layerMode) {
      case _PickerLayerMode.street:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
      case _PickerLayerMode.satellite:
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
      case _PickerLayerMode.dark:
        return 'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png';
    }
  }

  String _getLayerLabel() {
    switch (_layerMode) {
      case _PickerLayerMode.street:
        return 'Ruas';
      case _PickerLayerMode.satellite:
        return 'Satélite';
      case _PickerLayerMode.dark:
        return 'Escuro';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 660,
          height: 660,
          child: Column(
            children: [
              // Cabeçalho + Busca
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.map, color: AppTheme.primaryColor),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Selecionar Localização (Santo Antônio do Içá, AM)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                          tooltip: 'Fechar',
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Buscar rua ou bairro em Santo Antônio do Içá, AM...',
                        isDense: true,
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF0F172A)
                            : Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        suffixIcon: _isSearching
                            ? const Padding(
                                padding: EdgeInsets.all(10),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : IconButton(
                                icon: const Icon(Icons.search),
                                tooltip: 'Buscar endereço',
                                onPressed: () =>
                                    _searchAddress(_searchController.text),
                              ),
                      ),
                      onSubmitted: _searchAddress,
                    ),
                  ],
                ),
              ),

              // Área do Mapa com Zoom Cravado no Pino Central
              Expanded(
                child: Stack(
                  children: [
                    Listener(
                      onPointerSignal: (pointerSignal) {
                        if (pointerSignal is PointerScrollEvent) {
                          final delta = pointerSignal.scrollDelta.dy < 0
                              ? 1.0
                              : -1.0;
                          _zoomKeepingFocus(delta);
                        }
                      },
                      child: FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: LatLng(_selectedLat, _selectedLng),
                          initialZoom: _currentZoom,
                          minZoom: 4.0,
                          maxZoom: 19.0,
                          interactionOptions: const InteractionOptions(
                            // Desativa scrollWheelZoom nativo que deslocava o centro para o cursor
                            flags:
                                InteractiveFlag.drag |
                                InteractiveFlag.pinchZoom |
                                InteractiveFlag.doubleTapZoom,
                          ),
                          onPositionChanged: _onPositionChanged,
                          onTap: (tapPos, point) {
                            setState(() {
                              _selectedLat = point.latitude;
                              _selectedLng = point.longitude;
                            });
                            _mapController.move(point, _currentZoom);
                            _performReverseGeocoding(
                              point.latitude,
                              point.longitude,
                            );
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: _getLayerUrl(),
                            userAgentPackageName: 'com.fieldassistant.app',
                          ),
                        ],
                      ),
                    ),

                    // Marcador Central Fixo
                    const IgnorePointer(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.only(bottom: 36),
                          child: Icon(
                            Icons.location_on,
                            size: 44,
                            color: AppTheme.alertRed,
                          ),
                        ),
                      ),
                    ),

                    // Indicador de Camada e Zoom
                    Positioned(
                      left: 12,
                      top: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_getLayerLabel()} • Zoom ${_currentZoom.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    // Botões de Camada, Zoom (+/-) e GPS
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FloatingActionButton.small(
                            heroTag: 'btnLayerPicker',
                            onPressed: _cycleLayer,
                            tooltip:
                                'Alternar Camada (${_getLayerLabel()}): Ruas / Satélite / Escuro',
                            child: const Icon(Icons.layers_outlined),
                          ),
                          const SizedBox(height: 8),
                          FloatingActionButton.small(
                            heroTag: 'btnZoomInPicker',
                            onPressed: () => _zoomKeepingFocus(1.0),
                            tooltip: 'Aproximar Zoom (+)',
                            child: const Icon(Icons.add),
                          ),
                          const SizedBox(height: 6),
                          FloatingActionButton.small(
                            heroTag: 'btnZoomOutPicker',
                            onPressed: () => _zoomKeepingFocus(-1.0),
                            tooltip: 'Afastar Zoom (-)',
                            child: const Icon(Icons.remove),
                          ),
                          const SizedBox(height: 8),
                          FloatingActionButton.small(
                            heroTag: 'btnGPSPicker',
                            onPressed: _centerOnDeviceLocation,
                            tooltip: 'Minha Localização Atual',
                            child: const Icon(Icons.my_location),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Painel Inferior com Endereço e Confirmação
              Container(
                padding: const EdgeInsets.all(14),
                color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        if (_isLoadingAddress)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          const Icon(
                            Icons.place,
                            size: 18,
                            color: AppTheme.alertRed,
                          ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _statusText,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Coordenadas: ${_selectedLat.toStringAsFixed(6)}, ${_selectedLng.toStringAsFixed(6)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text('Confirmar Este Ponto'),
                          onPressed: () {
                            final finalResult =
                                _geocodedResult ??
                                ReverseGeocodingResult(
                                  latitude: _selectedLat,
                                  longitude: _selectedLng,
                                  street: widget.initialAddress,
                                  neighborhood: widget.initialNeighborhood,
                                );
                            Navigator.pop(context, finalResult);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
