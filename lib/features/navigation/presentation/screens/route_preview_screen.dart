import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loc_motos/core/utils/distance_format.dart';
import 'package:loc_motos/core/utils/navigation_duration_format.dart';
import 'package:loc_motos/features/auth/domain/entities/app_user.dart';
import 'package:loc_motos/features/navigation/domain/entities/alert_preferences.dart';
import 'package:loc_motos/features/navigation/domain/entities/hybrid_map_styles.dart';
import 'package:loc_motos/features/navigation/domain/entities/navigation_route.dart';
import 'package:loc_motos/features/navigation/domain/entities/route_alert.dart';
import 'package:loc_motos/features/navigation/domain/entities/route_plan.dart';
import 'package:loc_motos/features/navigation/presentation/models/navigation_map_camera_mode.dart';
import 'package:loc_motos/features/navigation/presentation/providers/navigation_providers.dart';
import 'package:loc_motos/features/navigation/presentation/screens/navigation_hud_screen.dart';
import 'package:loc_motos/features/navigation/presentation/widgets/map_network_resume_binder.dart';
import 'package:loc_motos/features/navigation/presentation/widgets/navigation_map_view.dart';
import 'package:loc_motos/features/navigation/presentation/widgets/navigation_map_zoom_controls.dart';
import 'package:loc_motos/features/navigation/presentation/widgets/offline_map_banner.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

class RoutePreviewScreen extends ConsumerStatefulWidget {
  const RoutePreviewScreen({
    super.key,
    required this.plan,
    required this.user,
  });

  final RoutePlan plan;
  final AppUser user;

  @override
  ConsumerState<RoutePreviewScreen> createState() => _RoutePreviewScreenState();
}

class _RoutePreviewScreenState extends ConsumerState<RoutePreviewScreen> {
  late RoutePlan _plan;
  var _enriching = false;
  String? _enrichingRouteId;
  final _enrichedRouteIds = <String>{};

