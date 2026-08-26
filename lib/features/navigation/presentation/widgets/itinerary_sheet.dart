import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loc_motos/core/constants/navigation_constants.dart';
import 'package:loc_motos/features/auth/domain/entities/user_vehicle.dart';
import 'package:loc_motos/features/auth/presentation/providers/auth_providers.dart';
import 'package:loc_motos/features/navigation/domain/entities/geo_point.dart';
import 'package:loc_motos/features/navigation/domain/entities/route_itinerary.dart';
import 'package:loc_motos/features/navigation/presentation/providers/navigation_providers.dart';
import 'package:loc_motos/features/navigation/presentation/widgets/route_preferences_bar.dart';

/// Panel inferior con la lista del itinerario (origen + paradas + destino).
class ItinerarySheet extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final stops = itinerary.stops;
    final canCloseLoop = itinerary.hasOrigin &&
        itinerary.canPlan &&
        !_samePoint(
          itinerary.origin!.point,
          itinerary.destination!.point,
        );

    final user = resolveSessionUser(
      ref.watch(signedInUserProvider),
      ref.watch(authStateProvider).asData?.value,
    );
    final vehicles = user?.resolvedVehicles ?? const <UserVehicle>[];
    final vehicleOverride = ref.watch(navigationVehicleIdProvider);
    final selectedId = vehicleOverride ??
        user?.activeVehicleId ??
        (vehicles.isNotEmpty
            ? vehicles.first.id
            : NavigationConstants.navigationNoVehicleId);
    UserVehicle? selected;
    if (selectedId != NavigationConstants.navigationNoVehicleId) {
      for (final v in vehicles) {
        if (v.id == selectedId) {
          selected = v;
          break;
        }
      }
    }
    final showCurvature =
        selected == null || selected.kind == VehicleKind.motorcycle;

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
              if (vehicles.isNotEmpty) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  // ignore: deprecated_member_use
                  value: selectedId,
                  decoration: const InputDecoration(
                    labelText: 'Vehículo',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: NavigationConstants.navigationNoVehicleId,
                      child: Text('Sin vehículo (ruta moto)'),
                    ),
                    for (final v in vehicles)
                      DropdownMenuItem<String>(
                        value: v.id,
                        child: Text(
                          '${v.displayLabel} · ${v.kind.label}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: busy
                      ? null
                      : (value) {
                          ref.read(navigationVehicleIdProvider.notifier).state =
                              value ?? NavigationConstants.navigationNoVehicleId;
                        },
                ),
              ],
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
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
                      onTap: busy ? null : () => onEditStop(stop.id),
                      trailing: !isOrigin
                          ? IconButton(
                              tooltip: 'Quitar',
                              onPressed:
                                  busy ? null : () => onRemoveStop(stop.id),
                              icon: const Icon(Icons.close),
                            )
                          : null,
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
              RoutePreferencesBar(
                enabled: !busy,
                showCurvature: showCurvature,
              ),
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
