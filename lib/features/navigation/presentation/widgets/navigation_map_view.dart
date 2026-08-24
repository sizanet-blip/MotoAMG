import 'package:flutter/material.dart';
import 'package:loc_motos/core/constants/navigation_constants.dart';
import 'package:loc_motos/features/navigation/domain/entities/navigation_route.dart';
import 'package:loc_motos/features/navigation/presentation/helpers/route_map_bounds.dart';
import 'package:loc_motos/features/navigation/presentation/models/navigation_map_camera_mode.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

/// Mapa MapLibre: seguimiento en HUD o encuadre de ruta en vista previa.
class NavigationMapView extends StatefulWidget {
  const NavigationMapView({
    super.key,
    required this.route,
    required this.styleString,
    this.latitude,
    this.longitude,
    this.bearing = 0,
    this.pitch = NavigationConstants.defaultMapPitch,
    this.cameraMode = NavigationMapCameraMode.followDevice,
    this.fitBoundsBottomExtra = 0,
    this.onControllerReady,
  });

  final NavigationRoute route;
  final String styleString;
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
  final List<Circle> _endpointMarkers = [];
  var _routeDrawn = false;
  var _lastCameraTarget = const LatLng(0, 0);
  var _cameraReady = false;
  var _mapConfigured = false;

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
  void didUpdateWidget(covariant NavigationMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller == null || !_routeDrawn || widget._isPreview) {
      return;
    }
    _syncCamera(oldWidget);
  }

  Future<void> _onMapCreated(MapLibreMapController controller) async {
    _controller = controller;
    widget.onControllerReady?.call(controller);
    await _drawRoute();
  }

  Future<void> _onStyleLoaded() async {
    _routeDrawn = false;
    _routeLine = null;
    _routeCasingLine = null;
    _endpointMarkers.clear();
    _mapConfigured = false;
    await _configureMap();
    await _drawRoute();
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
    }

    _routeDrawn = true;
    await _moveCamera(animate: !_cameraReady);
    _cameraReady = true;
  }

  Future<void> _drawEndpointMarkers(MapLibreMapController controller) async {
    if (_endpointMarkers.isNotEmpty) {
      return;
    }

    final origin = widget.route.origin;
    final destination = widget.route.destination;
    final markers = await controller.addCircles([
      const CircleOptions(
        circleRadius: 9,
        circleColor: '#2E7D32',
        circleStrokeWidth: 2.5,
        circleStrokeColor: '#FFFFFF',
      ).copyWith(
        CircleOptions(geometry: LatLng(origin.lat, origin.lng)),
      ),
      const CircleOptions(
        circleRadius: 9,
        circleColor: '#C62828',
        circleStrokeWidth: 2.5,
        circleStrokeColor: '#FFFFFF',
      ).copyWith(
        CircleOptions(geometry: LatLng(destination.lat, destination.lng)),
      ),
    ]);
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
      styleString: widget.styleString,
      initialCameraPosition: CameraPosition(
        target: _cameraTarget,
        zoom: isPreview ? 12 : NavigationConstants.defaultNavigationZoom,
        bearing: isPreview ? 0 : widget.bearing,
        tilt: isPreview ? 0 : widget.pitch,
      ),
      onMapCreated: _onMapCreated,
      onStyleLoadedCallback: _onStyleLoaded,
      myLocationEnabled: true,
      myLocationTrackingMode: MyLocationTrackingMode.none,
      myLocationRenderMode: MyLocationRenderMode.compass,
      compassEnabled: isPreview,
      rotateGesturesEnabled: isPreview,
      tiltGesturesEnabled: isPreview,
      zoomGesturesEnabled: true,
      trackCameraPosition: false,
    );
  }
}
