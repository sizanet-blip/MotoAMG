import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:loc_motos/core/utils/distance_format.dart';
import 'package:loc_motos/core/utils/gps_status.dart';
import 'package:loc_motos/features/auth/domain/entities/app_user.dart';
import 'package:loc_motos/features/auth/domain/entities/vehicle_map_marker.dart';
import 'package:loc_motos/features/auth/presentation/widgets/vehicle_navigation_marker.dart';
import 'package:loc_motos/features/groups/domain/entities/group_incident.dart';
import 'package:loc_motos/features/groups/domain/entities/group_member.dart';
import 'package:loc_motos/features/groups/domain/entities/ride_role.dart';
import 'package:loc_motos/features/groups/domain/services/group_pack_proximity_tracker.dart';
import 'package:loc_motos/features/groups/domain/services/group_ride_alert_feedback.dart';
import 'package:loc_motos/features/groups/domain/services/group_incident_service.dart';
import 'package:loc_motos/features/groups/presentation/providers/group_providers.dart';
import 'package:loc_motos/features/groups/presentation/widgets/group_incident_session_panel.dart';
import 'package:loc_motos/features/groups/presentation/widgets/group_incident_widgets.dart';
import 'package:loc_motos/features/groups/presentation/widgets/group_pack_list_sheet.dart';
import 'package:loc_motos/features/navigation/domain/entities/geo_point.dart';
import 'package:loc_motos/features/navigation/domain/entities/hybrid_map_styles.dart';
import 'package:loc_motos/features/navigation/domain/entities/navigation_route.dart';
import 'package:loc_motos/features/navigation/data/services/navigation_map_style_service.dart';
import 'package:loc_motos/features/navigation/presentation/providers/navigation_providers.dart';
import 'package:loc_motos/features/navigation/presentation/screens/navigation_hud_screen.dart';
import 'package:loc_motos/features/navigation/presentation/theme/navigation_hud_theme.dart';
import 'package:loc_motos/features/navigation/presentation/widgets/offline_map_banner.dart';
import 'package:loc_motos/features/tracking/domain/entities/device_position.dart';
import 'package:loc_motos/features/tracking/domain/entities/live_location.dart';
import 'package:loc_motos/features/tracking/presentation/providers/tracking_providers.dart';
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

  static const _iconMe = 'locmotos-group-me';
  static const _iconGroup = 'locmotos-group-mate';
  static const _iconCabecera = 'locmotos-group-cabecera';
  static const _iconCola = 'locmotos-group-cola';
  static const _iconStale = 'locmotos-group-stale';
  static const _iconEmergencia = 'locmotos-group-emergencia';
  static const _iconAveria = 'locmotos-group-averia';
  static const _iconSeparado = 'locmotos-group-separado';

  static const _routeSourceId = 'locmotos-group-route';
  static const _routeLineLayerId = 'locmotos-group-route-line';

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
  NavigationPuckStyle? _loadedPuckStyle;
  NavigationRoute? _lastSharedRoute;

  final _dismissedBannerIds = <String>{};
  final _seenIncidentKeys = <String>{};
  var _incidentAlertPrimed = false;
  final _packTracker = GroupPackProximityTracker();

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
      _scheduleFollow(
        liveUids,
        [
          for (final e in entries) LatLng(e.lat, e.lng),
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

    Widget quickActions({required bool embedded, bool vertical = false}) {
      return _GroupMapQuickActions(
        embedded: embedded,
        vertical: vertical,
        hasSharedRoute: sharedRoute != null,
        followGroup: _followGroup,
        onNavigate: sharedRoute == null
            ? null
            : () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute<void>(
                    builder: (_) => NavigationHudScreen(
                      route: sharedRoute,
                      user: widget.user,
                    ),
                  ),
                  (route) => route.isFirst,
                );
              },
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

    final bottomInset = MediaQuery.paddingOf(context).bottom;

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
          top: 8,
          left: 8,
          right: landscape ? 64 : 8,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!landscape)
                const _MapLegend(
                  meColor: _meColor,
                  groupColor: _groupColor,
                  cabeceraColor: _cabeceraColor,
                  colaColor: _colaColor,
                ),
              if (!hasNetwork) ...[
                if (!landscape) const SizedBox(height: 8),
                const OfflineMapBanner(compact: true),
              ],
              if (waiting.isNotEmpty) ...[
                const SizedBox(height: 8),
                _WaitingBanner(names: waiting, compact: landscape),
              ],
              if (locationsAsync.hasError) ...[
                const SizedBox(height: 8),
                Material(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      'No se ven las motos del grupo. ${locationsAsync.error}',
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
                      _dismissedBannerIds.add(_bannerId(bannerIncident));
                    });
                  },
                  isOwnIncident: bannerIncident.uid == widget.user.uid,
                  onClear: bannerIncident.uid == widget.user.uid
                      ? () => unawaited(_clearOwnIncidentFromBanner())
                      : null,
                ),
              ],
            ],
          ),
        ),
        if (landscape) ...[
          Positioned(
            left: 10,
            bottom: bottomInset + 8,
            child: Material(
              elevation: 10,
              color: NavigationHudTheme.panel.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(14),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: GroupIncidentSessionPanel(
                    groupId: widget.groupId,
                    user: widget.user,
                    compact: true,
                    embedded: true,
                    showBanner: false,
                    drivingMode: true,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 12,
            child: quickActions(embedded: false, vertical: true),
          ),
        ] else
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 0, 6, 4),
                child: Material(
                  elevation: 6,
                  color: Theme.of(context)
                      .colorScheme
                      .surface
                      .withValues(alpha: 0.97),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        quickActions(embedded: true),
                        const Divider(height: 8),
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
  }

  Future<void> _onStyleLoaded(NavigationPuckStyle? puckStyle) async {
    _symbols.clear();
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

  Future<void> _clearOwnIncidentFromBanner() async {
    try {
      await ref.read(groupIncidentServiceProvider).clear(
            groupId: widget.groupId,
            uid: widget.user.uid,
          );
    } catch (_) {
      if (!mounted) {
        return;
      }
      unawaited(_retryClearOwnIncidentFromBanner());
    }
  }

  Future<void> _retryClearOwnIncidentFromBanner() async {
    await Future<void>.delayed(const Duration(seconds: 3));
    if (!mounted) {
      return;
    }
    try {
      await ref.read(groupIncidentServiceProvider).clear(
            groupId: widget.groupId,
            uid: widget.user.uid,
          );
    } catch (_) {}
  }

  String _bannerId(GroupIncident incident) =>
      '${incident.uid}|${incident.at.toIso8601String()}|${incident.type.name}';

  GroupIncident? _highestPriorityBanner(List<GroupIncident> incidents) {
    final candidates = incidents
        .where(
          (incident) =>
              incident.active && !_dismissedBannerIds.contains(_bannerId(incident)),
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
          left: MediaQuery.orientationOf(context) == Orientation.landscape
              ? 72
              : 48,
          top: MediaQuery.orientationOf(context) == Orientation.landscape
              ? 72
              : 120,
          right: MediaQuery.orientationOf(context) == Orientation.landscape
              ? 72
              : 48,
          bottom: MediaQuery.orientationOf(context) == Orientation.landscape
              ? 72
              : 100,
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
    return Material(
      elevation: 1,
      borderRadius: BorderRadius.circular(8),
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.94),
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
        Text(label, style: const TextStyle(fontSize: 12)),
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
    return Material(
      elevation: 1,
      borderRadius: BorderRadius.circular(8),
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 10,
          vertical: compact ? 4 : 8,
        ),
        child: Text(
          names.length == 1
              ? '1 motero aún no manda GPS'
              : '${names.length} moteros aún no mandan GPS',
          style: TextStyle(
            fontSize: compact ? 11 : 12,
            color: Theme.of(context).colorScheme.onTertiaryContainer,
          ),
        ),
      ),
    );
  }
}

