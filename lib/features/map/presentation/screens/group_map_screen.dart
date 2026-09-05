import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:moto_amg/core/constants/navigation_constants.dart';
import 'package:moto_amg/core/theme/hub_style.dart';
import 'package:moto_amg/core/utils/distance_format.dart';
import 'package:moto_amg/core/utils/external_navigation.dart';
import 'package:moto_amg/core/utils/gps_status.dart';
import 'package:moto_amg/features/auth/domain/entities/app_user.dart';
import 'package:moto_amg/features/auth/domain/entities/vehicle_map_marker.dart';
import 'package:moto_amg/features/auth/presentation/widgets/vehicle_navigation_marker.dart';
import 'package:moto_amg/features/groups/domain/entities/group_incident.dart';
import 'package:moto_amg/features/groups/domain/entities/group_member.dart';
import 'package:moto_amg/features/groups/domain/entities/group_voice_announcement.dart';
import 'package:moto_amg/features/groups/domain/entities/ride_role.dart';
import 'package:moto_amg/features/groups/domain/services/group_pack_proximity_tracker.dart';
import 'package:moto_amg/features/groups/domain/services/group_ride_alert_feedback.dart';
import 'package:moto_amg/features/groups/presentation/providers/group_providers.dart';
import 'package:moto_amg/features/groups/presentation/widgets/catch_up_cabecera_sheet.dart';
import 'package:moto_amg/features/groups/presentation/widgets/group_incident_session_panel.dart';
import 'package:moto_amg/features/groups/presentation/widgets/group_incident_widgets.dart';
import 'package:moto_amg/features/groups/presentation/widgets/group_pack_list_sheet.dart';
import 'package:moto_amg/features/groups/domain/entities/group_stop.dart';
import 'package:moto_amg/features/groups/domain/services/group_stop_service.dart';
import 'package:moto_amg/features/groups/presentation/widgets/group_stop_map_marker.dart';
import 'package:moto_amg/features/groups/presentation/widgets/group_stops_list_sheet.dart';
import 'package:moto_amg/features/groups/presentation/widgets/group_stop_widgets.dart';
import 'package:moto_amg/features/intercom/presentation/widgets/intercom_controls_bar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:moto_amg/features/navigation/domain/entities/geo_point.dart';
import 'package:moto_amg/features/navigation/domain/entities/hybrid_map_styles.dart';
import 'package:moto_amg/features/navigation/domain/entities/navigation_route.dart';
import 'package:moto_amg/features/navigation/data/services/navigation_map_style_service.dart';
import 'package:moto_amg/features/navigation/presentation/providers/navigation_providers.dart';
import 'package:moto_amg/features/navigation/presentation/screens/navigation_hub_screen.dart';
import 'package:moto_amg/features/navigation/presentation/helpers/enrich_route_limits_before_navigation.dart';
import 'package:moto_amg/features/navigation/presentation/screens/navigation_hud_screen.dart';
import 'package:moto_amg/features/navigation/presentation/widgets/navigation_map_my_location_button.dart';
import 'package:moto_amg/features/navigation/presentation/widgets/navigation_map_zoom_controls.dart';
import 'package:moto_amg/features/navigation/presentation/widgets/offline_map_banner.dart';
import 'package:moto_amg/features/settings/presentation/screens/offline_maps_settings_screen.dart';
import 'package:moto_amg/features/tracking/domain/entities/device_position.dart';
import 'package:moto_amg/features/tracking/domain/entities/live_location.dart';
import 'package:moto_amg/features/tracking/presentation/providers/tracking_providers.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

/// Mapa en vivo del grupo: mismo motor/estilos que navegación (MapLibre).
class GroupMapView extends ConsumerStatefulWidget {
  const GroupMapView({
    super.key,
    required this.user,
    required this.groupId,
  });

  final AppUser user;
  final String groupId;

  @override
  ConsumerState<GroupMapView> createState() => _GroupMapViewState();
}

class _GroupMapViewState extends ConsumerState<GroupMapView> {
  /// Evita destruir el mapa si el GPS parpadea un instante.
  var _hadGpsFix = false;

  @override
  Widget build(BuildContext context) {
    // Pausar MapLibre solo si hay otra pantalla completa encima (HUD, hub…),
    // NO cuando hay un diálogo modal: isCurrent=false pero isActive=true.
    final route = ModalRoute.of(context);
    final routeIsActive = route?.isActive ?? true;
    if (!routeIsActive) {
      return const ColoredBox(color: Color(0xFF1A1F24));
    }

    final hasFix = ref.watch(
      ownDevicePositionProvider.select((value) => value != null),
    );
    if (hasFix) {
      _hadGpsFix = true;
    }
    if (!_hadGpsFix && !hasFix) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Buscando tu ubicación…\n'
                'Si usas el emulador: tres puntitos → Location → elige tu zona.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final mapStylesAsync = ref.watch(hybridMapStylesProvider);
    final cachedStyles = mapStylesAsync.valueOrNull;
    if (cachedStyles == null) {
      return mapStylesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('No se pudo cargar el mapa.\n$error'),
          ),
        ),
        data: (_) => const SizedBox.shrink(),
      );
    }

    return _GroupMapCanvas(
      user: widget.user,
      groupId: widget.groupId,
      mapStyles: cachedStyles,
    );
  }
}

class _GroupMapCanvas extends ConsumerStatefulWidget {
  const _GroupMapCanvas({
    required this.user,
    required this.groupId,
    required this.mapStyles,
  });

  final AppUser user;
  final String groupId;
  final HybridMapStyles mapStyles;

  @override
  ConsumerState<_GroupMapCanvas> createState() => _GroupMapCanvasState();
}

class _GroupMapCanvasState extends ConsumerState<_GroupMapCanvas> {
  static const _meColor = Color(0xFF1565C0);
  static const _groupColor = Color(0xFFE65100);
  static const _cabeceraColor = Color(0xFF2E7D32);
  static const _colaColor = Color(0xFFEF6C00);
  static const _staleColor = Color(0xFF78909C);
  static const _emergenciaColor = Color(0xFFC62828);
  static const _averiaColor = Color(0xFFFFA000);
  static const _separadoColor = Color(0xFF1565C0);
  static const _stopCafeColor = Color(0xFF795548);
  static const _stopFuelColor = Color(0xFF388E3C);
  static const _stopWaitColor = Color(0xFF8E24AA);
  static const _stopMeetColor = Color(0xFF00897B);
  static const _routeOriginColor = Color(0xFF2E7D32);
  static const _routeDestColor = Color(0xFFC62828);
  static const _routeWaypointColor = Color(0xFFEF6C00);

  static const _iconMe = 'motoamg-group-me';
  static const _iconGroup = 'motoamg-group-mate';
  static const _iconCabecera = 'motoamg-group-cabecera';
  static const _iconCola = 'motoamg-group-cola';
  static const _iconStale = 'motoamg-group-stale';
  static const _iconEmergencia = 'motoamg-group-emergencia';
  static const _iconAveria = 'motoamg-group-averia';
  static const _iconSeparado = 'motoamg-group-separado';
  static const _iconStopCafe = 'motoamg-group-stop-cafe';
  static const _iconStopFuel = 'motoamg-group-stop-fuel';
  static const _iconStopWait = 'motoamg-group-stop-wait';
  static const _iconStopMeet = 'motoamg-group-stop-meet';
  static const _iconRouteOrigin = 'motoamg-group-route-origin';
  static const _iconRouteDest = 'motoamg-group-route-dest';
  static const _iconRouteWaypoint = 'motoamg-group-route-waypoint';

  static const _routeSourceId = 'motoamg-group-route';
  static const _routeLineLayerId = 'motoamg-group-route-line';

  MapLibreMapController? _controller;
  late String _activeStyle;
  var _styleSwitching = false;
  var _iconsReady = false;
  var _routeLayerReady = false;
  var _followGroup = true;
  var _programmaticCamera = false;
  DateTime? _lastFollowFit;
  var _fittedUids = <String>{};
  final _symbols = <String, Symbol>{};
  final _stopSymbols = <String, Symbol>{};
  final _routePointSymbols = <String, Symbol>{};
  NavigationPuckStyle? _loadedPuckStyle;
  NavigationRoute? _lastSharedRoute;

