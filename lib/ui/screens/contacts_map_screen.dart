import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_logger.dart';
import '../../core/app_theme.dart';
import '../../database/app_database.dart';
import '../../reports/report_export_service.dart';
import '../../territory/geocoding_service.dart';
import '../../territory/geolocation_helper.dart';
import '../../territory/landmark_manager.dart';
import '../../territory/mbtiles/mbtiles_service.dart';
import '../../territory/sector_manager.dart';
import '../../territory/tile_cache/tile_cache_service.dart';
import '../providers.dart';
import '../widgets/managed_text_controllers.dart';
import '../widgets/map_location_picker_dialog.dart';
import '../../contacts/person_hand_off_helper.dart';
import '../../territory/territory_coverage_engine.dart';
import '../../territory/territory_data_port_service.dart';
import '../../reports/web_downloader.dart';
import '../widgets/screen_hero_accent_band.dart';
import 'person_detail_screen.dart';
import 'download_maps_screen.dart';
import '../widgets/map/dynamic_tile_layer.dart';
import '../widgets/map/map_layer_and_engine_sheet.dart';
import '../widgets/map/maplibre_vector_map_view.dart';
import '../../territory/map_engine_adapter.dart';
import '../../territory/map_engine/map_engine_selector.dart';
import '../../territory/map_engine/maplibre_native_adapter.dart';
import '../../territory/geocoding/offline_geocoding_service.dart';
import '../../territory/routing/offline_routing_engine.dart';
import 'contacts_map/offline_search_modal.dart';
import '../widgets/person_deletion_dialog.dart';

part 'contacts_map/territory_modals.dart';
part 'contacts_map/contacts_map_canvas.dart';
part 'contacts_map/contacts_map_list_view.dart';

class ContactsMapScreen extends ConsumerStatefulWidget {
  final String? highlightPersonId;
  final Future<ReverseGeocodingResult?> Function(String)? geocodeAddress;
  final MapEngineAdapter? mapEngineAdapter;
  final MapEnginePreference initialEnginePreference;
  final OfflineRoutingEngine? verifiedRegionalRoutingEngine;

  const ContactsMapScreen({
    super.key,
    this.highlightPersonId,
    this.geocodeAddress,
    this.mapEngineAdapter,
    this.initialEnginePreference = MapEnginePreference.auto,
    this.verifiedRegionalRoutingEngine,
  });

  @override
  ConsumerState<ContactsMapScreen> createState() => _ContactsMapScreenState();
}

