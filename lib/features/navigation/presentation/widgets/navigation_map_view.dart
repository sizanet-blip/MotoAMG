import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:loc_motos/core/constants/navigation_constants.dart';
import 'package:loc_motos/core/utils/navigation_duration_format.dart';
import 'package:loc_motos/features/navigation/domain/entities/geo_point.dart';
import 'package:loc_motos/features/navigation/domain/entities/hybrid_map_styles.dart';
import 'package:loc_motos/features/navigation/domain/entities/navigation_route.dart';
import 'package:loc_motos/features/navigation/domain/entities/route_alert.dart';
import 'package:loc_motos/features/navigation/presentation/helpers/route_map_bounds.dart';
import 'package:loc_motos/features/navigation/presentation/models/navigation_map_camera_mode.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

/// Mapa MapLibre: seguimiento en HUD o encuadre de ruta en vista previa.
///
/// Usa PMTiles offline dentro de la CCAA descargada y OpenFreeMap al salir.
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
    this.pitch = NavigationConstants.defaultMapPitch,
    this.cameraMode = NavigationMapCameraMode.followDevice,
    this.fitBoundsBottomExtra = 0,
    this.onControllerReady,
  });

  final NavigationRoute route;

  /// Otras opciones de ruta (vista previa); se pintan más claras.
  final List<NavigationRoute> alternativeRoutes;
  final HybridMapStyles mapStyles;
  final bool hasNetwork;
  final double? latitude;
  final double? longitude;
  final double bearing;
  final double pitch;
  final NavigationMapCameraMode cameraMode;
  final double fitBoundsBottomExtra;
  final ValueChanged<MapLibreMapController>? onControllerReady;

  bool get _isPreview => cameraMode == NavigationMapCameraMode.fitRoute;

  @override
  State<NavigationMapView> createState() => _NavigationMapViewState();
}

class _NavigationMapViewState extends State<NavigationMapView> {
  static const _routeSourceId = 'locmotos-route';
  static const _routeCasingLayerId = 'locmotos-route-casing';
  static const _routeLineLayerId = 'locmotos-route-line';
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
  static const _alertIconFuelId = 'locmotos-alert-fuel';
  static const _alertIconTollId = 'locmotos-alert-toll';

  /// Tipos que se pintan en el mapa (no curvas: saturan el trazado).
  static const _mapAlertTypes = {
    RouteAlertType.speedCamera,
    RouteAlertType.fuel,
    RouteAlertType.toll,
  };

  /// Refs tipo A-23 / N-234 / CV-624 / AP-7 (no calles largas).
  static final _roadRefPattern = RegExp(
    r'\b([A-ZÁÉÍÓÚÜÑ]{1,3}[-\s]?\d[\w-]*)',
    caseSensitive: false,
  );

  MapLibreMapController? _controller;
  Circle? _puck;
  Circle? _puckHalo;
  final List<Circle> _endpointMarkers = [];
  var _routeDrawn = false;
  var _routeLayersReady = false;
  var _etaPillsReady = false;
  var _alertIconsReady = false;
  var _lastCameraTarget = const LatLng(0, 0);
  var _cameraReady = false;
  /// En preview: solo un encuadre inicial; no reajustar al soltar el dedo.
  var _hasFittedPreview = false;
  var _mapConfigured = false;
  var _styleSwitching = false;
  late String _activeStyle;

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

  @override
  void initState() {
    super.initState();
    _activeStyle = widget.mapStyles.resolve(
      _cameraTarget.latitude,
      _cameraTarget.longitude,
      hasNetwork: widget.hasNetwork,
    );
  }

