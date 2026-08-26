import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

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
    final colors = Theme.of(context).colorScheme;
    final active = enabled && onPressed != null;

    return Material(
      elevation: 3,
      color: emphasized && active
          ? colors.primary
          : colors.surface.withValues(alpha: 0.96),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        tooltip: 'Mi ubicación',
        onPressed: active ? onPressed : null,
        icon: Icon(
          Icons.my_location_rounded,
          color: emphasized && active
              ? colors.onPrimary
              : (active ? colors.primary : colors.onSurfaceVariant),
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
