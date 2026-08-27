import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:loc_motos/core/constants/navigation_constants.dart';
import 'package:loc_motos/core/utils/navigation_duration_format.dart';
import 'package:loc_motos/features/auth/domain/entities/vehicle_map_marker.dart';
import 'package:loc_motos/features/auth/presentation/widgets/vehicle_navigation_marker.dart';
import 'package:loc_motos/features/navigation/data/services/navigation_map_style_service.dart';
import 'package:loc_motos/features/navigation/domain/entities/alert_preferences.dart';
import 'package:loc_motos/features/navigation/domain/entities/geo_point.dart';
import 'package:loc_motos/features/navigation/domain/entities/hybrid_map_styles.dart';
import 'package:loc_motos/features/navigation/domain/entities/navigation_route.dart';
import 'package:loc_motos/features/navigation/domain/entities/route_alert.dart';
import 'package:loc_motos/features/navigation/presentation/helpers/route_map_bounds.dart';
import 'package:loc_motos/features/navigation/presentation/helpers/route_progress_split.dart';
import 'package:loc_motos/features/navigation/presentation/models/navigation_map_camera_mode.dart';
import 'package:loc_motos/core/utils/navigation_bearing.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

/// Compañero de grupo en el mapa de navegación (HUD).
@immutable
class HudGroupMate {
  const HudGroupMate({
    required this.uid,
    required this.lat,
    required this.lng,
    required this.heading,
    required this.label,
    this.isStale = false,
  });

  final String uid;
  final double lat;
  final double lng;
  final double heading;
  final String label;
  final bool isStale;

  @override
  bool operator ==(Object other) {
    return other is HudGroupMate &&
        other.uid == uid &&
        other.lat == lat &&
        other.lng == lng &&
        other.heading == heading &&
        other.label == label &&
        other.isStale == isStale;
  }

  @override
  int get hashCode => Object.hash(uid, lat, lng, heading, label, isStale);
}

/// Mapa MapLibre: seguimiento en HUD o encuadre de ruta en vista previa.
///
/// Usa PMTiles Protomaps (local o remoto) en España; OpenFreeMap fuera.
class NavigationMapView extends StatefulWidget {
  const NavigationMapView({
    super.key,
    required this.route,
    required this.mapStyles,
    this.alternativeRoutes = const [],
    this.hasNetwork = false,
    this.latitude,
    this.longitude,
    this.bearing = 0,
    this.speedMps = 0,
    this.pitch = 0,
    this.show3dBuildings = false,
    this.cameraMode = NavigationMapCameraMode.followDevice,
    this.cameraFollowUser = true,
    this.cameraFollowEpoch = 0,
    this.previewFocusLatitude,
    this.previewFocusLongitude,
    this.previewFocusEpoch = 0,
    this.fitBoundsBottomExtra = 0,
    this.alertPreferences = AlertPreferences.defaults,
    this.puckStyle,
    this.preferDarkMap = false,
    this.lowGlCompat = false,
    this.groupMates = const [],
    this.onControllerReady,
    this.onCameraFollowChanged,
  });

  final NavigationRoute route;

  /// Otras opciones de ruta (vista previa); se pintan más claras.
  final List<NavigationRoute> alternativeRoutes;
  final HybridMapStyles mapStyles;
  final bool hasNetwork;
  final double? latitude;
  final double? longitude;
  final double bearing;

  /// Velocidad para zoom dinámico (HUD).
  final double speedMps;
  final double pitch;

  /// Edificios extruidos (fill-extrusion). Solo navegación HUD con “Mapa en 3D”.
  final bool show3dBuildings;
  final NavigationMapCameraMode cameraMode;

  /// Si es `false` (p. ej. el usuario ha arrastrado el mapa), no se fuerza el seguimiento.
  final bool cameraFollowUser;

  /// Se incrementa al pulsar “mi ubicación” para forzar un recentrado.
  final int cameraFollowEpoch;

  /// En preview: si no es null, centra aquí en lugar de encuadrar toda la ruta.
  final double? previewFocusLatitude;
  final double? previewFocusLongitude;
  final int previewFocusEpoch;
  final double fitBoundsBottomExtra;
  final AlertPreferences alertPreferences;

  /// Si es `null`, se usa el puck azul circular por defecto.
  final NavigationPuckStyle? puckStyle;

  /// Preferir estilo oscuro online (noche).
  final bool preferDarkMap;

  /// Emulador API antigua: estilo mínimo + TextureView + menos capas.
  final bool lowGlCompat;

  /// Motos del grupo (excepto la tuya) visibles mientras navegas.
  final List<HudGroupMate> groupMates;
  final ValueChanged<MapLibreMapController>? onControllerReady;

  /// Aviso cuando el usuario deja de seguir la posición (arrastre) o se recentra.
  final ValueChanged<bool>? onCameraFollowChanged;

  bool get _isPreview => cameraMode == NavigationMapCameraMode.fitRoute;

  @override
  State<NavigationMapView> createState() => _NavigationMapViewState();
}

class _NavigationMapViewState extends State<NavigationMapView> {
  static const _routeSourceId = 'locmotos-route';
  static const _routeCasingLayerId = 'locmotos-route-casing';
  static const _routeLineLayerId = 'locmotos-route-line';
  static const _traveledSourceId = 'locmotos-traveled';
  static const _traveledCasingLayerId = 'locmotos-traveled-casing';
  static const _traveledLineLayerId = 'locmotos-traveled-line';
  static const _altsSourceId = 'locmotos-alts';
  static const _altsCasingLayerId = 'locmotos-alts-casing';
  static const _altsLineLayerId = 'locmotos-alts-line';
  static const _routeLabelsSourceId = 'locmotos-route-labels';
  static const _routeLabelsLayerId = 'locmotos-route-labels-text';
  static const _etaSourceId = 'locmotos-eta';
  static const _etaLayerId = 'locmotos-eta-text';
  static const _etaPillSelectedId = 'locmotos-eta-pill';
  static const _etaPillAltId = 'locmotos-eta-pill-alt';
  static const _alertsSourceId = 'locmotos-alerts';
  static const _alertsSymbolLayerId = 'locmotos-alerts-symbol';
  static const _alertIconCameraId = 'locmotos-alert-camera';
  static const _alertIconRadarFixedId = 'locmotos-alert-radar-fixed';
  static const _alertIconRadarSectionId = 'locmotos-alert-radar-section';
  static const _alertIconRadarTrailerId = 'locmotos-alert-radar-trailer';
  static const _alertIconFuelId = 'locmotos-alert-fuel';
  static const _alertIconTollId = 'locmotos-alert-toll';
  static const _alertIconCurveId = 'locmotos-alert-curve';
  static const _puckIconImageId = 'locmotos-nav-puck-icon-v2';
  static const _groupMateIconId = 'locmotos-hud-group-mate';
  static const _groupMateStaleIconId = 'locmotos-hud-group-mate-stale';
  static const _groupMateColor = Color(0xFFE65100);
  static const _groupMateStaleColor = Color(0xFF78909C);

  /// Refs tipo A-23 / N-234 / CV-624 / AP-7 (no calles largas).
  static final _roadRefPattern = RegExp(
    r'\b([A-ZÁÉÍÓÚÜÑ]{1,3}[-\s]?\d[\w-]*)',
    caseSensitive: false,
  );

  MapLibreMapController? _controller;
  Circle? _puck;
  Circle? _puckHalo;
  Symbol? _puckSymbol;
  NavigationPuckStyle? _loadedPuckStyle;
  final _groupMateSymbols = <String, Symbol>{};
  var _groupMateIconsReady = false;
  final List<Circle> _endpointMarkers = [];
  var _routeDrawn = false;
  var _routeLayersReady = false;
  var _etaPillsReady = false;
  var _alertIconsReady = false;
  /// Evita dos `_drawRoute` concurrentes (p. ej. onMapCreated + onStyleLoaded).
  var _drawRouteBusy = false;
  var _drawRouteQueued = false;
  var _lastCameraTarget = const LatLng(0, 0);
  var _cameraReady = false;
  /// En preview: solo un encuadre inicial; no reajustar al soltar el dedo.
  var _hasFittedPreview = false;
  /// El usuario pidió “mi ubicación”: no volver a encuadrar toda la ruta.
  var _previewFocusOnUser = false;
  var _mapConfigured = false;
  var _styleSwitching = false;
  Timer? _styleDebounce;
  var _styleVeilOpacity = 0.0;
  var _awaitingStyleFadeOut = false;
  /// Evita confundir un animateCamera nuestro con un pan del usuario.
  var _programmaticCameraMove = false;
  late String _activeStyle;
  var _allowMapMount = true;

