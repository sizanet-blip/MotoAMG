import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:moto_amg/core/theme/hub_style.dart';

/// Botón circular “mi ubicación” para recentrar el mapa en el GPS.
class NavigationMapMyLocationButton extends StatelessWidget {
  const NavigationMapMyLocationButton({
    super.key,
    required this.onPressed,
    this.enabled = true,
    this.emphasized = false,
  });

  final VoidCallback? onPressed;
  final bool enabled;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final active = enabled && onPressed != null;

    return Material(
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      color: emphasized && active
          ? HubStyle.accent
          : HubStyle.surface.withValues(alpha: 0.97),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        tooltip: 'Mi ubicación',
        onPressed: active ? onPressed : null,
        icon: Icon(
          Icons.my_location_rounded,
          color: emphasized && active
              ? Colors.white
              : (active
                  ? HubStyle.accent
                  : HubStyle.subtitle.withValues(alpha: 0.45)),
        ),
      ),
    );
  }
}

/// Anima la cámara a [lat]/[lng] (p. ej. GPS).
Future<void> animateMapToMyLocation(
  MapLibreMapController controller, {
  required double lat,
  required double lng,
  double zoom = 15,
}) {
  return controller.animateCamera(
    CameraUpdate.newCameraPosition(
      CameraPosition(
        target: LatLng(lat, lng),
        zoom: zoom,
      ),
    ),
    duration: const Duration(milliseconds: 500),
  );
}
