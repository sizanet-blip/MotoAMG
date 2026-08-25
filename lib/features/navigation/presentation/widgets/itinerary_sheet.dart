import 'package:flutter/material.dart';
import 'package:loc_motos/features/navigation/domain/entities/geo_point.dart';
import 'package:loc_motos/features/navigation/domain/entities/route_itinerary.dart';
import 'package:loc_motos/features/navigation/presentation/widgets/route_preferences_bar.dart';

/// Panel inferior con la lista del itinerario (origen + paradas + destino).
class ItinerarySheet extends StatelessWidget {
  const ItinerarySheet({
    super.key,
    required this.itinerary,
    required this.busy,
    required this.onAddStop,
    required this.onRemoveStop,
    required this.onReorder,
    required this.onCloseLoop,
    required this.onPlanRoute,
    required this.onEditStop,
  });

  final RouteItinerary itinerary;
  final bool busy;
  final VoidCallback onAddStop;
  final ValueChanged<String> onRemoveStop;
  final void Function(int oldIndex, int newIndex) onReorder;
  final VoidCallback onCloseLoop;
  final VoidCallback onPlanRoute;
  final ValueChanged<String> onEditStop;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final stops = itinerary.stops;
    final canCloseLoop = itinerary.hasOrigin &&
      itinerary.canPlan &&
      !_samePoint(
        itinerary.origin!.point,
        itinerary.destination!.point,
      );

    return Material(
      elevation: 10,
      color: colors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Itinerario',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ReorderableListView.builder(
                  shrinkWrap: true,
                  buildDefaultDragHandles: false,
                  itemCount: stops.length,
                  onReorder: onReorder,
                  itemBuilder: (context, index) {
                    final stop = stops[index];
                    final isOrigin = index == 0;
                    final isDest =
                        index == stops.length - 1 && stops.length > 1;
                    final badge = isOrigin
                        ? 'A'
                        : isDest
                            ? 'B'
                            : '$index';
                    final badgeColor = isOrigin
                        ? const Color(0xFF2E7D32)
                        : isDest
                            ? const Color(0xFFC62828)
                            : colors.primary;
                    return ListTile(
                      key: ValueKey(stop.id),
                      contentPadding: EdgeInsets.zero,
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ReorderableDragStartListener(
                            index: index,
                            child: const Icon(Icons.drag_handle),
                          ),
                          const SizedBox(width: 4),
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: badgeColor,
                            child: Text(
                              badge,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      title: Text(
                        stop.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        isOrigin
                            ? (stop.followsGps
                                ? 'Origen · GPS'
                                : 'Origen')
                            : isDest
                                ? 'Destino'
                                : 'Parada',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Editar',
                            onPressed: busy ? null : () => onEditStop(stop.id),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          if (!isOrigin || stops.length > 1)
                            IconButton(
                              tooltip: 'Quitar',
                              onPressed:
                                  busy ? null : () => onRemoveStop(stop.id),
                              icon: const Icon(Icons.close),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: busy ? null : onAddStop,
                    icon: const Icon(Icons.add_location_alt_outlined),
                    label: const Text('Añadir parada'),
                  ),
                  if (canCloseLoop)
                    OutlinedButton.icon(
                      onPressed: busy ? null : onCloseLoop,
                      icon: const Icon(Icons.loop),
                      label: const Text('Cerrar circuito'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              RoutePreferencesBar(enabled: !busy),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: busy || !itinerary.canPlan ? null : onPlanRoute,
                icon: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.route),
                label: Text(
                  itinerary.hasIntermediateStops
                      ? 'Ver circuito'
                      : 'Ver ruta',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

bool _samePoint(GeoPoint a, GeoPoint b) {
  return (a.lat - b.lat).abs() < 0.00005 && (a.lng - b.lng).abs() < 0.00005;
}
