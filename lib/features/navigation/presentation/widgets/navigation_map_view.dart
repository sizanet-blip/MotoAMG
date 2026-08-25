import 'dart:async';

import 'package:flutter/material.dart';
import 'package:loc_motos/core/constants/navigation_constants.dart';
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
  MapLibreMapController? _controller;
  Line? _routeLine;
  Line? _routeCasingLine;
  Circle? _puck;
  Circle? _puckHalo;
  final List<Circle> _endpointMarkers = [];
  var _routeDrawn = false;
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
    _routeLine = null;
    _routeCasingLine = null;
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

    final geometry = widget.route.polyline
        .map((point) => LatLng(point.lat, point.lng))
        .toList(growable: false);

    const casingOptions = LineOptions(
      lineColor: '#FFFFFF',
      lineWidth: 13,
      lineOpacity: 0.92,
      lineJoin: 'round',
      lineBlur: 0.4,
    );
    const routeOptions = LineOptions(
      lineColor: '#1A73E8',
      lineWidth: 8,
      lineOpacity: 1,
      lineJoin: 'round',
    );

    if (_routeCasingLine != null) {
      await controller.updateLine(
        _routeCasingLine!,
        casingOptions.copyWith(LineOptions(geometry: geometry)),
      );
    } else {
      _routeCasingLine = await controller.addLine(
        casingOptions.copyWith(LineOptions(geometry: geometry)),
      );
    }

    if (_routeLine != null) {
      await controller.updateLine(
        _routeLine!,
        routeOptions.copyWith(LineOptions(geometry: geometry)),
      );
    } else {
      _routeLine = await controller.addLine(
        routeOptions.copyWith(LineOptions(geometry: geometry)),
      );
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