  @override
  void didUpdateWidget(covariant NavigationMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mapStyles != widget.mapStyles ||
        oldWidget.hasNetwork != widget.hasNetwork) {
      // Usar el centro de cámara real (en preview no es el origen de la ruta).
      unawaited(_syncStyleForVisiblePoint());
    }
    if (_controller == null) {
      return;
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
        _cameraReady = false;
      }
      unawaited(_drawRoute());
      return;
    }
    if (!_routeDrawn || widget._isPreview) {
      return;
    }
    _syncCamera(oldWidget);
    unawaited(_syncPuck());
    // En HUD: al avanzar, actualizar qué avisos (próximos 1–2) se muestran.
    if (oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude) {
      unawaited(_syncAlertsSource());
      unawaited(_syncStyleForVisiblePoint());
    }
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
    final controller = _controller;
    final next = widget.mapStyles.resolve(
      point.latitude,
      point.longitude,
      hasNetwork: widget.hasNetwork,
    );
    if (next == _activeStyle) {
      return;
    }
    _activeStyle = next;
    if (controller == null) {
      return;
    }
    _styleSwitching = true;
    try {
      await controller.setStyle(next);
    } catch (_) {
      _styleSwitching = false;
    }
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
  }

  Future<void> _drawRoute() async {
    final controller = _controller;
    if (controller == null || widget.route.polyline.length < 2) {
      return;
    }

    if (!_mapConfigured) {
      await _configureMap();
    }

    final selectedGeoJson = _routeGeoJson(widget.route.polyline);
    final altsGeoJson = _alternativesGeoJson(widget.alternativeRoutes);
    final labelsGeoJson = _routeStreetLabelsGeoJson(widget.route);
    final etaGeoJson = _etaLabelsGeoJson(
      selected: widget.route,
      alternatives: widget.alternativeRoutes,
    );
    final alertsGeoJson = _alertsGeoJson();

    if (_routeLayersReady) {
      await controller.setGeoJsonSource(_altsSourceId, altsGeoJson);
      await controller.setGeoJsonSource(_routeSourceId, selectedGeoJson);
      await controller.setGeoJsonSource(_routeLabelsSourceId, labelsGeoJson);
      await controller.setGeoJsonSource(_etaSourceId, etaGeoJson);
      await controller.setGeoJsonSource(_alertsSourceId, alertsGeoJson);
    } else {
      await _addRouteLayersBelowLabels(
        controller,
        altsGeoJson: altsGeoJson,
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
    }

    _routeDrawn = true;
    if (widget._isPreview) {
      if (!_hasFittedPreview) {
        await _moveCamera(animate: true);
        _hasFittedPreview = true;
      }
    } else {
      await _moveCamera(animate: !_cameraReady);
      _cameraReady = true;
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
                RouteAlertType.speedCamera => _alertIconCameraId,
                RouteAlertType.fuel => _alertIconFuelId,
                RouteAlertType.toll => _alertIconTollId,
                RouteAlertType.sharpCurve => _alertIconCameraId,
              },
              'label': alert.label,
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
        .where((a) => _mapAlertTypes.contains(a.type))
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
    // Ordenados por distancia a lo largo de la ruta; mostrar solo los próximos.
    final along = _approxAlongMeters(GeoPoint(lat: lat, lng: lng));
    final ahead = [
      for (final a in mapped)
        if (a.distanceAlongRouteMeters >= along - 40) a,
    ];
    return ahead.take(2).toList(growable: false);
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
    return {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'properties': <String, dynamic>{},
          'geometry': {
            'type': 'LineString',
            'coordinates': [
              for (final point in polyline) [point.lng, point.lat],
            ],
          },
        },
      ],
    };
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

  /// Línea bajo textos del mapa; refs de ruta encima de la línea azul.
  Future<void> _addRouteLayersBelowLabels(
    MapLibreMapController controller, {
    required Map<String, dynamic> altsGeoJson,
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

    await controller.addGeoJsonSource(_routeSourceId, selectedGeoJson);
    await controller.addLineLayer(
      _routeSourceId,
      _routeCasingLayerId,
      const LineLayerProperties(
        lineColor: '#FFFFFF',
        lineWidth: 13,
        lineOpacity: 0.92,
        lineJoin: 'round',
        lineBlur: 0.4,
      ),
      belowLayerId: belowLayerId,
      enableInteraction: false,
    );
    await controller.addLineLayer(
      _routeSourceId,
      _routeLineLayerId,
      const LineLayerProperties(
        lineColor: '#1A73E8',
        lineWidth: 8,
        lineOpacity: 1,
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
          background: const Color(0xFFC62828),
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

    final image = await recorder.endRecording().toImage(size.toInt(), size.toInt());
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

  /// Marcador de posición de navegación (GPS o simulación).
  Future<void> _syncPuck() async {
    final controller = _controller;
    final lat = widget.latitude;
    final lng = widget.longitude;
    if (controller == null || widget._isPreview || lat == null || lng == null) {
      return;
    }

    final geometry = LatLng(lat, lng);
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

    final CameraUpdate update;
    if (widget._isPreview) {
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
    } else {
      update = CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _cameraTarget,
          zoom: NavigationConstants.defaultNavigationZoom,
          bearing: widget.bearing,
          tilt: widget.pitch,
        ),
      );
    }

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
  }

  @override
  Widget build(BuildContext context) {
    final isPreview = widget._isPreview;
    return MapLibreMap(
      styleString: _activeStyle,
      initialCameraPosition: CameraPosition(
        target: _cameraTarget,
        zoom: isPreview ? 12 : NavigationConstants.defaultNavigationZoom,
        bearing: isPreview ? 0 : widget.bearing,
        tilt: isPreview ? 0 : widget.pitch,
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
      // En HUD usamos nuestro puck (simulación / posición de navegación).
      // El punto azul nativo sería el GPS real y confundiría.
      myLocationEnabled: isPreview,
      myLocationTrackingMode: MyLocationTrackingMode.none,
      myLocationRenderMode: isPreview
          ? MyLocationRenderMode.compass
          : MyLocationRenderMode.normal,
      compassEnabled: isPreview,
      rotateGesturesEnabled: isPreview,
      tiltGesturesEnabled: isPreview,
      zoomGesturesEnabled: true,
      scrollGesturesEnabled: true,
      trackCameraPosition: true,
    );
  }
}
