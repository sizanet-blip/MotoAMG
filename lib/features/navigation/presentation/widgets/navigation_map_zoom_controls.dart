import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:moto_amg/core/theme/hub_style.dart';

/// Botones + / − para acercar y alejar el mapa.
class NavigationMapZoomControls extends StatelessWidget {
  const NavigationMapZoomControls({
    super.key,
    required this.controller,
    this.onZoom,
  });

  final MapLibreMapController controller;
  final VoidCallback? onZoom;

  Future<void> _zoomBy(double delta) async {
    onZoom?.call();
    await controller.animateCamera(
      CameraUpdate.zoomBy(delta),
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      color: HubStyle.surface.withValues(alpha: 0.97),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Acercar',
            onPressed: () => _zoomBy(1),
            icon: const Icon(Icons.add, color: HubStyle.title),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: HubStyle.subtitle.withValues(alpha: 0.2),
          ),
          IconButton(
            tooltip: 'Alejar',
            onPressed: () => _zoomBy(-1),
            icon: const Icon(Icons.remove, color: HubStyle.title),
          ),
        ],
      ),
    );
  }
}
