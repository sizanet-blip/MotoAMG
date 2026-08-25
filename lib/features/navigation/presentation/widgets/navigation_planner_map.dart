import 'dart:async';

import 'package:flutter/material.dart';
import 'package:loc_motos/features/navigation/domain/entities/hybrid_map_styles.dart';
import 'package:loc_motos/features/navigation/domain/entities/route_itinerary.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

/// Mapa libre del planificador (sin ruta obligatoria): GPS + pins de itinerario.
class NavigationPlannerMap extends StatefulWidget {
  const NavigationPlannerMap({
    super.key,
    required this.mapStyles,
    required this.hasNetwork,
    required this.stops,
    this.latitude,
    this.longitude,
    this.onMapLongPress,
    this.onControllerReady,
  });

  final HybridMapStyles mapStyles;
  final bool hasNetwork;
  final List<RouteItineraryStop> stops;
  final double? latitude;
  final double? longitude;
  final void Function(LatLng point)? onMapLongPress;
  final ValueChanged<MapLibreMapController>? onControllerReady;

  @override
  State<NavigationPlannerMap> createState() => _NavigationPlannerMapState();
}

class _NavigationPlannerMapState extends State<NavigationPlannerMap> {
  MapLibreMapController? _controller;
  final List<Circle> _stopCircles = [];
  Circle? _puck;
  Circle? _puckHalo;
  var _styleSwitching = false;
  var _userMovedCamera = false;
  late String _activeStyle;

  LatLng get _cameraTarget {
    final lat = widget.latitude;
    final lng = widget.longitude;
    if (lat != null && lng != null) {
      return LatLng(lat, lng);
    }
    if (widget.stops.isNotEmpty) {
      final origin = widget.stops.first.point;
      return LatLng(origin.lat, origin.lng);
    }
    return const LatLng(41.6488, -0.8891); // Zaragoza fallback
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
  void didUpdateWidget(covariant NavigationPlannerMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mapStyles != widget.mapStyles ||
        oldWidget.hasNetwork != widget.hasNetwork) {
      unawaited(_syncStyleForVisiblePoint());
    }
    if (oldWidget.stops != widget.stops) {
      unawaited(_drawStops());
    }
    final moved = oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude;
    if (moved && !_userMovedCamera) {
      unawaited(_followGps());
      unawaited(_syncPuck());
    } else if (moved) {
      unawaited(_syncPuck());
    }
  }

  Future<void> _onMapCreated(MapLibreMapController controller) async {
    _controller = controller;
    widget.onControllerReady?.call(controller);
    await _syncPuck();
    await _drawStops();
  }

  Future<void> _onStyleLoaded() async {
    _stopCircles.clear();
    _puck = null;
    _puckHalo = null;
    _styleSwitching = false;
    await _syncPuck();
    await _drawStops();
  }

  Future<void> _onCameraIdle() async {
    if (_styleSwitching) {
      return;
    }
    await _syncStyleForVisiblePoint();
  }

  LatLng _visiblePoint() {
    return _controller?.cameraPosition?.target ?? _cameraTarget;
  }

  Future<void> _syncStyleForVisiblePoint() async {
    final controller = _controller;
    final point = _visiblePoint();
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

  Future<void> _followGps() async {
    final controller = _controller;
    final lat = widget.latitude;
    final lng = widget.longitude;
    if (controller == null || lat == null || lng == null) {
      return;
    }
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: LatLng(lat, lng), zoom: 14),
      ),
      duration: const Duration(milliseconds: 500),
    );
  }

  Future<void> _syncPuck() async {
    final controller = _controller;
    final lat = widget.latitude;
    final lng = widget.longitude;
    if (controller == null || lat == null || lng == null) {
      return;
    }
    final geometry = LatLng(lat, lng);
    const halo = CircleOptions(
      circleRadius: 18,
      circleColor: '#1A73E8',
      circleOpacity: 0.22,
      circleStrokeWidth: 0,
    );
    const puck = CircleOptions(
      circleRadius: 9,
      circleColor: '#1A73E8',
      circleStrokeWidth: 3,
      circleStrokeColor: '#FFFFFF',
      circleOpacity: 1,
    );
    if (_puckHalo == null) {
      final circles = await controller.addCircles([
        halo.copyWith(CircleOptions(geometry: geometry)),
        puck.copyWith(CircleOptions(geometry: geometry)),
      ]);
      if (circles.length >= 2) {
        _puckHalo = circles[0];
        _puck = circles[1];
      }
      return;
    }
    await controller.updateCircle(
      _puckHalo!,
      halo.copyWith(CircleOptions(geometry: geometry)),
    );
    if (_puck != null) {
      await controller.updateCircle(
        _puck!,
        puck.copyWith(CircleOptions(geometry: geometry)),
      );
    }
  }

  Future<void> _drawStops() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    if (_stopCircles.isNotEmpty) {
      await controller.removeCircles(_stopCircles);
      _stopCircles.clear();
    }
    if (widget.stops.isEmpty) {
      return;
    }
    final options = <CircleOptions>[];
    for (var i = 0; i < widget.stops.length; i++) {
      final stop = widget.stops[i];
      final isOrigin = i == 0;
      final isDest = i == widget.stops.length - 1 && widget.stops.length > 1;
      final color = isOrigin
          ? '#2E7D32'
          : isDest
              ? '#C62828'
              : '#1565C0';
      options.add(
        CircleOptions(
          geometry: LatLng(stop.point.lat, stop.point.lng),
          circleRadius: isOrigin || isDest ? 10 : 8,
          circleColor: color,
          circleStrokeWidth: 2.5,
          circleStrokeColor: '#FFFFFF',
          circleOpacity: 1,
        ),
      );
    }
    final circles = await controller.addCircles(options);
    _stopCircles.addAll(circles);
  }

  @override
  Widget build(BuildContext context) {
    return MapLibreMap(
      styleString: _activeStyle,
      initialCameraPosition: CameraPosition(
        target: _cameraTarget,
        zoom: 13,
      ),
      onMapCreated: _onMapCreated,
      onStyleLoadedCallback: _onStyleLoaded,
      onMapLongClick: widget.onMapLongPress == null
          ? null
          : (point, latLng) {
              _userMovedCamera = true;
              widget.onMapLongPress!(latLng);
            },
      myLocationEnabled: false,
      compassEnabled: true,
      rotateGesturesEnabled: true,
      tiltGesturesEnabled: false,
      zoomGesturesEnabled: true,
      scrollGesturesEnabled: true,
      trackCameraPosition: true,
      onCameraIdle: () {
        final cam = _controller?.cameraPosition;
        if (cam != null && widget.latitude != null && widget.longitude != null) {
          final dLat = (cam.target.latitude - widget.latitude!).abs();
          final dLng = (cam.target.longitude - widget.longitude!).abs();
          if (dLat > 0.001 || dLng > 0.001) {
            _userMovedCamera = true;
          }
        }
        unawaited(_onCameraIdle());
      },
    );
  }
}
