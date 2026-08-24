import 'package:flutter/material.dart';
import 'package:loc_motos/features/navigation/presentation/models/route_endpoint_input_mode.dart';

/// Conmutador compacto dirección ↔ coordenadas.
class RouteEndpointModeToggle extends StatelessWidget {
  const RouteEndpointModeToggle({
    super.key,
    required this.mode,
    required this.enabled,
    required this.onChanged,
  });

  final RouteEndpointInputMode mode;
  final bool enabled;
  final ValueChanged<RouteEndpointInputMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SegmentedButton<RouteEndpointInputMode>(
      showSelectedIcon: false,
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 4),
        ),
      ),
      segments: [
        ButtonSegment(
          value: RouteEndpointInputMode.address,
          icon: Icon(Icons.place_outlined, size: 18, color: colors.primary),
          tooltip: 'Buscar dirección',
        ),
        ButtonSegment(
          value: RouteEndpointInputMode.coordinates,
          icon: Icon(Icons.gps_not_fixed, size: 18, color: colors.primary),
          tooltip: 'Latitud y longitud',
        ),
      ],
      selected: {mode},
      onSelectionChanged: enabled
          ? (selection) => onChanged(selection.first)
          : null,
    );
  }
}