class _ContactsMapScreenState extends ConsumerState<ContactsMapScreen>
    with SingleTickerProviderStateMixin {
  void _updateState(VoidCallback fn) => setState(fn);
  final TransformationController _transformationController =
      TransformationController();
  bool _hasAppliedInitialMatrix = false;
  bool _hasScheduledInitialCenter = false;
  double _pendingInitialDx = 0.0;
  double _pendingInitialDy = 0.0;
  int _matrixSyncGeneration = 0;
  bool _hasPendingResizeSync = false;
  double _pendingResizeDeltaViewerW = 0.0;
  double _pendingResizeDeltaViewerH = 0.0;
  double _pendingResizeDeltaOriginPx = 0.0;
  double _pendingResizeDeltaOriginPy = 0.0;
  bool _suppressTileBoundsListener = false;
  String? _highlightPersonId;
  String _selectedStatusFilter =
      'Todos'; // 'Todos', 'Estudos', 'Revisitas', 'Interessados'
  String _selectedDayFilter = 'Todos'; // 'Todos', 'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo'
  String _selectedNeighborhood = 'Todos';
  String _viewMode = 'Mapa Interativo'; // 'Mapa Interativo', 'Lista / Bairros'
  bool _showLandmarks = true;
  PersonEntry? _selectedPinPerson;
  TerritoryLandmark? _selectedPinLandmark;

  final Set<String> _geocodedPersonIds = {};
  bool _hasCenteredHighlightPerson = false;
  bool _geocodeInFlight = false;
  ProviderSubscription<AsyncValue<List<PersonEntry>>>? _peopleSubscription;
  int _zoom = 15;
  double? _activeCenterLng;
  double? _activeCenterLat;
  static const double _tileSize = 256.0;
  DateTime? _lastZoomChangeTime;
  // Rotação manual do mapa via ValueNotifier para evitar rebuild da tela a 60/120fps.
  final ValueNotifier<double> _rotationNotifier = ValueNotifier<double>(0.0);
  late final AnimationController _rotationAnimController;
  Animation<double>? _rotationAnimation;
  final Map<int, Offset> _touchPointers = {};
  double _twoFingerStartAngle = 0.0;
  double _rotationAtTouchStart = 0.0;
  bool _isMouseRotating = false;
  double _mouseRotateStartAngle = 0.0;
  double _rotationAtMouseStart = 0.0;
  ({double latitude, double longitude})? _userGpsLocation; // Localização GPS
  bool _isLocatingUser = false;
  Size? _lastConstraintsSize;
  int? _lastGridHalfSize;
  late MapEngineAdapter _mapEngineAdapter;
  bool _ownsMapEngineAdapter = false;
  late MapEnginePreference _enginePreference;
  String? _activeVectorPackageId;
  OfflineMapFormat _activeVectorPackageFormat = OfflineMapFormat.pmtiles;
  OfflineRoutingEngine? _verifiedRegionalRoutingEngine;

  bool get _hasVerifiedRegionalRoutingGraph =>
      _verifiedRegionalRoutingEngine != null &&
      _verifiedRegionalRoutingEngine!.nodes.isNotEmpty;

  void _configureMapEngine({required bool disposePrevious}) {
    final selection = MapEngineSelector.resolve(
      overrideAdapter: widget.mapEngineAdapter,
      preference: _enginePreference,
    );
    if (disposePrevious && _ownsMapEngineAdapter) {
      _mapEngineAdapter.dispose();
    }
    _mapEngineAdapter = selection.adapter;
    _ownsMapEngineAdapter = selection.ownsAdapter;
    _activeVectorPackageId = selection.activePackageId;
    _activeVectorPackageFormat = selection.activePackageFormat;

    _mapEngineAdapter.initialize().then((_) {
      if (mounted) {
        _mapEngineAdapter.moveCamera(
          MapViewportState(
            latitude: _activeCenterLat ?? GeolocationHelper.defaultLat,
            longitude: _activeCenterLng ?? GeolocationHelper.defaultLng,
            zoom: _zoom.toDouble(),
            bearingDegrees: _rotationNotifier.value * (180.0 / math.pi),
          ),
        );
      }
    });
  }

  void _handleTilesRevisionChanged() {
    if (!mounted) return;
    final currentPkg = MBTilesService.instance.primaryVectorPackage;
    final pkgChanged =
        currentPkg?.id != _activeVectorPackageId ||
        (currentPkg?.format ?? OfflineMapFormat.pmtiles) !=
            _activeVectorPackageFormat;
    final needsVectorSwitch =
        widget.mapEngineAdapter == null &&
        _enginePreference == MapEnginePreference.auto &&
        MapLibreVectorMapView.isSupportedOnCurrentPlatform &&
        ((currentPkg != null && _mapEngineAdapter is! MaplibreNativeAdapter) ||
            (currentPkg == null && _mapEngineAdapter is MaplibreNativeAdapter));
    if (pkgChanged || needsVectorSwitch) {
      setState(() {
        _configureMapEngine(disposePrevious: true);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _verifiedRegionalRoutingEngine = widget.verifiedRegionalRoutingEngine;
    _enginePreference = widget.initialEnginePreference;
    _configureMapEngine(disposePrevious: false);
    MBTilesService.instance.tilesRevision.addListener(
      _handleTilesRevisionChanged,
    );
    _rotationAnimController =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 350),
          )
          ..addListener(() {
            if (_rotationAnimation != null) {
              _rotationNotifier.value = _rotationAnimation!.value;
            }
          })
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              _rotationNotifier.value = 0.0;
            }
          });
    _highlightPersonId = widget.highlightPersonId;
    MBTilesService.instance
        .init()
        .then((_) => _handleTilesRevisionChanged())
        .catchError((Object e, StackTrace st) {
          AppLogger.warning(
            'Falha ao inicializar pacotes offline .mbtiles no mapa',
            e,
            st,
          );
        });
    _peopleSubscription = ref.listenManual<AsyncValue<List<PersonEntry>>>(
      peopleStreamProvider,
      (_, next) {
        next.whenData(_syncHighlightSideEffects);
      },
      fireImmediately: true,
    );
  }

  @override
  void didUpdateWidget(covariant ContactsMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.verifiedRegionalRoutingEngine !=
        widget.verifiedRegionalRoutingEngine) {
      _verifiedRegionalRoutingEngine = widget.verifiedRegionalRoutingEngine;
    }
    if (oldWidget.highlightPersonId != widget.highlightPersonId) {
      _highlightPersonId = widget.highlightPersonId;
      _hasCenteredHighlightPerson = false;
      final current = ref.read(peopleStreamProvider).value;
      if (current != null) {
        _syncHighlightSideEffects(current);
      }
    }
  }

  void _syncHighlightSideEffects(List<PersonEntry> contacts) {
    final targetId = _highlightPersonId;
    if (targetId == null || !mounted) return;
    PersonEntry? highlightPerson;
    for (final c in contacts) {
      if (c.id == targetId) {
        highlightPerson = c;
        break;
      }
    }
    if (highlightPerson == null) return;

    final hasCoords =
        highlightPerson.latitude != null &&
        highlightPerson.longitude != null &&
        (highlightPerson.latitude != 0.0 || highlightPerson.longitude != 0.0) &&
        highlightPerson.latitude!.abs() <= 90 &&
        highlightPerson.longitude!.abs() <= 180;

    if (hasCoords && _selectedPinPerson == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _selectedPinPerson != null) return;
        setState(() {
          _selectedPinPerson = highlightPerson;
        });
      });
      return;
    }

    if (!hasCoords &&
        !_geocodeInFlight &&
        highlightPerson.address != null &&
        highlightPerson.address!.trim().isNotEmpty &&
        !_geocodedPersonIds.contains(highlightPerson.id)) {
      _geocodedPersonIds.add(highlightPerson.id);
      _geocodeInFlight = true;
      final personToGeocode = highlightPerson;
      Future.delayed(const Duration(milliseconds: 250), () async {
        try {
          if (!mounted) return;
          final res = widget.geocodeAddress != null
              ? await widget.geocodeAddress!(personToGeocode.address!)
              : await GeocodingService.geocodeAddress(
                  personToGeocode.address!,
                  db: ref.read(databaseProvider),
                );
          if (res == null || !mounted) return;
          final review = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Localização aproximada'),
              content: const Text(
                'A busca por endereço pode apontar para o lugar errado. Revise e selecione o ponto no mapa antes de salvar.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Agora não'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Revisar no mapa'),
                ),
              ],
            ),
          );
          if (review != true || !mounted) return;
          final selected = await showDialog<ReverseGeocodingResult>(
            context: context,
            builder: (_) => MapLocationPickerDialog(
              initialLat: res.latitude,
              initialLng: res.longitude,
              initialAddress: personToGeocode.address,
            ),
          );
          if (selected != null && mounted) {
            await ref
                .read(repositoryProvider)
                .applyGeocodedCoordinates(
                  personId: personToGeocode.id,
                  expectedAddress: personToGeocode.address!,
                  latitude: selected.latitude,
                  longitude: selected.longitude,
                );
          }
        } catch (e, st) {
          AppLogger.warning(
            'Não foi possível salvar a localização obtida pelo endereço.',
            e,
            st,
          );
        } finally {
          _geocodeInFlight = false;
        }
      });
    }
  }

  int _lon2tileX(double lon, int z) =>
      ((lon + 180.0) / 360.0 * (1 << z)).floor();

  int _lat2tileY(double lat, int z) {
    final latRad = lat.clamp(-85.0511, 85.0511) * math.pi / 180.0;
    return ((1.0 -
                math.log(math.tan(latRad) + 1.0 / math.cos(latRad)) / math.pi) /
            2.0 *
            (1 << z))
        .floor();
  }

  double _lon2pixelX(double lon, int z) =>
      (lon + 180.0) / 360.0 * (_tileSize * (1 << z));

  double _lat2pixelY(double lat, int z) {
    final latRad = lat.clamp(-85.0511, 85.0511) * math.pi / 180.0;
    final sinLat = math.sin(latRad).clamp(-0.9999, 0.9999);
    return (0.5 - math.log((1.0 + sinLat) / (1.0 - sinLat)) / (4.0 * math.pi)) *
        (_tileSize * (1 << z));
  }

  double _pixelX2lon(double px, int z) =>
      (px / (_tileSize * (1 << z))) * 360.0 - 180.0;

  double _pixelY2lat(double py, int z) {
    final n = math.pi - (2.0 * math.pi * py) / (_tileSize * (1 << z));
    return 180.0 / math.pi * math.atan(0.5 * (math.exp(n) - math.exp(-n)));
  }

  ({
    double viewportW,
    double viewportH,
    double viewerW,
    double viewerH,
    int gridHalfSize,
  })
  _computeMapMetrics(double rawWidth, double rawHeight) {
    final viewportW = rawWidth > 0 ? rawWidth : 400.0;
    final viewportH = rawHeight > 0 ? rawHeight : 600.0;
    final rotExtent = math
        .sqrt(viewportW * viewportW + viewportH * viewportH)
        .ceilToDouble();
    final minTilesFromCenter = (rotExtent / (2.0 * 0.6 * _tileSize)).ceil();
    // Folga ampla no canvas lógico (zero tiles adicionais montados, pois
    // _DynamicTileLayer só monta os tiles visíveis + anel de borda) para garantir
    // que mesmo sob rotação máxima e telas largas não ocorram cortes pretos diagonais.
    final gridHalfSize = math.max(16, minTilesFromCenter + 12);
    return (
      viewportW: viewportW,
      viewportH: viewportH,
      viewerW: rotExtent,
      viewerH: rotExtent,
      gridHalfSize: gridHalfSize,
    );
  }

  Matrix4 _applyPendingResizeTo(Matrix4 base) {
    if (!_hasPendingResizeSync) return base;
    final s = base.getMaxScaleOnAxis();
    final effScale = s > 0.01 ? s : 1.0;
    final nextDx =
        base.storage[12] +
        _pendingResizeDeltaViewerW +
        _pendingResizeDeltaOriginPx * effScale;
    final nextDy =
        base.storage[13] +
        _pendingResizeDeltaViewerH +
        _pendingResizeDeltaOriginPy * effScale;
    return Matrix4.identity()
      ..translateByDouble(nextDx, nextDy, 0, 1)
      ..scaleByDouble(effScale, effScale, 1, 1);
  }

  void _cancelPendingResizeSync() {
    _matrixSyncGeneration++;
    _hasPendingResizeSync = false;
    _pendingResizeDeltaViewerW = 0.0;
    _pendingResizeDeltaViewerH = 0.0;
    _pendingResizeDeltaOriginPx = 0.0;
    _pendingResizeDeltaOriginPy = 0.0;
  }

  void _setMatrixWithRebuildPending(Matrix4 next) {
    _suppressTileBoundsListener = true;
    try {
      _transformationController.value = next;
    } finally {
      _suppressTileBoundsListener = false;
    }
  }

  void _changeZoom(
    int newZoom,
    BoxConstraints constraints,
    double originPx,
    double originPy, {
    double? viewerW,
    double? viewerH,
    int? gridHalfSize,
  }) {
    final targetZoom = newZoom.clamp(6, 19);
    if (targetZoom == _zoom) return;

    final currentMatrix = _applyPendingResizeTo(
      _transformationController.value,
    );
    final currentScale = currentMatrix.getMaxScaleOnAxis();
    final effectiveScale = currentScale > 0.01 ? currentScale : 1.0;
    final dx = currentMatrix.storage[12];
    final dy = currentMatrix.storage[13];

    final metrics = _computeMapMetrics(
      constraints.maxWidth,
      constraints.maxHeight,
    );
    final vW = viewerW ?? metrics.viewerW;
    final vH = viewerH ?? metrics.viewerH;
    final gHalf = gridHalfSize ?? metrics.gridHalfSize;

    // Ponto geográfico central atualmente visualizado (compensando a escala do InteractiveViewer)
    final canvasCenterX = ((vW / 2.0) - dx) / effectiveScale;
    final canvasCenterY = ((vH / 2.0) - dy) / effectiveScale;
    final worldPx = originPx + canvasCenterX;
    final worldPy = originPy + canvasCenterY;
    final focalLng = _pixelX2lon(worldPx, _zoom).clamp(-179.999999, 179.999999);
    final focalLat = _pixelY2lat(worldPy, _zoom).clamp(-85.0511, 85.0511);

    // Reprojeção para novo nível de resolução 'z' centrando exatamente no ponto focal
    final newCenterTileX = _lon2tileX(focalLng, targetZoom);
    final newCenterTileY = _lat2tileY(focalLat, targetZoom);
    final newMinTileX = newCenterTileX - gHalf;
    final newMinTileY = newCenterTileY - gHalf;
    final newOriginPx = newMinTileX * _tileSize;
    final newOriginPy = newMinTileY * _tileSize;

    final newWorldPx = _lon2pixelX(focalLng, targetZoom);
    final newWorldPy = _lat2pixelY(focalLat, targetZoom);

    final newCanvasX = newWorldPx - newOriginPx;
    final newCanvasY = newWorldPy - newOriginPy;

    final newDx = (vW / 2.0) - newCanvasX;
    final newDy = (vH / 2.0) - newCanvasY;

    _hasAppliedInitialMatrix = true;
    _cancelPendingResizeSync();
    setState(() {
      _activeCenterLng = focalLng;
      _activeCenterLat = focalLat;
      _zoom = targetZoom;
    });

    _setMatrixWithRebuildPending(Matrix4.translationValues(newDx, newDy, 0.0));
  }

  @override
  void dispose() {
    MBTilesService.instance.tilesRevision.removeListener(
      _handleTilesRevisionChanged,
    );
    _peopleSubscription?.close();
    _transformationController.dispose();
    _rotationAnimController.dispose();
    _rotationNotifier.dispose();
    if (_ownsMapEngineAdapter) {
      _mapEngineAdapter.dispose();
    }
    super.dispose();
  }

  void _animateResetRotationToNorth() {
    final current = _rotationNotifier.value;
    if (current.abs() < 1e-4) {
      if (current != 0.0) {
        _rotationNotifier.value = 0.0;
      }
      return;
    }
    _rotationAnimController.stop();

    // Normaliza a rotação inicial no intervalo (-pi, pi]
    var start = current % (2 * math.pi);
    if (start > math.pi) start -= 2 * math.pi;
    if (start < -math.pi) start += 2 * math.pi;

    _rotationNotifier.value = start;
    _rotationAnimation = Tween<double>(begin: start, end: 0.0).animate(
      CurvedAnimation(
        parent: _rotationAnimController,
        curve: Curves.easeOutCubic,
      ),
    );

    _rotationAnimController.forward(from: 0.0);
  }

  void _rotateBy(double deltaRadians) {
    _rotationAnimController.stop();
    _rotationNotifier.value =
        (_rotationNotifier.value + deltaRadians) % (2 * math.pi);
  }

  double _calculateDistanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const p = 0.017453292519943295; // pi / 180
    final a =
        0.5 -
        math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) *
            math.cos(lat2 * p) *
            (1 - math.cos((lon2 - lon1) * p)) /
            2;
    return 12742 * math.asin(math.sqrt(a));
  }

  void _centerOnCoords(
    double lat,
    double lng,
    double viewportWidth,
    double viewportHeight, {
    double? viewerW,
    double? viewerH,
    int? gridHalfSize,
  }) {
    final metrics = _computeMapMetrics(viewportWidth, viewportHeight);
    final vW = viewerW ?? metrics.viewerW;
    final vH = viewerH ?? metrics.viewerH;
    final gHalf = gridHalfSize ?? metrics.gridHalfSize;

    final newCenterTileX = _lon2tileX(lng, _zoom);
    final newCenterTileY = _lat2tileY(lat, _zoom);
    final newOriginPx = (newCenterTileX - gHalf) * _tileSize;
    final newOriginPy = (newCenterTileY - gHalf) * _tileSize;
    final targetPx = _lon2pixelX(lng, _zoom) - newOriginPx;
    final targetPy = _lat2pixelY(lat, _zoom) - newOriginPy;

    _hasAppliedInitialMatrix = true;
    _cancelPendingResizeSync();
    setState(() {
      _activeCenterLat = lat;
      _activeCenterLng = lng;
    });
    if (vW > 0 && vH > 0) {
      final dx = (vW / 2.0) - targetPx;
      final dy = (vH / 2.0) - targetPy;
      _setMatrixWithRebuildPending(Matrix4.translationValues(dx, dy, 0.0));
    }
  }

  Future<void> _openSingleRoute(
    dynamic target, [
    double? destLat,
    double? destLon,
  ]) async {
    double? lat = destLat;
    double? lon = destLon;
    String name = '';
    if (target is PersonEntry) {
      lat = target.latitude;
      lon = target.longitude;
      name = target.address ?? target.name;
    } else if (target is String) {
      name = target;
    }
    final query = (lat != null && lon != null && (lat != 0.0 || lon != 0.0))
        ? '$lat,$lon'
        : Uri.encodeComponent(name);
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$query',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openLandmarkRoute(TerritoryLandmark landmark) async {
    final query =
        (landmark.latitude != null &&
            landmark.longitude != null &&
            landmark.latitude != 0.0)
        ? '${landmark.latitude},${landmark.longitude}'
        : Uri.encodeComponent(landmark.address ?? landmark.name);
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$query',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openMultiContactRoute(List<PersonEntry> contacts) async {
    final validContacts = contacts
        .where(
          (c) =>
              (c.address != null && c.address!.trim().isNotEmpty) ||
              (c.latitude != null &&
                  c.longitude != null &&
                  (c.latitude != 0.0 || c.longitude != 0.0)),
        )
        .toList();
    if (validContacts.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Nenhum contato com endereço cadastrado para traçar rota.',
            ),
          ),
        );
      }
      return;
    }

    if (validContacts.length == 1) {
      await _openSingleRoute(validContacts.first);
      return;
    }

    // Filtra pontos distantes (> 60km) calculados em relação à mediana do agrupamento do território
    final validLats = <double>[];
    final validLngs = <double>[];
    for (final c in validContacts) {
      if (c.latitude != null &&
          c.longitude != null &&
          (c.latitude != 0.0 || c.longitude != 0.0) &&
          c.latitude!.abs() <= 90 &&
          c.longitude!.abs() <= 180) {
        validLats.add(c.latitude!);
        validLngs.add(c.longitude!);
      }
    }

    final nearbyContacts = <PersonEntry>[];
    if (validLats.isNotEmpty) {
      validLats.sort();
      validLngs.sort();
      final medianLat = validLats[validLats.length ~/ 2];
      final medianLng = validLngs[validLngs.length ~/ 2];

      for (final c in validContacts) {
        if (c.latitude != null &&
            c.longitude != null &&
            (c.latitude != 0.0 || c.longitude != 0.0)) {
          final dist = _calculateDistanceKm(
            medianLat,
            medianLng,
            c.latitude!,
            c.longitude!,
          );
          if (dist <= 60.0) {
            nearbyContacts.add(c);
          }
        } else {
          nearbyContacts.add(c);
        }
      }
    } else {
      nearbyContacts.addAll(validContacts);
    }

    if (nearbyContacts.isEmpty) nearbyContacts.addAll(validContacts);

    if (nearbyContacts.length == 1) {
      await _openSingleRoute(nearbyContacts.first);
      return;
    }

    if (nearbyContacts.length < validContacts.length && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Rota traçada apenas para os ${nearbyContacts.length} contatos próximos do território.',
          ),
        ),
      );
    }

    final effectiveContacts = nearbyContacts.length > 10
        ? nearbyContacts.take(10).toList()
        : nearbyContacts;
    if (nearbyContacts.length > 10 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Enviando os primeiros 10 contatos de ${nearbyContacts.length} ao Google Maps; a ordem não foi otimizada.',
          ),
        ),
      );
    }

    final dest = effectiveContacts.last;
    final destQuery =
        (dest.latitude != null &&
            dest.longitude != null &&
            (dest.latitude != 0.0 || dest.longitude != 0.0))
        ? '${dest.latitude},${dest.longitude}'
        : Uri.encodeComponent(dest.address ?? dest.name);

    final waypointsList = effectiveContacts
        .sublist(0, effectiveContacts.length - 1)
        .map((c) {
          return (c.latitude != null &&
                  c.longitude != null &&
                  (c.latitude != 0.0 || c.longitude != 0.0))
              ? '${c.latitude},${c.longitude}'
              : Uri.encodeComponent(c.address ?? c.name);
        })
        .where((w) => w.isNotEmpty)
        .toList();

    final waypointsParam = waypointsList.isNotEmpty
        ? '&waypoints=${waypointsList.join("|")}'
        : '';
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$destQuery$waypointsParam',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // Abre o Google Maps padrão com a visualização do mapa/localizações (NÃO rota de carro)
  Future<void> _openStandardGoogleMaps(
    List<PersonEntry> contacts, [
    List<TerritoryLandmark>? landmarks,
  ]) async {
    final validLats = <double>[];
    final validLngs = <double>[];

    for (final c in contacts) {
      if (c.latitude != null &&
          c.longitude != null &&
          (c.latitude != 0.0 || c.longitude != 0.0) &&
          c.latitude!.abs() <= 90 &&
          c.longitude!.abs() <= 180) {
        validLats.add(c.latitude!);
        validLngs.add(c.longitude!);
      }
    }
    if (landmarks != null) {
      for (final l in landmarks) {
        if (l.latitude != null &&
            l.longitude != null &&
            (l.latitude != 0.0 || l.longitude != 0.0) &&
            l.latitude!.abs() <= 90 &&
            l.longitude!.abs() <= 180) {
          validLats.add(l.latitude!);
          validLngs.add(l.longitude!);
        }
      }
    }

    if (validLats.isNotEmpty) {
      validLats.sort();
      validLngs.sort();
      final medianLat = validLats[validLats.length ~/ 2];
      final medianLng = validLngs[validLngs.length ~/ 2];

      // Abre o Google Maps visualizando o ponto central do território
      final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$medianLat,$medianLng',
      );
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    for (final c in contacts) {
      if (c.address != null && c.address!.trim().isNotEmpty) {
        final query = Uri.encodeComponent(c.address!);
        final uri = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=$query',
        );
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
      }
    }

    final defaultUri = Uri.parse('https://www.google.com/maps');
    if (await canLaunchUrl(defaultUri)) {
      await launchUrl(defaultUri, mode: LaunchMode.externalApplication);
    }
  }

  String _extractNeighborhood(String? address) {
    if (address == null || address.trim().isEmpty) return 'Sem Bairro Definido';
    final parts = address.split(RegExp(r'[-–,]'));
    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.toLowerCase().startsWith('bairro') ||
          trimmed.toLowerCase().startsWith('jd') ||
          trimmed.toLowerCase().startsWith('jardim') ||
          trimmed.toLowerCase().startsWith('centro')) {
        return trimmed;
      }
    }
    if (parts.length >= 2) {
      final candidate = parts[1].trim();
      if (candidate.isNotEmpty && !RegExp(r'^\d+$').hasMatch(candidate)) {
        return candidate;
      }
    }
    return 'Geral';
  }

  void _centerMapOnCoordinates(double lat, double lng) {
    setState(() {
      _activeCenterLat = lat;
      _activeCenterLng = lng;
    });
    try {
      _mapEngineAdapter.moveCamera(
        MapViewportState(latitude: lat, longitude: lng, zoom: _zoom.toDouble()),
      );
    } catch (_) {}
  }

  void _showOfflineSearchModal(BuildContext context) {
    OfflineSearchModal.show(
      context,
      db: ref.read(databaseProvider),
      onSelectResult: (result) {
        if (result.hasCoordinates) {
          _centerMapOnCoordinates(result.latitude!, result.longitude!);
        }
        if (result.type == LocalResultType.contact) {
          final contacts = ref.read(peopleStreamProvider).value ?? [];
          for (final c in contacts) {
            if (c.id == result.id) {
              setState(() {
                _selectedPinPerson = c;
              });
              break;
            }
          }
        } else if (result.type == LocalResultType.landmark) {
          final landmarks = ref.read(landmarksStreamProvider).value ?? [];
          for (final lm in landmarks) {
            if (lm.id == result.id) {
              setState(() {
                _selectedPinLandmark = lm;
              });
              break;
            }
          }
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Localizado: ${result.title}'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
    );
  }

  void _showOfflineRouteDialog({
    required String destinationName,
    required double destLat,
    required double destLon,
  }) {
    final supportsOfflineRouting =
        _mapEngineAdapter.capabilities.supportsOfflineRouting;
    final hasVerifiedGraph = _hasVerifiedRegionalRoutingGraph;

    if (!supportsOfflineRouting || !hasVerifiedGraph) {
      showDialog(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.alt_route, color: AppTheme.primaryTeal),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Roteamento Offline',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'O roteamento offline não está disponível para esta região. '
                'Nenhum grafo viário regional verificado foi carregado neste dispositivo.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              Text(
                'Destino: $destinationName',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Coordenadas: ${destLat.toStringAsFixed(4)}, ${destLon.toStringAsFixed(4)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              const Text(
                'Deseja abrir o trajeto no aplicativo de mapas externo?',
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Fechar'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Abrir no Mapa Externo'),
              onPressed: () {
                Navigator.pop(dialogCtx);
                _openSingleRoute(destinationName, destLat, destLon);
              },
            ),
          ],
        ),
      );
      return;
    }

    final engine = _verifiedRegionalRoutingEngine!;
    final originLat = _activeCenterLat ?? -3.1022;
    final originLon = _activeCenterLng ?? -67.9397;

    final walkRoute = engine.findRouteBetweenCoordinates(
      startLat: originLat,
      startLon: originLon,
      goalLat: destLat,
      goalLon: destLon,
      mode: RoutingMode.walking,
    );

    final driveRoute = engine.findRouteBetweenCoordinates(
      startLat: originLat,
      startLon: originLon,
      goalLat: destLat,
      goalLon: destLon,
      mode: RoutingMode.driving,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.alt_route, color: AppTheme.primaryTeal),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Rota Offline (A*): $destinationName',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (walkRoute.isSuccess) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.directions_walk,
                    color: AppTheme.primaryTeal,
                  ),
                  title: const Text('A pé (1.25 m/s)'),
                  subtitle: Text(walkRoute.formattedSummary),
                ),
              ],
              if (driveRoute.isSuccess) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.directions_car, color: Colors.blue),
                  title: const Text('Carro / Moto'),
                  subtitle: Text(driveRoute.formattedSummary),
                ),
              ],
              if (!walkRoute.isSuccess && !driveRoute.isSuccess)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    walkRoute.errorMessage ??
                        'Não foi possível encontrar rota offline segura.',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              if (walkRoute.isSuccess || driveRoute.isSuccess) ...[
                const Divider(),
                const Text(
                  'Etapas do trajeto offline:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                ...((walkRoute.isSuccess ? walkRoute.steps : driveRoute.steps).map(
                  (step) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          step.isFerryCrossing
                              ? Icons.directions_boat
                              : Icons.turn_right,
                          size: 16,
                          color: step.isFerryCrossing
                              ? Colors.blue
                              : Colors.grey,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${step.instruction} (${step.distanceMeters.round()} m)',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Abrir no Mapa Externo'),
            onPressed: () {
              Navigator.pop(context);
              _openSingleRoute(destinationName, destLat, destLon);
            },
          ),
        ],
      ),
    );
  }

  void _showMapLayerStylesModal(BuildContext context) {
    showMapLayerAndEngineSheet(
      context: context,
      currentPreference: _enginePreference,
      activeEngineName: _mapEngineAdapter.engineName,
      activeVectorPackageId: _activeVectorPackageId,
      isEngineOverridden: widget.mapEngineAdapter != null,
      onPreferenceChanged: (pref) {
        if (!mounted || pref == _enginePreference) return;
        setState(() {
          _enginePreference = pref;
          _configureMapEngine(disposePrevious: true);
        });
      },
      onLayerStyleChanged: (style) {
        TileCacheService.instance.setLayerStyle(style);
        if (mounted) setState(() {});
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final peopleAsync = ref.watch(peopleStreamProvider);
    final landmarks = ref.watch(landmarksStreamProvider).value ?? [];
    final studies = ref.watch(studiesStreamProvider).value ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFullscreen = ref.watch(isMapFullscreenProvider);

    return Scaffold(
      appBar: isFullscreen
          ? null
          : AppBar(
              title: Semantics(
                header: true,
                child: const FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Mapa dos Contatos e Território')),
              ),
              bottom: ScreenHeroAccentBand.territory(),
              actions: [
                Semantics(
                  button: true,
                  label: 'Baixar e gerenciar mapas offline',
                  child: IconButton(
                    icon: const Icon(Icons.download_for_offline),
                    tooltip: 'Baixar Mapas Offline',
                    onPressed: () => DownloadMapsScreen.show(context),
                  ),
                ),
                Semantics(
                  button: true,
                  label: 'Buscar contatos, marcos e setores offline',
                  child: IconButton(
                    icon: const Icon(Icons.search),
                    tooltip: 'Buscar no Território (Offline)',
                    onPressed: () => _showOfflineSearchModal(context),
                  ),
                ),
                Semantics(
                  button: true,
                  selected: _viewMode == 'Mapa Interativo',
                  label: 'Alternar para modo Mapa Interativo',
                  child: IconButton(
                    icon: const Icon(Icons.map_outlined),
                    tooltip: 'Ver Mapa Interativo',
                    onPressed: () {
                      setState(() {
                        _viewMode = 'Mapa Interativo';
                      });
                    },
                  ),
                ),
                Semantics(
                  button: true,
                  selected: _viewMode == 'Lista / Bairros',
                  label: 'Alternar para modo Lista por Bairros',
                  child: IconButton(
                    icon: const Icon(Icons.view_agenda_outlined),
                    tooltip: 'Ver em Lista / Bairros',
                    onPressed: () {
                      setState(() {
                        _viewMode = 'Lista / Bairros';
                      });
                    },
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Mais Opções do Mapa',
                  constraints: const BoxConstraints(
                    minWidth: 280,
                    maxWidth: 380,
                  ),
                  onSelected: (val) {
                    final people = peopleAsync.value ?? [];
                    if (val == 'pdf') {
                      final sectors =
                          ref.read(sectorsStreamProvider).value ?? [];
                      ReportExportService.exportContactsMapPdf(
                        context: context,
                        people: people,
                        landmarks: landmarks,
                        sectors: sectors,
                      );
                    } else if (val == 'offline') {
                      DownloadMapsScreen.show(context);
                    } else if (val == 'google_maps') {
                      _openStandardGoogleMaps(people, landmarks);
                    } else if (val == 'landmark') {
                      _showAddLandmarkModal(context);
                    } else if (val == 'coverage') {
                      _showCoverageAnalysisModal(context, people);
                    } else if (val == 'duplicates') {
                      _showDuplicateAnalysisModal(context, people);
                    } else if (val == 'import') {
                      _showImportTerritoryDialog(context);
                    } else if (val == 'kml') {
                      _exportKml(context, people);
                    } else if (val == 'geojson') {
                      _exportGeoJson(context, people);
                    } else if (val == 'csv') {
                      _exportCsv(context, people);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'coverage',
                      child: Row(
                        children: [
                          Icon(
                            Icons.analytics_outlined,
                            size: 18,
                            color: AppTheme.primaryBlue,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Índice de Cobertura (IC) & Zonas',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'duplicates',
                      child: Row(
                        children: [
                          Icon(
                            Icons.compare_arrows,
                            size: 18,
                            color: Color(0xFFD97706),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Detectar Duplicidades (<25m)',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'import',
                      child: Row(
                        children: [
                          Icon(
                            Icons.file_upload_outlined,
                            size: 18,
                            color: Color(0xFF0D9488),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Importar Território (KML/GeoJSON/CSV)',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'kml',
                      child: Row(
                        children: [
                          Icon(
                            Icons.share_location,
                            size: 18,
                            color: Color(0xFF16A34A),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Exportar KML (Google Earth)',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'geojson',
                      child: Row(
                        children: [
                          Icon(
                            Icons.data_object,
                            size: 18,
                            color: Color(0xFF7C3AED),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Exportar GeoJSON Padrão',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'csv',
                      child: Row(
                        children: [
                          Icon(
                            Icons.table_chart_outlined,
                            size: 18,
                            color: Color(0xFF0284C7),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Exportar Planilha (CSV)',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'pdf',
                      child: Row(
                        children: [
                          Icon(Icons.picture_as_pdf, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Exportar Mapa Geral (PDF)',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'offline',
                      child: Row(
                        children: [
                          Icon(Icons.download_for_offline_outlined, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Baixar Mapa Offline',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'google_maps',
                      child: Row(
                        children: [
                          Icon(Icons.public, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Abrir no Google Maps',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'landmark',
                      child: Row(
                        children: [
                          Icon(Icons.add_location_alt_outlined, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '+ Ponto de Referência',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton:
          (_selectedPinPerson == null && _selectedPinLandmark == null)
          ? FloatingActionButton.extended(
              heroTag: 'fab_add_landmark',
              backgroundColor: AppTheme.accentTeal,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_location),
              label: const Text('+ Ponto de Referência'),
              onPressed: () => _showAddLandmarkModal(context),
            )
          : null,
      body: peopleAsync.when(
        data: (people) {
          final neighborhoods = <String>{'Todos'};
          for (final p in people) {
            if (p.address != null && p.address!.isNotEmpty) {
              neighborhoods.add(_extractNeighborhood(p.address));
            }
          }

          final filtered = people.where((p) {
            // Se for o contato em destaque vindo do perfil individual, nunca exclui por filtros
            if (_highlightPersonId != null && p.id == _highlightPersonId) {
              return true;
            }

            final hasLoc =
                (p.address != null && p.address!.trim().isNotEmpty) ||
                (p.latitude != null && p.longitude != null);
            if (!hasLoc) return false;

            if (_selectedStatusFilter == 'Todos') {
              if (p.status == 'revisita_encerrada' || p.status == 'encerrado') {
                return false;
              }
            } else if (_selectedStatusFilter == 'Estudos' &&
                p.status != 'estudo') {
              return false;
            } else if (_selectedStatusFilter == 'Revisitas' &&
                p.status != 'revisita') {
              return false;
            } else if (_selectedStatusFilter == 'Interessados' &&
                p.status != 'interessado') {
              return false;
            } else if (_selectedStatusFilter == 'Estrangeiros') {
              final tags = p.tags.toLowerCase();
              final notes = (p.generalNotes ?? '').toLowerCase();
              final isForeign =
                  tags.contains('estrangeiro') ||
                  notes.contains('idioma') ||
                  notes.contains('língua') ||
                  notes.contains('estrangeir') ||
                  notes.contains('inglês') ||
                  notes.contains('espanhol') ||
                  notes.contains('francês') ||
                  notes.contains('chinês') ||
                  notes.contains('coreano') ||
                  notes.contains('crioulo') ||
                  notes.contains('árabe');
              if (!isForeign) return false;
            } else if (_selectedStatusFilter == 'Encerrados' &&
                !(p.status == 'revisita_encerrada' ||
                    p.status == 'encerrado' ||
                    p.status == 'concluido')) {
              return false;
            }

            if (_selectedNeighborhood != 'Todos') {
              final b = _extractNeighborhood(p.address);
              if (b != _selectedNeighborhood) return false;
            }

            if (_selectedDayFilter != 'Todos') {
              final sched = (p.preferredSchedule ?? '').toLowerCase();
              final dayNorm = _selectedDayFilter.toLowerCase();
              if (!sched.contains(dayNorm.substring(0, 3))) return false;
            }

            return true;
          }).toList();

          return Column(
            children: [
              // Barra de filtros superior
              Container(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Column(
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final status in [
                            'Todos',
                            'Estudos',
                            'Revisitas',
                            'Interessados',
                            'Estrangeiros',
                            'Encerrados',
                          ])
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(status),
                                selected: _selectedStatusFilter == status,
                                onSelected: (sel) {
                                  if (sel) {
                                    setState(
                                      () => _selectedStatusFilter = status,
                                    );
                                  }
                                },
                                selectedColor: AppTheme.primaryBlue.withValues(
                                  alpha: 0.15,
                                ),
                              ),
                            ),
                          const VerticalDivider(width: 12),
                          DropdownButton<String>(
                            value: _selectedDayFilter,
                            underline: const SizedBox.shrink(),
                            hint: const Text('Dia da Visita'),
                            items:
                                [
                                  'Todos',
                                  'Segunda',
                                  'Terça',
                                  'Quarta',
                                  'Quinta',
                                  'Sexta',
                                  'Sábado',
                                  'Domingo',
                                ].map((d) {
                                  return DropdownMenuItem(
                                    value: d,
                                    child: Text(
                                      d == 'Todos' ? 'Qualquer Dia' : d,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  );
                                }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedDayFilter = val);
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          if (neighborhoods.length > 2)
                            DropdownButton<String>(
                              value:
                                  neighborhoods.contains(_selectedNeighborhood)
                                  ? _selectedNeighborhood
                                  : 'Todos',
                              underline: const SizedBox.shrink(),
                              items: neighborhoods.map((b) {
                                return DropdownMenuItem(
                                  value: b,
                                  child: Text(
                                    b == 'Todos' ? 'Todos os Bairros' : b,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedNeighborhood = val);
                                }
                              },
                            ),
                          const SizedBox(width: 8),
                          FilterChip(
                            avatar: Icon(
                              Icons.place,
                              size: 16,
                              color: _showLandmarks
                                  ? Colors.white
                                  : AppTheme.accentTeal,
                            ),
                            label: Text('Pontos Ref. (${landmarks.length})'),
                            selected: _showLandmarks,
                            onSelected: (val) =>
                                setState(() => _showLandmarks = val),
                            selectedColor: AppTheme.accentTeal,
                            labelStyle: TextStyle(
                              color: _showLandmarks ? Colors.white : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${filtered.length} contatos • ${landmarks.length} marcos de referência',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? const Color(0xFFCBD5E1)
                                  : AppTheme.textMuted,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    minimumSize: const Size(36, 36),
                                  ),
                                  icon: const Icon(Icons.public, size: 16),
                                  label: const Text(
                                    'Mapa Padrão',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  onPressed: () => _openStandardGoogleMaps(
                                    filtered,
                                    landmarks,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                if (filtered.isNotEmpty)
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.accentTeal,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      minimumSize: const Size(36, 36),
                                    ),
                                    icon: const Icon(
                                      Icons.directions,
                                      size: 16,
                                    ),
                                    label: const Text(
                                      'Traçar Rota',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    onPressed: () =>
                                        _openMultiContactRoute(filtered),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Corpo da Tela: Mapa Interativo Visual OU Lista por Bairros
              Expanded(
                child: _viewMode == 'Mapa Interativo'
                    ? _buildInteractiveVisualMap(filtered, landmarks)
                    : filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.location_off_outlined,
                                size: 56,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Nenhum contato com endereço cadastrado coincide com os filtros selecionados.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isDark
                                      ? const Color(0xFFCBD5E1)
                                      : AppTheme.textMuted,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.filter_alt_off),
                                label: const Text('Limpar Filtros'),
                                onPressed: () {
                                  setState(() {
                                    _selectedStatusFilter = 'Todos';
                                    _selectedDayFilter = 'Todos';
                                    _selectedNeighborhood = 'Todos';
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      )
                    : _buildGroupedNeighborhoodList(filtered, studies),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) =>
            Center(child: Text('Erro ao carregar contatos: $err')),
      ),
    );
  }
}

typedef _DynamicTileLayer = DynamicTileLayer;
