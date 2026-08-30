import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loc_motos/core/utils/spain_data_freshness.dart';
import 'package:loc_motos/core/utils/distance_format.dart';
import 'package:loc_motos/core/utils/navigation_duration_format.dart';
import 'package:loc_motos/core/widgets/map_quick_action_tile.dart';
import 'package:loc_motos/features/auth/domain/entities/app_user.dart';
import 'package:loc_motos/features/groups/presentation/providers/group_providers.dart';
import 'package:loc_motos/features/navigation/domain/entities/alert_preferences.dart';
import 'package:loc_motos/features/navigation/domain/entities/hybrid_map_styles.dart';
import 'package:loc_motos/features/navigation/domain/entities/navigation_route.dart';
import 'package:loc_motos/features/navigation/domain/entities/route_alert.dart';
import 'package:loc_motos/features/navigation/domain/entities/route_plan.dart';
import 'package:loc_motos/features/navigation/presentation/models/navigation_map_camera_mode.dart';
import 'package:loc_motos/features/navigation/presentation/providers/navigation_providers.dart';
import 'package:loc_motos/features/navigation/presentation/screens/navigation_hud_screen.dart';
import 'package:loc_motos/features/navigation/presentation/widgets/collapsible_map_bottom_panel.dart';
import 'package:loc_motos/features/navigation/presentation/widgets/map_network_resume_binder.dart';
import 'package:loc_motos/features/navigation/presentation/widgets/navigation_map_view.dart';
import 'package:loc_motos/features/navigation/presentation/widgets/navigation_map_zoom_controls.dart';
import 'package:loc_motos/features/navigation/presentation/widgets/navigation_map_my_location_button.dart';
import 'package:loc_motos/features/navigation/presentation/widgets/offline_map_banner.dart';
import 'package:loc_motos/features/tracking/presentation/providers/tracking_providers.dart';
import 'package:loc_motos/features/tracking/presentation/widgets/own_position_watcher.dart';
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
  final _enrichedRouteIds = <String>{};
  /// null = valor de Configuración; true/false = override en esta pantalla.
  bool? _showFuelOnMap;
  bool? _showRadarOnMap;
  bool? _showTollOnMap;
  bool? _showCurveOnMap;

  @override
  void initState() {
    super.initState();
    _plan = widget.plan;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_enrichAllAlternatives());
    });
  }

  void _selectAlternative(int index) {
    final next = _plan.select(index);
    if (next.selectedIndex == _plan.selectedIndex) {
      return;
    }
    setState(() => _plan = next);
    ref.read(activeNavigationRouteProvider.notifier).state = next.selected;
  }

  bool _fuelVisibleOnMap(AlertPreferences prefs) {
    if (!prefs.fuelEnabled) {
      return false;
    }
    return _showFuelOnMap ?? prefs.fuelShowOnPreview;
  }

  bool _radarVisibleOnMap(AlertPreferences prefs) {
    if (!prefs.radarsEnabled) {
      return false;
    }
    return _showRadarOnMap ?? prefs.radarShowOnPreview;
  }

  bool _tollVisibleOnMap(AlertPreferences prefs) {
    if (!prefs.tollsEnabled) {
      return false;
    }
    return _showTollOnMap ?? prefs.tollShowOnPreview;
  }

  bool _curveVisibleOnMap(AlertPreferences prefs) {
    if (!prefs.curvesEnabled) {
      return false;
    }
    return _showCurveOnMap ?? prefs.curvesShowOnPreview;
  }

  AlertPreferences _mapAlertPreferences(AlertPreferences prefs) {
    return prefs.copyWith(
      fuelShowOnMap: _fuelVisibleOnMap(prefs),
      radarShowOnMap: _radarVisibleOnMap(prefs),
      tollShowOnMap: _tollVisibleOnMap(prefs),
      curvesShowOnMap: _curveVisibleOnMap(prefs),
    );
  }

  void _toggleFuelOnMap() {
    final prefs = ref.read(alertPreferencesProvider);
    setState(() => _showFuelOnMap = !_fuelVisibleOnMap(prefs));
  }

  void _toggleRadarOnMap() {
    final prefs = ref.read(alertPreferencesProvider);
    setState(() => _showRadarOnMap = !_radarVisibleOnMap(prefs));
  }

  void _toggleTollOnMap() {
    final prefs = ref.read(alertPreferencesProvider);
    setState(() => _showTollOnMap = !_tollVisibleOnMap(prefs));
  }

  void _toggleCurveOnMap() {
    final prefs = ref.read(alertPreferencesProvider);
    setState(() => _showCurveOnMap = !_curveVisibleOnMap(prefs));
  }

  Future<void> _enrichAllAlternatives() async {
    final pending = [
      for (final route in _plan.alternatives)
        if (!_enrichedRouteIds.contains(route.id)) route,
    ];
    if (pending.isEmpty) {
      return;
    }

    setState(() => _enriching = true);
    final preferredFuel = resolveNavigationPreferredFuel(
      user: widget.user,
      vehicleId: ref.read(navigationVehicleIdProvider),
    );
    final preferences = ref.read(alertPreferencesProvider);
    final service = ref.read(routeAlertsServiceProvider);

    final results = await Future.wait(
      pending.map((route) async {
        try {
          return await service.enrich(
            route,
            preferredFuel: preferredFuel,
            preferences: preferences,
          );
        } catch (_) {
          // Overpass/Valhalla opcionales: la preview sigue usable.
          return route;
        }
      }),
    );

    if (!mounted) {
      return;
    }

    final byId = <String, NavigationRoute>{
      for (final route in results) route.id: route,
    };
    for (final route in pending) {
      _enrichedRouteIds.add(route.id);
    }

    final alts = [
      for (final route in _plan.alternatives) byId[route.id] ?? route,
    ];
    setState(() {
      _plan = RoutePlan(
        alternatives: alts,
        selectedIndex: _plan.selectedIndex,
      );
      _enriching = false;
    });
    ref.read(activeNavigationRouteProvider.notifier).state = _plan.selected;
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
    // Sustituye la preview: dos MapLibre a la vez tumba el proceso Android 11.
    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => NavigationHudScreen(
          route: route,
          user: widget.user,
          enableGroupFeatures:
              (widget.user.currentGroupId ?? '').isNotEmpty,
        ),
      ),
      (route) => route.isFirst,
    );
  }

  Future<void> _shareGpx() async {
    final route = _plan.selected;
    final name = route.destinationLabel?.trim().isNotEmpty == true
        ? 'Ruta a ${route.destinationLabel!.trim()}'
        : 'Ruta LocMotos';
    try {
      await ref.read(routeGpxServiceProvider).shareRoute(route, name: name);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo compartir el GPX.')),
      );
    }
  }

  Future<void> _publishToGroup({required bool updating}) async {
    final groupId = widget.user.currentGroupId;
    if (groupId == null || groupId.isEmpty) {
      return;
    }
    await ref.read(groupActionControllerProvider.notifier).publishSharedRoute(
          actor: widget.user,
          groupId: groupId,
          route: _plan.selected,
        );
    if (!mounted) {
      return;
    }
    final error = ref.read(groupActionControllerProvider).asError?.error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error == null
              ? (updating
                  ? 'Ruta del grupo actualizada'
                  : 'Ruta compartida con el grupo')
              : 'No se pudo publicar: $error',
        ),
      ),
    );
  }

  Future<void> _clearGroupRoute() async {
    final groupId = widget.user.currentGroupId;
    if (groupId == null || groupId.isEmpty) {
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Quitar la ruta del grupo?'),
        content: const Text(
          'El grupo dejará de ver esta ruta en el mapa. '
          'Podrás compartir otra más adelante.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) {
      return;
    }
    await ref.read(groupActionControllerProvider.notifier).clearSharedRoute(
          actor: widget.user,
          groupId: groupId,
        );
    if (!mounted) {
      return;
    }
    final error = ref.read(groupActionControllerProvider).asError?.error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error == null
              ? 'Ruta del grupo eliminada'
              : 'No se pudo quitar: $error',
        ),
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
    final alertPrefs = ref.watch(alertPreferencesProvider);
    final mapAlertPrefs = _mapAlertPreferences(alertPrefs);
    final showFuelToggle = alertPrefs.fuelEnabled;
    final showRadarToggle = alertPrefs.radarsEnabled;
    final showTollToggle = alertPrefs.tollsEnabled;
    final showCurveToggle = alertPrefs.curvesEnabled;
    final fuelOnMap = _fuelVisibleOnMap(alertPrefs);
    final radarOnMap = _radarVisibleOnMap(alertPrefs);
    final tollOnMap = _tollVisibleOnMap(alertPrefs);
    final curveOnMap = _curveVisibleOnMap(alertPrefs);
    final groupId = widget.user.currentGroupId;
    final group = groupId == null || groupId.isEmpty
        ? null
        : ref.watch(rideGroupProvider(groupId)).asData?.value;
    final canPublishGroupRoute =
        group != null && group.isActive && group.isAdmin(widget.user.uid);
    final hasSharedRoute = groupId != null &&
        groupId.isNotEmpty &&
        (ref.watch(groupHasSharedRouteProvider(groupId)).asData?.value ==
            true);
    final publishBusy = ref.watch(groupActionControllerProvider).isLoading;
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final screenSize = MediaQuery.sizeOf(context);
    final top = MediaQuery.paddingOf(context).top;

    return OwnPositionWatcher(
      child: MapNetworkResumeBinder(
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          body: mapStyleAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) =>
                const Center(child: Text('No se pudo cargar el mapa.')),
            data: (mapStyles) {
              final mapLayer = _RoutePreviewMapLayer(
                route: route,
                alternativeRoutes: _plan.otherAlternatives,
                mapStyles: mapStyles,
                hasNetwork: hasNetwork,
                showOfflineBanner: showOfflineBanner,
                alertPreferences: mapAlertPrefs,
                showFuelToggle: showFuelToggle,
                showRadarToggle: showRadarToggle,
                showTollToggle: showTollToggle,
                showCurveToggle: showCurveToggle,
                fuelVisibleOnMap: fuelOnMap,
                radarVisibleOnMap: radarOnMap,
                tollVisibleOnMap: tollOnMap,
                curveVisibleOnMap: curveOnMap,
                onToggleFuel: _toggleFuelOnMap,
                onToggleRadar: _toggleRadarOnMap,
                onToggleToll: _toggleTollOnMap,
                onToggleCurve: _toggleCurveOnMap,
              );

              final previewSheet = _RoutePreviewSheet(
                plan: _plan,
                enriching: _enriching,
                enrichedRouteIds: _enrichedRouteIds,
                preferencesSummary:
                    ref.watch(routePreferencesProvider).summaryLabel,
                fuelCacheReady: ref
                        .watch(spainFuelCacheStatusProvider)
                        .asData
                        ?.value
                        .isReady ??
                    false,
                fuelStaleMessage: () {
                  final status = ref
                      .watch(spainFuelCacheStatusProvider)
                      .asData
                      ?.value;
                  if (status == null || !status.isReady) {
                    return null;
                  }
                  final message = spainFuelStaleMessage(status.fetchedAt);
                  return message.isEmpty ? null : message;
                }(),
                radarStaleMessage: () {
                  final status = ref
                      .watch(spainRadarCacheStatusProvider)
                      .asData
                      ?.value;
                  if (status == null || !status.isReady) {
                    return null;
                  }
                  final message = spainRadarCacheStaleMessage(
                    hasOfficial: status.hasOfficial,
                    officialFetchedAt: status.officialFetchedAt,
                    hasOsm: status.hasOsm,
                    osmFetchedAt: status.osmFetchedAt,
                  );
                  return message.isEmpty ? null : message;
                }(),
                fuelAlertsEnabled: alertPrefs.fuelEnabled,
                radarAlertsEnabled: alertPrefs.radarsEnabled,
                onSelect: _selectAlternative,
                onShare: () => unawaited(_shareGpx()),
                onStart: _startNavigation,
                canPublishToGroup: canPublishGroupRoute,
                publishBusy: publishBusy,
                updatingGroupRoute: hasSharedRoute,
                onPublishToGroup: () => unawaited(
                  _publishToGroup(updating: hasSharedRoute),
                ),
                onClearGroupRoute: hasSharedRoute && canPublishGroupRoute
                    ? () => unawaited(_clearGroupRoute())
                    : null,
                maxHeight: screenSize.height * 0.46,
              );

              if (landscape) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    mapLayer,
                    Positioned(
                      left: 8,
                      top: top + 64,
                      bottom: 8,
                      width: (screenSize.width * 0.38).clamp(300.0, 400.0),
                      child: previewSheet,
                    ),
                  ],
                );
              }

              return Column(
                children: [
                  Expanded(child: mapLayer),
                  previewSheet,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RoutePreviewMapLayer extends ConsumerStatefulWidget {
  const _RoutePreviewMapLayer({
    required this.route,
    required this.alternativeRoutes,
    required this.mapStyles,
    required this.hasNetwork,
    required this.showOfflineBanner,
    required this.alertPreferences,
    required this.showFuelToggle,
    required this.showRadarToggle,
    required this.showTollToggle,
    required this.showCurveToggle,
    required this.fuelVisibleOnMap,
    required this.radarVisibleOnMap,
    required this.tollVisibleOnMap,
    required this.curveVisibleOnMap,
    required this.onToggleFuel,
    required this.onToggleRadar,
    required this.onToggleToll,
    required this.onToggleCurve,
  });

  final NavigationRoute route;
  final List<NavigationRoute> alternativeRoutes;
  final HybridMapStyles mapStyles;
  final bool hasNetwork;
  final bool showOfflineBanner;
  final AlertPreferences alertPreferences;
  final bool showFuelToggle;
  final bool showRadarToggle;
  final bool showTollToggle;
  final bool showCurveToggle;
  final bool fuelVisibleOnMap;
  final bool radarVisibleOnMap;
  final bool tollVisibleOnMap;
  final bool curveVisibleOnMap;
  final VoidCallback onToggleFuel;
  final VoidCallback onToggleRadar;
  final VoidCallback onToggleToll;
  final VoidCallback onToggleCurve;

  @override
  ConsumerState<_RoutePreviewMapLayer> createState() =>
      _RoutePreviewMapLayerState();
}

class _RoutePreviewMapLayerState extends ConsumerState<_RoutePreviewMapLayer> {
  MapLibreMapController? _mapController;
  double? _focusLat;
  double? _focusLng;
  var _focusEpoch = 0;

  void _recenterOnMe() {
    final own = ref.read(ownDevicePositionProvider);
    if (own == null) {
      return;
    }
    setState(() {
      _focusLat = own.lat;
      _focusLng = own.lng;
      _focusEpoch++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final top = MediaQuery.paddingOf(context).top + 8;
    final own = ref.watch(ownDevicePositionProvider);

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.hardEdge,
      children: [
        NavigationMapView(
          route: widget.route,
          alternativeRoutes: widget.alternativeRoutes,
          mapStyles: widget.mapStyles,
          hasNetwork: widget.hasNetwork,
          alertPreferences: widget.alertPreferences,
          cameraMode: NavigationMapCameraMode.fitRoute,
          previewFocusLatitude: _focusLat,
          previewFocusLongitude: _focusLng,
          previewFocusEpoch: _focusEpoch,
          lowGlCompat: ref.watch(lowGlMapModeProvider),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                NavigationMapZoomControls(controller: _mapController!),
                const SizedBox(height: 8),
                NavigationMapMyLocationButton(
                  enabled: own != null,
                  onPressed: own == null ? null : _recenterOnMe,
                ),
                if (widget.showFuelToggle) ...[
                  const SizedBox(height: 8),
                  _PreviewMapToggleButton(
                    tooltip: widget.fuelVisibleOnMap
                        ? 'Ocultar gasolineras'
                        : 'Mostrar gasolineras',
                    icon: Icons.local_gas_station_outlined,
                    active: widget.fuelVisibleOnMap,
                    onPressed: widget.onToggleFuel,
                  ),
                ],
                if (widget.showRadarToggle) ...[
                  const SizedBox(height: 8),
                  _PreviewMapToggleButton(
                    tooltip: widget.radarVisibleOnMap
                        ? 'Ocultar radares'
                        : 'Mostrar radares',
                    icon: Icons.camera_alt_outlined,
                    active: widget.radarVisibleOnMap,
                    onPressed: widget.onToggleRadar,
                  ),
                ],
                if (widget.showTollToggle) ...[
                  const SizedBox(height: 8),
                  _PreviewMapToggleButton(
                    tooltip: widget.tollVisibleOnMap
                        ? 'Ocultar peajes'
                        : 'Mostrar peajes',
                    icon: Icons.toll_outlined,
                    active: widget.tollVisibleOnMap,
                    onPressed: widget.onToggleToll,
                  ),
                ],
                if (widget.showCurveToggle) ...[
                  const SizedBox(height: 8),
                  _PreviewMapToggleButton(
                    tooltip: widget.curveVisibleOnMap
                        ? 'Ocultar curvas'
                        : 'Mostrar curvas',
                    icon: Icons.turn_sharp_right,
                    active: widget.curveVisibleOnMap,
                    onPressed: widget.onToggleCurve,
                  ),
                ],
              ],
            ),
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

class _PreviewMapToggleButton extends StatelessWidget {
  const _PreviewMapToggleButton({
    required this.tooltip,
    required this.icon,
    required this.active,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      elevation: 3,
      color: active
          ? colors.primaryContainer.withValues(alpha: 0.96)
          : colors.surface.withValues(alpha: 0.96),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(
          icon,
          color: active ? colors.primary : colors.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _RoutePreviewSheet extends StatelessWidget {
  const _RoutePreviewSheet({
    required this.plan,
    required this.enriching,
    required this.enrichedRouteIds,
    required this.preferencesSummary,
    required this.fuelCacheReady,
    required this.fuelAlertsEnabled,
    required this.radarAlertsEnabled,
    this.fuelStaleMessage,
    this.radarStaleMessage,
    required this.onSelect,
    required this.onShare,
    required this.onStart,
    this.canPublishToGroup = false,
    this.publishBusy = false,
    this.updatingGroupRoute = false,
    this.onPublishToGroup,
    this.onClearGroupRoute,
    required this.maxHeight,
  });

  final RoutePlan plan;
  final bool enriching;
  final Set<String> enrichedRouteIds;
  final String preferencesSummary;
  final bool fuelCacheReady;
  final bool fuelAlertsEnabled;
  final bool radarAlertsEnabled;
  final String? fuelStaleMessage;
  final String? radarStaleMessage;
  final ValueChanged<int> onSelect;
  final VoidCallback onShare;
  final VoidCallback onStart;
  final bool canPublishToGroup;
  final bool publishBusy;
  final bool updatingGroupRoute;
  final VoidCallback? onPublishToGroup;
  final VoidCallback? onClearGroupRoute;
  final double maxHeight;

  int? get _fastestIndex {
    if (plan.alternatives.length < 2) {
      return null;
    }
    var bestIndex = 0;
    var bestSeconds = plan.alternatives.first.durationSeconds;
    for (var i = 1; i < plan.alternatives.length; i++) {
      final seconds = plan.alternatives[i].durationSeconds;
      if (seconds < bestSeconds) {
        bestSeconds = seconds;
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  String? _alertsSummaryLine(Map<RouteAlertType, int> counts) {
    final parts = <String>[];
    final tolls = counts[RouteAlertType.toll] ?? 0;
    final fuel = counts[RouteAlertType.fuel] ?? 0;
    final radars = counts[RouteAlertType.speedCamera] ?? 0;
    final curves = counts[RouteAlertType.sharpCurve] ?? 0;
    if (tolls > 0) {
      parts.add('$tolls peaje${tolls == 1 ? '' : 's'}');
    }
    if (fuel > 0) {
      parts.add('$fuel gasolinera${fuel == 1 ? '' : 's'}');
    }
    if (radars > 0) {
      parts.add('$radars radar${radars == 1 ? '' : 'es'}');
    }
    if (curves > 0) {
      parts.add('$curves curva${curves == 1 ? '' : 's'}');
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final hPad = landscape ? 14.0 : 20.0;
    final route = plan.selected;
    final alertCounts = <RouteAlertType, int>{
      for (final t in RouteAlertType.values) t: 0,
    };
    for (final a in route.alerts) {
      alertCounts[a.type] = (alertCounts[a.type] ?? 0) + 1;
    }
    final fastestIndex = _fastestIndex;
    final comparingLabel = plan.hasAlternatives
        ? 'Comparando rutas…'
        : 'Buscando avisos en la ruta…';
    final alertsLine = _alertsSummaryLine(alertCounts);
    final staleMessages = [
      if (!enriching && fuelAlertsEnabled && fuelStaleMessage != null)
        fuelStaleMessage!,
      if (!enriching && radarAlertsEnabled && radarStaleMessage != null)
        radarStaleMessage!,
    ];
    final panelTitle = 'Vista previa de la ruta';
    final panelSubtitle =
        '${formatRideDistance(route.distanceMeters)} · '
        '${formatNavigationDurationCompact(route.durationSeconds)}';

    Widget alternativesHeader() {
      if (!plan.hasAlternatives) {
        return Padding(
          padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 0),
          child: Text(
            preferencesSummary,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: landscape ? 6 : 10),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: hPad),
            child: Row(
              children: [
                for (var index = 0;
                    index < plan.alternatives.length;
                    index++) ...[
                  if (index > 0) SizedBox(width: landscape ? 4 : 6),
                  Expanded(
                    child: _RouteAlternativeChip(
                      index: index,
                      route: plan.alternatives[index],
                      selected: index == plan.selectedIndex,
                      enriched: enrichedRouteIds.contains(
                        plan.alternatives[index].id,
                      ),
                      isFastest: fastestIndex == index,
                      onTap: () => onSelect(index),
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: landscape ? 4 : 6),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: hPad),
            child: Text(
              preferencesSummary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      );
    }

    Widget routeDetails() {
      return Padding(
        padding: EdgeInsets.fromLTRB(hPad, landscape ? 6 : 10, hPad, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (enriching)
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
                  Expanded(
                    child: Text(
                      comparingLabel,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              )
            else if (alertsLine != null)
              Text(
                alertsLine,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              )
            else if (fuelAlertsEnabled && !fuelCacheReady)
              Text(
                'Descarga gasolineras en Configuración para ver precios en la ruta.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            if (staleMessages.isNotEmpty) ...[
              SizedBox(height: landscape ? 6 : 8),
              _SpainDataStaleHint(message: staleMessages.join(' ')),
            ],
            SizedBox(height: landscape ? 8 : 12),
            _RouteTripEndpointsCompact(
              origin: route.originDisplay,
              destination: route.destinationDisplay,
              waypointCount:
                  route.hasWaypoints ? route.waypoints.length : 0,
              compact: landscape,
            ),
          ],
        ),
      );
    }

    Widget actionButtons({required bool withBorder}) {
      final dense = landscape || MediaQuery.sizeOf(context).height < 720;
      final actionTiles = <Widget>[
        if (canPublishToGroup)
          MapQuickActionTile(
            icon: updatingGroupRoute
                ? Icons.sync_rounded
                : Icons.groups_rounded,
            label: updatingGroupRoute ? 'Actualizar' : 'Grupo',
            emphasized: true,
            enabled: !enriching && !publishBusy,
            onTap: enriching || publishBusy ? null : onPublishToGroup,
          ),
        if (onClearGroupRoute != null)
          MapQuickActionTile(
            icon: Icons.playlist_remove_rounded,
            label: 'Quitar',
            enabled: !enriching,
            onTap: enriching ? null : onClearGroupRoute,
          ),
        MapQuickActionTile(
          icon: Icons.ios_share_rounded,
          label: 'GPX',
          enabled: !enriching,
          onTap: enriching ? null : onShare,
        ),
      ];

      return Container(
        padding: EdgeInsets.fromLTRB(
          hPad,
          dense ? 6 : 8,
          hPad,
          dense ? 10 : 12,
        ),
        decoration: withBorder
            ? BoxDecoration(
                color: colors.surface,
                border: Border(
                  top: BorderSide(
                    color: colors.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                for (var i = 0; i < actionTiles.length; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(child: actionTiles[i]),
                ],
              ],
            ),
            SizedBox(height: dense ? 10 : 12),
            FilledButton(
              onPressed: enriching ? null : onStart,
              style: FilledButton.styleFrom(
                minimumSize: Size.fromHeight(dense ? 44 : 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Empezar navegación',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
    }

    return CollapsibleMapBottomPanel(
      title: panelTitle,
      subtitle: panelSubtitle,
      sidePanel: landscape,
      maxExpandedHeight: landscape ? null : maxHeight,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            alternativesHeader(),
            routeDetails(),
            actionButtons(withBorder: !landscape),
          ],
        ),
      ),
    );
  }
}

class _RouteTripEndpointsCompact extends StatelessWidget {
  const _RouteTripEndpointsCompact({
    required this.origin,
    required this.destination,
    this.waypointCount = 0,
    this.compact = false,
  });

  final String origin;
  final String destination;
  final int waypointCount;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RouteEndpointLine(
            icon: Icons.trip_origin,
            iconColor: const Color(0xFF2E7D32),
            label: origin,
            compact: compact,
          ),
          if (waypointCount > 0) ...[
            Padding(
              padding: const EdgeInsets.only(left: 9, top: 2, bottom: 2),
              child: Row(
                children: [
                  Container(
                    width: 2,
                    height: 12,
                    color: colors.outlineVariant,
                  ),
                  const SizedBox(width: 17),
                  Text(
                    waypointCount == 1
                        ? '1 parada intermedia'
                        : '$waypointCount paradas intermedias',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(left: 9),
              child: Container(
                width: 2,
                height: 10,
                color: colors.outlineVariant,
              ),
            ),
          _RouteEndpointLine(
            icon: Icons.flag_outlined,
            iconColor: const Color(0xFFC62828),
            label: destination,
            compact: compact,
          ),
        ],
      ),
    );
  }
}

class _RouteEndpointLine extends StatelessWidget {
  const _RouteEndpointLine({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.compact = false,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _RouteAlternativeChip extends StatelessWidget {
  const _RouteAlternativeChip({
    required this.index,
    required this.route,
    required this.selected,
    required this.enriched,
    required this.isFastest,
    required this.onTap,
  });

  final int index;
  final NavigationRoute route;
  final bool selected;
  final bool enriched;
  final bool isFastest;
  final VoidCallback onTap;

  int get _tollCount =>
      route.alerts.where((a) => a.type == RouteAlertType.toll).length;

  String get _tollLabel {
    if (!enriched) {
      return '…';
    }
    final count = _tollCount;
    if (count == 0) {
      return 'Sin peajes';
    }
    return '$count peaje${count == 1 ? '' : 's'}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final label = isFastest
        ? 'Más rápida'
        : (index == 0 ? 'Sugerida' : 'Opción ${index + 1}');

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
              Text(
                _tollLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  color: enriched && _tollCount > 0
                      ? colors.tertiary
                      : colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpainDataStaleHint extends StatelessWidget {
  const _SpainDataStaleHint({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.warning_amber_rounded, size: 18, color: colors.error),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.error,
                ),
          ),
        ),
      ],
    );
  }
}