  LatLng get _fallbackTarget {
    final origin = widget.route.origin;
    return LatLng(origin.lat, origin.lng);
  }

  LatLng get _cameraTarget {
    final lat = widget.latitude;
    final lng = widget.longitude;
    if (lat != null && lng != null) {
      return LatLng(lat, lng);
    }
    return _fallbackTarget;
  }

  bool get _effectiveShow3dBuildings =>
      widget.show3dBuildings && !widget.lowGlCompat;

  double get _effectivePitch => widget.lowGlCompat ? 0 : widget.pitch;

  /// En preview con red usamos siempre el mapa online: el encuadre puede
  /// abarcar varias CCAA y un PMTiles regional deja zonas sin teselas (gris).
  String _resolveActiveStyle(LatLng point) {
    if (widget.lowGlCompat) {
      return NavigationMapStyleService.lowGlCompatStyle(
        dark: widget.preferDarkMap,
      );
    }
    if (widget._isPreview && widget.hasNetwork) {
      if (widget.preferDarkMap) {
        return widget.mapStyles.onlineStyleDark ?? widget.mapStyles.onlineStyle;
      }
      return widget.mapStyles.onlineStyle;
    }
    return widget.mapStyles.resolve(
      point.latitude,
      point.longitude,
      hasNetwork: widget.hasNetwork,
      preferDark: widget.preferDarkMap,
    );
  }