  final _dismissedBannerIds = <String>{};
  final _seenIncidentKeys = <String>{};
  var _incidentAlertPrimed = false;
  final _packTracker = GroupPackProximityTracker();

  String? _focusedStopId;
  Timer? _focusStopTimer;

  LatLng get _initialTarget {
    final own = ref.read(ownDevicePositionProvider);
    if (own != null) {
      return LatLng(own.lat, own.lng);
    }
    return const LatLng(41.6488, -0.8891);
  }

  @override
  void initState() {
    super.initState();
    final own = ref.read(ownDevicePositionProvider);
    _activeStyle = widget.mapStyles.resolve(
      own?.lat ?? 41.6488,
      own?.lng ?? -0.8891,
      hasNetwork: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final own = ref.watch(ownDevicePositionProvider);
    final gpsLost = ref.watch(ownGpsLostProvider);
    ref.watch(gpsClockProvider);
    final now = DateTime.now();
    final hasNetwork =
        ref.watch(mapNetworkAvailableProvider).asData?.value ?? true;
    final locationsAsync = ref.watch(groupLocationsProvider(widget.groupId));
    final members =
        ref.watch(groupMembersProvider(widget.groupId)).asData?.value;
    final sharedRoute =
        ref.watch(groupSharedRouteProvider(widget.groupId)).asData?.value;
    final stopsAsync = ref.watch(groupStopsProvider(widget.groupId));
    final stops = stopsAsync.valueOrNull ?? const <GroupStop>[];
    final packPrefs = ref.watch(groupPackAlertProvider);
    final group =
        ref.watch(rideGroupProvider(widget.groupId)).asData?.value;
    final iAmAdmin = group?.isAdmin(widget.user.uid) ?? false;
    final iAmCabecera = members?.any(
          (member) =>
              member.uid == widget.user.uid &&
              member.rideRole == RideRole.cabecera,
        ) ??
        false;
    final canManageStops = iAmAdmin || iAmCabecera;
    // Solo creador/admin prepara o cambia la ruta del grupo.
    final canPrepareRoute = iAmAdmin;
    final incidentsAsync = ref.watch(groupIncidentsProvider(widget.groupId));
    final incidents = incidentsAsync.valueOrNull ?? const <GroupIncident>[];
    final locations = locationsAsync.valueOrNull ?? const <LiveLocation>[];
    final entries = _buildEntries(
      locations,
      own ??
          ownDevicePosition(
            lat: _initialTarget.latitude,
            lng: _initialTarget.longitude,
          ),
      now: now,
      ownGpsLost: gpsLost,
      members: members,
      incidents: incidents,
    );
    final memberUids = {
      widget.user.uid,
      if (members != null && members.isNotEmpty)
        ...members.map((member) => member.uid),
    };
    final liveUids = {
      for (final location in locations)
        if (members == null ||
            members.isEmpty ||
            memberUids.contains(location.uid))
          location.uid,
      widget.user.uid,
    };
    final waiting = (members ?? const <GroupMember>[])
        .where((member) => !liveUids.contains(member.uid))
        .map((member) => member.displayName)
        .where((name) => name.trim().isNotEmpty)
        .toList();

    final puckStyle = resolveNavigationPuckStyle(user: widget.user);
    final bannerIncident = _highestPriorityBanner(incidents);
    final lowGl = ref.watch(lowGlMapModeProvider);

    ref.listen(mapNetworkAvailableProvider, (previous, next) {
      final online = next.asData?.value;
      if (online == null) {
        return;
      }
      unawaited(_syncStyle(hasNetwork: online));
    });

    ref.listen(groupIncidentsProvider(widget.groupId), (previous, next) {
      next.when(
        data: (list) => _maybeAlertNewIncidents(list),
        error: (_, _) {},
        loading: () {},
      );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_syncMembers(entries, puckStyle: puckStyle));
      unawaited(_syncSharedRoute(sharedRoute));
      unawaited(_syncGroupStops(stops));
      _scheduleFollow(
        liveUids,
        [
          for (final e in entries) LatLng(e.lat, e.lng),
          for (final stop in stops) LatLng(stop.point.lat, stop.point.lng),
          if (sharedRoute != null) ...[
            LatLng(sharedRoute.origin.lat, sharedRoute.origin.lng),
            LatLng(sharedRoute.destination.lat, sharedRoute.destination.lng),
            for (final wp in sharedRoute.waypoints)
              LatLng(wp.lat, wp.lng),
            ..._samplePolyline(sharedRoute.polyline),
          ],
        ],
      );
      _maybeEvaluatePackAlerts(
        own: own,
        locations: locations,
        members: members,
        now: now,
      );
    });

    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    Widget quickActions({
      required bool embedded,
      bool compact = false,
    }) {
      return _GroupMapQuickActions(
        embedded: embedded,
        compact: compact,
        hasSharedRoute: sharedRoute != null,
        preferExternalNav: packPrefs.preferExternalNavigation,
        followGroup: _followGroup,
        onPrepareRoute: canPrepareRoute
            ? () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => NavigationHubScreen(
                      user: widget.user.copyWith(
                        currentGroupId: widget.groupId,
                      ),
                      enableGroupFeatures: true,
                    ),
                  ),
                );
              }
            : null,
        onClearRoute: iAmAdmin && sharedRoute != null
            ? () => unawaited(_confirmClearSharedRoute())
            : null,
        onNavigate: sharedRoute == null
            ? null
            : () => unawaited(_openGroupNavigation(sharedRoute)),
        onOpenWaze: sharedRoute == null
            ? null
            : () => unawaited(
                  _openExternalNavigation(
                    ExternalNavigation.wazeTo(sharedRoute.destination),
                  ),
                ),
        onOpenGoogleMaps: sharedRoute == null
            ? null
            : () => unawaited(
                  _openExternalNavigation(
                    ExternalNavigation.googleMapsNavigationTo(
                      sharedRoute.destination,
                    ),
                    fallback: ExternalNavigation.googleMapsWebTo(
                      sharedRoute.destination,
                    ),
                  ),
                ),
        onShowStops: canManageStops || stops.isNotEmpty
            ? () => unawaited(
                  _openStopsSheet(canManageStops: canManageStops),
                )
            : null,
        stopCount: stops.length,
        onPackList: () => unawaited(
          showGroupPackListSheet(
            context: context,
            groupId: widget.groupId,
            user: widget.user,
          ),
        ),
        onRecenter: _recenterGroup,
      );
    }

    final padding = MediaQuery.paddingOf(context);
    final viewPadding = MediaQuery.viewPaddingOf(context);
    var leftSafe = math.max(padding.left, viewPadding.left);
    var rightSafe = math.max(padding.right, viewPadding.right);
    for (final feature in MediaQuery.displayFeaturesOf(context)) {
      if (feature.bounds.left < 96) {
        leftSafe = math.max(leftSafe, feature.bounds.right);
      }
      final screenWidth = MediaQuery.sizeOf(context).width;
      if (feature.bounds.right > screenWidth - 96) {
        rightSafe = math.max(rightSafe, screenWidth - feature.bounds.left);
      }
    }
    final mapTop = 8.0;

    Widget mapMapControls() {
      final controller = _controller;
      if (controller == null) {
        return const SizedBox.shrink();
      }
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          NavigationMapZoomControls(
            controller: controller,
            onZoom: () {
              if (_followGroup) {
                setState(() => _followGroup = false);
              }
            },
          ),
          const SizedBox(height: 8),
          NavigationMapMyLocationButton(
            enabled: own != null,
            onPressed: own == null
                ? null
                : () => unawaited(_recenterOnMe()),
          ),
        ],
      );
    }

    // Misma composición que el HUD: MapLibre en un Stack interno y los
    // controles como hermanos en el Stack exterior (si no, Android tapa los botones).
    return Stack(
      fit: StackFit.expand,
      children: [
        Stack(
          fit: StackFit.expand,
          children: [
            MapLibreMap(
              styleString: lowGl
                  ? NavigationMapStyleService.lowGlCompatStyle()
                  : _activeStyle,
              initialCameraPosition: CameraPosition(
                target: _initialTarget,
                zoom: 15,
              ),
              onMapCreated: _onMapCreated,
              onStyleLoadedCallback: () => unawaited(_onStyleLoaded(puckStyle)),
              myLocationEnabled: false,
              compassEnabled: !lowGl,
              rotateGesturesEnabled: !lowGl,
              tiltGesturesEnabled: false,
              zoomGesturesEnabled: true,
              scrollGesturesEnabled: true,
              trackCameraPosition: true,
              onCameraIdle: _onCameraIdle,
              onMapLongClick: canManageStops
                  ? (_, latLng) => unawaited(_onMapLongPress(latLng))
                  : null,
              translucentTextureSurface: lowGl,
              annotationOrder: const [
                AnnotationType.fill,
                AnnotationType.circle,
                AnnotationType.symbol,
              ],
            ),
          ],
        ),
        Positioned(
          top: mapTop,
          // En horizontal dejar hueco al panel de incidencias (izq.) y a zoom (der.).
          left: landscape ? leftSafe + 56 : 8,
          right: landscape ? rightSafe + 112 : 72,
          child: landscape
              ? _buildLandscapeTopAlerts(
                  context,
                  sharedRoute: sharedRoute,
                  hasNetwork: hasNetwork,
                  bannerIncident: bannerIncident,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _MapLegend(
                      meColor: _meColor,
                      groupColor: _groupColor,
                      cabeceraColor: _cabeceraColor,
                      colaColor: _colaColor,
                    ),
                    if (sharedRoute != null) ...[
                      const SizedBox(height: 8),
                      GroupMapModeBanner(
                        destinationLabel: sharedRoute.destinationDisplay,
                      ),
                    ],
                    if (!hasNetwork) ...[
                      const SizedBox(height: 8),
                      const OfflineMapBanner(compact: true),
                    ],
                    if (waiting.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _WaitingBanner(names: waiting),
                    ],
                    if (locationsAsync.hasError) ...[
                      const SizedBox(height: 8),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: HubStyle.cardShadow,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Text(
                            'No se ven las motos del grupo. ${locationsAsync.error}',
                            style: HubStyle.caption(color: HubStyle.title),
                          ),
                        ),
                      ),
                    ],
                    if (bannerIncident != null) ...[
                      const SizedBox(height: 8),
                      GroupIncidentBanner(
                        incident: bannerIncident,
                        onDismiss: () {
                          setState(() {
                            _dismissedBannerIds
                                .add(_bannerId(bannerIncident));
                          });
                        },
                        isOwnIncident: false,
                        onClear: null,
                      ),
                    ],
                  ],
                ),
        ),
        if (landscape &&
            waiting.isNotEmpty &&
            bannerIncident == null)
          Positioned(
            left: leftSafe + 60,
            bottom: padding.bottom + 8,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200),
              child: _WaitingBanner(names: waiting, compact: true),
            ),
          ),
        if (_controller != null)
          Positioned(
            top: mapTop,
            right: (landscape ? rightSafe : 0) + 8,
            child: mapMapControls(),
          ),
        if (landscape && _controller != null)
          Positioned(
            right: rightSafe + 8,
            bottom: padding.bottom + 8,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onLongPress: () {},
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _GroupMapRoundButton(
                    tooltip: 'Pelotón',
                    icon: Icons.format_list_bulleted_rounded,
                    onTap: () => unawaited(
                      showGroupPackListSheet(
                        context: context,
                        groupId: widget.groupId,
                        user: widget.user,
                      ),
                    ),
                  ),
                  if (canManageStops || stops.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    _GroupMapRoundButton(
                      tooltip: stops.isNotEmpty
                          ? 'Paradas (${stops.length})'
                          : 'Paradas',
                      icon: Icons.place_outlined,
                      emphasized: stops.isNotEmpty,
                      onTap: () => unawaited(
                        _openStopsSheet(canManageStops: canManageStops),
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  _GroupMapRoundButton(
                    tooltip: 'Centrar grupo',
                    icon: Icons.groups,
                    emphasized: _followGroup,
                    onTap: _recenterGroup,
                  ),
                  if (canPrepareRoute) ...[
                    const SizedBox(width: 8),
                    _GroupMapRoundButton(
                      tooltip: sharedRoute == null
                          ? 'Preparar ruta'
                          : 'Cambiar ruta',
                      icon: Icons.route_outlined,
                      emphasized: sharedRoute == null,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => NavigationHubScreen(
                              user: widget.user.copyWith(
                                currentGroupId: widget.groupId,
                              ),
                              enableGroupFeatures: true,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                  if (iAmAdmin && sharedRoute != null) ...[
                    const SizedBox(width: 8),
                    _GroupMapRoundButton(
                      tooltip: 'Quitar ruta del grupo',
                      icon: Icons.playlist_remove_rounded,
                      onTap: () => unawaited(_confirmClearSharedRoute()),
                    ),
                  ],
                  if (sharedRoute != null) ...[
                    const SizedBox(width: 8),
                    _GroupMapRoundButton(
                      tooltip: packPrefs.preferExternalNavigation
                          ? 'Waze'
                          : 'Navegar',
                      icon: Icons.navigation_rounded,
                      onTap: packPrefs.preferExternalNavigation
                          ? () => unawaited(
                                _openExternalNavigation(
                                  ExternalNavigation.wazeTo(
                                    sharedRoute.destination,
                                  ),
                                ),
                              )
                          : () => unawaited(
                                _openGroupNavigation(sharedRoute),
                              ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        if (landscape)
          Positioned(
            left: leftSafe + 60,
            right: rightSafe + 220,
            bottom: padding.bottom + 8,
            child: IntercomControlsBar(
              groupId: widget.groupId,
              compact: true,
            ),
          ),
        if (landscape)
          Positioned(
            left: leftSafe + 8,
            bottom: padding.bottom + 8,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onLongPress: () {},
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: HubStyle.surface.withValues(alpha: 0.97),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: HubStyle.cardShadow,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: IntrinsicHeight(
                    child: SizedBox(
                      width: 48,
                      child: GroupIncidentSessionPanel(
                        groupId: widget.groupId,
                        user: widget.user,
                        compact: true,
                        vertical: true,
                        embedded: true,
                        showBanner: false,
                        drivingMode: true,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (!landscape)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 0, 6, 4),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: HubStyle.surface.withValues(alpha: 0.97),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: HubStyle.cardShadow,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IntercomControlsBar(
                          groupId: widget.groupId,
                          compact: true,
                        ),
                        quickActions(embedded: true),
                        GroupIncidentSessionPanel(
                          groupId: widget.groupId,
                          user: widget.user,
                          compact: true,
                          embedded: true,
                          showBanner: false,
                          drivingMode: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _onMapCreated(MapLibreMapController controller) async {
    _controller = controller;
    controller.onSymbolTapped.add((symbol) {
      if (!mounted) {
        return;
      }
      String? stopId;
      for (final entry in _stopSymbols.entries) {
        if (entry.value.id == symbol.id) {
          stopId = entry.key;
          break;
        }
      }
      if (stopId == null) {
        return;
      }
      final stops =
          ref.read(groupStopsProvider(widget.groupId)).valueOrNull ?? const [];
      GroupStop? stop;
      for (final candidate in stops) {
        if (candidate.id == stopId) {
          stop = candidate;
          break;
        }
      }
      if (stop != null) {
        unawaited(_focusStop(stop));
      }
    });
  }

  @override
  void dispose() {
    _focusStopTimer?.cancel();
    super.dispose();
  }

  Future<void> _onStyleLoaded(NavigationPuckStyle? puckStyle) async {
    _symbols.clear();
    _stopSymbols.clear();
    _routePointSymbols.clear();
    _iconsReady = false;
    _routeLayerReady = false;
    _loadedPuckStyle = null;
    _styleSwitching = false;
    await _ensureIcons(puckStyle);
    _iconsReady = true;
    await _syncSharedRoute(_lastSharedRoute);
  }

  void _onCameraIdle() {
    if (_styleSwitching || _programmaticCamera) {
      final hasNetwork =
          ref.read(mapNetworkAvailableProvider).asData?.value ?? true;
      unawaited(_syncStyle(hasNetwork: hasNetwork));
      return;
    }
    if (_followGroup) {
      setState(() => _followGroup = false);
    }
    final hasNetwork =
        ref.read(mapNetworkAvailableProvider).asData?.value ?? true;
    unawaited(_syncStyle(hasNetwork: hasNetwork));
  }

  Future<void> _syncStyle({required bool hasNetwork}) async {
    final controller = _controller;
    final cam = controller?.cameraPosition?.target ?? _initialTarget;
    final next = widget.mapStyles.resolve(
      cam.latitude,
      cam.longitude,
      hasNetwork: hasNetwork,
    );
    if (next == _activeStyle || controller == null) {
      return;
    }
    _activeStyle = next;
    _styleSwitching = true;
    try {
      await controller.setStyle(next);
    } catch (_) {
      _styleSwitching = false;
    }
  }

  Future<void> _ensureIcons(NavigationPuckStyle? puckStyle) async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    try {
      await _enableOverlappingSymbols(controller);
      await controller.addImage(_iconGroup, await _buildDotPng(_groupColor));
      await controller.addImage(
        _iconCabecera,
        await _buildDotPng(_cabeceraColor),
      );
      await controller.addImage(_iconCola, await _buildDotPng(_colaColor));
      await controller.addImage(_iconStale, await _buildDotPng(_staleColor));
      await controller.addImage(
        _iconEmergencia,
        await _buildDotPng(_emergenciaColor),
      );
      await controller.addImage(
        _iconAveria,
        await _buildDotPng(_averiaColor),
      );
      await controller.addImage(
        _iconSeparado,
        await _buildDotPng(_separadoColor),
      );
      await controller.addImage(
        _iconStopCafe,
        await GroupStopMapMarker.toPng(
          type: GroupStopType.cafe,
          color: _stopCafeColor,
        ),
      );
      await controller.addImage(
        _iconStopFuel,
        await GroupStopMapMarker.toPng(
          type: GroupStopType.gasolinera,
          color: _stopFuelColor,
        ),
      );
      await controller.addImage(
        _iconStopWait,
        await GroupStopMapMarker.toPng(
          type: GroupStopType.esperarAqui,
          color: _stopWaitColor,
        ),
      );
      await controller.addImage(
        _iconStopMeet,
        await GroupStopMapMarker.toPng(
          type: GroupStopType.reunion,
          color: _stopMeetColor,
        ),
      );
      await controller.addImage(
        _iconRouteOrigin,
        await _buildDotPng(_routeOriginColor),
      );
      await controller.addImage(
        _iconRouteDest,
        await _buildDotPng(_routeDestColor),
      );
      await controller.addImage(
        _iconRouteWaypoint,
        await _buildDotPng(_routeWaypointColor),
      );
      if (puckStyle != null) {
        await controller.addImage(
          _iconMe,
          await VehicleNavigationMarker.toPng(
            icon: puckStyle.icon,
            color: puckStyle.color,
            logicalSize: 140,
          ),
        );
        _loadedPuckStyle = puckStyle;
      } else {
        await controller.addImage(_iconMe, await _buildDotPng(_meColor));
      }
    } catch (_) {}
  }

  /// Sin esto MapLibre esconde una moto cuando se solapa con otra o con su nombre.
  Future<void> _enableOverlappingSymbols(MapLibreMapController controller) async {
    try {
      await controller.setSymbolIconAllowOverlap(true);
      await controller.setSymbolTextAllowOverlap(true);
      await controller.setSymbolIconIgnorePlacement(true);
      await controller.setSymbolTextIgnorePlacement(true);
    } catch (_) {}
  }

  Future<Uint8List> _buildDotPng(Color color) {
    return VehicleNavigationMarker.toPng(
      icon: VehicleMapIcon.motorcycle,
      color: color,
      logicalSize: 120,
    );
  }

  Future<void> _syncSharedRoute(NavigationRoute? route) async {
    final controller = _controller;
    _lastSharedRoute = route;
    if (controller == null || !_iconsReady) {
      return;
    }

    final hasLine = route != null && route.polyline.length >= 2;
    if (!hasLine) {
      if (_routeLayerReady) {
        try {
          await controller.removeLayer(_routeLineLayerId);
        } catch (_) {}
        try {
          await controller.removeSource(_routeSourceId);
        } catch (_) {}
        _routeLayerReady = false;
      }
      await _syncRoutePointMarkers(null);
      return;
    }

    final geoJson = _routeGeoJson(route.polyline);
    try {
      if (_routeLayerReady) {
        await controller.setGeoJsonSource(_routeSourceId, geoJson);
      } else {
        await controller.addGeoJsonSource(_routeSourceId, geoJson);
        await controller.addLineLayer(
          _routeSourceId,
          _routeLineLayerId,
          const LineLayerProperties(
            lineColor: '#1A73E8',
            lineWidth: 7,
            lineOpacity: 0.88,
            lineJoin: 'round',
          ),
          enableInteraction: false,
        );
        _routeLayerReady = true;
      }
    } catch (_) {
      _routeLayerReady = false;
    }
    await _syncRoutePointMarkers(route);
  }

  Future<void> _syncRoutePointMarkers(NavigationRoute? route) async {
    final controller = _controller;
    if (controller == null || !_iconsReady) {
      return;
    }

    final keep = <String>{};
    if (route != null) {
      keep.add('origin');
      keep.add('destination');
      for (var i = 0; i < route.waypoints.length; i++) {
        keep.add('wp:$i');
      }
    }

    final removeKeys =
        _routePointSymbols.keys.where((key) => !keep.contains(key)).toList();
    for (final key in removeKeys) {
      final symbol = _routePointSymbols.remove(key);
      if (symbol != null) {
        try {
          await controller.removeSymbol(symbol);
        } catch (_) {}
      }
    }

    if (route == null) {
      return;
    }

    Future<void> upsert({
      required String key,
      required GeoPoint point,
      required String icon,
      required String label,
    }) async {
      final options = SymbolOptions(
        geometry: LatLng(point.lat, point.lng),
        iconImage: icon,
        iconSize: 1.05,
        iconAnchor: 'center',
        textField: label,
        textSize: 11,
        textColor: '#FFFFFF',
        textHaloColor: '#000000',
        textHaloWidth: 1.2,
        textOffset: const Offset(0, 1.5),
        textAnchor: 'top',
        zIndex: 2,
      );
      final existing = _routePointSymbols[key];
      if (existing == null) {
        try {
          _routePointSymbols[key] = await controller.addSymbol(options);
        } catch (_) {}
      } else {
        try {
          await controller.updateSymbol(existing, options);
        } catch (_) {}
      }
    }

    await upsert(
      key: 'origin',
      point: route.origin,
      icon: _iconRouteOrigin,
      label: 'Salida',
    );
    await upsert(
      key: 'destination',
      point: route.destination,
      icon: _iconRouteDest,
      label: 'Destino',
    );
    for (var i = 0; i < route.waypoints.length; i++) {
      await upsert(
        key: 'wp:$i',
        point: route.waypoints[i],
        icon: _iconRouteWaypoint,
        label: 'Parada ${i + 1}',
      );
    }
  }

  Future<void> _syncGroupStops(List<GroupStop> stops) async {
    final controller = _controller;
    if (controller == null || !_iconsReady) {
      return;
    }

    final keep = stops.map((stop) => stop.id).toSet();
    final removeIds =
        _stopSymbols.keys.where((id) => !keep.contains(id)).toList();
    for (final id in removeIds) {
      final symbol = _stopSymbols.remove(id);
      if (symbol != null) {
        try {
          await controller.removeSymbol(symbol);
        } catch (_) {}
      }
    }

    for (final stop in stops) {
      final style = _stopStyle(stop.type);
      final focused = stop.id == _focusedStopId;
      final author = (stop.displayName ?? '').trim();
      final text = [
        stop.type.shortLabel,
        if (author.isNotEmpty) author,
      ].join('\n');
      final options = SymbolOptions(
        geometry: LatLng(stop.point.lat, stop.point.lng),
        iconImage: style.iconImage,
        iconSize: focused ? style.iconSize * 1.35 : style.iconSize,
        iconAnchor: 'bottom',
        textField: text,
        textSize: focused ? 13.5 : 12,
        textColor: style.textColor,
        textHaloColor: '#FFFFFF',
        textHaloWidth: focused ? 2 : 1.4,
        textOffset: const Offset(0, 0.6),
        textAnchor: 'top',
        zIndex: focused ? 12 : 8,
      );
      final existing = _stopSymbols[stop.id];
      if (existing == null) {
        try {
          _stopSymbols[stop.id] = await controller.addSymbol(options);
        } catch (_) {}
      } else {
        try {
          await controller.updateSymbol(existing, options);
        } catch (_) {}
      }
    }
  }

  ({String iconImage, double iconSize, String textColor}) _stopStyle(
    GroupStopType type,
  ) {
    return switch (type) {
      GroupStopType.cafe => (
          iconImage: _iconStopCafe,
          iconSize: 1.35,
          textColor: '#795548',
        ),
      GroupStopType.gasolinera => (
          iconImage: _iconStopFuel,
          iconSize: 1.35,
          textColor: '#388E3C',
        ),
      GroupStopType.esperarAqui => (
          iconImage: _iconStopWait,
          iconSize: 1.4,
          textColor: '#8E24AA',
        ),
      GroupStopType.reunion => (
          iconImage: _iconStopMeet,
          iconSize: 1.35,
          textColor: '#00897B',
        ),
    };
  }

  Future<void> _onMapLongPress(LatLng point) async {
    final type = await showGroupStopTypeSheet(context);
    if (!mounted || type == null) {
      return;
    }
    try {
      await ref.read(groupStopServiceProvider).publish(
            groupId: widget.groupId,
            uid: widget.user.uid,
            displayName: widget.user.displayName,
            type: type,
            point: GeoPoint(lat: point.latitude, lng: point.longitude),
          );
    } catch (_) {}
  }

  Future<void> _openGroupNavigation(NavigationRoute sharedRoute) async {
    final own = ref.read(ownDevicePositionProvider);
    final members =
        ref.read(groupMembersProvider(widget.groupId)).asData?.value ??
            const <GroupMember>[];
    final locations =
        ref.read(groupLocationsProvider(widget.groupId)).valueOrNull ??
            const <LiveLocation>[];
    final now = DateTime.now();

    GroupMember? cabecera;
    for (final member in members) {
      if (member.uid == widget.user.uid) {
        continue;
      }
      if (member.rideRole == RideRole.cabecera) {
        cabecera = member;
        break;
      }
    }
    LiveLocation? cabeceraLoc;
    if (cabecera != null) {
      for (final location in locations) {
        if (location.uid != cabecera.uid) {
          continue;
        }
        if (location.hasSignal && !isGpsStale(location.updatedAt, now)) {
          cabeceraLoc = location;
        }
        break;
      }
    }

    CatchUpCabeceraChoice? choice;
    if (own != null && cabecera != null && cabeceraLoc != null) {
      final distanceToRoute =
          ref.read(routeDeviationServiceProvider).distanceToPolylineMeters(
                GeoPoint(lat: own.lat, lng: own.lng),
                sharedRoute.polyline,
              );
      if (distanceToRoute > NavigationConstants.deviationThresholdMeters) {
        choice = await showCatchUpCabeceraSheet(
          context: context,
          cabeceraName: cabecera.displayName,
        );
        if (!mounted || choice == null) {
          return;
        }
        unawaited(_publishCatchUpVoice(choice));
      }
    }

    var hudRoute = sharedRoute;
    final chase = choice == CatchUpCabeceraChoice.chase;
    if (chase && own != null && cabecera != null && cabeceraLoc != null) {
      final chaseFrom = own;
      final chaseMember = cabecera;
      final chaseLocation = cabeceraLoc;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const PopScope(
          canPop: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
      try {
        hudRoute = await ref.read(navigationSessionProvider.notifier).planCatchUpRoute(
              from: GeoPoint(lat: chaseFrom.lat, lng: chaseFrom.lng),
              to: GeoPoint(lat: chaseLocation.lat, lng: chaseLocation.lng),
              destinationLabel: chaseMember.displayName,
            );
      } catch (_) {
        hudRoute = sharedRoute;
      } finally {
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      }
    }

    if (!mounted) {
      return;
    }
    hudRoute = await enrichRouteLimitsBeforeNavigation(
      context: context,
      ref: ref,
      route: hudRoute,
    );
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => NavigationHudScreen(
          route: hudRoute,
          user: widget.user,
          chaseCabecera: chase,
          sharedGroupRoute: chase ? sharedRoute : null,
          enableGroupFeatures: true,
        ),
      ),
      (route) => route.isFirst,
    );
  }

  Future<void> _publishCatchUpVoice(CatchUpCabeceraChoice choice) async {
    final announcement = GroupVoiceAnnouncement(
      id: 'local',
      uid: widget.user.uid,
      kind: choice.voiceKind,
      at: DateTime.now(),
      displayName: widget.user.displayName,
    );
    unawaited(
      GroupRideAlertFeedback.playVoiceAnnouncement(
        announcement: announcement,
        voice: ref.read(navigationVoiceServiceProvider),
      ),
    );
    try {
      await ref.read(groupVoiceDatasourceProvider).publish(
            groupId: widget.groupId,
            announcement: announcement,
          );
    } catch (_) {
      // Sin red: solo se oye en este móvil.
    }
  }

  Future<void> _openStopsSheet({required bool canManageStops}) async {
    await showGroupStopsListSheet(
      context: context,
      groupId: widget.groupId,
      user: widget.user,
      canManageStops: canManageStops,
      onFocusStop: _focusStop,
    );
  }

  Future<void> _focusStop(GroupStop stop) async {
    if (!mounted) {
      return;
    }
    _focusStopTimer?.cancel();
    setState(() {
      _followGroup = false;
      _focusedStopId = stop.id;
    });
    _focusStopTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => _focusedStopId = null);
      }
    });

    final stops =
        ref.read(groupStopsProvider(widget.groupId)).valueOrNull ?? const [];
    unawaited(_syncGroupStops(stops));

    final controller = _controller;
    if (controller == null) {
      return;
    }
    _programmaticCamera = true;
    try {
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(stop.point.lat, stop.point.lng),
            zoom: 17,
          ),
        ),
        duration: const Duration(milliseconds: 500),
      );
    } catch (_) {
    } finally {
      Future<void>.delayed(const Duration(milliseconds: 650), () {
        _programmaticCamera = false;
      });
    }
  }

  Future<void> _openExternalNavigation(
    Uri uri, {
    Uri? fallback,
  }) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened || fallback == null) {
      return;
    }
    await launchUrl(fallback, mode: LaunchMode.externalApplication);
  }

  Map<String, dynamic> _routeGeoJson(List<GeoPoint> polyline) {
    return {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'properties': <String, dynamic>{},
          'geometry': {
            'type': 'LineString',
            'coordinates': [
              for (final point in polyline) [point.lng, point.lat],
            ],
          },
        },
      ],
    };
  }

  List<_MemberMapEntry> _buildEntries(
    List<LiveLocation> locations,
    OwnDevicePosition own, {
    required DateTime now,
    required bool ownGpsLost,
    required List<GroupMember>? members,
    required List<GroupIncident> incidents,
  }) {
    // Solo excluimos uids si ya tenemos lista de miembros cargada y no vacía.
    // Si members es null/[] no filtramos: si no, el otro no aparece nunca.
    final memberUids = members == null || members.isEmpty
        ? null
        : members.map((member) => member.uid).toSet();
    final names = <String, String>{
      widget.user.uid: widget.user.displayName,
      if (members != null)
        for (final member in members) member.uid: member.displayName,
    };
    final roles = <String, RideRole?>{
      if (members != null)
        for (final member in members) member.uid: member.rideRole,
    };
    final incidentsByUid = <String, GroupIncident>{
      for (final incident in incidents)
        if (incident.active) incident.uid: incident,
    };
    final byUid = <String, LiveLocation>{};
    for (final location in locations) {
      if (location.uid == widget.user.uid) {
        continue; // La propia va siempre desde el GPS local (abajo).
      }
      if (memberUids != null && !memberUids.contains(location.uid)) {
        continue;
      }
      byUid[location.uid] = location;
    }
    // Posición propia: GPS/simulación local, no el nodo RTDB (puede ir atrasado).
    byUid[widget.user.uid] = LiveLocation(
      uid: widget.user.uid,
      groupId: widget.groupId,
      lat: own.lat,
      lng: own.lng,
      heading: own.heading ?? 0,
      speed: own.speedMps,
      updatedAt: now,
      displayName: widget.user.displayName,
      hasSignal: !ownGpsLost,
    );

    final placed = <({double lat, double lng})>[];
    final out = <_MemberMapEntry>[];
    // Primero “tú”: el apilado visual no te saca de tu posición real.
    final ordered = byUid.values.toList()
      ..sort((a, b) {
        final aMe = a.uid == widget.user.uid ? 0 : 1;
        final bMe = b.uid == widget.user.uid ? 0 : 1;
        return aMe.compareTo(bMe);
      });
    for (final location in ordered) {
      final isMe = location.uid == widget.user.uid;
      final stale = isMe
          ? ownGpsLost
          : !location.hasSignal || isGpsStale(location.updatedAt, now);
      // Índice solo para apilar icono/texto en pantalla; lat/lng reales.
      var stackIndex = 0;
      for (final previous in placed) {
        final meters = Geolocator.distanceBetween(
          location.lat,
          location.lng,
          previous.lat,
          previous.lng,
        );
        if (meters < 35) {
          stackIndex++;
        }
      }
      placed.add((lat: location.lat, lng: location.lng));
      final name = (names[location.uid] ?? location.displayName).trim();
      final labelName = name.isEmpty ? 'Motero' : name;
      final distanceLabel = isMe || stale
          ? null
          : formatRideDistance(
              Geolocator.distanceBetween(
                own.lat,
                own.lng,
                location.lat,
                location.lng,
              ),
            );
      final staleLabel =
          stale ? formatGpsStaleLabel(location.updatedAt, now) : null;
      final incident = incidentsByUid[location.uid];
      final role = roles[location.uid];
      final roleLabel = switch (role) {
        RideRole.cabecera => 'cabecera',
        RideRole.cola => 'cola',
        null => null,
      };
      final text = [
        isMe ? '$labelName (tú)' : labelName,
        ?roleLabel,
        ?(incident?.type.label),
        ?staleLabel,
        ?distanceLabel,
      ].join('\n');
      out.add(
        _MemberMapEntry(
          uid: location.uid,
          lat: location.lat,
          lng: location.lng,
          heading: location.heading,
          isMe: isMe,
          isStale: stale,
          rideRole: role,
          incident: incident,
          text: text,
          stackIndex: stackIndex,
        ),
      );
    }
    return out;
  }

  Future<void> _syncMembers(
    List<_MemberMapEntry> entries, {
    required NavigationPuckStyle? puckStyle,
  }) async {
    final controller = _controller;
    if (controller == null || !_iconsReady) {
      return;
    }
    await _enableOverlappingSymbols(controller);
    if (puckStyle != null &&
        (_loadedPuckStyle?.icon != puckStyle.icon ||
            _loadedPuckStyle?.color != puckStyle.color)) {
      try {
        await controller.addImage(
          _iconMe,
          await VehicleNavigationMarker.toPng(
            icon: puckStyle.icon,
            color: puckStyle.color,
            logicalSize: 140,
          ),
        );
        _loadedPuckStyle = puckStyle;
      } catch (_) {}
    }

    final keep = entries.map((e) => e.uid).toSet();
    final removeUids =
        _symbols.keys.where((uid) => !keep.contains(uid)).toList();
    for (final uid in removeUids) {
      final symbol = _symbols.remove(uid);
      if (symbol != null) {
        try {
          await controller.removeSymbol(symbol);
        } catch (_) {}
      }
    }

    final cameraBearing = controller.cameraPosition?.bearing ?? 0;
    for (final entry in entries) {
      final style = _markerStyle(entry, puckStyle: puckStyle);
      var iconRotate = 0.0;
      if (entry.heading.isFinite && entry.heading.abs() > 8) {
        var delta = entry.heading - cameraBearing;
        while (delta > 180) {
          delta -= 360;
        }
        while (delta < -180) {
          delta += 360;
        }
        iconRotate = delta;
      }
      final stack = entry.stackIndex;
      // Posición GPS real; el apilado es solo en píxeles del icono (arriba).
      final options = SymbolOptions(
        geometry: LatLng(entry.lat, entry.lng),
        iconImage: style.iconImage,
        iconSize: style.iconSize,
        iconRotate: iconRotate,
        iconAnchor: 'center',
        iconOffset: Offset(0, -1.15 * stack),
        textField: entry.text,
        textSize: 11,
        textColor: style.textColor,
        textHaloColor: '#FFFFFF',
        textHaloWidth: 1.2,
        // Nombre a la derecha si hay pila, para no tapar la moto de abajo.
        textOffset: stack > 0 ? const Offset(1.35, 0.15) : const Offset(0, 1.6),
        textAnchor: stack > 0 ? 'left' : 'top',
        zIndex: entry.isMe ? 10 : 1 + stack,
      );
      final existing = _symbols[entry.uid];
      if (existing == null) {
        try {
          _symbols[entry.uid] = await controller.addSymbol(options);
        } catch (_) {}
      } else {
        try {
          await controller.updateSymbol(existing, options);
        } catch (_) {}
      }
    }
  }

  ({String iconImage, double iconSize, String textColor}) _markerStyle(
    _MemberMapEntry entry, {
    required NavigationPuckStyle? puckStyle,
  }) {
    if (entry.isMe) {
      return (
        iconImage: _iconMe,
        iconSize: puckStyle != null ? 1.35 : 1.2,
        textColor: '#1565C0',
      );
    }
    if (entry.isStale) {
      return (
        iconImage: _iconStale,
        iconSize: 0.85,
        textColor: '#C62828',
      );
    }
    final incident = entry.incident;
    if (incident != null) {
      return switch (incident.type) {
        GroupIncidentType.emergencia => (
            iconImage: _iconEmergencia,
            iconSize: 1.25,
            textColor: '#C62828',
          ),
        GroupIncidentType.averia => (
            iconImage: _iconAveria,
            iconSize: 1.2,
            textColor: '#FFA000',
          ),
        GroupIncidentType.separado => (
            iconImage: _iconSeparado,
            iconSize: 1.2,
            textColor: '#1565C0',
          ),
        GroupIncidentType.espera => (
            iconImage: _iconSeparado,
            iconSize: 1.2,
            textColor: '#6A1B9A',
          ),
      };
    }
    return switch (entry.rideRole) {
      RideRole.cabecera => (
          iconImage: _iconCabecera,
          iconSize: 1.05,
          textColor: '#2E7D32',
        ),
      RideRole.cola => (
          iconImage: _iconCola,
          iconSize: 1.05,
          textColor: '#EF6C00',
        ),
      null => (
          iconImage: _iconGroup,
          iconSize: 0.85,
          textColor: '#E65100',
        ),
    };
  }

  Future<void> _confirmClearSharedRoute() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HubStyle.surface,
        title: Text('¿Quitar la ruta del grupo?', style: HubStyle.sectionTitle()),
        content: Text(
          'El grupo dejará de ver esta ruta en el mapa.',
          style: HubStyle.body(),
        ),
        actions: [
          TextButton(
            style: HubStyle.textButtonStyle(),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: HubStyle.filledButtonStyle(),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) {
      return;
    }
    try {
      await ref.read(groupActionControllerProvider.notifier).clearSharedRoute(
            actor: widget.user,
            groupId: widget.groupId,
          );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ruta del grupo eliminada')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo quitar la ruta.')),
      );
    }
  }

  /// En horizontal: como mucho incidencia, o un solo aviso compacto (destino/offline).
  Widget _buildLandscapeTopAlerts(
    BuildContext context, {
    required NavigationRoute? sharedRoute,
    required bool hasNetwork,
    required GroupIncident? bannerIncident,
  }) {
    if (bannerIncident != null) {
      return GroupIncidentBanner(
        incident: bannerIncident,
        compact: true,
        landscape: true,
        onDismiss: () {
          setState(() {
            _dismissedBannerIds.add(_bannerId(bannerIncident));
          });
        },
        isOwnIncident: false,
        onClear: null,
      );
    }

    final hasDestination = sharedRoute != null;
    final offline = !hasNetwork;
    if (!hasDestination && !offline) {
      return const SizedBox.shrink();
    }

    final dest = sharedRoute?.destinationDisplay.trim() ?? '';
    final shortDest = dest.isEmpty
        ? 'Ruta del grupo'
        : (dest.length > 42 ? '${dest.substring(0, 40)}…' : dest);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: offline
            ? const Color(0xFF1F2937).withValues(alpha: 0.94)
            : HubStyle.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        boxShadow: HubStyle.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            Icon(
              offline ? Icons.wifi_off_rounded : Icons.map_outlined,
              size: 16,
              color: offline ? Colors.white : HubStyle.accent,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                offline
                    ? (hasDestination
                        ? 'Sin red · $shortDest'
                        : 'Sin conexión · solo zonas descargadas')
                    : 'Destino: $shortDest',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HubStyle.caption(
                  color: offline ? Colors.white : HubStyle.title,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            if (offline)
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const OfflineMapsSettingsScreen(),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('Mapas', style: TextStyle(fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }

  String _bannerId(GroupIncident incident) =>
      '${incident.uid}|${incident.at.toIso8601String()}|${incident.type.name}';

  GroupIncident? _highestPriorityBanner(List<GroupIncident> incidents) {
    // Quien avisa ya tiene el botón verde; el banner es para el resto del grupo.
    final candidates = incidents
        .where(
          (incident) =>
              incident.active &&
              incident.uid != widget.user.uid &&
              !_dismissedBannerIds.contains(_bannerId(incident)),
        )
        .toList();
    if (candidates.isEmpty) {
      return null;
    }
    candidates.sort((a, b) {
      final critical =
          (b.isCriticalEmergency ? 1 : 0) - (a.isCriticalEmergency ? 1 : 0);
      if (critical != 0) {
        return critical;
      }
      final byType = b.type.priorityRank.compareTo(a.type.priorityRank);
      if (byType != 0) {
        return byType;
      }
      return b.at.compareTo(a.at);
    });
    return candidates.first;
  }

  void _maybeAlertNewIncidents(List<GroupIncident> incidents) {
    final keys = <String>{
      for (final incident in incidents)
        if (incident.active) _bannerId(incident),
    };
    if (!_incidentAlertPrimed) {
      _seenIncidentKeys.addAll(keys);
      _incidentAlertPrimed = true;
      return;
    }
    final voice = ref.read(navigationVoiceServiceProvider);
    final names = <String, String>{
      widget.user.uid: widget.user.displayName,
    };
    final members =
        ref.read(groupMembersProvider(widget.groupId)).asData?.value;
    if (members != null) {
      for (final member in members) {
        names[member.uid] = member.displayName;
      }
    }
    for (final incident in incidents) {
      if (!incident.active || incident.uid == widget.user.uid) {
        continue;
      }
      final key = _bannerId(incident);
      if (_seenIncidentKeys.add(key)) {
        final name =
            (incident.displayName ?? names[incident.uid] ?? '').trim();
        unawaited(
          GroupRideAlertFeedback.playIncident(
            incident: incident,
            name: name,
            voice: voice,
          ),
        );
      }
    }
  }

  void _maybeEvaluatePackAlerts({
    required OwnDevicePosition? own,
    required List<LiveLocation> locations,
    required List<GroupMember>? members,
    required DateTime now,
  }) {
    if (own == null) {
      return;
    }
    final prefs = ref.read(groupPackAlertProvider);
    if (!prefs.enabled || prefs.isPackAlertsMutedAt(now)) {
      return;
    }
    final names = <String, String>{
      for (final member in members ?? const <GroupMember>[])
        member.uid: member.displayName,
    };
    final alerts = _packTracker.evaluate(
      ownLat: own.lat,
      ownLng: own.lng,
      others: locations,
      names: names,
      now: now,
      ownUid: widget.user.uid,
      enabled: true,
      behindMeters: prefs.behindMeters,
      farMeters: prefs.farMeters,
      resetMeters: prefs.resetMeters,
    );
    if (alerts.isEmpty) {
      return;
    }
    final voice = ref.read(navigationVoiceServiceProvider);
    for (final alert in alerts) {
      unawaited(
        GroupRideAlertFeedback.playPackDistance(
          name: alert.name,
          distanceLabel: alert.distanceLabel,
          far: alert.kind == GroupPackAlertKind.far,
          voice: voice,
        ),
      );
    }
  }

  void _recenterGroup() {
    setState(() {
      _followGroup = true;
      _lastFollowFit = null;
    });
    // Encaja ya (no esperar al throttle de 2 s del follow automático).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_followGroup) {
        return;
      }
      final points = _collectFollowPoints();
      if (points.isEmpty) {
        return;
      }
      _lastFollowFit = DateTime.now();
      unawaited(_fitPoints(points));
    });
  }

  List<LatLng> _collectFollowPoints() {
    final members =
        ref.read(groupMembersProvider(widget.groupId)).asData?.value ??
            const <GroupMember>[];
    final locations =
        ref.read(groupLocationsProvider(widget.groupId)).valueOrNull ??
            const <LiveLocation>[];
    final stops =
        ref.read(groupStopsProvider(widget.groupId)).asData?.value ??
            const <GroupStop>[];
    final sharedRoute =
        ref.read(groupSharedRouteProvider(widget.groupId)).asData?.value;
    final now = DateTime.now();
    final points = <LatLng>[];
    for (final location in locations) {
      if (!location.hasSignal || isGpsStale(location.updatedAt, now)) {
        continue;
      }
      // Solo miembros del grupo (por si queda basura en RTDB).
      if (!members.any((m) => m.uid == location.uid)) {
        continue;
      }
      points.add(LatLng(location.lat, location.lng));
    }
    for (final stop in stops) {
      points.add(LatLng(stop.point.lat, stop.point.lng));
    }
    if (sharedRoute != null) {
      points.add(LatLng(sharedRoute.origin.lat, sharedRoute.origin.lng));
      points.add(
        LatLng(sharedRoute.destination.lat, sharedRoute.destination.lng),
      );
      for (final wp in sharedRoute.waypoints) {
        points.add(LatLng(wp.lat, wp.lng));
      }
      points.addAll(_samplePolyline(sharedRoute.polyline));
    }
    return points;
  }

  List<LatLng> _samplePolyline(List<GeoPoint> polyline) {
    if (polyline.isEmpty) {
      return const [];
    }
    if (polyline.length <= 40) {
      return [for (final p in polyline) LatLng(p.lat, p.lng)];
    }
    final step = (polyline.length / 40).ceil();
    final out = <LatLng>[];
    for (var i = 0; i < polyline.length; i += step) {
      final p = polyline[i];
      out.add(LatLng(p.lat, p.lng));
    }
    final last = polyline.last;
    if (out.isEmpty ||
        out.last.latitude != last.lat ||
        out.last.longitude != last.lng) {
      out.add(LatLng(last.lat, last.lng));
    }
    return out;
  }

  Future<void> _recenterOnMe() async {
    final controller = _controller;
    final own = ref.read(ownDevicePositionProvider);
    if (controller == null || own == null) {
      return;
    }
    setState(() => _followGroup = false);
    await animateMapToMyLocation(
      controller,
      lat: own.lat,
      lng: own.lng,
    );
  }

  void _scheduleFollow(Set<String> uids, List<LatLng> points) {
    if (!_followGroup || points.isEmpty || _controller == null) {
      return;
    }
    final membersChanged = !setEquals(uids, _fittedUids);
    final due = _lastFollowFit == null ||
        DateTime.now().difference(_lastFollowFit!) >=
            const Duration(seconds: 2);
    if (!membersChanged && !due) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_followGroup || points.isEmpty) {
        return;
      }
      _fittedUids = uids;
      _lastFollowFit = DateTime.now();
      unawaited(_fitPoints(points));
    });
  }

  Future<void> _fitPoints(List<LatLng> points) async {
    final controller = _controller;
    if (controller == null || points.isEmpty) {
      return;
    }
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final size = MediaQuery.sizeOf(context);
    final safe = MediaQuery.paddingOf(context);
    // El mapa ocupa toda la pantalla; el panel inferior tapa la zona baja.
    // Sin ese margen, ruta y pelotón quedan “centrados” detrás del panel.
    final topPad = landscape
        ? math.max(72.0, safe.top + 56)
        : math.max(140.0, safe.top + kToolbarHeight + 72);
    final bottomPad = landscape
        ? math.max(88.0, safe.bottom + 72)
        : math.max(220.0, size.height * 0.30 + safe.bottom);
    final sidePad = landscape ? 88.0 : 48.0;

    _programmaticCamera = true;
    try {
      if (points.length == 1) {
        await controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: points.first, zoom: 15),
          ),
          duration: const Duration(milliseconds: 450),
        );
        return;
      }
      var minLat = points.first.latitude;
      var maxLat = points.first.latitude;
      var minLng = points.first.longitude;
      var maxLng = points.first.longitude;
      for (final p in points.skip(1)) {
        minLat = math.min(minLat, p.latitude);
        maxLat = math.max(maxLat, p.latitude);
        minLng = math.min(minLng, p.longitude);
        maxLng = math.max(maxLng, p.longitude);
      }
      // Evitar bounds degenerados.
      if ((maxLat - minLat).abs() < 0.0003) {
        minLat -= 0.001;
        maxLat += 0.001;
      }
      if ((maxLng - minLng).abs() < 0.0003) {
        minLng -= 0.001;
        maxLng += 0.001;
      }
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          left: sidePad,
          top: topPad,
          right: sidePad,
          bottom: bottomPad,
        ),
        duration: const Duration(milliseconds: 450),
      );
    } catch (_) {
    } finally {
      Future<void>.delayed(const Duration(milliseconds: 600), () {
        _programmaticCamera = false;
      });
    }
  }
}