  @override
  void initState() {
    super.initState();
    _plan = widget.plan;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_enrichSelected());
    });
  }

  void _selectAlternative(int index) {
    final next = _plan.select(index);
    if (next.selectedIndex == _plan.selectedIndex) {
      return;
    }
    setState(() => _plan = next);
    ref.read(activeNavigationRouteProvider.notifier).state = next.selected;
    unawaited(_enrichSelected());
  }

  Future<void> _enrichSelected() async {
    final selected = _plan.selected;
    if (_enrichedRouteIds.contains(selected.id) ||
        _enrichingRouteId == selected.id) {
      return;
    }
    _enrichingRouteId = selected.id;
    setState(() => _enriching = true);
    try {
      final enriched =
          await ref.read(routeAlertsServiceProvider).enrich(
                selected,
                preferredFuel: resolveNavigationPreferredFuel(
                  user: widget.user,
                  vehicleId: ref.read(navigationVehicleIdProvider),
                ),
                preferences: ref.read(alertPreferencesProvider),
              );
      if (!mounted || _plan.selected.id != selected.id) {
        return;
      }
      final alts = [
        for (final r in _plan.alternatives)
          if (r.id == enriched.id) enriched else r,
      ];
      _enrichedRouteIds.add(selected.id);
      setState(() {
        _plan = RoutePlan(
          alternatives: alts,
          selectedIndex: _plan.selectedIndex,
        );
      });
      ref.read(activeNavigationRouteProvider.notifier).state = enriched;
    } catch (_) {
      _enrichedRouteIds.add(selected.id);
      // Overpass/Valhalla opcionales: la preview sigue usable.
    } finally {
      if (mounted && _enrichingRouteId == selected.id) {
        setState(() => _enriching = false);
      }
    }
  }

  Future<void> _startNavigation() async {
    var route = _plan.selected;
    if (!_enrichedRouteIds.contains(route.id)) {
      try {
        route = await ref.read(routeAlertsServiceProvider).enrich(
              route,
              preferredFuel: resolveNavigationPreferredFuel(
                user: widget.user,
                vehicleId: ref.read(navigationVehicleIdProvider),
              ),
              preferences: ref.read(alertPreferencesProvider),
            );
        _enrichedRouteIds.add(route.id);
      } catch (_) {}
    }
    ref.read(activeNavigationRouteProvider.notifier).state = route;
    await ref.read(navigationRepositoryProvider).saveActiveRoute(route);
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NavigationHudScreen(route: route, user: widget.user),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mapStyleAsync = ref.watch(hybridMapStylesProvider);
    final networkAsync = ref.watch(mapNetworkAvailableProvider);
    final hasNetwork = networkAsync.asData?.value ?? true;
    final showOfflineBanner = networkAsync.asData?.value == false;
    final route = _plan.selected;

    return MapNetworkResumeBinder(
      child: Scaffold(
        body: mapStyleAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) =>
              const Center(child: Text('No se pudo cargar el mapa.')),
          data: (mapStyles) => Column(
            children: [
              Expanded(
                child: _RoutePreviewMapLayer(
                  route: route,
                  alternativeRoutes: _plan.otherAlternatives,
                  mapStyles: mapStyles,
                  hasNetwork: hasNetwork,
                  showOfflineBanner: showOfflineBanner,
                  alertPreferences: ref.watch(alertPreferencesProvider),
                ),
              ),
              _RoutePreviewSheet(
                plan: _plan,
                enriching: _enriching,
                preferencesSummary:
                    ref.watch(routePreferencesProvider).summaryLabel,
                fuelCacheReady: ref
                        .watch(spainFuelCacheStatusProvider)
                        .asData
                        ?.value
                        .isReady ??
                    false,
                fuelAlertsEnabled:
                    ref.watch(alertPreferencesProvider).fuelEnabled,
                onSelect: _selectAlternative,
                onStart: _startNavigation,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoutePreviewMapLayer extends StatefulWidget {
  const _RoutePreviewMapLayer({
    required this.route,
    required this.alternativeRoutes,
    required this.mapStyles,
    required this.hasNetwork,
    required this.showOfflineBanner,
    required this.alertPreferences,
  });

  final NavigationRoute route;
  final List<NavigationRoute> alternativeRoutes;
  final HybridMapStyles mapStyles;
  final bool hasNetwork;
  final bool showOfflineBanner;
  final AlertPreferences alertPreferences;

  @override
  State<_RoutePreviewMapLayer> createState() => _RoutePreviewMapLayerState();
}

class _RoutePreviewMapLayerState extends State<_RoutePreviewMapLayer> {
  MapLibreMapController? _mapController;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final top = MediaQuery.paddingOf(context).top + 8;

    return Stack(
      fit: StackFit.expand,
      children: [
        NavigationMapView(
          route: widget.route,
          alternativeRoutes: widget.alternativeRoutes,
          mapStyles: widget.mapStyles,
          hasNetwork: widget.hasNetwork,
          alertPreferences: widget.alertPreferences,
          cameraMode: NavigationMapCameraMode.fitRoute,
          onControllerReady: (controller) {
            if (_mapController == controller) {
              return;
            }
            setState(() => _mapController = controller);
          },
        ),
        Positioned(
          top: top,
          left: 8,
          child: Material(
            color: colors.surface.withValues(alpha: 0.96),
            shape: const CircleBorder(),
            elevation: 2,
            clipBehavior: Clip.antiAlias,
            child: BackButton(
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ),
        if (_mapController != null)
          Positioned(
            top: top,
            right: 12,
            child: NavigationMapZoomControls(controller: _mapController!),
          ),
        if (widget.showOfflineBanner)
          const Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: OfflineMapBanner(compact: true),
          ),
      ],
    );
  }
}

class _RoutePreviewSheet extends StatelessWidget {
  const _RoutePreviewSheet({
    required this.plan,
    required this.enriching,
    required this.preferencesSummary,
    required this.fuelCacheReady,
    required this.fuelAlertsEnabled,
    required this.onSelect,
    required this.onStart,
  });

  final RoutePlan plan;
  final bool enriching;
  final String preferencesSummary;
  final bool fuelCacheReady;
  final bool fuelAlertsEnabled;
  final ValueChanged<int> onSelect;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final route = plan.selected;
    final alertCounts = <RouteAlertType, int>{
      for (final t in RouteAlertType.values) t: 0,
    };
    for (final a in route.alerts) {
      alertCounts[a.type] = (alertCounts[a.type] ?? 0) + 1;
    }

    return Material(
      elevation: 12,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      color: colors.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.outlineVariant,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                route.hasWaypoints
                    ? 'Vista previa del circuito'
                    : 'Vista previa de la ruta',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (plan.hasAlternatives) ...[
                const SizedBox(height: 12),
                Text(
                  'Elige una ruta',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (var index = 0;
                        index < plan.alternatives.length;
                        index++) ...[
                      if (index > 0) const SizedBox(width: 6),
                      Expanded(
                        child: _RouteAlternativeChip(
                          index: index,
                          route: plan.alternatives[index],
                          selected: index == plan.selectedIndex,
                          onTap: () => onSelect(index),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _RouteStatChip(
                    icon: Icons.straighten,
                    label: formatRideDistance(route.distanceMeters),
                  ),
                  _RouteStatChip(
                    icon: Icons.schedule,
                    label: formatNavigationDuration(route.durationSeconds),
                  ),
                  if (route.hasWaypoints)
                    _RouteStatChip(
                      icon: Icons.place_outlined,
                      label: '${route.waypoints.length} parada'
                          '${route.waypoints.length == 1 ? '' : 's'}',
                    ),
                  _RouteStatChip(
                    icon: Icons.tune,
                    label: preferencesSummary,
                  ),
                ],
              ),
              if (enriching) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Buscando avisos en la ruta…',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ] else if (route.hasAlerts) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if ((alertCounts[RouteAlertType.toll] ?? 0) > 0)
                      _RouteStatChip(
                        icon: Icons.toll_outlined,
                        label: '${alertCounts[RouteAlertType.toll]} peaje'
                            '${(alertCounts[RouteAlertType.toll] ?? 0) == 1 ? '' : 's'}',
                      ),
                    if ((alertCounts[RouteAlertType.fuel] ?? 0) > 0)
                      _RouteStatChip(
                        icon: Icons.local_gas_station_outlined,
                        label: '${alertCounts[RouteAlertType.fuel]} gasolinera'
                            '${(alertCounts[RouteAlertType.fuel] ?? 0) == 1 ? '' : 's'}',
                      ),
                    if ((alertCounts[RouteAlertType.speedCamera] ?? 0) > 0)
                      _RouteStatChip(
                        icon: Icons.camera_alt_outlined,
                        label:
                            '${alertCounts[RouteAlertType.speedCamera]} radar'
                            '${(alertCounts[RouteAlertType.speedCamera] ?? 0) == 1 ? '' : 'es'}',
                      ),
                    if ((alertCounts[RouteAlertType.sharpCurve] ?? 0) > 0)
                      _RouteStatChip(
                        icon: Icons.turn_sharp_right,
                        label: '${alertCounts[RouteAlertType.sharpCurve]} curva'
                            '${(alertCounts[RouteAlertType.sharpCurve] ?? 0) == 1 ? '' : 's'}',
                      ),
                  ],
                ),
              ] else if (!enriching &&
                  fuelAlertsEnabled &&
                  !fuelCacheReady) ...[
                const SizedBox(height: 10),
                Text(
                  'Descarga gasolineras en Configuración para ver precios en la ruta.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _RouteEndpointRow(
                icon: Icons.trip_origin,
                iconColor: const Color(0xFF2E7D32),
                title: 'Origen',
                subtitle: route.originDisplay,
              ),
              if (route.hasWaypoints) ...[
                for (var i = 0; i < route.waypoints.length; i++) ...[
                  const SizedBox(height: 8),
                  _RouteEndpointRow(
                    icon: Icons.radio_button_checked,
                    iconColor: const Color(0xFFF9A825),
                    title: 'Parada ${i + 1}',
                    subtitle:
                        '${route.waypoints[i].lat.toStringAsFixed(5)}, '
                        '${route.waypoints[i].lng.toStringAsFixed(5)}',
                  ),
                ],
              ],
              const SizedBox(height: 8),
              _RouteEndpointRow(
                icon: Icons.flag_outlined,
                iconColor: const Color(0xFFC62828),
                title: 'Destino',
                subtitle: route.destinationDisplay,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.navigation),
                label: const Text('Empezar navegación'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RouteAlternativeChip extends StatelessWidget {
  const _RouteAlternativeChip({
    required this.index,
    required this.route,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final NavigationRoute route;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final label = index == 0 ? 'Sugerida' : 'Opción ${index + 1}';

    return Material(
      color: selected ? colors.primaryContainer : colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? colors.primary : colors.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: selected
                      ? colors.onPrimaryContainer
                      : colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                formatNavigationDurationCompact(route.durationSeconds),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  color: selected ? colors.primary : colors.onSurface,
                ),
              ),
              Text(
                formatRideDistance(route.distanceMeters),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  height: 1.1,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RouteStatChip extends StatelessWidget {
  const _RouteStatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _RouteEndpointRow extends StatelessWidget {
  const _RouteEndpointRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
