import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

/// Botones + / − para acercar y alejar el mapa.
class NavigationMapZoomControls extends StatelessWidget {
  const NavigationMapZoomControls({
    super.key,
    required this.controller,
  });

  final MapLibreMapController controller;

  Future<void> _zoomBy(double delta) async {
    await controller.animateCamera(
      CameraUpdate.zoomBy(delta),
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      elevation: 3,
      color: colors.surface.withValues(alpha: 0.96),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Acercar',
            onPressed: () => _zoomBy(1),
            icon: const Icon(Icons.add),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: colors.outlineVariant.withValues(alpha: 0.7),
          ),
          IconButton(
            tooltip: 'Alejar',
            onPressed: () => _zoomBy(-1),
            icon: const Icon(Icons.remove),
          ),
        ],
      ),
    );
  }
}
