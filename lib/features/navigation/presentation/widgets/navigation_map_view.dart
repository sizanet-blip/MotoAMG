import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:loc_motos/core/constants/navigation_constants.dart';
import 'package:loc_motos/features/navigation/domain/entities/geo_point.dart';
import 'package:loc_motos/features/navigation/domain/entities/hybrid_map_styles.dart';
import 'package:loc_motos/features/navigation/domain/entities/navigation_route.dart';
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
  static const _routeLabelsSourceId = 'locmotos-route-labels';
  static const _routeLabelsLayerId = 'locmotos-route-labels-text';

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
    if (oldWidget.route.id != widget.route.id) {
      _hasFittedPreview = false;
      _cameraReady = false;
      unawaited(_drawRoute());
      return;
    }
    if (!_routeDrawn || widget._isPreview) {
      return;
    }
    _syncCamera(oldWidget);
    unawaited(_syncPuck());
    if (oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude) {
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

    final geojson = _routeGeoJson(widget.route.polyline);
    final labelsGeoJson = _routeStreetLabelsGeoJson(widget.route);
    if (_routeLayersReady) {
      await controller.setGeoJsonSource(_routeSourceId, geojson);
      await controller.setGeoJsonSource(_routeLabelsSourceId, labelsGeoJson);
    } else {
      await _addRouteLayersBelowLabels(controller, geojson, labelsGeoJson);
      _routeLayersReady = true;
    }

    if (widget._isPreview) {
      await _drawEndpointMarkers(controller);
    } else {
      await _syncPuck();
    }

    _routeDrawn = true;
    if (widget._isPreview) {
      // Tras un cambio de estilo (híbrido offline/online) se redibuja la ruta;
      // no debemos volver a hacer fitBounds o el mapa “salta” al soltar.
      if (!_hasFittedPreview) {
        await _moveCamera(animate: true);
        _hasFittedPreview = true;
      }
    } else {
      await _moveCamera(animate: !_cameraReady);
      _cameraReady = true;
    }
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
    MapLibreMapController controller,
    Map<String, dynamic> geojson,
    Map<String, dynamic> labelsGeoJson,
  ) async {
    final belowLayerId = await _firstMapLabelLayerId(controller);

    await controller.addGeoJsonSource(_routeSourceId, geojson);
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