/// Navegar, pelotón y centrar en un solo bloque.
class _GroupMapQuickActions extends StatelessWidget {
  const _GroupMapQuickActions({
    this.embedded = false,
    this.vertical = false,
    required this.hasSharedRoute,
    required this.followGroup,
    required this.onNavigate,
    required this.onPackList,
    required this.onRecenter,
  });

  final bool embedded;
  final bool vertical;
  final bool hasSharedRoute;
  final bool followGroup;
  final VoidCallback? onNavigate;
  final VoidCallback onPackList;
  final VoidCallback onRecenter;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final content =
        vertical ? _buildColumn(context, colors) : _buildRow(context, colors);

    if (embedded) {
      return content;
    }

    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      color: colors.surface.withValues(alpha: 0.96),
      child: Padding(
        padding: EdgeInsets.all(vertical ? 6 : 8),
        child: content,
      ),
    );
  }

  Widget _buildColumn(BuildContext context, ColorScheme colors) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasSharedRoute) ...[
          IconButton.filledTonal(
            tooltip: 'Navegar ruta',
            onPressed: onNavigate,
            style: IconButton.styleFrom(
              minimumSize: const Size(44, 44),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.navigation_rounded, size: 22),
          ),
          const SizedBox(height: 6),
        ],
        IconButton.outlined(
          tooltip: 'Pelotón',
          onPressed: onPackList,
          style: IconButton.styleFrom(
            minimumSize: const Size(44, 44),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: const Icon(Icons.format_list_bulleted_rounded, size: 22),
        ),
        const SizedBox(height: 6),
        IconButton.filledTonal(
          tooltip: 'Centrar grupo',
          onPressed: onRecenter,
          isSelected: followGroup,
          style: IconButton.styleFrom(
            backgroundColor: followGroup ? colors.primary : null,
            foregroundColor: followGroup ? colors.onPrimary : null,
            minimumSize: const Size(44, 44),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: const Icon(Icons.groups, size: 22),
        ),
      ],
    );
  }

  Widget _buildRow(BuildContext context, ColorScheme colors) {
    return Row(
      children: [
        if (hasSharedRoute) ...[
          Expanded(
            flex: 2,
            child: FilledButton.tonalIcon(
              onPressed: onNavigate,
              icon: const Icon(Icons.navigation_rounded, size: 18),
              label: Text(
                embedded ? 'Navegar' : 'Navegar ruta',
                style: const TextStyle(fontSize: 12),
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                minimumSize: const Size(0, 38),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onPackList,
            icon: const Icon(Icons.format_list_bulleted_rounded, size: 18),
            label: const Text(
              'Pelotón',
              style: TextStyle(fontSize: 12),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              minimumSize: const Size(0, 38),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
        const SizedBox(width: 4),
        IconButton.filledTonal(
          tooltip: 'Centrar grupo',
          onPressed: onRecenter,
          isSelected: followGroup,
          style: IconButton.styleFrom(
            backgroundColor: followGroup ? colors.primary : null,
            foregroundColor: followGroup ? colors.onPrimary : null,
            minimumSize: const Size(38, 38),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: const Icon(Icons.groups, size: 20),
        ),
      ],
    );
  }
}