class _MemberMapEntry {
  const _MemberMapEntry({
    required this.uid,
    required this.lat,
    required this.lng,
    required this.heading,
    required this.isMe,
    required this.isStale,
    required this.text,
    this.rideRole,
    this.incident,
    this.stackIndex = 0,
  });

  final String uid;
  final double lat;
  final double lng;
  final double heading;
  final bool isMe;
  final bool isStale;
  final RideRole? rideRole;
  final GroupIncident? incident;
  final String text;

  /// Cuántas motos hay ya casi en el mismo sitio (solo para apilar el dibujo).
  final int stackIndex;
}

class _MapLegend extends StatelessWidget {
  const _MapLegend({
    required this.meColor,
    required this.groupColor,
    required this.cabeceraColor,
    required this.colaColor,
  });

  final Color meColor;
  final Color groupColor;
  final Color cabeceraColor;
  final Color colaColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: HubStyle.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(12),
        boxShadow: HubStyle.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LegendDot(color: meColor, label: 'Tú'),
            const SizedBox(width: 12),
            _LegendDot(color: groupColor, label: 'Grupo'),
            const SizedBox(width: 12),
            _LegendDot(color: cabeceraColor, label: 'Cabecera'),
            const SizedBox(width: 12),
            _LegendDot(color: colaColor, label: 'Cola'),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: const SizedBox(width: 10, height: 10),
        ),
        const SizedBox(width: 6),
        Text(label, style: HubStyle.caption(color: HubStyle.title)),
      ],
    );
  }
}

