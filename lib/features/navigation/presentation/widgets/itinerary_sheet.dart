import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loc_motos/core/constants/navigation_constants.dart';
import 'package:loc_motos/features/auth/domain/entities/user_vehicle.dart';
import 'package:loc_motos/features/auth/presentation/providers/auth_providers.dart';
import 'package:loc_motos/features/navigation/domain/entities/geo_point.dart';
import 'package:loc_motos/features/navigation/domain/entities/route_itinerary.dart';
import 'package:loc_motos/features/navigation/presentation/providers/navigation_providers.dart';
import 'package:loc_motos/features/navigation/presentation/widgets/collapsible_map_bottom_panel.dart';
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
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final screenHeight = MediaQuery.sizeOf(context).height;
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

    final destination = itinerary.destination?.label;
    final subtitle = destination != null && destination.isNotEmpty
        ? destination
        : stops.length >= 2
            ? '${stops.length} paradas'
            : null;

    return CollapsibleMapBottomPanel(
      title: 'Itinerario',
      subtitle: subtitle,
      sidePanel: landscape,
      maxExpandedHeight: landscape
          ? null
          : screenHeight * 0.55,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            if (vehicles.isNotEmpty) ...[
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: selectedId,
                decoration: InputDecoration(
                  labelText: 'Vehículo',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  contentPadding: landscape
                      ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
                      : null,
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
              SizedBox(height: landscape ? 6 : 8),
            ],
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: landscape ? 160 : 180,
              ),
              child: ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
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
                    visualDensity:
                        landscape ? VisualDensity.compact : VisualDensity.standard,
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ReorderableDragStartListener(
                          index: index,
                          child: Icon(
                            Icons.drag_handle,
                            size: landscape ? 20 : 24,
                          ),
                        ),
                        SizedBox(width: landscape ? 2 : 4),
                        CircleAvatar(
                          radius: landscape ? 12 : 14,
                          backgroundColor: badgeColor,
                          child: Text(
                            badge,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: landscape ? 11 : 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    title: Text(
                      stop.label,
                      maxLines: landscape ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: busy ? null : () => onEditStop(stop.id),
                    trailing: IconButton(
                      tooltip: 'Quitar',
                      visualDensity: VisualDensity.compact,
                      onPressed: busy ? null : () => onRemoveStop(stop.id),
                      icon: Icon(Icons.close, size: landscape ? 20 : 24),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: landscape ? 6 : 8),
            Wrap(
              spacing: 8,
              runSpacing: landscape ? 4 : 8,
              children: [
                OutlinedButton.icon(
                  onPressed: busy ? null : onAddStop,
                  style: OutlinedButton.styleFrom(
                    visualDensity:
                        landscape ? VisualDensity.compact : VisualDensity.standard,
                    padding: landscape
                        ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6)
                        : null,
                  ),
                  icon: Icon(Icons.add_location_alt_outlined,
                      size: landscape ? 18 : 24),
                  label: const Text('Añadir parada'),
                ),
                if (canCloseLoop)
                  OutlinedButton.icon(
                    onPressed: busy ? null : onCloseLoop,
                    style: OutlinedButton.styleFrom(
                      visualDensity:
                          landscape ? VisualDensity.compact : VisualDensity.standard,
                      padding: landscape
                          ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6)
                          : null,
                    ),
                    icon: Icon(Icons.loop, size: landscape ? 18 : 24),
                    label: const Text('Cerrar circuito'),
                  ),
              ],
            ),
            SizedBox(height: landscape ? 6 : 8),
            RoutePreferencesBar(
              enabled: !busy,
              showCurvature: showCurvature,
            ),
            SizedBox(height: landscape ? 8 : 10),
            FilledButton.icon(
              onPressed: busy || !itinerary.canPlan ? null : onPlanRoute,
              style: FilledButton.styleFrom(
                visualDensity:
                    landscape ? VisualDensity.compact : VisualDensity.standard,
                padding: landscape
                    ? const EdgeInsets.symmetric(vertical: 10)
                    : null,
              ),
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.route, size: landscape ? 18 : 24),
              label: Text(
                itinerary.hasIntermediateStops ? 'Ver circuito' : 'Ver ruta',
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
