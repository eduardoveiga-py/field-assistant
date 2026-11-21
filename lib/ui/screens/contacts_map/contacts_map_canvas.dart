part of '../contacts_map_screen.dart';

extension _ContactsMapCanvas on _ContactsMapScreenState {
  Widget _buildMetricScaleBar(
    double effectiveScale,
    double latitude,
    int zoom,
  ) {
    final latRad = latitude.clamp(-85.0, 85.0) * math.pi / 180.0;
    final scale = effectiveScale > 0.01 ? effectiveScale : 1.0;
    final metersPerPixel =
        (156543.03392 * math.cos(latRad) / math.pow(2, zoom)) / scale;

    const thresholds = [
      10,
      20,
      50,
      100,
      200,
      500,
      1000,
      2000,
      5000,
      10000,
      20000,
      50000,
    ];
    int selectedMeters = 200;
    for (final t in thresholds) {
      final px = t / metersPerPixel;
      if (px >= 40 && px <= 130) {
        selectedMeters = t;
        break;
      }
    }
    final barWidth = (selectedMeters / metersPerPixel).clamp(40.0, 140.0);
    final label = selectedMeters >= 1000
        ? '${selectedMeters ~/ 1000} km'
        : '$selectedMeters m';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Container(
            width: barWidth,
            height: 3,
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(color: Colors.white, width: 2),
                right: BorderSide(color: Colors.white, width: 2),
                bottom: BorderSide(color: Colors.white, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Visualizador geográfico com mapa real OpenStreetMap (tiles raster com cache offline) e zoom interativo
  Widget _buildInteractiveVisualMap(
    List<PersonEntry> contacts,
    List<TerritoryLandmark> landmarks,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final visits = ref.watch(visitsStreamProvider).value ?? [];
    final allAppointments = ref.watch(appointmentsStreamProvider).value ?? [];
    final allSectors = ref.watch(sectorsStreamProvider).value ?? [];

    final Map<String, DateTime> lastVisitMap = {};
    for (final v in visits) {
      if (v.deletedAt != null) continue;
      final existing = lastVisitMap[v.personId];
      if (existing == null || v.dateTimeField.isAfter(existing)) {
        lastVisitMap[v.personId] = v.dateTimeField;
      }
    }

    final Map<String, DateTime> nextApptMap = {};
    final nowTime = DateTime.now();
    for (final a in allAppointments) {
      if (a.deletedAt != null ||
          a.status == 'cancelado' ||
          a.personId == null) {
        continue;
      }
      if (a.startTime.isAfter(nowTime)) {
        final existing = nextApptMap[a.personId!];
        if (existing == null || a.startTime.isBefore(existing)) {
          nextApptMap[a.personId!] = a.startTime;
        }
      }
    }

    final geoContacts = contacts
        .where(
          (c) =>
              c.latitude != null &&
              c.longitude != null &&
              (c.latitude != 0.0 || c.longitude != 0.0) &&
              c.latitude!.abs() <= 90 &&
              c.longitude!.abs() <= 180,
        )
        .toList();
    final geoLandmarks = _showLandmarks
        ? landmarks
              .where(
                (l) =>
                    l.latitude != null &&
                    l.longitude != null &&
                    (l.latitude != 0.0 || l.longitude != 0.0) &&
                    l.latitude!.abs() <= 90 &&
                    l.longitude!.abs() <= 180,
              )
              .toList()
        : <TerritoryLandmark>[];

    PersonEntry? highlightPerson;
    if (_highlightPersonId != null) {
      for (final c in contacts) {
        if (c.id == _highlightPersonId) {
          highlightPerson = c;
          break;
        }
      }
    }

    final hasHighlightCoords =
        highlightPerson != null &&
        highlightPerson.latitude != null &&
        highlightPerson.longitude != null &&
        (highlightPerson.latitude != 0.0 || highlightPerson.longitude != 0.0) &&
        highlightPerson.latitude!.abs() <= 90 &&
        highlightPerson.longitude!.abs() <= 180;

    double centerLat = GeolocationHelper.defaultLat;
    double centerLng = GeolocationHelper.defaultLng;
    if (hasHighlightCoords) {
      // Centraliza no endereço específico da pessoa destacada (sem mutar estado durante build - A6)
      centerLat = highlightPerson.latitude!;
      centerLng = highlightPerson.longitude!;
    }

    final effectiveCenterLat = _activeCenterLat ?? centerLat;
    final effectiveCenterLng = _activeCenterLng ?? centerLng;

    final centerTileX = _lon2tileX(effectiveCenterLng, _zoom);
    final centerTileY = _lat2tileY(effectiveCenterLat, _zoom);

    // Ordena para que o pino destacado seja renderizado por último (no topo de pinos próximos)
    final orderedContacts = List<PersonEntry>.from(geoContacts);
    if (_highlightPersonId != null) {
      orderedContacts.sort((a, b) {
        if (a.id == _highlightPersonId) return 1;
        if (b.id == _highlightPersonId) return -1;
        return 0;
      });
    }

    final Map<String, TerritoryPinLayer> pinLayers = {
      for (final p in orderedContacts)
        p.id: TerritoryCoverageEngine.classifyPin(
          p,
          hasActiveStudy: p.status.toLowerCase() == 'estudo',
          lastVisitDate: lastVisitMap[p.id],
          nextAppointmentDate: nextApptMap[p.id],
        ),
    };
    final isFullscreen = ref.watch(isMapFullscreenProvider);
    final activeLayerStyle = TileCacheService.instance.activeStyle;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= 0 || constraints.maxHeight <= 0) {
          return const SizedBox.shrink();
        }

        final metrics = _computeMapMetrics(
          constraints.maxWidth,
          constraints.maxHeight,
        );
        final viewportW = metrics.viewportW;
        final viewportH = metrics.viewportH;
        final viewerW = metrics.viewerW;
        final viewerH = metrics.viewerH;
        final gridHalfSize = metrics.gridHalfSize;

        final minTileX = centerTileX - gridHalfSize;
        final maxTileX = centerTileX + gridHalfSize;
        final minTileY = centerTileY - gridHalfSize;
        final maxTileY = centerTileY + gridHalfSize;

        final originPx = minTileX * _ContactsMapScreenState._tileSize;
        final originPy = minTileY * _ContactsMapScreenState._tileSize;

        final canvasWidth =
            (gridHalfSize * 2 + 1) * _ContactsMapScreenState._tileSize;
        final canvasHeight =
            (gridHalfSize * 2 + 1) * _ContactsMapScreenState._tileSize;

        final centerPx = _lon2pixelX(centerLng, _zoom) - originPx;
        final centerPy = _lat2pixelY(centerLat, _zoom) - originPy;

        Matrix4? frameMatrixOverride;
        if (!_hasAppliedInitialMatrix) {
          _lastConstraintsSize = constraints.biggest;
          _lastGridHalfSize = gridHalfSize;
          if (hasHighlightCoords) _hasCenteredHighlightPerson = true;
          final dx = (viewerW / 2.0) - centerPx;
          final dy = (viewerH / 2.0) - centerPy;
          _pendingInitialDx = dx;
          _pendingInitialDy = dy;
          frameMatrixOverride = Matrix4.translationValues(dx, dy, 0.0);
          if (!_hasScheduledInitialCenter) {
            _hasScheduledInitialCenter = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _hasScheduledInitialCenter = false;
              if (!mounted || _hasAppliedInitialMatrix) return;
              _hasAppliedInitialMatrix = true;
              _transformationController.value = Matrix4.translationValues(
                _pendingInitialDx,
                _pendingInitialDy,
                0.0,
              );
            });
          }
        } else if (hasHighlightCoords && !_hasCenteredHighlightPerson) {
          _hasCenteredHighlightPerson = true;
          _lastConstraintsSize = constraints.biggest;
          _lastGridHalfSize = gridHalfSize;
          _cancelPendingResizeSync();
          final dx = (viewerW / 2.0) - centerPx;
          final dy = (viewerH / 2.0) - centerPy;
          frameMatrixOverride = Matrix4.translationValues(dx, dy, 0.0);
          final scheduledGen = _matrixSyncGeneration;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && scheduledGen == _matrixSyncGeneration) {
              _centerOnCoords(
                centerLat,
                centerLng,
                viewportW,
                viewportH,
                viewerW: viewerW,
                viewerH: viewerH,
                gridHalfSize: gridHalfSize,
              );
            }
          });
        } else if (_lastConstraintsSize != null &&
            _lastConstraintsSize != constraints.biggest) {
          final oldSize = _lastConstraintsSize!;
          final oldMetrics = _computeMapMetrics(oldSize.width, oldSize.height);
          final oldGridHalf = _lastGridHalfSize ?? oldMetrics.gridHalfSize;
          final deltaViewerW = (viewerW - oldMetrics.viewerW) / 2.0;
          final deltaViewerH = (viewerH - oldMetrics.viewerH) / 2.0;
          final deltaOriginPx =
              (oldGridHalf - gridHalfSize) * _ContactsMapScreenState._tileSize;
          final deltaOriginPy =
              (oldGridHalf - gridHalfSize) * _ContactsMapScreenState._tileSize;
          _lastConstraintsSize = constraints.biggest;
          _lastGridHalfSize = gridHalfSize;

          _pendingResizeDeltaViewerW += deltaViewerW;
          _pendingResizeDeltaViewerH += deltaViewerH;
          _pendingResizeDeltaOriginPx += deltaOriginPx;
          _pendingResizeDeltaOriginPy += deltaOriginPy;

          if (!_hasPendingResizeSync) {
            _hasPendingResizeSync = true;
            final scheduledGen = ++_matrixSyncGeneration;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted ||
                  !_hasPendingResizeSync ||
                  scheduledGen != _matrixSyncGeneration) {
                return;
              }
              final next = _applyPendingResizeTo(
                _transformationController.value,
              );
              _cancelPendingResizeSync();
              _transformationController.value = next;
            });
          }
          frameMatrixOverride = _applyPendingResizeTo(
            _transformationController.value,
          );
        } else if (_hasPendingResizeSync) {
          frameMatrixOverride = _applyPendingResizeTo(
            _transformationController.value,
          );
        }

        return Stack(
          children: [
            if (_mapEngineAdapter is MaplibreNativeAdapter &&
                MapLibreVectorMapView.isSupportedOnCurrentPlatform &&
                _activeVectorPackageId != null)
              Positioned.fill(
                child: MapLibreVectorMapView(
                  adapter: _mapEngineAdapter as MaplibreNativeAdapter,
                  initialLat: effectiveCenterLat,
                  initialLng: effectiveCenterLng,
                  initialZoom: _zoom.toDouble(),
                  initialBearing: _rotationNotifier.value * (180.0 / math.pi),
                  isDarkMode: isDark,
                  packageId: _activeVectorPackageId,
                  packageFormat: _activeVectorPackageFormat,
                  contacts: [
                    for (final p in orderedContacts)
                      if (p.latitude != null && p.longitude != null)
                        {
                          'id': p.id,
                          'name': p.name,
                          'latitude': p.latitude,
                          'longitude': p.longitude,
                          'status': p.status,
                          'notes': p.generalNotes ?? '',
                        },
                  ],
                  landmarks: _showLandmarks
                      ? [
                          for (final lm in geoLandmarks)
                            {
                              'id': lm.id,
                              'title': lm.name,
                              'latitude': lm.latitude,
                              'longitude': lm.longitude,
                              'category': lm.category,
                            },
                        ]
                      : const [],
                  sectors: MapEngineSelector.buildSectorOverlayMaps(
                    sectors: allSectors,
                    contacts: orderedContacts,
                  ),
                  onCameraChanged: (vp) {
                    _activeCenterLat = vp.latitude;
                    _activeCenterLng = vp.longitude;
                    _rotationNotifier.value =
                        vp.bearingDegrees * (math.pi / 180.0);
                  },
                  onContactTapped: (contactId) {
                    for (final p in orderedContacts) {
                      if (p.id == contactId) {
                        _updateState(() {
                          _selectedPinPerson = p;
                          _selectedPinLandmark = null;
                        });
                        break;
                      }
                    }
                  },
                  onLandmarkTapped: (landmarkId) {
                    for (final lm in geoLandmarks) {
                      if (lm.id == landmarkId) {
                        _updateState(() {
                          _selectedPinLandmark = lm;
                          _selectedPinPerson = null;
                        });
                        break;
                      }
                    }
                  },
                ),
              )
            else
              RepaintBoundary(
                child: ClipRect(
                  child: Listener(
                    behavior: HitTestBehavior.translucent,
                    onPointerSignal: (pointerSignal) {
                      if (pointerSignal is PointerScrollEvent) {
                        final now = clock.now();
                        if (_lastZoomChangeTime == null ||
                            now
                                    .difference(_lastZoomChangeTime!)
                                    .inMilliseconds >=
                                250) {
                          if (pointerSignal.scrollDelta.dy < -2 && _zoom < 19) {
                            _lastZoomChangeTime = now;
                            _changeZoom(
                              _zoom + 1,
                              constraints,
                              originPx,
                              originPy,
                              viewerW: viewerW,
                              viewerH: viewerH,
                              gridHalfSize: gridHalfSize,
                            );
                          } else if (pointerSignal.scrollDelta.dy > 2 &&
                              _zoom > 6) {
                            _lastZoomChangeTime = now;
                            _changeZoom(
                              _zoom - 1,
                              constraints,
                              originPx,
                              originPy,
                              viewerW: viewerW,
                              viewerH: viewerH,
                              gridHalfSize: gridHalfSize,
                            );
                          }
                        }
                      }
                    },
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onDoubleTap: () {
                        if (_zoom < 19) {
                          _changeZoom(
                            _zoom + 1,
                            constraints,
                            originPx,
                            originPy,
                            viewerW: viewerW,
                            viewerH: viewerH,
                            gridHalfSize: gridHalfSize,
                          );
                        }
                      },
                      onLongPressStart: (details) {
                        final m = _applyPendingResizeTo(
                          _transformationController.value,
                        );
                        final currentScale = m.getMaxScaleOnAxis();
                        final effectiveScale = currentScale > 0.01
                            ? currentScale
                            : 1.0;
                        final dx = m.storage[12];
                        final dy = m.storage[13];
                        final offset =
                            details.localPosition -
                            Offset(viewportW / 2, viewportH / 2);
                        final rotation = _rotationNotifier.value;
                        final c = math.cos(rotation);
                        final sn = math.sin(rotation);
                        final localX =
                            offset.dx * c + offset.dy * sn + viewerW / 2;
                        final localY =
                            -offset.dx * sn + offset.dy * c + viewerH / 2;
                        final touchCanvasX = (localX - dx) / effectiveScale;
                        final touchCanvasY = (localY - dy) / effectiveScale;
                        final touchWorldPx = originPx + touchCanvasX;
                        final touchWorldPy = originPy + touchCanvasY;
                        final touchLng = _pixelX2lon(touchWorldPx, _zoom);
                        final touchLat = _pixelY2lat(touchWorldPy, _zoom);
                        _showAddLandmarkModal(
                          context,
                          initialLat: touchLat,
                          initialLng: touchLng,
                        );
                      },
                      child: Listener(
                        behavior: HitTestBehavior.translucent,
                        onPointerDown: (event) {
                          _touchPointers[event.pointer] = event.position;
                          if (event.kind == PointerDeviceKind.mouse &&
                              (event.buttons & kSecondaryMouseButton != 0 ||
                                  HardwareKeyboard.instance.isShiftPressed)) {
                            _isMouseRotating = true;
                            _mouseRotateStartAngle = math.atan2(
                              event.localPosition.dy - viewportH / 2,
                              event.localPosition.dx - viewportW / 2,
                            );
                            _rotationAtMouseStart = _rotationNotifier.value;
                          } else if (_touchPointers.length >= 2) {
                            final pts = _touchPointers.values.take(2).toList();
                            _twoFingerStartAngle = math.atan2(
                              pts[1].dy - pts[0].dy,
                              pts[1].dx - pts[0].dx,
                            );
                            _rotationAtTouchStart = _rotationNotifier.value;
                          }
                        },
                        onPointerMove: (event) {
                          if (_touchPointers.containsKey(event.pointer)) {
                            _touchPointers[event.pointer] = event.position;
                          }
                          if (_isMouseRotating) {
                            final currentAngle = math.atan2(
                              event.localPosition.dy - viewportH / 2,
                              event.localPosition.dx - viewportW / 2,
                            );
                            var diff = currentAngle - _mouseRotateStartAngle;
                            while (diff > math.pi) {
                              diff -= 2 * math.pi;
                            }
                            while (diff < -math.pi) {
                              diff += 2 * math.pi;
                            }
                            _rotationAnimController.stop();
                            _rotationNotifier.value =
                                _rotationAtMouseStart + diff;
                          } else if (_touchPointers.length >= 2) {
                            final pts = _touchPointers.values.take(2).toList();
                            final currentAngle = math.atan2(
                              pts[1].dy - pts[0].dy,
                              pts[1].dx - pts[0].dx,
                            );
                            var diff = currentAngle - _twoFingerStartAngle;
                            while (diff > math.pi) {
                              diff -= 2 * math.pi;
                            }
                            while (diff < -math.pi) {
                              diff += 2 * math.pi;
                            }
                            if (diff.abs() > 0.08) {
                              _rotationAnimController.stop();
                              _rotationNotifier.value =
                                  _rotationAtTouchStart + diff;
                            }
                          }
                        },
                        onPointerUp: (event) {
                          _touchPointers.remove(event.pointer);
                          _isMouseRotating = false;
                          _rotationAtTouchStart = _rotationNotifier.value;
                          if (_touchPointers.length >= 2) {
                            final pts = _touchPointers.values.take(2).toList();
                            _twoFingerStartAngle = math.atan2(
                              pts[1].dy - pts[0].dy,
                              pts[1].dx - pts[0].dx,
                            );
                          }
                        },
                        onPointerCancel: (event) {
                          _touchPointers.remove(event.pointer);
                          _isMouseRotating = false;
                          _rotationAtTouchStart = _rotationNotifier.value;
                          if (_touchPointers.length >= 2) {
                            final pts = _touchPointers.values.take(2).toList();
                            _twoFingerStartAngle = math.atan2(
                              pts[1].dy - pts[0].dy,
                              pts[1].dx - pts[0].dx,
                            );
                          }
                        },
                        child: SizedBox(
                          width: viewportW,
                          height: viewportH,
                          child: Center(
                            child: OverflowBox(
                              minWidth: viewerW,
                              maxWidth: viewerW,
                              minHeight: viewerH,
                              maxHeight: viewerH,
                              child: ValueListenableBuilder<double>(
                                valueListenable: _rotationNotifier,
                                builder: (context, rotation, child) {
                                  return Transform.rotate(
                                    angle: rotation,
                                    child: child,
                                  );
                                },
                                child: InteractiveViewer(
                                  transformationController:
                                      _transformationController,
                                  constrained: false, // Permite que o mapa ocupe 100% da área sem distorção ou cortes pretos
                                  boundaryMargin: EdgeInsets.zero, // O canvas dinâmico já excede a diagonal em todos os zooms, evitando áreas vazias
                                  panEnabled: true,
                                  scaleEnabled: true, // Habilita zoom fluido por gesto de pinça na tela e trackpad
                                  trackpadScrollCausesScale: true, // Garante que pinça de trackpad aplique ZOOM em vez de deslizar para os lados
                                  minScale: 0.6,
                                  maxScale: 2.0,
                                  // Quase sem inércia: a origem é realinhada ao fim do gesto.
                                  interactionEndFrictionCoefficient: 1e-100,
                                  onInteractionEnd: (details) {
                                    if (details.pointerCount >= 2) return;
                                    _hasAppliedInitialMatrix = true;
                                    final m = _applyPendingResizeTo(
                                      _transformationController.value,
                                    );
                                    final currentScale = m.getMaxScaleOnAxis();
                                    final effectiveScale = currentScale > 0.01
                                        ? currentScale
                                        : 1.0;
                                    final dx = m.storage[12];
                                    final dy = m.storage[13];
                                    final canvasCenterX =
                                        ((viewerW / 2.0) - dx) / effectiveScale;
                                    final canvasCenterY =
                                        ((viewerH / 2.0) - dy) / effectiveScale;
                                    final worldPx = originPx + canvasCenterX;
                                    final worldPy = originPy + canvasCenterY;
                                    final focalLng = _pixelX2lon(
                                      worldPx,
                                      _zoom,
                                    ).clamp(-179.999999, 179.999999);
                                    final focalLat = _pixelY2lat(
                                      worldPy,
                                      _zoom,
                                    ).clamp(-85.0511, 85.0511);

                                    final now = clock.now();
                                    if (_lastZoomChangeTime == null ||
                                        now
                                                .difference(
                                                  _lastZoomChangeTime!,
                                                )
                                                .inMilliseconds >=
                                            250) {
                                      if (currentScale >= 1.35 && _zoom < 19) {
                                        _lastZoomChangeTime = now;
                                        _changeZoom(
                                          _zoom + 1,
                                          constraints,
                                          originPx,
                                          originPy,
                                          viewerW: viewerW,
                                          viewerH: viewerH,
                                          gridHalfSize: gridHalfSize,
                                        );
                                        return;
                                      } else if (currentScale <= 0.75 &&
                                          _zoom > 6) {
                                        _lastZoomChangeTime = now;
                                        _changeZoom(
                                          _zoom - 1,
                                          constraints,
                                          originPx,
                                          originPy,
                                          viewerW: viewerW,
                                          viewerH: viewerH,
                                          gridHalfSize: gridHalfSize,
                                        );
                                        return;
                                      }
                                    }
                                    final newCenterTileX = _lon2tileX(
                                      focalLng,
                                      _zoom,
                                    );
                                    final newCenterTileY = _lat2tileY(
                                      focalLat,
                                      _zoom,
                                    );
                                    if (newCenterTileX == centerTileX &&
                                        newCenterTileY == centerTileY) {
                                      _activeCenterLng = focalLng;
                                      _activeCenterLat = focalLat;
                                      return;
                                    }
                                    final newMinTileX =
                                        newCenterTileX - gridHalfSize;
                                    final newMinTileY =
                                        newCenterTileY - gridHalfSize;
                                    final newOriginX =
                                        newMinTileX *
                                        _ContactsMapScreenState._tileSize;
                                    final newOriginY =
                                        newMinTileY *
                                        _ContactsMapScreenState._tileSize;
                                    final nextDx =
                                        dx +
                                        (newOriginX - originPx) *
                                            effectiveScale;
                                    final nextDy =
                                        dy +
                                        (newOriginY - originPy) *
                                            effectiveScale;
                                    _cancelPendingResizeSync();
                                    _updateState(() {
                                      _activeCenterLng = focalLng;
                                      _activeCenterLat = focalLat;
                                    });
                                    _setMatrixWithRebuildPending(
                                      Matrix4.identity()
                                        ..translateByDouble(
                                          nextDx,
                                          nextDy,
                                          0,
                                          1,
                                        )
                                        ..scaleByDouble(
                                          effectiveScale,
                                          effectiveScale,
                                          1,
                                          1,
                                        ),
                                    );
                                  },
                                  child: Container(
                                    width: canvasWidth,
                                    height: canvasHeight,
                                    color: isDark
                                        ? const Color(0xFF0F172A)
                                        : const Color(0xFFF1F5F9),
                                    child: Stack(
                                      children: [
                                        // Camada de Tiles dinâmica isolada (sem rebuild da tela inteira durante arraste/zoom/rotação)
                                        Positioned.fill(
                                          child: _DynamicTileLayer(
                                            transformationController:
                                                _transformationController,
                                            rotationListenable:
                                                _rotationNotifier,
                                            zoom: _zoom,
                                            minTileX: minTileX,
                                            maxTileX: maxTileX,
                                            minTileY: minTileY,
                                            maxTileY: maxTileY,
                                            originPx: originPx,
                                            originPy: originPy,
                                            viewportW: viewportW,
                                            viewportH: viewportH,
                                            viewerW: viewerW,
                                            viewerH: viewerH,
                                            tileSize: _ContactsMapScreenState
                                                ._tileSize,
                                            isDark: isDark,
                                            layerStyle: activeLayerStyle,
                                            initialMatrixOverride:
                                                frameMatrixOverride,
                                            shouldIgnoreTransformUpdates: () =>
                                                _suppressTileBoundsListener,
                                          ),
                                        ),

                                        // Renderização dos Marcos / Pontos de Referência geolocalizados
                                        if (_showLandmarks)
                                          for (
                                            int i = 0;
                                            i < geoLandmarks.length;
                                            i++
                                          )
                                            _buildLandmarkPin(
                                              geoLandmarks[i],
                                              i,
                                              geoLandmarks.length,
                                              originPx: originPx,
                                              originPy: originPy,
                                              canvasWidth: canvasWidth,
                                              canvasHeight: canvasHeight,
                                            ),

                                        // Ponto Azul Pulsante de Localização GPS Nativa (Regra 12)
                                        if (_userGpsLocation != null) ...[
                                          () {
                                            final userX =
                                                _lon2pixelX(
                                                  _userGpsLocation!.longitude,
                                                  _zoom,
                                                ) -
                                                originPx;
                                            final userY =
                                                _lat2pixelY(
                                                  _userGpsLocation!.latitude,
                                                  _zoom,
                                                ) -
                                                originPy;
                                            return Positioned(
                                              left: userX - 22,
                                              top: userY - 22,
                                              child: IgnorePointer(
                                                child: Stack(
                                                  alignment: Alignment.center,
                                                  children: [
                                                    Container(
                                                      width: 44,
                                                      height: 44,
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color: Colors.blue
                                                            .withValues(
                                                              alpha: 0.22,
                                                            ),
                                                        border: Border.all(
                                                          color: Colors
                                                              .blueAccent
                                                              .withValues(
                                                                alpha: 0.5,
                                                              ),
                                                          width: 1.5,
                                                        ),
                                                      ),
                                                    ),
                                                    Container(
                                                      width: 14,
                                                      height: 14,
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color: const Color(
                                                          0xFF2563EB,
                                                        ),
                                                        border: Border.all(
                                                          color: Colors.white,
                                                          width: 2.5,
                                                        ),
                                                        boxShadow: const [
                                                          BoxShadow(
                                                            color:
                                                                Colors.black38,
                                                            blurRadius: 4,
                                                            offset: Offset(
                                                              0,
                                                              1,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          }(),
                                        ],

                                        // Camada de Sobreposição Translúcida de Zonas Esquecidas (>90 dias sem visita)
                                        for (final p in orderedContacts) ...[
                                          () {
                                            final layer = pinLayers[p.id];
                                            if (layer !=
                                                TerritoryPinLayer
                                                    .forgottenZone) {
                                              return const SizedBox.shrink();
                                            }

                                            final hasGeo =
                                                p.latitude != null &&
                                                p.longitude != null &&
                                                (p.latitude != 0.0 ||
                                                    p.longitude != 0.0) &&
                                                p.latitude!.abs() <= 90 &&
                                                p.longitude!.abs() <= 180;
                                            if (!hasGeo) {
                                              return const SizedBox.shrink();
                                            }

                                            final x =
                                                _lon2pixelX(
                                                  p.longitude!,
                                                  _zoom,
                                                ) -
                                                originPx;
                                            final y =
                                                _lat2pixelY(
                                                  p.latitude!,
                                                  _zoom,
                                                ) -
                                                originPy;
                                            const double haloRadius = 42.0;

                                            return Positioned(
                                              left: x - haloRadius,
                                              top: y - haloRadius,
                                              child: IgnorePointer(
                                                child: Container(
                                                  width: haloRadius * 2,
                                                  height: haloRadius * 2,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: const Color(
                                                      0xFFDC2626,
                                                    ).withValues(alpha: 0.18),
                                                    border: Border.all(
                                                      color: const Color(
                                                        0xFFDC2626,
                                                      ).withValues(alpha: 0.45),
                                                      width: 1.5,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          }(),
                                        ],

                                        // Renderização de cada pino de contato com coordenadas válidas (destacado por último)
                                        for (
                                          int i = 0;
                                          i < orderedContacts.length;
                                          i++
                                        )
                                          _buildMapPin(
                                            orderedContacts[i],
                                            i,
                                            orderedContacts.length,
                                            originPx: originPx,
                                            originPy: originPy,
                                            canvasWidth: canvasWidth,
                                            canvasHeight: canvasHeight,
                                            pinLayer:
                                                pinLayers[orderedContacts[i]
                                                    .id] ??
                                                TerritoryPinLayer.interested,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            if (_highlightPersonId != null && highlightPerson != null)
              Positioned(
                top: 12,
                left: 12,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(20),
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      _updateState(() {
                        _activeCenterLat ??= centerLat;
                        _activeCenterLng ??= centerLng;
                        _highlightPersonId = null;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFF59E0B),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star,
                            color: Color(0xFFD97706),
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Destacado: ${highlightPerson.name.split(' ').first}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.close,
                            size: 14,
                            color: AppTheme.textMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Controles Flutuantes de Zoom (+ / -), Bússola, Tela Cheia e Localização
            Positioned(
              top: 12,
              right: 12,
              bottom: 90,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Rotação manual com bússola e retorno suave ao norte
                    GestureDetector(
                      onHorizontalDragUpdate: (details) {
                        _rotationAnimController.stop();
                        _rotationNotifier.value +=
                            (details.primaryDelta ?? 0.0) * 0.02;
                      },
                      child: ValueListenableBuilder<double>(
                        valueListenable: _rotationNotifier,
                        builder: (context, rotation, _) {
                          return Semantics(
                            button: true,
                            label:
                                'Bússola: alinhar mapa ao norte (rotação atual ${(rotation * 180 / math.pi).round()} graus)',
                            child: FloatingActionButton.small(
                              heroTag: 'map_compass',
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.red.shade700,
                              tooltip:
                                  'Rotação do mapa (${(rotation * 180 / math.pi).round()}°). Toque para voltar suavemente ao norte ou arraste para girar.',
                              onPressed: _animateResetRotationToNorth,
                              child: Transform.rotate(
                                angle: rotation,
                                child: const Icon(
                                  Icons.navigation_rounded,
                                  size: 20,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Botões de ajuste manual de rumo
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: FloatingActionButton.small(
                            heroTag: 'map_rotate_left',
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black87,
                            elevation: 2,
                            tooltip: 'Girar 45° à esquerda',
                            onPressed: () => _rotateBy(-math.pi / 4),
                            child: const Icon(Icons.rotate_left, size: 16),
                          ),
                        ),
                        const SizedBox(width: 4),
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: FloatingActionButton.small(
                            heroTag: 'map_rotate_right',
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black87,
                            elevation: 2,
                            tooltip: 'Girar 45° à direita',
                            onPressed: () => _rotateBy(math.pi / 4),
                            child: const Icon(Icons.rotate_right, size: 16),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Botão Camadas do Mapa (Estilos Organic Maps e Motor MapLibre)
                    Semantics(
                      button: true,
                      label: 'Abrir opções de camadas e motor do mapa',
                      hint: 'Abre opções de estilo de mapa e alternância de motor',
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        child: FloatingActionButton.small(
                          heroTag: 'map_layer_styles',
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.accentTeal,
                          tooltip: 'Camadas e Estilos de Mapa',
                          onPressed: () => _showMapLayerStylesModal(context),
                          child: const Icon(Icons.layers_rounded, size: 20),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Botão Tela Cheia (Fullscreen toggle para iPads/tablets e mobile)
                    Semantics(
                      button: true,
                      label: isFullscreen
                          ? 'Sair do modo tela cheia do mapa'
                          : 'Ativar modo tela cheia do mapa',
                      hint: isFullscreen
                          ? 'Retorna a exibição normal com app bar'
                          : 'Expande o mapa por toda a tela',
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        child: FloatingActionButton.small(
                          heroTag: 'map_fullscreen',
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black87,
                          tooltip: isFullscreen
                              ? 'Sair da Tela Cheia'
                              : 'Modo Tela Cheia',
                          onPressed: () {
                            ref.read(isMapFullscreenProvider.notifier).toggle();
                          },
                          child: Icon(
                            isFullscreen
                                ? Icons.fullscreen_exit
                                : Icons.fullscreen,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Botão Minha Localização GPS
                    Semantics(
                      button: true,
                      label: 'Centralizar mapa na minha localização GPS',
                      hint: 'Move a visualização para as coordenadas do dispositivo',
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        child: FloatingActionButton.small(
                          heroTag: 'map_gps_locate',
                          backgroundColor: _isLocatingUser
                              ? AppTheme.accentTeal
                              : Colors.white,
                          foregroundColor: _isLocatingUser
                              ? Colors.white
                              : Colors.blue.shade700,
                          tooltip: 'Minha Localização GPS',
                          onPressed: () async {
                            if (_isLocatingUser) return;
                            final messenger = ScaffoldMessenger.of(context);
                            final warningColor = Colors.orange.shade800;
                            _updateState(() => _isLocatingUser = true);
                            final result =
                                await GeolocationHelper.getCurrentLocationWithStatus();
                            if (!mounted) return;
                            final loc = result.coordinates;
                            if (result.isSuccess && loc != null) {
                              _updateState(() {
                                _userGpsLocation = loc;
                                _isLocatingUser = false;
                              });
                              _centerOnCoords(
                                loc.latitude,
                                loc.longitude,
                                viewportW,
                                viewportH,
                                viewerW: viewerW,
                                viewerH: viewerH,
                                gridHalfSize: gridHalfSize,
                              );
                            } else {
                              _updateState(() => _isLocatingUser = false);
                              messenger
                                ..hideCurrentSnackBar()
                                ..showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '${result.userMessage} O mapa permaneceu na posição anterior.',
                                    ),
                                    backgroundColor: warningColor,
                                    duration: const Duration(seconds: 5),
                                    action: SnackBarAction(
                                      label: 'Ajustes',
                                      textColor: Colors.white,
                                      onPressed: () =>
                                          GeolocationHelper.openAppSettings(),
                                    ),
                                  ),
                                );
                            }
                          },
                          child: _isLocatingUser
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.my_location, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),

                    Semantics(
                      button: true,
                      label: 'Aproximar zoom do mapa',
                      hint: 'Aumenta a aproximação do mapa',
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        child: FloatingActionButton.small(
                          heroTag: 'map_zoom_in',
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black87,
                          tooltip: 'Aproximar Zoom',
                          onPressed: () {
                            if (_zoom < 19) {
                              _changeZoom(
                                _zoom + 1,
                                constraints,
                                originPx,
                                originPy,
                                viewerW: viewerW,
                                viewerH: viewerH,
                                gridHalfSize: gridHalfSize,
                              );
                            }
                          },
                          child: const Icon(Icons.add),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Semantics(
                      liveRegion: true,
                      label: 'Nível de zoom atual: $_zoom',
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Z: $_zoom',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Semantics(
                      button: true,
                      label: 'Afastar zoom do mapa',
                      hint: 'Diminui a aproximação do mapa',
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        child: FloatingActionButton.small(
                          heroTag: 'map_zoom_out',
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black87,
                          tooltip: 'Afastar Zoom',
                          onPressed: () {
                            if (_zoom > 6) {
                              _changeZoom(
                                _zoom - 1,
                                constraints,
                                originPx,
                                originPy,
                                viewerW: viewerW,
                                viewerH: viewerH,
                                gridHalfSize: gridHalfSize,
                              );
                            }
                          },
                          child: const Icon(Icons.remove),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Semantics(
                      button: true,
                      label: 'Recentralizar mapa nos contatos',
                      hint: 'Centraliza em Santo Antônio do Içá',
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        child: FloatingActionButton.small(
                          heroTag: 'map_recenter',
                          backgroundColor: AppTheme.primaryBlue,
                          foregroundColor: Colors.white,
                          tooltip: 'Ir para Santo Antônio do Içá (mapa offline: camada Padrão, zoom 8 a 16)',
                          onPressed: () => _centerOnCoords(
                            GeolocationHelper.defaultLat,
                            GeolocationHelper.defaultLng,
                            viewportW,
                            viewportH,
                            viewerW: viewerW,
                            viewerH: viewerH,
                            gridHalfSize: gridHalfSize,
                          ),
                          child: const Icon(
                            Icons.filter_center_focus,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Barra de Escala Métrica Dinâmica e Selo de Atribuição OSM
            Positioned(
              bottom: 8,
              left: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_zoom > 16 &&
                      TileCacheService.instance.activeStyle ==
                          MapLayerStyle.standard)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      color: Colors.white.withValues(alpha: 0.9),
                      child: const Text(
                        'Pacote SAI: detalhe nativo até Z16',
                        style: TextStyle(fontSize: 10, color: Colors.black87),
                      ),
                    ),
                  ValueListenableBuilder<Matrix4>(
                    valueListenable: _transformationController,
                    builder: (context, matrix, _) {
                      return _buildMetricScaleBar(
                        matrix.getMaxScaleOnAxis(),
                        effectiveCenterLat,
                        _zoom,
                      );
                    },
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '© OpenStreetMap contributors',
                          style: TextStyle(fontSize: 10, color: Colors.black87),
                        ),
                      ),
                      if (contacts.length > geoContacts.length) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Colors.amber.shade600,
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            '${contacts.length - geoContacts.length} contatos sem GPS',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade900,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Painel inferior flutuante ao tocar em um Ponto de Referência
            if (_selectedPinLandmark != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: _selectedPinLandmark!.color
                                      .withValues(alpha: 0.15),
                                  child: Icon(
                                    _selectedPinLandmark!.icon,
                                    color: _selectedPinLandmark!.color,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  _selectedPinLandmark!.name,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () => _updateState(
                                () => _selectedPinLandmark = null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _selectedPinLandmark!.color.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _selectedPinLandmark!.categoryLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _selectedPinLandmark!.color,
                            ),
                          ),
                        ),
                        if (_selectedPinLandmark!.address != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 16,
                                color: isDark
                                    ? const Color(0xFFCBD5E1)
                                    : AppTheme.textMuted,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _selectedPinLandmark!.address!,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (_selectedPinLandmark!.notes != null &&
                            _selectedPinLandmark!.notes!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            _selectedPinLandmark!.notes!,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? const Color(0xFFCBD5E1)
                                  : AppTheme.textMuted,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _selectedPinLandmark!.color,
                                ),
                                icon: const Icon(Icons.directions, size: 16),
                                label: const Text('Rota até esta Referência'),
                                onPressed: () =>
                                    _openLandmarkRoute(_selectedPinLandmark!),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.share, size: 16),
                              label: const Text('Compartilhar'),
                              onPressed: () =>
                                  _shareLandmark(_selectedPinLandmark!),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: AppTheme.alertRed,
                              ),
                              tooltip: 'Excluir marco',
                              onPressed: () async {
                                final mgr = ref.read(landmarkManagerProvider);
                                await mgr.deleteLandmark(
                                  _selectedPinLandmark!.id,
                                );
                                _updateState(() => _selectedPinLandmark = null);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            key: const Key('btn_navigate_external_landmark'),
                            icon: const Icon(Icons.explore_outlined, size: 16),
                            label: const Text('Navegar (Mapas externos)'),
                            onPressed: () {
                              final lm = _selectedPinLandmark!;
                              final lat = lm.latitude ?? -3.1022;
                              final lon = lm.longitude ?? -67.9397;
                              ExternalNavigationLauncher.showNavigationSheet(
                                context,
                                lat: lat,
                                lng: lon,
                                label: lm.name,
                                originLat: _userGpsLocation?.latitude,
                                originLng: _userGpsLocation?.longitude,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Painel inferior flutuante ao tocar em um pino de contato
            if (_selectedPinPerson != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                _selectedPinPerson!.name,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor(
                                  _selectedPinPerson!.status,
                                ).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _selectedPinPerson!.status.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _getStatusColor(
                                    _selectedPinPerson!.status,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () =>
                                  _updateState(() => _selectedPinPerson = null),
                            ),
                          ],
                        ),
                        if (_selectedPinPerson!.address != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 16,
                                color: isDark
                                    ? const Color(0xFFCBD5E1)
                                    : AppTheme.textMuted,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _selectedPinPerson!.address!,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (_selectedPinPerson!.preferredSchedule != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.schedule,
                                size: 16,
                                color: isDark
                                    ? const Color(0xFFCBD5E1)
                                    : AppTheme.textMuted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _selectedPinPerson!.preferredSchedule!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.accentTeal,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Tooltip(
                                message:
                                    _mapEngineAdapter
                                            .capabilities
                                            .supportsOfflineRouting &&
                                        _hasVerifiedRegionalRoutingGraph
                                    ? 'Calcular rota offline regional (A*)'
                                    : 'Roteamento offline indisponível nesta região',
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.alt_route, size: 16),
                                  label: const Text('Rota Offline (A*)'),
                                  onPressed: () {
                                    final p = _selectedPinPerson!;
                                    final lat = p.latitude ?? -3.1022;
                                    final lon = p.longitude ?? -67.9397;
                                    _showOfflineRouteDialog(
                                      destinationName: p.name,
                                      destLat: lat,
                                      destLon: lon,
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.directions, size: 16),
                                label: const Text('Rota Externa'),
                                onPressed: () =>
                                    _openSingleRoute(_selectedPinPerson!),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.person, size: 16),
                              label: const Text('Perfil'),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PersonDetailScreen(
                                      personId: _selectedPinPerson!.id,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            key: const Key('btn_navigate_external_contact'),
                            icon: const Icon(Icons.explore_outlined, size: 16),
                            label: const Text('Navegar (Mapas externos)'),
                            onPressed: () {
                              final p = _selectedPinPerson!;
                              final lat = p.latitude ?? -3.1022;
                              final lon = p.longitude ?? -67.9397;
                              ExternalNavigationLauncher.showNavigationSheet(
                                context,
                                lat: lat,
                                lng: lon,
                                label: p.name,
                                originLat: _userGpsLocation?.latitude,
                                originLng: _userGpsLocation?.longitude,
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF059669),
                              side: const BorderSide(color: Color(0xFF059669)),
                            ),
                            icon: const Icon(Icons.share_outlined, size: 16),
                            label: const Text(
                              'Passar Contato para Irmão Responsável (WhatsApp)',
                            ),
                            onPressed: () =>
                                PersonHandOffHelper.sendViaWhatsApp(
                                  person: _selectedPinPerson!,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildLandmarkPin(
    TerritoryLandmark landmark,
    int index,
    int total, {
    required double originPx,
    required double originPy,
    required double canvasWidth,
    required double canvasHeight,
  }) {
    double x;
    double y;

    final hasGeo =
        landmark.latitude != null &&
        landmark.longitude != null &&
        (landmark.latitude != 0.0 || landmark.longitude != 0.0) &&
        landmark.latitude!.abs() <= 90 &&
        landmark.longitude!.abs() <= 180;
    if (hasGeo) {
      x = _lon2pixelX(landmark.longitude!, _zoom) - originPx;
      y = _lat2pixelY(landmark.latitude!, _zoom) - originPy;
    } else {
      final radius = 120.0 + (index % 3) * 60.0;
      final angle = (index * 2 * math.pi) / (total > 0 ? total : 1);
      x = (canvasWidth / 2) + radius * math.cos(angle);
      y = (canvasHeight / 2) + radius * math.sin(angle);
    }

    final isSelected = _selectedPinLandmark?.id == landmark.id;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Positioned(
      left: x - 60,
      bottom: canvasHeight - y,
      width: 120,
      child: GestureDetector(
        onTap: () {
          _updateState(() {
            _selectedPinLandmark = landmark;
            _selectedPinPerson = null;
          });
        },
        child: ValueListenableBuilder<double>(
          valueListenable: _rotationNotifier,
          builder: (context, rotation, childWidget) {
            if (rotation == 0.0) return childWidget!;
            return Transform.rotate(
              angle: -rotation,
              alignment: Alignment.bottomCenter,
              child: childWidget,
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                constraints: const BoxConstraints(maxWidth: 120),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? landmark.color
                      : (isDark ? const Color(0xFF1E293B) : Colors.white),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                  border: Border.all(color: landmark.color, width: 2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      landmark.icon,
                      size: 14,
                      color: isSelected ? Colors.white : landmark.color,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        landmark.name.split(' ').first,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Colors.white
                              : (isDark ? Colors.white : AppTheme.textDark),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                landmark.icon,
                color: landmark.color,
                size: isSelected ? 34 : 26,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMapPin(
    PersonEntry person,
    int index,
    int total, {
    required double originPx,
    required double originPy,
    required double canvasWidth,
    required double canvasHeight,
    TerritoryPinLayer pinLayer = TerritoryPinLayer.interested,
  }) {
    double x;
    double y;

    final hasGeo =
        person.latitude != null &&
        person.longitude != null &&
        (person.latitude != 0.0 || person.longitude != 0.0) &&
        person.latitude!.abs() <= 90 &&
        person.longitude!.abs() <= 180;
    if (hasGeo) {
      x = _lon2pixelX(person.longitude!, _zoom) - originPx;
      y = _lat2pixelY(person.latitude!, _zoom) - originPy;
    } else {
      final radius = 180.0 + (index % 4) * 60.0;
      final angle = (index * 2 * math.pi) / (total > 0 ? total : 1);
      x = (canvasWidth / 2) + radius * math.cos(angle);
      y = (canvasHeight / 2) + radius * math.sin(angle);
    }

    final isHighlighted =
        _highlightPersonId != null && person.id == _highlightPersonId;
    final isSelected = _selectedPinPerson?.id == person.id;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isForeign =
        person.tags.toLowerCase().contains('estrangeiro') ||
        (person.generalNotes ?? '').toLowerCase().contains('idioma') ||
        (person.generalNotes ?? '').toLowerCase().contains('língua') ||
        (person.generalNotes ?? '').toLowerCase().contains('estrangeir');

    final Color pinColor;
    if (isHighlighted) {
      pinColor = const Color(0xFFD97706);
    } else if (isSelected) {
      pinColor = AppTheme.primaryBlue;
    } else if (isForeign) {
      pinColor = const Color(0xFF0284C7);
    } else {
      pinColor = pinLayer.color;
    }

    final IconData pinIcon;
    if (isHighlighted) {
      pinIcon = Icons.stars;
    } else if (isForeign) {
      pinIcon = Icons.public;
    } else {
      pinIcon = pinLayer.icon;
    }

    return Positioned(
      left: x - 70,
      bottom: canvasHeight - y,
      width: 140,
      child: GestureDetector(
        behavior: HitTestBehavior.deferToChild,
        onTap: () {
          _updateState(() {
            _selectedPinPerson = person;
            _selectedPinLandmark = null;
          });
        },
        child: ValueListenableBuilder<double>(
          valueListenable: _rotationNotifier,
          builder: (context, rotation, childWidget) {
            if (rotation == 0.0) return childWidget!;
            return Transform.rotate(
              angle: -rotation,
              alignment: Alignment.bottomCenter,
              child: childWidget,
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                constraints: BoxConstraints(
                  maxWidth: isHighlighted ? 140 : 110,
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: isHighlighted ? 10 : 8,
                  vertical: isHighlighted ? 5 : 4,
                ),
                decoration: BoxDecoration(
                  color: isHighlighted
                      ? const Color(0xFFD97706)
                      : (isSelected
                            ? Colors.black87
                            : (isDark
                                  ? const Color(0xFF1E293B)
                                  : Colors.white)),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    if (isHighlighted)
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.65),
                        blurRadius: 14,
                        spreadRadius: 3,
                      )
                    else
                      const BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                  ],
                  border: Border.all(
                    color: isHighlighted ? Colors.white : pinColor,
                    width: isHighlighted ? 2.5 : 2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isHighlighted) ...[
                      const Icon(
                        Icons.star,
                        color: Colors.amberAccent,
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                    ] else if (isForeign) ...[
                      const Text('🌐', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                    ] else if (pinLayer == TerritoryPinLayer.forgottenZone) ...[
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFDC2626),
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child: Text(
                        person.name.split(' ').first,
                        style: TextStyle(
                          fontSize: isHighlighted ? 12 : 11,
                          fontWeight: FontWeight.bold,
                          color: (isHighlighted || isSelected)
                              ? Colors.white
                              : (isDark ? Colors.white : AppTheme.textDark),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                pinIcon,
                color: isHighlighted ? const Color(0xFFD97706) : pinColor,
                size: isHighlighted ? 44 : (isSelected ? 38 : 30),
                shadows: isHighlighted
                    ? [Shadow(color: Colors.amber.shade300, blurRadius: 12)]
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