class _WaitingBanner extends StatelessWidget {
  const _WaitingBanner({required this.names, this.compact = false});

  final List<String> names;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: HubStyle.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        boxShadow: HubStyle.cardShadow,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 10,
          vertical: compact ? 4 : 8,
        ),
        child: Text(
          names.length == 1
              ? '1 motero aún no manda GPS'
              : '${names.length} moteros aún no mandan GPS',
          style: HubStyle.caption(
            color: HubStyle.title,
          ).copyWith(fontSize: compact ? 11 : 12),
        ),
      ),
    );
  }
}

/// Navegar, pelotón, paradas y centrar en un solo bloque.
class _GroupMapQuickActions extends StatelessWidget {
  const _GroupMapQuickActions({
    this.embedded = false,
    this.compact = false,
    required this.hasSharedRoute,
    required this.preferExternalNav,
    required this.followGroup,
    this.onPrepareRoute,
    this.onClearRoute,
    required this.onNavigate,
    this.onOpenWaze,
    this.onOpenGoogleMaps,
    this.onShowStops,
    this.stopCount = 0,
    required this.onPackList,
    required this.onRecenter,
  });

  final bool embedded;
  final bool compact;
  final bool hasSharedRoute;
  final bool preferExternalNav;
  final bool followGroup;
  final VoidCallback? onPrepareRoute;
  final VoidCallback? onClearRoute;
  final VoidCallback? onNavigate;
  final VoidCallback? onOpenWaze;
  final VoidCallback? onOpenGoogleMaps;
  final VoidCallback? onShowStops;
  final int stopCount;
  final VoidCallback onPackList;
  final VoidCallback onRecenter;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      if (onPrepareRoute != null)
        _QuickActionTile(
          icon: Icons.route_outlined,
          label: hasSharedRoute ? 'Cambiar' : 'Ruta',
          emphasized: !hasSharedRoute,
          onTap: onPrepareRoute,
        ),
      if (onClearRoute != null)
        _QuickActionTile(
          icon: Icons.playlist_remove_rounded,
          label: 'Quitar',
          onTap: onClearRoute,
        ),
      if (hasSharedRoute)
        _QuickActionTile(
          icon: preferExternalNav
              ? Icons.navigation_outlined
              : Icons.navigation_rounded,
          label: preferExternalNav ? 'Waze' : 'Navegar',
          emphasized: true,
          onTap: preferExternalNav ? onOpenWaze : onNavigate,
          menuItems: [
            if (!preferExternalNav && onOpenWaze != null)
              (
                icon: Icons.navigation_outlined,
                label: 'Abrir en Waze',
                onTap: onOpenWaze!,
              ),
            if (onOpenGoogleMaps != null)
              (
                icon: Icons.map_outlined,
                label: 'Abrir en Maps',
                onTap: onOpenGoogleMaps!,
              ),
            if (preferExternalNav && onNavigate != null)
              (
                icon: Icons.sports_motorsports_outlined,
                label: 'Navegar en MotoAMG',
                onTap: onNavigate!,
              ),
          ],
        ),
      _QuickActionTile(
        icon: Icons.format_list_bulleted_rounded,
        label: 'Pelotón',
        onTap: onPackList,
      ),
      if (onShowStops != null)
        _QuickActionTile(
          icon: Icons.place_outlined,
          label: 'Paradas',
          badge: stopCount > 0 ? '$stopCount' : null,
          emphasized: stopCount > 0,
          onTap: onShowStops,
        ),
      _QuickActionTile(
        icon: Icons.groups,
        label: 'Centrar',
        emphasized: followGroup,
        onTap: onRecenter,
      ),
    ];

    final row = Row(
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(child: tiles[i]),
        ],
      ],
    );

    if (embedded) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: row,
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: HubStyle.surface.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(16),
        boxShadow: HubStyle.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: row,
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.emphasized = false,
    this.badge,
    this.menuItems = const [],
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool emphasized;
  final String? badge;
  final List<({IconData icon, String label, VoidCallback onTap})> menuItems;

  @override
  Widget build(BuildContext context) {
    final bg = emphasized
        ? HubStyle.accent.withValues(alpha: 0.14)
        : const Color(0xFFF3F4F6);
    final fg = emphasized ? HubStyle.accent : HubStyle.subtitle;

    Widget circle = Material(
      color: bg,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        onLongPress: menuItems.isEmpty
            ? null
            : () async {
                final selected = await showModalBottomSheet<int>(
                  context: context,
                  showDragHandle: true,
                  backgroundColor: HubStyle.surface,
                  builder: (ctx) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < menuItems.length; i++)
                          ListTile(
                            leading: Icon(
                              menuItems[i].icon,
                              color: HubStyle.accent,
                            ),
                            title: Text(
                              menuItems[i].label,
                              style: HubStyle.body(color: HubStyle.title),
                            ),
                            onTap: () => Navigator.pop(ctx, i),
                          ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                );
                if (selected != null) {
                  menuItems[selected].onTap();
                }
              },
        child: SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, color: fg, size: 22),
              if (badge != null)
                Positioned(
                  right: 4,
                  top: 4,
                  child: CircleAvatar(
                    radius: 8,
                    backgroundColor: HubStyle.accent,
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        circle,
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: HubStyle.caption(color: HubStyle.subtitle),
        ),
      ],
    );
  }
}

class _GroupMapRoundButton extends StatelessWidget {
  const _GroupMapRoundButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.emphasized = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: emphasized
          ? HubStyle.accent
          : HubStyle.surface.withValues(alpha: 0.97),
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            color: emphasized ? Colors.white : HubStyle.title,
            size: 22,
          ),
        ),
      ),
    );
    if (tooltip == null) {
      return button;
    }
    return Tooltip(
      message: tooltip!,
      child: button,
    );
  }
}
