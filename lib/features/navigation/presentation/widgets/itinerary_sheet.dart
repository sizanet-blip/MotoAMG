import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loc_motos/core/constants/navigation_constants.dart';
import 'package:loc_motos/core/widgets/map_quick_action_tile.dart';
import 'package:loc_motos/features/auth/domain/entities/user_vehicle.dart';
import 'package:loc_motos/features/auth/presentation/providers/auth_providers.dart';
import 'package:loc_motos/features/navigation/domain/entities/geo_point.dart';
import 'package:loc_motos/features/navigation/domain/entities/route_itinerary.dart';
import 'package:loc_motos/features/navigation/domain/entities/route_preferences.dart';
import 'package:loc_motos/features/navigation/presentation/providers/navigation_providers.dart';
import 'package:loc_motos/features/navigation/presentation/widgets/collapsible_map_bottom_panel.dart';
import 'package:loc_motos/features/navigation/presentation/widgets/route_preferences_bar.dart';

/// Panel inferior del itinerario: vehículo, puntos y acciones al estilo mapa.
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
    final textTheme = Theme.of(context).textTheme;
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
    final prefs = ref.watch(routePreferencesProvider);

    final destination = itinerary.destination?.label;
    final subtitle = destination != null && destination.isNotEmpty
        ? _shortLabel(destination)
        : stops.length >= 2
            ? '${stops.length} puntos'
            : null;

    final fieldDecoration = InputDecoration(
      filled: true,
      fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.primary, width: 1.5),
      ),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    );

    final actionTiles = <Widget>[
      MapQuickActionTile(
        icon: Icons.add_location_alt_outlined,
        label: 'Parada',
        enabled: !busy,
        onTap: busy ? null : onAddStop,
      ),
      if (canCloseLoop)
        MapQuickActionTile(
          icon: Icons.loop,
          label: 'Circuito',
          enabled: !busy,
          onTap: busy ? null : onCloseLoop,
        ),
      if (showCurvature)
        MapQuickActionTile(
          icon: Icons.route,
          label: prefs.curvature.label,
          emphasized: prefs.curvature != RouteCurvatureLevel.balanced,
          enabled: !busy,
          onTap: busy
              ? null
              : () => RoutePreferencesBar.openCurvatureSheet(context, ref),
        ),
      MapQuickActionTile(
        icon: Icons.block,
        label: 'Evitaciones',
        emphasized: prefs.activeAvoidanceCount > 0,
        badge: prefs.activeAvoidanceCount > 0
            ? '${prefs.activeAvoidanceCount}'
            : null,
        enabled: !busy,
        onTap: busy
            ? null
            : () => RoutePreferencesBar.openAvoidancesSheet(context, ref),
      ),
    ];

    return CollapsibleMapBottomPanel(
      title: 'Itinerario',
      subtitle: subtitle,
      sidePanel: landscape,
      maxExpandedHeight: landscape ? null : screenHeight * 0.52,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 2, 14, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (vehicles.isNotEmpty) ...[
                DropdownButtonFormField<String>(
                  // ignore: deprecated_member_use
                  value: selectedId,
                  isExpanded: true,
                  decoration: fieldDecoration.copyWith(
                    prefixIcon: Icon(
                      selected?.kind == VehicleKind.auto
                          ? Icons.directions_car_outlined
                          : Icons.two_wheeler_outlined,
                      size: 20,
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 36,
                    ),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: NavigationConstants.navigationNoVehicleId,
                      child: Text('Sin vehículo · moto'),
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
                              value ??
                                  NavigationConstants.navigationNoVehicleId;
                        },
                ),
                const SizedBox(height: 8),
              ],
              if (stops.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Elige origen y destino en el mapa o con búsqueda.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: landscape ? 140 : 156,
                  ),
                  child: ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: stops.length > 3
                        ? const ClampingScrollPhysics()
                        : const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    itemCount: stops.length,
                    onReorder: onReorder,
                    proxyDecorator: (child, index, animation) {
                      return Material(
                        elevation: 3,
                        borderRadius: BorderRadius.circular(10),
                        color: colors.surface,
                        child: child,
                      );
                    },
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
                      return Padding(
                        key: ValueKey(stop.id),
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Material(
                          color: colors.surfaceContainerHighest.withValues(
                            alpha: 0.35,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: busy ? null : () => onEditStop(stop.id),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(4, 4, 2, 4),
                              child: Row(
                                children: [
                                  ReorderableDragStartListener(
                                    index: index,
                                    child: Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: Icon(
                                        Icons.drag_indicator,
                                        size: 18,
                                        color: colors.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                  CircleAvatar(
                                    radius: 11,
                                    backgroundColor: badgeColor,
                                    child: Text(
                                      badge,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _shortLabel(stop.label),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Quitar',
                                    visualDensity: VisualDensity.compact,
                                    constraints: const BoxConstraints(
                                      minWidth: 36,
                                      minHeight: 36,
                                    ),
                                    onPressed: busy
                                        ? null
                                        : () => onRemoveStop(stop.id),
                                    icon: Icon(
                                      Icons.close_rounded,
                                      size: 18,
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (var i = 0; i < actionTiles.length; i++) ...[
                    if (i > 0) const SizedBox(width: 4),
                    Expanded(child: actionTiles[i]),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: busy || !itinerary.canPlan ? null : onPlanRoute,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        itinerary.hasIntermediateStops
                            ? 'Ver circuito'
                            : 'Ver ruta',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _shortLabel(String raw) {
  final parts = raw.split(' · ');
  if (parts.length <= 2) {
    return raw;
  }
  return '${parts[0]} · ${parts[1]}';
}

bool _samePoint(GeoPoint a, GeoPoint b) {
  return (a.lat - b.lat).abs() < 0.00005 && (a.lng - b.lng).abs() < 0.00005;
}