  @override
  void initState() {
    super.initState();
    _activeStyle = _resolveActiveStyle(_cameraTarget);
    if (widget.lowGlCompat) {
      _allowMapMount = false;
      Future<void>.delayed(const Duration(milliseconds: 350), () {
        if (mounted) {
          setState(() => _allowMapMount = true);
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant NavigationMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mapStyles != widget.mapStyles ||
        oldWidget.hasNetwork != widget.hasNetwork ||
        oldWidget.preferDarkMap != widget.preferDarkMap ||
        oldWidget.lowGlCompat != widget.lowGlCompat) {
      // Usar el centro de cámara real (en preview no es el origen de la ruta).
      if (oldWidget.preferDarkMap != widget.preferDarkMap) {
        _loadedPuckStyle = null;
        unawaited(_resetPuckAnnotations());
      }
      unawaited(_syncStyleForVisiblePoint());
    }
    if (_controller == null) {
      return;
    }
    if (!_sameGroupMates(oldWidget.groupMates, widget.groupMates)) {
      unawaited(_syncGroupMates());
    }
    final routeChanged = oldWidget.route.id != widget.route.id;
    final alertsChanged = !_sameAlertIds(
      oldWidget.route.alerts,
      widget.route.alerts,
    );
    final altsChanged = !_sameRouteIds(
      oldWidget.alternativeRoutes,
      widget.alternativeRoutes,
    );
    if (routeChanged || altsChanged || alertsChanged) {
      final oldIds = {
        oldWidget.route.id,
        ...oldWidget.alternativeRoutes.map((r) => r.id),
      };
      final newIds = {
        widget.route.id,
        ...widget.alternativeRoutes.map((r) => r.id),
      };
      final samePlan =
          oldIds.length == newIds.length && oldIds.containsAll(newIds);
      if (!samePlan) {
        _hasFittedPreview = false;
        _previewFocusOnUser = false;
        _cameraReady = false;
      }
      unawaited(_drawRoute());
      return;
    }
    if (oldWidget.alertPreferences != widget.alertPreferences) {
      unawaited(_syncAlertsSource());
    }
    if (oldWidget.puckStyle != widget.puckStyle) {
      unawaited(_resetPuckAnnotations());
    }
    if (widget._isPreview &&
        oldWidget.previewFocusEpoch != widget.previewFocusEpoch &&
        widget.previewFocusLatitude != null &&
        widget.previewFocusLongitude != null) {
      _previewFocusOnUser = true;
      _hasFittedPreview = true;
      unawaited(_moveCamera(animate: true));
      return;
    }
    if (!_routeDrawn || widget._isPreview) {
      return;
    }
    if (oldWidget.pitch != widget.pitch && widget.cameraFollowUser) {
      unawaited(_moveCamera(animate: true));
      unawaited(_syncPuck());
      if (oldWidget.show3dBuildings != widget.show3dBuildings ||
          oldWidget.lowGlCompat != widget.lowGlCompat) {
        unawaited(_sync3dBuildings());
      }
      return;
    }
    if (oldWidget.show3dBuildings != widget.show3dBuildings ||
        oldWidget.lowGlCompat != widget.lowGlCompat) {
      unawaited(_sync3dBuildings());
    }
    final followResumed =
        !oldWidget.cameraFollowUser && widget.cameraFollowUser;
    final followForced =
        widget.cameraFollowUser &&
        oldWidget.cameraFollowEpoch != widget.cameraFollowEpoch;
    if (followResumed || followForced) {
      unawaited(_moveCamera(animate: true));
      unawaited(_syncPuck());
      return;
    }
    _syncCamera(oldWidget);
    unawaited(_syncPuck());
    // En HUD: al avanzar, actualizar qué avisos (próximos 1–2) se muestran.
    if (oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude) {
      unawaited(_syncRouteProgress());
      unawaited(_syncAlertsSource());
      unawaited(_syncStyleForVisiblePoint());
    } else if ((oldWidget.speedMps - widget.speedMps).abs() > 1.5 &&
        widget.cameraFollowUser) {
      // Zoom dinámico al cambiar de ritmo (ciudad ↔ carretera).
      unawaited(_moveCamera(animate: true));
    }
  }

  @override
  void dispose() {
    _styleDebounce?.cancel();
    super.dispose();
  }

  Future<void> _onMapCreated(MapLibreMapController controller) async {
    _controller = controller;
    widget.onControllerReady?.call(controller);
    await _syncStyleForVisiblePoint();
    await _drawRoute();
  }

  Future<void> _onStyleLoaded() async {
    _routeDrawn = false;
    _routeLayersReady = false;
    _etaPillsReady = false;
    _alertIconsReady = false;
    _puck = null;
    _puckHalo = null;
    _puckSymbol = null;
    _loadedPuckStyle = null;
    _groupMateSymbols.clear();
    _groupMateIconsReady = false;
    _endpointMarkers.clear();
    _mapConfigured = false;
    _styleSwitching = false;
    await _configureMap();
    await _drawRoute();
  }

  Future<void> _onCameraIdle() async {
    if (_styleSwitching) {
      return;
    }
    await _syncStyleForVisiblePoint();
    if (widget._isPreview || !widget.cameraFollowUser) {
      return;
    }
    if (_programmaticCameraMove) {
      _programmaticCameraMove = false;
      return;
    }
    final cam = _controller?.cameraPosition?.target;
    if (cam == null) {
      return;
    }
    final target = _cameraTarget;
    final awayMeters = _haversineMetersLocal(
      GeoPoint(lat: cam.latitude, lng: cam.longitude),
      GeoPoint(lat: target.latitude, lng: target.longitude),
    );
    // El usuario ha arrastrado el mapa lejos de su posición.
    if (awayMeters > 55) {
      widget.onCameraFollowChanged?.call(false);
    }
  }

  LatLng _visiblePoint() {
    final camera = _controller?.cameraPosition?.target;
    if (camera != null) {
      return camera;
    }
    return _cameraTarget;
  }

  Future<void> _syncStyleForVisiblePoint() =>
      _syncStyleForPoint(_visiblePoint());

  Future<void> _syncStyleForPoint(LatLng point) async {
    final next = _resolveActiveStyle(point);
    if (next == _activeStyle || _styleSwitching || _awaitingStyleFadeOut) {
      return;
    }
    _styleDebounce?.cancel();
    if (widget._isPreview) {
      // Preview: cambio rápido (encuadres grandes / CCAA).
      _styleDebounce = Timer(const Duration(milliseconds: 200), () async {
        if (!mounted || _controller == null) {
          return;
        }
        final latest = _resolveActiveStyle(_visiblePoint());
        if (latest == _activeStyle) {
          return;
        }
        _activeStyle = latest;
        _styleSwitching = true;
        try {
          await _controller!.setStyle(latest);
        } catch (_) {
          _styleSwitching = false;
        }
      });
      return;
    }
    // HUD: fundido día↔noche / cambio de estilo.
    unawaited(_crossfadeToStyle(next));
  }

  Future<void> _crossfadeToStyle(String next) async {
    if (!mounted || _controller == null) {
      return;
    }
    final latest = _resolveActiveStyle(_visiblePoint());
    if (latest == _activeStyle) {
      return;
    }
    setState(() => _styleVeilOpacity = 1);
    await Future<void>.delayed(NavigationConstants.mapStyleCrossfadeIn);
    if (!mounted || _controller == null) {
      return;
    }
    final still = _resolveActiveStyle(_visiblePoint());
    if (still == _activeStyle) {
      if (mounted) {
        setState(() => _styleVeilOpacity = 0);
      }
      return;
    }
    _activeStyle = still;
    _styleSwitching = true;
    _awaitingStyleFadeOut = true;
    try {
      await _controller!.setStyle(still);
    } catch (_) {
      _styleSwitching = false;
      _awaitingStyleFadeOut = false;
      if (mounted) {
        setState(() => _styleVeilOpacity = 0);
      }
    }
  }

  void _finishStyleCrossfadeIfNeeded() {
    if (!_awaitingStyleFadeOut) {
      return;
    }
    _awaitingStyleFadeOut = false;
    if (!mounted) {
      return;
    }
    // Pequeño delay para que el basemap pinte antes de quitar el velo.
    Future<void>.delayed(const Duration(milliseconds: 80), () {
      if (mounted) {
        setState(() => _styleVeilOpacity = 0);
      }
    });
  }

  Future<void> _configureMap() async {
    final controller = _controller;
    if (controller == null || _mapConfigured || !mounted) {
      return;
    }

    final topInset = MediaQuery.paddingOf(context).top;
    if (widget._isPreview) {
      await controller.setPadding(
        top: topInset + NavigationConstants.routePreviewPaddingTop,
        bottom: NavigationConstants.routePreviewPaddingBottom +
            widget.fitBoundsBottomExtra,
      );
    } else {
      await controller.setPadding(
        top: topInset + NavigationConstants.mapPaddingTop,
        bottom: NavigationConstants.mapPaddingBottom,
      );
    }

    try {
      await controller.setMapLanguage('es');
    } catch (_) {}

    _mapConfigured = true;
    await _hideBasemapPois(controller);
    await _sync3dBuildings();
  }

  /// En navegación, menos clutter: ocultar POIs del basemap.
  Future<void> _hideBasemapPois(MapLibreMapController controller) async {
    if (widget._isPreview) {
      return;
    }
    try {
      final ids = await controller.getLayerIds();
      for (final raw in ids) {
        final id = raw?.toString() ?? '';
        final lower = id.toLowerCase();
        if (id.startsWith('locmotos-')) {
          continue;
        }
        if (lower.contains('poi') ||
            lower.contains('place_') ||
            lower == 'places_subplace' ||
            lower == 'pois') {
          try {
            await controller.setLayerProperties(
              id,
              const SymbolLayerProperties(visibility: 'none'),
            );
          } catch (_) {
            try {
              await controller.setLayerProperties(
                id,
                const FillLayerProperties(visibility: 'none'),
              );
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _drawRoute() async {
    if (_drawRouteBusy) {
      _drawRouteQueued = true;
      return;
    }
    _drawRouteBusy = true;
    try {
      do {
        _drawRouteQueued = false;
        await _drawRouteBody();
      } while (_drawRouteQueued && mounted);
    } finally {
      _drawRouteBusy = false;
    }
  }

  Future<void> _drawRouteBody() async {
    final controller = _controller;
    if (controller == null || widget.route.polyline.length < 2) {
      _finishStyleCrossfadeIfNeeded();
      return;
    }

    if (!_mapConfigured) {
      await _configureMap();
    }

    final routePolylines = _routeProgressPolylines();
    final selectedGeoJson = _routeGeoJson(routePolylines.remaining);
    final traveledGeoJson = _routeGeoJson(routePolylines.traveled);
    final altsGeoJson = _alternativesGeoJson(widget.alternativeRoutes);
    final labelsGeoJson = _routeStreetLabelsGeoJson(widget.route);
    final etaGeoJson = _etaLabelsGeoJson(
      selected: widget.route,
      alternatives: widget.alternativeRoutes,
    );
    final alertsGeoJson = _alertsGeoJson();

    if (_routeLayersReady) {
      try {
        await controller.setGeoJsonSource(_altsSourceId, altsGeoJson);
        await controller.setGeoJsonSource(_traveledSourceId, traveledGeoJson);
        await controller.setGeoJsonSource(_routeSourceId, selectedGeoJson);
        await controller.setGeoJsonSource(_routeLabelsSourceId, labelsGeoJson);
        await controller.setGeoJsonSource(_etaSourceId, etaGeoJson);
        await controller.setGeoJsonSource(_alertsSourceId, alertsGeoJson);
      } catch (_) {
        // Estilo/fuentes recreados: volver a crear capas.
        _routeLayersReady = false;
        _alertIconsReady = false;
      }
    }
    if (!_routeLayersReady) {
      await _clearRouteOverlayLayers(controller);
      await _addRouteLayersBelowLabels(
        controller,
        altsGeoJson: altsGeoJson,
        traveledGeoJson: traveledGeoJson,
        selectedGeoJson: selectedGeoJson,
        labelsGeoJson: labelsGeoJson,
        etaGeoJson: etaGeoJson,
        alertsGeoJson: alertsGeoJson,
      );
      _routeLayersReady = true;
    }

    if (widget._isPreview) {
      await _drawEndpointMarkers(controller);
    } else {
      await _syncPuck();
      await _syncGroupMates();
    }

    _routeDrawn = true;
    await _sync3dBuildings();
    _finishStyleCrossfadeIfNeeded();
    if (widget._isPreview) {
      if (_previewFocusOnUser || !_hasFittedPreview) {
        await _moveCamera(animate: true);
        _hasFittedPreview = true;
      }
    } else {
      await _moveCamera(animate: !_cameraReady);
      _cameraReady = true;
    }
  }

  /// Muestra/oculta fill-extrusion según [show3dBuildings] (añade/quita capa).
  Future<void> _sync3dBuildings() async {
    final controller = _controller;
    if (controller == null || !_mapConfigured) {
      return;
    }

    const layerId = NavigationMapStyleService.buildings3dLayerId;
    // OpenFreeMap trae building-3d; lo quitamos para no duplicar ni dejarlo en 2D.
    for (final id in [layerId, 'building-3d', 'building_3d', 'buildings-3d']) {
      try {
        await controller.removeLayer(id);
      } catch (_) {}
    }

    if (!_effectiveShow3dBuildings || widget._isPreview) {
      return;
    }

    List<String> sourceIds;
    try {
      sourceIds = await controller.getSourceIds();
    } catch (_) {
      return;
    }

    late final String sourceId;
    late final String sourceLayer;
    late final dynamic heightExpr;
    late final dynamic baseExpr;
    dynamic filter;
    if (sourceIds.contains('protomaps')) {
      sourceId = 'protomaps';
      sourceLayer = 'buildings';
      heightExpr = [
        'coalesce',
        ['get', 'height'],
        10,
      ];
      baseExpr = [
        'coalesce',
        ['get', 'min_height'],
        0,
      ];
      filter = [
        'in',
        'kind',
        'building',
        'building_part',
      ];
    } else if (sourceIds.contains('openmaptiles')) {
      sourceId = 'openmaptiles';
      sourceLayer = 'building';
      heightExpr = ['get', 'render_height'];
      baseExpr = ['get', 'render_min_height'];
    } else {
      return;
    }

    // Debajo de la ruta (si existe) o de la primera etiqueta del basemap.
    String? belowLayerId;
    try {
      final ids = (await controller.getLayerIds())
          .map((e) => e?.toString())
          .whereType<String>()
          .toSet();
      if (ids.contains(_altsCasingLayerId)) {
        belowLayerId = _altsCasingLayerId;
      } else if (ids.contains(_routeCasingLayerId)) {
        belowLayerId = _routeCasingLayerId;
      } else {
        belowLayerId = await _firstMapLabelLayerId(controller);
      }
    } catch (_) {}

    try {
      await controller.addFillExtrusionLayer(
        sourceId,
        layerId,
        FillExtrusionLayerProperties(
          fillExtrusionColor: '#c8c4bc',
          fillExtrusionOpacity: 0.72,
          fillExtrusionHeight: heightExpr,
          fillExtrusionBase: baseExpr,
          fillExtrusionVerticalGradient: true,
        ),
        sourceLayer: sourceLayer,
        minzoom: 14,
        belowLayerId: belowLayerId,
        filter: filter,
        enableInteraction: false,
      );
    } catch (_) {}
  }

  /// Quita capas/fuentes de ruta si ya existen (evita CannotAddLayerException).
  Future<void> _clearRouteOverlayLayers(MapLibreMapController controller) async {
    const layerIds = [
      _alertsSymbolLayerId,
      _etaLayerId,
      _routeLabelsLayerId,
      _routeLineLayerId,
      _routeCasingLayerId,
      _traveledLineLayerId,
      _traveledCasingLayerId,
      _altsLineLayerId,
      _altsCasingLayerId,
    ];
    const sourceIds = [
      _alertsSourceId,
      _etaSourceId,
      _routeLabelsSourceId,
      _routeSourceId,
      _traveledSourceId,
      _altsSourceId,
    ];
    for (final id in layerIds) {
      try {
        await controller.removeLayer(id);
      } catch (_) {}
    }
    for (final id in sourceIds) {
      try {
        await controller.removeSource(id);
      } catch (_) {}
    }
  }

  bool _sameRouteIds(List<NavigationRoute> a, List<NavigationRoute> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) {
        return false;
      }
    }
    return true;
  }

  bool _sameAlertIds(List<RouteAlert> a, List<RouteAlert> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) {
        return false;
      }
    }
    return true;
  }

  Future<void> _syncAlertsSource() async {
    final controller = _controller;
    if (controller == null || !_routeLayersReady) {
      return;
    }
    try {
      await controller.setGeoJsonSource(_alertsSourceId, _alertsGeoJson());
    } catch (_) {}
  }

  /// Preview: todos los POI de la ruta. HUD: solo los próximos 1–2.
  Map<String, dynamic> _alertsGeoJson() {
    final visible = _alertsForMap();
    return {
      'type': 'FeatureCollection',
      'features': [
        for (final alert in visible)
          {
            'type': 'Feature',
            'properties': {
              'kind': alert.type.name,
              'icon': switch (alert.type) {
                RouteAlertType.speedCamera => switch (alert.effectiveRadarKind) {
                    RadarKind.fixed => _alertIconRadarFixedId,
                    RadarKind.section => _alertIconRadarSectionId,
                    RadarKind.trailer => _alertIconRadarTrailerId,
                    RadarKind.unknown => _alertIconCameraId,
                  },
                RouteAlertType.fuel => _alertIconFuelId,
                RouteAlertType.toll => _alertIconTollId,
                RouteAlertType.sharpCurve => _alertIconCurveId,
              },
            },
            'geometry': {
              'type': 'Point',
              'coordinates': [alert.point.lng, alert.point.lat],
            },
          },
      ],
    };
  }

  List<RouteAlert> _alertsForMap() {
    final mapped = widget.route.alerts
        .where((a) => widget.alertPreferences.showTypeOnMap(a.type))
        .toList(growable: false);
    if (mapped.isEmpty) {
      return const [];
    }
    if (widget._isPreview) {
      return mapped;
    }
    final lat = widget.latitude;
    final lng = widget.longitude;
    if (lat == null || lng == null) {
      return mapped.take(2).toList(growable: false);
    }
    // Ordenados por distancia a lo largo de la ruta; mostrar solo los próximos
    // y descartar radares laterales (calles / sentido paralelo).
    final position = GeoPoint(lat: lat, lng: lng);
    final along = _approxAlongMeters(position);
    final slack = NavigationConstants.radarHudLateralSlackMeters;
    final ahead = <RouteAlert>[];
    for (final a in mapped) {
      if (a.distanceAlongRouteMeters < along - 40) {
        continue;
      }
      if (a.type == RouteAlertType.speedCamera &&
          !_radarPlausibleOnRoute(a, along, position, slack)) {
        continue;
      }
      ahead.add(a);
      if (ahead.length >= 2) {
        break;
      }
    }
    return ahead;
  }

  bool _radarPlausibleOnRoute(
    RouteAlert alert,
    double alongMeters,
    GeoPoint position,
    double lateralSlackMeters,
  ) {
    final remaining =
        (alert.distanceAlongRouteMeters - alongMeters).clamp(0.0, 1e9);
    final direct = _haversineMetersLocal(position, alert.point);
    final lateralSq = direct * direct - remaining * remaining;
    if (lateralSq <= 0) {
      return true;
    }
    return math.sqrt(lateralSq) <= lateralSlackMeters;
  }

  double _approxAlongMeters(GeoPoint position) {
    final polyline = widget.route.polyline;
    if (polyline.length < 2) {
      return 0;
    }
    var bestAlong = 0.0;
    var bestDist = double.infinity;
    var cumulative = 0.0;
    for (var i = 0; i < polyline.length - 1; i++) {
      final a = polyline[i];
      final b = polyline[i + 1];
      final seg = _haversineMetersLocal(a, b);
      final t = _projectT(position, a, b);
      final proj = GeoPoint(
        lat: a.lat + (b.lat - a.lat) * t,
        lng: a.lng + (b.lng - a.lng) * t,
      );
      final d = _haversineMetersLocal(position, proj);
      if (d < bestDist) {
        bestDist = d;
        bestAlong = cumulative + t * seg;
      }
      cumulative += seg;
    }
    return bestAlong;
  }

  double _projectT(GeoPoint p, GeoPoint a, GeoPoint b) {
    final dx = b.lng - a.lng;
    final dy = b.lat - a.lat;
    final len2 = dx * dx + dy * dy;
    if (len2 < 1e-18) {
      return 0;
    }
    return (((p.lng - a.lng) * dx + (p.lat - a.lat) * dy) / len2).clamp(0.0, 1.0);
  }

  double _haversineMetersLocal(GeoPoint a, GeoPoint b) {
    const r = 6371000.0;
    final dLat = (b.lat - a.lat) * math.pi / 180;
    final dLng = (b.lng - a.lng) * math.pi / 180;
    final lat1 = a.lat * math.pi / 180;
    final lat2 = b.lat * math.pi / 180;
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return 2 * r * math.asin(math.sqrt(h));
  }

  Map<String, dynamic> _routeGeoJson(List<GeoPoint> polyline) {
    final points = _displayPolyline(polyline);
    return {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'properties': <String, dynamic>{},
          'geometry': {
            'type': 'LineString',
            'coordinates': [
              for (final point in points) [point.lng, point.lat],
            ],
          },
        },
      ],
    };
  }

  /// En GLES débil, demasiados vértices en glBufferData provocan SIGSEGV.
  List<GeoPoint> _displayPolyline(List<GeoPoint> polyline) {
    if (!widget.lowGlCompat || polyline.length <= 400) {
      return polyline;
    }
    final step = (polyline.length / 400).ceil();
    final out = <GeoPoint>[
      for (var i = 0; i < polyline.length; i += step) polyline[i],
    ];
    if (out.isEmpty || out.last != polyline.last) {
      out.add(polyline.last);
    }
    return out;
  }

  Map<String, dynamic> _alternativesGeoJson(List<NavigationRoute> routes) {
    return {
      'type': 'FeatureCollection',
      'features': [
        for (final route in routes)
          if (route.polyline.length >= 2)
            {
              'type': 'Feature',
              'properties': {'id': route.id},
              'geometry': {
                'type': 'LineString',
                'coordinates': [
                  for (final point in route.polyline) [point.lng, point.lat],
                ],
              },
            },
      ],
    };
  }

  Map<String, dynamic> _etaLabelsGeoJson({
    required NavigationRoute selected,
    required List<NavigationRoute> alternatives,
  }) {
    final features = <Map<String, dynamic>>[];
    void add(NavigationRoute route, {required bool isSelected}) {
      if (route.polyline.length < 2) {
        return;
      }
      final coords = [
        for (final p in route.polyline) [p.lng, p.lat],
      ];
      final length = _lineLengthMeters(coords);
      if (length < 500) {
        return;
      }
      // Un poco desplazado del centro para no amontonar etiquetas.
      final along = isSelected ? length * 0.42 : length * 0.58;
      final point = _pointAlongLine(coords, along);
      features.add({
        'type': 'Feature',
        'properties': {
          'label': formatNavigationDurationCompact(route.durationSeconds),
          'selected': isSelected ? 1 : 0,
        },
        'geometry': {
          'type': 'Point',
          'coordinates': point,
        },
      });
    }

    for (final route in alternatives) {
      add(route, isSelected: false);
    }
    add(selected, isSelected: true);

    return {'type': 'FeatureCollection', 'features': features};
  }

  /// Etiquetas de carretera desde Valhalla (puntos), raleadas para el zoom de itinerario.
  Map<String, dynamic> _routeStreetLabelsGeoJson(NavigationRoute route) {
    final polyline = route.polyline;
    final maneuvers = route.maneuvers;
    if (polyline.length < 2 || maneuvers.isEmpty) {
      return {'type': 'FeatureCollection', 'features': <Map<String, dynamic>>[]};
    }

    // Candidatos: un punto por tramo continuo con ref (solo tramos “de verdad”).
    final candidates = <({String ref, double meters, List<double> point})>[];
    String? currentRef;
    var segmentStart = 0;
    var segmentEnd = 0;
    var segmentMeters = 0.0;

    void emit() {
      final ref = currentRef;
      // Ignora enlaces/rotondas cortos: saturan el mapa en Secundarias.
      if (ref == null || segmentEnd <= segmentStart || segmentMeters < 2500) {
        return;
      }
      final last =
          segmentEnd < polyline.length ? segmentEnd : polyline.length - 1;
      final coords = <List<double>>[
        for (var i = segmentStart; i <= last; i++)
          [polyline[i].lng, polyline[i].lat],
      ];
      if (coords.length < 2) {
        return;
      }
      final length = _lineLengthMeters(coords);
      if (length < 2500) {
        return;
      }
      // Una etiqueta por tramo; si es muy largo, otra a mitad del segundo tercio.
      final points = length >= 45000
          ? [
              _pointAlongLine(coords, length * 0.33),
              _pointAlongLine(coords, length * 0.66),
            ]
          : [_pointAlongLine(coords, length / 2)];
      for (final point in points) {
        candidates.add((ref: ref, meters: length, point: point));
      }
    }

    for (var i = 0; i < maneuvers.length; i++) {
      final m = maneuvers[i];
      // Preferir street_names; la instrucción añade ruido en salidas cortas.
      final ref = _extractRoadRef(m.streetName) ??
          (m.distanceMeters >= 800
              ? _extractRoadRef(m.instruction) ??
                  _extractRoadRef(m.voiceInstruction)
              : null);
      final start = m.beginShapeIndex.clamp(0, polyline.length - 1);
      final end = i + 1 < maneuvers.length
          ? maneuvers[i + 1].beginShapeIndex.clamp(0, polyline.length - 1)
          : polyline.length - 1;

      if (ref == null) {
        if (currentRef != null) {
          segmentEnd = end;
          segmentMeters += m.distanceMeters;
        }
        continue;
      }

      if (currentRef == ref) {
        segmentEnd = end;
        segmentMeters += m.distanceMeters;
      } else {
        emit();
        currentRef = ref;
        segmentStart = start;
        segmentEnd = end;
        segmentMeters = m.distanceMeters;
      }
    }
    emit();

    // Primero los tramos más largos; luego separación mínima entre etiquetas.
    candidates.sort((a, b) => b.meters.compareTo(a.meters));
    const minSeparationMeters = 22000.0;
    const maxLabels = 14;
    final kept = <({String ref, double meters, List<double> point})>[];
    for (final c in candidates) {
      if (kept.length >= maxLabels) {
        break;
      }
      final tooClose = kept.any(
        (k) =>
            _approxMeters(k.point[1], k.point[0], c.point[1], c.point[0]) <
            minSeparationMeters,
      );
      if (tooClose) {
        continue;
      }
      kept.add(c);
    }

    return {
      'type': 'FeatureCollection',
      'features': [
        for (final c in kept)
          {
            'type': 'Feature',
            'properties': {
              'ref': c.ref,
              // Sprites OpenFreeMap/Protomaps: road_1 … road_6
              'ref_length': c.ref.length.clamp(1, 6),
            },
            'geometry': {
              'type': 'Point',
              'coordinates': c.point,
            },
          },
      ],
    };
  }

  double _lineLengthMeters(List<List<double>> coords) {
    var total = 0.0;
    for (var i = 1; i < coords.length; i++) {
      total += _approxMeters(
        coords[i - 1][1],
        coords[i - 1][0],
        coords[i][1],
        coords[i][0],
      );
    }
    return total;
  }

  List<double> _pointAlongLine(List<List<double>> coords, double meters) {
    var remaining = meters;
    for (var i = 1; i < coords.length; i++) {
      final a = coords[i - 1];
      final b = coords[i];
      final seg = _approxMeters(a[1], a[0], b[1], b[0]);
      if (seg <= 0) {
        continue;
      }
      if (remaining <= seg) {
        final t = remaining / seg;
        return [
          a[0] + (b[0] - a[0]) * t,
          a[1] + (b[1] - a[1]) * t,
        ];
      }
      remaining -= seg;
    }
    return coords.last;
  }

  double _approxMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const metersPerDegLat = 111320.0;
    final midLatRad = ((lat1 + lat2) / 2) * (math.pi / 180);
    final cosLat = math.cos(midLatRad).abs().clamp(0.01, 1.0);
    final dy = (lat2 - lat1) * metersPerDegLat;
    final dx = (lng2 - lng1) * metersPerDegLat * cosLat;
    return math.sqrt(dx * dx + dy * dy);
  }

  String? _extractRoadRef(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final match = _roadRefPattern.firstMatch(raw);
    return match?.group(1)?.toUpperCase();
  }

  Future<void> _syncRouteProgress() async {
    final controller = _controller;
    if (controller == null ||
        !_routeLayersReady ||
        widget._isPreview ||
        widget.route.polyline.length < 2) {
      return;
    }
    final parts = _routeProgressPolylines();
    try {
      await controller.setGeoJsonSource(
        _traveledSourceId,
        _routeGeoJson(parts.traveled),
      );
      await controller.setGeoJsonSource(
        _routeSourceId,
        _routeGeoJson(parts.remaining),
      );
    } catch (_) {}
  }

  ({List<GeoPoint> traveled, List<GeoPoint> remaining})
      _routeProgressPolylines() {
    final poly = widget.route.polyline;
    final lat = widget.latitude;
    final lng = widget.longitude;
    if (widget._isPreview || lat == null || lng == null || poly.length < 2) {
      return (traveled: const <GeoPoint>[], remaining: poly);
    }
    return splitRoutePolyline(poly, lat, lng);
  }

  double get _navigationCameraZoom =>
      NavigationConstants.navigationZoomForSpeedMps(widget.speedMps);

  double get _navigationCameraBearing {
    final lat = widget.latitude;
    final lng = widget.longitude;
    if (lat == null || lng == null || widget._isPreview) {
      return widget.bearing;
    }
    return resolveLookAheadBearing(
      lat: lat,
      lng: lng,
      headingDegrees: widget.bearing,
      polyline: widget.route.polyline,
      lookAheadMeters: NavigationConstants.cameraLookAheadMeters,
    );
  }

  /// Inclinación base (3D) + boost suave si hay curva por delante.
  double get _navigationCameraPitch {
    final base = _effectivePitch;
    if (base <= 0.5 || widget._isPreview) {
      return 0;
    }
    final lat = widget.latitude;
    final lng = widget.longitude;
    if (lat == null || lng == null || widget.route.polyline.length < 2) {
      return base;
    }
    final ahead = resolveLookAheadBearing(
      lat: lat,
      lng: lng,
      headingDegrees: widget.bearing,
      polyline: widget.route.polyline,
      lookAheadMeters: NavigationConstants.cameraLookAheadMeters,
      blend: 1,
    );
    final turn = shortestBearingDelta(widget.bearing, ahead).abs();
    // Recto ≈ sin boost; a partir de ~8° de giro sube hasta +12°.
    final t = ((turn - 8) / 40).clamp(0.0, 1.0);
    return (base + t * NavigationConstants.cameraLookAheadPitchBoost)
        .clamp(0.0, 55.0);
  }

  /// Línea bajo textos del mapa; refs de ruta encima de la línea azul.
  Future<void> _addRouteLayersBelowLabels(
    MapLibreMapController controller, {
    required Map<String, dynamic> altsGeoJson,
    required Map<String, dynamic> traveledGeoJson,
    required Map<String, dynamic> selectedGeoJson,
    required Map<String, dynamic> labelsGeoJson,
    required Map<String, dynamic> etaGeoJson,
    required Map<String, dynamic> alertsGeoJson,
  }) async {
    final belowLayerId = await _firstMapLabelLayerId(controller);

    await controller.addGeoJsonSource(_altsSourceId, altsGeoJson);
    await controller.addLineLayer(
      _altsSourceId,
      _altsCasingLayerId,
      const LineLayerProperties(
        lineColor: '#FFFFFF',
        lineWidth: 10,
        lineOpacity: 0.7,
        lineJoin: 'round',
      ),
      belowLayerId: belowLayerId,
      enableInteraction: false,
    );
    await controller.addLineLayer(
      _altsSourceId,
      _altsLineLayerId,
      const LineLayerProperties(
        lineColor: '#90CAF9',
        lineWidth: 6,
        lineOpacity: 0.95,
        lineJoin: 'round',
      ),
      belowLayerId: belowLayerId,
      enableInteraction: false,
    );

    // Tramo ya recorrido (atenuado), debajo de la ruta activa.
    final dark = widget.preferDarkMap;
    await controller.addGeoJsonSource(_traveledSourceId, traveledGeoJson);
    await controller.addLineLayer(
      _traveledSourceId,
      _traveledCasingLayerId,
      LineLayerProperties(
        lineColor: dark ? '#15202b' : '#FFFFFF',
        lineWidth: 10,
        lineOpacity: dark ? 0.22 : 0.28,
        lineJoin: 'round',
      ),
      belowLayerId: belowLayerId,
      enableInteraction: false,
    );
    await controller.addLineLayer(
      _traveledSourceId,
      _traveledLineLayerId,
      LineLayerProperties(
        lineColor: dark ? '#3a5068' : '#90CAF9',
        lineWidth: 6,
        lineOpacity: dark ? 0.28 : 0.35,
        lineJoin: 'round',
      ),
      belowLayerId: belowLayerId,
      enableInteraction: false,
    );

    await controller.addGeoJsonSource(_routeSourceId, selectedGeoJson);
    await controller.addLineLayer(
      _routeSourceId,
      _routeCasingLayerId,
      LineLayerProperties(
        lineColor: dark ? '#0f1822' : '#FFFFFF',
        lineWidth: 13,
        lineOpacity: dark ? 0.55 : 0.92,
        lineJoin: 'round',
        lineBlur: 0.4,
      ),
      belowLayerId: belowLayerId,
      enableInteraction: false,
    );
    await controller.addLineLayer(
      _routeSourceId,
      _routeLineLayerId,
      LineLayerProperties(
        lineColor: dark ? '#3B8DD9' : '#1A73E8',
        lineWidth: 8,
        lineOpacity: dark ? 0.82 : 0.88,
        lineJoin: 'round',
      ),
      belowLayerId: belowLayerId,
      enableInteraction: false,
    );

    await controller.addGeoJsonSource(_routeLabelsSourceId, labelsGeoJson);
    // Mismo aspecto que highway-shield del basemap (caja blanca + texto negro).
    await controller.addSymbolLayer(
      _routeLabelsSourceId,
      _routeLabelsLayerId,
      SymbolLayerProperties(
        iconImage: const [
          Expressions.concat,
          'road_',
          [
            Expressions.toStringExpression,
            [Expressions.get, 'ref_length'],
          ],
        ],
        iconSize: 1,
        iconRotationAlignment: 'viewport',
        iconAllowOverlap: false,
        iconIgnorePlacement: false,
        iconOptional: true,
        textField: const [Expressions.get, 'ref'],
        textSize: 10,
        textColor: '#000000',
        textHaloColor: '#ffffff',
        textHaloWidth: 1.2,
        textFont: const ['Noto Sans Regular'],
        textRotationAlignment: 'viewport',
        textAllowOverlap: false,
        textIgnorePlacement: false,
        textOptional: false,
        textAnchor: 'center',
        symbolPlacement: 'point',
      ),
      enableInteraction: false,
    );

    await controller.addGeoJsonSource(_etaSourceId, etaGeoJson);
    await _ensureEtaPillImages(controller);
    // Pastilla blanca + texto oscuro (legible sobre la línea azul).
    await controller.addSymbolLayer(
      _etaSourceId,
      _etaLayerId,
      SymbolLayerProperties(
        iconImage: const [
          Expressions.caseExpression,
          [
            Expressions.equal,
            [Expressions.get, 'selected'],
            1,
          ],
          _etaPillSelectedId,
          _etaPillAltId,
        ],
        iconTextFit: 'both',
        iconTextFitPadding: const [5.0, 10.0, 5.0, 10.0],
        iconAllowOverlap: true,
        iconIgnorePlacement: true,
        iconOptional: true,
        textField: const [Expressions.get, 'label'],
        textSize: const [
          Expressions.interpolate,
          ['linear'],
          [Expressions.zoom],
          5,
          11,
          10,
          13,
        ],
        textColor: '#202124',
        textHaloColor: '#ffffff',
        textHaloWidth: 1.5,
        textFont: const ['Noto Sans Regular'],
        textAllowOverlap: true,
        textIgnorePlacement: true,
        textOptional: false,
        textAnchor: 'center',
        symbolPlacement: 'point',
      ),
      enableInteraction: false,
    );

    await controller.addGeoJsonSource(_alertsSourceId, alertsGeoJson);
    await _ensureAlertIconImages(controller);
    // Iconos discretos (radar / gasolinera / peaje). El precio sale en el HUD al acercarte.
    await controller.addSymbolLayer(
      _alertsSourceId,
      _alertsSymbolLayerId,
      const SymbolLayerProperties(
        iconImage: [Expressions.get, 'icon'],
        iconSize: 0.55,
        iconAllowOverlap: true,
        iconIgnorePlacement: true,
        iconAnchor: 'center',
        symbolPlacement: 'point',
      ),
      enableInteraction: false,
    );
  }

  Future<void> _ensureAlertIconImages(MapLibreMapController controller) async {
    if (_alertIconsReady) {
      return;
    }
    try {
      await controller.addImage(
        _alertIconCameraId,
        await _buildAlertMarkerPng(
          icon: Icons.photo_camera_rounded,
          background: Color(RadarKind.unknown.mapColorArgb),
        ),
      );
      await controller.addImage(
        _alertIconRadarFixedId,
        await _buildAlertMarkerPng(
          icon: Icons.photo_camera_rounded,
          background: Color(RadarKind.fixed.mapColorArgb),
        ),
      );
      await controller.addImage(
        _alertIconRadarSectionId,
        await _buildAlertMarkerPng(
          icon: Icons.speed_rounded,
          background: Color(RadarKind.section.mapColorArgb),
        ),
      );
      await controller.addImage(
        _alertIconRadarTrailerId,
        await _buildAlertMarkerPng(
          icon: Icons.rv_hookup_rounded,
          background: Color(RadarKind.trailer.mapColorArgb),
        ),
      );
      await controller.addImage(
        _alertIconFuelId,
        await _buildAlertMarkerPng(
          icon: Icons.local_gas_station_rounded,
          background: const Color(0xFFEF6C00),
        ),
      );
      await controller.addImage(
        _alertIconTollId,
        await _buildAlertMarkerPng(
          icon: Icons.toll_rounded,
          background: const Color(0xFF6A1B9A),
        ),
      );
      await controller.addImage(
        _alertIconCurveId,
        await _buildAlertMarkerPng(
          icon: Icons.turn_sharp_right_rounded,
          background: const Color(0xFF00897B),
        ),
      );
      _alertIconsReady = true;
    } catch (_) {
      // Sin iconos: los avisos siguen en chips / HUD.
    }
  }

  /// Marcador circular con icono Material (estilo app de navegación).
  Future<Uint8List> _buildAlertMarkerPng({
    required IconData icon,
    required Color background,
  }) async {
    const size = 96.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = const Offset(size / 2, size / 2);

    canvas.drawCircle(
      center,
      size / 2 - 2,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawCircle(center, size / 2 - 6, Paint()..color = background);
    canvas.drawCircle(
      center,
      size / 2 - 6,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );

    final textPainter = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: 46,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: Colors.white,
        ),
      )
      ..layout();
    textPainter.paint(
      canvas,
      Offset(
        (size - textPainter.width) / 2,
        (size - textPainter.height) / 2,
      ),
    );

    final image =
        await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  Future<void> _ensureEtaPillImages(MapLibreMapController controller) async {
    if (_etaPillsReady) {
      return;
    }
    try {
      await controller.addImage(
        _etaPillSelectedId,
        await _buildEtaPillPng(
          fill: const Color(0xFFFFFFFF),
          stroke: const Color(0xFF1A73E8),
        ),
      );
      await controller.addImage(
        _etaPillAltId,
        await _buildEtaPillPng(
          fill: const Color(0xFFF8F9FA),
          stroke: const Color(0xFF9AA0A6),
        ),
      );
      _etaPillsReady = true;
    } catch (_) {
      // Sin pastilla: el texto sigue siendo usable con halo.
    }
  }

  Future<Uint8List> _buildEtaPillPng({
    required Color fill,
    required Color stroke,
  }) async {
    const width = 72.0;
    const height = 32.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final rect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(1.5, 1.5, width - 3, height - 3),
      const Radius.circular(10),
    );
    canvas.drawRRect(rect, Paint()..color = fill);
    canvas.drawRRect(
      rect,
      Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    final image = await recorder.endRecording().toImage(
      width.toInt(),
      height.toInt(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  /// Primera capa de texto/escudo/pueblo (abajo→arriba) para meter la ruta debajo.
  Future<String?> _firstMapLabelLayerId(
    MapLibreMapController controller,
  ) async {
    try {
      final ids = await controller.getLayerIds();
      for (final raw in ids) {
        final id = raw?.toString();
        if (id != null && _looksLikeMapLabelLayer(id)) {
          return id;
        }
      }
    } catch (_) {}
    return null;
  }

  bool _looksLikeMapLabelLayer(String id) {
    if (id.startsWith('locmotos-')) {
      return false;
    }
    final lower = id.toLowerCase();
    return lower.contains('label') ||
        lower.contains('name') ||
        lower.contains('place') ||
        lower.contains('shield') ||
        lower.contains('ref') ||
        lower.contains('poi');
  }

  Future<void> _resetPuckAnnotations() async {
    final controller = _controller;
    if (controller != null) {
      try {
        if (_puckSymbol != null) {
          await controller.removeSymbol(_puckSymbol!);
        }
        if (_puck != null) {
          await controller.removeCircle(_puck!);
        }
        if (_puckHalo != null) {
          await controller.removeCircle(_puckHalo!);
        }
      } catch (_) {}
    }
    _puckSymbol = null;
    _puck = null;
    _puckHalo = null;
    _loadedPuckStyle = null;
    await _syncPuck();
  }

  /// Marcador de posición de navegación (GPS o simulación).
  Future<void> _syncPuck() async {
    final controller = _controller;
    final lat = widget.latitude;
    final lng = widget.longitude;
    if (controller == null || widget._isPreview || lat == null || lng == null) {
      return;
    }

    final geometry = LatLng(lat, lng);
    final style = widget.puckStyle;
    if (style != null) {
      await _syncCustomPuck(
        controller: controller,
        geometry: geometry,
        style: style,
      );
      return;
    }

    // Sin vehículo / sin icono: puck azul clásico.
    if (_puckSymbol != null) {
      try {
        await controller.removeSymbol(_puckSymbol!);
      } catch (_) {}
      _puckSymbol = null;
      _loadedPuckStyle = null;
    }

    const haloOptions = CircleOptions(
      circleRadius: 18,
      circleColor: '#1A73E8',
      circleOpacity: 0.22,
      circleStrokeWidth: 0,
    );
    const puckOptions = CircleOptions(
      circleRadius: 9,
      circleColor: '#1A73E8',
      circleStrokeWidth: 3,
      circleStrokeColor: '#FFFFFF',
      circleOpacity: 1,
    );

    if (_puckHalo == null) {
      final circles = await controller.addCircles([
        haloOptions.copyWith(CircleOptions(geometry: geometry)),
        puckOptions.copyWith(CircleOptions(geometry: geometry)),
      ]);
      if (circles.length >= 2) {
        _puckHalo = circles[0];
        _puck = circles[1];
      }
      return;
    }

    await controller.updateCircle(
      _puckHalo!,
      haloOptions.copyWith(CircleOptions(geometry: geometry)),
    );
    if (_puck != null) {
      await controller.updateCircle(
        _puck!,
        puckOptions.copyWith(CircleOptions(geometry: geometry)),
      );
    }
  }

  Future<void> _syncCustomPuck({
    required MapLibreMapController controller,
    required LatLng geometry,
    required NavigationPuckStyle style,
  }) async {
    // Un solo Symbol limpio (sin círculo aparte).
    if (_puck != null || _puckHalo != null) {
      try {
        if (_puck != null) {
          await controller.removeCircle(_puck!);
        }
        if (_puckHalo != null) {
          await controller.removeCircle(_puckHalo!);
        }
      } catch (_) {}
      _puck = null;
      _puckHalo = null;
    }

    if (_loadedPuckStyle != style) {
      try {
        await controller.addImage(
          _puckIconImageId,
          await _buildNavPuckPng(style: style),
        );
        _loadedPuckStyle = style;
      } catch (_) {
        _loadedPuckStyle = null;
        return;
      }
      if (_puckSymbol != null) {
        try {
          await controller.removeSymbol(_puckSymbol!);
        } catch (_) {}
        _puckSymbol = null;
      }
    }

    final symbolOptions = SymbolOptions(
      geometry: geometry,
      iconImage: _puckIconImageId,
      iconSize: 1.35,
      // Los symbols usan icon-rotation-alignment≈viewport: el ángulo es
      // relativo a la pantalla. La cámara ya va en rumbo de marcha →
      // iconRotate = bearing haría doble rotación (moto “de lado”).
      iconRotate: _puckIconRotateDegrees(controller),
      iconAnchor: 'center',
      zIndex: 20,
    );

    if (_puckSymbol == null) {
      await _enableOverlappingSymbols(controller);
      _puckSymbol = await controller.addSymbol(symbolOptions);
    } else {
      await controller.updateSymbol(_puckSymbol!, symbolOptions);
    }
  }

  /// Rumbo del icono respecto a la pantalla (morro del PNG = arriba).
  double _puckIconRotateDegrees(MapLibreMapController controller) {
    // Seguimiento HUD: la cámara ya orienta el mapa; el vehículo mira “arriba”.
    if (widget.cameraFollowUser) {
      return 0;
    }
    final cameraBearing =
        controller.cameraPosition?.bearing ?? widget.bearing;
    var delta = widget.bearing - cameraBearing;
    while (delta > 180) {
      delta -= 360;
    }
    while (delta < -180) {
      delta += 360;
    }
    return delta;
  }

  bool _sameGroupMates(List<HudGroupMate> a, List<HudGroupMate> b) {
    if (identical(a, b)) {
      return true;
    }
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  Future<void> _ensureGroupMateIcons(MapLibreMapController controller) async {
    if (_groupMateIconsReady) {
      return;
    }
    try {
      await _enableOverlappingSymbols(controller);
      await controller.addImage(
        _groupMateIconId,
        await VehicleNavigationMarker.toPng(
          icon: VehicleMapIcon.motorcycle,
          color: _groupMateColor,
          logicalSize: 110,
        ),
      );
      await controller.addImage(
        _groupMateStaleIconId,
        await VehicleNavigationMarker.toPng(
          icon: VehicleMapIcon.motorcycle,
          color: _groupMateStaleColor,
          logicalSize: 110,
        ),
      );
      _groupMateIconsReady = true;
    } catch (_) {
      _groupMateIconsReady = false;
    }
  }

  Future<void> _enableOverlappingSymbols(MapLibreMapController controller) async {
    try {
      await controller.setSymbolIconAllowOverlap(true);
      await controller.setSymbolTextAllowOverlap(true);
      await controller.setSymbolIconIgnorePlacement(true);
      await controller.setSymbolTextIgnorePlacement(true);
    } catch (_) {}
  }

  /// Compañeros de grupo sobre el mapa de navegación (más pequeños que el puck).
  Future<void> _syncGroupMates() async {
    final controller = _controller;
    if (controller == null || widget._isPreview) {
      return;
    }
    await _ensureGroupMateIcons(controller);
    if (!_groupMateIconsReady) {
      return;
    }

    final mates = widget.groupMates;
    final keep = mates.map((mate) => mate.uid).toSet();
    final removeUids =
        _groupMateSymbols.keys.where((uid) => !keep.contains(uid)).toList();
    for (final uid in removeUids) {
      final symbol = _groupMateSymbols.remove(uid);
      if (symbol == null) {
        continue;
      }
      try {
        await controller.removeSymbol(symbol);
      } catch (_) {}
    }

    final cameraBearing = controller.cameraPosition?.bearing ?? widget.bearing;
    final ownLat = widget.latitude;
    final ownLng = widget.longitude;
    final placed = <({double lat, double lng})>[
      if (ownLat != null && ownLng != null) (lat: ownLat, lng: ownLng),
    ];

    for (final mate in mates) {
      var stackIndex = 0;
      for (final previous in placed) {
        final meters = _haversineMetersLocal(
          GeoPoint(lat: mate.lat, lng: mate.lng),
          GeoPoint(lat: previous.lat, lng: previous.lng),
        );
        if (meters < 35) {
          stackIndex++;
        }
      }
      placed.add((lat: mate.lat, lng: mate.lng));

      var iconRotate = 0.0;
      if (mate.heading.isFinite && mate.heading.abs() > 8) {
        var delta = mate.heading - cameraBearing;
        while (delta > 180) {
          delta -= 360;
        }
        while (delta < -180) {
          delta += 360;
        }
        iconRotate = delta;
      }
      // GPS real: apilar solo el dibujo hacia arriba si coinciden.
      final options = SymbolOptions(
        geometry: LatLng(mate.lat, mate.lng),
        iconImage: mate.isStale ? _groupMateStaleIconId : _groupMateIconId,
        iconSize: mate.isStale ? 0.75 : 0.9,
        iconRotate: iconRotate,
        iconAnchor: 'center',
        iconOffset: Offset(0, -1.15 * stackIndex),
        textField: mate.label,
        textSize: 11,
        textColor: mate.isStale ? '#C62828' : '#E65100',
        textHaloColor: '#FFFFFF',
        textHaloWidth: 1.2,
        textOffset:
            stackIndex > 0 ? const Offset(1.35, 0.15) : const Offset(0, 1.55),
        textAnchor: stackIndex > 0 ? 'left' : 'top',
        zIndex: 1 + stackIndex,
      );
      final existing = _groupMateSymbols[mate.uid];
      if (existing == null) {
        try {
          _groupMateSymbols[mate.uid] = await controller.addSymbol(options);
        } catch (_) {}
      } else {
        try {
          await controller.updateSymbol(existing, options);
        } catch (_) {}
      }
    }
  }

  /// Silueta del vehículo (cenital) tintada con el color del marcador.
  Future<Uint8List> _buildNavPuckPng({
    required NavigationPuckStyle style,
  }) {
    return VehicleNavigationMarker.toPng(
      icon: style.icon,
      color: style.color,
      logicalSize: 160,
      nightMode: widget.preferDarkMap,
    );
  }

  Future<void> _drawEndpointMarkers(MapLibreMapController controller) async {
    if (_endpointMarkers.isNotEmpty) {
      return;
    }

    final origin = widget.route.origin;
    final destination = widget.route.destination;
    final options = <CircleOptions>[
      const CircleOptions(
        circleRadius: 9,
        circleColor: '#2E7D32',
        circleStrokeWidth: 2.5,
        circleStrokeColor: '#FFFFFF',
      ).copyWith(
        CircleOptions(geometry: LatLng(origin.lat, origin.lng)),
      ),
      for (final via in widget.route.waypoints)
        const CircleOptions(
          circleRadius: 8,
          circleColor: '#F9A825',
          circleStrokeWidth: 2.5,
          circleStrokeColor: '#FFFFFF',
        ).copyWith(
          CircleOptions(geometry: LatLng(via.lat, via.lng)),
        ),
      const CircleOptions(
        circleRadius: 9,
        circleColor: '#C62828',
        circleStrokeWidth: 2.5,
        circleStrokeColor: '#FFFFFF',
      ).copyWith(
        CircleOptions(geometry: LatLng(destination.lat, destination.lng)),
      ),
    ];
    final markers = await controller.addCircles(options);
    _endpointMarkers.addAll(markers);
  }

  Future<void> _syncCamera(NavigationMapView oldWidget) async {
    if (!widget.cameraFollowUser) {
      return;
    }
    final moved = oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude;
    final rotated = (oldWidget.bearing - widget.bearing).abs() > 2;
    if (!moved && !rotated) {
      return;
    }
    await _moveCamera(animate: true);
  }

  Future<void> _moveCamera({required bool animate}) async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    if (!widget._isPreview && !widget.cameraFollowUser) {
      return;
    }

    final CameraUpdate update;
    if (widget._isPreview) {
      final focusLat = widget.previewFocusLatitude;
      final focusLng = widget.previewFocusLongitude;
      if (_previewFocusOnUser && focusLat != null && focusLng != null) {
        final currentZoom = controller.cameraPosition?.zoom;
        update = CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(focusLat, focusLng),
            // Conserva el zoom del encuadre de la ruta o el que el usuario haya dejado.
            zoom: currentZoom ?? 12,
            bearing: controller.cameraPosition?.bearing ?? 0,
            tilt: 0,
          ),
        );
      } else {
        final bounds = boundsForPoints([
          widget.route.origin,
          widget.route.destination,
          ...widget.route.waypoints,
          ...widget.route.polyline,
          for (final alt in widget.alternativeRoutes) ...alt.polyline,
        ]);
        final horizontal = NavigationConstants.routePreviewPaddingHorizontal;
        update = CameraUpdate.newLatLngBounds(
          bounds,
          left: horizontal,
          top: NavigationConstants.routePreviewPaddingTop,
          right: horizontal,
          bottom: NavigationConstants.routePreviewPaddingBottom +
              widget.fitBoundsBottomExtra,
        );
      }
    } else {
      update = CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _cameraTarget,
          zoom: _navigationCameraZoom,
          bearing: _navigationCameraBearing,
          tilt: _navigationCameraPitch,
        ),
      );
    }

    _programmaticCameraMove = true;
    try {
      if (!animate) {
        await controller.moveCamera(update);
      } else if (widget._isPreview) {
        await controller.animateCamera(
          update,
          duration: const Duration(milliseconds: 700),
        );
      } else {
        final target = _cameraTarget;
        final deltaLat = (target.latitude - _lastCameraTarget.latitude).abs();
        final deltaLng = (target.longitude - _lastCameraTarget.longitude).abs();
        await controller.animateCamera(
          update,
          duration: Duration(
            milliseconds: deltaLat < 0.00001 && deltaLng < 0.00001 ? 280 : 650,
          ),
        );
        _lastCameraTarget = target;
        return;
      }

      if (!widget._isPreview) {
        _lastCameraTarget = _cameraTarget;
      }
    } finally {
      // Se limpia en onCameraIdle; si no llega, no bloquear el siguiente pan.
      Future<void>.delayed(const Duration(milliseconds: 800), () {
        _programmaticCameraMove = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPreview = widget._isPreview;
    final veilColor = widget.preferDarkMap
        ? const Color(0xFF0A0E14)
        : const Color(0xFF1A1F24);
    if (!_allowMapMount) {
      return ColoredBox(color: veilColor);
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        MapLibreMap(
          styleString: _activeStyle,
          initialCameraPosition: CameraPosition(
            target: _cameraTarget,
            zoom: isPreview ? 12 : _navigationCameraZoom,
            bearing: isPreview ? 0 : _navigationCameraBearing,
            tilt: isPreview ? 0 : _navigationCameraPitch,
          ),
          onMapCreated: _onMapCreated,
          onStyleLoadedCallback: _onStyleLoaded,
          onCameraIdle: _onCameraIdle,
          // Ruta = capas GeoJSON; no hace falta LineManager (taparía etiquetas).
          annotationOrder: const [
            AnnotationType.fill,
            AnnotationType.circle,
            AnnotationType.symbol,
          ],
          // En HUD usamos nuestro puck; en preview también (evita el botón/GPS nativo).
          myLocationEnabled: false,
          myLocationTrackingMode: MyLocationTrackingMode.none,
          myLocationRenderMode: MyLocationRenderMode.normal,
          compassEnabled: isPreview && !widget.lowGlCompat,
          rotateGesturesEnabled: isPreview && !widget.lowGlCompat,
          tiltGesturesEnabled: false,
          zoomGesturesEnabled: true,
          scrollGesturesEnabled: true,
          trackCameraPosition: true,
          translucentTextureSurface: widget.lowGlCompat,
        ),
        IgnorePointer(
          child: AnimatedOpacity(
            opacity: _styleVeilOpacity,
            duration: _styleVeilOpacity > 0.5
                ? NavigationConstants.mapStyleCrossfadeIn
                : NavigationConstants.mapStyleCrossfadeOut,
            curve: Curves.easeInOut,
            child: ColoredBox(color: veilColor),
          ),
        ),
      ],
    );
  }
}
